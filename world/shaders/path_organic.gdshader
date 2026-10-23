shader_type spatial;
// Organic dirt paths (HD-2D terrain): a per-level mask (PathMask) says where the road is; the
// dirt thins out through a blade-shaped noise threshold so grass seems to grow over its edge.
render_mode diffuse_lambert, specular_disabled;
#include "res://world/shaders/dirt.gdshaderinc"
#include "res://world/shaders/weather_common.gdshaderinc"

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec2 mask_origin;   // world (x, z) of the mask's first pixel corner
uniform vec2 mask_size;     // metres covered (x, z)
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float tex_scale = 0.5;
uniform vec3 path_tint : source_color = vec3(1.0, 1.0, 1.0);
// 0 = keep the dirt colour, 1 = use path_tint outright (Pewter's grey stone streets).
uniform float path_mix = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float m = texture(mask_tex, (world_pos.xz - mask_origin) / mask_size).r;
	// Blade tips: thin in x, long in z (the camera looks north) -> ragged grass over the edge.
	float blade = dirt_hash(floor(world_pos.xz * vec2(24.0, 8.0)));
	if (m < 0.25 + blade * 0.5) {
		discard;
	}
	vec3 c = mix(dirt_color(world_pos.xz), path_tint, path_mix);
	if (use_tex) {
		c *= texture(albedo_tex, world_pos.xz * tex_scale).rgb * 1.6;
	}
	ALBEDO = c * mix(0.85, 1.0, smoothstep(0.3, 0.8, m));
	ROUGHNESS = 1.0;
	vec4 w = weather_at(world_pos);
	weather_surface(ALBEDO, ROUGHNESS, 1.0, w, 1.0);
	SPECULAR = 0.2 * w.r;
	// D77 puddles on paths/dirt: darker than the wet path, a subtle capped sky fresnel (never
	// near white at the 32 deg camera) and ripple rings. The high specular picks up the sun by day
	// and lamps/windows at night.
	float pud = weather_puddle(world_pos.xz, w.r);
	if (pud > 0.0) {
		ALBEDO *= 1.0 - 0.6 * pud;
		ROUGHNESS = mix(ROUGHNESS, 0.06, pud);
		SPECULAR = mix(SPECULAR, 0.9, pud);
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		ALBEDO = mix(ALBEDO, vec3(0.16, 0.22, 0.32), pud * min(0.4, 0.10 + 0.30 * fres));
		float rip = weather_ripple(world_pos.xz, TIME) * pud;
		ALBEDO += vec3(0.30, 0.38, 0.50) * rip * 0.5;
		SPECULAR = max(SPECULAR, rip);
	}
}
