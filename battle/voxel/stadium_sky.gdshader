shader_type sky;
// Sky of the training stadium (ArenaStadium moods: day, sunset, night and the scenario overrides):
// gradient from the horizon to the zenith, a warm glow around the sun, a pixel sun / moon disc,
// stars at night and slow blocky clouds (quantised to a coarse grid, to match the voxel look).

uniform vec3 top_color : source_color = vec3(0.3, 0.52, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.92);
uniform vec3 ground_color : source_color = vec3(0.32, 0.36, 0.3);
uniform vec3 glow_color : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 disc_color : source_color = vec3(1.0, 0.96, 0.86);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.76, 0.84);
uniform float disc_size = 0.035;  // rad
uniform float disc_energy = 6.0;
uniform float glow = 0.35;
uniform float stars = 0.0;
uniform float clouds = 0.45;
uniform float cloud_speed = 0.004;
uniform vec3 sun_dir = vec3(0.3, 0.7, 0.6);  // towards the sun or the moon

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	vec3 s = normalize(sun_dir);
	float sd = dot(d, s);
	col += glow_color * glow * pow(max(sd, 0.0), 8.0) * (0.4 + 0.6 * clamp(1.0 - h * 2.0, 0.0, 1.0));
	if (!AT_CUBEMAP_PASS && !AT_HALF_RES_PASS && !AT_QUARTER_RES_PASS) {
		// Pixel disc: the angle to the sun on a coarse grid.
		vec2 q = floor(vec2(atan(d.x, d.z), asin(clamp(h, -1.0, 1.0))) / 0.006) * 0.006;
		vec3 dq = vec3(sin(q.x) * cos(q.y), sin(q.y), cos(q.x) * cos(q.y));
		float a = acos(clamp(dot(dq, s), -1.0, 1.0));
		col = mix(col, disc_color * disc_energy, step(a, disc_size));
	}
	if (stars > 0.0 && h > 0.0) {
		vec2 g = floor(vec2(atan(d.x, d.z) * 180.0, h * 180.0));
		float r = h21(g);
		float tw = 0.7 + 0.3 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
		col += vec3(0.9, 0.95, 1.0) * step(0.9975, r) * stars * tw * smoothstep(0.0, 0.25, h);
	}
	if (clouds > 0.0 && h > 0.02) {
		vec2 p = d.xz / (h + 0.08) * 2.2 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		p = floor(p * 6.0) / 6.0;
		float n = vnoise(p) * 0.62 + vnoise(p * 2.3 + 5.1) * 0.38;
		float c = smoothstep(1.0 - clouds * 0.62, 1.04 - clouds * 0.62, n);
		float lit = smoothstep(0.0, 1.0, vnoise(p * 2.3 + 5.1));
		vec3 cc = mix(cloud_shade, cloud_color, lit);
		col = mix(col, cc, c * smoothstep(0.02, 0.18, h) * 0.92);
	}
	COLOR = col;
}
