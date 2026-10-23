extends SceneTree
## Real-renderer screenshots (not headless):
## godot --path . --resolution 1280x720 --script res://tests/interiors/shot_interiors.gd
## Saves docs/screens/interior_lab.png, interior_center.png and interior_mart.png.


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	root.get_node("Game").spawn_request = {"interior": "oak_lab", "spawn": "front_of_oak"}
	var w: Node3D = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await _shot("res://docs/screens/interior_lab.png")
	await w.go_to_interior("pokemon_center_viridian", "counter")
	await _shot("res://docs/screens/interior_center.png")
	await w.go_to_interior("mart_viridian", "counter")
	await _shot("res://docs/screens/interior_mart.png")
	quit(0)
