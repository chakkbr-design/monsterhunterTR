shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Pixel-art crowd of the training stadium (ArenaCrowd with the overworld NPC sheets): one MultiMesh
// instance per fan, a quad (UV 0..1, origin on the seat pan, sunk below it) turned toward the camera
// around Y like CharSprite (BILLBOARD_FIXED_Y) and lit like it (shaded, alpha cut, nearest).
// atlas: one row per sheet, the 3 "down" frames (0 idle, 1 / 2 a foot forward); cells = (3, rows).
// INSTANCE_CUSTOM: r = sheet row * 2 + mirrored, g = brightness, b = phase (0..1),
// a = team (0 side A fans, 1 neutral, 2 side B fans) + liveliness (0..0.99).
// Same cheer / wave uniforms as crowd.gdshader (ArenaCrowd.set_param): cheering fans stand up and
// hop on the walk frames, the Mexican wave is a band of fans standing up around the bowl.

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 cells = vec2(3.0, 1.0);
uniform float cheer_a = 0.0;
uniform float cheer_b = 0.0;
uniform float idle = 1.0;
uniform float wave_tw = -1.0;  // seconds since the wave started (< 0: no wave)
uniform float wave_secs = 14.0;
uniform float wave_speed = 0.9;  // rad/s around the bowl
uniform float wave_a0 = 0.0;
uniform float wave_width = 0.28;  // rad

varying flat vec2 v_cell;
varying flat float v_flip;
varying flat float v_tint;

void vertex() {
	float ph = INSTANCE_CUSTOM.b * 6.2831853;
	float act = fract(INSTANCE_CUSTOM.a);
	float team = floor(INSTANCE_CUSTOM.a + 0.001);
	float ex = team < 0.5 ? cheer_a : (team > 1.5 ? cheer_b : 0.55 * max(cheer_a, cheer_b));
	ex = clamp(ex * (0.5 + 0.7 * act), 0.0, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	float wv = 0.0;
	float tw = wave_tw;
	if (tw >= 0.0 && tw < wave_secs) {
		float ang = atan(o.z, o.x);
		float d = mod(ang - wave_a0 - tw * wave_speed + 3.14159265, 6.2831853) - 3.14159265;
		wv = exp(-d * d / (wave_width * wave_width)) * smoothstep(0.0, 1.0, tw) * smoothstep(wave_secs, wave_secs - 1.5, tw);
	}
	float up = clamp(max(ex, wv), 0.0, 1.0);
	float stand = smoothstep(0.2, 0.8, up);
	float hop = ex * max(sin(TIME * (6.5 + 3.5 * act) + ph), 0.0) * 0.12;
	float bob = idle * sin(TIME * (1.1 + act) + ph * 2.0) * 0.012;
	// Frame: idle when seated; standing fans step on the walk frames (cheer faster than the wave).
	float col = 0.0;
	if (up > 0.45) {
		col = 1.0 + step(0.0, sin(TIME * (ex > 0.3 ? 7.0 + 3.0 * act : 3.0) + ph));
	}
	float code = floor(INSTANCE_CUSTOM.r + 0.5);
	v_cell = vec2(col, floor(code * 0.5));
	v_flip = mod(code, 2.0);
	v_tint = INSTANCE_CUSTOM.g > 0.0 ? INSTANCE_CUSTOM.g : 1.0;
	VERTEX.y += stand * 0.3 + hop + bob;
	// Y-axis billboard (as BaseMaterial3D BILLBOARD_FIXED_Y), keeping the instance scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, v_flip), UV.y);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec4 t = texture(atlas, (v_cell + uv) / cells);
	ALBEDO = t.rgb * v_tint;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.25;
}
