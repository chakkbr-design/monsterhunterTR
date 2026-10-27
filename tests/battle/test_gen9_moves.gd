extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_gen9_moves.gd
## Golpes da Gen 9 dos Pokémon 1-51 e as mecânicas de battle/battle_move_effects.gd.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const KINDS := [
	"dash",
	"arc",
	"multi_arc",
	"whip",
	"projectile",
	"homing",
	"stream",
	"beam",
	"aoe_self",
	"aoe_target",
	"zone",
	"self_buff",
	"debuff_aoe",
	"clones"
]
const NEW_MOVES := [
	"acid_spray",
	"after_you",
	"agility",
	"air_cutter",
	"aromatherapy",
	"assurance",
	"belch",
	"bug_bite",
	"bulldoze",
	"charm",
	"coil",
	"confuse_ray",
	"copycat",
	"cosmic_power",
	"covet",
	"cross_poison",
	"disarming_voice",
	"discharge",
	"double_edge",
	"echoed_voice",
	"endeavor",
	"extrasensory",
	"feather_dance",
	"feint",
	"fell_stinger",
	"fire_spin",
	"fissure",
	"flare_blitz",
	"flash_cannon",
	"flatter",
	"follow_me",
	"fury_cutter",
	"gastro_acid",
	"giga_drain",
	"grassy_terrain",
	"gravity",
	"gunk_shot",
	"gyro_ball",
	"haze",
	"healing_wish",
	"hyper_voice",
	"ice_fang",
	"imprison",
	"incinerate",
	"inferno",
	"iron_defense",
	"laser_focus",
	"life_dew",
	"light_screen",
	"mean_look",
	"meteor_mash",
	"metronome",
	"mimic",
	"moonblast",
	"moonlight",
	"nasty_plot",
	"night_slash",
	"nuzzle",
	"petal_blizzard",
	"play_nice",
	"play_rough",
	"pluck",
	"poison_fang",
	"power_whip",
	"protect",
	"psychic",
	"quick_guard",
	"quiver_dance",
	"rage_powder",
	"rest",
	"roost",
	"round",
	"safeguard",
	"sandstorm",
	"shell_smash",
	"sludge_bomb",
	"spit_up",
	"spite",
	"stockpile",
	"stored_power",
	"superpower",
	"swallow",
	"sweet_kiss",
	"swords_dance",
	"synthesis",
	"tailwind",
	"take_down",
	"thunder_fang",
	"thunder_punch",
	"toxic",
	"toxic_spikes",
	"venoshock",
	"wave_crash",
	"will_o_wisp",
	"worry_seed",
	"x_scissor",
	"zen_headbutt"
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	seed(9)  # Mon.create sorteia IVs/natureza/habilidade no RNG global: luta de IA repetível
	_data()
	_hits_odds()
	_recoil()
	_protect_and_feint()
	_quick_guard()
	_toxic_and_freeze()
	_stockpile()
	_ohko_and_endeavor()
	_field_moves()
	_priority()
	_variable_power()
	_support()
	_helping_hand()
	_call_moves()
	_counter()
	_substitute()
	_switch_moves()
	_endure_and_false_swipe()
	_focus_punch()
	_hazards()
	_terrains()
	_conditional_power()
	_jealousy_and_mist()
	_taunt_and_sleep()
	for i in 6:
		_ai_fight(i)
	print("gen9_moves: %d checks, %d falhas" % [_count, _fails])
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
	opts["speed"] = 1.0
	opts["auto_battle"] = false
	opts["damage_pace"] = 1.0
	opts["field_objects"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada (os dois sem controle), intro já passada.
func _still(me := "charmander", foe := "rattata", lv := 30, foe_lv := 30) -> Node:
	var a := _arena([Mon.create(me, lv)], [Mon.create(foe, foe_lv)], {"seed": 11})
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	# Um golpe que a IA já soltou (investida, Sucker Punch) termina; depois tudo volta ao zero.
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.clear_status()
		f.confusion_t = 0.0
		f.trap_t = 0.0
		f.evasion_t = 0.0
		for k in f.stages:
			f.stages[k] = 0
		f.knock = Vector3.ZERO
		_ready_all(f)
	return a


func _ready_all(f: BattleFighter) -> void:
	f.move_cd.clear()
	f.gcd_t = 0.0
	f.stun_t = 0.0
	f.impact_t = 0.0


func _data() -> void:
	var ok := true
	for id in NEW_MOVES:
		var mv := Dex.move(id)
		if mv.is_empty() or not String(mv.get("kind", "")) in KINDS:
			ok = false
			print("  golpe sem dados/kind: ", id)
	check(ok, "97 golpes novos com kind válido")
	check(NEW_MOVES.size() == 97, "lista com 97 golpes")
	var missing := []
	for sp in Dex.all_species():
		var d := Dex.species(sp)
		if int(d.get("dex_no", 999)) > 51:
			continue
		for e in d.get("learnset", []):
			if Dex.move(String(e[1])).is_empty():
				missing.append(String(e[1]))
	check(missing.is_empty(), "learnsets 1-51 só com golpes do jogo %s" % str(missing))
	check(
		Dex.move("double_edge").kind == "dash" and float(Dex.move("double_edge").range) >= 6.0,
		"Double-Edge fecha distância"
	)
	check(int(Dex.move("protect").priority) == 4, "Protect prioridade +4")
	check(Dex.move("hyper_voice").get("multi_target") == "all_opponents", "Hyper Voice é de área")
	check(not Dex.move("iron_tail").has("crit"), "Iron Tail sem crítico alto (Gen 9)")


func _hits_odds() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var n := {2: 0, 3: 0, 4: 0, 5: 0}
	for i in 4000:
		var m := fx.roll_hits(Dex.move("fury_swipes"))
		n[int(m.hits)] += 1
	check(
		near(n[2] / 4000.0, 0.35, 0.03) and near(n[3] / 4000.0, 0.35, 0.03),
		"2-3 acertos 35%% cada %s" % str(n)
	)
	check(
		near(n[4] / 4000.0, 0.15, 0.025) and near(n[5] / 4000.0, 0.15, 0.025),
		"4-5 acertos 15%% cada"
	)
	check(
		int(fx.roll_hits(Dex.move("pin_missile")).count) >= 2,
		"Pin Missile rola o número de agulhas"
	)
	check(fx.roll_hits(Dex.move("double_kick")).hits == 2, "Double Kick fica em 2")
	a.free()


func _recoil() -> void:
	var a := _still("rattata", "slowbro", 40, 50)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var hp_e := e.hp
	check(a.moves.use(p, "double_edge"), "usa Double-Edge de longe")
	_run(a, 1.2)
	var dealt := hp_e - e.hp
	check(dealt > 0, "Double-Edge acertou a 6 m (%d)" % dealt)
	check(
		near(p.max_hp - p.hp, int(dealt * 0.33), 1.0),
		"recuo de 1/3 (%d de %d)" % [p.max_hp - p.hp, dealt]
	)
	a.free()


func _protect_and_feint() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var hp0 := e.hp
	check(a.moves.use(e, "protect"), "usa Protect")
	_run(a, 0.1)
	check(a.moves.use(p, "ember"), "solta Ember no protegido")
	_run(a, 0.6)
	check(e.hp == hp0, "Protect segura o golpe")
	_run(a, 1.5)
	_ready_all(e)
	_ready_all(p)
	check(a.moves.use(e, "protect"), "Protect de novo")
	_run(a, 0.05)
	check(a.moves.use(p, "feint"), "Feint")
	_run(a, 0.6)
	check(e.hp < hp0, "Feint atravessa o Protect (%d -> %d)" % [hp0, e.hp])
	a.free()


func _quick_guard() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var hp0 := e.hp
	check(a.moves.use(e, "quick_guard"), "Quick Guard")
	_run(a, 0.05)
	check(a.moves.use(p, "quick_attack"), "Quick Attack")
	_run(a, 0.6)
	check(e.hp == hp0, "Quick Guard para golpe de prioridade")
	a.free()


func _toxic_and_freeze() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.immortal = true
	var hp0 := e.hp
	check(e.apply_status("toxic"), "Toxic")
	check(e.mon.status == "poison", "fora da luta vira veneno comum")
	_run(a, 1.05)
	check(e.hp == hp0, "Toxic não tira HP por segundo (fim de turno)")
	a.end_turn.run()
	var d1 := hp0 - e.hp
	a.end_turn.run()
	var d2 := hp0 - e.hp - d1
	var u := maxi(1, int(e.max_hp / 16.0))
	check(d1 == u and d2 == 2 * u, "Toxic piora: 1/16, 2/16 (%d, %d)" % [d1, d2])
	e.clear_status()
	check(e.apply_status("freeze") and not e.can_act(), "congelado não age")
	_run(a, 2.6)
	check(e.status == "freeze", "congelado não descongela por tempo")
	var tries := 0
	while e.status == "freeze" and tries < 200:
		e.try_act()
		tries += 1
	check(e.status == "" and e.can_act(), "descongela na tentativa de agir (20%%, %d)" % tries)
	e.apply_status("freeze")
	a.moves.hit(p, e, Dex.move("ember"), Vector3.FORWARD)
	check(e.status != "freeze", "golpe de fogo descongela")
	var s := _still("pikachu", "magnemite")
	check(s.moves.effects.blocks_status(s.player, s.enemy, "poison"), "Aço não se envenena")
	s.free()
	a.free()


func _stockpile() -> void:
	var a := _still("jigglypuff", "rattata")
	var p: BattleFighter = a.player
	var fx: BattleMoveEffects = a.moves.effects
	check(not fx.usable(p, Dex.move("spit_up")), "Spit Up sem Stockpile falha")
	check(a.moves.use(p, "stockpile"), "Stockpile 1")
	_run(a, 0.4)
	_ready_all(p)
	check(a.moves.use(p, "stockpile"), "Stockpile 2")
	_run(a, 0.4)
	check(int(fx.st(p).stock) == 2 and int(p.stages.def) == 2, "guardou 2 e Defesa +2")
	_ready_all(p)
	p.hp = p.max_hp / 4
	var hp0 := p.hp
	check(a.moves.use(p, "swallow"), "Swallow")
	_run(a, 0.4)
	check(p.hp - hp0 >= int(p.max_hp * 0.5) - 1, "Swallow com 2 cura metade")
	check(int(p.stages.def) == 0 and int(fx.st(p).stock) == 0, "Swallow devolve os estágios")
	a.free()


func _ohko_and_endeavor() -> void:
	var a := _still("diglett", "rattata", 30, 40)
	var fx: BattleMoveEffects = a.moves.effects
	var e: BattleFighter = a.enemy
	a.moves.hit(a.player, e, Dex.move("fissure"), Vector3.FORWARD)
	check(e.hp == e.max_hp, "Fissure não pega nível maior")
	check(fx.accuracy_of(a.player, Dex.move("fissure")) < 30.0, "precisão do OHKO cai com o nível")
	a.free()
	a = _still("diglett", "rattata", 30, 20)
	e = a.enemy
	a.moves.hit(a.player, e, Dex.move("fissure"), Vector3.FORWARD)
	check(e.hp == 0, "Fissure derruba de uma vez")
	a.free()
	a = _still("rattata", "slowbro", 30, 30)
	a.player.hp = 7
	a.moves.hit(a.player, a.enemy, Dex.move("endeavor"), Vector3.FORWARD)
	check(a.enemy.hp == 7, "Endeavor iguala o HP (%d)" % a.enemy.hp)
	a.free()
	a = _still("diglett", "pidgey", 30, 20)
	a.moves.hit(a.player, a.enemy, Dex.move("fissure"), Vector3.FORWARD)
	check(a.enemy.hp == a.enemy.max_hp, "Fissure não pega Voador")
	a.free()


func _field_moves() -> void:
	var a := _still("pidgey", "pidgey")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	var spe0 := p.stat("spe")
	var spe_e := e.stat("spe")
	check(a.moves.use(p, "tailwind"), "Tailwind")
	_run(a, 0.4)
	check(
		near(p.stat("spe"), spe0 * 2.0, 0.01) and near(e.stat("spe"), spe_e, 0.01),
		"Tailwind dobra a Speed do lado"
	)
	for i in BattleMoveEffects.TAILWIND_TURNS:
		a.end_turn.run()
	check(near(p.stat("spe"), spe0, 0.01), "Tailwind acaba em 4 rodadas")
	_ready_all(p)
	check(a.moves.use(p, "light_screen"), "Light Screen")
	_run(a, 0.4)
	check(
		near(fx.damage_mult(e, p, Dex.move("ember")), 0.5, 0.001),
		"Light Screen corta especial pela metade"
	)
	check(near(fx.damage_mult(e, p, Dex.move("scratch")), 1.0, 0.001), "e não mexe no físico")
	_ready_all(e)
	check(a.moves.use(e, "gravity"), "Gravity")
	_run(a, 0.4)
	check(not p.can_jump(), "Gravity: ninguém pula")
	var prof := fx.defender_profile(e, p, Dex.move("earthquake"))
	check(Dex.effectiveness("ground", prof.types) > 0.0, "Gravity: Terra pega Voador")
	check(fx.accuracy_of(e, Dex.move("sand_attack")) > 100.0, "Gravity aumenta a precisão")
	p.stages.atk = 3
	e.stages.def = -2
	_ready_all(e)
	check(a.moves.use(e, "haze"), "Haze")
	_run(a, 0.4)
	check(int(p.stages.atk) == 0 and int(e.stages.def) == 0, "Haze zera os estágios")
	_ready_all(e)
	check(a.moves.use(e, "safeguard"), "Safeguard")
	_run(a, 0.4)
	check(fx.blocks_status(p, e, "paralysis"), "Safeguard bloqueia status")
	a.free()


func _priority() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	check(a.moves.use(p, "whirlwind"), "Whirlwind")
	check(p.prepare_t >= 0.6 / 1.45, "prioridade -6 sai devagar (%.2f s)" % p.prepare_t)
	a.free()


func _variable_power() -> void:
	var a := _still("geodude", "pikachu")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	check(
		float(fx.adjust_move(p, e, Dex.move("gyro_ball")).power) > 40.0,
		"Gyro Ball mais forte no lento (IVs sorteados: 25 x Speed dele / minha + 1)"
	)
	e.apply_status("poison")
	check(
		near(float(fx.adjust_move(p, e, Dex.move("venoshock")).power), 130.0, 0.1),
		"Venoshock dobra no envenenado"
	)
	p.stages.atk = 2
	p.stages.spe = 1
	check(
		near(float(fx.adjust_move(p, e, Dex.move("stored_power")).power), 80.0, 0.1),
		"Stored Power +20 por estágio"
	)
	p.stages.atk = 0
	fx.on_use(p, Dex.move("fury_cutter"))
	fx.after_hit(p, e, Dex.move("fury_cutter"), 5)
	fx.on_use(p, Dex.move("fury_cutter"))
	check(
		near(float(fx.adjust_move(p, e, Dex.move("fury_cutter")).power), 80.0, 0.1),
		"Fury Cutter dobra em sequência"
	)
	fx.st(p).laser = fx.now + 5.0
	check(
		int(fx.adjust_move(p, e, Dex.move("tackle")).get("crit", 0)) == 3,
		"Laser Focus garante crítico"
	)
	e.hp = 1
	a.moves.hit(p, e, Dex.move("fell_stinger"), Vector3.FORWARD)
	check(int(p.stages.atk) == 3, "Fell Stinger: Ataque +3 no nocaute")
	a.free()


func _support() -> void:
	var a := _still("pidgey", "zubat")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	p.hp = p.max_hp / 4
	var hp0 := p.hp
	check(a.moves.use(p, "roost"), "Roost")
	_run(a, 0.4)
	check(p.hp >= hp0 + p.max_hp / 2 - 1 and not "flying" in p.types, "Roost cura e tira o Voador")
	a.end_turn.run()
	_run(a, 0.1)
	check("flying" in p.types, "Voador volta no fim da rodada do Roost")
	check(not fx.usable(p, Dex.move("healing_wish")), "Healing Wish sem reserva falha")
	e.moves = ["mean_look", "ember"]
	a.moves.hit(e, p, Dex.move("mean_look"), Vector3.BACK)
	check(not a.run_away(), "Mean Look impede a fuga")
	fx.st(e).imprison = true
	check(not fx.usable(p, Dex.move("ember")), "Imprison bloqueia golpe que o outro conhece")
	_ready_all(p)
	p.hp = 5
	p.moves = ["rest"]
	check(a.moves.use(p, "rest"), "Rest")
	_run(a, 0.4)
	check(p.hp == p.max_hp and p.status == "sleep", "Rest cura tudo e dorme")
	a.free()


func _helping_hand() -> void:
	var a := _arena(
		[Mon.create("charmander", 30), Mon.create("pidgey", 30)],
		[Mon.create("rattata", 30), Mon.create("rattata", 30)],
		{"seed": 11, "battle_size": 2}
	)
	_run(a, 1.3)
	var mine: Array = a.fighters.filter(func(f): return f.side == 0 and f.active())
	var foe: BattleFighter = a.fighters.filter(func(f): return f.side == 1 and f.active())[0]
	check(mine.size() == 2, "dupla com dois do meu lado")
	if mine.size() < 2:
		a.free()
		return
	for f in a.fighters:
		f.controller = "none"
	_run(a, 1.5)
	var helper: BattleFighter = mine[1]
	var striker: BattleFighter = mine[0]
	var fx: BattleMoveEffects = a.moves.effects
	_ready_all(helper)
	helper.moves = ["helping_hand"]
	var ember := Dex.move("ember")
	check(is_equal_approx(fx.damage_mult(striker, foe, ember), 1.0), "sem ajuda: 1x")
	check(a.moves.use(helper, "helping_hand"), "Helping Hand")
	_run(a, 0.5)
	fx.on_use(striker, ember)
	check(
		is_equal_approx(fx.damage_mult(striker, foe, ember), 1.5),
		"Helping Hand: próximo golpe do parceiro 1,5x"
	)
	_run(a, BattleMoveEffects.HELP_HOLD + 0.2)
	check(is_equal_approx(fx.damage_mult(striker, foe, ember), 1.0), "a ajuda acaba depois do uso")
	check(helper.stages.get("atk", 0) == 0, "Helping Hand não sobe o Ataque de quem usa")
	a.free()


func _call_moves() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var n0 := p.cast_n
	check(a.moves.use(p, "metronome"), "Metronome")
	_run(a, 1.0)
	check(p.cast_n >= n0 + 2, "Metronome solta outro golpe")
	a.free()


func _counter() -> void:
	var a := _still("nidoqueen", "rattata", 50, 20)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	check(a.moves.use(p, "counter"), "Counter")
	check(p.prepare_t >= 0.5 / 1.6, "Counter -5 entra devagar (%.2f s)" % p.prepare_t)
	_run(a, p.prepare_t + 0.05)
	check(fx.active(fx.st(p), "counter"), "postura do Counter ativa")
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	var took := p.max_hp - p.hp
	check(took > 0, "Counter levou o golpe físico (%d)" % took)
	check(
		e.max_hp - e.hp == mini(took * 2, e.max_hp),
		"Counter devolve 2x (%d de %d)" % [e.max_hp - e.hp, took]
	)
	e.hp = e.max_hp
	p.hp = p.max_hp
	fx.st(p).counter = fx.now + 1.0
	fx.st(p).counter_cat = "physical"
	a.moves.hit(e, p, Dex.move("ember"), Vector3.BACK)
	check(e.hp == e.max_hp, "Counter não devolve golpe especial")
	_run(a, 1.2)
	p.hp = p.max_hp
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	check(e.hp == e.max_hp, "fora da postura não devolve")
	a.free()


func _substitute() -> void:
	var a := _still("charmander", "rattata")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	check(a.moves.use(p, "substitute"), "Substitute")
	_run(a, 0.4)
	var cost := p.max_hp / 4
	check(p.hp == p.max_hp - cost and int(fx.st(p).sub) == cost, "Substitute custa 1/4 do HP")
	var hp0 := p.hp
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	check(p.hp == hp0 and int(fx.st(p).sub) < cost, "o substituto leva o golpe")
	fx.st(p).sub = 999
	a.moves.hit(e, p, Dex.move("thunder_wave"), Vector3.BACK)
	check(p.status == "", "o substituto bloqueia status")
	fx.st(p).sub = 1
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	check(int(fx.st(p).sub) == 0 and p.hp == hp0, "o substituto quebra sem passar dano")
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	check(p.hp < hp0, "sem substituto o dano volta")
	_ready_all(p)
	p.hp = p.max_hp / 5
	check(not fx.usable(p, Dex.move("substitute")), "Substitute sem HP falha")
	a.free()


func _switch_moves() -> void:
	var a := _arena(
		[Mon.create("pikachu", 30), Mon.create("squirtle", 30)],
		[Mon.create("rattata", 30), Mon.create("pidgey", 30)],
		{"seed": 11, "battle_size": 1}
	)
	_run(a, 1.3)
	for f in a.fighters:
		f.controller = "none"
	_run(a, 1.5)
	var p: BattleFighter = a.player
	_ready_all(p)
	p.stages.atk = 2
	p.crit_stage = 1
	check(a.moves.use(p, "baton_pass"), "Baton Pass")
	_run(a, 0.5)
	var q: BattleFighter = a.player
	check(q != p and q.mon.species.to_lower() == "squirtle", "Baton Pass troca com o reserva")
	check(int(q.stages.atk) == 2 and q.crit_stage == 1, "Baton Pass passa os estágios")
	q.controller = "none"
	a.moves.hit(q, a.enemy, Dex.move("u_turn"), Vector3.FORWARD)
	_run(a, 0.6)
	check(
		a.player != q and a.player.mon.species.to_lower() == "pikachu",
		"U-turn volta para o reserva"
	)
	check(int(a.player.stages.atk) == 0, "U-turn não passa estágios")
	a.player.controller = "none"
	var e: BattleFighter = a.enemy
	a.moves.hit(e, a.player, Dex.move("u_turn"), Vector3.BACK)
	_run(a, 0.6)
	check(
		a.enemy != e and a.enemy.mon.species.to_lower() == "pidgey",
		"U-turn do adversário troca o dele"
	)
	check(a.enemies[1].species.to_lower() == "rattata", "quem saiu volta a esperar na lista")
	a.free()
	var s := _still()
	check(not s.moves.effects.usable(s.player, Dex.move("baton_pass")), "Baton Pass sozinho falha")
	s.free()


func _endure_and_false_swipe() -> void:
	var a := _still("rattata", "charmander", 40, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.hp = 3
	a.moves.hit(p, e, Dex.move("false_swipe"), Vector3.FORWARD)
	check(e.hp == 1, "False Swipe deixa 1 HP (%d)" % e.hp)
	a.moves.hit(p, e, Dex.move("false_swipe"), Vector3.FORWARD)
	check(e.hp == 1, "False Swipe não derruba")
	check(int(Dex.move("endure").priority) == 4, "Endure prioridade +4")
	check(a.moves.use(e, "endure"), "Endure")
	_run(a, 0.1)
	e.hp = 2
	a.moves.hit(p, e, Dex.move("body_slam"), Vector3.FORWARD)
	check(e.hp == 1, "Endure aguenta com 1 HP")
	a.end_turn.run()
	e.immortal = true
	e.hp = 1
	a.moves.hit(p, e, Dex.move("tackle"), Vector3.FORWARD)
	check(e.hp == e.max_hp, "depois da janela o Endure não segura (o boneco caiu e recarregou)")
	a.free()


func _focus_punch() -> void:
	var a := _still("nidoking", "rattata", 30, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	p.position = e.position + Vector3(0, 0, 1.2)
	check(a.moves.use(p, "focus_punch"), "Focus Punch")
	check(p.prepare_t > 0.5, "Focus Punch concentra antes (%.2f s)" % p.prepare_t)
	_run(a, 0.2)
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	_run(a, 2.0)
	check(e.hp == e.max_hp, "apanhou na concentração: Focus Punch falha")
	fx.st(p).focus_t = fx.now - 1.0
	fx.st(p).hurt_t = fx.now - 0.5
	a.moves.hit(p, e, Dex.move("focus_punch"), Vector3.FORWARD)
	check(e.hp == e.max_hp, "dano depois de começar a concentração também faz falhar")
	fx.st(p).hurt_t = fx.now - 2.0
	a.moves.hit(p, e, Dex.move("focus_punch"), Vector3.FORWARD)
	check(e.hp < e.max_hp, "sem levar golpe o Focus Punch acerta")
	a.free()


func _hazards() -> void:
	var a := _still("pikachu", "rattata")
	var e: BattleFighter = a.enemy
	check(a.moves.use(a.player, "spikes"), "Spikes")
	_run(a, 0.3)
	var spk := e.max_hp - maxi(1, int(e.max_hp / 8.0))
	check(e.hp == spk, "Spikes tira 1/8 de quem pisa (%d/%d)" % [e.hp, e.max_hp])
	_run(a, 0.5)
	check(e.hp == spk, "Spikes pega uma vez só")
	a.free()
	a = _still("pikachu", "pidgey")
	e = a.enemy
	check(a.moves.use(a.player, "spikes"), "Spikes no Voador")
	_run(a, 0.3)
	check(e.hp == e.max_hp, "Spikes não pega Voador")
	_ready_all(a.player)
	check(a.moves.use(a.player, "stealth_rock"), "Stealth Rock")
	_run(a, 0.3)
	check(
		e.hp == e.max_hp - maxi(1, int(e.max_hp / 8.0 * 2.0)),
		"Stealth Rock pela eficácia de Pedra (Voador 2x: 1/4) %d/%d" % [e.hp, e.max_hp]
	)
	check(not a.moves.effects.spikes.is_empty(), "pedras no campo")
	a.moves.effects._rapid_spin(e)
	check(a.moves.effects.spikes.is_empty(), "Rapid Spin tira as pedras")
	a.free()


func _terrains() -> void:
	var a := _still("pikachu", "rattata")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	check(a.moves.use(p, "electric_terrain"), "Electric Terrain")
	_run(a, 0.3)
	check(near(fx.damage_mult(p, e, Dex.move("thunder_shock")), 1.3, 0.001), "Elétrico 1,3x")
	check(fx.blocks_status(e, p, "sleep"), "no campo elétrico ninguém dorme")
	_ready_all(e)
	check(a.moves.use(e, "misty_terrain"), "Misty Terrain")
	_run(a, 0.3)
	check(not fx.active(fx.field, "electric"), "um terreno tira o outro")
	check(fx.blocks_status(e, p, "burn"), "campo de névoa bloqueia status")
	check(near(fx.damage_mult(e, p, Dex.move("dragon_pulse")), 0.5, 0.001), "névoa: Dragão 0,5x")
	a.moves.hit(p, e, Dex.move("ice_spinner"), Vector3.FORWARD)
	check(not fx.active(fx.field, "misty"), "Ice Spinner destrói o terreno")
	check(int(fx.move_for(p, Dex.move("grassy_glide")).get("priority", 0)) == 0, "Glide sem grama")
	fx.set_rounds(fx.field, "grassy", BattleMoveEffects.FIELD_TURNS)
	check(
		int(fx.move_for(p, Dex.move("grassy_glide")).get("priority", 0)) == 1,
		"Grassy Glide +1 na grama"
	)
	for i in BattleMoveEffects.FIELD_TURNS:
		a.end_turn.run()
	check(not fx.active(fx.field, "grassy"), "terreno acaba em 5 rodadas")
	a.free()


func _conditional_power() -> void:
	var a := _still("nidoking", "rattata")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	var rev := Dex.move("revenge")
	fx.st(p).hit_by.clear()
	check(near(float(fx.adjust_move(p, e, rev).power), 60.0, 0.1), "Revenge normal 60")
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.BACK)
	check(near(float(fx.adjust_move(p, e, rev).power), 120.0, 0.1), "Revenge 2x depois de apanhar")
	_run(a, BattleMoveEffects.REVENGE_WINDOW + 0.2)
	check(near(float(fx.adjust_move(p, e, rev).power), 60.0, 0.1), "Revenge volta a 60")
	e.apply_status("paralysis")
	check(near(float(fx.adjust_move(p, e, Dex.move("hex")).power), 130.0, 0.1), "Hex 2x com status")
	p.apply_status("burn")
	check(near(float(fx.adjust_move(p, e, Dex.move("facade")).power), 140.0, 0.1), "Facade 2x")
	check(not fx.attacker_profile(p, e, Dex.move("facade")).burned, "Facade ignora a queimadura")
	p.clear_status()
	var wb := Dex.move("weather_ball")
	check(fx.adjust_move(p, e, wb).type == "normal", "Weather Ball sem clima é Normal")
	fx.set_weather("rain", 5)
	var w2 := fx.adjust_move(p, e, wb)
	check(
		w2.type == "water" and near(float(w2.power), 100.0, 0.1), "Weather Ball na chuva: Água 100"
	)
	fx.set_weather("sun", 5)
	check(fx.adjust_move(p, e, wb).type == "fire", "Weather Ball no sol: Fogo")
	p.hp = p.max_hp / 2
	check(
		near(float(fx.adjust_move(p, e, Dex.move("water_spout")).power), 75.0, 1.0),
		"Water Spout pela fração de HP"
	)
	a.free()
	a = _still("venusaur", "diglett")
	fx = a.moves.effects
	var hc := Dex.move("heat_crash")
	check(
		near(float(fx.adjust_move(a.player, a.enemy, hc).power), 120.0, 0.1), "Heat Crash 5x: 120"
	)
	check(
		near(float(fx.adjust_move(a.enemy, a.player, hc).power), 40.0, 0.1), "Heat Crash leve: 40"
	)
	a.free()


func _jealousy_and_mist() -> void:
	var a := _still("charmander", "rattata")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	e.immortal = true
	a.moves.hit(p, e, Dex.move("burning_jealousy"), Vector3.FORWARD)
	check(e.status == "", "Burning Jealousy sem subir atributo não queima")
	a.moves.change_stage(e, "atk", 1)
	a.moves.hit(p, e, Dex.move("burning_jealousy"), Vector3.FORWARD)
	check(e.status == "burn", "Burning Jealousy queima quem subiu atributo")
	e.clear_status()
	_run(a, BattleTurns.ROUND_SECS + 0.1)
	a.moves.hit(p, e, Dex.move("burning_jealousy"), Vector3.FORWARD)
	check(e.status == "", "só vale o turno (rodada) em que subiu")
	var lo := Dex.move("lash_out")
	check(near(float(fx.adjust_move(p, e, lo).power), 75.0, 0.1), "Lash Out normal")
	a.moves.change_stage(p, "atk", -1, e)
	check(near(float(fx.adjust_move(p, e, lo).power), 150.0, 0.1), "Lash Out 2x depois de cair")
	_ready_all(p)
	check(a.moves.use(p, "mist"), "Mist")
	_run(a, 0.3)
	var atk := int(p.stages.atk)
	a.moves.change_stage(p, "atk", -1, e)
	check(int(p.stages.atk) == atk, "Mist barra a queda vinda do adversário")
	a.moves.change_stage(p, "atk", -1)
	check(int(p.stages.atk) == atk - 1, "Mist não barra a própria queda")
	a.free()


func _taunt_and_sleep() -> void:
	var a := _still("charmander", "rattata")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var fx: BattleMoveEffects = a.moves.effects
	a.moves.hit(p, e, Dex.move("taunt"), Vector3.FORWARD)
	check(not fx.usable(e, Dex.move("growl")), "Taunt bloqueia golpe de status")
	check(fx.usable(e, Dex.move("tackle")), "Taunt deixa atacar")
	for i in BattleMoveEffects.TAUNT_TURNS:
		a.end_turn.run()
	check(fx.usable(e, Dex.move("growl")), "Taunt acaba em 3 rodadas")
	check(not fx.usable(p, Dex.move("fake_out")), "Fake Out só logo ao entrar")
	fx.st(p).entered = fx.now
	check(fx.usable(p, Dex.move("fake_out")), "Fake Out ao entrar")
	p.moves = ["snore", "ember"]
	check(not fx.usable(p, Dex.move("snore")), "Snore acordado falha")
	p.apply_status("sleep")
	p.sleep_turns = 5
	check(not a.moves.use(p, "ember"), "dormindo não solta golpe comum")
	check(a.moves.use(p, "snore"), "Snore sai dormindo")
	_run(a, 1.0)
	_ready_all(p)
	p.clear_status()
	p.hp = 10
	check(a.moves.use(p, "wish"), "Wish")
	_run(a, 0.3)
	check(p.hp == 10, "Wish ainda não cura")
	a.end_turn.run()
	a.end_turn.run()
	check(p.hp >= mini(10 + p.max_hp / 2, p.max_hp), "Wish cura metade no fim do turno seguinte")
	a.free()


## IA contra IA só com golpes novos: a luta termina e os golpes de suporte saem.
func _ai_fight(i: int) -> void:
	var sets := [
		[
			"clefairy",
			["protect", "moonblast", "metronome", "life_dew"],
			"ekans",
			["toxic", "stockpile", "spit_up", "haze"]
		],
		[
			"pidgey",
			["tailwind", "roost", "feather_dance", "double_edge"],
			"vulpix",
			["will_o_wisp", "confuse_ray", "inferno", "imprison"]
		],
		[
			"squirtle",
			["shell_smash", "wave_crash", "protect", "iron_defense"],
			"pikachu",
			["nuzzle", "light_screen", "nasty_plot", "discharge"]
		],
		[
			"sandshrew",
			["sandstorm", "swords_dance", "gyro_ball", "fissure"],
			"zubat",
			["mean_look", "quick_guard", "venoshock", "poison_fang"]
		],
		[
			"nidoqueen",
			["counter", "substitute", "spikes", "body_press"],
			"clefairy",
			["wish", "taunt", "stealth_rock", "facade"]
		],
		[
			"jigglypuff",
			["rest", "sleep_talk", "hyper_voice", "reflect"],
			"oddish",
			["misty_terrain", "strength_sap", "grassy_glide", "attract"]
		],
	]
	var m: Array = sets[i]
	var a_mon := Mon.create(m[0], 25)
	a_mon.moves = m[1]
	var b_mon := Mon.create(m[2], 25)
	b_mon.moves = m[3]
	var a := _arena([a_mon], [b_mon], {"seed": 300 + i, "autoplay": true})
	var used := {}
	a.move_used.connect(func(_u, mv: Dictionary) -> void: used[String(mv.id)] = true)
	var t := 0.0
	while a.state != "done" and t < 400.0:
		a.step(DT)
		t += DT
	print("  %s x %s: %.1f s, golpes %s" % [m[0], m[2], t, str(used.keys())])
	check(a.state == "done", "luta IA %s x %s termina" % [m[0], m[2]])
	check(used.size() >= 4, "IA usa vários golpes novos (%d)" % used.size())
	a.free()
