// Clima na tela (BattleWeatherFx): só um tom nas bordas, por cima do 3D e por baixo do HUD. Nada de
// véu no meio da tela (atrapalha a leitura): chuva escurece as bordas, areia dá tom marrom nas bordas,
// neve põe geada nas bordas, sol dá vinheta quente. Cada força vai de 0 a 1.
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
		over(col, a, vec3(0.95, 0.55, 0.2), sun * 0.12 * vig);
	}
	if (rain > 0.0) {
		over(col, a, vec3(0.1, 0.15, 0.24), rain * 0.25 * vig);
	}
	if (sand > 0.0) {
		over(col, a, vec3(0.62, 0.47, 0.28), sand * 0.22 * vig);
	}
	if (snow > 0.0) {
		float fr = smoothstep(0.6, 1.08, length(uv - 0.5) * 1.5 + (fbm(p * 9.0) - 0.5) * 0.3);
		over(col, a, vec3(0.87, 0.93, 1.0), snow * 0.4 * fr);
	}
	COLOR = vec4(col, a);
}
