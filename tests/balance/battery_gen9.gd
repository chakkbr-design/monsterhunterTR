extends SceneTree
## Bateria de lutas do modo treino (Gen 9, Pokémon 1-51): times de 6 com tipos variados, todos contra
## todos, em 1x1 e 2x2, com turbo, nos dois lados (A x B e B x A, para ver vantagem de lado). Mede vencedor, duração, uso de golpes (status x dano), dano médio
## por acerto de cada golpe nos dois modos (deve ser igual) e erros.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/balance/battery_gen9.gd
## Opções (depois de --): seeds=N (lutas por par e modo, padrão 1), level=N (padrão 50),
## out=<arquivo json> (padrão user://battery_gen9.json).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const TEAMS := {
	"Iniciais+": ["Venusaur", "Charizard", "Blastoise", "Raichu", "Sandslash", "Clefable"],
	"Rota": ["Pidgeot", "Arbok", "Ninetales", "Dugtrio", "Parasect", "Wigglytuff"],
	"Floresta": ["Butterfree", "Nidoking", "Wartortle", "Pikachu", "Raticate", "Vileplume"],
	"Montanha": ["Beedrill", "Fearow", "Nidoqueen", "Charmeleon", "Ivysaur", "Clefairy"],
	"Noite": ["Golbat", "Venomoth", "Sandshrew", "Vulpix", "Jigglypuff", "Blastoise"],
}
## Limite por luta em segundos de jogo (passou disso conta como empate).
const TIME_LIMIT := 900

var seeds := 1
var level := 50
var out_path := "user://battery_gen9.json"
var _hp := {}
var _stats := {}
var _fight := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			match kv[0]:
				"seeds":
					seeds = int(kv[1])
				"level":
					level = int(kv[1])
				"out":
					out_path = kv[1]
	_run.call_deferred()


func _team(names: Array) -> Array:
	var out: Array = []
	for n in names:
		out.append(Cfg.mon_entry(String(n), level))
	return out


func _run() -> void:
	Cfg.path = "user://battery_cfg.json"
	var keys := TEAMS.keys()
	var fights: Array = []
	for size in [1, 2]:
		for i in keys.size():
			for j in keys.size():
				if j == i:
					continue
				for s in seeds:
					var r := await _one(keys[i], keys[j], size, 100 + s)
					fights.append(r)
					print(
						(
							"%dx%d %-10s x %-10s -> %-7s %5.1fs KOs %d-%d"
							% [
								size,
								size,
								keys[i],
								keys[j],
								r.outcome,
								r.time,
								r.ko_by_a,
								r.ko_by_b
							]
						)
					)
	_report(fights)
	quit(0)


func _one(a: String, b: String, size: int, sd: int) -> Dictionary:
	var c := Cfg.default_config()
	c.sides[0].name = a
	c.sides[1].name = b
	c.sides[0].mons = _team(TEAMS[a])
	c.sides[1].mons = _team(TEAMS[b])
	c.battle_size = size
	c.seed = sd
	c.turbo = true
	c.time_limit = TIME_LIMIT
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	_hp.clear()
	_fight = {"ko_by_a": 0, "ko_by_b": 0}
	var mode := "%dx%d" % [size, size]
	var arena: Node = tb.arena
	arena.move_used.connect(func(u, mv): _on_move(mode, u, mv))
	arena.hit_landed.connect(func(u, t, mv): _on_hit(mode, u, t, mv))
	for i in 60 * 60 * 20:
		await process_frame
		if tb._result_box.visible:
			break
		if not is_instance_valid(tb.arena):
			continue
		for f in tb.arena.fighters:
			if is_instance_valid(f):
				_hp[f] = f.hp
	var r := {
		"a": a,
		"b": b,
		"mode": mode,
		"seed": sd,
		"outcome": String(tb.result.get("outcome", "?")),
		"time": snappedf(float(tb.fight_time), 0.1),
		"ko_by_a": _fight.ko_by_a,
		"ko_by_b": _fight.ko_by_b,
	}
	tb.queue_free()
	await process_frame
	return r


func _st(mode: String, id: String) -> Dictionary:
	var k := mode + "|" + id
	if not _stats.has(k):
		_stats[k] = {"uses": 0, "hits": 0, "dmg": 0, "kos": 0}
	return _stats[k]


func _on_move(mode: String, _u, mv: Dictionary) -> void:
	_st(mode, String(mv.get("id", "?"))).uses += 1


func _on_hit(mode: String, u, t, mv: Dictionary) -> void:
	if not is_instance_valid(t):
		return
	var before := int(_hp.get(t, t.hp))
	var d := before - int(t.hp)
	_hp[t] = t.hp
	if d <= 0:
		return
	var s := _st(mode, String(mv.get("id", "?")))
	s.hits += 1
	s.dmg += d
	if t.hp <= 0:
		s.kos += 1
		if is_instance_valid(u) and int(u.side) == 0:
			_fight.ko_by_a += 1
		else:
			_fight.ko_by_b += 1


func _report(fights: Array) -> void:
	var by_mode := {}
	for f in fights:
		var m: Dictionary = by_mode.get(f.mode, {"n": 0, "time": 0.0, "timeout": 0})
		m.n += 1
		m.time += f.time
		if f.outcome == "timeout":
			m.timeout += 1
		by_mode[f.mode] = m
	print("\n== Resumo por modo ==")
	for k in by_mode:
		var m: Dictionary = by_mode[k]
		print(
			(
				"%s: %d lutas, duração média %.1f s, %d sem vencedor"
				% [k, m.n, m.time / maxf(1, m.n), m.timeout]
			)
		)
	print("
== Vitórias por time e por lado ==")
	for mode in ["1x1", "2x2"]:
		var wins := {}
		var side_a := 0
		var n := 0
		for f in fights:
			if f.mode != mode or f.outcome == "timeout":
				continue
			n += 1
			var w: String = f.a if f.outcome == "win" else f.b
			wins[w] = int(wins.get(w, 0)) + 1
			if f.outcome == "win":
				side_a += 1
		print("%s: lado A ganhou %d de %d; por time %s" % [mode, side_a, n, str(wins)])
	var status_uses := {"1x1": 0, "2x2": 0}
	var all_uses := {"1x1": 0, "2x2": 0}
	var ids := {}
	for k in _stats:
		var p := String(k).split("|")
		ids[p[1]] = true
		var mv := Dex.move(p[1])
		all_uses[p[0]] += _stats[k].uses
		if String(mv.get("category", "")) == "status":
			status_uses[p[0]] += _stats[k].uses
	print("\n== Golpes de status / total ==")
	for k in all_uses:
		print(
			(
				"%s: %d / %d (%.0f%%)"
				% [k, status_uses[k], all_uses[k], 100.0 * status_uses[k] / maxf(1, all_uses[k])]
			)
		)
	print("\n== Dano médio por acerto (1x1 | 2x2) e usos ==")
	var rows: Array = ids.keys()
	rows.sort()
	for id in rows:
		var s1: Dictionary = _stats.get("1x1|" + id, {"uses": 0, "hits": 0, "dmg": 0})
		var s2: Dictionary = _stats.get("2x2|" + id, {"uses": 0, "hits": 0, "dmg": 0})
		print(
			(
				"%-16s %6.1f | %6.1f   usos %4d | %4d"
				% [
					id,
					float(s1.dmg) / maxf(1, s1.hits),
					float(s2.dmg) / maxf(1, s2.hits),
					s1.uses,
					s2.uses
				]
			)
		)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fights": fights, "moves": _stats}, " "))
		print("\nJSON: " + ProjectSettings.globalize_path(out_path))
