extends SceneTree
## Séries de lutas com times sorteados (Cfg.randomize_sides) pela tela do treino, em turbo, para caçar
## bugs: em cada quadro confere HP, estágios, status, energia/PP e posição de todo lutador em campo, e
## marca luta parada (ninguém soltou golpe por STALL s) e luta que não terminou no limite de tempo.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/balance/random_series.gd
## Opções (depois de --): n=N (lutas, padrão 20), seed=N (primeira semente, padrão 1000),
## mode=energy|vgc|mix (padrão mix), size=1|2|mix (padrão mix).
## Cada linha traz a semente: Cfg.randomize_sides com ela refaz os times (e a luta).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const TIME_LIMIT := 600
const STALL := 60.0
const STATUSES := ["", "burn", "poison", "toxic", "paralysis", "sleep", "freeze"]

var n := 20
var seed0 := 1000
var mode := "mix"
var size := "mix"
var problems: Array = []
var used := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"n":
				n = int(kv[1])
			"seed":
				seed0 = int(kv[1])
			"mode":
				mode = kv[1]
			"size":
				size = kv[1]
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://random_series_cfg.json"
	_check_moves()
	var outcomes := {}
	for k in n:
		var sd := seed0 + k
		var r := await _one(sd)
		outcomes[r.outcome] = int(outcomes.get(r.outcome, 0)) + 1
		print(
			(
				"seed %d %s %dx%d -> %-7s %6.1fs %s"
				% [sd, r.mode, r.size, r.size, r.outcome, r.time, " | ".join(r.notes)]
			)
		)
	print("resultados: %s" % str(outcomes))
	print("golpes usados: %d" % used.size())
	print("PROBLEMAS: %d" % problems.size())
	for p in problems.slice(0, 60):
		print("  ", p)
	quit(1 if not problems.is_empty() else 0)


func check_ok(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)


## Regras do sorteio de golpes em todas as espécies, com várias sementes.
func _check_moves() -> void:
	var rng := RandomNumberGenerator.new()
	check_ok(
		Cfg.random_pool().size() >= 80,
		"sorteio com as evoluções finais (%d)" % Cfg.random_pool().size()
	)
	for sp in Cfg.random_pool():
		var into := String(Dex.species(sp).get("evolution", {}).get("into", ""))
		check_ok(
			into == "" or Dex.species(into).is_empty(),
			"%s evolui para %s e está no sorteio" % [sp, into]
		)
	for sp in Cfg.random_pool():
		for s in 5:
			rng.seed = s * 977 + hash(sp)
			var mv := Cfg.random_moves(sp, rng)
			var learn: Array = Cfg.learnable_moves(sp).map(func(e): return String(e.id))
			var dmg := mv.filter(func(id): return Dex.move(id).get("category") != "status")
			var st := mv.filter(func(id): return Dex.move(id).get("category") == "status")
			var uniq := {}
			for id in mv:
				uniq[id] = true
			if mv.size() > Mon.MAX_MOVES or uniq.size() != mv.size():
				problems.append("%s: golpes repetidos ou demais %s" % [sp, mv])
			if mv.any(func(id): return not learn.has(id)):
				problems.append("%s: golpe fora do learnset %s" % [sp, mv])
			var can_dmg := learn.any(func(id): return Dex.move(id).get("category") != "status")
			if can_dmg and dmg.is_empty():
				problems.append("%s: sem golpe de dano %s" % [sp, mv])
			if st.size() > 1:
				problems.append("%s: mais de um golpe de status %s" % [sp, mv])
			var cat := Cfg.preferred_category(sp)
			var types: Array = Dex.species(sp).get("types", [])
			for id in dmg:
				var m: Dictionary = Dex.move(id)
				if cat == "" or m.get("category") == cat or types.has(m.get("type")):
					continue
				if not Cfg._secondary_worth(m):
					problems.append("%s: %s fora da categoria %s sem efeito %s" % [sp, id, cat, mv])
			for t in Dex.species(sp).get("types", []):
				var can := learn.any(
					func(id):
						var m: Dictionary = Dex.move(id)
						return (
							m.get("type") == t
							and m.get("category") != "status"
							and float(m.get("power", 0)) > 0
						)
				)
				if can and not dmg.any(func(id): return Dex.move(id).get("type") == t):
					problems.append("%s: sem golpe de dano do tipo %s %s" % [sp, t, mv])


func _one(sd: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var c := Cfg.default_config()
	Cfg.randomize_sides(c, rng)
	var m: String = mode if mode != "mix" else ["energy", "vgc"][sd % 2]
	var sz := int(size) if size != "mix" else 1 + (sd / 2) % 2
	c.battle_mode = m
	c.battle_size = sz
	c.seed = sd
	c.turbo = true
	c.time_limit = TIME_LIMIT
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	var notes: Array = []
	var last_move := [0.0]
	var arena: Node = null
	var stalled := false
	for i in 60 * 60 * 30:
		if tb.arena != arena and is_instance_valid(tb.arena):
			arena = tb.arena
			arena.move_used.connect(
				func(u, mv: Dictionary) -> void:
					last_move[0] = tb.fight_time
					used[String(mv.get("id", ""))] = true
			)
		await process_frame
		if tb._result_box.visible:
			break
		if not is_instance_valid(tb.arena):
			continue
		_inspect(tb, sd, notes)
		if not stalled and tb.fight_time - last_move[0] > STALL:
			stalled = true
			_note(notes, sd, "ninguém soltou golpe por %d s (t=%.0f)" % [STALL, tb.fight_time])
	var outcome := String(tb.result.get("outcome", "?"))
	if outcome == "timeout" or not tb._result_box.visible:
		_note(notes, sd, "não terminou (%s)" % outcome)
	var r := {
		"mode": m,
		"size": sz,
		"outcome": outcome,
		"time": float(tb.fight_time),
		"notes": notes,
	}
	tb.queue_free()
	await process_frame
	return r


func _inspect(tb: Node, sd: int, notes: Array) -> void:
	var a: Node = tb.arena
	var rect: Rect2 = a.rect.grow(1.5)
	for f in a.fighters:
		if not is_instance_valid(f) or not f.on_field:
			continue
		var who := "%s(%d)" % [f.mon.species, f.side]
		if f.hp < 0 or f.hp > f.max_hp:
			_note(notes, sd, "%s HP fora da faixa %d/%d" % [who, f.hp, f.max_hp])
		for k in f.stages:
			if absi(int(f.stages[k])) > 6:
				_note(notes, sd, "%s estágio %s = %d" % [who, k, f.stages[k]])
		if not STATUSES.has(f.status):
			_note(notes, sd, "%s status estranho '%s'" % [who, f.status])
		if is_nan(f.pp_max) or f.pp_max < -0.01 or f.pp_max > f.pp_base + 0.01:
			_note(notes, sd, "%s energia/PP fora da faixa %.2f/%.2f" % [who, f.pp_max, f.pp_base])
		var p: Vector3 = f.position
		if is_nan(p.x) or is_nan(p.z) or not rect.has_point(Vector2(p.x, p.z)):
			_note(notes, sd, "%s fora da quadra %s" % [who, str(p)])
		if f.status == "paralysis" and f.par_t > f.PARALYSIS_SECS + 0.01:
			_note(notes, sd, "%s paralisia com %.1f s" % [who, f.par_t])


## Cada problema entra uma vez por luta (pelo texto sem os números).
func _note(notes: Array, sd: int, text: String) -> void:
	var re := RegEx.create_from_string("[-0-9.(),/ ]+")
	var key := re.sub(text, "", true)
	if notes.any(func(x): return re.sub(String(x), "", true) == key):
		return
	notes.append(text)
	problems.append("seed %d: %s" % [sd, text])
