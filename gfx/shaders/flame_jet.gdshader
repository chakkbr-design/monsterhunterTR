shader_type spatial;
// D106: the sheetless Flamethrower jet -- one straight camera-facing quad, white-hot -> yellow ->
// amber -> red along its length (the GBA reference look). The SHAPE is a union of overlapping
// round lobes whose radii grow from the mouth (dense + tiny there so they merge into a thin beam)
// toward the far end -- not a smooth cone, which read as a flashlight. Each lobe's size and offset
// is randomly seeded, so the silhouette changes every cast. A noise field darkens pockets inside
// the flame (soot/shadow) so it reads as a volume, not a flat gradient. `front` is the fraction
// reached so far; each lobe grows in as the front passes it (Moves gates damage on the same travel).
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float length_m = 6.0;   // quad length = the jet's reach (m)
uniform float half_h = 0.9;     // quad half-height (m); must fit the widest lobe
uniform float mouth_w = 0.26;   // beam width (m) at the mouth
uniform float tip_w = 1.4;      // widest lobe width (m) near the far end
uniform int lobes = 13;         // number of overlapping puffs
uniform float front = 1.0;      // 0..1: how far the flame has travelled
uniform float alpha_mul = 1.0;
uniform float dim = 1.0;         // <1 for the darker back layer that gives the jet depth
uniform float seed = 0.0;
uniform vec3 c_mouth : source_color = vec3(1.0, 1.0, 0.8);
uniform vec3 c_hot : source_color = vec3(1.0, 0.85, 0.25);
uniform vec3 c_mid : source_color = vec3(1.0, 0.45, 0.05);
uniform vec3 c_tip : source_color = vec3(0.7, 0.06, 0.02);

float hash1(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i.x + i.y * 57.0);
	float b = hash1(i.x + 1.0 + i.y * 57.0);
	float c = hash1(i.x + (i.y + 1.0) * 57.0);
	float d = hash1(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 ramp(float x) {
	vec3 col = mix(c_mouth, c_hot, smoothstep(0.0, 0.16, x));
	col = mix(col, c_mid, smoothstep(0.18, 0.42, x));
	return mix(col, c_tip, smoothstep(0.38, 0.68, x));
}

void fragment() {
	float x = UV.x * length_m;                 // metres along the jet
	float y = (UV.y - 0.5) * 2.0 * half_h;     // metres from the axis
	float t = clamp(UV.x, 0.0, 1.0);
	float r0 = mouth_w * 0.5;
	float r1 = tip_w * 0.5;
	float cover = 0.0;
	float ring = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= lobes) {
			break;
		}
		float fi = float(i);
		// Positions cluster near the mouth (pow < 1) so the tiny early lobes overlap into a beam;
		// past that they spread into distinct puffs.
		float ct = pow((fi + 0.5) / float(lobes), 1.35);
		float grow = smoothstep(0.03, 0.38, ct);
		float cap = mix(0.7, 1.0, 1.0 - smoothstep(0.88, 1.05, ct));
		// Random per-lobe size/offset, eased in with `grow` so the mouth beam stays a clean line
		// and only the grown puffs get the irregular silhouette.
		float r = mix(r0, r1, grow) * cap * (1.0 + (hash1(fi * 1.7) - 0.5) * 0.5);
		r *= clamp((front - ct) * 8.0, 0.0, 1.0);  // grow in as the travelling front passes
		float oy = (hash1(fi * 5.3) - 0.5) * 0.5 * r * grow;
		float ox = (hash1(fi * 7.9) - 0.5) * 0.3 * length_m / float(lobes) * grow;
		float cx = ct * length_m + ox;
		float d = distance(vec2(x, y), vec2(cx, oy));
		cover = max(cover, 1.0 - smoothstep(r * 0.82, r, d));
		ring = max(ring, 1.0 - smoothstep(r * 0.82, r * 1.35, d));
	}
	// A smooth tapered strip bridges the tiny mouth lobes into the reference's solid thin beam,
	// then hands off to the lobes once they are big enough to merge on their own.
	float beam_r = mix(r0, r1 * 0.36, smoothstep(0.0, 0.3, t));
	float beam = (1.0 - smoothstep(beam_r * 0.8, beam_r, abs(y))) * (1.0 - smoothstep(0.2, 0.42, t));
	cover = max(cover, beam);
	cover = clamp(cover, 0.0, 1.0);
	// Two-octave noise, drifting with time: dark pockets + hot streaks inside the flame, so the
	// gradient is broken up and the jet reads as a volume rather than a flat coloured cone.
	float n = 0.6 * vnoise(vec2(x * 2.4, y * 3.2 - TIME * 1.1))
		+ 0.4 * vnoise(vec2(x * 5.0 + 11.0, y * 6.0 - TIME * 2.0));
	// A thin white-hot centre line near the mouth (the beam core); the far end stays amber/red.
	float core = (1.0 - smoothstep(0.0, r0 * 1.8, abs(y))) * (1.0 - smoothstep(0.0, 0.32, t));
	// The far tip flickers: the leading edge wavers and the tip brightens/dims on its own clock.
	float tip = smoothstep(0.6, 1.0, t);
	float flick = vnoise(vec2(TIME * 7.0, seed * 3.0)) - 0.5;
	float head_pos = front + flick * 0.07 * tip;
	float head = 1.0 - smoothstep(head_pos - 0.02, head_pos + 0.02, t);
	// Each lobe's rim (ring outside the solid cover) goes dark red, so the puffs read as volumes.
	float rim = clamp(ring - cover, 0.0, 1.0);
	vec3 col = ramp(t);
	// Soot: multiply down into the dark pockets and nudge them red, lift the hot streaks.
	col *= mix(0.45, 1.25, n);
	col = mix(col, col * vec3(1.0, 0.4, 0.2), (1.0 - n) * 0.6);
	col = mix(col, col * vec3(0.85, 0.22, 0.12), rim * 0.8);
	// Distinct near-black soot blotches inside the flame body (not near the mouth beam).
	float soot = smoothstep(0.6, 0.88, n * 0.5 + 0.5)
		* smoothstep(0.16, 0.38, t) * smoothstep(0.0, 0.3, abs(y) / max(r1, 0.01));
	col = mix(col, vec3(0.1, 0.04, 0.03), soot * 0.6);
	// Volume: lit from above -- bright along the top of the jet, dark underside and a hot spine.
	float yy = clamp(y / max(r1, 0.01), -1.0, 1.0);
	float spine = 1.0 - smoothstep(0.0, 0.55, abs(yy));
	col *= 0.62 + 0.5 * smoothstep(-0.3, 1.0, yy);
	col = mix(col, col * vec3(0.78, 0.32, 0.18), smoothstep(0.0, -1.0, yy) * 0.5);
	col = mix(col, vec3(1.0, 0.95, 0.7), spine * 0.16);
	col *= 1.0 + 0.3 * flick * tip;  // the far tip breathes hotter/cooler
	col = mix(col, vec3(1.0, 1.0, 0.85), core);
	col *= dim;
	ALBEDO = col;
	// Darker pockets are slightly more opaque (solid soot), hot streaks a touch thinner.
	ALPHA = clamp((cover + core * 0.7) * head * alpha_mul * mix(1.0, 0.85, n), 0.0, 1.0);
}
