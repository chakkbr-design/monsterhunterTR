// A cloth flag on a pole (VoxelZone flags): a subdivided quad whose free end ripples in the
// breeze (UV.x = 0 at the pole, 1 at the fly end), painted from a small nearest-filtered pixel
// texture so it matches the voxel look. Back faces show the same cloth. The flag swings round its
// pole to fly downwind (wind_dir, like the grass and the trees), ripples harder and droops less as
// wind_strength and wind_gust rise, and flutters faster in a storm.
// hang = 1: laundry on a washing line instead (VoxelZone._laundry): the top edge (UV.y = 0) is
// pegged and the free bottom sways; transparent texels cut the garment's shape out. Laundry cannot
// turn, so the wind blowing across the line pushes the garments out and lifts their hems.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cloth : source_color, filter_nearest;
uniform float wave = 0.09;  // ripple amplitude at the free end (m)
uniform float speed = 4.5;
uniform float phase = 0.0;
uniform float hang = 0.0;
uniform float pole_x = -0.66;  // flag: the pole's x in the quad's space (it turns round it)

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_gust;

void vertex() {
	float u = mix(UV.x, UV.y, hang);
	float t = TIME * speed + phase;
	// 0 calm breeze .. 1 storm (wind_strength runs from 1 up to about 2.3, gusts past 1).
	float storm = clamp(wind_strength - 1.0, 0.0, 1.0);
	float blow = clamp(0.6 + 0.35 * wind_strength + 0.45 * wind_gust, 0.5, 2.2);
	float s = sin(u * 7.0 - t) + 0.35 * sin(u * 13.0 - t * 1.7 + UV.y * 2.0);
	s += storm * 0.45 * sin(u * 19.0 - t * 2.6 + UV.y * 3.0);
	// Laundry: mostly a slow whole-garment swing plus a little ripple.
	float sw = sin(t * 0.6 + UV.x * 1.5) * 1.4;
	s = mix(s, sw + 0.3 * s, hang);
	vec2 wo = (inverse(mat3(MODEL_MATRIX)) * vec3(wind_dir.x, 0.0, wind_dir.y)).xz;
	wo = length(wo) > 1e-4 ? normalize(wo) : vec2(1.0, 0.0);
	float amp = wave * blow;
	VERTEX.z += u * amp * s;
	float ds = cos(u * 7.0 - t) * 7.0 + 0.35 * 13.0 * cos(u * 13.0 - t * 1.7 + UV.y * 2.0);
	vec3 nf = vec3(-u * amp * ds, 0.0, 1.0);
	vec3 nh = vec3(0.0, u * amp * s, 1.0);
	if (hang > 0.5) {
		// Wind across the line pushes the garment out of its plane and lifts the hem a little.
		float push = wo.y * (0.1 * wind_strength + 0.22 * wind_gust);
		VERTEX.z += u * u * push;
		VERTEX.y += u * u * abs(push) * 0.35;
	} else {
		// A limp flag droops at the fly end; the wind holds it out.
		float hold = clamp((wind_strength - 0.8) * 0.7 + wind_gust * 0.5, 0.0, 1.0);
		VERTEX.y -= u * u * mix(0.09, 0.015, hold);
		// Turn round the pole so the fly end points downwind (+x of the quad -> wo).
		vec2 p = vec2(VERTEX.x - pole_x, VERTEX.z);
		VERTEX.x = pole_x + p.x * wo.x - p.y * wo.y;
		VERTEX.z = p.x * wo.y + p.y * wo.x;
		nf = vec3(nf.x * wo.x - nf.z * wo.y, nf.y, nf.x * wo.y + nf.z * wo.x);
	}
	NORMAL = normalize(mix(nf, nh, hang));
}

void fragment() {
	vec4 c = texture(cloth, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35);
}
