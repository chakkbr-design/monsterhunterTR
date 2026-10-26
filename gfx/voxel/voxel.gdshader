shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Voxel scenery (docs/VOXEL.md). Meshes from VoxelMesher.greedy only follow solidity; every
// fragment looks its voxel up in the grid's 3D texture (sRGB colour + material id), then derives
// per-voxel ambient occlusion and edge bevels from the occupancy around it, the material's
// lighting from VoxelMat.lut(), and rain / snow from the weather globals where the sky reaches it
// (column tops texture). Model-space coordinates are used, so a scaled or moved instance keeps its
// colours (arena hills squash when damaged).

uniform sampler3D vox : filter_nearest, repeat_disable;
uniform sampler2D tops : filter_nearest, repeat_disable, hint_default_black;
uniform sampler2D mat_lut : filter_nearest, repeat_disable;
uniform ivec3 grid_origin = ivec3(0);
uniform ivec3 grid_size = ivec3(1);
uniform float voxel = 0.25;
uniform float ao_strength = 1.0;
uniform float ao_direct = 0.55;  // how much voxel AO also darkens sun / lamp light
uniform float edge_light = 0.12;  // bevel highlight on convex voxel edges
uniform float seam_dark = 0.05;  // faint line between coplanar voxels
uniform float jitter = 0.03;  // per-voxel brightness noise
uniform float sway = 0.0;  // crown sway (m per m above sway_base)
uniform float sway_base = 0.0;
uniform float emit_window = 1.8;
uniform float emit_lamp = 5.0;
uniform float emit_always = 2.2;
uniform float emit_flood = 9.0;
uniform float weather = 1.0;  // 0 = ignore rain / snow (indoors)
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 flash = vec3(0.0);  // additive emission (hit flash)
// a > 0: lit windows glow in this colour instead of their own (a zone's warm lamplight; bright
// cream emission turns white under AgX). Default off: the arenas keep their look.
uniform vec4 window_glow : source_color = vec4(0.0);
// > 0: a floor of sky light (x the horizon colour) under the indirect light: the shaded
// undersides of a zone's bushes and crowns stay dark green. Default off: the arenas' look.
uniform float shade_lift = 0.0;

global uniform float night_lamps;
global uniform float night_windows;
global uniform float rain_wet;
global uniform float rain_puddle;
global uniform float rain_amount;
global uniform float snow_cover;
global uniform float wind_time;
global uniform vec2 wind_dir;
global uniform float wind_gust;
global uniform vec4 sky_horizon_color;

varying vec3 mpos;
varying vec3 mnrm;

void vertex() {
	mpos = VERTEX;
	mnrm = NORMAL;
	if (sway > 0.0) {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(w.y - sway_base, 0.0);
		float ph = wind_time * 1.3 + dot(w.xz, vec2(0.31, 0.23));
		float s = (sin(ph) * 0.6 + sin(ph * 2.3 + 1.7) * 0.25 + wind_gust * 0.9) * sway * h;
		VERTEX.x += wind_dir.x * s;
		VERTEX.z += wind_dir.y * s;
	}
}

vec4 cell(ivec3 c) {
	ivec3 t = c - grid_origin;
	if (any(lessThan(t, ivec3(0))) || any(greaterThanEqual(t, grid_size))) {
		return vec4(0.0);
	}
	return texelFetch(vox, ivec3(t.x, t.z, t.y), 0);
}

float occ(ivec3 c) {
	return cell(c).a > 0.0 ? 1.0 : 0.0;
}

float corner_ao(float s1, float s2, float c) {
	return (s1 > 0.5 && s2 > 0.5) ? 0.0 : 3.0 - (s1 + s2 + c);
}

// 1 when the air cell `a` is at or above the highest solid voxel of its column.
float sky(ivec3 a) {
	ivec3 t = a - grid_origin;
	if (t.x < 0 || t.z < 0 || t.x >= grid_size.x || t.z >= grid_size.z) {
		return 1.0;
	}
	float top = texelFetch(tops, ivec2(t.x, t.z), 0).r * 255.0;
	return float(t.y) >= top - 0.5 ? 1.0 : 0.0;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Expanding rings from rain drops (0.4 m cells); returns an xz normal tilt.
vec2 ripples(vec2 p, float t, float amt) {
	if (amt < 0.001) {
		return vec2(0.0);
	}
	vec2 g = p * 2.5;
	vec2 id = floor(g);
	vec2 acc = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = id + vec2(float(x), float(y));
			float hx = h21(c);
			float hy = h21(c + 17.3);
			float tt = t * (0.9 + hy * 0.4) + hx * 7.0;
			float ph = fract(tt);
			float cyc = floor(tt);
			if (h21(c + cyc) > amt) {
				continue;
			}
			vec2 d = g - (c + 0.2 + 0.6 * vec2(h21(c + cyc * 1.37), h21(c + cyc * 2.11)));
			float r = length(d);
			float rr = ph * 1.2;
			float ring = sin((r - rr) * 18.0) * smoothstep(0.25, 0.0, abs(r - rr)) * (1.0 - ph) * (1.0 - ph);
			acc += d / max(r, 1e-4) * ring;
		}
	}
	return acc * 0.6;
}

void fragment() {
	vec3 n = normalize(mnrm);
	ivec3 ni = ivec3(round(n));
	vec3 g = mpos / voxel;
	ivec3 c = ivec3(floor(g - n * 0.5));
	vec4 src = cell(c);
	ivec3 t1;
	ivec3 t2;
	vec2 f;
	if (ni.x != 0) {
		t1 = ivec3(0, 1, 0);
		t2 = ivec3(0, 0, 1);
		f = fract(g.yz);
	} else if (ni.y != 0) {
		t1 = ivec3(1, 0, 0);
		t2 = ivec3(0, 0, 1);
		f = fract(g.xz);
	} else {
		t1 = ivec3(1, 0, 0);
		t2 = ivec3(0, 1, 0);
		f = fract(g.xy);
	}
	// Ambient occlusion from the 8 cells around the air cell in front of the face (0fps rule).
	ivec3 a = c + ni;
	float s1m = occ(a - t1);
	float s1p = occ(a + t1);
	float s2m = occ(a - t2);
	float s2p = occ(a + t2);
	float ao00 = corner_ao(s1m, s2m, occ(a - t1 - t2));
	float ao10 = corner_ao(s1p, s2m, occ(a + t1 - t2));
	float ao01 = corner_ao(s1m, s2p, occ(a - t1 + t2));
	float ao11 = corner_ao(s1p, s2p, occ(a + t1 + t2));
	float aoi = mix(mix(ao00, ao10, f.x), mix(ao01, ao11, f.x), f.y) / 3.0;
	float ao = mix(1.0, mix(0.4, 1.0, aoi), ao_strength);
	// Convex edges (the in-plane neighbour is air) catch a bevel highlight.
	float w = 0.1;
	float e1m = (1.0 - occ(c - t1)) * (1.0 - smoothstep(0.0, w, f.x));
	float e1p = (1.0 - occ(c + t1)) * (1.0 - smoothstep(0.0, w, 1.0 - f.x));
	float e2m = (1.0 - occ(c - t2)) * (1.0 - smoothstep(0.0, w, f.y));
	float e2p = (1.0 - occ(c + t2)) * (1.0 - smoothstep(0.0, w, 1.0 - f.y));
	float conv = max(max(e1m, e1p), max(e2m, e2p));
	float ed = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = 1.0 - smoothstep(0.0, 0.045, ed);

	int id = int(src.a * 255.0 + 0.5);
	vec4 lut = texelFetch(mat_lut, ivec2(id, 0), 0);
	float rough = lut.r;
	int emit_class = int(lut.g * 255.0 + 0.5);
	float por = lut.b;
	int flags = int(lut.a * 255.0 + 0.5);

	vec3 col = to_linear(src.rgb) * tint.rgb;
	col *= 1.0 + (h31(vec3(c)) - 0.5) * 2.0 * jitter;
	float bevel = (1.0 + edge_light * conv * (ni.y > 0 ? 1.0 : 0.55))
			* (1.0 - seam_dark * seam * (1.0 - conv));
	col *= bevel;

	// Weather on surfaces the sky reaches.
	float expo = sky(a) * weather;
	float up = ni.y > 0 ? 1.0 : 0.0;
	vec3 nw = n;
	float spec = (flags & 32) != 0 ? 0.6 : 0.35;
	float wet = rain_wet * expo * (1.0 - float((flags & 16) != 0));
	float k = mix(1.0, 0.38, por);
	col *= mix(1.0, k, wet);
	rough = mix(rough, 0.14, wet * (1.0 - 0.4 * por));
	spec = mix(spec, 0.5, wet);
	if ((flags & 2) != 0 && up > 0.5 && rain_puddle > 0.001) {
		vec2 vc = floor(mpos.xz / voxel);
		float pn = vnoise(vc * 0.11) * 0.75 + vnoise(vc * 0.37) * 0.25;
		float pud = smoothstep(1.0 - rain_puddle, 1.06 - rain_puddle, pn) * expo;
		col = mix(col, col * 0.42, pud);
		rough = mix(rough, 0.02, pud);
		spec = mix(spec, 0.6, pud);
		vec2 rp = ripples(mpos.xz, TIME, rain_amount) * pud;
		nw = normalize(vec3(rp.x, 1.0, rp.y));
	}
	if ((flags & 1) != 0 && snow_cover > 0.001) {
		// Settles (and thaws) in drifts rather than voxel by voxel: low noise plus a ragged edge.
		vec2 cc = vec2(float(c.x), float(c.z));
		float drift = vnoise(cc * 0.21) * 0.55 + h31(vec3(cc.x, 0.0, cc.y) + 3.1) * 0.45;
		float sn = up * expo * step(drift, snow_cover * 1.15);
		// The top voxel of a column also gets a snow band on its sides.
		if (up < 0.5 && ni.y == 0) {
			float above = 1.0 - occ(c + ivec3(0, 1, 0));
			float cap = above * sky(c + ivec3(0, 1, 0)) * weather;
			sn = max(sn, cap * step(1.0 - snow_cover * 0.45, fract(g.y)));
		}
		// Not one flat white sheet, so paths, beds, pond banks and court lines still read:
		// - trodden ground (the F_PUDDLE materials: stone, dirt, sand, slab, gravel) keeps a thinner,
		//   greyer, patchy layer (the ground shows through here and there) against the smooth white
		//   lawns and roofs;
		// - painted lines and emblems (VoxelMat.PAINT, id 24) are swept: wet paint under a dusting,
		//   darker than the snow around it (white lines on a white field still read);
		// - a per-voxel grain (+-7 %) and slow drift shading (+-8 %);
		// - the voxel seams three times darker than bare ground, so the grid stays visible.
		float trod = (flags & 2) != 0 ? up : 0.0;
		float grain = 0.86 + 0.14 * h31(vec3(c) + 9.1) + 0.16 * (vnoise(cc * 0.05) - 0.5);
		vec3 snow = mix(vec3(0.86, 0.9, 0.96), vec3(0.6, 0.62, 0.66), trod);
		float seam_s = 1.0 - 2.0 * seam_dark * seam * (1.0 - conv);
		float patchy = 1.0 - 0.45 * step(0.7, h31(vec3(c) + 4.7));
		float swept = id == 24 ? sn : 0.0;
		col *= mix(1.0, 0.72, swept);
		rough = mix(rough, 0.3, swept);
		sn *= mix(1.0, 0.75 * patchy, trod) * (1.0 - 0.7 * swept);
		col = mix(col, snow * grain * bevel * seam_s, sn);
		rough = mix(rough, 0.75, sn);
		wet *= 1.0 - sn;
	}
	if (any(notEqual(nw, n))) {
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nw, 0.0)).xyz);
	}

	vec3 em = vec3(0.0);
	if (emit_class == 1) {
		em = mix(col, window_glow.rgb, window_glow.a) * emit_window * night_windows;
		col *= 1.0 - window_glow.a * night_windows;  // the lit pane, not moonlit cream glass
	} else if (emit_class == 2) {
		em = col * emit_lamp * night_lamps;
	} else if (emit_class == 3) {
		em = col * emit_always;
	} else if (emit_class == 4) {
		em = col * emit_flood * night_lamps;
	}
	if (shade_lift > 0.0) {
		em += col * to_linear(sky_horizon_color.rgb) * shade_lift;
	}
	ALBEDO = col * mix(1.0, ao, 0.35);
	AO = ao;
	AO_LIGHT_AFFECT = ao_direct;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = (flags & 8) != 0 ? 0.75 : 0.0;
	EMISSION = em + flash;
	if ((flags & 4) != 0) {
		BACKLIGHT = col * 0.35;
	}
}
