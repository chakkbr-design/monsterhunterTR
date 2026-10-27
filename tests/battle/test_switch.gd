extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_switch.gd
## Troca: sai na hora (fora da trava de troca) e quem entra herda os golpes mirados em quem saiu;
## substituto de quem desmaiou escolhido pela IA do treinador; interface para a IA de treinador (trainer_ai[side].round_start / pick_replacement, request_switch, request_trainer_item,
## bench_of).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0


class FakeTrainer:
	extends RefCounted
	var starts := 0
	var asked: Array = []
	var pick := -1

	func round_start() -> void:
		starts += 1

	func pick_replacement(slot: int) -> int:
		asked.append(slot)
		return pick


var _fails := 0
var _count := 0


func _initialize() -> void:
	# Mon.create sorteia IVs/natureza/habilidade no RNG global, que o Godot randomiza a cada
	# execução: sem semente fixa as lutas de 3 s de autoplay mudam de uma execução para outra (quem
	# desmaia antes da troca, quem a IA tira de campo) e as checagens viram sorteio.
	seed(5)
	_switch_now()
	_one_per_side()
	_retarget()
	_trainer_hooks()
	_replacement()
	_trainer_item()
	_stands_and_ball()
	_status_on_switch()
	_paralysis_secs()
	print("switch: %d checks, %d falhas" % [_count, _fails])
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
	if not opts.has("speed"):
		opts["speed"] = 1.0
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _next_round(a: Node) -> void:
	var r: int = a.turns.round_n
	var t := 0.0
	while a.turns.round_n == r and t < 15.0:
		a.step(DT)
		t += DT


func _doubles(seed_n := 5) -> Node:
	var a := _arena(
		[
			Mon.create("pikachu", 20),
			Mon.create("geodude", 20),
			Mon.create("squirtle", 20),
			Mon.create("bulbasaur", 20)
		],
		[
			Mon.create("rattata", 20),
			Mon.create("onix", 20),
			Mon.create("pidgey", 20),
			Mon.create("spearow", 20)
		],
		{"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": seed_n, "no_rewards": true}
	)
	_run(a, 3.0)
	return a


## Fora da trava de troca (BattleArena.switch_locked).
func _open(a: Node) -> void:
	a.fight_clock = maxf(float(a.fight_clock), float(a.SWITCH_OPEN))
	a.switch_lock = 0.0


func _switch_now() -> void:
	var a := _doubles()
	var out: BattleFighter = a.player
	var bench: Array = a.bench_of(0)
	check(bench.size() == 2, "banco do jogador com 2 (%d)" % bench.size())
	var m: Mon = bench[0]
	check(not a.request_switch(0, out, 0), "no começo da luta a troca está travada")
	_open(a)
	check(a.request_switch(0, out, 0), "pede a troca")
	check(not out.on_field, "saiu na hora")
	check(a.player.mon == m, "entrou o do banco")
	a.free()


func _one_per_side() -> void:
	var a := _doubles(6)
	_open(a)
	check(not a.request_switch(0, a.enemy, 0), "não troca o Pokémon do outro lado")
	check(not a.request_switch(1, a.enemy2, 9), "índice fora do banco não")
	check(a.request_switch(0, a.player, 0), "1ª troca do lado")
	check(not a.request_switch(0, a.ally, 1), "logo depois de uma troca, trava")
	_open(a)
	check(a.request_switch(0, a.ally, 0), "passada a trava pode de novo")
	a.free()


func _retarget() -> void:
	var a := _doubles(7)
	_open(a)
	var out: BattleFighter = a.enemy
	for f in [a.player, a.ally]:
		f.opponent = out
		f.ai.retarget_t = 99.0
	a.request_switch(1, out, 0)
	var nf: BattleFighter = a.enemy
	check(nf != out and nf.active(), "o adversário trocou")
	check(
		a.player.opponent == nf and a.ally.opponent == nf,
		"os golpes mirados em quem saiu vão para quem entrou"
	)
	a.free()


func _trainer_hooks() -> void:
	var a := _doubles(8)
	var t0 := FakeTrainer.new()
	var t1 := FakeTrainer.new()
	a.trainer_ai = {0: t0, 1: t1}
	_next_round(a)
	_next_round(a)
	check(t0.starts >= 2 and t1.starts >= 2, "round_start a cada rodada nos dois lados")
	a.free()


func _replacement() -> void:
	var a := _doubles(9)
	var t1 := FakeTrainer.new()
	t1.pick = 1  # o 2º do banco, não o próximo da lista
	a.trainer_ai = {1: t1}
	for g in a.fighters:
		g.controller = "none"
	var want: Mon = a.bench_of(1)[1]
	var down: BattleFighter = a.enemy
	down.take_damage(down.hp, Vector3.ZERO, 0.0)
	_run(a, a.RECALL_SECS + a.NEXT_TRAINER_MON + 3.0)
	check(t1.asked.size() == 1, "pick_replacement perguntado uma vez (%d)" % t1.asked.size())
	var field: Array = a.fighters.filter(func(f): return f.side == 1 and f.active())
	check(field.size() == 2, "o substituto entrou")
	check(field.any(func(f): return f.mon == want), "entrou o escolhido pela IA do treinador")
	a.free()


func _trainer_item() -> void:
	var a := _doubles(10)
	var f: BattleFighter = a.enemy
	for g in [a.player, a.ally, a.enemy2, f]:
		g.controller = "none"
	_run(a, 2.0)  # golpes que já estavam no ar caem antes
	f.hp = int(f.max_hp * 0.3)
	var hp0: int = f.hp
	check(a.request_trainer_item(1, "super_potion", f), "pede a Super Poção")
	check(f.hp > hp0 and f.item_used, "item usado na hora")
	check(not a.request_trainer_item(1, "potion", f), "item do treinador uma vez por Mon")
	a.free()


## Um treinador atrás de cada lado (no selvagem só o do jogador) e a troca pela bola: o que entra só
## aparece quando a bola abre.
func _stands_and_ball() -> void:
	var a := _doubles(11)
	check(a._stands.has(0) and a._stands.has(1), "treinador dos dois lados na luta de treinador")
	var t0: Vector3 = a.trainer_spot(0)
	var t1: Vector3 = a.trainer_spot(1)
	check((t1 - t0).dot(a.axis) > 0.0, "cada treinador do seu lado")
	_open(a)
	a.request_switch(0, a.player, 0)
	var nf: BattleFighter = a.player
	check(not nf.visible and a._balls.size() == 1, "a bola sai da mão do treinador")
	_run(a, a.SEND_FLIGHT + 0.05)
	check(nf.visible, "o Pokémon aparece quando a bola abre")
	_run(a, a.SEND_OPEN + 0.1)
	check(a._balls.is_empty(), "a bola some depois de abrir")
	a.free()
	var w := _arena([Mon.create("charmander", 10)], [Mon.create("pidgey", 5)], {"seed": 3})
	_run(w, 1.0)
	check(w._stands.has(0) and not w._stands.has(1), "selvagem: só o treinador do jogador")
	w.free()


## Troca como no oficial: estágios, confusão e Leech Seed zeram; status principal fica (Toxic com o
## contador zerado, sono com os turnos que faltam, congelado); a paralisia segue com o tempo que falta.
func _status_on_switch() -> void:
	var a := _doubles(8)
	var cases := [["toxic", "toxic"], ["sleep", "sleep"], ["freeze", "freeze"], ["burn", "burn"]]
	for c in cases:
		var out: BattleFighter = a.player
		var m: Mon = out.mon
		out.clear_status()
		out.stages["atk"] = 2
		out.stages["spe"] = -1
		out.apply_status("confusion")
		out.apply_status("leech", a.enemy)
		check(out.apply_status(String(c[0])), "%s pegou" % c[0])
		out.toxic_n = 4
		if c[0] == "sleep":
			out.sleep_turns = 1
		var back: BattleFighter = null
		for k in 6:
			_open(a)
			var nf: BattleFighter = a.switch_out(a.player)
			if nf == null:
				break
			if nf.mon == m:
				back = nf
				break
		check(back != null, "%s: voltou para campo" % c[0])
		if back == null:
			continue
		check(back.status == String(c[1]), "%s: status ficou (%s)" % [c[0], back.status])
		check(back.stages["atk"] == 0 and back.stages["spe"] == 0, "%s: estágios zeraram" % c[0])
		check(
			back.confusion_t <= 0.0 and not back.seeded, "%s: confusão e Leech Seed saíram" % c[0]
		)
		check(back.toxic_n == 0, "%s: contador do Toxic zerou" % c[0])
		if c[0] == "sleep":
			check(
				back.sleep_turns == 1, "sono guardou os turnos que faltavam (%d)" % back.sleep_turns
			)
	a.player.clear_status()
	a.free()


func _paralysis_secs() -> void:
	var a := _doubles(9)
	var f: BattleFighter = a.player
	f.immortal = true
	f.clear_status()
	check(f.apply_status("paralysis"), "paralisou")
	_run(a, 6.0)
	check(f.status == "paralysis", "ainda paralisado em 6 s")
	# A luta só conta o tempo de campo (a entrada e as pausas de impacto não contam).
	var left := f.par_t
	check(left > 3.0 and left < 9.0, "contou o tempo de campo (%.2f)" % left)
	_open(a)
	var nf: BattleFighter = a.switch_out(f)
	check(is_equal_approx(f.mon.par_left, left), "guardou o que falta (%.2f)" % f.mon.par_left)
	var m: Mon = f.mon
	for k in 6:
		if nf == null or nf.mon == m:
			break
		_open(a)
		nf = a.switch_out(nf)
	check(nf != null and nf.mon == m and nf.status == "paralysis", "voltou paralisado")
	if nf:
		nf.immortal = true
		check(is_equal_approx(nf.par_t, left), "voltou com o tempo que faltava (%.2f)" % nf.par_t)
		_run(a, left - 1.0)
		check(nf.status == "paralysis", "ainda paralisado com o tempo que faltava")
		var t := 0.0
		while nf.status == "paralysis" and t < 10.0:
			a.step(DT)
			t += DT
		check(nf.status != "paralysis", "paralisia acabou nos 10 s de campo somados")
	var g: BattleFighter = a.ally
	g.immortal = true
	g.clear_status()
	g.apply_status("paralysis")
	var tg := 0.0
	while g.status == "paralysis" and tg < BattleFighter.PARALYSIS_SECS * 2.0:
		a.step(DT)
		tg += DT
	check(g.status != "paralysis", "aliado também sai da paralisia em 10 s de campo (%.1f)" % tg)
	a.free()
