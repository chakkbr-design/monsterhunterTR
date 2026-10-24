// Feixe de luz do sol forte (BattleWeatherFx): faixa vertical somada à cena, mais forte em cima,
// bordas suaves e um tremor lento. `strength` 0..1 e `phase` por feixe.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.0;
uniform float phase = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.85, 0.55);

void fragment() {
	float side = smoothstep(0.0, 0.5, UV.x) * smoothstep(1.0, 0.5, UV.x);
	float down = mix(1.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float flick = 0.7 + 0.3 * sin(TIME * 0.8 + phase) * sin(TIME * 0.33 + phase * 2.0);
	float streak = 0.75 + 0.25 * sin(UV.x * 18.0 + phase + TIME * 0.2);
	ALBEDO = tint;
	ALPHA = side * side * down * flick * streak * strength * 0.35;
}
