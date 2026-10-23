shader_type spatial;
// Earth cliff walls (HD-2D terrain): warm eroded earth with vertical streaks and soft ochre
// bands, darker toward the foot and right under the grassy lip. COLOR.r = height fraction
// (1 top, 0 foot) and UV = (metres along the wall, world y), both from CliffWall.build.
render_mode specular_disabled;
#include "res://world/shaders/weather_common.gdshaderinc"

uniform vec3 earth_light : source_color = vec3(0.70, 0.47, 0.30);
uniform vec3 earth_dark : source_color = vec3(0.42, 0.26, 0.17);
uniform vec3 ochre : source_color = vec3(0.80, 0.60, 0.38);
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float tex_scale = 0.5;
uniform float levels = 24.0;
uniform float bands = 3.0;
uniform float band_soft = 0.2;

varying float hfrac;
varying vec3 world_pos;
varying vec3 world_normal;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	hfrac = COLOR.r;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 cell = floor(UV * 16.0);
	vec2 px = cell / 16.0;
	float streak = vnoise(vec2(px.x * 3.0, px.y * 0.35));
	float lumps = vnoise(px * 1.3 + 7.0);
	float band = smoothstep(0.55, 0.75, vnoise(vec2(px.x * 0.2, px.y * 2.2) + 3.0));
	vec3 c = mix(earth_dark, earth_light, clamp(streak * 0.6 + lumps * 0.4, 0.0, 1.0));
	c = mix(c, ochre, band * 0.35);
	if (use_tex) {
		c *= texture(albedo_tex, UV * tex_scale).rgb * 1.6;
	}
	c *= mix(0.55, 1.0, smoothstep(0.0, 0.45, hfrac));
	c *= mix(0.7, 1.0, smoothstep(0.0, 0.08, 1.0 - hfrac));
	c *= 0.94 + h21(cell) * 0.1;
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
