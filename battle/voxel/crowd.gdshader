shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Crowd of the training stadium (ArenaCrowd): one MultiMesh instance per fan, a seated figure of
// 1/16 m boxes. Vertex colour is white, so COLOR is the instance colour (the shirt). UV.x holds the
// region (0 shirt, 1 skin, 2 hair, 3 trousers, 4 cap brim), UV.y the arm (0 none, 1 left, 2 right).
// INSTANCE_CUSTOM: r = skin + 8 * hair, g = trousers + 8 * cap, b = phase (0..1),
// a = team (0 side A fans, 1 neutral, 2 side B fans) + liveliness (0..0.99).
// Motion: idle sway and bob, cheering (stand up, hop, arms up) driven by cheer_a / cheer_b, and the
// Mexican wave: a band of fans standing up that runs around the bowl from wave_a0 at wave_speed
// (wave_tw is the time since it started, driven by ArenaStadium).

uniform float cheer_a = 0.0;
uniform float cheer_b = 0.0;
uniform float idle = 1.0;
uniform float wave_tw = -1.0;  // seconds since the wave started (< 0: no wave)
uniform float wave_secs = 14.0;
uniform float wave_speed = 0.9;  // rad/s around the bowl
uniform float wave_a0 = 0.0;
uniform float wave_width = 0.28;  // rad
uniform vec3 skin[6];
uniform vec3 hair[6];
uniform vec3 trousers[4];

varying vec3 v_col;
varying float v_shade;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	int region = int(UV.x + 0.5);
	int arm = int(UV.y + 0.5);
	float y0 = VERTEX.y;
	float ph = INSTANCE_CUSTOM.b * 6.2831853;
	float act = fract(INSTANCE_CUSTOM.a);
	float team = floor(INSTANCE_CUSTOM.a + 0.001);
	float ex = team < 0.5 ? cheer_a : (team > 1.5 ? cheer_b : 0.55 * max(cheer_a, cheer_b));
	ex = clamp(ex * (0.5 + 0.7 * act), 0.0, 1.0);
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wv = 0.0;
	float tw = wave_tw;
	if (tw >= 0.0 && tw < wave_secs) {
		float ang = atan(o.z, o.x);
		float d = mod(ang - wave_a0 - tw * wave_speed + 3.14159265, 6.2831853) - 3.14159265;
		wv = exp(-d * d / (wave_width * wave_width)) * smoothstep(0.0, 1.0, tw) * smoothstep(wave_secs, wave_secs - 1.5, tw);
	}
	float up = clamp(max(ex, wv), 0.0, 1.0);
	float stand = smoothstep(0.2, 0.8, up);
	float hop = ex * max(sin(TIME * (6.5 + 3.5 * act) + ph), 0.0) * 0.1;
	float bob = idle * act * max(sin(TIME * (1.3 + act) + ph), 0.0) * 0.035;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (arm > 0) {
		// Some fans wave or clap now and then even when calm.
		float calm = idle * smoothstep(0.82, 1.0, sin(TIME * 0.37 + ph * 3.0)) * (act > 0.6 ? 1.0 : 0.0);
		float a = max(up, calm) * (2.65 + 0.35 * sin(TIME * 9.0 + ph + float(arm) * 1.9));
		vec3 piv = vec3(arm == 1 ? -0.25 : 0.25, 0.5625, 0.0);
		vec3 r = v - piv;
		float c = cos(a);
		float s = sin(a);
		v = piv + vec3(r.x, r.y * c - r.z * s, r.y * s + r.z * c);
		n = vec3(n.x, n.y * c - n.z * s, n.y * s + n.z * c);
	}
	v.y += stand * 0.3 + hop + bob;
	v.x += sin(TIME * 0.8 + ph) * 0.025 * max(v.y, 0.0) * idle;
	float cap = step(7.5, INSTANCE_CUSTOM.g);
	if (region == 4 && cap < 0.5) {
		v = vec3(0.0, 0.7, 0.0);
	}
	VERTEX = v;
	NORMAL = n;
	int si = int(mod(INSTANCE_CUSTOM.r, 8.0));
	int hi = int(INSTANCE_CUSTOM.r / 8.0);
	int ti = int(mod(INSTANCE_CUSTOM.g, 8.0));
	vec3 shirt = COLOR.rgb;
	vec3 col = shirt;
	if (region == 1) {
		col = skin[clamp(si, 0, 5)];
	} else if (region == 2) {
		col = cap > 0.5 && y0 > 0.86 ? shirt * 0.8 : hair[clamp(hi, 0, 5)];
	} else if (region == 3) {
		col = trousers[clamp(ti, 0, 3)];
	} else if (region == 4) {
		col = shirt * 0.8;
	}
	v_col = to_linear(col);
	// Cheap occlusion: the lower body sits between the rows.
	v_shade = region == 3 ? 0.62 : mix(0.75, 1.0, clamp((y0 - 0.1) * 1.6, 0.0, 1.0));
}

void fragment() {
	ALBEDO = v_col * v_shade;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
