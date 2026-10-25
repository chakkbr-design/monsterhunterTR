// Luz do clima somada à tela (BattleWeatherFx): raios de sol saindo do canto de cima, brilho da
// fonte e o clarão do relâmpago na chuva.
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float sun = 0.0;
uniform float flash = 0.0;
uniform vec2 source = vec2(0.86, -0.18);

float hash1(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = vec2((uv.x - source.x) * aspect, uv.y - source.y);
	float r = length(d);
	float ang = atan(d.y, d.x);
	vec3 col = vec3(0.0);
	if (sun > 0.0) {
		float rays = noise1(ang * 13.0 + TIME * 0.07) * 0.6 + noise1(ang * 29.0 - TIME * 0.11) * 0.4;
		rays = pow(rays, 2.2) * (0.75 + 0.25 * sin(TIME * 0.9 + ang * 5.0));
		float fall = exp(-r * 1.1);
		float glow = exp(-r * 3.5);
		col += vec3(1.0, 0.85, 0.55) * (rays * fall * 0.25 + glow * 0.35) * sun;
	}
	if (flash > 0.0) {
		col += vec3(0.75, 0.82, 1.0) * flash * (0.45 + 0.25 * (1.0 - uv.y));
	}
	COLOR = vec4(col, 1.0);
}
