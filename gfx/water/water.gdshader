shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Placeholder water (docs/VOXEL.md, "Water"): see-through tint with moving ripples. The water work
// replaces it with refraction, depth absorption, foam, caustics and rain rings; keep the uniforms.

uniform vec2 flow = vec2(0.0);
uniform float depth_hint = 1.0;
uniform vec4 tint : source_color = vec4(0.12, 0.42, 0.5, 0.55);

global uniform float rain_amount;
global uniform float wind_time;

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz + flow * TIME;
	float w = sin(p.x * 3.1 + TIME * 1.3) * cos(p.y * 2.7 - TIME * 1.1);
	vec3 nm = normalize(vec3(w * 0.05, 1.0, w * 0.04));
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
}
