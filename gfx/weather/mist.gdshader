shader_type spatial;
// Ground mist (WeatherRig): a few stacked horizontal sheets below knee height. Slow patchy noise
// drifting with the wind, soft where a sheet meets the ground or a wall (depth fade, so it hugs the
// voxels instead of slicing them), thinner near the camera and toward the edge of the area. Lit by
// the scene, so it is pale grey by day, warm around lamps and dark at night. Caio's rule: never a
// veil over the action, so it stays low and light (WeatherRig caps the density).
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform float density = 0.0;  // 0..1 (WeatherRig)
uniform float layer = 0.0;  // 0 = lowest sheet .. 1 = highest (thinner, slower)
uniform float soft = 0.35;  // m of depth fade against the scene
uniform float radius = 24.0;  // fades out toward this distance from `center`
uniform vec3 center = vec3(0.0);
uniform vec3 tint : source_color = vec3(0.86, 0.88, 0.9);

global uniform vec2 wind_dir;
global uniform float wind_time;

varying vec3 wp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 wd = length(wind_dir) > 1e-4 ? normalize(wind_dir) : vec2(1.0, 0.0);
	vec2 drift = wd * wind_time * (0.22 - 0.08 * layer);
	vec2 p = (wp.xz - drift) * 0.14 + vec2(layer * 17.0, layer * 5.0);
	float n = fbm(p);
	n = smoothstep(0.42, 0.82, n + 0.12 * vnoise(wp.xz * 0.6 - drift * 2.0));  // patches, clear gaps
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, max(d, 1e-7), 1.0);
	sv.xyz /= sv.w;
	float thick = clamp((VERTEX.z - sv.z) / soft, 0.0, 1.0);
	float cam = smoothstep(3.0, 9.0, length(VERTEX));
	float edge = 1.0 - smoothstep(radius * 0.55, radius, length(wp.xz - center.xz));
	ALBEDO = tint;
	ALPHA = clamp(density * n * thick * cam * edge * (0.3 - 0.1 * layer), 0.0, 1.0);
}
