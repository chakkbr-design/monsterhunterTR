shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// Voxel-world water (docs/VOXEL.md, "Water"): a flat plane at local y = 0 over a voxel bed carved
// below it. Everything is read from the opaque pass: the screen texture (refraction of the bed,
// in-shader screen-space reflection) and the depth texture (water column for Beer-Lambert
// absorption, shore foam that follows the voxel steps of the bed, caustics projected on the bed,
// stream wakes behind rocks). Lighting: ALPHA stays 1, the refracted scene and the reflection go to
// EMISSION and the light scattered by the water body to ALBEDO, so the sun and the lamps light the
// body; light() adds sharp GGX highlights (sun glints, warm lamp streaks at night). SPECULAR = 0
// turns the engine's sky reflection off: the reflection is ray-marched against the depth buffer and
// falls back to the sky globals. Patterns use world metres (optionally quantised to the 1/16 m
// detail grid, the "voxel pixel" look); only the ellipse shape and the life paths follow the node's
// transform, so scaling the node grows / dries a pond without stretching the ripples.
// Budget per pixel: 2 + ssr_steps + 4 depth taps (3 more on streams), 2 screen taps, 1 leaf tap,
// 3 gradient-noise octaves, 4-iteration caustic, 3x3 rain cells only while it rains.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D leaf_tex : source_color, filter_nearest, repeat_disable, hint_default_transparent;

group_uniforms shape;
uniform int kind = 0;  // 0 pond, 1 fountain, 2 stream, 3 sea, 4 puddle (WaterSurface.KINDS)
uniform int shape = 0;  // 0 rectangle (the terrain cuts the shore), 1 ellipse inscribed in `size`
uniform vec2 size = vec2(4.0);  // plane size in local metres (ellipse, life paths)
uniform float seed = 0.0;
uniform vec2 flow = vec2(0.0);  // world m/s (streams)
uniform float depth_hint = 1.0;  // typical bed depth (m): scales absorption
uniform float pixel = 0.0625;  // pattern grid (m), 1/16 = detail voxel; 0 = smooth

group_uniforms colour;
uniform vec4 deep_color : source_color = vec4(0.015, 0.17, 0.23, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.78, 1.0, 0.94, 1.0);
uniform vec3 absorb = vec3(1.4, 0.46, 0.38);  // Beer-Lambert per metre at depth_hint 1
uniform float murk_blur = 1.4;  // screen mip per metre of path
uniform float body_light = 1.0;  // how strongly the water body scatters light

group_uniforms surface;
uniform float wave_amp = 1.0;
uniform float wave_scale = 1.0;
uniform float wave_speed = 1.0;
uniform float chop = 1.0;
uniform float swell = 0.0;  // long sea swell
uniform float refract_strength = 0.3;
uniform float roughness = 0.07;
uniform float reflect_strength = 1.0;
uniform float fresnel_min = 0.04;

group_uniforms foam;
uniform float foam_width = 0.2;  // m of water column that foams at the shore
uniform float foam_amount = 1.0;
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);

group_uniforms caustics;
uniform float caustic_strength = 1.4;
uniform float caustic_scale = 2.2;  // cells per metre

group_uniforms reflection;
uniform int ssr_steps = 20;
uniform float ssr_max = 14.0;

group_uniforms life;
uniform int fish_count = 0;
uniform vec4 fish_color_a : source_color = vec4(0.98, 0.42, 0.16, 1.0);
uniform vec4 fish_color_b : source_color = vec4(0.97, 0.9, 0.82, 1.0);
uniform float fish_jump = 1.0;
uniform float leaf_density = 0.0;
uniform float petal_density = 0.0;
uniform float sparkle = 1.0;

group_uniforms ripples;
uniform vec4 ripple_src[12];  // local x, local z, radius (m), strength
uniform int ripple_count = 0;

group_uniforms ice;
uniform float freeze = 0.0;  // 0..1 ice grows from the shallows over the whole surface
uniform float frost = 1.0;  // thin ice at the margins when snow_cover is high
group_uniforms;
uniform int debug_view = 0;  // 1 reflection, 2 hit mask, 3 refraction, 4 foam, 5 column, 6 caustic

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_gust;
global uniform vec3 sun_dir_world;
global uniform vec4 sun_color_world;
global uniform float sun_amount;
global uniform vec4 sky_top_color;
global uniform vec4 sky_horizon_color;
global uniform float rain_amount;
global uniform float snow_cover;
global uniform float lightning_flash;

varying float v_spec;
varying float v_twinkle;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Gradient noise with its analytic derivative (Inigo Quilez): x = value, yz = d/dp.
vec3 noised(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	vec2 ga = hash22(i) * 2.0 - 1.0;
	vec2 gb = hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 gc = hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 gd = hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
	float va = dot(ga, f);
	float vb = dot(gb, f - vec2(1.0, 0.0));
	float vc = dot(gc, f - vec2(0.0, 1.0));
	float vd = dot(gd, f - vec2(1.0, 1.0));
	float k = va - vb - vc + vd;
	float v = va + u.x * (vb - va) + u.y * (vc - va) + u.x * u.y * k;
	vec2 d = ga + u.x * (gb - ga) + u.y * (gc - ga) + u.x * u.y * (ga - gb - gc + gd)
			+ du * (u.yx * k + vec2(vb, vc) - va);
	return vec3(v, d);
}

vec2 rot(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Expanding rain rings in 0.4 m cells: xy = slope, z = fresh-impact splash.
// Raindrop rings on 0.5 m cells: one drop per cell and cycle (amt = chance), a crest growing to
// 0.3 m with a fainter inner ring. Returns (slope.xy, crest line 0..1, splash dot 0..1). The crest
// is 0.08 m wide so it stays one or two voxel pixels thick when drawn on the 1/16 m grid.
vec4 rain_rings(vec2 p, float t, float amt) {
	vec2 g = p * 2.0;
	vec2 id = floor(g);
	vec2 acc = vec2(0.0);
	float line = 0.0;
	float splash = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = id + vec2(float(x), float(y));
			vec2 h = hash22(c);
			float tt = t * (1.2 + h.y * 0.6) + h.x * 7.0;
			float ph = fract(tt);
			float cyc = floor(tt);
			if (hash12(c + cyc * 0.37) > amt) {
				continue;
			}
			vec2 d = (g - (c + 0.2 + 0.6 * hash22(c + cyc * 1.37))) * 0.5;
			float r = length(d);
			float rr = 0.02 + ph * 0.28;
			float fade = (1.0 - ph) * (1.0 - ph);
			float u = (r - rr) / 0.04;
			float crest = exp(-u * u);
			acc -= d / max(r, 1e-4) * 2.0 * u * crest * fade;
			float u2 = (r - rr * 0.5) / 0.04;
			line = max(line, max(crest, exp(-u2 * u2) * 0.6 * step(0.08, rr)) * fade);
			splash += smoothstep(0.1, 0.0, ph) * smoothstep(0.05, 0.0, r);
		}
	}
	return vec4(acc, line, splash);
}

// Caustic web: bright edges of drifting Voronoi cells (feature points circle slowly).
float caustic(vec2 p, float t) {
	p += 0.35 * vec2(sin(p.y * 1.3 + t * 0.7), sin(p.x * 1.1 - t * 0.6));
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 b = vec2(float(x), float(y));
			vec2 h = hash22(i + b);
			vec2 o = 0.5 + 0.36 * sin(t * (0.5 + 0.6 * h) + TAU * h);
			float d = length(b + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	float e = 1.0 - smoothstep(0.0, 0.2, f2 - f1);
	return e * e * (0.6 + 0.4 * smoothstep(0.2, 0.7, f1));
}

// View-space position of the opaque scene at uv (reversed Z, Forward+). Sky = very far.
vec3 view_at(vec2 uv, mat4 ip) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	d = max(d, 1e-7);
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

vec2 to_uv(vec3 p, mat4 proj) {
	vec4 c = proj * vec4(p, 1.0);
	return c.xy / max(c.w, 1e-4) * 0.5 + 0.5;
}

// 1 when the opaque scene covers world point q from above, close to q: a bank, a rock, a post or
// a leg emerges there (anything far in front of q, like a person on the dock, does not count).
float emerged(vec3 q, mat4 view, mat4 inv_view, mat4 proj, mat4 ip) {
	vec3 qv = (view * vec4(q, 1.0)).xyz;
	vec2 u = to_uv(qv, proj);
	if (u.x <= 0.0 || u.y <= 0.0 || u.x >= 1.0 || u.y >= 1.0) {
		return 0.0;
	}
	vec3 sv = view_at(u, ip);
	if (sv.z < qv.z - 0.02) {
		return 0.0;
	}
	vec3 sw = (inv_view * vec4(sv, 1.0)).xyz;
	return (sw.y > q.y - 0.03 && distance(sw, q) < 0.5) ? 1.0 : 0.0;
}

// Screen-space reflection marched against the depth buffer: rgb + confidence.
vec4 ssr(vec3 p0, vec3 r, mat4 proj, mat4 ip, float jit) {
	float stp = 0.07;
	float tr = stp * jit;
	float prev = 0.0;
	for (int i = 0; i < ssr_steps; i++) {
		prev = tr;
		tr += stp;
		stp *= 1.2;
		if (tr > ssr_max) {
			break;
		}
		vec3 p = p0 + r * tr;
		if (p.z > -0.05) {
			break;
		}
		vec2 uv = to_uv(p, proj);
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			break;
		}
		float dz = view_at(uv, ip).z - p.z;
		if (dz > 0.0 && dz < 0.3 + tr * 0.15) {
			float a = prev;
			float b = tr;
			for (int k = 0; k < 4; k++) {
				float m = (a + b) * 0.5;
				vec3 pm = p0 + r * m;
				vec2 um = to_uv(pm, proj);
				if (view_at(um, ip).z - pm.z > 0.0) {
					b = m;
				} else {
					a = m;
				}
			}
			uv = to_uv(p0 + r * b, proj);
			vec2 e = smoothstep(vec2(0.0), vec2(0.08), uv) * smoothstep(vec2(0.0), vec2(0.08), 1.0 - uv);
			float conf = e.x * e.y * (1.0 - smoothstep(ssr_max * 0.6, ssr_max, b));
			return vec4(textureLod(screen_tex, uv, 0.0).rgb, conf);
		}
	}
	return vec4(0.0);
}

vec3 sky_color(vec3 rw) {
	float h = clamp(rw.y, 0.0, 1.0);
	vec3 top = to_linear(sky_top_color.rgb);
	vec3 hor = to_linear(sky_horizon_color.rgb);
	vec3 c = mix(hor, top, sqrt(h));
	return c * (1.0 + lightning_flash * 5.0);
}

// Fish silhouette in its own frame (x forward, y to the side), metres: 1 inside.
float fish_shape(vec2 q, float t, float ph) {
	float len = 0.34;
	float tail = clamp(0.5 - q.x / len, 0.0, 1.0);
	float v = q.y + sin(q.x * 14.0 - t * 8.0 + ph) * 0.03 * tail * tail;
	vec2 e = vec2(q.x / (len * 0.5), v / 0.06);
	float body = step(dot(e, e), 1.0);
	float tu = -q.x - len * 0.42;
	float fin = step(0.0, tu) * step(tu, 0.1) * step(abs(v), 0.015 + tu * 0.8);
	return max(body, fin);
}

vec2 fish_local(int i, float t) {
	float fi = float(i) + seed * 0.13;
	float h1 = hash11(fi * 7.31 + 0.5);
	float h2 = hash11(fi * 3.17 + 1.3);
	float h3 = hash11(fi * 5.91 + 2.7);
	float w = 0.07 + 0.05 * h1;
	vec2 c = (vec2(h2, h3) - 0.5) * 0.16 * size;
	vec2 rr = size * vec2(0.17 + 0.08 * h3, 0.15 + 0.08 * h1);
	float a = t * w + h2 * TAU;
	return c + vec2(sin(a), sin(a * 1.37 + h1 * TAU)) * rr;
}

void fragment() {
	float t = TIME;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 wsize = size * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	vec2 fwv = fwidth(wp.xz);
	float fw = max(max(fwv.x, fwv.y), 1e-4);  // metres per screen pixel
	// Quantise patterns to the detail lattice while a cell spans >= ~2.5 pixels.
	float px = (pixel > 0.0 && fw * 2.5 < pixel) ? pixel : 0.0;
	vec2 pq = px > 0.0 ? (floor(wp.xz / px) + 0.5) * px : wp.xz;
	float lod = 1.0 - smoothstep(0.03, 0.12, fw);  // small ripples fade when unresolvable

	// Ellipse shape on the 0.25 m voxel columns (follows the node's scale: a drying pond).
	bool outside = false;
	float edge = 1e3;
	if (shape == 1) {
		// Ellipse tested per 0.25 m voxel column, so the outline steps like the voxel bed; the
		// edge distance is measured to the border of the nearest outside column (foam band).
		mat3 ib = inverse(mat3(MODEL_MATRIX));
		vec2 half_size = max(size * 0.5, vec2(0.01));
		vec2 col_id = floor(wp.xz * 4.0);
		vec2 fr = wp.xz * 4.0 - col_id;
		vec3 lo = ib * (vec3((col_id.x + 0.5) * 0.25, wp.y, (col_id.y + 0.5) * 0.25) - origin);
		outside = length(lo.xz / half_size) > 1.0;
		vec2 dirs[4] = {vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0)};
		for (int k = 0; k < 4; k++) {
			vec2 nc = (col_id + dirs[k] + 0.5) * 0.25;
			vec3 nl = ib * (vec3(nc.x, wp.y, nc.y) - origin);
			if (length(nl.xz / half_size) > 1.0) {
				float d = dot(dirs[k], dirs[k] * 0.5 + 0.5 - fr);
				edge = min(edge, max(d, 0.0) * 0.25);
			}
		}
	}

	// ---------------- surface slope (world gradient of the height field)
	vec2 wd = length(wind_dir) > 1e-4 ? normalize(wind_dir) : vec2(1.0, 0.0);
	float gust = clamp(wind_gust, 0.0, 1.5);
	float wind = clamp(wind_strength, 0.0, 3.0) * (1.0 + gust);
	float energy = wave_amp * (0.55 + 0.45 * wind) * (1.0 + 0.6 * rain_amount);
	vec2 g = vec2(0.0);
	float agit = 0.0;  // agitation foam (jets, fish, rocks)
	float splash = 0.0;
	float rain_line = 0.0;  // raindrop ring crests, drawn as faint foam
	{
		vec2 p = pq;
		vec2 fdir = length(flow) > 1e-3 ? normalize(flow) : wd;
		vec2 d2 = rot(wd, 0.7);
		vec2 d3 = rot(wd, -0.6);
		float sc = wave_scale;
		float sp = wave_speed;
		if (kind == 2) {
			// Streams: pattern rides the flow, stretched along it.
			vec2 a = vec2(dot(p - flow * t, fdir), dot(p - flow * t, vec2(-fdir.y, fdir.x)));
			vec2 s1 = vec2(0.55, 1.5) * sc;
			vec2 s2 = vec2(1.3, 3.4) * sc;
			vec3 n1 = noised(a * s1 + vec2(0.0, t * 0.05));
			vec3 n2 = noised(a * s2 + vec2(17.0, -t * 0.09));
			vec2 ga = n1.yz * s1 * 0.035 + n2.yz * s2 * 0.012 * lod;
			g += ga.x * fdir + ga.y * vec2(-fdir.y, fdir.x);
		} else {
			vec3 n1 = noised((p - (flow + wd * 0.1 * sp) * t) * 0.45 * sc + seed);
			vec3 n2 = noised((p - (flow + d2 * 0.17 * sp) * t) * 1.15 * sc + 31.0);
			vec3 n3 = noised((p - (flow + d3 * 0.26 * sp) * t) * 2.9 * sc + 57.0);
			// Cat's paws: gust patches sweeping with the wind roughen the small ripples.
			float paws = smoothstep(0.35, 0.8, vnoise((p - wd * (0.9 + gust) * t) * 0.22));
			float small = (0.45 + paws * (0.6 + 1.2 * gust)) * chop * lod;
			g += n1.yz * 0.45 * sc * 0.045;
			g += n2.yz * 1.15 * sc * 0.016;
			g += n3.yz * 2.9 * sc * 0.0055 * small;
		}
		g *= energy;
		if (swell > 0.0) {
			float k1 = TAU / 6.5;
			float k2 = TAU / 3.9;
			vec2 s1 = rot(wd, 0.25);
			vec2 s2 = rot(wd, -0.4);
			g += s1 * k1 * 0.07 * cos(dot(p, s1) * k1 - t * sqrt(9.8 * k1) * 0.6) * swell;
			g += s2 * k2 * 0.04 * cos(dot(p, s2) * k2 - t * sqrt(9.8 * k2) * 0.6 + 1.3) * swell;
		}
		if (rain_amount > 0.002) {
			vec4 rr = rain_rings(pq, t, clamp(rain_amount, 0.0, 1.0));
			g += rr.xy * 0.18;
			rain_line = smoothstep(0.3, 0.6, rr.z) * lod;
			splash += rr.w;
		}
		// Ripple sources (fountain jets, cascades): rings + turbulence + churn foam.
		for (int i = 0; i < ripple_count; i++) {
			vec4 s = ripple_src[i];
			vec3 sw = (MODEL_MATRIX * vec4(s.x, 0.0, s.y, 1.0)).xyz;
			vec2 d = pq - sw.xz;
			float r = length(d);
			float rad = max(s.z, 0.05);
			float fall = exp(-max(r - rad, 0.0) * 2.2) * s.w;
			float ph = r * 24.0 - t * 7.0 + float(i) * 1.7;
			float wob = 0.7 + 0.3 * sin(atan(d.y, d.x) * 3.0 + t * 1.3 + float(i));
			g += d / max(r, 1e-3) * cos(ph) * 0.07 * fall * wob;
			float inz = smoothstep(rad * 1.25, rad * 0.2, r) * s.w;
			vec3 tn = noised(pq * 6.0 + vec2(t * 2.3 + float(i) * 3.1, -t * 1.9));
			g += tn.yz * 0.05 * inz;
			agit = max(agit, inz * smoothstep(0.42, 0.62, vnoise(pq * 11.0 + vec2(t * 5.0, -t * 3.0) + float(i) * 9.0)));
		}
	}

	// ---------------- life: fish paths (local, scale with the node), jump rings
	float fish_m = 0.0;
	vec3 fish_c = vec3(0.0);
	float fish_d = 0.25;
	vec2 fish_p[4];
	float fish_y[4];
	int nf = min(fish_count, 4);
	for (int i = 0; i < nf; i++) {
		vec2 l0 = fish_local(i, t);
		vec2 l1 = fish_local(i, t + 0.15);
		vec2 f0 = (MODEL_MATRIX * vec4(l0.x, 0.0, l0.y, 1.0)).xz;
		vec2 f1 = (MODEL_MATRIX * vec4(l1.x, 0.0, l1.y, 1.0)).xz;
		vec2 hd = normalize(f1 - f0 + vec2(1e-5, 0.0));
		float df = 0.22 + 0.08 * sin(t * 0.37 + float(i) * 2.1);
		fish_p[i] = f0;
		fish_y[i] = df;
		vec2 dq = pq - f0;
		vec2 q = vec2(dot(dq, hd), dot(dq, vec2(-hd.y, hd.x)));
		float m = fish_shape(q, t, float(i) * 1.3);
		if (m > fish_m) {
			fish_m = m;
			fish_c = mod(float(i), 2.0) < 0.5 ? fish_color_a.rgb : fish_color_b.rgb;
			fish_d = df;
		}
		// Now and then a fish breaks the surface: rings and a splash.
		float per = 9.0 + 6.0 * hash11(float(i) * 4.7 + seed);
		float cyc = floor(t / per);
		float age = t - cyc * per;
		if (hash12(vec2(cyc, float(i) + seed)) < 0.55 * fish_jump && age < 2.6) {
			vec2 lj = fish_local(i, cyc * per);
			vec2 jp = (MODEL_MATRIX * vec4(lj.x, 0.0, lj.y, 1.0)).xz;
			vec2 d = pq - jp;
			float r = length(d);
			float rr = 0.08 + age * 0.45;
			float a = (1.0 - age / 2.6);
			float ring = sin((r - rr) * 26.0) * smoothstep(0.3, 0.0, abs(r - rr)) * a * a;
			g += d / max(r, 1e-3) * ring * 0.09;
			agit = max(agit, smoothstep(0.5, 0.0, age) * smoothstep(0.22, 0.05, r));
			splash += smoothstep(0.03, 0.0, abs(r - rr)) * a * 0.6;
		}
	}

	// ---------------- depth: water column, refraction
	vec3 nflat = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float sdepth = -VERTEX.z;
	vec3 vb0 = view_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bw0 = (INV_VIEW_MATRIX * vec4(vb0, 1.0)).xyz;
	float col0 = wp.y - bw0.y;  // vertical column under this pixel (negative: something sticks out)
	float fd = min(col0, edge);  // shallowness for foam / ice
	float fn = vnoise(pq * 3.3 + seed) * 0.6 + vnoise(pq * 8.1 - seed) * 0.4;
	// Waterline: 4 probes around the pixel (jittered per lattice cell, breathing like lapping
	// waves) find banks, rocks, posts and legs that come out of the water within foam_width.
	float near = 0.0;
	if (foam_amount > 0.0 || snow_cover > 0.5) {
		vec2 cell = floor(pq / 0.0625);
		float ang = hash12(cell + seed) * 1.5708;
		float breathe = 0.78 + 0.22 * sin(t * 1.3 + fn * 6.0);
		float reach = max(foam_width, 0.12 * smoothstep(0.5, 1.0, snow_cover));
		for (int k = 0; k < 4; k++) {
			float rr = reach * breathe * (0.35 + 0.65 * hash12(cell * 1.7 + float(k) * 7.1));
			vec2 o = rot(vec2(rr, 0.0), ang + float(k) * 1.5708);
			near += emerged(vec3(wp.x + o.x, wp.y, wp.z + o.y), VIEW_MATRIX, INV_VIEW_MATRIX,
					PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
		}
		near *= 0.25;
	}

	// Ice: from the shallows outwards with `freeze`, a thin rim of frost with heavy snow.
	float ice_thr = freeze * max(depth_hint * 3.0, 1.5) + smoothstep(0.55, 1.0, snow_cover) * 0.32 * frost;
	float ice = freeze > 0.995 ? 1.0 : (1.0 - smoothstep(ice_thr * 0.75, ice_thr + 0.001, fd + (fn - 0.5) * 0.08));
	ice *= step(0.001, ice_thr);
	ice = max(ice, step(0.12, near) * smoothstep(0.55, 0.9, snow_cover) * frost);
	g *= 1.0 - ice * 0.9;
	vec3 nw = normalize(vec3(-g.x, 1.0, -g.y));
	vec3 nv = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	NORMAL = nv;

	vec2 off = (nv - nflat).xy * vec2(1.0, -1.0) * refract_strength * PROJECTION_MATRIX[1][1] * 0.5
			/ max(sdepth, 0.5);
	off *= clamp(col0 * 4.0, 0.0, 1.0);
	vec2 uv = clamp(SCREEN_UV + off, vec2(0.002), vec2(0.998));
	vec3 vb = view_at(uv, INV_PROJECTION_MATRIX);
	if (-vb.z < sdepth + 0.02) {
		uv = SCREEN_UV;
		vb = vb0;
	}
	vec3 bw = (INV_VIEW_MATRIX * vec4(vb, 1.0)).xyz;
	float column = max(wp.y - bw.y, 0.0);
	float path = clamp(length(vb) - length(VERTEX), 0.0, 60.0);
	path *= 1.0 + 0.4 * rain_amount;
	vec3 tr = exp(-absorb / max(depth_hint, 0.15) * path);
	vec3 refr = textureLod(screen_tex, uv, clamp(path * murk_blur, 0.0, 3.5)).rgb;
	refr *= mix(vec3(1.0), shallow_color.rgb, smoothstep(0.0, 0.3, column));

	// Caustics on the bed, projected along the sun ray (none at night or under clouds).
	float caus = 0.0;
	vec3 sd = normalize(sun_dir_world + vec3(0.0, 1e-4, 0.0));
	if (sun_amount > 0.002 && caustic_strength > 0.0 && column > 0.01) {
		vec2 cp = bw.xz + sd.xz / max(sd.y, 0.25) * column + g * 1.5;
		cp = px > 0.0 ? (floor(cp / px) + 0.5) * px : cp;
		float c = caustic(cp * caustic_scale + seed * 0.37, t);
		caus = c;
		float cw = smoothstep(0.0, 0.08, column) * exp(-column * 0.8 / max(depth_hint, 0.3));
		refr *= 1.0 + c * cw * caustic_strength * sun_amount * to_linear(sun_color_world.rgb) * lod;
	}
	// Fish shadows on the bed.
	if (nf > 0 && sun_amount > 0.002) {
		float sh = 0.0;
		for (int i = 0; i < nf; i++) {
			float above = column - fish_y[i];
			if (above > 0.05) {
				vec2 sp = bw.xz + sd.xz / max(sd.y, 0.25) * above;
				sp = px > 0.0 ? (floor(sp / px) + 0.5) * px : sp;
				sh = max(sh, step(length(sp - fish_p[i]), 0.16) * 0.5);
			}
		}
		refr *= 1.0 - sh * sun_amount * 0.55;
	}

	// ---------------- reflection
	float ndv = clamp(dot(nv, VIEW), 0.0, 1.0);
	float fres = fresnel_min + (1.0 - fresnel_min) * pow(1.0 - ndv, 5.0);
	fres = clamp(fres * reflect_strength, 0.0, 1.0);
	vec3 rv = reflect(-VIEW, normalize(mix(nflat, nv, 0.6)));
	vec3 rw = (INV_VIEW_MATRIX * vec4(rv, 0.0)).xyz;
	vec3 refl = sky_color(rw);
	vec4 hit = vec4(0.0);
	if (ssr_steps > 0) {
		float jit = hash12(floor(pq * 16.0));
		hit = ssr(VERTEX, rv, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, jit);
		refl = mix(refl, hit.rgb, hit.a);
	}

	// ---------------- body, fish
	vec3 deep = deep_color.rgb;
	float scatter = 1.0 - dot(tr, vec3(0.25, 0.45, 0.3));
	vec3 albedo = deep * scatter * body_light;
	vec3 emis = refr * tr;
	// Fish under the surface: seen through df metres of water, lit like the body.
	float fish_vis = fish_m * smoothstep(fish_d + 0.02, fish_d + 0.18, col0) * (1.0 - ice);
	if (fish_vis > 0.0) {
		vec3 tf = exp(-absorb / max(depth_hint, 0.15) * fish_d * 1.8);
		albedo = mix(albedo, fish_c * tf * 0.75 + deep * (1.0 - tf) * 0.6, fish_vis);
		emis *= 1.0 - fish_vis * 0.85;
	}
	albedo *= 1.0 - fres;
	emis = emis * (1.0 - fres) + refl * fres;

	// ---------------- foam
	float foam = 0.0;
	if (foam_amount > 0.0) {
		float shore = smoothstep(0.15, 0.55, near);
		shore = max(shore, 1.0 - smoothstep(foam_width * 0.15, foam_width * 0.35, fd));
		if (kind == 2) {
			// Stream wakes: foam streaks downstream of rocks, found by looking upstream in the depth.
			vec2 fdir = length(flow) > 1e-3 ? normalize(flow) : vec2(0.0, 1.0);
			float wake = 0.0;
			for (int k = 1; k <= 3; k++) {
				vec3 up = vec3(wp.x - fdir.x * 0.3 * float(k), wp.y, wp.z - fdir.y * 0.3 * float(k));
				vec2 uu = to_uv((VIEW_MATRIX * vec4(up, 1.0)).xyz, PROJECTION_MATRIX);
				if (uu.x > 0.0 && uu.y > 0.0 && uu.x < 1.0 && uu.y < 1.0) {
					vec3 sw = (INV_VIEW_MATRIX * vec4(view_at(uu, INV_PROJECTION_MATRIX), 1.0)).xyz;
					float hit = step(wp.y - 0.06, sw.y) * step(distance(sw, up), 0.5);
					wake = max(wake, hit * (1.0 - float(k - 1) * 0.28));
				}
			}
			vec2 a = vec2(dot(pq - flow * t, fdir), dot(pq, vec2(-fdir.y, fdir.x)));
			float streak = vnoise(a * vec2(1.4, 9.0));
			shore = max(shore, wake * smoothstep(0.35, 0.6, streak));
			shore = max(shore, smoothstep(0.8, 0.95, vnoise(a * vec2(0.8, 6.0) + 40.0)) * 0.6);
		}
		if (kind == 3) {
			// Sea: surf lines rolling up the beach.
			float surf = smoothstep(0.86, 0.98, sin(fd * 9.0 - t * 1.7 + fn * 3.0));
			shore = max(shore, surf * (1.0 - smoothstep(0.2, 0.9, fd)) * step(0.0, fd));
		}
		foam = max(shore, agit) * foam_amount;
		foam = smoothstep(0.42, 0.58, foam * (0.7 + 0.6 * fn));
	}
	foam = max(foam, clamp(splash, 0.0, 1.0) * 0.9);
	foam = max(foam, rain_line * 0.4);
	foam *= 1.0 - ice;

	// ---------------- sparkles: tiny pixel stars blinking on the open water in the sun
	float spk = 0.0;
	if (sparkle > 0.0 && sun_amount > 0.01 && px > 0.0) {
		vec2 sc = floor(wp.xz * 2.0);
		float hs = hash12(sc + seed);
		float tt = t * (0.5 + 0.8 * hs) + hs * 10.0;
		float ph = fract(tt);
		float cyc = floor(tt);
		vec2 c = (sc + 0.15 + 0.7 * hash22(sc + cyc)) * 0.5;
		vec2 d = abs(floor((wp.xz - c) / px + 0.5));
		float star = d.x + d.y < 0.5 ? 1.0 : (d.x + d.y < 1.5 ? 0.45 : 0.0);
		float sunward = 0.25 + 0.75 * pow(max(dot(rw, sd), 0.0), 6.0);
		spk = star * smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.08, 0.3, ph));
		spk *= step(hash12(sc * 1.31 + cyc), 0.35 * sparkle * sunward) * lod;
	}

	// ---------------- floating leaves (Pixel Lab leaf) and petals, drifting in world space
	float leaf_a = 0.0;
	vec3 leaf_c = vec3(0.0);
	if ((leaf_density > 0.0 || petal_density > 0.0) && col0 > 0.03) {
		vec2 drift = flow + wd * (0.03 + 0.05 * gust) + vec2(cos(t * 0.031 + seed), sin(t * 0.027 + seed)) * 0.03;
		vec2 q = wp.xz - drift * t;
		float cs = 1.7;
		vec2 cid = floor(q / cs);
		vec2 cf = q - (cid + 0.5) * cs;
		vec2 h = hash22(cid + seed * 3.1);
		vec2 o = (hash22(cid * 1.73 + 11.0) - 0.5) * cs * 0.45;
		vec2 bob = vec2(sin(t * 0.7 + h.x * 9.0), cos(t * 0.6 + h.y * 9.0)) * 0.015;
		vec2 lq = cf - o - bob;
		if (h.x < leaf_density) {
			// 90 degree turns keep the pixel art crisp.
			float turn = floor(h.y * 4.0);
			vec2 r = turn < 1.0 ? lq : (turn < 2.0 ? vec2(-lq.y, lq.x) : (turn < 3.0 ? -lq : vec2(lq.y, -lq.x)));
			vec2 luv = r / 0.3 + 0.5;
			if (luv.x > 0.0 && luv.y > 0.0 && luv.x < 1.0 && luv.y < 1.0) {
				vec4 lc = texture(leaf_tex, luv);
				float hue = hash12(cid + 5.0);
				vec3 tint = hue < 0.55 ? vec3(1.0) : (hue < 0.8 ? vec3(1.35, 1.05, 0.35) : vec3(1.6, 0.6, 0.25));
				leaf_a = step(0.5, lc.a);
				leaf_c = lc.rgb * tint;
			}
		} else if (h.x < leaf_density + petal_density) {
			vec2 cell = floor(lq / 0.0625);
			vec2 hh = hash22(cid + 7.0);
			float w = hh.x < 0.5 ? 2.0 : 1.0;
			if (cell.x >= 0.0 && cell.x < w && cell.y >= 0.0 && cell.y < 3.0 - w) {
				leaf_a = 1.0;
				leaf_c = hh.y < 0.45 ? vec3(0.98, 0.62, 0.74) : (hh.y < 0.8 ? vec3(1.0, 0.96, 0.92) : vec3(1.0, 0.85, 0.3));
				leaf_c = to_linear(leaf_c);
			}
		}
		leaf_a *= 1.0 - ice;
	}

	// ---------------- ice / frost
	vec3 ice_c = vec3(0.0);
	if (ice > 0.0) {
		// Cracks along the edges of a jittered 0.6 m cell grid, then snow dusting.
		vec2 ip = pq * 1.6;
		vec2 ic = floor(ip);
		float best = 9.0;
		float second = 9.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = ic + vec2(float(x), float(y));
				float d = length(ip - c - hash22(c + seed));
				if (d < best) {
					second = best;
					best = d;
				} else if (d < second) {
					second = d;
				}
			}
		}
		float crack = 1.0 - smoothstep(0.02, 0.07, second - best);
		ice_c = mix(vec3(0.42, 0.62, 0.72), vec3(0.75, 0.88, 0.95), fn) * (1.0 - crack * 0.35);
		ice_c = mix(ice_c, vec3(0.86, 0.9, 0.96), smoothstep(0.3, 0.9, snow_cover) * (0.4 + 0.6 * fn));
	}

	// ---------------- compose
	emis += spk * to_linear(sun_color_world.rgb) * sun_amount * 5.0 * (1.0 - foam) * (1.0 - ice);
	albedo = mix(albedo, foam_color.rgb * 0.85, foam);
	emis *= 1.0 - foam;
	albedo = mix(albedo, leaf_c, leaf_a);
	emis *= 1.0 - leaf_a;
	albedo = mix(albedo, ice_c, ice * 0.9);
	emis = mix(emis, refr * tr * 0.3 + refl * fres * 0.6, ice);

	if (debug_view > 0) {
		albedo = vec3(0.0);
		vec3 dbg[6] = {refl, vec3(hit.a), refr * tr, vec3(foam), vec3(fract(column * 4.0)), vec3(caus)};
		emis = dbg[clamp(debug_view, 1, 6) - 1];
	}
	ALBEDO = albedo;
	EMISSION = emis;
	ROUGHNESS = mix(mix(roughness, 0.55, max(foam, leaf_a)), 0.18, ice);
	SPECULAR = 0.0;
	METALLIC = 0.0;
	ALPHA = 1.0;
	v_spec = (1.0 - max(foam, leaf_a)) * mix(1.0, 0.6, ice);
	vec2 cell16 = floor(pq / 0.0625);
	float tw = hash12(cell16 + floor(t * 7.0 + hash12(cell16) * 7.0));
	v_twinkle = step(1.0 - 0.025 * sparkle, tw) * 6.0 * sparkle * lod;
	if (outside) {
		discard;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// The water body scatters light like a volume: half-Lambert.
	DIFFUSE_LIGHT += clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float nh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float nl = clamp(ndl, 0.0, 1.0);
	float nv = clamp(dot(NORMAL, VIEW), 0.05, 1.0);
	float a = max(ROUGHNESS * ROUGHNESS, 0.0025);
	float a2 = a * a;
	float dd = nh * nh * (a2 - 1.0) + 1.0;
	float dist = a2 / (PI * dd * dd);
	float k = a * 0.5;
	float vis = 0.25 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
	float fr = 0.02 + 0.98 * pow(1.0 - clamp(dot(LIGHT, h), 0.0, 1.0), 5.0);
	vec3 s = dist * vis * fr * nl * ATTENUATION * LIGHT_COLOR * v_spec * (1.0 + v_twinkle);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lamps also leave a broad warm pool on the rippled surface.
		float b2 = 0.09;
		float db = nh * nh * (b2 - 1.0) + 1.0;
		s += b2 / (PI * db * db) * 0.25 * fr * nl * ATTENUATION * LIGHT_COLOR * v_spec;
	}
	SPECULAR_LIGHT += min(s, vec3(80.0));
}
