class_name WorldTimeOfDay
extends Node
## Port of the original time_of_day.gd + clock.gd + the look part of zone_streamer.gd, made
## continuous (docs/VOXEL.md):
## - Clock (original clock.gd): game minutes advance at data/time.json "scale" (20x) from MON 9:00
##   (game_state.gd DEFAULT_CLOCK_MINUTES 540), only while the player is free (stops with the menu,
##   dialogue, cutscenes and door fades, clock.gd should_run). Kept in Game.flags["clock_minutes"]
##   (saved). clock_label() is the HUD text ("SEG 9:00"). `period` (morning, midday, afternoon,
##   sunset, night) still comes from time.json for the systems that switch on it.
## - Sky: every frame the look follows the game minute through SkyCycle (data/time_of_day.json):
##   a sun on an arc from sunrise (06:00) to sunset (18:30), a separate moon light at night (they
##   never overlap, so shadows switch at zero energy), and colour keys from pre-dawn to night that
##   modulate the zone's look (sun colour / energy, sky, ambient, exposure, post-fx tints, ground
##   tints, lamps, windows). Indoors the look stays at the 12:30 identity like the original.
## - One persistent Environment: a location change copies the look's properties (world/look/*.tres
##   picked by the zone's look.env, interior_env / cave_env indoors) onto the live Environment
##   instead of swapping resources, so SDFGI and volumetric fog keep their caches. The live sky is
##   always world/sky/sky.gdshader; the look only gives its base colours. Two outdoor looks blend.
## - Publishes the shader globals night_lamps, night_windows, sun_dir_world, sun_color_world,
##   sun_amount, sky_top_color, sky_horizon_color when they change, drives the NightLights shadow
##   budget and halos, the graphics tier's environment flags (group "gfx_quality").
## Force the look with --period=<id>, --hour=HH:MM (pins the hour; with --time-scale it only sets
## the start), --time-scale=N (game minutes per real second), or the statics below (F9 sky panel).

const GROUP := "time_of_day"
const TIME := "res://data/time.json"
const DEFAULT_PERIOD := "midday"
const START_MIN := 540.0  ## MON 9:00 (original DEFAULT_CLOCK_MINUTES)
const CLOCK_FLAG := "clock_minutes"
const DAYS := ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"]  ## original clock.gd DAYS (MON..SUN)
const DEFAULT_SUN := 1.6
const INDOOR_SUN := 1.1
const CAVE_SUN := 0.12  ## roofless cave rooms: the sun must not light them like a house
const GROUND_TINTS := {
	"tint_a": Color(1, 1, 0.92), "tint_b": Color(0.78, 0.9, 0.78), "tint_c": Color(1.06, 1.02, 0.8)
}
const INDOOR_MINUTE := 750.0  ## interiors keep the 12:30 look (the keys' identity)
const LOOK_BLEND := 1.5  ## s to blend two outdoor looks (walking across a zone edge)
const WRITE_STEP := 0.04  ## game minutes between environment writes
const SKY_STEP := 0.5  ## game minutes between sky material writes
const SKY_SHADER := "res://world/sky/sky.gdshader"
const DEFAULT_ENV := "res://world/look/overworld_env.tres"
## Every outdoor look shares this SDFGI layout (changing it resets the cascades): 0.25 m cells to
## match the voxels, half height for flat towns.
const SDFGI_LAYOUT := {
	"sdfgi_cascades": 4,
	"sdfgi_min_cell_size": 0.25,
	"sdfgi_y_scale": Environment.SDFGI_Y_SCALE_50_PERCENT,
	"sdfgi_use_occlusion": true,
	"sdfgi_read_sky_light": true,
}
## Look properties copied onto the live Environment on a location change.
const COPY := [
	"background_mode",
	"background_color",
	"background_energy_multiplier",
	"ambient_light_source",
	"reflected_light_source",
	"tonemap_mode",
	"tonemap_white",
	"tonemap_agx_white",
	"tonemap_agx_contrast",
	"ssr_max_steps",
	"ssr_fade_in",
	"ssr_fade_out",
	"ssr_depth_tolerance",
	"ssao_radius",
	"ssao_intensity",
	"ssao_power",
	"ssao_detail",
	"ssao_horizon",
	"ssao_sharpness",
	"ssao_light_affect",
	"ssao_ao_channel_affect",
	"ssil_radius",
	"ssil_intensity",
	"ssil_sharpness",
	"ssil_normal_rejection",
	"sdfgi_bounce_feedback",
	"sdfgi_energy",
	"sdfgi_normal_bias",
	"sdfgi_probe_bias",
	"glow_enabled",
	"glow_levels/1",
	"glow_levels/2",
	"glow_levels/3",
	"glow_levels/4",
	"glow_levels/5",
	"glow_levels/6",
	"glow_levels/7",
	"glow_normalized",
	"glow_intensity",
	"glow_strength",
	"glow_mix",
	"glow_bloom",
	"glow_blend_mode",
	"glow_hdr_threshold",
	"glow_hdr_scale",
	"glow_hdr_luminance_cap",
	"glow_map_strength",
	"glow_map",
	"fog_enabled",
	"fog_mode",
	"fog_light_color",
	"fog_light_energy",
	"fog_sun_scatter",
	"fog_density",
	"fog_aerial_perspective",
	"fog_sky_affect",
	"fog_height",
	"fog_height_density",
	"fog_depth_curve",
	"fog_depth_begin",
	"fog_depth_end",
	"volumetric_fog_density",
	"volumetric_fog_albedo",
	"volumetric_fog_emission",
	"volumetric_fog_emission_energy",
	"volumetric_fog_gi_inject",
	"volumetric_fog_anisotropy",
	"volumetric_fog_length",
	"volumetric_fog_detail_spread",
	"volumetric_fog_ambient_inject",
	"volumetric_fog_sky_affect",
	"volumetric_fog_temporal_reprojection_enabled",
	"volumetric_fog_temporal_reprojection_amount",
	"adjustment_enabled",
	"adjustment_brightness",
	"adjustment_contrast",
	"adjustment_saturation",
	"adjustment_color_correction",
]

static var forced_period := ""  ## tests / screenshots (--period=)
static var forced_minutes := -1.0  ## pins the look and the HUD hour (--hour= alone, sky panel)
static var minutes_per_sec := -1.0  ## clock speed override (--time-scale=, sky panel); -1 = time.json
static var paused := false  ## sky panel: the clock stands still
## SDFGI outdoors: -1 = as the look asks (env sdfgi_enabled / metadata/sdfgi or look "sdfgi"),
## 0 = never, 1 = every outdoor look (--sdfgi=off|on, A/B screenshots of the HGSS zones).
static var sdfgi_override := -1

var cycle: SkyCycle
var period := DEFAULT_PERIOD
var minutes := START_MIN  ## time of day, 0..1440
var total := START_MIN  ## minutes since the week began (day of the week = total / 1440)
var indoor := false
var look: Dictionary = {}
var env: Environment  ## the persistent live Environment
var state := {}  ## last applied values (sun / moon angles and energies, exposure, lamps...)

var _scale := 20.0
var _periods: Array = []  ## [[start_min, id], ...] sorted
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env_node: WorldEnvironment
var _sky: Sky
var _sky_mat: ShaderMaterial
var _post: WorldPostFx
var _base := {}
var _base_from := {}
var _look_t := 1.0
var _env_from := {}  ## look property -> value before the blend
var _env_to := {}  ## look property -> value of the new look
var _lamps := 0.0
var _windows := 0.0
var _fireflies := 0.0
var _shafts := 1.0
var _check := 0.0
var _last_m := -1e9
var _last_sky_m := -1e9
var _last_cloud := -1.0
var _globals := {}
var _start_hour := -1.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GfxQuality.GROUP)
	cycle = SkyCycle.shared()
	var ow := get_parent()
	_sun = ow.get_node_or_null("Sun") as DirectionalLight3D
	_env_node = ow.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_post = ow.get_node_or_null("PostFX") as WorldPostFx
	var t = JSON.parse_string(FileAccess.get_file_as_string(TIME))
	if t is Dictionary:
		_scale = float(t.get("scale", 20.0))
		for p in t.get("periods", []):
			var hm := String(p.start).split(":")
			_periods.append([int(hm[0]) * 60 + int(hm[1]), String(p.id)])
		_periods.sort_custom(func(a, b): return a[0] < b[0])
	_read_cli()
	_make_lights_and_env()
	_load_clock()
	if _start_hour >= 0.0:
		set_minute(_start_hour)
	_tick_clock()
	period = _period_now()
	if _base.is_empty():
		_apply_look_env(load(DEFAULT_ENV) as Environment, false)
	_write(true)


func _read_cli() -> void:
	var hour := -1.0
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--period="):
			forced_period = a.substr(9)
		elif a.begins_with("--hour="):
			hour = SkyCycle.parse_hm(a.substr(7))
		elif a.begins_with("--time-scale="):
			minutes_per_sec = maxf(float(a.substr(13)), 0.0)
		elif a.begins_with("--sdfgi="):
			sdfgi_override = 1 if a.substr(8) in ["on", "1", "true"] else 0
	if hour >= 0.0:
		if minutes_per_sec >= 0.0:
			_start_hour = hour
		else:
			forced_minutes = hour


## The moon light, and the persistent Environment with the sky shader (built once).
func _make_lights_and_env() -> void:
	if _sun:
		_sun.light_volumetric_fog_energy = 0.0
		_sun.shadow_enabled = true
		_moon = DirectionalLight3D.new()
		_moon.name = "Moon"
		_moon.light_volumetric_fog_energy = 0.0
		_moon.shadow_blur = 1.6
		_moon.light_energy = 0.0
		_moon.shadow_enabled = false
		_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		add_child(_moon)
	if _env_node == null:
		return
	env = Environment.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load(SKY_SHADER)
	_sky = Sky.new()
	_sky.sky_material = _sky_mat
	_sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_sky.radiance_size = GfxQuality.radiance_size()
	env.sky = _sky
	_env_node.environment = env
	_env_node.camera_attributes = null


## Game clock "HH:MM".
func clock_text() -> String:
	return "%02d:%02d" % [int(minutes / 60.0) % 24, int(minutes) % 60]


## HUD clock like the original Clock.format: "SEG 9:00".
func clock_label() -> String:
	if forced_minutes >= 0.0:
		return format_clock(floorf(total / 1440.0) * 1440.0 + forced_minutes)
	return format_clock(total)


static func format_clock(m: float) -> String:
	var day := int(fposmod(m, 10080.0) / 1440.0)
	var hm := fposmod(m, 1440.0)
	return "%s %d:%02d" % [DAYS[day], int(hm / 60.0), int(hm) % 60]


## Day index since the start (weather picks its day by it).
func day() -> int:
	return int(total / 1440.0)


## Moves the clock to `m` minutes into the current day (sky panel, --hour with --time-scale).
## When the hour is pinned (forced_minutes), moves the pin instead.
func set_minute(m: float) -> void:
	m = fposmod(m, 1440.0)
	forced_period = ""
	if forced_minutes >= 0.0:
		forced_minutes = m
	else:
		total = floorf(total / 1440.0) * 1440.0 + m
		var g := get_node_or_null("/root/Game")
		if g:
			g.flags[CLOCK_FLAG] = total
	_tick_clock()
	period = _period_now()
	_write(true)


## Reads the saved clock (old saves without it: the old play_time clock, so the hour doesn't jump).
func _load_clock() -> void:
	var g := get_node_or_null("/root/Game")
	if g == null:
		return
	var v = g.flags.get(CLOCK_FLAG)
	if v is float or v is int:
		total = float(v)
	else:
		total = START_MIN + float(g.play_time) * _scale / 60.0 if g.play_time > 0.0 else START_MIN
		g.flags[CLOCK_FLAG] = total


## Original clock.gd should_run: a player on the map and no menu, dialogue, cutscene or transition.
## (Groups by name: naming OverworldPlayer / WorldHud here would pull the Game autoload into
## --script tests before it exists, and the statics below would start at zero.)
func should_run() -> bool:
	var p := get_tree().get_first_node_in_group("ow_player")
	if p == null or (p.has_method("ui_blocking") and p.ui_blocking()):
		return false
	var hud := get_tree().get_first_node_in_group("ow_hud")
	if hud and hud.has_method("is_dialog_open") and hud.is_dialog_open():
		return false
	var ow := get_parent()
	return not (ow and "traveling" in ow and ow.traveling)


## Game minutes per real second (time.json scale is game seconds per real second).
func speed() -> float:
	return minutes_per_sec if minutes_per_sec >= 0.0 else _scale / 60.0


func _advance(delta: float) -> void:
	var g := get_node_or_null("/root/Game")
	if g == null:
		return
	if g.flags.get(CLOCK_FLAG) is float or g.flags.get(CLOCK_FLAG) is int:
		total = float(g.flags[CLOCK_FLAG])  # a load or a script may have changed it
	if not paused and should_run():
		total += delta / maxf(Engine.time_scale, 0.0001) * speed()
		g.flags[CLOCK_FLAG] = total


func _tick_clock() -> void:
	minutes = forced_minutes if forced_minutes >= 0.0 else fposmod(total, 1440.0)
	RenderingServer.global_shader_parameter_set("weather_time", minutes)


func _period_now() -> String:
	if forced_period != "":
		return forced_period
	if _periods.is_empty():
		return DEFAULT_PERIOD
	var id: String = _periods[-1][1]  # before the first start = last period (night)
	for p in _periods:
		if minutes >= p[0]:
			id = p[1]
	return id


## Minute the outdoor look shows: a forced period's hour, the pinned hour or the clock.
func look_minute() -> float:
	if forced_period != "":
		var m := cycle.period_minute(forced_period)
		return m if m >= 0.0 else cycle.period_minute(DEFAULT_PERIOD)
	return minutes


## Called by RouteWorld on every location change. `zone_look` = the zone's look dictionary.
func apply_location(zone_look: Dictionary, is_indoor: bool) -> void:
	var was_outdoor := not indoor and not _base.is_empty()
	look = zone_look
	indoor = is_indoor
	var path := WorldFx.env_path(String(look.get("env", "")))
	if indoor:
		path = (
			"res://world/look/cave_env.tres" if _is_cave() else "res://world/look/interior_env.tres"
		)
	_apply_look_env(load(path) as Environment, was_outdoor and not indoor)
	if not indoor and look.has("fog_density") and env:
		if _env_to.has("fog_density"):
			_env_to["fog_density"] = float(look.fog_density)
		else:
			env.fog_density = float(look.fog_density)
	_apply_camera()
	period = _period_now()
	_write(true)


## Copies a look onto the live Environment and captures its base values.
func _apply_look_env(src: Environment, blend: bool) -> void:
	if src == null:
		src = load(DEFAULT_ENV) as Environment
	var old := _base.duplicate()
	_env_from = {}
	_env_to = {}
	if env:
		for p in COPY:
			var v = env.get(p)
			var to = src.get(p)
			if blend and not old.is_empty() and (v is float or v is Color) and v != to:
				_env_from[p] = v
				_env_to[p] = to
			else:
				env.set(p, to)
		if not indoor:
			for p in SDFGI_LAYOUT:
				env.set(p, SDFGI_LAYOUT[p])
		env.sky = _sky
	_capture_base(src)
	if blend and not old.is_empty():
		_base_from = old
		_look_t = 0.0
	else:
		_look_t = 1.0
	apply_quality()


## RouteWorld passes {"cave": true} for CaveBuilder rooms (room meta "cave_dark").
func _is_cave() -> bool:
	return indoor and bool(look.get("cave", false))


func _apply_camera() -> void:
	var rig = get_tree().get_first_node_in_group("ow_camera")
	if rig == null:
		return
	if indoor:
		rig.set_zone_look({})
	else:
		rig.set_zone_look(look)


func _capture_base(src: Environment) -> void:
	var g: Dictionary = look.get("ground", {}) if not indoor else {}
	var gb := {}
	for k in GROUND_TINTS:
		gb[k] = Color(String(g[k])) if g.has(k) else GROUND_TINTS[k]
	gb["desaturate"] = float(g.get("desaturate", 0.0))
	var sky := _sky_colors(src)
	_base = {
		"sun_energy":
		(
			(CAVE_SUN if _is_cave() else INDOOR_SUN)
			if indoor
			else float(look.get("sun_energy", src.get_meta("sun_energy", DEFAULT_SUN)))
		),
		"moon_energy": 0.0 if indoor else float(src.get_meta("moon_energy", 1.0)),
		"sky_top": sky[0],
		"sky_horizon": sky[1],
		"sky_ground": sky[2],
		"ambient": src.ambient_light_color,
		"ambient_energy": src.ambient_light_energy,
		"sky_contribution": src.ambient_light_sky_contribution,
		"exposure": src.tonemap_exposure,
		"sky_neutral": float(src.get_meta("sky_neutral", 0.0)),
		"shadow_tint": Color(0.36, 0.42, 0.6),
		"highlight_tint": Color(1.0, 0.9, 0.72),
		"halos": bool(src.get_meta("lamp_halos", false)) and not indoor,
		"sdfgi": not indoor and _wants_sdfgi(src),
		"ssr": not indoor and src.ssr_enabled,
		"ssao": src.ssao_enabled,
		"ssil": src.ssil_enabled,
		"ground": gb,
	}


func _wants_sdfgi(src: Environment) -> bool:
	if sdfgi_override >= 0:
		return sdfgi_override == 1
	return bool(look.get("sdfgi", src.sdfgi_enabled or bool(src.get_meta("sdfgi", false))))


## (top, horizon, ground) of a look's sky: ProceduralSkyMaterial colours, the sky shader's
## uniforms, or the background colour for rooms without a sky.
static func _sky_colors(src: Environment) -> Array:
	if src.sky and src.sky.sky_material is ProceduralSkyMaterial:
		var m: ProceduralSkyMaterial = src.sky.sky_material
		return [m.sky_top_color, m.sky_horizon_color, m.ground_bottom_color]
	if src.sky and src.sky.sky_material is ShaderMaterial:
		var s: ShaderMaterial = src.sky.sky_material
		return [
			_param(s, "top_color", Color(0.36, 0.55, 0.85)),
			_param(s, "horizon_color", Color(0.86, 0.86, 0.82)),
			_param(s, "ground_color", Color(0.28, 0.27, 0.24)),
		]
	var c := src.background_color
	return [c, c, c]


static func _param(m: ShaderMaterial, n: String, def: Color) -> Color:
	var v = m.get_shader_parameter(n)
	if v is Color:
		return v
	if v is Vector3:
		return Color(v.x, v.y, v.z)
	return def


## Graphics tier changed (Settings.apply -> group "gfx_quality") or a new look: environment
## flags, shadow distances, sky radiance, halos.
func apply_quality() -> void:
	if env and not _base.is_empty():
		var want := {
			"ssao": _base.ssao,
			"ssil": _base.ssil,
			"sdfgi": _base.sdfgi,
			"ssr": _base.ssr,
			"volumetric": _base.halos,
		}
		GfxQuality.apply_env(env, -1, want)
	if _sky:
		_sky.radiance_size = GfxQuality.radiance_size()
	var far := 2.0 if float(look.get("camera_far", 0.0)) > 220.0 and not indoor else 1.0
	GfxQuality.apply_sun(_sun, -1, far)
	GfxQuality.apply_sun(_moon, -1, far)
	NightLights.halos_on = (
		not _base.is_empty() and bool(_base.halos) and bool(GfxQuality.spec().volumetric)
	)
	NightLights.refresh_halos()
	_last_m = -1e9


func night_mult() -> Dictionary:
	return {"lamps": _lamps, "windows": _windows}


func fireflies_mult() -> float:
	return _fireflies


func shafts_mult() -> float:
	return _shafts


## Shows a period's hour (the original's API; forced_period does the same from tests).
func apply_period(name: String, _secs := 0.0) -> void:
	forced_period = name if cycle.period_minute(name) >= 0.0 else ""
	period = _period_now()
	_write(true)


func _process(delta: float) -> void:
	_advance(delta)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_tick_clock()
		period = _period_now()
	minutes = forced_minutes if forced_minutes >= 0.0 else fposmod(total, 1440.0)
	if _look_t < 1.0:
		_look_t = minf(1.0, _look_t + delta / LOOK_BLEND)
		_last_m = -1e9
		_blend_env()
	_write(false)
	var rig := get_tree().get_first_node_in_group("ow_camera") as Node3D
	var cam := get_viewport().get_camera_3d()
	var focus := rig.global_position if rig else (cam.global_position if cam else Vector3.ZERO)
	NightLights.update_budget(focus, 0 if indoor else GfxQuality.lamp_shadows(), delta)


## Numeric look properties (glow, AO, tonemap white, adjustments...) follow the look blend, so
## walking from a zone into its neighbour has no contrast pop (modes and flags switch at once).
func _blend_env() -> void:
	if env == null or _env_to.is_empty():
		return
	var t := smoothstep(0.0, 1.0, _look_t)
	for p in _env_to:
		var a = _env_from[p]
		var b = _env_to[p]
		env.set(p, (a as Color).lerp(b, t) if a is Color else lerpf(a, b, t))
	if _look_t >= 1.0:
		_env_to = {}


static func sun_color(el: float) -> Color:
	var horizon := Color(1.0, 0.55, 0.3)
	var golden := Color(1.0, 0.86, 0.62)
	var noon := Color(1.0, 0.97, 0.92)
	if el < 20.0:
		return horizon.lerp(golden, clampf(el / 20.0, 0.0, 1.0))
	return golden.lerp(noon, clampf((el - 20.0) / 40.0, 0.0, 1.0))


static func to_sun(el_deg: float, az_deg: float) -> Vector3:
	return SkyCycle.to_dir(el_deg, az_deg)


func _blended_base() -> Dictionary:
	if _look_t >= 1.0 or _base_from.is_empty():
		return _base
	var t := smoothstep(0.0, 1.0, _look_t)
	var d := _base.duplicate()
	for k in _base:
		var b = _base[k]
		var a = _base_from.get(k, b)
		if b is Color:
			d[k] = (a as Color).lerp(b, t)
		elif b is float:
			d[k] = lerpf(float(a), b, t)
	return d


func _cloud() -> float:
	if indoor or not is_inside_tree():
		return 0.0
	var w := get_tree().get_first_node_in_group("weather")
	return clampf(float(w.get("cloud")), 0.0, 1.0) if w and w.get("cloud") != null else 0.0


## Applies the look of the current minute. Without `force`, only when the minute moved WRITE_STEP
## (game minutes) since the last write, the cloud cover changed or two looks are blending.
func _write(force: bool) -> void:
	if _base.is_empty():
		return
	var lm := INDOOR_MINUTE if indoor else look_minute()
	var cloud := _cloud()
	if not force and absf(lm - _last_m) < WRITE_STEP and absf(cloud - _last_cloud) < 0.004:
		return
	_last_m = lm
	_last_cloud = cloud
	var k := cycle.sample(lm)
	if k.is_empty():
		return
	var real := k if not indoor else cycle.sample(look_minute())
	var b := _blended_base()
	var sa := cycle.sun_angles(lm)
	var ma := cycle.moon_angles(lm)
	var sv := SkyCycle.visibility(cycle.sun, sa.x)
	var mv := SkyCycle.visibility(cycle.moon, ma.x) * (0.0 if indoor else 1.0)
	var sun_dir := SkyCycle.to_dir(sa.x, sa.y)
	var moon_dir := SkyCycle.to_dir(ma.x, ma.y)
	var full := 1.0 - absf(_moon_phase() - 0.5) * 2.0
	var sun_e := float(b.sun_energy) * float(k.sun_energy) * sv * (1.0 - 0.72 * cloud)
	if indoor:
		sun_e = float(b.sun_energy) * float(k.sun_energy)
	var moon_e := (
		float(cycle.moon.energy)
		* float(b.moon_energy)
		* mv
		* (0.65 + 0.35 * full)
		* (1.0 - 0.8 * cloud)
	)
	var sun_col: Color = k.sun_color
	_set_light(_sun, sun_dir, sun_col, sun_e, float(k.shadow_blur) + cloud * 1.8)
	_set_light(_moon, moon_dir, cycle.moon.color, moon_e, 1.4 + cloud)
	# Environment.
	var top := (b.sky_top as Color).lerp(k.sky_top, float(k.sky_weight))
	var hor := (b.sky_horizon as Color).lerp(k.sky_horizon, float(k.sky_weight))
	var amb := (b.ambient as Color).lerp(k.ambient_color, float(k.ambient_weight))
	var lum := amb.get_luminance()
	amb = amb.lerp(Color(lum * 0.96, lum * 0.98, lum), cloud * 0.55)
	var amb_e := float(b.ambient_energy) * float(k.ambient_energy) * (1.0 + 0.12 * cloud)
	var expo := float(b.exposure) * float(k.exposure) * (1.0 + 0.1 * cloud)
	if env:
		env.ambient_light_color = amb
		env.ambient_light_energy = amb_e
		env.ambient_light_sky_contribution = clampf(
			float(b.sky_contribution) * float(k.sky_ambient), 0.0, 1.0
		)
		env.tonemap_exposure = expo
		_write_halos(real)
	_write_sky(lm, top, hor, b, k, [sun_dir, sv, moon_dir, cloud], force)
	if _post:
		var pw := float(k.post_weight)
		_post.shadow_tint = (b.shadow_tint as Color).lerp(k.shadow_tint, pw)
		_post.highlight_tint = (b.highlight_tint as Color).lerp(k.highlight_tint, pw)
	_write_ground(k)
	var bs := get_tree().get_nodes_in_group("map_builder") if is_inside_tree() else []
	if not bs.is_empty():  # (not MapBuilder by name: it would pull the Game autoload into --script tests)
		# The HGSS water's fake sky sheen and night dimming read these (the original's water_reflections.gd).
		var wm: ShaderMaterial = bs[0].water_material()
		wm.set_shader_parameter("sky_top", top)
		wm.set_shader_parameter("sun_color", sun_col.lerp(cycle.moon.color, 1.0 - sv))
	# Lamps and windows follow the real clock, indoors too (the street is lit when you come out).
	var lamps := float(real.lamps)
	var windows := float(real.windows)
	var night_changed := force or absf(lamps - _lamps) > 0.0005 or absf(windows - _windows) > 0.0005
	_lamps = lamps
	_windows = windows
	_shafts = float(k.shafts) * (1.0 - cloud)
	_fireflies = float(real.fireflies)
	if is_inside_tree():
		if night_changed:
			for n in get_tree().get_nodes_in_group("night_lights"):
				n.set_period_mult(_lamps, _windows)
		for n in get_tree().get_nodes_in_group("sun_shafts"):
			n.set_period_mult(_shafts)
		for n in get_tree().get_nodes_in_group("fireflies"):
			n.set_period_mult(0.0 if indoor else _fireflies)
		for n in get_tree().get_nodes_in_group("day_ambient"):
			n.set_period_mult(0.0 if indoor else (1.0 - _fireflies) * sv)
	# Globals: the key light is the sun by day and the moon by night (never both).
	var key_dir := sun_dir * sv + moon_dir * mv * 0.25
	if key_dir.length() < 0.01:
		key_dir = Vector3(sun_dir.x, maxf(sun_dir.y, 0.05), sun_dir.z)
	_global("night_lamps", lamps)
	_global("night_windows", windows)
	_global("sun_dir_world", key_dir.normalized())
	_global("sun_color_world", sun_col if sv >= mv * 0.25 else cycle.moon.color)
	_global("sun_amount", (sv + mv * 0.25) * (1.0 - cloud) * (0.0 if indoor else 1.0))
	_global("sky_top_color", top)
	_global("sky_horizon_color", hor)
	state = {
		"minute": lm,
		"sun_elevation": sa.x,
		"sun_azimuth": sa.y,
		"sun_energy": sun_e,
		"sun_visible": sv,
		"moon_elevation": ma.x,
		"moon_azimuth": ma.y,
		"moon_energy": moon_e,
		"moon_visible": mv,
		"exposure": expo,
		"ambient": amb,
		"ambient_energy": amb_e,
		"sky_top": top,
		"sky_horizon": hor,
		"lamps": lamps,
		"windows": windows,
		"cloud": cloud,
	}


func _set_light(l: DirectionalLight3D, to_body: Vector3, col: Color, e: float, blur: float) -> void:
	if l == null:
		return
	var dir := -to_body
	l.global_transform.basis = Basis.looking_at(
		dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
	)
	l.light_color = col
	l.light_energy = e
	l.shadow_blur = blur
	l.visible = e > 0.0005
	l.shadow_enabled = e > 0.0005


func _moon_phase() -> float:
	return fposmod(0.5 + float(day()) / 8.0, 1.0)


## Sky material (throttled to SKY_STEP game minutes: every write re-renders the radiance map).
## bodies = [sun_dir, sun_visible, moon_dir, cloud].
func _write_sky(
	lm: float, top: Color, hor: Color, b: Dictionary, k: Dictionary, bodies: Array, force: bool
) -> void:
	if _sky_mat == null:
		return
	if not force and absf(lm - _last_sky_m) < SKY_STEP and _look_t >= 1.0:
		return
	_last_sky_m = lm
	var cloud := float(bodies[3])
	var wind := get_tree().get_first_node_in_group("wind") if is_inside_tree() else null
	var wd: Vector2 = wind.dir if wind else Vector2(1, 0)
	var hl := maxf((b.sky_horizon as Color).get_luminance(), 0.01)
	var gf := clampf(hor.get_luminance() / hl, 0.04, 1.2)
	_sky_mat.set_shader_parameter("top_color", top)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("ground_color", (b.sky_ground as Color) * gf)
	_sky_mat.set_shader_parameter("sun_dir", bodies[0])
	_sky_mat.set_shader_parameter("sun_color", k.sun_color)
	_sky_mat.set_shader_parameter("sun_visible", bodies[1])
	_sky_mat.set_shader_parameter("moon_dir", bodies[2])
	_sky_mat.set_shader_parameter("moon_color", cycle.moon.color)
	_sky_mat.set_shader_parameter("moon_visible", smoothstep(-2.0, 4.0, cycle.moon_angles(lm).x))
	_sky_mat.set_shader_parameter("moon_phase", _moon_phase())
	_sky_mat.set_shader_parameter("stars", float(k.stars))
	_sky_mat.set_shader_parameter("haze", float(k.haze) * (1.0 - cloud))
	_sky_mat.set_shader_parameter("haze_color", k.sun_color)
	_sky_mat.set_shader_parameter(
		"cloud_offset", Vector2(fposmod(lm * 0.004, 64.0), 0.0).rotated(wd.angle())
	)
	var at: Color = k.ambient_color
	var al := maxf(at.get_luminance(), 0.05)
	# Half way to white: the pull is mostly toward neutral, only a hint of the key's ambient hue.
	var tint := Color(at.r / al, at.g / al, at.b / al).lerp(Color.WHITE, 0.5)
	_sky_mat.set_shader_parameter("ambient_tint", tint)
	_sky_mat.set_shader_parameter(
		"ambient_neutral",
		clampf(maxf(float(b.sky_neutral), float(k.get("sky_neutral", 0.0))), 0.0, 1.0)
	)


## Lamp halos: volumetric fog only while lamps are lit, on tiers that run it, outdoors in looks
## that ask for halos (voxel_env). Density follows the lamps and the rain.
func _write_halos(real: Dictionary) -> void:
	var lamps := float(real.lamps)
	var on := NightLights.halos_on and not indoor and lamps > 0.01
	if env.volumetric_fog_enabled != on:
		env.volumetric_fog_enabled = on
	if on:
		env.volumetric_fog_density = 0.0
		var w := get_tree().get_first_node_in_group("weather") if is_inside_tree() else null
		var wet := float(w.get("wet")) if w and w.get("wet") != null else 0.0
		NightLights.set_halo_density(lamps * (0.55 + 0.9 * wet))


## HGSS ground tints: every built zone keeps its own tints (captured the first time its material
## is seen) times the key's ground_mult.
func _write_ground(k: Dictionary) -> void:
	if not is_inside_tree():
		return
	var gm_mult: Color = k.ground_mult
	var desat := float(k.ground_desaturate)
	if indoor:
		gm_mult = Color.WHITE
		desat = 0.0
	for b in get_tree().get_nodes_in_group("map_builder"):
		var gm: ShaderMaterial = b.ground_material
		if gm == null:
			continue
		if not gm.has_meta("tod_base"):
			var base := {}
			for t in GROUND_TINTS:
				var v = gm.get_shader_parameter(t)
				base[t] = v if v is Color else GROUND_TINTS[t]
			var d = gm.get_shader_parameter("desaturate")
			base["desaturate"] = float(d) if d != null else 0.0
			gm.set_meta("tod_base", base)
		var tb: Dictionary = gm.get_meta("tod_base")
		for t in GROUND_TINTS:
			gm.set_shader_parameter(t, (tb[t] as Color) * gm_mult)
		gm.set_shader_parameter("desaturate", float(tb.desaturate) + desat)


func _global(n: String, v) -> void:
	var old = _globals.get(n)
	if old != null and typeof(old) == typeof(v):
		if v is float and absf(float(old) - float(v)) < 0.0002:
			return
		if v is Color and (old as Color).is_equal_approx(v):
			return
		if v is Vector3 and (old as Vector3).is_equal_approx(v):
			return
	_globals[n] = v
	RenderingServer.global_shader_parameter_set(n, v)


## Last value written to a shader global by this node (tests; null if never written).
func global_value(n: String):
	return _globals.get(n)


## Re-applies the current look instantly (a newly built zone's ground material, night lights...).
func refresh() -> void:
	_write(true)
