extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_turns.gd
## Rodadas pela Speed (BattleTurns): ordem pela Speed, prioridade, Trick Room, empate no sorteio,
## um golpe por rodada, folga mínima entre golpes, marcador de vez, 1x1 e 2x2, turn_mode false.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_order()
	_priority()
	_trick_room()
	_ties()
	_paralysis()
	for i in 3:
		_one_per_round(i, true)
	_one_per_round(0, false)
	_marker()
	_old_mode()
	print("turns: %d checks, %d falhas" % [_count, _fails])
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


## 2x2 de treinador parado logo depois da abertura (a IA não anda), com a Speed de cada um à mão.
func _doubles(seed_n := 5) -> Node:
	var a := _arena(
		[Mon.create("pikachu", 20), Mon.create("geodude", 20)],
		[Mon.create("rattata", 20), Mon.create("onix", 20)],
		{"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": seed_n, "no_rewards": true}
	)
	_run(a, 3.0)
	return a


func _four(a: Node) -> Array:
	return [a.player, a.ally, a.enemy, a.enemy2]


func _set_spe(f: BattleFighter, v: float) -> void:
	f.stats["spe"] = v
	f.ai.intent = ""


func _ids(list: Array) -> Array:
	return list.map(func(f): return f.mon.species)


func _order() -> void:
	var a := _doubles()
	var fs := _four(a)
	check(fs.all(func(f): return is_instance_valid(f)), "2x2 com quatro em campo")
	var spe := [50.0, 120.0, 80.0, 30.0]
	for i in 4:
		_set_spe(fs[i], spe[i])
	var got: Array = a.turns.build_order(fs)
	check(got == [fs[1], fs[2], fs[0], fs[3]], "ordem pela Speed: %s" % [_ids(got)])
	# Estágio de Speed conta (+2 = 2x).
	fs[3].stages["spe"] = 2
	got = a.turns.build_order(fs)
	check(got[0] == fs[1] and got[2] == fs[3], "estágio +2 sobe na fila: %s" % [_ids(got)])
	fs[3].stages["spe"] = 0
	# Tailwind dobra a Speed do lado.
	a.moves.effects._sd(1)["tailwind"] = a.moves.effects.now + 10.0
	got = a.turns.build_order(fs)
	check(got[0] == fs[2], "Tailwind põe o lado na frente: %s" % [_ids(got)])
	a.free()


func _priority() -> void:
	var a := _doubles()
	var fs := _four(a)
	var spe := [50.0, 120.0, 80.0, 30.0]
	for i in 4:
		_set_spe(fs[i], spe[i])
	fs[3].ai.intent = "quick_attack"  # +1: o mais lento sai primeiro
	fs[1].ai.intent = "whirlwind"  # -6: o mais rápido sai por último
	var got: Array = a.turns.build_order(fs)
	check(got[0] == fs[3], "prioridade +1 passa na frente: %s" % [_ids(got)])
	check(got[3] == fs[1], "prioridade -6 vai para o fim: %s" % [_ids(got)])
	check(got[1] == fs[2] and got[2] == fs[0], "faixa 0 pela Speed: %s" % [_ids(got)])
	check(BattleTurns.priority_of(fs[0], "protect") == 4, "Protect +4 dos dados")
	a.free()


func _trick_room() -> void:
	var a := _doubles()
	var fs := _four(a)
	var spe := [50.0, 120.0, 80.0, 30.0]
	for i in 4:
		_set_spe(fs[i], spe[i])
	fs[1].ai.intent = "quick_attack"
	check(a.turns.toggle_trick_room(), "Trick Room liga")
	var got: Array = a.turns.build_order(fs)
	check(got[0] == fs[1], "Trick Room não mexe na prioridade: %s" % [_ids(got)])
	check(
		got.slice(1) == [fs[3], fs[0], fs[2]],
		"Trick Room inverte dentro da faixa: %s" % [_ids(got)]
	)
	check(not a.turns.toggle_trick_room(), "Trick Room de novo desliga")
	a.turns.toggle_trick_room(1)
	a.end_turn.run()
	check(not a.turns.trick_room(), "Trick Room acaba sozinho no fim da rodada")
	a.free()


func _ties() -> void:
	var a := _doubles()
	var fs := _four(a)
	for f in fs:
		_set_spe(f, 70.0)
	var first := {}
	for k in 60:
		a.turns._ties.clear()
		var got: Array = a.turns.build_order(fs)
		first[got[0].get_instance_id()] = true
	check(first.size() >= 3, "empate de Speed no sorteio (%d primeiros diferentes)" % first.size())
	a.free()


func _paralysis() -> void:
	var a := _doubles()
	var fs := _four(a)
	_set_spe(fs[0], 100.0)
	_set_spe(fs[1], 60.0)
	check(a.turns.build_order([fs[0], fs[1]])[0] == fs[0], "mais rápido primeiro")
	fs[0].status = "paralysis"
	check(a.turns.build_order([fs[0], fs[1]])[0] == fs[1], "paralisia corta a Speed pela metade")
	fs[0].status = ""
	a.free()


## Luta real (IA nos dois lados): cada lutador solta no máximo um golpe por rodada, só na vez dele, com
## MOVE_GAP s entre um golpe e o seguinte; rodadas de pelo menos ROUND_SECS s.
func _one_per_round(i: int, doubles: bool) -> void:
	var teams := [
		[["pikachu", "geodude"], ["rattata", "onix"]],
		[["charmander", "pidgey"], ["squirtle", "mankey"]],
		[["bulbasaur", "zubat"], ["psyduck", "sandshrew"]],
	]
	var party: Array = teams[i][0].map(func(s): return Mon.create(s, 18))
	var foes: Array = teams[i][1].map(func(s): return Mon.create(s, 18))
	var opts := {"kind": "trainer", "autoplay": true, "seed": 400 + i, "no_rewards": true}
	opts["battle_size"] = 2 if doubles else 1
	var a := _arena(party, foes, opts)
	var tag := "%s %d" % ["2x2" if doubles else "1x1", i]
	var off_turn := [0]
	var used := [0]
	a.move_used.connect(
		func(u: BattleFighter, _mv: Dictionary) -> void:
			used[0] += 1
			var h: Array = a.turns.history
			var last_me: bool = (
				not h.is_empty() and h[-1].who == u and a.turns.clock - float(h[-1].t) < 2.5
			)
			if a.turns.tracked(u) and a.turns.current != u and not last_me:
				off_turn[0] += 1
	)
	var t := 0.0
	while a.state != "done" and t < 240.0:
		a.step(DT)
		t += DT
	var hist: Array = a.turns.history.filter(func(e): return e.what in ["move", "struggle", "item"])
	print(
		(
			"  %s: %.1f s, %d rodadas, %d golpes na fila, %d golpes no total"
			% [tag, t, a.turns.round_n, hist.size(), used[0]]
		)
	)
	check(hist.size() >= 4, "golpes pela fila (%s: %d)" % [tag, hist.size()])
	check(off_turn[0] == 0, "nenhum golpe fora da vez (%s: %d)" % [tag, off_turn[0]])
	var per := {}
	var min_gap := INF
	for k in hist.size():
		var e: Dictionary = hist[k]
		var key := "%d:%d" % [int(e.round), e.who.get_instance_id()]
		per[key] = int(per.get(key, 0)) + 1
		if k > 0:
			min_gap = minf(min_gap, float(e.t) - float(hist[k - 1].t))
	check(per.values().all(func(n): return n == 1), "um golpe por rodada por lutador (%s)" % tag)
	check(
		min_gap >= BattleTurns.MOVE_GAP - 0.02,
		"folga mínima entre golpes (%s: %.2f s)" % [tag, min_gap]
	)
	var rounds: int = a.turns.round_n
	check(
		rounds <= t / BattleTurns.ROUND_SECS + 1.0,
		(
			"rodada dura pelo menos %.1f s (%s: %d em %.1f s)"
			% [BattleTurns.ROUND_SECS, tag, rounds, t]
		)
	)
	var fighters_n := 4 if doubles else 2
	check(
		float(hist.size()) / maxf(rounds, 1) <= fighters_n,
		"no máximo um golpe por lutador por rodada (%s)" % tag
	)
	a.free()


func _marker() -> void:
	var a := _doubles(11)
	var seen := 0
	var ok := true
	for k in 240:
		a.step(DT)
		var who: BattleFighter = a.turns.next_up()
		var mark: Node3D = a.get("_turn_mark")
		if who != null and mark != null and mark.visible:
			seen += 1
			var flat := Vector3(1, 0, 1)
			ok = ok and (mark.position * flat).distance_to(who.position * flat) < 0.01
	check(seen > 30, "marcador de vez aparece (%d quadros)" % seen)
	check(ok, "marcador fica em quem é o próximo da fila")
	a.free()


func _old_mode() -> void:
	var a := _arena(
		[Mon.create("pikachu", 15)],
		[Mon.create("rattata", 15)],
		{"autoplay": true, "seed": 3, "battle_size": 1, "turn_mode": false}
	)
	_run(a, 6.0)
	check(not a.turns.on and a.turns.queue.is_empty(), "turn_mode false: sem fila")
	check(a.turns.can_fire(a.enemy), "turn_mode false: solta quando quiser")
	check(a.turns.round_n >= 1, "turn_mode false: o fim de rodada continua (relógio)")
	a.free()
