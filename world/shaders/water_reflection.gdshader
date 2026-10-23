shader_type spatial;
// D79 fake mirrored billboard reflection (Pokémon / player / NPCs near water).
//
// One quad per body, parented to the body, positioned at the body's mirror across the water
// plane. Fixed-Y billboard (matches Sprite3D billboard = 2), the frame is sampled upside-down,
// tinted toward the water colour, rippled with the same wave feel as the surface and faded with
// depth below the waterline.
//
// Honest geometry for our camera (looking north, pitched down): the mirror hangs BELOW the body
// on screen (toward the camera), starting at its feet. It is visible only where the strip
// between the camera and the body crosses water, so a body on the north/east/west shore or
// standing/wading in water reflects; a body on the south shore (water behind it on screen) does
// not. The clip is the camera -> fragment ray's crossing of the water plane against the
// noise-warped water rect.
//
// The opaque water plane (and the ground under it) would hide a sprite below the surface, so the
// reflection is drawn depth-test-disabled and rejects itself against the depth buffer wherever an
// opaque object (its own body, another sprite, a tree) stands between the camera and the water
// crossing — it never draws over a sprite.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture;
uniform mat4 cam_vp = mat4(1.0);   // camera view-projection, set by water_reflections.gd
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);   // frame region in the atlas (x, y, w, h)
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool flip_h = false;

uniform vec3 water_tint : source_color = vec3(0.48, 0.63, 0.8);
uniform float strength : hint_range(0.0, 1.0) = 0.85;     // overall opacity of the reflection
uniform float ripple : hint_range(0.0, 0.1) = 0.018;      // horizontal ripple distortion
uniform float ripple_speed = 2.4;
uniform float fade_depth : hint_range(0.2, 6.0) = 1.8;    // metres below the waterline to fade out

// Water rect (the same unwarped box + noise the surface shader uses) for the water-only clip.
uniform float water_y = 0.04;
uniform vec2 water_centre = vec2(0.0);
uniform vec2 water_half = vec2(1.0);
uniform float water_warp = 0.35;

varying vec3 world_pos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float sd_box(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void vertex() {
	// Fixed-Y billboard (Sprite3D billboard = 2), written straight into MODELVIEW_MATRIX.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 d = cam.xz - MODEL_MATRIX[3].xz;
	if (length(d) < 0.0001) {
		d = vec2(0.0, 1.0);
	}
	d = normalize(d);
	vec3 right = vec3(d.y, 0.0, -d.x);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 fwd = vec3(d.x, 0.0, d.y);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(fwd * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	world_pos = (INV_VIEW_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xyz;
}

void fragment() {
	// Ripple: a couple of cheap waves slide the sampled column, so the mirror shimmers.
	float wob = sin(UV.y * 30.0 + TIME * ripple_speed + world_pos.x * 2.0) * ripple;
	wob += sin(UV.y * 13.0 - TIME * ripple_speed * 0.7 + world_pos.z * 1.7) * ripple * 0.6;
	float u = clamp(UV.x + wob, 0.0, 1.0);
	if (flip_h) {
		u = 1.0 - u;
	}
	vec4 c = texture(albedo_tex, uv_rect.xy + vec2(u, 1.0 - UV.y) * uv_rect.zw);
	float a = c.a * tint.a;

	// Crossing mask: where does the camera -> fragment ray meet the water plane? The mirror is
	// only seen through water, so a ray that lands on land is clipped away.
	float denom = world_pos.y - CAMERA_POSITION_WORLD.y;
	if (denom > -0.0001) {
		discard;
	}
	float t = (water_y - CAMERA_POSITION_WORLD.y) / denom;
	if (t <= 0.0 || t >= 1.0) {
		discard;
	}
	vec3 cross = CAMERA_POSITION_WORLD + (world_pos - CAMERA_POSITION_WORLD) * t;
	vec2 p = cross.xz - water_centre;
	float dwob = (vnoise(p * 0.5) - 0.5) + (vnoise(p * 1.3 + 5.0) - 0.5) * 0.5;
	if (sd_box(p, water_half) + dwob * 2.0 * water_warp > 0.0) {
		discard;
	}
	// Never draw over a body/sprite/tree in front of the water crossing: the opaque depth at this
	// pixel is the water surface, so anything nearer than the crossing means something is in front.
	vec4 clip = cam_vp * vec4(cross, 1.0);
	float cross_depth = clip.z / clip.w;
	if (texture(depth_tex, SCREEN_UV).x > cross_depth + 0.002) {
		discard;
	}

	float depth_below = water_y - world_pos.y;
	float fade = 1.0 - smoothstep(0.0, fade_depth, depth_below);
	a *= strength * fade;
	if (a < 0.01) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb * mix(vec3(1.0), water_tint, 0.35);
	ALPHA = a;
}
