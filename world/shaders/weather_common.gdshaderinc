// D76 weather coverage map. Include from a spatial (or canvas_item) shader and sample per world
// position:
//
//   #include "res://world/shaders/weather_common.gdshaderinc"
//   ...
//   vec4 w = weather_at(world_pos);   // .r wet  .g snow  .b fog  .a cloud  (each 0..1)
//
// The map is an RGBA8 image over the world bounds at `weather_px` metres per texel, with texel 0
// at world (weather_origin.x, weather_origin.y) = (x, z). Outside the map it reads 0, so a shader
// can use it unconditionally. `weather_time` is the game clock in minutes (0..~1440/day).
// Published by scripts/world/weather.gd; the globals are declared in project.godot [shader_globals].

global uniform sampler2D weather_map;
global uniform vec2 weather_origin;
global uniform float weather_px;
global uniform float weather_time;

// Normalised coverage-map UV for a world position (may be outside 0..1).
vec2 weather_uv(vec3 world_pos) {
	vec2 size = vec2(textureSize(weather_map, 0));
	return (vec2(world_pos.x, world_pos.z) - weather_origin) / (weather_px * size);
}

// Coverage at a world position: (wet, snow, fog, cloud), 0 outside the map.
vec4 weather_at(vec3 world_pos) {
	vec2 uv = weather_uv(world_pos);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return texture(weather_map, uv);
}

// D77 surface look, shared by the ground/path/grass/foliage/prop/cliff/boulder shaders:
//   wet  (w.r) darkens the albedo ~35-45% with a slight cool shift and lowers roughness (the
//              sheen shows where the shader has specular enabled);
//   snow (w.g) blends to the cold white #eef3f8 by `snow_mask`. The caller decides the mask:
//              flat ground/paths/cliffs pass `smoothstep(0.55, 0.9, normal.y)` (up-facing), while
//              grass and foliage cards pass a HEIGHT mask (`smoothstep(0.35, 0.9, UV.y)`) so a
//              tuft gets snow-dusted tips, not a flat white card. `snow_max` caps the blend for
//              foliage/props (0.6) so leaves still show through; ground/path pass 1.0.
// `w == vec4(0.0)` (outside every cell) is a no-op, so an unwetted world is pixel-identical to
// before weather. Call it after the shader has set ALBEDO and ROUGHNESS.
void weather_surface(inout vec3 albedo, inout float roughness, float snow_mask, vec4 w, float snow_max) {
	float wet = clamp(w.r, 0.0, 1.0);
	if (wet > 0.0) {
		albedo *= 1.0 - 0.78 * wet;
		albedo *= mix(vec3(1.0), vec3(0.85, 0.91, 1.0), wet);
		roughness = mix(roughness, 0.22, wet);
	}
	float snow = clamp(w.g, 0.0, 1.0);
	if (snow > 0.0) {
		albedo = mix(albedo, vec3(0.933, 0.953, 0.973), snow * clamp(snow_mask, 0.0, 1.0) * snow_max);
	}
}

// ---------------------------------------------------------------- D77 puddles

float weather_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float weather_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(weather_hash(i), weather_hash(i + vec2(1.0, 0.0)), u.x),
			mix(weather_hash(i + vec2(0.0, 1.0)), weather_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Stable world-space puddle mask: low-frequency ~1.4 m blobs over ~20% of the surface, filling as
// the wet channel rises past 0.5 and fading as it dries (dry_hours gives the trail). Returns 0
// when dry, so an unwetted surface is pixel-identical to before weather.
float weather_puddle(vec2 xz, float wet) {
	float w = smoothstep(0.5, 0.9, wet);
	if (w <= 0.0) {
		return 0.0;
	}
	float n = weather_noise(xz * 0.7);
	return smoothstep(0.63, 0.80, n) * w;
}

// Expanding rain rings inside a puddle, animated on real time (TIME). Cheap: one hash per
// fragment, no texture.
float weather_ripple(vec2 xz, float t) {
	vec2 cell = floor(xz * 1.2);
	vec2 f = fract(xz * 1.2) - 0.5;
	float ph = fract(t * 0.7 + weather_hash(cell));
	float r = ph * 0.55;
	float ring = smoothstep(0.07, 0.0, abs(length(f) - r));
	return ring * (1.0 - ph) * smoothstep(0.0, 0.12, ph);
}
