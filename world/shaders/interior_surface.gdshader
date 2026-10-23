shader_type spatial;
// Interior room surfaces (floor, walls, skirting) in the HD-2D language: the texture is tiled
// in world space (nearest), pixel-quantised, with a little large-scale tint noise so big flat
// planes don't look dead, and the same 3-band soft diffuse the props use. Replaces the plain
// StandardMaterial3D in scripts/room.gd.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tiles_per_meter = 0.5;
uniform float levels = 24.0;
uniform float noise_amount = 0.05;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(world_normal);
	vec3 c = vec3(1.0);
	if (use_tex) {
		if (an.y > max(an.x, an.z)) {
			c = texture(albedo_tex, world_pos.xz * tiles_per_meter).rgb;
		} else if (an.x > an.z) {
			c = texture(albedo_tex, world_pos.zy * tiles_per_meter).rgb;
		} else {
			c = texture(albedo_tex, world_pos.xy * tiles_per_meter).rgb;
		}
	}
	c *= tint.rgb;
	c *= 1.0 + (hash(floor(world_pos * 4.0)) - 0.5) * 2.0 * noise_amount;
	ALBEDO = floor(c * levels + 0.5) / levels;
	ROUGHNESS = 1.0;
}
// No custom light(): Godot only applies a light's projector (cookie) through the built-in
// lighting path, and the room surfaces must receive the window cookie. The 3-band toon look
// stays on the props (shaders/prop_stylize.gdshader).
