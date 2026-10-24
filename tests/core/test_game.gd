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
	fails += int(
		(
			game.use_item("moon_stone", c) == ""
			or c.species != "Clefable"
			or game.bag.has("moon_stone")
		)
	)
	fails += int(not game.save_game())
	game.party = []
	var d: Dictionary = game.load_game()
	fails += int(
		game.party.size() != 1 or game.party[0].species != "Pikachu" or d.get("version") != 1
	)
	var money_before: int = game.money
	game._opts = {"kind": "trainer", "trainer_id": "test_youngster"}
	game._enemies = [Mon.create("rattata", 5)]
	game.mark_seen("Rattata")
	game._finish({"outcome": "win"})
	fails += int(
		(
			game.money != money_before + 16 * 5
			or not game.flags.get("trainer_test_youngster", false)
			or not game.seen.has("Rattata")
		)
	)
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
	fails += int(
		y.level != 25 or game.pending_learns.size() != (0 if y.moves.has("sweet_scent") else 1)
	)
	game.resolve_learn(-1)
	game.new_game("ASH", "GARY")
	var st: Mon = game.choose_starter("charmander")
	fails += int(
		(
			game.party.size() != 1
			or st.level != 5
			or game.flags.rival_starter != "Squirtle"
			or game.fill_names("{PLAYER} x {RIVAL}") != "ASH x GARY"
		)
	)
	game.save_game()
	game.player_name = ""
	game.load_game()
	fails += int(game.player_name != "ASH")
	game.party = [Mon.create("pidgey", 5), Mon.create("rattata", 5)]
	game.pc = []
	fails += int(not game.deposit(1) or game.party.size() != 1 or game.pc.size() != 1)
	fails += int(game.deposit(0))
	fails += int(not game.withdraw(0) or game.party.size() != 2 or not game.release(0) == false)
	var ev := Mon.create("charmander", 15)
	ev.add_exp(Growth.exp_for_level(ev.growth, 16) - ev.xp)
	game.resolve_evolution(ev, false)
	fails += int(ev.species != "Charmander" or ev.evolution_target() != "")
	# Pedra com 4 golpes: sem golpe de evolução nada entra na fila, a Pokédex marca a evolução e o texto usa o nome antigo.
	var c2 := Mon.create("clefairy", 20)
	c2.moves = ["pound", "growl", "sing", "double_slap"]
	game.pending_learns = []
	game.add_item("moon_stone")
	var stone_msg: String = game.use_item("moon_stone", c2)
	fails += int(
		(
			not stone_msg.begins_with("Clefairy")
			or not game.caught.has("Clefable")
			# Gen 9: Clefable não tem golpe de evolução (só os de nível 1)
			or not game.pending_learns.is_empty()
		)
	)
	game.pending_learns = []
	# Rare Candy até o nível de evolução: evolui na hora (sem a tela Evolution).
	var rc := Mon.create("bulbasaur", 15)
	game.party = [rc]
	game.add_item("rare_candy")
	game.use_item("rare_candy", rc)
	fails += int(rc.level != 16 or rc.species != "Ivysaur")
	game.new_game("A", "B")
	fails += int(not game.pending_evolutions.is_empty() or not game.pending_learns.is_empty())
	fails += _rodada6(game)
	game.free()
	print("game: %d falhas" % fails)
	quit(1 if fails else 0)


## Correções da jogada comparada: PP no mundo, PC cura, Repel, prêmio do 1º rival, autosave.
func _rodada6(game) -> int:
	var fails := 0
	var a := Mon.create("pidgey", 5)
	a.pp = 5.0
	game.party = [a]
	game.regen_pp(20.0)
	fails += _ok(
		is_equal_approx(a.pp, minf(a.pp_base, 5.0 + a.pp_base * 0.005 * 20.0)), "PP volta 0,5%/s"
	)
	var hurt := Mon.create("rattata", 5)
	hurt.hp = 1
	hurt.status = "poison"
	game.party = [Mon.create("pidgey", 5), hurt]
	game.pc = []
	game.deposit(1)
	fails += _ok(game.pc[0].hp == game.pc[0].max_hp and game.pc[0].status == "", "depositar cura")
	game.pc[0].hp = 2
	game.withdraw(0)
	fails += _ok(game.party[1].hp == game.party[1].max_hp, "sacar cura")
	game.bag = {"repel": 1}
	game.repel_steps = 0
	var msg: String = game.use_field_item("repel")
	fails += _ok(
		msg != "" and game.repel_steps == 100 and not game.bag.has("repel"), "Repel 100 passos"
	)
	fails += _ok(game.use_field_item("potion") == "", "poção não é item de campo")
	fails += _ok(game.repel_active() and game.repel_blocks(50), "Repel bloqueia encontros")
	game.repel_steps = 2
	fails += _ok(
		not game.repel_step() and game.repel_step() and not game.repel_active(), "Repel acaba"
	)
	game.repel_steps = 7
	var d: Dictionary = game.to_dict()
	game.from_dict(d)
	fails += _ok(game.repel_steps == 7, "repel_steps salvo")
	var m0: int = game.money
	game._opts = {
		"kind": "trainer",
		"trainer_id": "rival_blue_route22",
		"trainer_class": "rival",
		"scripted": true
	}
	game._enemies = [Mon.create("squirtle", 5)]
	game._finish({"outcome": "win"})
	fails += _ok(game.money == m0 + 175, "1º rival paga 35 x 5 (%d)" % (game.money - m0))
	var g2 = load("res://core/game.gd").new()
	fails += _ok(not g2.save_enabled, "autosave desligado antes do novo jogo")
	g2.free()
	fails += _ok(game.save_enabled and not game.can_autosave(null), "autosave sem mundo não grava")
	return fails


func _ok(cond: bool, what: String) -> int:
	if not cond:
		print("FAIL " + what)
	return 0 if cond else 1
