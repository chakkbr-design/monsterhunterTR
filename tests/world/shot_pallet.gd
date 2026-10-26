extends SceneTree
## Real-renderer screenshots of the voxel Pallet Town (not headless):
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan
##   --resolution 1600x900 --script res://tests/world/shot_pallet.gd -- --out=/tmp/shots
##   [--spots=start,plaza,...] [--periods=midday,night | --hours=12:30,18:10]
##   [--weather=clear|cloudy|overcast|rain|storm|snow|mist] [--melt=0.3] [--settle=45]
##   [--env-off=ssao,ssil,sdfgi]
## Boots res://world/route_world.tscn at Pallet (like shot_original_look.gd), puts the player on each
## spot and saves <out>/pallet_<spot>_<period>[_<weather>].png (without --out, <out> is
## user://shots/pallet). The period is forced with
## WorldTimeOfDay.forced_period (scripts are loaded by path: a SceneTree script compiles before the
## autoloads exist); the night / weather shader globals are also set directly, so the
## shot shows the lamps and wet ground even before the sky work drives them. With --hours (needs the
## continuous TimeOfDay, WorldTimeOfDay.forced_minutes) the hour is pinned instead and the files are
## named pallet_<spot>_<HHMM>; the TimeOfDay then drives the night globals itself, and the weather
## is the real WorldWeather type forced with WorldWeather.forced and snapped to its settled look
## (lying snow, wet ground). "storm" also saves <..>_bolt.png right after a lightning strike in
## view; --melt=<cover> (with snow) also saves <..>_melt.png with the snow stopped and that much
## cover left on the ground (thawing).

const SPOTS := {
	"start": [Vector3(-13, 0, -3), Vector3(0, 0, 1)],
	"plaza": [Vector3(-1, 0, 12), Vector3(0, 0, -1)],
	"fountain": [Vector3(0, 0, 10), Vector3(0, 0, -1)],
	"house": [Vector3(-16, 0, -1), Vector3(0, 0, -1)],
	"laundry": [Vector3(-21, 0, 20), Vector3(0, 0, -1)],
	"plantation": [Vector3(-23, 0, -1), Vector3(0, 0, -1)],
	"rival": [Vector3(11, 0, -2), Vector3(0, 0, -1)],
	"lab": [Vector3(16, 0, 24), Vector3(0, 0, -1)],
	"pond": [Vector3(-10, 0, 14), Vector3(-1, 0, 0)],
	"dock": [Vector3(-11, 0, 11), Vector3(-1, 0, 0)],
	"bridge": [Vector3(-13, 0, 25), Vector3(0, 0, -1)],
	"gate": [Vector3(0, 0, -13), Vector3(0, 0, -1)],
	"orchard": [Vector3(24, 0, -2), Vector3(0, 0, -1)],
	"south": [Vector3(6, 0, 25), Vector3(0, 0, -1)],
	"paddock": [Vector3(27, 0, 8), Vector3(0, 0, -1)],
	"west": [Vector3(-24, 0, 4), Vector3(0, 0, -1)],
	"east": [Vector3(22, 0, 0), Vector3(0, 0, -1)],
	"centre": [Vector3(0, 0, 4), Vector3(0, 0, -1)],
	"backyard": [Vector3(-14, 0, -14), Vector3(0, 0, 1)],
	"meadow": [Vector3(-19, 0, 4), Vector3(0, 0, -1)],
	"north": [Vector3(12, 0, -11), Vector3(0, 0, -1)],
	"flag": [Vector3(20, 0, 26), Vector3(0, 0, -1)],
}
const NIGHT := {
	"morning": [0.0, 0.0],
	"midday": [0.0, 0.0],
	"afternoon": [0.0, 0.0],
	"sunset": [0.7, 0.5],
	"night": [1.0, 1.0],
}

var w: Node3D
var out := ProjectSettings.globalize_path("user://shots/pallet")
var spots: PackedStringArray = ["start", "plaza", "house", "rival", "lab", "pond", "gate"]
var periods: PackedStringArray = ["midday"]
var weather := "clear"
var hours: PackedStringArray = []  ## --hours=HH:MM,...: pinned hours (continuous TimeOfDay)
var far := 0.0  ## --far=<m>: overview distance (debug)
var pitch := 0.0  ## --pitch=<deg>
var no_lamps := false  ## --no-lamps: hide every OmniLight3D (look-dev: what the sky alone gives)
var melt := -1.0  ## --melt=<cover>: also a thawing shot (snow stopped, this much left lying)
var settle := 45  ## --settle=<frames> per spot before the shot
var env_off: PackedStringArray = []  ## --env-off=ssao,ssil,sdfgi: look-dev, which effect does what


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--spots="):
			spots = a.substr(8).split(",")
		elif a.begins_with("--periods="):
			periods = a.substr(10).split(",")
		elif a == "--no-lamps":
			no_lamps = true
		elif a.begins_with("--hours="):
			hours = a.substr(8).split(",")
		elif a.begins_with("--weather="):
			weather = a.substr(10)
		elif a.begins_with("--far="):
			far = float(a.substr(6))
		elif a.begins_with("--pitch="):
			pitch = float(a.substr(8))
		elif a.begins_with("--melt="):
			melt = float(a.substr(7))
		elif a.begins_with("--settle="):
			settle = int(a.substr(9))
		elif a.begins_with("--env-off="):
			env_off = a.substr(10).split(",")
	if out.ends_with(".png"):
		out = out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _globals(period: String) -> void:
	var nm: Array = NIGHT.get(period, [0.0, 0.0])
	if not hours.is_empty():
		nm = []
	else:
		RenderingServer.global_shader_parameter_set("night_lamps", nm[0])
		RenderingServer.global_shader_parameter_set("night_windows", nm[1])
	if not hours.is_empty():  # the real WorldWeather drives the weather globals
		return
	var wet := 1.0 if weather == "rain" else 0.0
	RenderingServer.global_shader_parameter_set("rain_wet", wet)
	RenderingServer.global_shader_parameter_set("rain_puddle", 0.55 * wet)
	RenderingServer.global_shader_parameter_set("rain_amount", wet)
	RenderingServer.global_shader_parameter_set("snow_cover", 1.0 if weather == "snow" else 0.0)
	if weather == "snow":  # the voxel zone reads the cover from the weather node
		for n in root.get_tree().get_nodes_in_group("weather"):
			n.set("battle_cover", Color(0, 1, 0, 0))
	if not nm.is_empty():
		for n in root.get_tree().get_nodes_in_group("night_lights"):
			n.set_period_mult(nm[0], nm[1])


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out, name]
	img.save_png(path)
	print("saved ", path)


func _run() -> void:
	var g := root.get_node("Game")
	g.save_path = "user://test_shot_pallet.json"
	if g.party.is_empty():
		g.add_mon(Mon.create("pikachu", 8))
	var tod_script = load("res://world/sky/time_of_day.gd")
	var looks: Array = Array(periods)
	var probe: Node = tod_script.new()
	var continuous := probe.has_method("set_minute")
	probe.free()
	if not hours.is_empty() and continuous:
		looks = Array(hours)
	else:
		hours = []
	tod_script.forced_period = periods[0] if hours.is_empty() else ""
	var wx_script = load("res://world/sky/weather.gd")
	if hours.is_empty():
		wx_script.forced = "rain" if weather == "rain" else "clear"
	else:
		wx_script.forced = weather
	g.spawn_request = {"zone": "pallet_town", "spawn": "start"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await _wait(60)
	var b = w.builders.get("pallet_town")
	if b and "load_ms" in b:
		print(
			(
				"pallet: voxel zone built in %d ms (stale bake: %s) counts %s"
				% [b.load_ms, b.stale, b.counts]
			)
		)
	var p: Node3D = get_first_node_in_group("ow_player")
	var rig = get_first_node_in_group("ow_camera")
	if far > 0.0:
		rig.distance = far
		rig.set("_zone_dist", 0.0)
	if pitch > 0.0:
		rig.pitch_deg = pitch
	for period in looks:
		if hours.is_empty():
			tod_script.forced_period = period
		else:
			var hm: PackedStringArray = String(period).split(":")
			var m := int(hm[0]) * 60.0 + (float(hm[1]) if hm.size() > 1 else 0.0)
			tod_script.forced_minutes = m
			var clock := get_first_node_in_group("time_of_day")
			if clock and clock.has_method("set_minute"):
				clock.set_minute(m)
			period = String(period).replace(":", "")
		var tod := get_first_node_in_group("time_of_day")
		if tod and tod.has_method("refresh"):
			tod.refresh()
		var wx := get_first_node_in_group("weather")
		if not hours.is_empty() and wx and wx.has_method("snap"):
			wx.snap()
		await _wait(30)
		if tod and "state" in tod:
			print("look %s: %s" % [period, tod.state])
		for d in root.find_children("*", "DirectionalLight3D", true, false):
			var dl := d as DirectionalLight3D
			print(
				(
					"  light %s: visible %s energy %.2f dir %s"
					% [dl.get_path(), dl.is_visible_in_tree(), dl.light_energy, -dl.global_basis.z]
				)
			)
		for s in spots:
			if not SPOTS.has(s):
				continue
			var sp: Array = SPOTS[s]
			p.global_position = sp[0]
			p.facing = sp[1]
			rig.snap()
			if not hours.is_empty() and wx and wx.has_method("snap"):
				wx.snap()
			_globals(period)
			for we in root.find_children("*", "WorldEnvironment", true, false):
				var env := (we as WorldEnvironment).environment
				for fx in env_off:
					env.set("%s_enabled" % fx, false)
			await _wait(settle)
			_globals(period)
			if no_lamps:
				for l in root.find_children("*", "OmniLight3D", true, false):
					(l as OmniLight3D).visible = false
			print("spot %s: player at %s" % [s, p.global_position])
			if wx and "state" in wx:
				print("  weather %s: %s" % [wx.get("type"), wx.state])
			var suffix := "" if weather == "clear" else "_" + weather
			if far > 0.0:
				suffix += "_far"
			var shot := "pallet_%s_%s%s" % [s, period, suffix]
			await _shot(shot)
			if weather == "storm" and wx and wx.get("lightning"):
				var l: Node = wx.lightning
				l.strike(p.global_position + Vector3(4.5, 0.0, -5.0))  # beside the player, in view
				await _wait(2)
				await _shot(shot + "_bolt")
			if melt >= 0.0 and weather == "snow" and wx and "state" in wx:
				wx.state["snow"] = 0.0
				wx.state["snow_cover"] = melt
				wx.state["cloud"] = 0.3
				await _wait(settle)
				await _shot(shot + "_melt")
				wx.snap()
	quit(0)
