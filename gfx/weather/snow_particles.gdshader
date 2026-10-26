shader_type particles;
// Snowflakes (WeatherRig): born in a box above the area, drifting down at ~1 m/s with the wind and
// a soft per-flake swirl (two phase-shifted sines plus a slow eddy field, cheaper than turbulence
// and calm enough to read as snow, not dust). A flake that touches the collision heightfield
// settles on the surface (ground, roof, branch) and fades out there over `settle_fade` seconds.
// CUSTOM: x billboard rotation (0, pixel flakes stay upright), y settled time (-1 = falling),
// z sprite frame (one of the 4 flake shapes), w age.
render_mode disable_force;

uniform vec3 extents = vec3(18.0, 0.5, 18.0);
uniform vec2 fall = vec2(0.75, 1.25);
uniform vec3 wind = vec3(0.0);
uniform float swirl = 0.45;
uniform vec2 scale_range = vec2(0.6, 1.5);
uniform float settle_fade = 2.0;

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
	float sc = mix(scale_range.x, scale_range.y, rnd(s + 3u) * rnd(s + 4u));
	TRANSFORM[0].xyz = vec3(sc, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, sc, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, sc);
	VELOCITY = vec3(wind.x * 0.7, -mix(fall.x, fall.y, rnd(s + 5u)), wind.z * 0.7);
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
	CUSTOM = vec4(0.0, -1.0, floor(rnd(s + 6u) * 4.0) / 4.0 + 0.01, 0.0);
}

void process() {
	CUSTOM.w += DELTA;
	float age = CUSTOM.w;
	float life = max(LIFETIME, 0.1);
	if (CUSTOM.y < 0.0) {
		vec3 p = TRANSFORM[3].xyz;
		float ph = float(INDEX % 97u) * 0.37;
		vec2 eddy = vec2(sin(p.z * 0.35 + TIME * 0.4), cos(p.x * 0.31 - TIME * 0.33));
		vec2 sw = vec2(sin(age * 1.7 + ph), cos(age * 1.3 + ph * 1.7)) * swirl + eddy * swirl * 0.6;
		float k = clamp(DELTA * 1.5, 0.0, 1.0);
		VELOCITY.x = mix(VELOCITY.x, wind.x * 0.7 + sw.x, k);
		VELOCITY.z = mix(VELOCITY.z, wind.z * 0.7 + sw.y, k);
		if (COLLIDED) {
			TRANSFORM[3].xyz += COLLISION_NORMAL * (COLLISION_DEPTH + 0.03);
			VELOCITY = vec3(0.0);
			CUSTOM.y = age;
		}
		COLOR.a = smoothstep(0.0, 0.6, age) * (1.0 - smoothstep(life - 1.0, life, age));
	} else {
		VELOCITY = vec3(0.0);
		COLOR.a = 1.0 - smoothstep(CUSTOM.y, CUSTOM.y + settle_fade, age);
		if (COLOR.a <= 0.0) {
			ACTIVE = false;
		}
	}
}
