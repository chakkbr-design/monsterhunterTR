shader_type spatial;
// Rain streak on a particle quad (WeatherRig): the particle aligns the quad's Y to its velocity and
// turns its face to the camera (TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY), so wind slants every
// streak the way it actually falls. Lit by the scene instead of glowing: grey-blue in daylight,
// almost invisible in the dark and bright where a lamp or the sun is behind the drop (backlight),
// like real rain. Far streaks are widened to at least ~1.3 px with their opacity lowered to match,
// so the thin lines never shimmer, and streaks right in front of the lens fade out.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.74, 0.8, 0.88);
uniform float opacity = 0.55;
uniform float width = 0.018;  // m, the quad's width (scale 1)
uniform float min_px = 1.3;  // never thinner than this on screen
uniform float near_fade = 3.0;  // m from the camera
uniform float far_fade = 60.0;
uniform float backlight = 0.75;
uniform float sky_fill = 0.16;  // a touch of the sky colour, so daytime rain reads against stone
// Far streaks (widened 4-8x past their real width, ~50-100 m from the camera at 720p) stretched this
// many times longer and as much fainter (the same light): a far drop lit by a floodlight is a dot of
// a pixel or two that reads as snow; stretched, the far rain is a haze of faint lines. 1 = off.
uniform float far_stretch = 1.0;

global uniform vec4 sky_horizon_color;
global uniform float lightning_flash;

varying float v_fade;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = max(-c.z, 0.05);
	// Metres per pixel there (abs: the Vulkan projection can flip Y, and a negative size would keep
	// every streak at its real width, far ones a bright sub-pixel dot).
	float px = 2.0 * d / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	float w = width * length((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	float f = max(1.0, min_px * px / max(w, 1e-5));
	VERTEX.x *= f;
	float st = mix(1.0, far_stretch, smoothstep(4.0, 8.0, f));
	VERTEX.y *= st;
	v_fade = 1.0 / (f * st);
	v_fade *= smoothstep(near_fade * 0.5, near_fade * 1.5, d) * (1.0 - smoothstep(far_fade * 0.7, far_fade, d));
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = smoothstep(0.0, 0.7, across);
	// UV.y 0 = leading end (the quad's +Y follows the velocity): a bright head, a long soft tail.
	float along = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.35, 1.0, UV.y));
	ALBEDO = tint;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	BACKLIGHT = vec3(backlight);
	EMISSION = sky_horizon_color.rgb * sky_fill
		+ vec3(0.62, 0.68, 0.85) * lightning_flash * 0.9;
	ALPHA = clamp(opacity * across * along * v_fade * COLOR.a, 0.0, 1.0);
}
