shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Decor at the detail scale (VoxelMesher.colored: flowers, pebbles, crops, tufts). Vertex colour is
// sRGB, COLOR.a is the baked voxel AO. Plants sway with the wind globals by height above their base
// (MultiMesh instances get a phase from INSTANCE_CUSTOM.r when custom data is on).

uniform float sway = 0.0;  // metres of tip travel per metre of height squared
uniform float voxel = 0.0625;
uniform float edge_light = 0.08;
uniform float weather = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float backlight = 0.0;
// > 0: a floor of sky light (x the horizon colour) on every face. In the shade only the indirect
// light reaches, and SDFGI gives the sides of thin blades next to nothing (black tufts).
// 0 (default): the arenas' look.
uniform float shade_lift = 0.0;

global uniform float rain_wet;
global uniform float snow_cover;
global uniform float wind_time;
global uniform vec2 wind_dir;
global uniform float wind_gust;
global uniform vec4 sky_horizon_color;
global uniform float gi_sky_floor;  // the world's floor while SDFGI runs (voxel.gdshader)

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	if (sway > 0.0) {
		vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float ph = wind_time * 2.1 + dot(o.xz, vec2(0.71, 0.53)) + INSTANCE_CUSTOM.r * 6.2831;
		float s = (sin(ph) * 0.7 + sin(ph * 2.7) * 0.2 + wind_gust) * sway * h * h;
		vec3 d = inverse(mat3(MODEL_MATRIX)) * vec3(wind_dir.x, 0.0, wind_dir.y);
		VERTEX += d * s;
	}
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 col = to_linear(COLOR.rgb) * tint.rgb;
	vec3 g = lpos / voxel;
	vec3 n = normalize(lnrm);
	vec2 f = abs(n.x) > 0.5 ? fract(g.yz) : (abs(n.y) > 0.5 ? fract(g.xz) : fract(g.xy));
	float ed = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col *= 1.0 + edge_light * (1.0 - smoothstep(0.0, 0.12, ed));
	vec3 wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float up = smoothstep(0.6, 0.9, wn.y) * weather;
	// Snow on the tops, with a per-voxel grain (not one flat white).
	vec3 vc = floor(g - n * 0.5);
	float grain = 0.88 + 0.12 * fract(sin(dot(vc, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	col = mix(col, vec3(0.86, 0.9, 0.96) * grain, up * smoothstep(0.1, 0.6, snow_cover));
	col *= mix(1.0, 0.7, rain_wet * weather);
	ALBEDO = col;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = mix(0.85, 0.3, rain_wet * weather);
	SPECULAR = 0.3;
	if (backlight > 0.0) {
		BACKLIGHT = col * backlight;
	}
	float lift = max(shade_lift, gi_sky_floor);
	if (lift > 0.0) {
		EMISSION = to_linear(sky_horizon_color.rgb) * col * lift;
	}
}
