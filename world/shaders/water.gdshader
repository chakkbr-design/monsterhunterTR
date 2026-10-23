shader_type spatial;
// HGSS pond/sea water (HD-2D). One plane per water rect (the builder sets `centre` / `half_size`),
// its shoreline a noise-warped rounded rect that discards outside, so there is no hard rectangle.
// The surface is the DS's own art: `sea_un` (caustic base) tiled in WORLD space at 1.6 m per
// repeat (2 DS tiles), with the six `sea_on` wave-glint frames cycling over it. `pond_line` draws
// the sand -> wet-earth shore band and `sea_line02` a foam edge; the wadeable shallow band
// (scripts/world/water.gd, SHALLOW_WIDTH) is a lighter strip inside the shore.
//
// Every knob is a uniform and lives in resources/look/water.tres, so it can be tweaked live in the
// inspector — see "How to tune the water" in docs/MAP_DESIGN.md.
render_mode diffuse_lambert, specular_schlick_ggx;

instance uniform vec2 centre = vec2(0.0);        // world (x, z) of the water rect centre
instance uniform vec2 half_size = vec2(1.0);     // water rect half extents (m)

// -- surface -----------------------------------------------------------------
uniform sampler2D sea_tex : source_color, filter_nearest, repeat_enable;    // sea_un caustic base
uniform sampler2D glint_tex : source_color, filter_nearest, repeat_enable;  // sea_on frame sheet
uniform float tile_size : hint_range(0.4, 4.0) = 1.6;     // metres per repeat (2 DS tiles)
uniform int glint_frames : hint_range(1, 8) = 6;          // frames packed left-to-right in the sheet
uniform float frame_time : hint_range(0.05, 1.0) = 0.2;   // seconds per glint frame (~DS speed)
uniform float glint_strength : hint_range(0.0, 1.0) = 0.4;  // how strongly the wave glints show
uniform float glint_scale : hint_range(0.5, 4.0) = 2.0;   // glint repeat as a multiple of tile_size
uniform float scroll_speed : hint_range(0.0, 0.5) = 0.05; // surface drift (m/s, 0 = still)
uniform vec2 scroll_dir = vec2(1.0, 0.5);                 // direction of that drift

// -- depth tint (shallow -> deep; subtle and DS-like, not a smooth ramp) ------
uniform vec3 shallow_tint : source_color = vec3(1.35, 1.25, 1.05);
uniform vec3 deep_tint : source_color = vec3(0.55, 0.75, 1.05);
uniform float depth : hint_range(0.5, 12.0) = 3.0;        // metres inside the shore to full deep tint

// -- shallow wading band (gameplay: Water.SHALLOW_WIDTH) ----------------------
uniform float shallow_width : hint_range(0.2, 4.0) = 1.2; // m of wadeable water inside the shore
uniform vec3 shallow_band : source_color = vec3(0.62, 0.92, 0.95); // clearer colour of that band

// -- shore -------------------------------------------------------------------
uniform sampler2D shore_tex : source_color, filter_nearest, repeat_enable;  // pond_line
uniform sampler2D foam_tex : source_color, filter_nearest, repeat_enable;   // sea_line02
uniform float margin : hint_range(0.0, 3.0) = 0.9;        // land band beyond the water edge (m)
uniform float edge : hint_range(0.05, 2.0) = 0.3;         // shore falloff (m)
uniform float warp : hint_range(0.0, 2.0) = 0.35;         // shoreline wobble (m)
uniform float shore_width : hint_range(0.2, 2.5) = 0.8;   // pond_line band width on the land side (m)
uniform vec3 sand : source_color = vec3(0.83, 0.70, 0.50); // beach fill on the land side
uniform float foam : hint_range(0.0, 1.0) = 0.45;         // sea_line02 foam strength at the water edge

// -- fake sky reflection (D79) -----------------------------------------------
// The current sky and sun colours are pushed in from scripts/world/water_reflections.gd, so this
// follows the time of day and overcast on every platform (Compatibility/web included, no SSR).
uniform vec3 sky_top : source_color = vec3(0.36, 0.55, 0.85);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);  // DirectionalLight3D light_color
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.35;   // sheen strength at the far edge
uniform float sky_grazing : hint_range(0.0, 1.5) = 0.40;   // view.y where the far-edge sheen starts
uniform float sky_ramp : hint_range(0.5, 12.0) = 9.0;      // how fast the sheen ramps in
uniform float sky_wobble : hint_range(0.0, 0.3) = 0.02;    // ripple of the reflected sky direction

// -- lighting (flat normal: a broad low sheen, never a smeared sun streak) ----
uniform float water_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float water_specular : hint_range(0.0, 1.0) = 0.5;
uniform float water_metal : hint_range(0.0, 1.0) = 0.0;
uniform float beach_roughness : hint_range(0.0, 1.0) = 1.0;
uniform float beach_specular : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Signed distance to an axis-aligned box centred on the origin (negative inside).
float sd_box(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// Outward direction of sd_box at p, so the shore band can run along the edge (its tangent).
vec2 box_out(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	vec2 s = vec2(sign(p.x), sign(p.y));
	if (q.x > 0.0 && q.y > 0.0) {
		return normalize(s * q);           // corner: away from the corner point
	}
	return q.x > q.y ? vec2(s.x, 0.0) : vec2(0.0, s.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz - centre;
	float d0 = sd_box(p, half_size);
	float wob = (vnoise(p * 0.5) - 0.5) + (vnoise(p * 1.3 + 5.0) - 0.5) * 0.5;
	float d = d0 + wob * 2.0 * warp;
	if (d > margin) {
		discard;
	}

	// ---- surface: sea_un base + the sea_on glint frames, world space, texel-snapped drift ----
	float texels_per_m = 32.0 / tile_size;
	vec2 drift = floor(normalize(scroll_dir) * scroll_speed * TIME * texels_per_m) / texels_per_m;
	vec2 tuv = (world_pos.xz + drift) / tile_size;
	vec3 c = texture(sea_tex, tuv).rgb;
	vec2 guv = (world_pos.xz + drift) / (tile_size * glint_scale);
	vec2 local = fract(guv);
	float fi = mod(floor(TIME / frame_time), float(glint_frames));
	vec4 glint = texture(glint_tex, vec2((local.x + fi) / float(glint_frames), local.y));
	c = mix(c, glint.rgb, glint.a * glint_strength);

	// ---- depth: a gentle deeper tint toward the middle, then the shallow band ----
	float deep_t = smoothstep(0.0, depth, -d0);
	vec3 water = c * mix(shallow_tint, deep_tint, deep_t);
	float band = 1.0 - smoothstep(shallow_width - 0.3, shallow_width, -d);
	water = mix(water, mix(c, shallow_band, 0.5), band);

	// ---- fake sky reflection (D79): a grazing sheen toward the current sky colours, rippled ----
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = clamp((sky_grazing - view_dir.y) * sky_ramp, 0.0, 1.0);  // 0 near the camera -> 1 at the far edge
	vec3 refl = reflect(-view_dir, vec3(0.0, 1.0, 0.0));
	// The same wave field as the surface nudges the reflected direction so the sky reads as water.
	vec2 sky_wob = vec2(vnoise(world_pos.xz * 1.1 + vec2(TIME * 0.12, 0.0)),
			vnoise(world_pos.xz * 0.9 - vec2(0.0, TIME * 0.1))) * 2.0 - 0.5;
	refl = normalize(refl + vec3(sky_wob.x, 0.0, sky_wob.y) * sky_wobble * 2.0);
	// Grazing rays (the far edge) reflect the sky, pulled toward the sun's own colour: a warm sunset
	// sun makes the far edge orange/pink, while midday stays a light blue band. The sheen is 0 over
	// the near two-thirds, so the pond keeps its saturated blue.
	float warm = clamp((sun_color.r - sun_color.g) * 2.0, 0.0, 1.0);
	vec3 sky = mix(sky_top, sun_color, warm);
	water = mix(water, sky, clamp(fres * sky_reflect, 0.0, 1.0));

	// ---- shore: pond_line band (sand -> wet earth) mapped across the warped shore ----
	vec2 out_dir = box_out(p, half_size);
	vec2 tang = vec2(-out_dir.y, out_dir.x);
	float su = dot(world_pos.xz, tang) / 0.8;              // 1 DS tile along the shore
	float sv = mix(0.14, 0.80, clamp(1.0 - d / shore_width, 0.0, 1.0));  // opaque rows of pond_line
	vec3 land = mix(sand, texture(shore_tex, vec2(su, sv)).rgb, 1.0 - smoothstep(0.0, 0.35, d));

	// ---- composite: water inside, land outside, foam just inside the edge ----
	float shore = smoothstep(-edge, edge, d);              // 0 water -> 1 land
	vec3 col = mix(water, land, shore);
	float foam_width = shore_width * 0.7;
	float foam_t = 1.0 - clamp(abs(d + foam_width * 0.5) / (foam_width * 0.5), 0.0, 1.0);
	vec4 foam_c = texture(foam_tex, vec2(su, mix(0.28, 0.69, foam_t)));
	col = mix(col, foam_c.rgb, foam_c.a * foam * foam_t * (1.0 - shore));

	ALBEDO = col;
	// The sunset sky's magenta ambient (violet zenith + orange horizon) turns the blue water purple.
	// A faint self-lit base scaled by the sky's brightness keeps the water's own blue readable while
	// night stays dark; a cyan push scaled by how warm the sun is counters the magenta at sunset.
	float sky_lum = dot(sky_top, vec3(0.2126, 0.7152, 0.0722));
	EMISSION = col * (0.03 + 0.17 * clamp(sky_lum / 0.55, 0.0, 1.0))
		+ vec3(0.0, 0.07, 0.05) * pow(clamp((sun_color.r - sun_color.g) * 2.0, 0.0, 1.0), 3.0);
	ROUGHNESS = mix(water_roughness, beach_roughness, shore);
	SPECULAR = mix(water_specular, beach_specular, shore);
	METALLIC = mix(water_metal, 0.0, shore);
}
