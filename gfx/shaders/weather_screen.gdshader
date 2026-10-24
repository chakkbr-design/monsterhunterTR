// Clima na tela (BattleWeatherFx): véu por cima do 3D e por baixo do HUD.
// Chuva: tom frio e escuro com vinheta; areia: névoa marrom em faixas que correm com o vento;
// neve: névoa clara e geada nas bordas; sol: vinheta quente. Cada força vai de 0 a 1.
shader_type canvas_item;
render_mode unshaded;

uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float sand = 0.0;
uniform float sun = 0.0;

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
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// Camada por cima (alpha "over") acumulada em col/a.
void over(inout vec3 col, inout float a, vec3 c, float k) {
	k = clamp(k, 0.0, 1.0);
	float na = k + a * (1.0 - k);
	if (na > 0.0001) {
		col = (c * k + col * a * (1.0 - k)) / na;
	}
	a = na;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float vig = smoothstep(0.3, 1.0, length(uv - 0.5) * 1.45);
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (sun > 0.0) {
		over(col, a, vec3(0.95, 0.55, 0.2), sun * (0.04 + 0.12 * vig));
	}
	if (rain > 0.0) {
		over(col, a, vec3(0.1, 0.15, 0.24), rain * (0.2 + 0.28 * vig));
	}
	if (sand > 0.0) {
		float n = fbm(vec2(p.x * 1.8 - TIME * 1.7, p.y * 4.5 + sin(p.x * 2.5 + TIME * 0.8) * 0.25));
		float n2 = fbm(vec2(p.x * 5.0 - TIME * 3.8, p.y * 12.0));
		vec3 sc = mix(vec3(0.58, 0.44, 0.27), vec3(0.88, 0.74, 0.5), n);
		over(col, a, sc, sand * (0.12 + 0.34 * n + 0.14 * n2 + 0.15 * vig));
	}
	if (snow > 0.0) {
		float fr = smoothstep(0.6, 1.08, length(uv - 0.5) * 1.5 + (fbm(p * 9.0) - 0.5) * 0.3);
		over(col, a, vec3(0.87, 0.93, 1.0), snow * (0.08 + 0.5 * fr));
	}
	COLOR = vec4(col, a);
}
