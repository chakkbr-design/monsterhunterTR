extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_director.gd
## Câmera de ação do treino (BattleDirector, modo de energia): enquadra os Pokémon mais perto que a
## câmera antiga, câmera lenta 0,5x antes do golpe que nocauteia e no desmaio, todo mundo parado
## na troca (a energia de ninguém muda) e nada disso no VGC nem no fast_sim.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const LIMIT := 60 * 240

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _cfg(mode: String) -> Dictionary:
	Cfg.path = "user://test_director_cfg.json"
	var c := Cfg.default_config()
	var a: Array = []
	var b: Array = []
	for s in ["Charizard", "Blastoise", "Venusaur"]:
		a.append(Cfg.mon_entry(s, 50))
	for s in ["Gengar", "Machamp", "Alakazam"]:
		b.append(Cfg.mon_entry(s, 50))
	c.sides[0].mons = a
	c.sides[1].mons = b
	c.speed = 2.0
	c.seed = 11
	c.battle_size = 2
	c.battle_mode = mode
	return c


func _run() -> void:
	Cfg.current = _cfg("energy")
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	var ar: Node = tb.arena
	check(ar.get("director") != null, "modo de energia no treino: câmera de ação ligada")
	var d: BattleDirector = ar.director
	var old_dist := float(tb.cam_dist())  # câmera fixa da quadra de energia (48 x 28)
	var dists: Array = []
	var shots := {}
	var slow := 0
	var hold_frames := 0
	var hold_moved := 0
	var prev := {}
	for i in LIMIT:
		await physics_frame
		if not is_instance_valid(ar) or tb._result_box.visible:
			break
		if String(ar.state) != "fight":
			continue
		shots[d.shot] = int(shots.get(d.shot, 0)) + 1
		if d.shot == "":
			dists.append(d._dist)
		if ar.cine_scale() < 0.99:
			slow += 1
		var now := {}
		for f in ar.fighters:
			if is_instance_valid(f) and f.active():
				now[f] = [f.pp_max, f.position]
		if d.holding():
			hold_frames += 1
			for f in now:
				if prev.has(f) and (absf(now[f][0] - prev[f][0]) > 0.001):
					hold_moved += 1
		prev = now
	check(tb._result_box.visible, "a luta terminou (%s)" % tb.result.get("outcome"))
	dists.sort()
	var med: float = dists[dists.size() / 2] if not dists.is_empty() else 99.0
	check(
		med < old_dist, "enquadramento mais perto: mediana %.1f m (antes %.1f m)" % [med, old_dist]
	)
	check(int(shots.get("ko", 0)) > 0, "zoom no desmaio (%d quadros)" % int(shots.get("ko", 0)))
	check(
		int(shots.get("finish", 0)) > 0,
		"zoom antes do golpe que nocauteia (%d quadros)" % int(shots.get("finish", 0))
	)
	check(int(shots.get("big", 0)) > 0, "destaque de golpe grande (%d)" % int(shots.get("big", 0)))
	check(slow > 0, "câmera lenta em %d quadros" % slow)
	check(hold_frames > 0, "troca segurou a luta por %d quadros" % hold_frames)
	check(hold_moved == 0, "ninguém gasta nem ganha energia na troca (%d)" % hold_moved)
	print("cenas: ", shots)
	tb.queue_free()
	await process_frame

	Cfg.current = _cfg("vgc")
	tb = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	check(tb.arena.get("director") == null, "VGC: câmera antiga")
	tb.queue_free()
	await process_frame

	var c := _cfg("energy")
	c["extra_opts"] = {"fast_sim": true}
	Cfg.current = c
	tb = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	check(tb.arena.get("director") == null, "fast_sim (bateria): sem câmera de ação")
	tb.queue_free()
	await process_frame

	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
