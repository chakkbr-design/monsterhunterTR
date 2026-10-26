// A cloth flag on a pole (VoxelZone flags): a subdivided quad whose free end ripples in the
// breeze (UV.x = 0 at the pole, 1 at the fly end), painted from a small nearest-filtered pixel
// texture so it matches the voxel look. Back faces show the same cloth.
// hang = 1: laundry on a washing line instead (VoxelZone._laundry): the top edge (UV.y = 0) is
// pegged and the free bottom sways; transparent texels cut the garment's shape out.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cloth : source_color, filter_nearest;
uniform float wave = 0.09;  // ripple amplitude at the free end (m)
uniform float speed = 4.5;
uniform float phase = 0.0;
uniform float hang = 0.0;

void vertex() {
	float u = mix(UV.x, UV.y, hang);
	float t = TIME * speed + phase;
	float s = sin(u * 7.0 - t) + 0.35 * sin(u * 13.0 - t * 1.7 + UV.y * 2.0);
	// Laundry: mostly a slow whole-garment swing plus a little ripple.
	float sw = sin(t * 0.6 + UV.x * 1.5) * 1.4;
	s = mix(s, sw + 0.3 * s, hang);
	VERTEX.z += u * wave * s;
	VERTEX.y -= u * u * 0.05 * (1.0 - hang);
	float ds = cos(u * 7.0 - t) * 7.0 + 0.35 * 13.0 * cos(u * 13.0 - t * 1.7 + UV.y * 2.0);
	vec3 nf = vec3(-u * wave * ds, 0.0, 1.0);
	vec3 nh = vec3(0.0, u * wave * s, 1.0);
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
