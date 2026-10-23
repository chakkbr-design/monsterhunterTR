extends SceneTree
## Rodar: godot --headless --path . --script res://tests/core/test_game.gd

func _initialize() -> void:
	var game = load("res://core/game.gd").new()
	var fails := 0
	var m := Mon.create("pikachu", 10)
	game.party = [m]
	m.hp = 1
	fails += int(game.use_item("potion", m) == "" or m.hp != mini(21, m.max_hp))
	fails += int(Items.can_use("thunder_stone", m))
	game.add_item("moon_stone")
	var c := Mon.create("clefairy", 10)
	fails += int(game.use_item("moon_stone", c) == "" or c.species != "Clefable" or game.bag.has("moon_stone"))
	fails += int(not game.save_game())
	game.party = []
	var d: Dictionary = game.load_game()
	fails += int(game.party.size() != 1 or game.party[0].species != "Pikachu" or d.get("version") != 1)
	game.free()
	print("game: %d falhas" % fails)
	quit(1 if fails else 0)
