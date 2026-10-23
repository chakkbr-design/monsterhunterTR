extends SceneTree
## Captura do HUD com renderização real (sem --headless):
## godot --path . --resolution 1152x648 --script res://tests/ui/shot_hud.gd
## Salva docs/screens/ui_hud.png (orbes, pílula do lugar, dicas) e ui_hud_dialog.png (caixa de diálogo).
## Usa save de teste; nunca grava user://save.json.

var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/screens/%s.png" % name
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	_game = root.get_node_or_null("Game")
	_game.save_path = "user://test_save_hud_shot.json"
	_game.last_save = {}
	_game.spawn_request = {}
	_game.player_name = "Ana"
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_game.party = [Mon.create("Charmander", 12, rng), Mon.create("Pidgey", 7, rng), Mon.create("Rattata", 5, rng)]
	_game.party[1].hp = int(_game.party[1].max_hp * 0.35)
	_game.party[2].hp = 0
	_game.party[0].pp = _game.party[0].pp_base * 0.6
	_game.flags["has_pokedex"] = true
	var world: Node = load("res://world/route_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(90)
	var hud = world.get_tree().get_first_node_in_group("ow_hud")
	hud.set_prompt("E: Talk")
	await _wait(10)
	await _shot("ui_hud")
	hud.set_prompt("")
	hud.say("Mamãe", PackedStringArray(["Bom dia, Ana! O Professor Carvalho passou aqui procurando por você. Ele disse que tem algo importante para te mostrar!"]))
	await _wait(150)
	await _shot("ui_hud_dialog")
	quit()
