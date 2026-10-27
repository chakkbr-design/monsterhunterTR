shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Malhas de efeito (Fx3D): fita (raio, corte, rastro), anel no chão, casca (esfera/cilindro) e feixe.
// Cor = tint * COLOR do vértice. phase anda com o tempo da luta (Fx3D.tick), nunca com TIME.
uniform int mode = 0; // 0 fita, 1 anel, 2 casca, 3 feixe, 4 rachadura
uniform float boost = 2.0;
uniform float noise_k = 0.0; // quanto o ruído quebra a forma
uniform float soft = 1.0; // dureza da borda
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float phase = 0.0;
instance uniform float fade = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 c = tint * COLOR;
	float a = 0.0;
	vec3 rgb = c.rgb;
	if (mode == 0) {
		float d = abs(UV.y * 2.0 - 1.0);
		float core = pow(clamp(1.0 - d, 0.0, 1.0), 1.5 * soft);
		a = core;
		rgb = mix(rgb, vec3(1.0), pow(core, 4.0) * 0.8);
	} else if (mode == 1) {
		float d = abs(UV.y * 2.0 - 1.0);
		a = pow(clamp(1.0 - d, 0.0, 1.0), soft);
		if (noise_k > 0.0) {
			float n = vnoise(vec2(UV.x * 40.0, UV.y * 3.0 + phase * 2.0));
			a *= clamp(1.0 - noise_k + n * noise_k * 1.6, 0.0, 1.0);
		}
		rgb = mix(rgb, vec3(1.0), pow(a, 3.0) * 0.5);
	} else if (mode == 2) {
		float fr = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
		a = pow(fr, 2.0 * soft) + 0.08;
		if (noise_k > 0.0) {
			float n = vnoise(vec2(UV.x * 18.0 + phase, UV.y * 10.0 - phase * 1.7));
			a *= clamp(1.0 - noise_k + n * noise_k * 1.5, 0.0, 1.0);
		}
		rgb = mix(rgb, vec3(1.0), pow(fr, 6.0) * 0.4);
	} else if (mode == 3) {
		float fr = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
		float core = pow(fr, 1.2 * soft);
		float n = vnoise(vec2(UV.x * 6.0, UV.y * 30.0 - phase * 12.0));
		a = core * (0.65 + n * 0.55 * max(noise_k, 0.4));
		rgb = mix(rgb, vec3(1.0), pow(core, 3.0) * 0.75);
		float ends = smoothstep(0.0, 0.03, UV.y) * smoothstep(1.0, 0.94, UV.y);
		a *= ends;
	} else if (mode == 4) {
		float d = abs(UV.y * 2.0 - 1.0);
		a = pow(clamp(1.0 - d, 0.0, 1.0), 2.0);
		rgb = mix(rgb, vec3(1.0, 0.95, 0.8), pow(a, 4.0) * 0.6);
	}
	ALBEDO = rgb * boost;
	ALPHA = clamp(a * c.a * fade, 0.0, 1.0);
}
