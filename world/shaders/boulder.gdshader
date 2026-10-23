shader_type spatial;
// Sandstone boulders for hop-down ledges (HD-2D terrain): warm ochre, darker toward the
// ground, world-space pixel noise, palette quantise, soft 3-band diffuse like the props.
render_mode specular_disabled;
#include "res://world/shaders/weather_common.gdshaderinc"

uniform vec3 stone_light : source_color = vec3(0.86, 0.64, 0.40);
uniform vec3 stone_dark : source_color = vec3(0.62, 0.42, 0.25);
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float tex_scale = 1.0;
uniform float levels = 24.0;
uniform float bands = 3.0;
uniform float band_soft = 0.25;

varying vec3 world_pos;
varying float local_h;
varying vec3 world_normal;

float h31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_h = VERTEX.y;
}

void fragment() {
	vec3 cell = floor(world_pos * 16.0);
	float n = h31(floor(world_pos * 3.0));
	vec3 c = mix(stone_dark, stone_light, 0.55 + 0.35 * n);
	if (use_tex) {
		c *= texture(albedo_tex, world_pos.xz * tex_scale + world_pos.y).rgb * 1.6;
	}
	c *= mix(0.6, 1.0, smoothstep(-0.45, 0.2, local_h));
	c *= 0.94 + h31(cell) * 0.1;
	ALBEDO = floor(c * levels + 0.5) / levels;
	ROUGHNESS = 1.0;
	vec4 w = weather_at(world_pos);
	weather_surface(ALBEDO, ROUGHNESS, smoothstep(0.55, 0.9, world_normal.y), w, 1.0);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float x = ndl * bands;
	float stepped = (floor(x) + smoothstep(1.0 - band_soft, 1.0, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR * stepped / PI;
}
