extends SceneTree
## Fotos da tela de montar times (sem --headless): godot --path . --resolution 1920x1080
## --script res://tests/ui_training/shot_training_setup.gd. Grava em user://shots/ e diz se o
## conteúdo cabe na tela sem passar da borda.

const Cfg := preload("res://ui/training/training_config.gd")


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	for i in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var p := "user://shots/%s.png" % name
	root.get_texture().get_image().save_png(p)
	print("foto: ", ProjectSettings.globalize_path(p))


func _run() -> void:
	Cfg.path = "user://test_shot_training.json"
	Cfg.teams_path = "user://test_shot_teams.json"
	Cfg.current = Cfg.default_config()
	var scr: Control = load("res://ui/training/training_setup.tscn").instantiate()
	scr.change_scene = func(_p: String): pass
	root.add_child(scr)
	await shot("1_tela")
	var vp := root.get_visible_rect().size
	var need: Vector2 = scr.get_child(1).get_combined_minimum_size()
	print("viewport %s, conteúdo precisa %s, cabe: %s" % [vp, need, need.x <= vp.x and need.y <= vp.y])
	for i in 4:
		scr.add_mon(0, ["Charmander", "Squirtle", "Pikachu", "Geodude"][i])
	scr.select(0, 1)
	await shot("2_time_cheio")
	need = scr.get_child(1).get_combined_minimum_size()
	print("com 6: precisa %s, cabe: %s" % [need, need.x <= vp.x and need.y <= vp.y])
	scr.open_species(1, -1)
	await shot("3_especies")
	scr.close_picker()
	scr.open_moves(1)
	await shot("4_golpes")
	scr.close_picker()
	scr.open_teams(0)
	scr.pick(0)
	await shot("5_salvos")
	quit()
