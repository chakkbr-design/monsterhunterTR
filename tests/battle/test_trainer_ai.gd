extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_trainer_ai.gd
## IA do treinador (docs/IA_TREINADOR.md, BattleTrainerAI): troca, item e substituto.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_switch()
	_item()
	_replacement()
	_switch_in_battle()
	print("trainer_ai: %d checks, %d falhas" % [_count, _fails])
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


func _mons(list: Array, lv := 40) -> Array:
	return list.map(func(s): return Mon.create(String(s), lv))


## Dupla de treinador parada (ninguém anda nem bate sozinho): os testes chamam a IA na mão.
func _still2(mine: Array, theirs: Array, seed_n := 3, extra := {}) -> Node:
	var o := {
		"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": seed_n, "no_rewards": true
	}
	o.merge(extra, true)
	var tai: bool = bool(o.get("trainer_ai", true))
	o["trainer_ai"] = false  # ninguém troca sozinho enquanto o teste monta a cena
	var a := _arena(_mons(mine), _mons(theirs), o)
	for i in int(3.0 / DT):
		a.step(DT)
		for f in a.fighters:
			f.controller = "none"  # ninguém luta enquanto a cena entra (sem acaso de quem bateu)
	if tai:
		a.trainer_ai = {0: BattleTrainerAI.new(a, 0), 1: BattleTrainerAI.new(a, 1)}
	for f in a.fighters:
		f.controller = "none"
		f.hp = f.max_hp
		f.clear_status()
	return a


func _side(a: Node, side: int) -> Array:
	return a.fighters.filter(func(f): return f.side == side and f.active())


func _named(a: Node, sp: String) -> BattleFighter:
	for f in a.fighters:
		if f.active() and f.mon.species == Dex.canon(sp):
			return f
	return null


func _switch() -> void:
	# Charmander contra dois de Água, com Bulbasaur no banco: troca.
	var a := _still2(["charmander", "pidgey", "bulbasaur"], ["squirtle", "psyduck"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	for f in _side(a, 1):
		f.moves = ["water_pulse"]
	var me := _named(a, "charmander")
	me.moves = ["scratch"]
	var c := tr.switch_for(me, _side(a, 1))
	check(not c.is_empty(), "matchup ruim: quer trocar")
	if not c.is_empty():
		check(a.bench_of(0)[int(c.idx)].species == "Bulbasaur", "entra quem resiste (Bulbasaur)")
	me.hp = int(me.max_hp * 0.3)
	check(tr.switch_for(me, _side(a, 1)).is_empty(), "com HP baixo fica e bate")
	me.hp = me.max_hp
	tr._swapped[me.mon] = a.turns.round_n
	check(tr.switch_for(me, _side(a, 1)).is_empty(), "sem ping-pong logo depois de trocar")
	a.free()


func _item() -> void:
	var a := _still2(["charmander", "pidgey"], ["rattata", "spearow"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	var me := _named(a, "charmander")
	me.trainer_item = "super_potion"
	me.item_used = false
	for f in _side(a, 1):
		f.moves = ["tackle"]
	me.hp = int(me.max_hp * 0.3)
	check(tr.item_for(me) == "super_potion", "cura com HP baixo quando sobrevive")
	for f in _side(a, 1):
		f.moves = ["hyper_fang", "tackle"]
		f.stages["atk"] = 6
	me.hp = 2
	check(tr.item_for(me) == "", "não cura quem cai na rodada mesmo curado")
	me.hp = me.max_hp
	check(tr.item_for(me) == "", "HP cheio sem item")
	me.trainer_item = "paralyze_heal"
	me.status = "paralysis"
	if not Dex.item("paralyze_heal").is_empty():
		check(tr.item_for(me) == "paralyze_heal", "cura paralisia")
	a.free()


func _replacement() -> void:
	var a := _still2(["charmander", "pidgey", "rattata", "bulbasaur"], ["squirtle", "psyduck"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	for f in _side(a, 1):
		f.moves = ["water_gun"]
	var k := tr.pick_replacement(0)
	var bench: Array = a.bench_of(0)
	check(
		k >= 0 and bench[k].species == "Bulbasaur",
		"substituto: o que resiste e bate (%s)" % (bench[k].species if k >= 0 else "-")
	)
	a.free()


## Luta de verdade: o treinador troca o Charmander que só apanharia (depois da trava do começo).
func _switch_in_battle() -> void:
	var a := _arena(
		_mons(["squirtle", "psyduck"]),
		_mons(["charmander", "spearow", "bulbasaur"]),
		{"kind": "trainer", "battle_size": 2, "seed": 4, "no_rewards": true, "autoplay": true}
	)
	_run(a, 3.0)
	for f in _side(a, 0):
		f.moves = ["water_pulse"]
		f.controller = "none"  # só ameaçam: o Charmander não cai antes de o treinador decidir
	var ch := _named(a, "charmander")
	if ch != null:
		ch.moves = ["scratch"]
	for f in _side(a, 1):
		f.controller = "none"  # a decisão é do treinador; ninguém cai enquanto isso
	var tr: BattleTrainerAI = a.trainer_ai[1]
	check(
		ch != null and not tr.switch_for(ch, _side(a, 0)).is_empty(), "Charmander em matchup ruim"
	)
	var t := 0.0
	while float(a.fight_clock) < float(a.SWITCH_OPEN) + 0.1 and t < 20.0:
		a.step(DT)
		t += DT
	for k in 20:  # a decisão tem chance (nível da IA); tenta até pedir
		if tr.switches > 0:
			break
		tr.round_start()
	check(tr.switches >= 1, "pediu a troca na arena")
	_run(a, 2.0)
	check(ch != null and not ch.on_field, "o Charmander saiu")
	check(_side(a, 1).any(func(f): return f.mon.species == "Bulbasaur"), "entrou o Bulbasaur")
	a.free()
