// Partícula de efeito (Fx3DParticles): quadrado virado para a câmera feito no vertex shader.
// Instância: origem = posição, escala = tamanho (m); INSTANCE_CUSTOM = velocidade no mundo (xyz) e giro (w).
// COLOR = cor da instância (alfa já com o fade).
uniform int shape = 0; // 0 brilho, 1 faísca, 2 estrela, 3 anel, 4 fumaça, 5 textura, 6 brasa, 7 bolha
uniform float stretch = 0.0; // s de borrão de movimento (estica na velocidade)
uniform float boost = 2.0; // brilho acima de 1 para o glow do Environment
uniform sampler2D tex : source_color, filter_nearest, hint_default_white;

varying float v_seed;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 vel_v = (VIEW_MATRIX * vec4(INSTANCE_CUSTOM.xyz, 0.0)).xyz;
	float rot = INSTANCE_CUSTOM.w;
	vec2 q = VERTEX.xy * size;
	vec2 ax = vec2(cos(rot), sin(rot));
	vec2 ay = vec2(-ax.y, ax.x);
	if (stretch > 0.0) {
		float sp = length(vel_v.xy);
		if (sp > 0.001) {
			ay = vel_v.xy / sp;
			ax = vec2(ay.y, -ay.x);
			q.y *= 1.0 + sp * stretch / max(size, 0.01);
		}
	}
	VERTEX = center + vec3(ax * q.x + ay * q.y, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_seed = fract(float(INSTANCE_ID) * 0.6180339);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 particle_color(vec2 uv, vec4 col) {
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float a = 0.0;
	vec3 rgb = col.rgb;
	if (shape == 0) {
		a = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
		rgb = mix(rgb, vec3(1.0), pow(clamp(1.0 - r * 1.8, 0.0, 1.0), 3.0) * 0.6);
	} else if (shape == 1) {
		float w = clamp(1.0 - abs(p.x) * 3.0, 0.0, 1.0);
		float h = clamp(1.0 - abs(p.y), 0.0, 1.0);
		a = w * w * h;
		rgb = mix(rgb, vec3(1.0), w * w * w * h * 0.7);
	} else if (shape == 2) {
		float cr = max(clamp(1.0 - abs(p.x) * 9.0, 0.0, 1.0) * (1.0 - abs(p.y)),
				clamp(1.0 - abs(p.y) * 9.0, 0.0, 1.0) * (1.0 - abs(p.x)));
		float g = pow(clamp(1.0 - r * 1.6, 0.0, 1.0), 2.0);
		a = clamp(cr * cr + g, 0.0, 1.0);
		rgb = mix(rgb, vec3(1.0), clamp(cr * cr * 0.8 + g * g, 0.0, 1.0));
	} else if (shape == 3) {
		a = clamp(1.0 - abs(r - 0.78) * 7.0, 0.0, 1.0);
		a *= a;
	} else if (shape == 4) {
		float n = vnoise(p * 2.3 + v_seed * 17.0) * 0.6 + vnoise(p * 5.1 - v_seed * 9.0) * 0.4;
		a = clamp((1.0 - r) * 1.6 - (1.0 - n) * 0.9, 0.0, 1.0);
		rgb *= 0.75 + n * 0.45;
	} else if (shape == 5) {
		vec4 t = texture(tex, uv);
		a = t.a;
		rgb *= t.rgb;
	} else if (shape == 6) {
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.4);
		rgb = mix(rgb, vec3(1.0, 1.0, 0.85), pow(clamp(1.0 - r * 2.2, 0.0, 1.0), 2.0));
	} else if (shape == 7) {
		float rim = clamp(1.0 - abs(r - 0.82) * 6.0, 0.0, 1.0);
		float hl = clamp(1.0 - length(p - vec2(-0.35, 0.35)) * 4.0, 0.0, 1.0);
		a = clamp(rim * 0.9 + hl + (1.0 - r) * 0.12, 0.0, 1.0) * step(r, 1.0);
		rgb = mix(rgb, vec3(1.0), hl);
	}
	return vec4(rgb, a * col.a);
}
