class_name WorldTimeOfDay
extends Node
## Port of the original time_of_day.gd + clock.gd + the look part of zone_streamer.gd.
## - Clock (original clock.gd): game minutes advance at data/time.json "scale" (20x) from MON 9:00
##   (game_state.gd DEFAULT_CLOCK_MINUTES 540), only while the player is free (stops with the menu,
##   dialogue, cutscenes and door fades, clock.gd should_run). Kept in Game.flags["clock_minutes"]
##   (saved); periods come from time.json. clock_label() is the HUD text ("SEG 9:00").
## - Look: on every location change the zone's `look` (data/world.json, same as the map JSON) picks
##   the environment (world/look/*.tres, converted from the original), sun energy, fog, ground tints
##   and the camera (distance / yaw / pitch / far). Interiors use interior_env.
## - Period presets (data/time_of_day.json) MODULATE that look and blend over blend_secs:
##   sun angle/colour/energy, sky, ambient, fog, post-fx toning, ground tint, lamps/windows/fireflies.
## Force a period with --period=<id> on the command line or `WorldTimeOfDay.forced_period`.

const GROUP := "time_of_day"
const DATA := "res://data/time_of_day.json"
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

static var forced_period := ""  ## tests / screenshots

var presets := {}
var blend_secs := 25.0
var period := DEFAULT_PERIOD
var minutes := START_MIN  ## time of day, 0..1440
var total := START_MIN  ## minutes since the week began (day of the week = total / 1440)
var indoor := false
var look: Dictionary = {}

var _scale := 20.0
var _periods: Array = []  ## [[start_min, id], ...] sorted
var _sun: DirectionalLight3D
var _env_node: WorldEnvironment
var _env: Environment
var _post: WorldPostFx
var _base := {}
var _from := {}
var _to := {}
var _t := 1.0
var _blend := 0.0
var _lamps := 0.0
var _windows := 0.0
var _fireflies := 0.0
var _shafts := 1.0
var _elev := 21.75
var _azim := 217.21
var _check := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	var ow := get_parent()
	_sun = ow.get_node_or_null("Sun") as DirectionalLight3D
	_env_node = ow.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_post = ow.get_node_or_null("PostFX") as WorldPostFx
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if d is Dictionary:
		presets = d.get("periods", {})
		blend_secs = float(d.get("blend_secs", 25.0))
	var t = JSON.parse_string(FileAccess.get_file_as_string(TIME))
	if t is Dictionary:
		_scale = float(t.get("scale", 20.0))
		for p in t.get("periods", []):
			var hm := String(p.start).split(":")
			_periods.append([int(hm[0]) * 60 + int(hm[1]), String(p.id)])
		_periods.sort_custom(func(a, b): return a[0] < b[0])
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--period="):
			forced_period = a.substr(9)
	_load_clock()
	_tick_clock()
	period = _period_now()


## Game clock "HH:MM".
func clock_text() -> String:
	return "%02d:%02d" % [int(minutes / 60.0) % 24, int(minutes) % 60]


## HUD clock like the original Clock.format: "SEG 9:00".
func clock_label() -> String:
	return format_clock(total)


static func format_clock(m: float) -> String:
	var day := int(fposmod(m, 10080.0) / 1440.0)
	var hm := fposmod(m, 1440.0)
	return "%s %d:%02d" % [DAYS[day], int(hm / 60.0), int(hm) % 60]


## Day index since the start (weather picks its day by it).
func day() -> int:
	return int(total / 1440.0)


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
func should_run() -> bool:
	var p := get_tree().get_first_node_in_group(OverworldPlayer.GROUP) as OverworldPlayer
	if p == null or p.ui_blocking():
		return false
	var hud := get_tree().get_first_node_in_group(WorldHud.GROUP) as WorldHud
	if hud and hud.is_dialog_open():
		return false
	var ow := get_parent()
	return not (ow and "traveling" in ow and ow.traveling)


func _advance(delta: float) -> void:
	var g := get_node_or_null("/root/Game")
	if g == null:
		return
	if g.flags.get(CLOCK_FLAG) is float or g.flags.get(CLOCK_FLAG) is int:
		total = float(g.flags[CLOCK_FLAG])  # a load or a script may have changed it
	if should_run():
		total += delta / maxf(Engine.time_scale, 0.0001) * _scale / 60.0
		g.flags[CLOCK_FLAG] = total


func _tick_clock() -> void:
	minutes = fposmod(total, 1440.0)
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


## Called by RouteWorld on every location change. `zone_look` = the zone's look dictionary.
func apply_location(zone_look: Dictionary, is_indoor: bool) -> void:
	look = zone_look
	indoor = is_indoor
	if _env_node:
		var path := WorldFx.env_path(String(look.get("env", "")))
		if indoor:
			path = (
				"res://world/look/cave_env.tres"
				if _is_cave()
				else "res://world/look/interior_env.tres"
			)
		_env = (load(path) as Environment).duplicate(true)
		if not indoor and look.has("fog_density"):
			_env.fog_density = float(look.fog_density)
		_env_node.environment = _env
		_env_node.camera_attributes = null
	_capture_base()
	_apply_camera()
	apply_period(DEFAULT_PERIOD if indoor else _period_now(), 0.0)


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


func _capture_base() -> void:
	if _env == null:
		return
	var g: Dictionary = look.get("ground", {}) if not indoor else {}
	var gb := {}
	for k in GROUND_TINTS:
		gb[k] = Color(String(g[k])) if g.has(k) else GROUND_TINTS[k]
	gb["desaturate"] = float(g.get("desaturate", 0.0))
	_base = {
		"sun_energy":
		(
			(CAVE_SUN if _is_cave() else INDOOR_SUN)
			if indoor
			else float(look.get("sun_energy", DEFAULT_SUN))
		),
		"sky_top": _sky(_env, "sky_top_color"),
		"sky_horizon": _sky(_env, "sky_horizon_color"),
		"ambient": _env.ambient_light_color,
		"ambient_energy": _env.ambient_light_energy,
		"fog_color": _env.fog_light_color,
		"fog_density": _env.fog_density,
		"shadow_tint": Color(0.36, 0.42, 0.6),
		"highlight_tint": Color(1.0, 0.9, 0.72),
		"ground": gb,
	}


func apply_period(name: String, secs := 25.0) -> void:
	if not presets.has(name):
		name = DEFAULT_PERIOD
	if not presets.has(name) or _base.is_empty():
		return
	period = name
	_to = _resolve(name)
	_from = _current()
	_blend = secs
	_t = 0.0
	if secs <= 0.0:
		_t = 1.0
		_write(_to)


func night_mult() -> Dictionary:
	return {"lamps": _lamps, "windows": _windows}


func fireflies_mult() -> float:
	return _fireflies


func shafts_mult() -> float:
	return _shafts


func _process(delta: float) -> void:
	_advance(delta)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_tick_clock()
		if not indoor:
			var p := _period_now()
			if p != period:
				apply_period(p, blend_secs)
	if _t >= 1.0 or _base.is_empty():
		return
	_t = minf(1.0, _t + delta / maxf(_blend, 0.0001))
	_write(_to if _t >= 1.0 else _lerp(_from, _to, _t))


static func sun_color(el: float) -> Color:
	var horizon := Color(1.0, 0.55, 0.3)
	var golden := Color(1.0, 0.86, 0.62)
	var noon := Color(1.0, 0.97, 0.92)
	if el < 20.0:
		return horizon.lerp(golden, clampf(el / 20.0, 0.0, 1.0))
	return golden.lerp(noon, clampf((el - 20.0) / 40.0, 0.0, 1.0))


static func to_sun(el_deg: float, az_deg: float) -> Vector3:
	var el := deg_to_rad(el_deg)
	var az := deg_to_rad(az_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


func _resolve(name: String) -> Dictionary:
	var p: Dictionary = presets[name]
	var b := _base
	var el := float(p.sun_elevation)
	var d := {
		"sun_elevation": el,
		"sun_azimuth": float(p.sun_azimuth),
		"sun_color": sun_color(el).lerp(Color(String(p.sun_color)), float(p.sun_color_weight)),
		"sun_energy": float(b.sun_energy) * float(p.sun_energy_mult),
		"sky_top": (b.sky_top as Color).lerp(Color(String(p.sky_top)), float(p.sky_top_weight)),
		"sky_horizon":
		(b.sky_horizon as Color).lerp(Color(String(p.sky_horizon)), float(p.sky_horizon_weight)),
		"ambient":
		(b.ambient as Color).lerp(Color(String(p.ambient_color)), float(p.ambient_weight)),
		"ambient_energy": float(b.ambient_energy) * float(p.ambient_energy_mult),
		"fog_color": (b.fog_color as Color).lerp(Color(String(p.fog_color)), float(p.fog_weight)),
		"fog_density": float(b.fog_density) * float(p.fog_density_mult),
		"shadow_tint":
		(b.shadow_tint as Color).lerp(Color(String(p.shadow_tint)), float(p.post_weight)),
		"highlight_tint":
		(b.highlight_tint as Color).lerp(Color(String(p.highlight_tint)), float(p.post_weight)),
		"shadow_blur": float(p.shadow_blur),
		"shafts": float(p.shafts),
		"lamps": float(p.get("lamps", 0.0)),
		"windows": float(p.get("windows", 0.0)),
		"fireflies": float(p.get("fireflies", 0.0)),
	}
	var gm := Color(String(p.ground_mult))
	var gb: Dictionary = b.ground
	for k in GROUND_TINTS:
		d["ground_" + k] = (gb[k] as Color) * gm
	d["ground_desaturate"] = float(gb.desaturate) + float(p.ground_desaturate)
	return d


func _current() -> Dictionary:
	var d := {
		"sun_elevation": _elev,
		"sun_azimuth": _azim,
		"sun_color": _sun.light_color if _sun else Color.WHITE,
		"sun_energy": _sun.light_energy if _sun else 1.0,
		"shadow_blur": _sun.shadow_blur if _sun else 0.25,
		"shafts": _shafts,
		"lamps": _lamps,
		"windows": _windows,
		"fireflies": _fireflies,
	}
	if _env:
		d["sky_top"] = _sky(_env, "sky_top_color")
		d["sky_horizon"] = _sky(_env, "sky_horizon_color")
		d["ambient"] = _env.ambient_light_color
		d["ambient_energy"] = _env.ambient_light_energy
		d["fog_color"] = _env.fog_light_color
		d["fog_density"] = _env.fog_density
	if _post:
		d["shadow_tint"] = _post.shadow_tint
		d["highlight_tint"] = _post.highlight_tint
	# Ground tints too (like the original), or they snap at the start of every period blend.
	for b in get_tree().get_nodes_in_group("map_builder"):
		var gm: ShaderMaterial = b.ground_material
		if gm:
			for k in GROUND_TINTS:
				d["ground_" + k] = gm.get_shader_parameter(k)
			d["ground_desaturate"] = float(gm.get_shader_parameter("desaturate"))
			break
	return d


func _lerp(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var d := {}
	for k in b:
		var bv = b[k]
		var av = a.get(k, bv)
		d[k] = (av as Color).lerp(bv, t) if bv is Color else lerpf(float(av), float(bv), t)
	return d


func _write(d: Dictionary) -> void:
	_elev = float(d.sun_elevation)
	_azim = float(d.sun_azimuth)
	if _sun:
		var dir := -to_sun(_elev, _azim)
		_sun.global_transform.basis = Basis.looking_at(
			dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK
		)
		_sun.light_color = d.sun_color
		_sun.light_energy = float(d.sun_energy)
		_sun.shadow_blur = float(d.shadow_blur)
	if _env:
		_sky_set(_env, "sky_top_color", d.sky_top)
		_sky_set(_env, "sky_horizon_color", d.sky_horizon)
		_sky_set(_env, "ground_horizon_color", d.sky_horizon)
		_env.ambient_light_color = d.ambient
		_env.ambient_light_energy = float(d.ambient_energy)
		_env.fog_light_color = d.fog_color
		_env.fog_density = float(d.fog_density)
	if _post:
		_post.shadow_tint = d.shadow_tint
		_post.highlight_tint = d.highlight_tint
	var bs := get_tree().get_nodes_in_group("map_builder")
	for b in bs:
		var gm: ShaderMaterial = b.ground_material
		if gm == null:
			continue
		for k in GROUND_TINTS:
			if d.has("ground_" + k):
				gm.set_shader_parameter(k, d["ground_" + k])
		if d.has("ground_desaturate"):
			gm.set_shader_parameter("desaturate", float(d.ground_desaturate))
	if not bs.is_empty():  # (not MapBuilder by name: it would pull the Game autoload into --script tests)
		# The water's fake sky sheen and night dimming read these (the original's water_reflections.gd).
		var wm: ShaderMaterial = bs[0].water_material()
		wm.set_shader_parameter("sky_top", d.sky_top)
		wm.set_shader_parameter("sun_color", d.sun_color)
	_shafts = float(d.get("shafts", _shafts))
	_lamps = float(d.get("lamps", _lamps))
	_windows = float(d.get("windows", _windows))
	_fireflies = float(d.get("fireflies", _fireflies))
	for n in get_tree().get_nodes_in_group("night_lights"):
		n.set_period_mult(_lamps, _windows)
	for n in get_tree().get_nodes_in_group("sun_shafts"):
		n.set_period_mult(_shafts)
	for n in get_tree().get_nodes_in_group("fireflies"):
		n.set_period_mult(0.0 if indoor else _fireflies)
	for n in get_tree().get_nodes_in_group("day_ambient"):
		n.set_period_mult(0.0 if indoor else 1.0 - _fireflies)


## Re-applies the current period instantly (a newly built zone's ground material, night lights...).
func refresh() -> void:
	if not _base.is_empty() and presets.has(period):
		_to = _resolve(period)
		if _t >= 1.0:
			_write(_to)


static func _sky(env: Environment, prop: String) -> Color:
	if env and env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		return env.sky.sky_material.get(prop)
	return Color(0.5, 0.5, 0.5)


static func _sky_set(env: Environment, prop: String, c: Color) -> void:
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		env.sky.sky_material.set(prop, c)
