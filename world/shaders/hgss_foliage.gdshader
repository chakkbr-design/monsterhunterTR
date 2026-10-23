shader_type spatial;
// HGSS foliage cards (the DS tree canopy and bush — a single camera-facing plane each). A
// billboard done by overriding MODELVIEW_MATRIX, so the card faces the camera but the base stays
// pinned while the shared global wind shears it by height. Nearest texture, alpha scissor, lit
// and shadow-casting (the shadow pass runs the same vertex code).
render_mode cull_disabled;
#include "res://world/shaders/weather_common.gdshaderinc"

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_gust;
global uniform float wind_time;
// World position of the main camera, published every frame by camera_rig.gd. The billboard must
// face the MAIN camera in every pass: the shadow pass looks down the sun, so a per-pass billboard
// (INV_VIEW_MATRIX) makes the caster a differently oriented quad that self-shadows the visible
// card — the hard lit/dark diagonal split.
global uniform vec3 main_cam_pos;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
// UV sub-rect (u0, v0, u1, v1) sampled by the card. A DS card texture carries transparent
// margins, so a card maps just the drawn mass onto its quad instead of floating in them.
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Horizontal shear per metre of height at wind (strength + gust) = 1.
uniform float sway = 0.04;
// Grass interaction (scripts/tall_grass.gd), used by the tall-grass tuft cards. `pushers`: up to
// 16 walkers (player, party, wilds, NPCs), xz = world position, w = radius (0 = unused);
// cards inside a radius bend away from the walker, more towards the tip. `shake`: a local shudder
// before a grass ambush, xz = centre, w = strength 0..1 (0 = calm). Trees and bushes leave both
// empty, so they pay only the loop's zero check.
uniform vec4 pushers[16];
uniform vec4 shake;
uniform float push_scale = 1.0;
varying vec3 world_pos;
// Step flick (scripts/tall_grass.gd): each walker's step in the grass, xy = world xz, z = age in
// seconds, w = strength (0 = unused). Cards within STEP_RADIUS of a fresh step squash down and
// spring back over STEP_SECS (HGSS's signature tile shake). Trees and bushes leave the array
// empty, so the loop's zero check skips them and they are untouched.
uniform vec4 steps[8];
const float STEP_RADIUS = 0.9;
const float STEP_SECS = 0.3;
// Battle grass-hide (scripts/tall_grass.gd, B28): `hide_rect` is the battle arena in world xz
// (x0, z0, x1, z1) and `hide_amount` 0..1 is how far the cards whose base sits inside it have
// collapsed into the ground. Trees and bushes never set it, so it stays 0 and they are untouched.
uniform vec4 hide_rect = vec4(0.0);
uniform float hide_amount = 0.0;
const float SHAKE_RADIUS = 2.2;

void vertex() {
	float s = length(MODEL_MATRIX[0]);  // uniform instance scale
	// Battle: shrink the cards standing inside the arena down into their base on the ground
	// (hide_amount 0..1; at 1 the card is a point and vanishes).
	if (hide_amount > 0.0) {
		vec2 base = MODEL_MATRIX[3].xz;
		if (base.x > hide_rect.x && base.x < hide_rect.z &&
				base.y > hide_rect.y && base.y < hide_rect.w) {
			VERTEX *= 1.0 - hide_amount;
		}
	}
	// Look-at basis toward the main camera (no roll): local z faces the camera, local y is as
	// close to world up as the tilt allows. Derived from main_cam_pos, so it is identical in the
	// main and shadow passes — the caster can no longer be a different quad than the card.
	vec3 cam_fwd = main_cam_pos - MODEL_MATRIX[3].xyz;
	if (dot(cam_fwd, cam_fwd) < 0.000001) {
		cam_fwd = INV_VIEW_MATRIX[2].xyz;  // no main camera published yet
	}
	cam_fwd = normalize(cam_fwd);
	vec3 cam_right = normalize(cross(vec3(0.0, 1.0, 0.0), cam_fwd));
	vec3 cam_up = cross(cam_fwd, cam_right);
	// Billboard: local x -> camera right, local y -> camera up, local z -> toward the camera.
	mat4 bb = mat4(vec4(cam_right * s, 0.0), vec4(cam_up * s, 0.0), vec4(cam_fwd * s, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	world_pos = MODEL_MATRIX[3].xyz;  // per-instance (MultiMesh) world base for the coverage map

	vec2 wd = normalize(wind_dir);
	// The wind is horizontal: project it onto the card's own axes so the shear follows wind_dir.
	vec2 local_dir = vec2(dot(wd, normalize(cam_right.xz)), dot(wd, normalize(cam_fwd.xz)));
	float h = max(VERTEX.y, 0.0) * s;  // height above the pinned base, in metres
	// Per-instance phase from world position; gusts travel across the town (dot(pos, wind_dir)).
	float ph = wind_time * 1.6 + dot(MODEL_MATRIX[3].xz, vec2(0.73, 1.27)) + dot(MODEL_MATRIX[3].xz, wd) * 0.45;
	float w = sin(ph) * 0.75 + 0.25 * sin(ph * 2.3 + 1.0);
	// D77: wet grass sways harder and droops a little in heavy rain.
	float wet_grass = weather_at(MODEL_MATRIX[3].xyz).r;
	float amp = sway * h * (wind_strength + wind_gust) * w * (1.0 + 0.9 * wet_grass);
	VERTEX.x += local_dir.x * amp;
	VERTEX.z += local_dir.y * amp;

	// Push: cards part around the walkers, and shudder around the player before an ambush.
	// Computed in world xz (the same space as the wind), then projected onto the card's axes.
	vec2 push = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		if (pushers[i].w <= 0.0) {
			continue;
		}
		vec2 d = MODEL_MATRIX[3].xz - pushers[i].xz;
		float dist = length(d);
		if (dist < pushers[i].w) {
			float f = 1.0 - dist / pushers[i].w;
			push += normalize(d + vec2(1e-4, 1e-4)) * f * f * pushers[i].w * 0.7;
		}
	}
	if (shake.w > 0.0) {
		vec2 d = MODEL_MATRIX[3].xz - shake.xz;
		float dist = length(d);
		if (dist < SHAKE_RADIUS) {
			float f = 1.0 - dist / SHAKE_RADIUS;
			push += vec2(sin(wind_time * 34.0 + MODEL_MATRIX[3].x * 4.0),
					cos(wind_time * 30.0 + MODEL_MATRIX[3].z * 4.0)) * f * f * shake.w * 0.5;
		}
	}
	push *= push_scale * (1.0 - UV.y);  // 0 at the pinned base, full at the tip
	VERTEX.x += dot(push, normalize(cam_right.xz));
	VERTEX.z += dot(push, normalize(cam_fwd.xz));

	// Step flick: squash the card down at a walker's feet, then let it spring back past level.
	float squash = 0.0;
	for (int i = 0; i < 8; i++) {
		if (steps[i].w <= 0.0) {
			continue;
		}
		vec2 d = MODEL_MATRIX[3].xz - steps[i].xy;
		float dist = length(d);
		if (dist < STEP_RADIUS) {
			float e = steps[i].z / STEP_SECS;
			if (e < 1.0) {
				float f = 1.0 - dist / STEP_RADIUS;
				squash += -exp(-4.5 * e) * sin(e * 9.0) * f * f * steps[i].w;
			}
		}
	}
	// Vertical scale about the pinned base (no shear), clamped so a card can never invert.
	VERTEX.y *= (1.0 + clamp(squash * 2.0, -0.75, 0.6)) * (1.0 - 0.12 * wet_grass);
}

void fragment() {
	vec2 uv = vec2(mix(uv_rect.x, uv_rect.z, UV.x), mix(uv_rect.y, uv_rect.w, UV.y));
	vec4 c = texture(albedo_tex, uv);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	vec4 w = weather_at(world_pos);
	// Snow on the tuft's upper blades (card height), not the billboard normal.
	weather_surface(ALBEDO, ROUGHNESS, smoothstep(0.2, 0.8, UV.y), w, 0.5);
}
