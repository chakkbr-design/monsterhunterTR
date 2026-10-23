extends SceneTree
## Captura com renderização real (sem --headless):
## godot --path . --resolution 1280x720 --script res://tests/ui_front/shot_title.gd
## Salva docs/screens/title.png (menu com Continuar), title_intro.png e title_name.png. Usa save de teste.

const SAVE := "user://test_save_front_shot.json"


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = SAVE
	root.add_child(game)
	game.new_game("Ana", "Gael", "female")
	game.choose_starter("Charmander")
	game.money = 3150
	game.save_game()
	var t: Node = load("res://ui/front/title.tscn").instantiate()
	t.game = game
	t.settings_path = "user://test_settings_front_shot.cfg"
	t.change_scene = func(_p): pass
	root.add_child(t)
	await _wait(10)
	t.press("ok")
	t.press("ok")
	await _wait(90)
	await _shot("res://docs/screens/title.png")
	t.press("down")
	t.press("ok")
	t.press("up")
	t.press("ok")
	await _wait(120)
	await _shot("res://docs/screens/title_intro.png")
	while t.state == "talk":
		t.press("ok")
		await process_frame
	t.press("right")
	await _wait(10)
	t.press("ok")
	for ch in "Ana":
		t._entry.type_char(ch)
	await _wait(20)
	await _shot("res://docs/screens/title_name.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings_front_shot.cfg"))
	quit(0)
