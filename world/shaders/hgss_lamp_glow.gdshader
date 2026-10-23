shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// The DS lamp models bake a glow card over the head: two mirrored quads, each mapping the whole
// `lamp_tkwa_sl3.png` / `lamp_nibi_sl3.png` (a yellow shape with a flat 0.66 alpha over most of
// it). The glTF import marks it alphaMode MASK, so at scissor 0.5 it cut to a hard-edged, sun-lit
// yellow pane. Here the art supplies only the colour and the falloff is ours, so it reads as the
// soft halo the DS sprite meant — and no rectangle, which the texture alpha would have kept.
//
// See Props._is_glow_card.

uniform sampler2D glow_tex : source_color, filter_nearest, repeat_disable;
// The one knob. Push up for a hotter bulb, down if the halo washes out what is behind it.
uniform float glow_alpha : hint_range(0.0, 2.0) = 0.35;  // Props.GLOW_ALPHA sets this
// The card's own vertical centre in the model: the halo is a disc around the bulb. Both HGSS
// street lamps share this geometry (quads at x ±1, y 2.009…3.741); a lamp with a different head
// height needs this as a uniform.
uniform float head_y = 2.875;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 c = texture(glow_tex, UV).rgb;
	// x is the model's own axis, so the two mirrored quads share one disc centred on the post
	// instead of a lobe each. The y radius is squashed by the card's shallower extent.
	float d = length(vec2(local_pos.x, (local_pos.y - head_y) * 1.15));
	ALBEDO = c * glow_alpha * smoothstep(1.0, 0.0, d);
	ALPHA = 1.0;
}
