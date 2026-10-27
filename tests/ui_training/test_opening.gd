extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/ui_training/test_opening.gd
## Abertura do treino (BattleOpening): o telão com os nomes, a arena inteira,
## cada treinador joga os titulares (close no treinador, a bola, zoom no Pokémon) e só então a
## luta começa. Antes disso ninguém está em campo à vista nem gasta energia; a abertura acaba em
## tempo limitado; nada disso no fast_sim nem com opts.opening = false.

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
## Teto da abertura em segundos de luta (2x2: ~8,6 s; 1x1: ~8,3 s).
const MAX_2V2 := 9.2
const MAX_1V1 := 9.0
const DT := 1.0 / 60.0

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1152, 648)
	_run.call_deferred()


func _cfg(size: int, extra := {}) -> Dictionary:
	Cfg.path = "user://test_opening_cfg.json"
	var c := Cfg.default_config()
	var a: Array = []
	var b: Array = []
	for s in ["Charizard", "Blastoise", "Venusaur"]:
		a.append(Cfg.mon_entry(s, 50))
	for s in ["Gengar", "Machamp", "Alakazam"]:
		b.append(Cfg.mon_entry(s, 50))
	c.sides[0].mons = a
	c.sides[1].mons = b
	c.sides[0]["name"] = "Red"
	c.sides[1]["name"] = ""
	c.speed = 1.0
	c.seed = 5
	c.battle_size = size
	if not extra.is_empty():
		c["extra_opts"] = extra
	return c


func _opening(size: int, limit: float) -> void:
	var tag := "%dx%d" % [size, size]
	Cfg.current = _cfg(size)
	var tb: Node = load(SCENE).instantiate()
	var beats: Array = []
	root.add_child(tb)
	var ar: Node = tb.arena
	ar.opening_beat.connect(func(b: String) -> void: beats.append(b))
	var sent := [0]
	ar.send_out_done.connect(func(_s: int, f) -> void: sent[0] += int(f != null))
	check(
		String(ar.state) == "opening" and ar.opening != null, "%s: a luta abre pela abertura" % tag
	)
	var d: BattleDirector = ar.director
	# "vs" sai dentro de start() (antes deste connect): o telão já mostra o "VS".
	check(tb._headline == "VS", '%s: "VS" no telão desde o começo' % tag)
	beats.append("vs")
	var pts: Array = d.cine.get("pts", [])
	check(
		not pts.is_empty() and pts.all(func(p: Vector3) -> bool: return p.z < -25.0),
		"%s: a câmera começa no telão do estádio (%d pontos)" % [tag, pts.size()]
	)
	check(
		ar.opening.names == [Cfg.side_name(Cfg.current, 0), Cfg.side_name(Cfg.current, 1)],
		"%s: nomes dos times no telão %s" % [tag, ar.opening.names]
	)
	var on_field: Array = ar.fighters.filter(func(f) -> bool: return f.on_field)
	check(on_field.size() == size * 2, "%s: %d titulares criados" % [tag, on_field.size()])
	check(
		on_field.all(func(f) -> bool: return not f.visible),
		"%s: ninguém à vista antes da bola" % tag
	)
	var energy := {}
	var pos := {}
	for f in on_field:
		energy[f] = f.pp_max
		pos[f] = f.position
	var t := 0.0
	var trainer_close := 0
	var ball_follow := 0
	var mon_zoom := 0
	var hidden_before_throw := true
	var headline_vs := false
	while String(ar.state) == "opening" and t < 20.0:
		await physics_frame
		t = float(ar.opening.t) if ar.opening else t
		if not beats.has("throw") and on_field.any(func(f) -> bool: return f.visible):
			hidden_before_throw = false
		if tb._headline == "VS":
			headline_vs = true
		if d.shot == "send":
			var fr := d._send_frame()
			if fr[3] == BattleDirector.SEND_TRAINER_DIST:
				trainer_close += 1
			elif fr[3] == BattleDirector.SEND_BALL_DIST:
				ball_follow += 1
			elif not d.framed().is_empty():
				mon_zoom += 1
	check(String(ar.state) == "fight", "%s: a luta começou depois da abertura" % tag)
	check(t <= limit, "%s: abertura em %.2f s de luta (teto %.1f)" % [tag, t, limit])
	check(
		beats == ["vs", "wide", "throw", "fight", "done"],
		"%s: sequência da abertura %s" % [tag, beats]
	)
	check(headline_vs, '%s: "VS" no telão' % tag)
	check(hidden_before_throw, "%s: ninguém aparece antes de a bola abrir" % tag)
	check(
		on_field.all(func(f) -> bool: return f.on_field and f.visible),
		"%s: os %d titulares em campo e à vista" % [tag, on_field.size()]
	)
	check(sent[0] == size * 2, "%s: %d bolas soltaram o Pokémon" % [tag, sent[0]])
	check(ar._balls.is_empty(), "%s: nenhuma bola sobrando" % tag)
	check(
		on_field.all(func(f) -> bool: return is_equal_approx(f.pp_max, energy[f])),
		"%s: ninguém ganha nem gasta energia na abertura" % tag
	)
	check(
		on_field.all(func(f) -> bool: return f.position.distance_to(pos[f]) < 0.01),
		"%s: ninguém anda na abertura" % tag
	)
	check(is_zero_approx(tb.fight_time), "%s: o relógio da luta só corre depois" % tag)
	check(
		trainer_close > 0 and ball_follow > 0 and mon_zoom > 0,
		(
			"%s: câmera no treinador (%d), na bola (%d) e no Pokémon (%d)"
			% [tag, trainer_close, ball_follow, mon_zoom]
		)
	)
	check(
		on_field.all(
			func(f) -> bool: return f.look == null or is_equal_approx(f.look.scale_mult, 1.0)
		),
		"%s: todos no tamanho normal ao começar" % tag
	)
	# A luta segue normal: alguém gasta energia logo depois.
	var moved := false
	for i in 60 * 6:
		await physics_frame
		if not is_instance_valid(ar) or String(ar.state) != "fight":
			break
		for f in on_field:
			if is_instance_valid(f) and f.position.distance_to(pos[f]) > 0.5:
				moved = true
		if moved:
			break
	check(moved, "%s: a IA começa a lutar depois da abertura" % tag)
	tb.queue_free()
	await process_frame


func _skipped(c: Dictionary, what: String) -> void:
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	var ar: Node = tb.arena
	check(
		ar.get("opening") == null and String(ar.state) != "opening",
		"%s: sem abertura (state %s)" % [what, ar.state]
	)
	tb.queue_free()
	await process_frame


func _run() -> void:
	await _opening(2, MAX_2V2)
	await _opening(1, MAX_1V1)
	await _skipped(_cfg(2, {"fast_sim": true}), "fast_sim (bateria)")
	await _skipped(_cfg(2, {"opening": false}), "opts.opening = false")
	print("FALHAS: %d" % fails)
	quit(1 if fails > 0 else 0)
