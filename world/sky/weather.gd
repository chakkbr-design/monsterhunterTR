class_name WorldWeather
extends Node3D
## Simplified port of the original weather.gd + rain.gd. The original drifts weather cells over a
## coverage map; here the whole outdoor world shares one coverage value (wet, snow, fog, cloud),
## published through the same weather_map shader global, so every ported shader (ground, paths,
## foliage, props) gets the original's wet look and puddles. data/weather.json "demo" mode: one
## rain shower per game day, starting between demo_rain.start_min and start_max and lasting
## demo_rain.life_hours. Force with --weather=rain|clear or `WorldWeather.forced`.

const GROUP := "weather"
const DATA := "res://data/weather.json"
const FADE_MIN := 6.0  ## game minutes to fade in/out

static var forced := ""

var wet := 0.0
var cloud := 0.0
var indoor := false

var _start := 690.0
var _len := 120.0
var _day := -1
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _cfg: Dictionary = {}
var _cov := Color(-1, 0, 0, 0)


func _ready() -> void:
	add_to_group(GROUP)
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_cfg = d if d is Dictionary else {}
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--weather="):
			forced = a.substr(10)
	_build_rain()
	_build_splash()


## (wet, snow) where the camera is: ambient particles hide in the rain.
func camera_cover() -> Dictionary:
	return {"wet": 0.0 if indoor else wet, "snow": 0.0}


static func _min(s: String) -> float:
	var hm := s.split(":")
	return int(hm[0]) * 60.0 + (int(hm[1]) if hm.size() > 1 else 0)


func _target(minutes: float, day: int) -> float:
	if forced == "rain":
		return 1.0
	if forced == "clear" or String(_cfg.get("mode", "demo")) != "demo":
		return 0.0
	if day != _day:
		_day = day
		var dr: Dictionary = _cfg.get("demo_rain", {})
		var rng := RandomNumberGenerator.new()
		rng.seed = day * 7919 + 13
		_start = rng.randf_range(_min(String(dr.get("start_min", "11:30"))), _min(String(dr.get("start_max", "14:00"))))
		_len = float(dr.get("life_hours", 2.0)) * 60.0
	var t := minutes - _start
	if t < 0.0 or t > _len:
		return 0.0
	return clampf(minf(t, _len - t) / FADE_MIN, 0.0, 1.0)


func _process(delta: float) -> void:
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP) as WorldTimeOfDay
	var minutes := tod.minutes if tod else 600.0
	var g := get_node_or_null("/root/Game")
	var day := int((WorldTimeOfDay.START_MIN + (float(g.play_time) if g else 0.0) * 20.0 / 60.0) / 1440.0)
	var target := _target(minutes, day)
	wet = move_toward(wet, target, delta * 0.25)
	cloud = wet * 0.7
	indoor = tod.indoor if tod else false
	var rains := wet * 0.8 if not indoor else 0.0
	var cov := Color(rains, 0.0, 0.0, cloud if not indoor else 0.0)
	if cov != _cov:  # texture upload only when the coverage changes, not every frame
		_cov = cov
		WorldFx.set_weather(cov)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain.global_position = cam.global_position + Vector3(0, 6.0, 0)
		var rig := get_tree().get_first_node_in_group("ow_camera") as Node3D
		var focus := rig.global_position if rig else cam.global_position
		_splash.global_position = focus + Vector3(0, 0.05, 0)
	_rain.amount_ratio = clampf(rains, 0.0, 1.0)
	_rain.emitting = rains > 0.02
	_splash.amount_ratio = clampf(rains, 0.0, 1.0)
	_splash.emitting = rains > 0.15


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.local_coords = false
	_rain.emitting = false
	_rain.amount = 1200
	_rain.amount_ratio = 0.0
	_rain.lifetime = 1.0
	_rain.preprocess = 1.0
	_rain.visibility_aabb = AABB(Vector3(-18, -14, -18), Vector3(36, 24, 36))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15.0, 0.5, 15.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0.0, -8.0, 0.0)
	_rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.84, 0.92, 0.5)
	q.material = m
	_rain.draw_pass_1 = q
	add_child(_rain)


func _build_splash() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "Splashes"
	_splash.local_coords = false
	_splash.emitting = false
	_splash.amount = 240
	_splash.amount_ratio = 0.0
	_splash.lifetime = 0.45
	_splash.visibility_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 3, 24))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.05, 10.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, -1.5, 0.0)
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.scale_min = 1.0
	pm.scale_max = 1.7
	var ac := Curve.new()
	ac.add_point(Vector2(0.0, 0.0))
	ac.add_point(Vector2(0.15, 1.0))
	ac.add_point(Vector2(1.0, 0.0))
	var act := CurveTexture.new()
	act.curve = ac
	pm.alpha_curve = act
	_splash.process_material = pm
	var q := PlaneMesh.new()
	q.size = Vector2(0.13, 0.13)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _ring_texture()
	m.albedo_color = Color(0.75, 0.82, 0.92, 0.55)
	q.material = m
	_splash.draw_pass_1 = q
	add_child(_splash)


static func _ring_texture() -> ImageTexture:
	var n := 16
	var c := (n - 1) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var a := smoothstep(0.45, 0.7, d) * (1.0 - smoothstep(0.85, 1.05, d))
			img.set_pixel(x, y, Color(0.86, 0.93, 1.0, a))
	return ImageTexture.create_from_image(img)
