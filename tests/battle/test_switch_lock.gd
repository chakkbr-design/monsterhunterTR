extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_switch_lock.gd
## Modo de energia (Caio, 2026-10-27): troca voluntária só depois de SWITCH_OPEN s de luta e cada troca
## trava as dos dois lados por SWITCH_LOCK s. O VGC não muda.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_energy()
	_vgc()
	print("switch_lock: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(mode: String) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		[Mon.create("squirtle", 50), Mon.create("pikachu", 50)],
		[Mon.create("bulbasaur", 50), Mon.create("charmander", 50)],
		{
			"kind": "trainer",
			"autoplay": true,
			"seed": 3,
			"speed": 1.0,
			"battle_mode": mode,
			"no_rewards": true,
			"fast_sim": true,
			"arena": Cfg.ARENA
		}
	)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(secs / DT):
		if a.state != "fight":
			return
		a.step(DT)


func _energy() -> void:
	var a := _arena("energy")
	_run(a, 1.0)
	check(a.switch_locked(), "energia: troca fechada no começo (%.1f s)" % a.fight_clock)
	check(a.switch_out(a.enemy) == null, "U-turn no começo não troca")
	_run(a, a.SWITCH_OPEN + 0.5 - a.fight_clock)
	if a.state != "fight":
		check(false, "a luta acabou antes de testar")
		a.free()
		return
	check(not a.switch_locked(), "troca abre depois de %.0f s" % a.SWITCH_OPEN)
	var nf = a.switch_out(a.enemy)
	check(nf != null, "troca do lado B sai")
	check(a.switch_locked(), "a troca trava os dois lados")
	check(a.switch_out(a.player) == null, "o lado A espera a trava")
	_run(a, a.SWITCH_LOCK + 0.5)
	if a.state == "fight":
		check(not a.switch_locked(), "a trava some em %.0f s" % a.SWITCH_LOCK)
	a.free()


func _vgc() -> void:
	var a := _arena("vgc")
	_run(a, 0.5)
	check(not a.switch_locked(), "VGC sem trava de troca")
	a.free()
