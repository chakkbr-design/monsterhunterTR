shader_type particles;
// Splash (WeatherRig): emitted by a raindrop where it hit (rain_particles.gdshader). A ring grows
// on the surface while a pixel crown of droplets plays its 4 frames (CUSTOM.z drives the frame of
// the billboard pass), then both fade. Splashes never move.
render_mode disable_force, disable_velocity;

uniform vec2 ring_scale = vec2(0.5, 1.4);

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
	vec3 p = TRANSFORM[3].xyz;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = p;
	VELOCITY = vec3(0.0);
	COLOR = vec4(1.0);
	// x: billboard rotation (none), y: size jitter, z: crown frame, w: age (s).
	CUSTOM = vec4(0.0, mix(0.75, 1.25, rnd(s)), 0.0, 0.0);
}

void process() {
	CUSTOM.w += DELTA;
	if (CUSTOM.w >= LIFETIME) {
		ACTIVE = false;
	}
	float t = clamp(CUSTOM.w / max(LIFETIME, 0.01), 0.0, 1.0);
	CUSTOM.z = t * 0.999;
	float sc = mix(ring_scale.x, ring_scale.y, sqrt(t)) * CUSTOM.y;
	TRANSFORM[0].xyz = vec3(sc, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, sc, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, sc);
	COLOR.a = smoothstep(0.0, 0.08, t) * pow(1.0 - t, 1.4);
}
