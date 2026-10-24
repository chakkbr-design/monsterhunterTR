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
	for i in 4:
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
	f.stamina = f.pp_max
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
	var d1 := hp0 - e.hp
	_run(a, 1.0)
	var d2 := hp0 - e.hp - d1
	check(d1 == maxi(1, int(e.max_hp / 32.0)) and d2 > d1, "Toxic piora (%d, %d)" % [d1, d2])
	e.clear_status()
	check(e.apply_status("freeze") and not e.can_act(), "congelado não age")
	_run(a, 2.6)
	check(e.status == "" and e.can_act(), "descongela sozinho")
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
	_run(a, BattleMoveEffects.TAILWIND_TURNS * BattleMoveEffects.TURN)
	check(near(p.stat("spe"), spe0, 0.01), "Tailwind acaba")
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
	_run(a, BattleMoveEffects.ROOST_TIME + 0.2)
	check("flying" in p.types, "Voador volta depois do Roost")
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
