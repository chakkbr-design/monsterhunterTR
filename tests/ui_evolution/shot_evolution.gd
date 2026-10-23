extends SceneTree
## Captura com renderização real (sem --headless):
## godot --path . --resolution 1280x720 --script res://tests/ui_evolution/shot_evolution.gd
## Salva docs/screens/evolution.png (meio da animação) e evolution_done.png (clarão final).


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save_evo.json"
	var evo = load("res://ui/evolution/evolution_ui.gd").new()
	evo.game = game
	root.add_child(evo)
	var m := Mon.create("Charmander", 16)
	game.party = [m]
	game.pending_evolutions = [m]
	game.evolution_requested.emit()
	evo.press("ok")
	for i in 38:       # gera partículas com passos curtos, para o rastro ficar natural
		evo.advance(3.3 / 38.0)
		await process_frame
	evo.set_process(false)
	await _shot("res://docs/screens/evolution.png")
	evo.set_process(true)
	evo.advance(evo.DURATION)
	evo.advance(0.25)
	evo.set_process(false)
	await _shot("res://docs/screens/evolution_done.png")
	game.free()
	quit(0)
