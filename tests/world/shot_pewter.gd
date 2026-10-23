extends SceneTree
## Real-renderer screenshots (not headless):
## godot --path . --resolution 1280x720 --script res://tests/world/shot_pewter.gd
## Saves docs/screens/pewter.png (Pewter, gym street), forest.png (Viridian Forest) and pewter_gym.png.


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var g := root.get_node("Game")
	g.save_path = "user://test_shot_save.json"
	g.flags["has_pokedex"] = true
	g.flags["pewter_guide_done"] = true
	g.spawn_request = {"zone": "pewter_city", "spawn": "pw_lamps"}
	var w: Node3D = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	var rig = get_first_node_in_group("ow_camera")
	rig.distance = 26.0
	rig.pitch_deg = 44.0
	await _wait(120)
	await _shot("res://docs/screens/pewter.png")
	await w.go_to_zone("viridian_forest", "vf_mid")
	rig.distance = 18.0
	rig.pitch_deg = 48.0
	await _wait(150)
	await _shot("res://docs/screens/forest.png")
	await w.go_to_interior("pewter_gym", "door")
	await _wait(60)
	await _shot("res://docs/screens/pewter_gym.png")
	quit(0)
