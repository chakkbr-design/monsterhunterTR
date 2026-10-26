shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Cloth of the training stadium (flags on the parapet and the corner masts, banners): a quad mesh
// with the pole along local x = 0 and the cloth along +x (`span` m), waving with the wind globals.
// The displacement is snapped to the 1/16 m detail grid so the cloth folds in voxel steps.
// `hang` = 1 for a banner hanging from its top edge (the wave runs down local -y instead).

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform float span = 1.6;
uniform float amp = 0.16;
uniform float hang = 0.0;
uniform float step_m = 0.0625;
uniform float phase = 0.0;
uniform float emission = 0.0;

global uniform float wind_time;
global uniform float wind_gust;
global uniform float wind_strength;

void vertex() {
	float u = hang > 0.5 ? clamp(-VERTEX.y / span, 0.0, 1.0) : clamp(VERTEX.x / span, 0.0, 1.0);
	float w = (0.55 + 0.6 * wind_gust) * max(wind_strength, 0.2);
	float along = hang > 0.5 ? VERTEX.x * 2.0 : -VERTEX.x * 4.0;
	float ph = wind_time * (hang > 0.5 ? 2.2 : 6.5) + along + phase;
	float k = hang > 0.5 ? 0.35 + 0.65 * u : u;
	float dz = sin(ph) * amp * k * w + sin(ph * 2.3 + 1.1) * amp * 0.3 * k * w;
	dz = round(dz / step_m) * step_m;
	VERTEX.z += dz;
	if (hang < 0.5) {
		VERTEX.y -= (1.0 - min(w, 1.0)) * 0.2 * u * u;
	}
	float slope = cos(ph) * amp * k * w * (hang > 0.5 ? 2.0 : -4.0);
	NORMAL = normalize(vec3(-slope, 0.0, 1.0));
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = t.rgb * 0.4;
	EMISSION = t.rgb * emission;
}
