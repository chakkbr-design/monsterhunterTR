shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;
#include "res://gfx/fx3d/shaders/fx_particle.gdshaderinc"

void fragment() {
	vec4 c = particle_color(UV, COLOR);
	ALBEDO = c.rgb * boost;
	ALPHA = c.a;
}
