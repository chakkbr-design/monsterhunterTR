shader_type spatial;
// D90 firefly: a tiny additive point that blinks on its own phase. The phase is a hash of the
// particle's world position, so neighbours blink out of step without needing a particle shader.
// Godot 4.7 has no `billboard` render mode, so we billboard by hand in vertex().
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 body_color : source_color = vec3(0.72, 1.0, 0.35);
uniform vec3 glow_color : source_color = vec3(1.0, 0.95, 0.45);
uniform float blink_rate = 2.4;   // blinks per second
uniform float sharpness = 3.0;    // higher = crisper on/off
uniform sampler2D glow_tex : hint_default_white;  // round radial falloff

varying float v_blink;

void vertex() {
	// INSTANCE_CUSTOM carries the particle's rotation (x) and lifetime phase (y): a stable seed
	// per particle, so neighbours blink out of step.
	float seed = INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.y;
	v_blink = pow(max(0.0, sin(TIME * blink_rate + seed * 6.2831853)), sharpness);
	// Face the camera, keep the quad's size (no rotation/scale from the particle transform).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float b = v_blink * texture(glow_tex, UV).r;
	ALBEDO = body_color * b;
	EMISSION = glow_color * b * 2.8;
	ALPHA = b;
}
