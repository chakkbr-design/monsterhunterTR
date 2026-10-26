shader_type particles;
// Raindrops (WeatherRig): born in a box above the covered area, falling at 11-14 m/s and carried by
// the wind (the horizontal speed eases toward `wind`, so gusts bend the rain). A drop that touches
// the collision heightfield (ground, roofs, trees, water) is moved back onto the surface and
// replaced by one splash particle there (sub-emitter), so splashes sit exactly on what was hit and
// no drop falls through a roof.
render_mode disable_force;

uniform vec3 extents = vec3(18.0, 0.5, 18.0);
uniform vec2 speed = vec2(11.0, 14.0);
uniform vec3 wind = vec3(0.0);  // m/s
uniform vec2 scale_range = vec2(0.8, 1.25);
uniform float gravity = 3.0;
uniform bool splashes = true;
uniform float splash_chance = 0.55;  // share of the drops that leave a visible splash

float rnd(uint s) {
	s = (s ^ 61u) ^ (s >> 16u);
	s *= 9u;
	s = s ^ (s >> 4u);
	s *= 0x27d4eb2du;
	s = s ^ (s >> 15u);
	return float(s % 65536u) / 65535.0;
}

void start() {
	uint s = RANDOM_SEED + NUMBER * 7919u;
	if (RESTART_POSITION) {
		vec3 off = (vec3(rnd(s), rnd(s + 1u), rnd(s + 2u)) * 2.0 - 1.0) * extents;
		TRANSFORM = mat4(1.0);
		TRANSFORM[3].xyz = off;
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
	if (RESTART_VELOCITY) {
		float v = mix(speed.x, speed.y, rnd(s + 3u));
		VELOCITY = vec3(wind.x, -v, wind.z);
	}
	float sc = mix(scale_range.x, scale_range.y, rnd(s + 4u));
	TRANSFORM[0].xyz = vec3(sc, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, sc, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, sc);
	COLOR = vec4(1.0);
	CUSTOM = vec4(0.0, 0.0, 0.0, sc);
}

void process() {
	float k = clamp(DELTA * 2.5, 0.0, 1.0);
	VELOCITY.x = mix(VELOCITY.x, wind.x, k);
	VELOCITY.z = mix(VELOCITY.z, wind.z, k);
	VELOCITY.y -= gravity * DELTA;
	if (COLLIDED) {
		vec3 hit = TRANSFORM[3].xyz + COLLISION_NORMAL * COLLISION_DEPTH;
		if (splashes && rnd(NUMBER * 31u + RANDOM_SEED) < splash_chance) {
			mat4 x = mat4(1.0);
			x[3].xyz = hit + COLLISION_NORMAL * 0.01;
			emit_subparticle(x, vec3(0.0), vec4(1.0), vec4(COLLISION_NORMAL, 0.0), FLAG_EMIT_POSITION);
		}
		ACTIVE = false;
	}
	float sc = CUSTOM.w;
	TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz) * sc;
	TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz) * sc;
	TRANSFORM[2].xyz = normalize(TRANSFORM[2].xyz) * sc;
}
