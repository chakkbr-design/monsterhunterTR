extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_switch.gd
## Troca no VGC com rodadas: só no começo da rodada, uma por lado, quem entra não ataca na rodada e
## herda os golpes mirados em quem saiu; substituto de quem desmaiou no fim da rodada; interface para a
## IA de treinador (trainer_ai[side].round_start / pick_replacement, request_switch, request_trainer_item,
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
	_switch_at_round_start()
	_one_per_side()
	_retarget()
	_trainer_hooks()
	_replacement_at_round_end()
	_trainer_item()
	_stands_and_ball()
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


func _switch_at_round_start() -> void:
	var a := _doubles()
	var out: BattleFighter = a.player
	var bench: Array = a.bench_of(0)
	check(bench.size() == 2, "banco do jogador com 2 (%d)" % bench.size())
	var m: Mon = bench[0]
	var r: int = a.turns.round_n
	check(a.request_switch(0, out, 0), "pede a troca")
	_run(a, 0.3)
	check(a.turns.round_n == r and out.active(), "não troca no meio da rodada")
	_next_round(a)
	check(not out.on_field, "saiu no começo da rodada")
	check(a.player.mon == m, "entrou o do banco")
	check(a.turns.sits_out(a.player), "quem entrou fica fora da fila nesta rodada")
	check(not a.turns.queue.has(a.player), "quem entrou não está na fila")
	var fired := [false]
	var nf: BattleFighter = a.player
	a.move_used.connect(
		func(u: BattleFighter, _mv: Dictionary) -> void:
			if u == nf and a.turns.round_n == r + 1:
				fired[0] = true
	)
	var r2: int = a.turns.round_n
	while a.turns.round_n == r2:
		a.step(DT)
	check(not fired[0], "quem entrou não ataca na rodada da troca")
	check(not a.turns.sits_out(nf), "na rodada seguinte já entra na fila")
	a.free()


func _one_per_side() -> void:
	var a := _doubles(6)
	check(a.request_switch(0, a.player, 0), "1ª troca do lado")
	check(not a.request_switch(0, a.ally, 1), "2ª troca do mesmo lado na mesma rodada não")
	check(a.request_switch(1, a.enemy, 0), "o outro lado também troca")
	check(not a.request_switch(0, a.enemy, 0), "não troca o Pokémon do outro lado")
	check(not a.request_switch(1, a.enemy2, 9), "índice fora do banco não")
	_next_round(a)
	check(a.request_switch(0, a.ally, 0), "na rodada seguinte pode de novo")
	a.free()


func _retarget() -> void:
	var a := _doubles(7)
	var out: BattleFighter = a.enemy
	for f in [a.player, a.ally]:
		f.opponent = out
		f.ai.retarget_t = 99.0
	a.request_switch(1, out, 0)
	_next_round(a)
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


func _replacement_at_round_end() -> void:
	var a := _doubles(9)
	var t1 := FakeTrainer.new()
	t1.pick = 1  # o 2º do banco, não o próximo da lista
	a.trainer_ai = {1: t1}
	var want: Mon = a.bench_of(1)[1]
	var down: BattleFighter = a.enemy
	var r: int = a.turns.round_n
	down.take_damage(down.hp, Vector3.ZERO, 0.0)
	_run(a, 1.0)
	var mid_round: bool = a.turns.round_n == r
	var field: Array = a.fighters.filter(func(f): return f.side == 1 and f.active())
	check(mid_round and field.size() == 1, "no meio da rodada ninguém entra no lugar")
	_next_round(a)
	_run(a, 2.0)
	check(t1.asked.size() == 1, "pick_replacement perguntado no fim da rodada")
	field = a.fighters.filter(func(f): return f.side == 1 and f.active())
	check(field.size() == 2, "o substituto entrou")
	check(field.any(func(f): return f.mon == want), "entrou o escolhido pela IA do treinador")
	a.free()


func _trainer_item() -> void:
	var a := _doubles(10)
	var f: BattleFighter = a.enemy
	for g in [a.player, a.ally, a.enemy2, f]:
		g.controller = "none"  # ninguém bate no alvo do item enquanto a rodada não vira
	_run(a, 2.0)  # golpes que já estavam no ar caem antes
	f.hp = int(f.max_hp * 0.3)
	var hp0: int = f.hp
	check(a.request_trainer_item(1, "super_potion", f), "pede a Super Poção")
	check(not a.request_trainer_item(1, "potion", f), "um item por alvo na rodada")
	check(f.hp == hp0, "o item espera o começo da rodada")
	_next_round(a)
	check(f.hp > hp0 and f.item_used, "item usado no começo da rodada")
	check(a.turns.sits_out(f), "quem recebeu o item não ataca na rodada")
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
	a.request_switch(0, a.player, 0)
	_next_round(a)
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
