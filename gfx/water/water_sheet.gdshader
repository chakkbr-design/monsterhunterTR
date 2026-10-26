shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// Falling water sheet (FountainFx: tier overflows, cascades). UV.x runs across the ribbon, UV.y down
// the fall. The pattern rides the water: a point fallen `v` metres left the lip tau(v) seconds ago
// (v = v0 * tau + g * tau^2 / 2), so streaks stretch and speed up as they drop. Streaks are drawn
// on the 1/16 m detail grid like the rest of the voxel world; the lip stays glassy, the foot foams.

uniform vec4 color : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float opacity = 0.62;
uniform float length_m = 1.0;  // ribbon length along the fall (m)
uniform float width_m = 0.4;  // ribbon width (m)
uniform float drop_m = 1.0;  // vertical drop (m)
uniform float lip_speed = 0.45;  // m/s when leaving the lip
uniform float pixel = 0.0625;
uniform float seed = 0.0;

global uniform vec4 sky_horizon_color;
global uniform vec4 sky_top_color;
global uniform float lightning_flash;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float t = TIME;
	vec2 m = vec2(UV.x * width_m, UV.y * length_m);
	if (pixel > 0.0) {
		m = (floor(m / vec2(pixel, pixel * 0.5)) + 0.5) * vec2(pixel, pixel * 0.5);
	}
	float s = clamp(m.y / max(length_m, 1e-3), 0.0, 1.0);
	float v = s * s * drop_m;  // metres fallen (the ribbon follows a parabola)
	float tau = (-lip_speed + sqrt(lip_speed * lip_speed + 19.6 * v)) / 9.8;
	float ph = (tau - t) * 4.0;
	float streak = vnoise(vec2(m.x * 22.0 + seed, ph * 1.6)) * 0.65 + vnoise(vec2(m.x * 47.0 - seed, ph * 3.5)) * 0.35;
	float gaps = smoothstep(0.18, 0.4, vnoise(vec2(m.x * 9.0 + 3.0 + seed, ph * 1.6)));
	// Ragged side edges and the glassy lip.
	float side = min(m.x, width_m - m.x);
	float rag = 0.02 + 0.05 * vnoise(vec2(m.y * 8.0 - t * 3.0, seed));
	float edge = smoothstep(0.0, rag, side);
	float foot = smoothstep(0.72, 1.0, s);
	float a = opacity * (0.45 + 0.55 * streak) * mix(1.0, gaps, smoothstep(0.15, 0.6, s)) * edge;
	a = max(a, foot * edge * smoothstep(0.35, 0.65, streak) * 0.9);
	a *= smoothstep(0.0, 0.04, s + 0.02);
	vec3 white = vec3(0.92, 0.96, 1.0);
	vec3 col = mix(color.rgb, white, smoothstep(0.55, 0.85, streak) * (0.4 + 0.6 * s));
	col = mix(col, white, foot);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
	// A touch of sky on the glassy parts (fresnel-ish), flashes with lightning.
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 sky = mix(to_linear(sky_horizon_color.rgb), to_linear(sky_top_color.rgb), 0.5);
	EMISSION = sky * (0.06 + 0.25 * fr) * (1.0 + lightning_flash * 4.0);
	ROUGHNESS = mix(0.12, 0.45, foot);
	SPECULAR = 0.5;
}
