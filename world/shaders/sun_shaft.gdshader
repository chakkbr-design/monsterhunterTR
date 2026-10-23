shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// D66 sun shaft. One shader for both the beam cards and the warm ground pool: additive and
// unshaded, so it only ever brightens what it covers (never a white plank, never a fog wall).
// The column falls from the canopy to the floor, fading at BOTH ends and its sides, so a
// character inside it stays readable. The pool is a warm disc broken up by leaf-dapple noise.
// The column's top shears along the ONE shared wind, as if the canopy moved.

uniform vec4 tint : source_color = vec4(1.0, 0.87, 0.58, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.2;
uniform float top_fade : hint_range(0.05, 1.0) = 0.5;    // fraction of the column that fades out at the canopy
uniform float bottom_fade : hint_range(0.02, 1.0) = 0.35;  // fraction that fades out at the floor
uniform float edge_soft : hint_range(0.05, 1.0) = 0.6;   // how soft the column's sides are
uniform float taper : hint_range(0.1, 1.0) = 0.7;        // column width at the canopy vs the ground
uniform float sway : hint_range(0.0, 3.0) = 0.7;         // metres the canopy drags the column top
uniform float dapple : hint_range(0.0, 1.0) = 0.4;       // leaf-dapple strength in the pool
uniform float seed = 0.0;
uniform bool ground_pool = false;

uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_gust = 0.0;
uniform float wind_strength = 1.0;

varying vec2 v_uv;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_uv = UV;
	if (!ground_pool) {
		VERTEX.x *= mix(taper, 1.0, UV.y);  // narrow toward the canopy (UV.y 0 = canopy, 1 = ground)
		float h = 1.0 - UV.y;              // 1 at the canopy, 0 at the ground
		float amp = sway * h * h * (0.3 * wind_strength + 0.7 * wind_gust);
		VERTEX.x += amp * wind_dir.x;
		VERTEX.z += amp * wind_dir.y;
	}
}

void fragment() {
	float a;
	if (ground_pool) {
		float d = length(v_uv - vec2(0.5)) * 2.0;
		a = smoothstep(1.0, 0.15, d);
		a *= 1.0 - dapple * (1.0 - vnoise(v_uv * 7.0 + vec2(seed * 13.0, seed * 7.0)));
	} else {
		float y = 1.0 - v_uv.y;                                          // 0 at the floor, 1 at the canopy
		a = smoothstep(1.0, 1.0 - top_fade, y);                          // fade into the canopy
		a *= smoothstep(0.0, bottom_fade, y);                            // soft falloff to the floor
		a *= smoothstep(1.0, 1.0 - edge_soft, abs(v_uv.x * 2.0 - 1.0));  // soft sides
	}
	ALBEDO = tint.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * strength;
}
