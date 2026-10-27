extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_regroup.gd
## Reagrupar depois do nocaute (BattleRegroup, arena.energy_pause "regroup"):
## quando alguém desmaia ninguém usa golpe nem toma dano até todo lugar que pode ser preenchido
## estar em campo e todos estarem perto do ponto de entrada; a luta ainda acaba. No 1x1 e no 2x2,
## com e sem fast_sim (a bateria).

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_fight(0, false, true)
	_fight(1, true, true)
	_fight(2, false, false)
	_fight(3, true, false)
	print("regroup: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		_fails += 1


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	opts.merge({"speed": 1.0, "no_rewards": true}, false)
	a.start(party, enemies, opts)
	return a


func _fight(i: int, doubles: bool, fast: bool) -> void:
	var party := [Mon.create("pikachu", 30), Mon.create("geodude", 30), Mon.create("oddish", 30)]
	var foes := [
		Mon.create("charmander", 30), Mon.create("squirtle", 30), Mon.create("rattata", 30)
	]
	var a := _arena(
		party,
		foes,
		{
			"kind": "trainer",
			"battle_size": 2 if doubles else 1,
			"autoplay": true,
			"seed": 70 + i,
			"arena": Cfg.SMALL_ARENA,
			"fast_sim": fast
		}
	)
	var tag := "%s%s seed %d" % ["2x2" if doubles else "1x1", " fast_sim" if fast else "", i]
	var moves_in_pause := [0]
	a.move_used.connect(
		func(_u, _mv) -> void:
			if a.energy_pause != "":
				moves_in_pause[0] += 1
	)
	var t := 0.0
	var regroups := 0
	var resumes := 0
	var good := 0
	var hurt := 0
	var was := ""
	var hp := {}
	var longest := 0.0
	var span := 0.0
	while t < 300.0 and a.state in ["intro", "fight"]:
		a.step(DT)
		t += DT
		var now: String = a.energy_pause
		if now == "regroup" and was != "regroup":
			regroups += 1
			span = 0.0
			hp = _hps(a)
		elif now == "regroup":
			span += DT
			longest = maxf(longest, span)
			var cur := _hps(a)
			for k in cur:
				if hp.has(k) and int(cur[k]) < int(hp[k]):
					hurt += 1
			hp = cur
		elif was == "regroup" and a.state == "fight":
			resumes += 1
			if a.regroup.filled() and a.regroup.home():
				good += 1
			else:
				print("  %s: voltou sem todos (t %.1f s no reagrupar)" % [tag, a.regroup.t])
		was = now
	print("  %s: %.0f s, %d reagrupes, mais longo %.1f s" % [tag, t, regroups, longest])
	check(a.state not in ["intro", "fight"], "%s: a luta acaba (%.0f s)" % [tag, t])
	check(regroups >= 1, "%s: reagrupou depois do nocaute (%d)" % [tag, regroups])
	check(
		moves_in_pause[0] == 0, "%s: ninguém usa golpe no reagrupar (%d)" % [tag, moves_in_pause[0]]
	)
	check(hurt == 0, "%s: ninguém toma dano no reagrupar (%d)" % [tag, hurt])
	check(
		resumes == 0 or good >= resumes - 1,
		"%s: volta com todos em campo e no ponto de entrada (%d de %d)" % [tag, good, resumes]
	)
	check(
		longest <= BattleRegroup.MAX_SECS + 0.1,
		"%s: o reagrupar nunca passa do teto (%.1f s)" % [tag, longest]
	)
	a.queue_free()


func _hps(a: Node) -> Dictionary:
	var out := {}
	for f in a.fighters:
		if is_instance_valid(f) and f.on_field:
			out[f.get_instance_id()] = f.hp
	return out


