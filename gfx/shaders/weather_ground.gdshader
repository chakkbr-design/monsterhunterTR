// Chão do clima por cima da quadra (BattleWeatherFx, quando não há o chão do mundo com clima):
// chuva = película molhada e brilhante com poças e anéis de gota; neve = manchas que crescem até
// cobrir tudo, com brilhinhos; areia = ondas de areia correndo com o vento. Bordas somem suaves.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform float wet = 0.0;
uniform float snow = 0.0;
uniform float sand = 0.0;

varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(5.3, 1.7);
		a *= 0.5;
	}
	return v;
}

float ripple(vec2 xz, float t) {
	vec2 cell = floor(xz * 1.6);
	vec2 f = fract(xz * 1.6) - 0.5;
	float ph = fract(t * 0.9 + hash(cell));
	float r = ph * 0.5;
	float ring = smoothstep(0.06, 0.0, abs(length(f) - r));
	return ring * (1.0 - ph) * step(0.35, hash(cell + 3.1));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = wp.xz;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.1, min(e.x, e.y));
	vec3 col = vec3(0.0);
	float a = 0.0;
	float rough = 1.0;
	vec3 emit = vec3(0.0);
	if (wet > 0.0) {
		float pud = smoothstep(0.52, 0.72, fbm(xz * 0.35));
		float rip = ripple(xz, TIME) * pud * wet;
		col = mix(vec3(0.04, 0.06, 0.09), vec3(0.3, 0.38, 0.48), pud * 0.35 + rip);
		a = wet * (0.3 + 0.4 * pud) + rip * 0.35;
		rough = mix(1.0, 0.05, wet * (0.45 + 0.55 * pud));
		emit += vec3(0.5, 0.6, 0.75) * rip * 0.5;
	}
	if (sand > 0.0) {
		float s = noise(vec2(xz.x * 0.7 - TIME * 0.9, xz.y * 2.6 + sin(xz.x * 0.4) * 0.8));
		float s2 = noise(xz * 6.0 + vec2(-TIME * 2.0, 0.0));
		vec3 sc = mix(vec3(0.62, 0.47, 0.28), vec3(0.9, 0.77, 0.52), s * 0.7 + s2 * 0.3);
		float sa = sand * (0.22 + 0.38 * s);
		col = mix(col, sc, sa / max(a + sa, 0.001));
		a = max(a, sa);
		rough = mix(rough, 1.0, sand);
	}
	if (snow > 0.0) {
		float base = fbm(xz * 0.4) * 0.8 + fbm(xz * 2.3 + 7.0) * 0.2;
		float lim = 1.05 - snow * 1.0;
		float cov = smoothstep(lim - 0.12, lim + 0.12, base);
		float shade = 0.9 + 0.1 * noise(xz * 7.0);
		vec3 sc = vec3(0.9, 0.94, 1.0) * shade;
		col = mix(col, sc, cov);
		a = max(a, cov * 0.88);
		rough = mix(rough, 0.75, cov);
		vec2 g = floor(xz * 28.0);
		float tw = step(0.992, hash(g)) * (0.5 + 0.5 * sin(TIME * 4.0 + hash(g + 1.0) * 6.28));
		emit += vec3(0.9, 0.95, 1.0) * tw * cov * 0.9;
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * edge;
	ROUGHNESS = rough;
	SPECULAR = 0.6;
	EMISSION = emit * edge;
}
