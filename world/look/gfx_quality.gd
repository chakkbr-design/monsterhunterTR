class_name GfxQuality
extends RefCounted
## Graphics tiers (Opções > GRÁFICOS: Baixo / Médio / Alto / Ultra; Alto is the default, tuned for
## an RTX 5070-class GPU). One table drives everything quality-dependent:
##   - the viewport: 3D render scale and upscaler, FXAA / SMAA (Ultra: FSR 2.2 as native AA).
##     Never MSAA: with it the water's depth / screen reads come back empty and the transparent
##     water turns opaque (gfx/water), and SMAA keeps the voxel and sprite edges just as clean;
##   - the renderer's global settings: directional and lamp shadow atlases, soft-shadow filter,
##     SSAO / SSIL / SSR quality, SDFGI rays and light-update rate, GI half resolution,
##     volumetric fog volume;
##   - per Environment (apply_env): which of SSAO, SSIL, SDFGI, SSR and volumetric fog may run.
##     A look (.tres) still decides what it wants; the tier only allows or forbids it. SSIL is
##     dropped whenever SDFGI runs (SDFGI already gives the bounce);
##   - the sun / moon shadow (apply_sun): distance, splits, PCSS angular size;
##   - how many street lamps cast shadows (NightLights budget) and the sky radiance size.
## Settings.apply() calls set_tier() + apply_all(); nodes in the "gfx_quality" group get
## apply_quality() so live environments (the world, the training stadium) re-apply their flags.
## --quality=0..3 (or baixo/medio/alto/ultra) forces a tier for screenshots.

const GROUP := "gfx_quality"
const NAMES := ["Baixo", "Médio", "Alto", "Ultra"]
const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3
const DEFAULT := HIGH

const TIERS := [
	{  # Baixo: integrated GPUs / laptops.
		"scale": 0.75,
		"scale_mode": Viewport.SCALING_3D_MODE_FSR,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"ssao": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
		"ssao_half": true,
		"ssil": false,
		"ssil_quality": RenderingServer.ENV_SSIL_QUALITY_VERY_LOW,
		"sdfgi": false,
		"sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		"sdfgi_update": RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES,
		"gi_half": true,
		"ssr": false,
		"ssr_half": true,
		"volumetric": false,
		"dir_shadow": 2048,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
		"shadow_distance": 32.0,
		"shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"sun_angular": 0.0,
		"pos_atlas": 2048,
		"lamp_shadows": 0,
		"radiance": 64,
	},
	{  # Médio: no GI, screen-space bounce instead.
		"scale": 1.0,
		"scale_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"ssao": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		"ssao_half": true,
		"ssil": true,
		"ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"sdfgi": false,
		"sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_16,
		"sdfgi_update": RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES,
		"gi_half": true,
		"ssr": false,
		"ssr_half": true,
		"volumetric": false,
		"dir_shadow": 4096,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_distance": 38.0,
		"shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"sun_angular": 0.0,
		"pos_atlas": 2048,
		"lamp_shadows": 2,
		"radiance": 128,
	},
	{  # Alto (default): SDFGI at half resolution, SSR for wet streets, lamp halos.
		"scale": 1.0,
		"scale_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"ssao": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_HIGH,
		"ssao_half": false,
		"ssil": true,
		"ssil_quality": RenderingServer.ENV_SSIL_QUALITY_MEDIUM,
		"sdfgi": true,
		"sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_32,
		"sdfgi_update": RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES,
		"gi_half": true,
		"ssr": true,
		"ssr_half": true,
		"volumetric": true,
		"dir_shadow": 4096,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"shadow_distance": 45.0,
		"shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"sun_angular": 0.0,
		"pos_atlas": 4096,
		"lamp_shadows": 4,
		"radiance": 128,
	},
	{  # Ultra: full-resolution GI and reflections, FSR 2.2 native AA, contact-hardening sun.
		"scale": 1.0,
		"scale_mode": Viewport.SCALING_3D_MODE_FSR2,
		"msaa": Viewport.MSAA_DISABLED,
		"screen_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
		"ssao": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_ULTRA,
		"ssao_half": false,
		"ssil": true,
		"ssil_quality": RenderingServer.ENV_SSIL_QUALITY_HIGH,
		"sdfgi": true,
		"sdfgi_rays": RenderingServer.ENV_SDFGI_RAY_COUNT_64,
		"sdfgi_update": RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_2_FRAMES,
		"gi_half": false,
		"ssr": true,
		"ssr_half": false,
		"volumetric": true,
		"dir_shadow": 8192,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"shadow_distance": 55.0,
		"shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"sun_angular": 0.5,
		"pos_atlas": 4096,
		"lamp_shadows": 6,
		"radiance": 256,
	},
]

static var forced := -1  ## --quality= (screenshots), wins over the settings file
static var _tier := -1
static var _cli_read := false


## Current tier: --quality=, else the one Settings.apply() set, else the settings file, else Alto.
static func tier() -> int:
	_read_cli()
	if forced >= 0:
		return forced
	if _tier < 0:
		var s = load("res://ui/front/settings.gd")
		_tier = clampi(int(s.load_cfg().get("quality", DEFAULT)), 0, NAMES.size() - 1)
	return _tier


static func set_tier(t: int) -> void:
	_tier = clampi(t, 0, NAMES.size() - 1)


static func spec(t := -1) -> Dictionary:
	return TIERS[clampi(t if t >= 0 else tier(), 0, TIERS.size() - 1)]


static func _read_cli() -> void:
	if _cli_read:
		return
	_cli_read = true
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--quality="):
			forced = parse(a.substr(10))


## "2", "alto", "Ultra"... -> tier index (-1 if unknown).
static func parse(s: String) -> int:
	var v := s.strip_edges().to_lower()
	if v.is_valid_int():
		return clampi(int(v), 0, NAMES.size() - 1)
	for i in NAMES.size():
		if String(NAMES[i]).to_lower() == v or String(NAMES[i]).to_lower().replace("é", "e") == v:
			return i
	return -1


## Viewport + renderer settings of the tier (skipped headless: there is no renderer to tune).
static func apply_all(vp: Viewport, t := -1) -> void:
	if DisplayServer.get_name() == "headless":
		return
	apply_viewport(vp, t)
	apply_server(t)


static func apply_viewport(vp: Viewport, t := -1) -> void:
	if vp == null:
		return
	var s := spec(t)
	vp.scaling_3d_mode = int(s.scale_mode)
	vp.scaling_3d_scale = float(s.scale)
	vp.msaa_3d = int(s.msaa)
	vp.screen_space_aa = int(s.screen_aa)
	vp.use_taa = false
	vp.use_debanding = true  # night skies and lamp falloffs are long dark gradients
	vp.positional_shadow_atlas_size = int(s.pos_atlas)


static func apply_server(t := -1) -> void:
	var s := spec(t)
	RenderingServer.directional_shadow_atlas_set_size(int(s.dir_shadow), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(s.soft_shadows))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(s.soft_shadows))
	RenderingServer.environment_set_ssao_quality(
		int(s.ssao_quality), bool(s.ssao_half), 0.5, 2, 50.0, 300.0
	)
	RenderingServer.environment_set_ssil_quality(int(s.ssil_quality), true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_ssr_half_size(bool(s.ssr_half))
	RenderingServer.environment_set_sdfgi_ray_count(int(s.sdfgi_rays))
	RenderingServer.environment_set_sdfgi_frames_to_converge(
		RenderingServer.ENV_SDFGI_CONVERGE_IN_20_FRAMES
	)
	RenderingServer.environment_set_sdfgi_frames_to_update_light(int(s.sdfgi_update))
	RenderingServer.gi_set_use_half_resolution(bool(s.gi_half))
	RenderingServer.environment_set_volumetric_fog_volume_size(
		64 if int(t if t >= 0 else tier()) < ULTRA else 96, 64
	)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)


## Which screen-space / GI effects this Environment runs. `want` is what the look asks for
## {"ssao", "ssil", "sdfgi", "ssr", "volumetric"} -> bool; by default the flags the env had the
## first time it came through here (kept in its "gfx_want" meta, so re-applying after a tier
## change can turn effects back on).
static func apply_env(env: Environment, t := -1, want := {}) -> void:
	if env == null:
		return
	var s := spec(t)
	if not env.has_meta("gfx_want") or not want.is_empty():
		var first := {
			"ssao": env.ssao_enabled,
			"ssil": env.ssil_enabled,
			"sdfgi": env.sdfgi_enabled,
			"ssr": env.ssr_enabled,
			"volumetric": env.volumetric_fog_enabled,
		}
		if env.has_meta("gfx_want"):
			first = env.get_meta("gfx_want")
		for k in want:
			first[k] = bool(want[k])
		env.set_meta("gfx_want", first)
	var w: Dictionary = env.get_meta("gfx_want")
	env.sdfgi_enabled = bool(s.sdfgi) and bool(w.sdfgi)
	env.ssao_enabled = bool(s.ssao) and bool(w.ssao)
	env.ssil_enabled = bool(s.ssil) and bool(w.ssil) and not env.sdfgi_enabled
	env.ssr_enabled = bool(s.ssr) and bool(w.ssr)
	env.volumetric_fog_enabled = bool(s.volumetric) and bool(w.volumetric)


## Keeps a scene's Environment (a battle or training stage outside the overworld) in line with
## the tier: applies it now and again whenever the tier changes (a small child node in the
## "gfx_quality" group). The look still decides what it wants; the tier only forbids.
static func track(we: WorldEnvironment) -> void:
	if we == null or we.get_node_or_null("GfxQualityEnv"):
		return
	var n := _EnvTracker.new()
	n.name = "GfxQualityEnv"
	we.add_child(n)
	apply_env(we.environment)


## Shadow distance, splits and PCSS size of a sun / moon. far_mult > 1 for zones whose camera
## looks far (low pitch, camera_far > 220).
static func apply_sun(light: DirectionalLight3D, t := -1, far_mult := 1.0) -> void:
	if light == null:
		return
	var s := spec(t)
	light.directional_shadow_max_distance = float(s.shadow_distance) * far_mult
	light.directional_shadow_mode = int(s.shadow_splits)
	light.directional_shadow_blend_splits = (
		int(s.shadow_splits) != (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	)
	light.directional_shadow_fade_start = 0.85
	light.light_angular_distance = float(s.sun_angular)


## Street lamps (nearest to the camera focus) allowed to cast shadows.
static func lamp_shadows(t := -1) -> int:
	return int(spec(t).lamp_shadows)


static func radiance_size(t := -1) -> int:
	match int(spec(t).radiance):
		32:
			return Sky.RADIANCE_SIZE_32
		64:
			return Sky.RADIANCE_SIZE_64
		256:
			return Sky.RADIANCE_SIZE_256
	return Sky.RADIANCE_SIZE_128


## Child of a tracked WorldEnvironment (track()): re-applies the tier when it changes.
class _EnvTracker:
	extends Node

	func _ready() -> void:
		add_to_group(GfxQuality.GROUP)

	func apply_quality() -> void:
		var we := get_parent() as WorldEnvironment
		if we:
			GfxQuality.apply_env(we.environment)
