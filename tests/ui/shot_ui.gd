extends SceneTree
## Capturas com renderização real (sem --headless):
## godot --path . --resolution 1152x648 --script res://tests/ui/shot_ui.gd
## Salva docs/screens/ui_pause.png, ui_summary.png, ui_pokedex.png e extras (ui_party, ui_bag, ui_card,
## ui_badges, ui_options, ui_controls, ui_dex_entry, ui_learn). Usa save de teste.

var game
var menu
var learn


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/screens/%s.png" % name
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _backdrop() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("7fb6e8"), Color("cfe8b0"), Color("5c9a48")])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = -1
	cl.add_child(bg)
	root.add_child(cl)


func _run() -> void:
	_backdrop()
	game = load("res://core/game.gd").new()
	game.save_path = "user://test_save_ui_shot.json"
	game.player_name = "Ana"
	game.rival_name = "Gael"
	game.money = 3150
	game.play_time = 5025.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	game.party = [Mon.create("Charmander", 14, rng), Mon.create("Pidgey", 9, rng), Mon.create("Pikachu", 11, rng),
		Mon.create("Bulbasaur", 8, rng)]
	game.party[1].hp = int(game.party[1].max_hp * 0.4)
	game.party[2].status = "paralysis"
	game.party[3].hp = 0
	game.bag = {"potion": 3, "super_potion": 1, "antidote": 2, "poke_ball": 8, "great_ball": 2, "rare_candy": 1}
	game.flags = {"has_pokedex": true, "badge_boulder": true, "boulder_badge": true}
	for s in ["Bulbasaur", "Charmander", "Squirtle", "Pidgey", "Rattata", "Caterpie", "Weedle", "Pikachu", "Spearow", "Nidoran F"]:
		game.seen[s] = true
	for s in ["Charmander", "Pidgey", "Pikachu", "Bulbasaur"]:
		game.caught[s] = true
	root.add_child(game)
	learn = load("res://ui/learn_move_ui.gd").new()
	learn.game = game
	root.add_child(learn)
	menu = load("res://ui/pause_menu.gd").new()
	menu.game = game
	menu.learn = learn
	menu.settings_path = "user://test_settings_ui_shot.cfg"
	root.add_child(menu)
	await process_frame
	menu.open()
	await _shot("ui_pause")
	menu.press("ok")   # POKéMON
	await _shot("ui_party")
	menu.press("ok")
	await _shot("ui_summary")
	menu.press("down")
	await _shot("ui_summary_skills")
	menu.press("down")
	await _shot("ui_summary_moves")
	menu.press("back")
	menu.press("back")
	menu.press("up")
	menu.press("ok")   # POKéDEX
	await _shot("ui_pokedex")
	for i in 3:
		menu.press("down")
	menu.press("ok")
	await _shot("ui_dex_entry")
	menu.press("back")
	menu.press("back")
	menu.press("down")
	menu.press("down")
	menu.press("ok")   # BOLSA
	await _shot("ui_bag")
	menu.press("back")
	menu.press("down")
	menu.press("ok")   # cartão
	await _shot("ui_card")
	menu.press("right")
	await _shot("ui_badges")
	menu.press("back")
	menu.press("down")
	menu.press("down")
	menu.press("ok")   # opções
	await _shot("ui_options")
	menu.press("down")
	menu.press("down")
	menu.press("ok")
	await _shot("ui_controls")
	menu.press("back")
	menu.press("back")
	menu.press("up")
	menu.press("ok")   # salvar
	await _shot("ui_save_msg")
	menu.close()
	var m: Mon = game.party[0]
	var nw := ""
	for id in Dex.all_moves():
		if not m.moves.has(id) and int(Dex.move(id).get("power", 0)) > 0:
			nw = id
			break
	while m.moves.size() < 4:
		m.moves.append(Dex.all_moves()[m.moves.size() + 10])
	game.queue_learn(m, nw)
	game.learn_requested.emit()
	await _shot("ui_learn")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_ui_shot.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings_ui_shot.cfg"))
	quit()
