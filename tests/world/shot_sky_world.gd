extends SceneTree
## Screenshots of the continuous sky on the old (HGSS) overworld (needs a GPU or lavapipe):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan \
##     --resolution 1600x900 --script res://tests/world/shot_sky_world.gd -- --out=/tmp/sky/world \
##     [--places=viridian_city:vc_center_door,pewter_city:pw_lamps] [--hours=07:00,12:00] \
##     [--weather=rain] [--quality=alto]
## Saves <out>_<zone>_<HHMM>.png for every place and hour. Uses a test save (never user://save.json).

var out := "user://shot_sky_world"
var places: Array = ["viridian_city:vc_center_door", "pewter_city:pw_lamps"]
var hours: Array = ["06:30", "12:00", "17:45", "19:15", "22:00"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--places="):
			places = Array(a.substr(9).split(","))
		elif a.begins_with("--hours="):
			hours = Array(a.substr(8).split(","))
		elif a.begins_with("--weather="):
			WorldWeather.forced = a.substr(10)
	if WorldWeather.forced == "":
		WorldWeather.forced = "clear"
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g := root.get_node("Game")
	g.save_path = "user://test_shot_sky_save.json"
	g.flags["has_pokedex"] = true
	g.flags["pewter_guide_done"] = true
	if g.party.is_empty():
		g.add_mon(load("res://core/mon.gd").create("pikachu", 8))
	WorldTimeOfDay.forced_minutes = SkyCycle.parse_hm(hours[0])
	var first: PackedStringArray = String(places[0]).split(":")
	g.spawn_request = {"zone": first[0], "spawn": first[1]}
	var w: Node3D = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await _wait(150)
	var tod: WorldTimeOfDay = w.get_node("TimeOfDay")
	for i in places.size():
		var place: PackedStringArray = String(places[i]).split(":")
		if i > 0:
			await w.go_to_zone(place[0], place[1])
			await _wait(120)
		for h in hours:
			tod.set_minute(SkyCycle.parse_hm(h))
			await _wait(45)
			await RenderingServer.frame_post_draw
			var path := "%s_%s_%s.png" % [out, place[0], String(h).replace(":", "")]
			root.get_texture().get_image().save_png(path)
			print("saved ", path, " exposure ", tod.state.get("exposure"))
	quit(0)
