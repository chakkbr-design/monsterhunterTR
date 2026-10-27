extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_director.gd
## Câmera de ação do treino (BattleDirector): enquadra os Pokémon mais perto que a
## câmera antiga, hit-stop e câmera lenta só no nocaute de verdade (golpe fatal que o alvo desvia não
## dá zoom), todo mundo parado na troca (a energia de ninguém muda) e nada disso no fast_sim.
## The camera never leaves a fighter it frames under the top HUD cards (BattleHUD.top_band): from
## the intro to the knockout, in doubles (campo) and singles (praia), on a 16:9 screen; and no hill,
## tree or boulder stays solid between it and a fighter (they fade, BattleDirector.FADE_ALPHA).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const LIMIT := 60 * 240
## Frames after a change of scene or of who is on the field in which the camera may still be
## catching up (GUARD_EASE): a fighter may cross the HUD band then, never stay under it.
const CATCH_UP := 12

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	# The game's 16:9 canvas (headless reports a square window otherwise).
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1152, 648)
	_run.call_deferred()


func _cfg(size := 2, scenario := "") -> Dictionary:
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
	c.battle_size = size
	c.scenario = scenario
	return c


## Watches one frame of the camera against the HUD band: `st` keeps the counters between frames.
func _watch_band(ar: Node, d: BattleDirector, st: Dictionary) -> void:
	var cam: Camera3D = ar._cam
	if cam == null or not cam.is_inside_tree():
		return
	var band := BattleHUD.top_band(2 if int(ar._battle_size) >= 2 else 1)
	var framed := d.framed()
	var key := "%s|%s" % [d.shot, framed]
	st.since = 0 if key != String(st.get("key", "")) else int(st.get("since", 0)) + 1
	st.key = key
	var under := false
	for f in framed:
		var g: Vector3 = f.global_position
		if cam.is_position_behind(g):
			continue
		var top := cam.unproject_position(g + Vector3(0, f.visual_height(), 0))
		if top.y < band:
			under = true
			st.worst = minf(float(st.get("worst", 1e9)), top.y)
	st.frames = int(st.get("frames", 0)) + 1
	st.run = int(st.get("run", 0)) + 1 if under else 0
	st.longest = maxi(int(st.get("longest", 0)), int(st.run))
	if under and int(st.since) > CATCH_UP:
		st.settled = int(st.get("settled", 0)) + 1
		if int(st.get("settled", 0)) <= 3:
			print("  sob o HUD: %s cena '%s' topo %.0f < %.0f" % [framed, d.shot, st.worst, band])
	if d.shot == "" and String(ar.state) in ["intro", "opening"]:
		st.intro = int(st.get("intro", 0)) + 1
	if d.shot == "ko":
		st.ko = int(st.get("ko", 0)) + 1


## Watches the obstacle fade on one frame: a solid obstacle between the eye and a fighter's middle
## (`st.hidden_run` frames in a row: a hill or peak on its real profile, anything else on its
## mesh boxes) and how many frames had something faded.
func _watch_fade(ar: Node, d: BattleDirector, st: Dictionary) -> void:
	var cam: Camera3D = ar._cam
	if cam == null or not cam.is_inside_tree():
		return
	var eye := cam.get_camera_transform().origin
	var mids: Array = []
	for f in ar.fighters:
		if is_instance_valid(f) and f.on_field and f.visible:
			mids.append(f.global_position + Vector3(0, f.visual_height() * 0.5, 0))
	var hidden := false
	var faded := false
	for e in d._obstacle_nodes():
		var geoms: Array = d._geoms_of(e[0])
		if geoms.any(func(g): return is_instance_valid(g) and g.transparency > 0.3):
			faded = true
			continue
		if not e[1].is_empty():
			hidden = hidden or d._relief_hides(e[1], eye, mids)
			continue
		for gi in geoms:
			if not (is_instance_valid(gi) and gi.is_visible_in_tree()):
				continue
			var box: AABB = gi.get_aabb()
			if box.size.y < BattleDirector.FADE_MIN_H:
				continue
			var inv: Transform3D = gi.global_transform.affine_inverse()
			for m in mids:
				if box.intersects_segment(inv * eye, inv * m) != null:
					hidden = true
	st.hidden_run = int(st.get("hidden_run", 0)) + 1 if hidden else 0
	st.hidden_longest = maxi(int(st.get("hidden_longest", 0)), int(st.hidden_run))
	st.faded = int(st.get("faded", 0)) + (1 if faded else 0)
	st.n_obst = maxi(int(st.get("n_obst", 0)), d.obstacles().size())


func _check_fade(st: Dictionary, what: String) -> void:
	check(
		int(st.get("hidden_longest", 0)) <= CATCH_UP,
		(
			"%s: nenhum obstáculo fica sólido entre a câmera e um lutador (mais longo %d quadros)"
			% [what, int(st.get("hidden_longest", 0))]
		)
	)
	check(
		int(st.get("faded", 0)) > 0,
		(
			"%s: obstáculos no caminho somem (%d quadros com algum apagado, %d malhas)"
			% [what, int(st.get("faded", 0)), int(st.get("n_obst", 0))]
		)
	)


func _check_band(st: Dictionary, what: String) -> void:
	check(
		int(st.get("settled", 0)) == 0,
		(
			"%s: ninguém enquadrado fica sob os cartões do HUD (%d quadros, mais longo %d)"
			% [what, int(st.get("frames", 0)), int(st.get("longest", 0))]
		)
	)
	check(
		int(st.get("longest", 0)) <= CATCH_UP,
		"%s: ao trocar de cena a câmera recua em até %d quadros" % [what, CATCH_UP]
	)
	check(
		int(st.get("intro", 0)) > 0 and int(st.get("ko", 0)) > 0,
		"%s: vigiado da entrada (%d) ao desmaio (%d)" % [what, st.get("intro", 0), st.get("ko", 0)]
	)


## Golpe que seria fatal não dá zoom antes de acertar (o alvo ainda pode desviar); o desmaio dá.
func _ko_zoom() -> void:
	var a: Node = load("res://battle/battle_arena.tscn").instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		[Mon.create("charizard", 50)],
		[Mon.create("bulbasaur", 50), Mon.create("pidgey", 50)],
		{
			"kind": "trainer",
			"battle_size": 1,
			"speed": 1.0,
			"action_cam": true,
			"autoplay": true,
			"no_rewards": true,
			"seed": 3
		}
	)
	var t := 0.0
	while a.state == "intro" and t < 10.0:
		a.step(1.0 / 60.0)
		t += 1.0 / 60.0
	var d: BattleDirector = a.director
	var u: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	foe.entry_t = 0.0
	foe.hp = 1
	foe.mon.hp = 1
	d.on_move(u, Dex.move("flamethrower"))  # dano de sobra, mas ainda não acertou
	check(
		d.shot != "ko" and is_equal_approx(d.time_scale(), 1.0),
		(
			"golpe fatal a caminho: sem zoom nem câmera lenta (cena '%s', %.2fx)"
			% [d.shot, d.time_scale()]
		)
	)
	for i in 90:  # o alvo desviou: nada acontece
		d.tick(1.0 / 60.0)
	check(d.shot != "ko", "o alvo desviou do golpe fatal: sem zoom de nocaute")
	foe.take_damage(40, u.flat_to(foe).normalized(), 4.0, {"source": u})
	check(not foe.alive(), "o golpe acertou e o alvo desmaiou")
	check(d.shot == "ko" and d.target == foe, "nocaute de verdade: zoom no desmaiado")
	check(
		d.time_scale() < BattleDirector.KO_SCALE,
		"hit-stop no impacto do nocaute (%.2fx)" % d.time_scale()
	)
	d.tick(BattleDirector.KO_HIT + 0.01)
	check(
		is_equal_approx(d.time_scale(), BattleDirector.KO_SCALE),
		"depois do impacto, câmera lenta no desmaio (%.2fx)" % d.time_scale()
	)
	a.queue_free()
	await process_frame


func _run() -> void:
	await _ko_zoom()
	Cfg.current = _cfg()
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
	var band := {}
	var fade := {}
	var raised := true
	for i in LIMIT:
		await physics_frame
		if not is_instance_valid(ar) or tb._result_box.visible:
			break
		_watch_band(ar, d, band)
		_watch_fade(ar, d, fade)
		raised = raised and ar._cam.v_offset > 0.0
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
	check(not shots.has("finish"), "sem zoom pela previsão de dano antes do golpe")
	check(int(shots.get("big", 0)) > 0, "destaque de golpe grande (%d)" % int(shots.get("big", 0)))
	check(slow > 0, "câmera lenta em %d quadros" % slow)
	check(hold_frames > 0, "troca segurou a luta por %d quadros" % hold_frames)
	check(hold_moved == 0, "ninguém gasta nem ganha energia na troca (%d)" % hold_moved)
	print("cenas: ", shots)
	_check_band(band, "dupla, campo")
	_check_fade(fade, "dupla, campo")
	check(raised, "a câmera sobe (v_offset) para a faixa livre entre o HUD")
	tb.queue_free()
	await process_frame

	# Singles on another scenario: one row of cards, so a lower band.
	Cfg.current = _cfg(1, "praia")
	tb = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	ar = tb.arena
	d = ar.director
	band = {}
	fade = {}
	for i in LIMIT:
		await physics_frame
		if not is_instance_valid(ar) or tb._result_box.visible:
			break
		_watch_band(ar, d, band)
		_watch_fade(ar, d, fade)
	check(tb._result_box.visible, "simples, praia: a luta terminou")
	_check_band(band, "simples, praia")
	_check_fade(fade, "simples, praia")
	tb.queue_free()
	await process_frame

	var c := _cfg()
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
