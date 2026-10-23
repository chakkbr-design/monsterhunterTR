extends SceneTree
## Real-renderer screenshot of route_world (not headless):
## godot --path . --resolution 1280x720 --script res://tests/world/shot_route_world.gd
## Saves docs/screens/route_world.png (Pallet start) and route_world_r1.png (Route 1 ledges).

func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	var w: Node3D = load("res://world/route_world.tscn").instantiate()
	root.add_child(w)
	var rig = get_first_node_in_group("ow_camera")
	rig.distance = 24.0
	rig.pitch_deg = 42.0
	for i in 90:
		await process_frame
	await _shot("res://docs/screens/route_world.png")
	var p: Node3D = get_first_node_in_group("ow_player")
	p.global_position = Vector3(-4, 1.1, -50)
	for i in 120:
		await process_frame
	await _shot("res://docs/screens/route_world_r1.png")
	quit(0)
