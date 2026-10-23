shader_type spatial;
// Pixel-art ground for the HD-2D overworld: the tiling texture is sampled in world
// space (nearest), then tinted by two layers of soft noise so large fields don't
// look flat (lighter meadows, darker damp patches).
render_mode diffuse_lambert;
#include "res://world/shaders/weather_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tiles_per_meter = 0.5;
uniform vec3 tint_a : source_color = vec3(1.0, 1.0, 0.92);
uniform vec3 tint_b : source_color = vec3(0.78, 0.9, 0.78);
uniform vec3 tint_c : source_color = vec3(1.06, 1.02, 0.8);
uniform float noise_scale = 0.045;
// Per-zone look: 0 = the green meadow, 1 = grey rock/stone ground (Pewter).
uniform float desaturate = 0.0;

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
	vec2 uv = world_pos.xz * tiles_per_meter;
	vec3 c = texture(albedo_tex, uv).rgb;
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), desaturate);
	float n1 = noise(world_pos.xz * noise_scale);
	float n2 = noise(world_pos.xz * noise_scale * 3.7 + 17.0);
	vec3 tint = mix(tint_b, tint_a, smoothstep(0.3, 0.7, n1));
	tint = mix(tint, tint_c, smoothstep(0.62, 0.85, n2) * 0.6);
	ALBEDO = c * tint;
	ROUGHNESS = 1.0;
	vec4 w = weather_at(world_pos);
	weather_surface(ALBEDO, ROUGHNESS, 1.0, w, 1.0);
	SPECULAR = 0.2 * w.r;
	// D77: the lawn gets only a faint darker wet patch — no mirror. Puddles belong on paths/dirt
	// (path_organic), not on grass terrain.
	float pud = weather_puddle(world_pos.xz, w.r);
	ALBEDO *= 1.0 - 0.18 * pud;
}
