extends SceneTree
## Rodar: godot --headless --path . --script res://tests/core/test_game.gd

func _initialize() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save.json"
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
	var money_before: int = game.money
	game._opts = {"kind": "trainer", "trainer_id": "test_youngster"}
	game._enemies = [Mon.create("rattata", 5)]
	game.mark_seen("Rattata")
	game._finish({"outcome": "win"})
	fails += int(game.money != money_before + 16 * 5 or not game.flags.get("trainer_test_youngster", false) or not game.seen.has("Rattata"))
	var b := Mon.create("bulbasaur", 15)
	b.add_exp(Growth.exp_for_level(b.growth, 16) - b.xp)
	game.party = [b]
	var r := {"outcome": "win"}
	game._finish(r)
	fails += int(b.species != "Ivysaur" or r.evolved.size() != 1)
	var f := Mon.create("bulbasaur", 20)
	fails += int(f.moves.size() != 4)
	game.add_item("tm09")
	game.use_item("tm09", f)
	fails += int(game.pending_learns.size() != 1 or not game.bag.has("tm09"))
	game.resolve_learn(0)
	fails += int(f.moves[0] != "bullet_seed" or not game.pending_learns.is_empty())
	var y := Mon.create("bulbasaur", 24)
	game.add_item("rare_candy")
	game.use_item("rare_candy", y)
	fails += int(y.level != 25 or game.pending_learns.size() != (0 if y.moves.has("sweet_scent") else 1))
	game.resolve_learn(-1)
	game.new_game("ASH", "GARY")
	var st: Mon = game.choose_starter("charmander")
	fails += int(game.party.size() != 1 or st.level != 5 or game.flags.rival_starter != "Squirtle" or game.fill_names("{PLAYER} x {RIVAL}") != "ASH x GARY")
	game.save_game()
	game.player_name = ""
	game.load_game()
	fails += int(game.player_name != "ASH")
	game.free()
	print("game: %d falhas" % fails)
	quit(1 if fails else 0)
