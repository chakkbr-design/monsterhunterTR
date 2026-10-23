shader_type spatial;
// HD-2D look for Kenney props (never buildings): base colour (or the model's colormap),
// world-space pixel noise so flat faces read like a pixel-art texture, palette quantise,
// and soft-banded diffuse that still receives shadows. Foliage sways on the shared wind.
render_mode specular_disabled;
#include "res://world/shaders/weather_common.gdshaderinc"

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_gust;
global uniform float wind_time;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float texel_per_m = 16.0;
uniform float noise_amount = 0.1;
uniform float levels = 24.0;
uniform float bands = 3.0;
uniform float band_soft = 0.15;
uniform bool is_foliage = false;
uniform float sway = 0.03;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	if (is_foliage) {
		vec3 o = MODEL_MATRIX[3].xyz;
		vec2 wd = normalize(wind_dir);
		float h = max(VERTEX.y - 0.3, 0.0);
		float ph = wind_time * 1.4 + dot(o.xz, wd) * 0.5 + o.x * 0.2;
		float amp = sway * h * (wind_strength + wind_gust);
		VERTEX.xz += wd * amp * (sin(ph) + 0.3 * sin(ph * 2.1));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	vec3 an = abs(world_normal);
	bool top = an.y > max(an.x, an.z);
	vec2 p = top ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
	float axis = top ? 1.0 : (an.x > an.z ? 2.0 : 3.0);
	base *= 1.0 + (hash(vec3(floor(p * texel_per_m), axis)) - 0.5) * 2.0 * noise_amount;
	base = floor(base * levels + 0.5) / levels;
	ALBEDO = base;
	EMISSION = emission_color.rgb * emission_energy;
	ROUGHNESS = 1.0;
	vec4 w = weather_at(world_pos);
	// D77: trees/bushes keep only a light cap on the TOP of the crown (0.4 max), so they read
	// snow-capped, not as pale beige blobs.
	weather_surface(ALBEDO, ROUGHNESS, smoothstep(0.7, 0.95, world_normal.y), w, 0.4);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float x = ndl * bands;
	float stepped = (floor(x) + smoothstep(1.0 - band_soft, 1.0, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR * stepped / PI;  // LIGHT_COLOR includes energy × PI
}
