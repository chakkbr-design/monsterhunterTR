// A cloth flag on a pole (VoxelZone flags): a subdivided quad whose free end ripples in the
// breeze (UV.x = 0 at the pole, 1 at the fly end), painted from a small nearest-filtered pixel
// texture so it matches the voxel look. Back faces show the same cloth.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cloth : source_color, filter_nearest;
uniform float wave = 0.09;  // ripple amplitude at the fly end (m)
uniform float speed = 4.5;
uniform float phase = 0.0;

void vertex() {
	float u = UV.x;
	float t = TIME * speed + phase;
	float s = sin(u * 7.0 - t) + 0.35 * sin(u * 13.0 - t * 1.7 + UV.y * 2.0);
	VERTEX.z += u * wave * s;
	VERTEX.y -= u * u * 0.05;
	float ds = cos(u * 7.0 - t) * 7.0 + 0.35 * 13.0 * cos(u * 13.0 - t * 1.7 + UV.y * 2.0);
	NORMAL = normalize(vec3(-u * wave * ds, 0.0, 1.0));
}

void fragment() {
	ALBEDO = texture(cloth, UV).rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.35);
}
