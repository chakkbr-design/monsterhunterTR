extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_doubles.gd
## Batalha Viva: 2x2 de treinador, Speed nova, perfis, comandos com amizade, avisos e CLASH.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_speed()
	_profiles()
	for i in 4:
		_doubles_fight(i)
	_gym_doubles()
	_commands()
	_telegraph_dodge()
	_clash()
	_flyer()
	print("doubles: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var got := {}
	a.finished.connect(func(r: Dictionary) -> void: got.merge(r), CONNECT_ONE_SHOT)
	a.set_meta("got", got)
	if not opts.has("speed"):
		opts["speed"] = 1.0
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _until_done(a: Node, cap := 600.0) -> float:
	var t := 0.0
	while a.state != "done" and t < cap:
		a.step(DT)
		t += DT
	return t


func _speed() -> void:
	check(StatCalc.battle_speed_factor(80, 40) > 1.2, "Speed dobrada dá mais de 1,2x")
	check(StatCalc.walk_speed(100) > StatCalc.walk_speed(30), "anda mais rápido com mais Speed")
	check(StatCalc.walk_speed(9999) == StatCalc.WALK_MAX, "andar limitado")


func _profiles() -> void:
	var cases := {"pidgey": "flyer", "spearow": "flyer", "zubat": "flyer"}
	for sp in cases:
		var m := Mon.create(sp, 10)
		check(BattleProfile.pick(m, m.moves) == cases[sp], "%s é %s" % [sp, cases[sp]])
	var seen := {}
	for sp in [
		"geodude", "onix", "psyduck", "pikachu", "mankey", "bulbasaur", "rattata", "clefairy"
	]:
		var m := Mon.create(sp, 15)
		seen[BattleProfile.pick(m, m.moves)] = true
	check(seen.size() >= 3, "perfis variados entre espécies (%s)" % [seen.keys()])


const TEAMS := [
	[["charmander", "pidgey", "geodude"], ["squirtle", "rattata", "spearow"]],
	[["bulbasaur", "pikachu"], ["mankey", "psyduck"]],
	[["onix", "clefairy", "zubat"], ["sandshrew", "oddish", "mankey"]],
	[["Nidoran M", "ekans"], ["paras", "jigglypuff"]],
]


func _team(ids: Array, lv: int) -> Array:
	var out: Array = []
	for id in ids:
		if not Dex.species(id).is_empty():
			out.append(Mon.create(id, lv))
	return out


func _doubles_fight(i: int) -> void:
	var a_team := _team(TEAMS[i][0], 18)
	var b_team := _team(TEAMS[i][1], 18)
	if a_team.size() < 2 or b_team.size() < 2:
		check(false, "time %d com espécies que existem" % i)
		return
	var a := _arena(
		a_team,
		b_team,
		{"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": 900 + i, "no_rewards": true}
	)
	check(a.doubles, "2x2 ligado (%d)" % i)
	_run(a, 3.0)
	check(
		is_instance_valid(a.ally) and is_instance_valid(a.enemy2),
		"dois de cada lado em campo (%d)" % i
	)
	var tele0 := 0
	var t := 3.0
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
		tele0 = maxi(tele0, a.telegraphs.size())
	var got: Dictionary = a.get_meta("got")
	var outcome := String(got.get("outcome", "none"))
	var n := a_team.size() + b_team.size()
	print(
		(
			"  2x2 %s vs %s -> %s em %.1f s (%.1f s por Pokémon), %d acertos"
			% [TEAMS[i][0], TEAMS[i][1], outcome, t, t / n, a.hits]
		)
	)
	check(outcome in ["win", "lose"], "2x2 termina (%d: %s)" % [i, outcome])
	var down := 0
	for m in a_team if outcome == "lose" else b_team:
		if m.is_fainted():
			down += 1
	check(
		down == (a_team.size() if outcome == "lose" else b_team.size()), "todos do perdedor caíram"
	)
	a.free()


func _gym_doubles() -> void:
	var a := _arena(
		[Mon.create("squirtle", 14), Mon.create("bulbasaur", 14)],
		[Mon.create("geodude", 12), Mon.create("onix", 14)],
		{"kind": "trainer", "trainer_id": "brock", "autoplay": true, "seed": 3, "no_rewards": true}
	)
	check(a.doubles, "ginásio do Brock é 2x2")
	a.free()
	var b := _arena(
		[Mon.create("squirtle", 14)],
		[Mon.create("geodude", 12), Mon.create("onix", 14)],
		{"kind": "trainer", "trainer_id": "brock", "autoplay": true, "seed": 3}
	)
	check(not b.doubles, "com um só Pokémon o ginásio vira 1x1")
	b.free()


func _commands() -> void:
	check(
		load(ARENA).instantiate().get_script().ignore_chance(0) > 0.2, "amizade baixa ignora mais"
	)
	var a := _arena(
		[Mon.create("charmander", 12), Mon.create("squirtle", 12)],
		[Mon.create("rattata", 12)],
		{"seed": 21, "auto_battle": true}
	)
	_run(a, 1.3)
	check(a.order("player", 0) == 0 and a.player.ai.ally_mode() == 0, "G: comando do controlado")
	check(a.order("ally", 2) == 2 and a.ally.ai.ally_mode() == 2, "F: comando do aliado")
	a.free()


func _telegraph_dodge() -> void:
	# Área avisada no chão: um Escaramuçador rápido sai antes de ela cair na maioria das vezes.
	var out := 0
	for k in 10:
		var a := _arena([Mon.create("pikachu", 20)], [Mon.create("geodude", 20)], {"seed": 50 + k})
		_run(a, 1.3)
		a.enemy.controller = "none"
		var p: BattleFighter = a.player
		p.moves = []
		var at := p.pos2(p.position)
		a.telegraph({"kind": "disc", "side": 1, "t": 0.9, "at": at, "r": 1.5})
		_run(a, 0.9)
		if p.pos2(p.position).distance_to(at) > 1.5:
			out += 1
		a.free()
	check(out >= 5, "desvia de área avisada (%d de 10)" % out)


func _clash() -> void:
	var a := _arena([Mon.create("rattata", 15)], [Mon.create("rattata", 15)], {"seed": 8})
	_run(a, 1.3)
	a.player.controller = "none"
	a.enemy.controller = "none"
	a.player.position = Vector3(0, 0, 1.0)
	a.enemy.position = Vector3(0, 0, -1.0)
	var hp0: int = a.enemy.hp
	var mv := Dex.move("tackle")
	a.player.start_dash(mv, Vector3(0, 0, -1), null)
	a.enemy.start_dash(mv, Vector3(0, 0, 1), null)
	_run(a, 0.3)
	check(a.enemy.hp == hp0 and a.player.hp == a.player.max_hp, "CLASH: ninguém toma dano")
	check(a.player.dash_t <= 0.0 and a.enemy.dash_t <= 0.0, "CLASH: as investidas param")
	a.free()


func _flyer() -> void:
	var a := _arena([Mon.create("geodude", 15)], [Mon.create("pidgey", 15)], {"seed": 4})
	_run(a, 1.3)
	check(a.enemy.profile == "flyer", "Pidgey voa")
	var top := 0.0
	var low := 9.0
	for i in 240:
		a.step(DT)
		top = maxf(top, a.enemy.fly_h)
		low = minf(low, a.enemy.fly_h)
	check(top > 0.9, "voador sobe (%.2f)" % top)
	check(low < 0.4, "voador desce para atacar (%.2f)" % low)
	a.free()
