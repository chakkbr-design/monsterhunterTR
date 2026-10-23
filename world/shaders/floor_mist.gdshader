shader_type spatial;
// N04e Part B: drifting floor haze for the cave rooms. A slow scrolling fbm density map drawn
// unshaded, so the haze catches the lantern pools' colour without being lit itself. No new deps.
// N04k: raised off the floor and spread over two staggered layers (floor_mist.gd) so it reads at
// the ~35 deg cave camera instead of being edge-on and near-invisible. Kept wispy, not soup.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.50, 0.56, 0.68, 1.0);
uniform float density = 0.3;
uniform float speed = 0.012;
uniform float uv_scale = 0.5;
uniform vec2 half_size = vec2(20.0);
uniform float seed = 0.0;

varying vec3 local_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() { local_pos = VERTEX; }

void fragment() {
	vec2 uv = local_pos.xz * uv_scale + vec2(TIME * speed, TIME * speed * 0.6) + seed;
	float n = vnoise(uv) * 0.55 + vnoise(uv * 2.1) * 0.3 + vnoise(uv * 4.3) * 0.15;
	// Fade to nothing at every room edge so the plane has no hard border.
	vec2 e = abs(local_pos.xz) / half_size;
	float edge = smoothstep(1.0, 0.6, e.x) * smoothstep(1.0, 0.6, e.y);
	ALBEDO = tint.rgb;
	ALPHA = density * smoothstep(0.42, 0.95, n) * edge;
}
