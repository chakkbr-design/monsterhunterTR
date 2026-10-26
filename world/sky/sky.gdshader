shader_type sky;
// Overworld sky (WorldTimeOfDay owns the material; the live Environment keeps it for every zone).
// The fixed overworld camera rarely shows the sky itself: it matters through the ambient light and
// the reflections it feeds (radiance cubemap, water fallback), so the gradient follows the
// ProceduralSkyMaterial curve the HGSS looks were tuned with. On top of it:
//   - horizon haze warmed toward the sun (golden hour / dawn), `haze`;
//   - sun disc (HDR, also in the radiance pass so water and wet stone catch it);
//   - moon disc with a phase terminator and a faint halo;
//   - stars at night (screen pass only, never in the radiance cubemap);
//   - a cloud layer: fair-weather puffs always, closing into overcast with the cloud_cover global,
//     lit by the sun (silver lining) and the lightning_flash global;
//   - in the radiance cubemap only, a pull toward a neutral/warm tint (ambient_neutral).
// Every uniform is written by WorldTimeOfDay at a low rate (no TIME here, so the radiance map is
// only refreshed when something actually changes; the Sky runs in incremental mode).

uniform vec3 top_color : source_color = vec3(0.36, 0.55, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.86, 0.82);
uniform vec3 ground_color : source_color = vec3(0.28, 0.27, 0.24);
uniform float sky_curve = 0.15;
uniform float energy = 1.0;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);  // toward the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_visible = 1.0;
uniform float sun_size = 0.022;  // radians
uniform float sun_disc_energy = 18.0;

uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 moon_color : source_color = vec3(0.85, 0.88, 0.95);
uniform float moon_visible = 0.0;
uniform float moon_size = 0.032;
uniform float moon_phase = 0.5;  // 0 new, 0.5 full

uniform float stars = 0.0;
uniform float haze = 0.0;
uniform vec3 haze_color : source_color = vec3(1.0, 0.62, 0.35);
uniform vec2 cloud_offset = vec2(0.0);
// Radiance cubemap only (ambient light, SDFGI sky light, reflections): pulls the dome toward its
// own luminance in `ambient_tint`, so a blue dawn/dusk dome does not tint grey stone in shadow.
uniform vec3 ambient_tint : source_color = vec3(1.0);
uniform float ambient_neutral = 0.0;
uniform float cloud_base = 0.22;  // fair-weather coverage on a clear day

global uniform float cloud_cover;
global uniform float lightning_flash;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
		mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float v_angle = acos(clamp(d.y, -1.0, 1.0));
	vec3 col;
	if (d.y >= 0.0) {
		float c = 1.0 - v_angle / (PI * 0.5);
		col = mix(horizon_color, top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	} else {
		float c = (v_angle - PI * 0.5) / (PI * 0.5);
		col = mix(horizon_color * 0.8, ground_color, clamp(1.0 - pow(1.0 - c, 1.0 / 0.04), 0.0, 1.0));
	}
	float above = smoothstep(-0.02, 0.04, d.y);
	float day = clamp(lum(top_color) * 4.0, 0.0, 1.0);

	// Haze: a warm band hugging the horizon, strongest toward the sun's azimuth.
	float toward = max(dot(normalize(vec3(d.x, 0.0, d.z) + 1e-5), normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 1e-5)), 0.0);
	float band = exp(-abs(d.y) * 7.0);
	col += haze_color * haze * band * (0.25 + 0.75 * pow(toward, 3.0)) * 0.55;
	// Mie glow around the sun.
	float sd = max(dot(d, sun_dir), 0.0);
	col += sun_color * sun_visible * (pow(sd, 48.0) * 0.6 + pow(sd, 6.0) * 0.12) * above;

	// Stars (not in the radiance cubemap).
	if (!AT_CUBEMAP_PASS && stars > 0.001 && d.y > 0.0) {
		vec3 g = d * 220.0;
		vec3 cell = floor(g);
		float h = h31(cell);
		if (h > 0.9965) {
			vec3 cp = cell + 0.5 + (vec3(h31(cell + 1.3), h31(cell + 2.7), h31(cell + 4.1)) - 0.5) * 0.6;
			float r = length(g - cp);
			float s = smoothstep(0.45, 0.0, r) * (0.4 + 1.6 * fract(h * 911.0));
			vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), fract(h * 37.0));
			col += tint * s * stars * smoothstep(0.02, 0.25, d.y) * (1.0 - cloud_cover);
		}
	}

	// Moon: disc with a phase terminator and a soft halo.
	if (moon_visible > 0.001) {
		float md = dot(d, moon_dir);
		float ang = acos(clamp(md, -1.0, 1.0));
		col += moon_color * moon_visible * pow(max(md, 0.0), 220.0) * 0.18 * above;
		if (ang < moon_size) {
			vec3 up = abs(moon_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
			vec3 mx = normalize(cross(up, moon_dir));
			vec3 my = cross(moon_dir, mx);
			vec2 uv = vec2(dot(d, mx), dot(d, my)) / sin(moon_size);
			float z = sqrt(max(1.0 - dot(uv, uv), 0.0));
			float ph = moon_phase * 2.0 * PI;
			vec3 ldir = vec3(sin(ph), 0.0, -cos(ph));
			float lit = smoothstep(-0.08, 0.12, dot(vec3(uv, z), ldir));
			float mare = 0.82 + 0.18 * vnoise(uv * 3.5 + 7.0);
			float edge = smoothstep(moon_size, moon_size * 0.9, ang);
			col = mix(col, moon_color * (0.05 + 2.4 * lit * mare), edge * moon_visible * above);
		}
	}

	// Sun disc.
	float sang = acos(clamp(dot(d, sun_dir), -1.0, 1.0));
	col += sun_color * sun_disc_energy * sun_visible * smoothstep(sun_size, sun_size * 0.7, sang) * above;

	// Clouds on a flat layer above the camera.
	if (d.y > 0.0) {
		vec2 p = d.xz / max(d.y, 0.06) * 0.55 + cloud_offset;
		float n = fbm(p);
		float cover = mix(cloud_base, 1.02, clamp(cloud_cover, 0.0, 1.0));
		float dens = smoothstep(1.0 - cover, 1.0 - cover + 0.32, n) * smoothstep(0.0, 0.18, d.y);
		float lit = 0.75 + 0.25 * vnoise(p * 2.0 + 3.0);
		float silver = pow(max(dot(d, sun_dir), 0.0), 5.0) * sun_visible;
		vec3 cl = mix(horizon_color, vec3(1.0), 0.55) * (0.35 + 0.65 * day) * lit;
		cl += sun_color * silver * 0.5;
		cl = mix(cl, vec3(lum(cl)) * vec3(0.92, 0.94, 1.0), cloud_cover * 0.7);
		cl *= mix(1.0, 0.55, cloud_cover * smoothstep(0.4, 0.9, n));
		col = mix(col, cl, dens * (0.55 + 0.4 * cloud_cover));
	}
	// Overcast: the whole dome greys out and dims.
	float gray = lum(col);
	col = mix(col, vec3(gray) * vec3(0.9, 0.93, 1.0) * 0.82, clamp(cloud_cover, 0.0, 1.0) * 0.75);
	// Lightning lights the cloud deck from inside.
	col += vec3(0.75, 0.8, 1.0) * lightning_flash * (1.4 + 1.6 * clamp(cloud_cover, 0.0, 1.0)) * above;
	if (AT_CUBEMAP_PASS) {
		col = mix(col, vec3(lum(col)) * ambient_tint, clamp(ambient_neutral, 0.0, 1.0));
	}
	COLOR = col * energy;
}
