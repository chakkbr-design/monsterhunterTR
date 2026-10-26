class_name WorldWeather
extends Node3D
## World weather. Replaces the old single daily shower with a real schedule (WeatherSchedule,
## data/weather.json): clear, cloudy, overcast, rain, storm, snow and light morning mist, picked
## by weight for spells of each game day (seeded by the day, so a day always has the same
## weather), at any hour, blending between spells. The ground follows in game time: it gets wet
## and dries after the rain, puddles linger longer, snow settles and melts.
## What it drives:
## - shader globals (docs/VOXEL.md §3): rain_amount, rain_wet, rain_puddle, snow_cover,
##   cloud_cover, lightning_flash; and the old weather_map texel for the HGSS shaders
##   (R wet, G snow, B mist or the battle's sand/fog, A cloud). Only written when they change;
## - WorldTimeOfDay reads `cloud` (dims the sun and moon, softens shadows, greys and lifts the
##   ambient), `gloom` (storm darkness) and `flash` (lightning) on every write;
## - WorldWind gets the storm wind (`storm`): stronger and gustier; the rain slants with it;
## - a WeatherRig following the camera focus (rain with splashes stopping on roofs, snow that
##   settles, ground mist), WeatherLightning in storms and WeatherAudio (rain, roof, wind, thunder).
## Indoors (teleported rooms) nothing falls and the globals read dry, but the outside keeps
## evolving, and the rain is heard muffled through the roof. A battle's weather (BattleWeatherFx)
## is merged in through battle_cover.
## Force a type with --weather=<id> (clear, cloudy, overcast, rain, storm, snow, mist; "off" =
## clear), `WorldWeather.forced` or the F9 sky panel; snap() jumps straight to its settled look.
## Ground mist can be switched off (Caio's no-veil rule): `mist_enabled`, saved in settings.cfg.

const GROUP := "weather"
const FORCE_FADE := 3.0  ## real seconds to fade into a type picked in the F9 panel
const JUMP_MIN := 30.0  ## game minutes: a bigger clock jump re-settles the weather
const RAIN_NORM := 0.62  ## the "rain" type's intensity: `wet` = 1 at ordinary rain
const MIST_MAX := 0.85
const STORM_WIND := 3.0  ## m/s of extra rain slant per unit of storm wind
const SETTINGS := "user://settings.cfg"

static var forced := ""
static var mist_enabled := true
static var _mist_loaded := false

## Battle weather (BattleWeatherFx): (wet, snow, fog, cloud) on top of the world's while it lasts.
var battle_cover := Color(0, 0, 0, 0)
var schedule: WeatherSchedule
var state := {}  ## WeatherSchedule.empty_state() keys
var type := "clear"  ## the spell now (or the forced type)
var wet := 0.0  ## how hard it rains (1 = ordinary rain); old API (follower, halos)
var cloud := 0.0
var gloom := 0.0
var flash := 0.0
var mist := 0.0
var indoor := false
var rig: WeatherRig
var lightning: WeatherLightning
var audio: WeatherAudio

var _forced_was := "<unset>"
var _fade_t := 1.0
var _fade_from := {}
var _fade_to := {}
var _last_now := -1.0
var _published := {}
var _cov := Color(-1, 0, 0, 0)
var _lightning_gap := Vector2(6.0, 16.0)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GfxQuality.GROUP)
	process_priority = -1  # before WorldTimeOfDay, so its write sees this frame's cloud and flash
	schedule = WeatherSchedule.shared()
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--weather="):
			forced = a.substr(10)
	if forced == "off":
		forced = "clear"
	load_mist_option()
	rig = WeatherRig.make({"name": "Rig", "area": Vector2(18.0, 18.0), "follow": true})
	add_child(rig)
	lightning = WeatherLightning.new()
	lightning.name = "Lightning"
	lightning.driven = true
	add_child(lightning)
	audio = WeatherAudio.new()
	audio.name = "Audio"
	add_child(audio)
	lightning.thunder.connect(_on_thunder)
	state = WeatherSchedule.empty_state()
	snap()


## Reads the ground-mist option (settings.cfg [video] weather_mist, default on).
static func load_mist_option() -> void:
	if _mist_loaded:
		return
	_mist_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		mist_enabled = bool(cf.get_value("video", "weather_mist", true))


## Switches the ground mist and saves the choice next to the other video options.
static func set_mist_option(on: bool, path := SETTINGS) -> void:
	mist_enabled = on
	_mist_loaded = true
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("video", "weather_mist", on)
	cf.save(path)


## [[id, label], ...] for the F9 sky panel: automatic, then every type.
func debug_choices() -> Array:
	var out: Array = [["", "Auto"]]
	out.append_array(schedule.names())
	return out


## Jumps to the settled weather of now (no fade): start of a session, screenshots, tests.
func snap() -> void:
	_forced_was = forced
	_fade_t = 1.0
	var now := _now()
	_last_now = now
	state = schedule.settled(now, _forced_id(), _sun())
	_derive()
	_publish(true)


func _forced_id() -> String:
	return forced if schedule.has_type(forced) else ""


func _tod() -> WorldTimeOfDay:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP) as WorldTimeOfDay


## Game minute now (minutes since the week began; the pinned hour when the clock is forced).
func _now() -> float:
	var tod := _tod()
	if tod == null:
		return WorldTimeOfDay.START_MIN
	return floorf(tod.total / 1440.0) * 1440.0 + tod.minutes


func _sun() -> float:
	var tod := _tod()
	if tod == null or tod.state.is_empty():
		return 0.5
	return clampf(float(tod.state.get("sun_visible", 0.0)), 0.0, 1.0)


## Snow lying on the ground here (0..1, 0 indoors): what this node publishes as the snow_cover
## global, a battle's snow included. VoxelZone polls it to bury its flowers and tall grass (the
## globals cannot be read back at runtime).
func snow_cover() -> float:
	if indoor:
		return 0.0
	return clampf(maxf(float(state.get("snow_cover", 0.0)), battle_cover.g), 0.0, 1.0)


## (wet, snow) where the camera is: ambient particles (pollen, fireflies) hide in rain and snow.
func camera_cover() -> Dictionary:
	if indoor:
		return {"wet": 0.0, "snow": 0.0}
	return {"wet": wet, "snow": clampf(float(state.get("snow", 0.0)) / 0.85, 0.0, 1.0)}


func _process(delta: float) -> void:
	var tod := _tod()
	indoor = tod.indoor if tod else false
	var now := _now()
	if forced != _forced_was:
		_start_fade()
	if _fade_t < 1.0:
		_fade_t = minf(1.0, _fade_t + delta / FORCE_FADE)
		var t := smoothstep(0.0, 1.0, _fade_t)
		for k in _fade_to:
			state[k] = lerpf(float(_fade_from[k]), float(_fade_to[k]), t)
		_last_now = now
	else:
		var dtm := now - _last_now
		if dtm < 0.0 or dtm > JUMP_MIN:
			state = schedule.settled(now, _forced_id(), _sun())
		elif dtm > 0.0:
			schedule.step(state, schedule.target(now, _forced_id()), dtm, _sun() * (1.0 - cloud))
		_last_now = now
	_derive()
	_update_lightning(delta)
	_update_rig(delta)
	_update_wind()
	_update_audio()
	_publish(false)


## A type picked in the F9 panel (or back to automatic): fade over FORCE_FADE s into its settled
## state (snow already lying, ground already wet).
func _start_fade() -> void:
	_forced_was = forced
	_fade_from = state.duplicate()
	_fade_to = schedule.settled(_now(), _forced_id(), _sun())
	_fade_t = 0.0


func _derive() -> void:
	var t := schedule.target(_now(), _forced_id())
	type = String(t.get("type", "clear"))
	var l = t.get("lightning", [])
	if l is Array and l.size() >= 2:
		_lightning_gap = Vector2(float(l[0]), float(l[1]))
	cloud = clampf(float(state.cloud), 0.0, 1.0)
	gloom = clampf(float(state.gloom), 0.0, 1.0)
	wet = clampf(float(state.rain) / RAIN_NORM, 0.0, 1.0)
	mist = minf(schedule.mist_of(state), MIST_MAX) if mist_enabled else 0.0


func _focus() -> Vector3:
	var rigf := get_tree().get_first_node_in_group("ow_camera") as Node3D
	if rigf:
		return rigf.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _update_lightning(delta: float) -> void:
	lightning.gap = _lightning_gap
	lightning.storm = clampf(float(state.storm), 0.0, 1.0) * smoothstep(0.5, 0.9, float(state.rain))
	var f := _focus()
	lightning.focus = f
	lightning.ground_y = f.y
	var cam := get_viewport().get_camera_3d()
	if cam:
		lightning.view_dir = -cam.global_transform.basis.z
	lightning.in_view_chance = 0.0 if indoor else 0.22
	lightning.visible = not indoor
	lightning.tick(delta)
	flash = 0.0 if indoor else lightning.flash


func _update_rig(delta: float) -> void:
	var on := not indoor
	rig.visible = on
	rig.rain = float(state.rain) if on else 0.0
	rig.snow = float(state.snow) if on else 0.0
	rig.mist = mist if on else 0.0
	rig.wind = wind_vector()
	rig.update(_focus(), get_viewport().get_camera_3d(), delta)


## Horizontal wind for the rain and snow (m/s): the shared wind direction, stronger in storms and
## in gusts.
func wind_vector() -> Vector2:
	var w := get_tree().get_first_node_in_group(WorldWind.GROUP) as WorldWind
	var d := w.dir if w else Vector2(1.0, -0.35).normalized()
	var g := w.gust() if w else 0.0
	return d * (0.6 + STORM_WIND * float(state.wind) + (1.2 + 2.5 * float(state.wind)) * g)


func _update_wind() -> void:
	var w := get_tree().get_first_node_in_group(WorldWind.GROUP) as WorldWind
	if w:
		w.storm = clampf(float(state.wind), 0.0, 2.0)


func _update_audio() -> void:
	audio.indoor = indoor
	audio.rain = clampf(float(state.rain), 0.0, 1.0)
	audio.wind = float(state.wind)
	var w := get_tree().get_first_node_in_group(WorldWind.GROUP) as WorldWind
	audio.gust = w.gust() if w else 0.0


func _on_thunder(distance: float, power: float) -> void:
	audio.thunder(distance, power)


## Graphics tier changed: particle amounts follow the new budget.
func apply_quality() -> void:
	if rig:
		rig.set_budget(GfxQuality.particles())


## Writes the globals and the HGSS coverage texel when they changed.
func _publish(force: bool) -> void:
	var out := indoor
	var rain := 0.0 if out else clampf(float(state.rain), 0.0, 1.0)
	var gw := 0.0 if out else float(state.wet)
	var pud := 0.0 if out else float(state.puddle_level)
	var snow := 0.0 if out else float(state.snow_cover)
	var cl := 0.0 if out else cloud
	var fog := 0.0 if out else mist
	var world_wet := gw
	var b := battle_cover if not out else Color(0, 0, 0, 0)
	if not out:
		gw = maxf(gw, b.r)
		pud = maxf(pud, smoothstep(0.5, 1.0, b.r) * 0.6)
		snow = maxf(snow, b.g)
		cl = maxf(cl, b.a)
	var dry := 1.0 - 0.85 * clampf(snow, 0.0, 1.0)  # snow lying on the ground hides the wet
	_global("rain_amount", rain, force)
	_global("rain_wet", clampf(gw * dry, 0.0, 1.0), force)
	_global("rain_puddle", clampf(pud * (1.0 - snow), 0.0, 1.0), force)
	_global("snow_cover", clampf(snow, 0.0, 1.0), force)
	_global("cloud_cover", clampf(cl, 0.0, 1.0), force)
	_global("lightning_flash", clampf(flash, 0.0, 1.0), force)
	# HGSS texel as the base had it: only the world's own wet is scaled by 0.8, the battle's wet
	# (Rain Dance, Drizzle) and its sand/fog (B) go in unscaled, on top of the world's.
	var cov := Color(
		maxf(clampf(world_wet * dry, 0.0, 1.0) * 0.8, clampf(b.r, 0.0, 1.0)),
		clampf(snow, 0.0, 1.0),
		clampf(maxf(fog, b.b), 0.0, 1.0),
		clampf(cl, 0.0, 1.0)
	)
	if force or not cov.is_equal_approx(_cov):  # texture upload only when the coverage changes
		_cov = cov
		WorldFx.set_weather(cov)


func _global(n: String, v: float, force: bool) -> void:
	if not force and _published.has(n) and absf(float(_published[n]) - v) < 0.0005:
		return
	_published[n] = v
	RenderingServer.global_shader_parameter_set(n, v)


## Last value written to a global by this node (tests; -1 if never written).
func published(n: String) -> float:
	return float(_published.get(n, -1.0))
