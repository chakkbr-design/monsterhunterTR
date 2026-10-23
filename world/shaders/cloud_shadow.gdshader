shader_type spatial;
// Cloud shadows: a large multiply-blended plane a little above the ground, drawn over everything
// (depth test off) so the same soft shade slides across grass, paths, buildings and characters
// together. Low-frequency noise scrolls along the shared wind (~1.5 m/s); ~30% coverage, ~18% darken.
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled;

global uniform vec2 wind_dir;
global uniform float wind_time;

uniform float cloud_scale = 0.018;
uniform float cloud_speed = 1.5;      // metres per second the clouds travel
uniform float coverage = 0.30;
uniform float darken = 0.18;

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wd = normalize(wind_dir);
	vec2 p = world_pos.xz * cloud_scale - wd * (wind_time * cloud_speed * cloud_scale);
	float n = noise(p) * 0.6 + noise(p * 2.3 + 11.0) * 0.3 + noise(p * 5.1 + 3.0) * 0.1;
	// Smoothstep centred so roughly `coverage` of the area is shaded, with soft edges.
	float cloud = smoothstep(0.5 - coverage * 0.5, 0.5 + coverage * 0.5, n);
	ALBEDO = vec3(1.0 - darken * cloud);
}
