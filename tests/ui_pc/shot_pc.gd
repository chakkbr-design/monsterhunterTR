extends SceneTree
## Captura de tela real (sem --headless): godot --path . --script res://tests/ui_pc/shot_pc.gd
## Salva docs/screens/pc.png com a caixa 1 aberta.

var _frames := 0
var _pc


func _initialize() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save_pc.json"
	game.party = [Mon.create("Charmander", 12), Mon.create("Pidgey", 9)]
	var names := ["Bulbasaur", "Rattata", "Caterpie", "Weedle", "Pikachu", "Magikarp", "Spearow", "Nidoran♀",
		"Geodude", "Oddish", "Squirtle", "Zubat", "Pidgeotto", "Metapod"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 17:
		var sp: String = names[i % names.size()]
		if Dex.species(sp).is_empty():
			sp = "Rattata"
		game.pc.append(Mon.create(sp, rng.randi_range(3, 18), rng))
	game.pc[4].hp = int(game.pc[4].max_hp * 0.3)
	_pc = load("res://ui/pc/pc_storage.gd").new()
	_pc.game = game
	root.add_child(_pc)


func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 2:
		_pc.open()
		_pc.press("down")
		_pc.press("ok")      # Retirar Pokémon
		_pc.press("right")
		_pc.press("right")
		_pc.press("right")
		_pc.press("down")    # espaço 10 da caixa 1
	if _frames == 30:
		var img := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://docs/screens/pc.png")
		print("salvo: ", img.save_png(path) == OK, " ", path)
		quit()
	return false
