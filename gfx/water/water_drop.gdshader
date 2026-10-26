shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// Fountain particles (FountainFx): jet streaks (quads the particle system aligns to the velocity),
// splash droplets and mist puffs (billboarded here, keeping the particle's scale and spin). Lit, so
// the sun sparkles on them and the basin's underwater light colours them at night. Mist is a soft
// particle: it fades where it meets the scene (depth texture) instead of cutting into it.

uniform bool billboard = false;
uniform bool soft = false;  // round soft puff (mist) instead of a streak / droplet
uniform vec4 color : source_color = vec4(0.86, 0.95, 1.0, 0.65);
uniform float fade_distance = 0.6;  // soft particles: metres to fade in front of the scene
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

global uniform vec4 sky_horizon_color;
global uniform float lightning_flash;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	if (billboard) {
		mat4 mw = mat4(
			normalize(INV_VIEW_MATRIX[0]),
			normalize(INV_VIEW_MATRIX[1]),
			normalize(INV_VIEW_MATRIX[2]),
			MODEL_MATRIX[3]
		);
		float sc = length(MODEL_MATRIX[0].xyz);
		float spin = INSTANCE_CUSTOM.x;
		mat4 r = mat4(
			vec4(cos(spin) * sc, -sin(spin) * sc, 0.0, 0.0),
			vec4(sin(spin) * sc, cos(spin) * sc, 0.0, 0.0),
			vec4(0.0, 0.0, sc, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0)
		);
		MODELVIEW_MATRIX = VIEW_MATRIX * mw * r;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float a;
	if (soft) {
		a = 1.0 - smoothstep(0.0, 1.0, length(c));
		a *= a;
		float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, max(d, 1e-7), 1.0);
		float scene = -v.z / v.w;
		a *= clamp((scene + VERTEX.z) / fade_distance, 0.0, 1.0);
	} else {
		a = (1.0 - smoothstep(0.35, 1.0, abs(c.x))) * (1.0 - smoothstep(0.25, 1.0, abs(c.y)));
	}
	ALPHA = clamp(a * color.a * COLOR.a, 0.0, 1.0);
	ALBEDO = color.rgb * COLOR.rgb;
	EMISSION = to_linear(sky_horizon_color.rgb) * ALBEDO * (0.12 + lightning_flash * 0.8);
	ROUGHNESS = soft ? 0.9 : 0.12;
	SPECULAR = soft ? 0.1 : 0.55;
}
