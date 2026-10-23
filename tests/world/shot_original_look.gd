extends SceneTree
## Real-renderer screenshots of the original-art world (not headless):
## godot --path . --resolution 1280x720 --script res://tests/world/shot_original_look.gd [-- --period=night --weather=rain]
## Saves docs/screens/world_pallet.png, world_route1.png, world_forest.png, world_pewter.png, world_lab.png.

var w: Node3D
var period := "midday"
var suffix := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--period="):
			period = a.substr(9)
			suffix = "_" + period
		if a.begins_with("--weather="):
			WorldWeather.forced = a.substr(10)
			suffix += "_" + a.substr(10)
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "res://docs/screens/%s%s.png" % [name, suffix]
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _zone(zone: String, spawn: String, pos := Vector3.INF, face := Vector3.ZERO) -> void:
	await w.go_to_zone(zone, spawn)
	var p: Node3D = get_first_node_in_group("ow_player")
	if pos != Vector3.INF:
		p.global_position = pos
	if face != Vector3.ZERO:
		p.facing = face
	var rig = get_first_node_in_group("ow_camera")
	rig.snap()
	await _wait(150)


func _run() -> void:
	var g := root.get_node("Game")
	g.save_path = "user://test_shot_save.json"
	g.flags["has_pokedex"] = true
	g.flags["pewter_guide_done"] = true
	if g.party.is_empty():
		g.add_mon(Mon.create("pikachu", 8))
	WorldTimeOfDay.forced_period = period
	if WorldWeather.forced == "":
		WorldWeather.forced = "clear"
	g.spawn_request = {"zone": "pallet_town", "spawn": "start"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await _wait(150)
	await _shot("world_pallet")
	await _zone("route_1", "r1_band1")
	await _shot("world_route1")
	await _zone("viridian_forest", "vf_mid")
	await _shot("world_forest")
	await _zone("pewter_city", "pw_lamps")
	await _shot("world_pewter")
	await w.go_to_interior("oak_lab", "door")
	await _wait(90)
	await _shot("world_lab")
	quit(0)
