// Shared HD-2D dirt look (organic paths, ramps): warm sandy brown, pixel-quantised
// world-space variation and sparse pebbles. Texel = 1/16 m like the props.
float dirt_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float dirt_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dirt_hash(i), dirt_hash(i + vec2(1.0, 0.0)), u.x),
			mix(dirt_hash(i + vec2(0.0, 1.0)), dirt_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 dirt_color(vec2 xz) {
	vec2 cell = floor(xz * 16.0);
	vec2 px = cell / 16.0;
	float big = dirt_noise(px * 0.35);
	float mid = dirt_noise(px * 1.7 + 11.0);
	vec3 light = vec3(0.80, 0.66, 0.46);
	vec3 dark = vec3(0.60, 0.46, 0.31);
	vec3 c = mix(dark, light, smoothstep(0.25, 0.75, big * 0.6 + mid * 0.4));
	c *= 0.94 + dirt_hash(cell) * 0.1;
	float pebble = step(0.965, dirt_hash(floor(xz * 5.0))) * step(0.5, dirt_hash(cell + 3.0));
	c = mix(c, vec3(0.86, 0.80, 0.70), pebble);
	return floor(c * 24.0 + 0.5) / 24.0;
}
