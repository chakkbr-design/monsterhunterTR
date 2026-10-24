extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_battle.gd
## Simula a arena com step(dt) manual: nada depende de tempo real.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
## Abertura do treinador: "<NOME> quer lutar!" (1.2 s) + "<NOME> mandou X!" (1.2 s), como o original.
const TRAINER_INTRO := 2.5

var _fails := 0
var _count := 0


func _initialize() -> void:
	_stamina()
	_cooldowns()
	_status()
	_capture()
	_swap()
	_recall_stops_combo()
	for i in 6:
		_full_battle(i)
	_trainer_battle()
	_items()
	_trainer_item()
	_ally_modes()
	_control_swap()
	for i in 3:
		_two_vs_one(i)
	_pause()
	_trainer_lines()
	_results()
	_capture_pc_and_ball()
	_auto_battle()
	_no_rewards()
	print("battle: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var got := {}
	a.finished.connect(func(r: Dictionary) -> void: got.merge(r), CONNECT_ONE_SHOT)
	a.set_meta("got", got)
	if not opts.has("speed"):
		opts["speed"] = 1.0  # the rules are timed at 1x (the game plays at the original's 0.6)
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false  # these suites drive the player's mon by hand
	if not opts.has("damage_pace"):
		opts["damage_pace"] = 1.0  # regras no ritmo original (a Batalha Viva escala dano e PP juntos)
	if not opts.has("field_objects"):
		opts["field_objects"] = false  # caixas e pedras da Batalha Viva mexem no rng das regras
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada: inimigo sem controle, intro já passada.
func _still(species := "charmander", foe := "pidgey") -> Node:
	var a := _arena([Mon.create(species, 10)], [Mon.create(foe, 10)], {"seed": 7})
	_run(a, 1.3)
	a.enemy.controller = "none"
	return a


func _done(a: Node) -> void:
	a.free()


func _stamina() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	check(a.state == "fight", "intro termina em luta")
	var sf := p.speed_factor()
	p.stamina = 0.0
	_run(a, 1.0)
	check(
		near(p.stamina, p.pp_max * 0.2 * sf, 0.6),
		"stamina regenera 20%%/s x fator (%.2f)" % p.stamina
	)
	p.stamina = p.pp_max
	p.sprinting = true
	_run(a, 1.0)
	check(near(p.stamina, p.pp_max * 0.7, 0.6), "sprint drena 30%%/s (%.2f)" % p.stamina)
	p.sprinting = false
	p.stamina = p.pp_max
	check(p.start_jump(), "pula")
	check(near(p.stamina, p.pp_max * 0.85, 0.01), "pulo custa 15%")
	check(near(p.air_t, sqrt(8.0 * p.jump_height / 23.8), 0.001), "tempo de pulo sqrt(8h/g)")
	check(not p.start_jump(), "não pula no ar")
	_run(a, p.jump_time + 0.05)
	check(p.air_t == 0.0 and p.land_t > 0.0, "pousa com lag")
	# Exaustão: stamina negativa depois do golpe => stagger 2 s.
	_run(a, 1.0)
	p.stamina = 1.0
	check(a.moves.use(p, "scratch"), "usa scratch cansado")
	check(p.stamina < 0.0, "stamina negativa")
	_run(a, 0.5)
	check(p.stagger_t > 1.0 and not p.can_act(), "stagger após o golpe")
	_run(a, 2.0)
	check(p.stagger_t == 0.0 and p.can_act(), "stagger dura 2 s")
	_done(a)


func _cooldowns() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var sf := p.speed_factor()
	var mv := Dex.move("ember")
	var pp0 := p.pp_max
	check(a.moves.use(p, "ember"), "usa ember")
	check(near(p.pp_max, pp0 - Dex.pp_cost(mv), 0.001), "debita PP")
	check(
		near(p.move_cd["ember"], Dex.cooldown(mv) / sf, Dex.cooldown(mv) / sf * 0.051),
		"cooldown por golpe / fator (+-5%)"
	)
	check(near(p.gcd_t, 1.0 / sf, 0.001), "GCD 1 s / fator")
	check(not a.moves.use(p, "scratch"), "GCD bloqueia outro golpe")
	_run(a, 1.0 / sf + 0.4)  # o hit-stop do acerto congela os timers do atacante
	check(not a.moves.use(p, "ember"), "cooldown do golpe ainda ativo")
	check(a.moves.use(p, "scratch"), "outro golpe depois do GCD")
	_run(a, Dex.cooldown(mv) / sf * 1.06)
	check(a.moves.use(p, "ember"), "ember volta após cooldown")
	p.pp_max = 0.5
	a.enemy.immortal = true  # queimadura do Ember não pode acabar a luta antes do struggle
	_run(a, 10.0)
	check(p.out_of_pp(), "sem PP")
	check(not a.moves.use(p, "ember"), "sem PP não usa golpe")
	check(p.struggle(), "struggle sem PP")
	_done(a)


func _status() -> void:
	var a := _still()
	var e: BattleFighter = a.enemy
	var hp0 := e.hp
	check(e.apply_status("burn"), "aplica burn")
	check(not e.apply_status("poison"), "um status major por vez")
	_run(a, 0.95)
	check(e.hp == hp0, "sem tick antes de 1 s")
	_run(a, 0.1)
	check(e.hp == hp0 - maxi(1, int(e.max_hp / 16.0)), "burn tira max_hp/16 por s")
	check(e.mon.status == "burn", "burn grava no Mon")
	_run(a, 5.0)
	check(e.status == "" and e.mon.status == "", "burn dura 6 s")
	check(e.hp == hp0 - 6 * maxi(1, int(e.max_hp / 16.0)), "6 ticks de burn (%d)" % (hp0 - e.hp))
	e.hp = e.max_hp
	hp0 = e.hp
	e.apply_status("poison")
	_run(a, 1.05)
	check(e.hp == hp0 - maxi(1, int(e.max_hp / 12.0)), "poison tira max_hp/12")
	e.clear_status()
	e.apply_status("sleep")
	check(not e.can_act(), "dormindo não age")
	_run(a, 2.9)
	check(e.status == "sleep", "sono ainda ativo em 2,9 s")
	_run(a, 0.2)
	check(e.status == "" and e.can_act(), "sono dura 3 s")
	e.apply_status("sleep")
	e.take_damage(1, Vector3.FORWARD, 4.0)
	check(e.status == "", "dano com knockback acorda")
	_run(a, 0.5)
	e.apply_status("flinch")
	check(not e.can_act() and near(e.stun_t, 0.5, 0.001), "flinch = stun 0,5 s")
	check(e.apply_status("confusion") and not e.apply_status("confusion"), "confusão não acumula")
	_run(a, 3.9)
	check(e.confusion_t > 0.0, "confusão ainda ativa em 3,9 s")
	_run(a, 0.2)
	check(e.confusion_t == 0.0, "confusão dura 4 s")
	e.apply_status("paralysis")
	var pos := e.position
	e.controller = "ai"
	e.drive(0.5, Vector3.RIGHT, 2.0)
	var moved := (e.position - pos).length()
	check(near(moved, 2.0 * 0.5 * 0.5, 0.05), "paralisia corta velocidade pela metade")
	_done(a)


func _capture() -> void:
	var a := _arena(
		[Mon.create("charmander", 10)],
		[Mon.create("pidgey", 3)],
		{"seed": 3, "ball": "master_ball"}
	)
	_run(a, 1.3)
	check(a.throw_ball(), "joga a bola")
	_run(a, 5.0)
	var got: Dictionary = a.get_meta("got")
	check(
		got.get("outcome") == "caught" and got.get("caught_mon") is Mon, "captura com master ball"
	)
	check(
		got.get("caught_mon") is Mon and got.caught_mon.ball == "master_ball", "bola gravada no Mon"
	)
	_done(a)
	var t := _arena(
		[Mon.create("charmander", 10)], [Mon.create("pidgey", 3)], {"kind": "trainer", "seed": 3}
	)
	_run(t, TRAINER_INTRO)
	check(not t.throw_ball() and not t.run_away(), "treinador: sem bola nem fuga")
	_done(t)
	var r := _arena([Mon.create("charmander", 10)], [Mon.create("pidgey", 3)], {"seed": 3})
	_run(r, 1.3)
	check(r.run_away(), "foge de selvagem")
	_run(r, 1.0)
	check(r.get_meta("got").get("outcome") == "run", "resultado run")
	_done(r)


func _swap() -> void:
	var party := [Mon.create("charmander", 10), Mon.create("squirtle", 10)]
	var a := _arena(party, [Mon.create("pidgey", 5)], {"seed": 5, "battle_size": 1})
	_run(a, 1.3)
	a.player.hp = 7
	a.player.mon.hp = 7
	check(a.swap(), "troca de mon")
	check(
		a.player.mon == party[1] and a.enemy.opponent == a.player,
		"novo mon em campo e alvo do inimigo"
	)
	check(party[0].hp == 7, "HP do mon recolhido persiste")
	check(not a.swap(), "troca tem cooldown")
	_done(a)


## Golpe de vários acertos (multi_arc) não continua do lutador recolhido pela troca.
func _recall_stops_combo() -> void:
	var party := [Mon.create("charmander", 20), Mon.create("squirtle", 20)]
	var a := _arena(party, [Mon.create("onix", 30)], {"seed": 3, "battle_size": 1})
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.position = Vector3(0, 0, 0.6)
	a.enemy.position = Vector3(0, 0, -4.0)  # longe: o 1º golpe não acerta (sem hit-stop)
	var old: BattleFighter = a.player
	old.stamina = old.pp_max
	var mv := Dex.move("fury_swipes").duplicate()
	mv.accuracy = 0  # sem erro aleatório
	a.moves.deliver(old, mv)
	check(a.swap() and a.player != old, "troca no meio do Fury Swipes")
	a.player.position = Vector3(2.5, 0, 0.6)
	a.enemy.position = Vector3(0, 0, -0.4)  # entra no alcance do recolhido
	var hits: int = a.hits
	_run(a, 1.5)
	check(a.hits == hits, "recolhido não segue acertando (%d -> %d)" % [hits, a.hits])
	_done(a)


const MATCHUPS := [
	["charmander", 8, "pidgey", 6],
	["squirtle", 8, "rattata", 7],
	["bulbasaur", 9, "caterpie", 8],
	["pikachu", 8, "spearow", 8],
	["geodude", 10, "charmander", 10],
	["pidgey", 6, "weedle", 6],
]


func _full_battle(i: int) -> void:
	var m: Array = MATCHUPS[i]
	var mine := Mon.create(m[0], m[1])
	var xp0 := mine.xp
	var a := _arena([mine], [Mon.create(m[2], m[3])], {"seed": 100 + i, "autoplay": true})
	var t := 0.0
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
	var got: Dictionary = a.get_meta("got")
	var outcome := String(got.get("outcome", "none"))
	print(
		(
			"  AI x AI %s Lv%d vs %s Lv%d -> %s em %.1f s, %d acertos, HP %d/%d, PP %.0f"
			% [m[0], m[1], m[2], m[3], outcome, t, a.hits, mine.hp, mine.max_hp, mine.pp]
		)
	)
	check(outcome in ["win", "lose"], "batalha IA x IA termina com vencedor (%s)" % m[0])
	check(a.hits > 0, "houve acertos")
	if outcome == "win":
		check(mine.xp > xp0 and not got.get("exp", []).is_empty(), "XP concedida ao vencedor")
		check(mine.ev_total() > 0, "EVs concedidos")
	else:
		check(mine.is_fainted(), "perdedor desmaiou")
	_done(a)


func _trainer_battle() -> void:
	var party := [Mon.create("charmander", 12), Mon.create("squirtle", 12)]
	var foes := [Mon.create("geodude", 9), Mon.create("onix", 10)]
	var a := _arena(
		party, foes, {"kind": "trainer", "trainer_id": "brock", "seed": 42, "autoplay": true}
	)
	var t := 0.0
	while a.state != "done" and t < 900.0:
		a.step(DT)
		t += DT
	var outcome := String(a.get_meta("got").get("outcome", "none"))
	print("  Treinador 2x2 -> %s em %.1f s (foes HP %d, %d)" % [outcome, t, foes[0].hp, foes[1].hp])
	check(outcome in ["win", "lose"], "batalha de treinador termina")
	if outcome == "win":
		check(foes[0].is_fainted() and foes[1].is_fainted(), "venceu derrotando os dois")
	else:
		check(party[0].is_fainted() and party[1].is_fainted(), "perdeu com a party toda desmaiada")
	_done(a)


# --- Itens, item do treinador, 2x1 com aliado ---


func _game_with(bag: Dictionary) -> Node:
	var g: Node = load("res://core/game.gd").new()
	g.save_path = "user://test_save.json"
	g.bag = bag.duplicate()
	return g


func _items() -> void:
	var g := _game_with({"potion": 2, "antidote": 1, "revive": 1, "poke_ball": 3})
	var party := [
		Mon.create("charmander", 12), Mon.create("squirtle", 12), Mon.create("bulbasaur", 12)
	]
	party[2].hp = 0
	var a := _arena(party, [Mon.create("pidgey", 5)], {"seed": 11, "game": g})
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.ally.controller = "none"
	var p: BattleFighter = a.player
	check(
		a.battle_items() == ["antidote", "potion", "revive"],
		"bolsa rápida lista só itens de batalha (%s)" % [a.battle_items()]
	)
	p.take_damage(15, Vector3.ZERO, 0.0)
	var hp0 := p.hp
	check(a.use_item("potion"), "usa poção no controlado")
	check(
		p.hp == mini(hp0 + 20, p.max_hp) and p.mon.hp == p.hp,
		"poção cura 20 e ressincroniza o lutador (%d -> %d)" % [hp0, p.hp]
	)
	check(int(g.bag.get("potion", 0)) == 1, "poção sai da bolsa")
	check(
		near(a.item_cd, 3.0, 0.001) and p.gcd_t >= 1.0,
		"item custa cooldown global de 3 s e trava 1 GCD"
	)
	check(not a.use_item("potion"), "cooldown de item bloqueia outro uso")
	_run(a, 3.1)
	p.stagger()
	check(
		not a.use_item("potion") and int(g.bag.get("potion", 0)) == 1,
		"exausto (stagger) não usa item"
	)
	_run(a, 2.1)
	var al: BattleFighter = a.ally
	al.apply_status("poison")
	check(a.use_item("antidote", al.mon), "antídoto no aliado (mon escolhido da party)")
	check(al.status == "" and al.mon.status == "", "status do aliado curado e ressincronizado")
	_run(a, 3.1)
	check(not a.use_item("potion", party[2]), "poção não funciona em desmaiado")
	check(
		a.use_item("revive", party[2]) and party[2].hp == party[2].max_hp / 2,
		"revive no desmaiado da party"
	)
	check(not g.bag.has("revive"), "revive consumido")
	_done(a)
	g.free()


func _trainer_item() -> void:
	var party := [Mon.create("charmander", 10)]
	var foes := [Mon.create("geodude", 10)]
	var a := _arena(
		party,
		foes,
		{"kind": "trainer", "trainer_id": "brock", "seed": 9, "trainer_item": "super_potion"}
	)
	check(a.ally == null, "batalha de treinador é 1x1 (sem aliado)")
	_run(a, TRAINER_INTRO)
	var e: BattleFighter = a.enemy
	e.take_damage(int(e.max_hp * 0.5), Vector3.ZERO, 0.0)
	_run(a, 0.3)
	check(not e.item_used, "treinador não usa item com HP > 35%")
	var low := int(e.max_hp * 0.3)
	e.hp = low
	_run(a, 0.1)
	check(
		e.item_used and e.hp == mini(low + 60, e.max_hp),
		"treinador usa super poção com HP <= 35%% (%d)" % e.hp
	)
	e.hp = low
	_run(a, 1.0)
	check(e.hp <= low, "item do treinador é usado só uma vez")
	_done(a)


## Arena 2x1 parada: inimigo e controlado parados, só o aliado age.
func _ally_arena(g: Node = null) -> Node:
	var party := [Mon.create("charmander", 12), Mon.create("squirtle", 12)]
	var o := {"seed": 21}
	if g:
		o["game"] = g
	var a := _arena(party, [Mon.create("rattata", 12)], o)
	_run(a, 1.3)
	a.enemy.controller = "none"
	return a


func _ally_modes() -> void:
	var a := _ally_arena()
	check(
		is_instance_valid(a.ally) and a.ally.mon != a.player.mon and a.ally.controller == "ai",
		"selvagem 2x1: aliado IA entra"
	)
	check(a.ally_mode == BattleAI.FREE, "comando padrão LIVRE")
	a.ally_mode = BattleAI.ATTACK
	check(a.cycle_ally_mode() == BattleAI.DEFEND, "F alterna ATTACK -> DEFEND")
	a.ally.moves = []  # só posicionamento
	a.ally.position = Vector3(4, 0, 4)
	_run(a, 4.0)
	var p: BattleFighter = a.player
	var al: BattleFighter = a.ally
	var to_e := p.flat_to(a.enemy)
	var to_a := p.flat_to(al)
	var along := to_a.dot(to_e.normalized())
	var off := (to_a - to_e.normalized() * along).length()
	check(
		along > 0.5 and along < to_e.length() and off < 0.6,
		"DEFEND: aliado fica entre o controlado e o inimigo (along %.2f, off %.2f)" % [along, off]
	)
	check(al.flat_to(p).length() <= 1.5 + 0.45, "DEFEND: a até 1,5 m do controlado")
	# Selvagem foca o tanque em DEFEND (+2 de peso).
	a.enemy.controller = "ai"
	a.enemy.ai.retarget_t = 0.0
	a.enemy.ai.pick_target(DT)
	check(a.enemy.opponent == al, "selvagem mira o aliado em DEFEND")
	_done(a)
	# SUPPORT: cura o controlado com item quando HP < 50%.
	var g := _game_with({"potion": 1, "super_potion": 1})
	var b := _ally_arena(g)
	b.ally.moves = []  # não derruba o selvagem durante o teste
	b.ally_mode = BattleAI.ATTACK
	b.cycle_ally_mode()
	check(b.cycle_ally_mode() == BattleAI.SUPPORT, "F alterna DEFEND -> SUPPORT")
	var bp: BattleFighter = b.player
	bp.hp = int(bp.max_hp * 0.6)
	_run(b, 0.2)
	check(g.bag.size() == 2, "SUPPORT não cura com HP >= 50%")
	var low := 5
	bp.hp = low
	bp.mon.hp = low
	_run(b, 0.1)
	check(
		bp.hp > low and bp.mon.hp == bp.hp,
		"SUPPORT: aliado cura o controlado (%d -> %d)" % [low, bp.hp]
	)
	check(
		not g.bag.has("super_potion") and g.bag.has("potion"),
		"SUPPORT escolhe o melhor item para o HP que falta"
	)
	bp.hp = low
	_run(b, 1.0)
	check(bp.hp == low and g.bag.has("potion"), "SUPPORT respeita o cooldown de item")
	_run(b, 2.5)
	check(bp.hp > low and not g.bag.has("potion"), "SUPPORT cura de novo depois do cooldown")
	_done(b)
	g.free()


func _control_swap() -> void:
	var a := _ally_arena()
	var m0: Mon = a.player.mon
	var m1: Mon = a.ally.mon
	check(a.swap(), "Tab troca o controle entre os dois")
	check(
		(
			a.player.mon == m1
			and a.ally.mon == m0
			and a.player.controller == "player"
			and a.ally.controller == "ai"
		),
		"controle passou para o aliado e o outro virou IA"
	)
	a.player.take_damage(a.player.hp, Vector3.ZERO, 0.0)
	check(
		a.player.mon == m0 and a.ally == null, "controlado desmaia: controle volta para quem sobrou"
	)
	_run(a, 1.2)
	check(a.state == "fight" and a.player.active(), "luta segue com um só mon")
	_done(a)
	var party := [
		Mon.create("charmander", 12), Mon.create("squirtle", 12), Mon.create("pidgey", 12)
	]
	var b := _arena(party, [Mon.create("rattata", 12)], {"seed": 4})
	_run(b, 1.3)
	check(b.send_in(2, true) and b.ally.mon == party[2], "escolhe da party quem entra como aliado")
	_run(b, 1.1)
	check(
		b.send_in(1) and b.player.mon == party[1] and b.ally.mon == party[2],
		"escolhe da party quem entra como controlado"
	)
	_done(b)


const DUOS := [
	["charmander", 9, "bulbasaur", 9, "rattata", 11],
	["squirtle", 9, "pidgey", 9, "spearow", 11],
	["pikachu", 9, "geodude", 9, "pidgey", 12],
]


func _two_vs_one(i: int) -> void:
	var m: Array = DUOS[i]
	var party := [Mon.create(m[0], m[1]), Mon.create(m[2], m[3])]
	var xp0: Array = party.map(func(x): return x.xp)
	var a := _arena(party, [Mon.create(m[4], m[5])], {"seed": 300 + i, "autoplay": true})
	a.ally_mode = i  # ATTACK, DEFEND, SUPPORT
	check(is_instance_valid(a.ally), "2x1 autoplay com aliado")
	var t := 0.0
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
	var got: Dictionary = a.get_meta("got")
	var outcome := String(got.get("outcome", "none"))
	print(
		(
			"  2x1 %s+%s vs %s Lv%d [%s] -> %s em %.1f s, %d acertos, HP %d/%d e %d/%d, PP %.0f e %.0f"
			% [
				m[0],
				m[2],
				m[4],
				m[5],
				a.ALLY_MODE_NAMES[i],
				outcome,
				t,
				a.hits,
				party[0].hp,
				party[0].max_hp,
				party[1].hp,
				party[1].max_hp,
				party[0].pp,
				party[1].pp
			]
		)
	)
	check(outcome in ["win", "lose"], "2x1 IA termina (%s)" % m[0])
	check(party[1].pp < party[1].pp_base or party[0].pp < party[0].pp_base, "PP persistido nos Mon")
	if outcome == "win":
		var alive: Array = party.filter(func(x): return not x.is_fainted())
		var gained: Array = []
		for k in 2:
			if party[k].xp > xp0[k]:
				gained.append(party[k])
		check(
			gained.size() == alive.size() and got.get("exp", []).size() == alive.size(),
			"XP dividida entre os participantes vivos (%d)" % gained.size()
		)
	else:
		check(party[0].is_fainted() and party[1].is_fainted(), "2x1 perdido com os dois desmaiados")
	_done(a)


# --- Pausa (Esc), falas do treinador, resultado do fim, captura com equipe cheia ---


func _pause() -> void:
	var a := _arena([Mon.create("charmander", 10)], [Mon.create("pidgey", 10)], {"seed": 4})
	check(not a.open_pause(), "pausa não abre na abertura")
	_run(a, 1.3)
	check(a.open_pause() and a.pause_open, "Esc abre a pausa na luta")
	var ids: Array = a.pause_items().map(func(it): return it.id)
	check(ids == ["ally_mode", "run", "resume"], "itens da pausa sem aliado (%s)" % [ids])
	var e: BattleFighter = a.enemy
	var at := e.position
	var hp := e.hp
	_run(a, 2.0)
	check(e.position == at and e.hp == hp, "a luta para com a pausa aberta")
	a.step(DT)
	check(a.hud.pause_text().contains("FUGIR"), "HUD mostra a lista da pausa")
	a.choose_pause("resume")
	check(not a.pause_open and a.state == "fight", "VOLTAR fecha a pausa")
	a.open_pause()
	a.choose_pause("run")
	check(a.state == "ending" and a.result.outcome == "run", "FUGIR foge de selvagem")
	_done(a)
	var t := _arena(
		[Mon.create("charmander", 10)], [Mon.create("pidgey", 3)], {"kind": "trainer", "seed": 3}
	)
	_run(t, TRAINER_INTRO)
	t.open_pause()
	t.choose_pause("run")
	check(t.pause_open and t.state == "fight", "FUGIR recusa em treinador e a pausa fica aberta")
	check(t.log_lines[-1].begins_with("Não! Não dá para fugir"), "aviso de treinador no log")
	_done(t)
	var party := [Mon.create("charmander", 12), Mon.create("squirtle", 12)]
	var d := _arena(party, [Mon.create("rattata", 12)], {"seed": 21})
	_run(d, 1.3)
	d.open_pause()
	ids = d.pause_items().map(func(it): return it.id)
	check("control_other" in ids, "CONTROLAR O OUTRO com dois em campo")
	var before: BattleFighter = d.player
	d.choose_pause("control_other")
	check(d.player != before and not d.pause_open, "CONTROLAR O OUTRO troca e fecha")
	_done(d)


func _trainer_lines() -> void:
	var foes := [Mon.create("weedle", 3), Mon.create("caterpie", 3)]
	var a := _arena(
		[Mon.create("charmander", 20)],
		foes,
		{"kind": "trainer", "trainer_id": "bug_catcher_rick", "seed": 6}
	)
	var nm: String = a.trainer_name()
	check(nm != "" and not nm.begins_with("O treinador"), "nome do treinador (%s)" % nm)
	check(
		a.hud.banner_text() == "%s quer lutar!" % nm, "faixa de desafio (%s)" % a.hud.banner_text()
	)
	check(not a.enemy.visible, "1º Pokémon só aparece depois do desafio")
	_run(a, 1.3)
	check(a.enemy.visible, "1º Pokémon aparece")
	check(
		a.hud.banner_text() == "%s mandou Weedle!" % nm,
		"mandou com o nome (%s)" % a.hud.banner_text()
	)
	_run(a, 1.3)
	check(a.state == "fight", "luta depois da abertura do treinador")
	a.enemy.controller = "none"
	a.enemy.take_damage(a.enemy.hp, Vector3.ZERO, 0.0)
	a.step(DT)
	check("Volte, Weedle!" in a.log_lines, "Volte, X! na troca")
	_run(a, 0.6)
	check(
		("%s vai mandar Caterpie!" % nm) in a.log_lines,
		"vai mandar com o nome (%s)" % [a.log_lines.slice(-3)]
	)
	_run(a, 1.5)
	check(a.enemy.mon == foes[1] and a.enemy.visible, "manda o 2º Pokémon")
	_done(a)
	var r := _arena(
		[Mon.create("charmander", 20)],
		[Mon.create("pidgey", 3)],
		{"kind": "trainer", "trainer_id": "rival_blue_route22", "seed": 6}
	)
	check(not r.trainer_name().contains("{RIVAL}"), "rival com nome (%s)" % r.trainer_name())
	_done(r)


func _results() -> void:
	var g := _game_with({})
	var mine := Mon.create("charmander", 5)
	var a := _arena(
		[mine],
		[Mon.create("geodude", 12)],
		{"kind": "trainer", "trainer_id": "brock", "seed": 2, "game": g}
	)
	_run(a, TRAINER_INTRO)
	a.enemy.controller = "none"
	a.enemy.last_hit_by = a.player
	var lv0 := mine.level
	a.enemy.take_damage(a.enemy.hp, Vector3.ZERO, 0.0)
	a.step(DT)
	check(a.state == "ending", "vitória entra no fim")
	check(not a.log_lines.any(func(l): return l.begins_with("+")), "sem popup de EXP na hora")
	var saw_fill := false
	var t := 0.0
	while a.state != "done" and t < 30.0:
		a.step(DT)
		t += DT
		if a.state == "results" and a.hud._player_card.script_xp >= 0.0:
			saw_fill = true
	var lines: Array = a.log_lines
	var gained := lines.filter(func(l): return l.contains(" ganhou ") and l.ends_with(" de EXP."))
	check(gained.size() == 1, "linha de EXP no resultado (%s)" % [lines.slice(-6)])
	check(saw_fill, "barra de EXP enche no cartão")
	if mine.level > lv0:
		check(
			lines.has("%s subiu para o Nv %d!" % [mine.display_name, mine.level]),
			"linha de nível no resultado"
		)
	var prize: int = g.trainer_payout("brock", 12)
	check(
		lines[-1] == "Você ganhou ₽%d pela vitória!" % prize,
		"linha do prêmio por último (%s)" % lines[-1]
	)
	check(a.state == "done" and a.get_meta("got").outcome == "win", "resultado termina a batalha")
	_done(a)
	g.free()


func _capture_pc_and_ball() -> void:
	var g := _game_with({"poke_ball": 5, "great_ball": 2, "master_ball": 1})
	for i in 6:
		g.party.append(Mon.create("rattata", 5))
	g.flags["selected_ball"] = "great_ball"
	var a := _arena([g.party[0]], [Mon.create("pidgey", 3)], {"seed": 3, "game": g})
	check(a._pick_ball() == "great_ball", "Q usa a bola escolhida na Bolsa")
	g.flags["selected_ball"] = "master_ball"
	_run(a, 1.3)
	a.enemy.controller = "none"
	check(a.throw_ball(), "joga a bola")
	var t := 0.0
	while a.state == "capture" and t < 10.0:
		a.step(DT)
		t += DT
	var line := String(a.log_lines[-1])
	check(
		line.contains("foi capturado!") and line.ends_with("Pidgey foi mandado para o PC."),
		"equipe cheia avisa o PC (%s)" % line
	)
	check(int(g.bag.get("master_ball", 0)) == 0, "gastou a bola escolhida")
	_done(a)
	g.free()
	var b: Node = load(ARENA).instantiate()
	b.manual = true
	root.add_child(b)
	b.start([Mon.create("charmander", 5)], [Mon.create("pidgey", 3)], {"seed": 1})
	check(
		b.fight_speed in [0.6, 1.0],
		"sem opts.speed usa a velocidade das opções (%.1f)" % b.fight_speed
	)
	_done(b)


## Batalha automática (padrão do jogo): sem autoplay o mon do jogador já luta com a IA, troca sozinho
## quando desmaia e usa os ajustes do lado A (player_think_scale, player_item, enemy_think_scale).
func _auto_battle() -> void:
	var party := [Mon.create("charmander", 7), Mon.create("squirtle", 7)]
	var foes := [Mon.create("geodude", 12), Mon.create("onix", 12)]
	var a := _arena(
		party,
		foes,
		{
			"kind": "trainer",
			"trainer_name": "Time B",
			"seed": 9,
			"auto_battle": true,
			"tutorial": true,
			"player_think_scale": 0.5,
			"player_item": "potion",
			"enemy_think_scale": 1.3,
		}
	)
	_run(a, 1.5)
	check(a.player.controller == "ai", "batalha automática: IA controla o mon do jogador")
	check(a.tutorial == null, "batalha automática: sem lição de teclas")
	check(near(a.player.ai.think_scale, 0.5, 0.001), "player_think_scale no lado A")
	check(a.player.trainer_item == "potion", "player_item no lado A")
	check(near(a.enemy.ai.think_scale, 1.3, 0.001), "enemy_think_scale no lado B")
	var t := 0.0
	var sent := {}
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
		if is_instance_valid(a.player):
			sent[a.player.mon] = true
			check(a.player.controller == "ai", "o mon que entra também é IA")
	var outcome := String(a.get_meta("got").get("outcome", "none"))
	check(outcome in ["win", "lose"], "batalha automática termina (%s em %.1f s)" % [outcome, t])
	check(sent.size() == 2 or outcome == "win", "troca sozinha quando o mon desmaia")
	check(party.any(func(m): return m.hp > 0) or outcome == "lose", "resultado coerente")
	_done(a)


## opts.no_rewards: a vitória não dá XP, EVs nem prêmio.
func _no_rewards() -> void:
	var mine := Mon.create("charmander", 20)
	var xp0 := mine.xp
	var a := _arena(
		[mine],
		[Mon.create("caterpie", 3)],
		{"kind": "trainer", "trainer_id": "brock", "seed": 4, "autoplay": true, "no_rewards": true}
	)
	var t := 0.0
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
	var got: Dictionary = a.get_meta("got")
	check(String(got.get("outcome", "")) == "win", "no_rewards: a luta termina com vitória")
	check(mine.xp == xp0 and mine.ev_total() == 0, "no_rewards: sem XP nem EVs")
	check(got.get("exp", []).is_empty() and int(got.get("prize", 0)) == 0, "no_rewards: sem prêmio")
	_done(a)
