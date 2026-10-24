extends SceneTree
## Duelo de IAs no modo treino: a IA VGC (BattleTactics + BattleTrainerAI) contra a IA antiga, com dois
## times de 6 montados para dupla (Protect, Tailwind, Fake Out, Follow Me, golpes de área), nos dois
## lados, com o mesmo time nos dois lados (o que mede a IA) e nas duas ordens dos times, em 2x2 (e 1x1 com size=1). Conta vitórias, trocas, itens e o uso
## de Protect/Tailwind/Fake Out/Helping Hand/Follow Me por IA.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/balance/ia_duel.gd -- seeds=3
## Opções: seeds=N (padrão 2), size=1|2 (padrão 2), mirror=1 (também VGC x VGC).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
## Golpes desejados por espécie (entram os 4 primeiros que a espécie aprende; o resto do Nv 50).
const TEAMS := {
	"Vento":
	{
		"Pidgeot": ["tailwind", "brave_bird", "protect", "hurricane", "air_slash", "quick_attack"],
		"Raichu": ["fake_out", "thunderbolt", "protect", "helping_hand", "thunder_wave"],
		"Nidoking": ["earth_power", "sludge_bomb", "protect", "ice_beam", "earthquake"],
		"Ninetales": ["heat_wave", "will_o_wisp", "protect", "flamethrower", "nasty_plot"],
		"Clefable": ["follow_me", "moonblast", "protect", "helping_hand", "thunder_wave"],
		"Golbat": ["tailwind", "cross_poison", "protect", "taunt", "air_slash"],
	},
	"Floresta":
	{
		"Venusaur": ["sleep_powder", "sludge_bomb", "giga_drain", "protect", "leaf_storm"],
		"Charizard": ["heat_wave", "air_slash", "protect", "tailwind", "flamethrower"],
		"Blastoise": ["fake_out", "surf", "ice_beam", "protect", "water_pulse"],
		"Sandslash": ["earthquake", "rock_slide", "swords_dance", "protect", "slash"],
		"Arbok": ["glare", "gunk_shot", "sucker_punch", "protect", "poison_jab"],
		"Vileplume": ["sleep_powder", "sludge_bomb", "moonblast", "protect", "giga_drain"],
	},
}
const TIME_LIMIT := 900
const WATCH := ["protect", "tailwind", "fake_out", "helping_hand", "follow_me", "rage_powder"]

var seeds := 2
var size := 2
var mirror := false
var _use := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			match kv[0]:
				"seeds":
					seeds = int(kv[1])
				"size":
					size = clampi(int(kv[1]), 1, 2)
				"mirror":
					mirror = kv[1] == "1"
	_run.call_deferred()


static func team(name: String) -> Array:
	var out: Array = []
	var t: Dictionary = TEAMS[name]
	for sp in t:
		var e := Cfg.mon_entry(String(sp), Cfg.LEVEL)
		var mv: Array = []
		for id in t[sp]:
			if mv.size() < 4 and Cfg.learn_level(String(sp), String(id)) >= 0:
				mv.append(String(id))
		for id in e.get("moves", []):
			if mv.size() < 4 and not mv.has(id):
				mv.append(id)
		e["moves"] = mv
		out.append(e)
	return out


func _run() -> void:
	Cfg.path = "user://ia_duel_cfg.json"
	var modes := [[true, false], [false, true]]
	if mirror:
		modes.append([true, true])
	var tally := {}
	for m in modes:
		for order in [
			["Vento", "Vento"],
			["Floresta", "Floresta"],
			["Vento", "Floresta"],
			["Floresta", "Vento"]
		]:
			for s in seeds:
				var r := await _one(order[0], order[1], m, 300 + s)
				var key := "%s x %s" % ["VGC" if m[0] else "antiga", "VGC" if m[1] else "antiga"]
				var t: Dictionary = tally.get(key, {"a": 0, "b": 0, "draw": 0, "time": 0.0, "n": 0})
				match String(r.outcome):
					"win":
						t.a += 1
					"lose":
						t.b += 1
					_:
						t.draw += 1
				t.time += float(r.time)
				t.n += 1
				tally[key] = t
				print(
					(
						"%s | %s x %s seed %d -> %s %.0fs | trocas %d-%d itens %d-%d"
						% [
							key,
							order[0],
							order[1],
							300 + s,
							r.outcome,
							r.time,
							r.sw[0],
							r.sw[1],
							r.it[0],
							r.it[1]
						]
					)
				)
	print("--- resumo (lado A x lado B) ---")
	for k in tally:
		var t: Dictionary = tally[k]
		print(
			(
				"%s: A %d, B %d, empate %d, média %.0fs"
				% [k, t.a, t.b, t.draw, t.time / maxf(float(t.n), 1.0)]
			)
		)
	print("--- golpes de dupla por IA ---")
	for k in _use:
		print("%s: %s" % [k, str(_use[k])])
	quit(0)


func _one(a: String, b: String, m: Array, sd: int) -> Dictionary:
	var c := Cfg.default_config()
	c.sides[0].name = a
	c.sides[1].name = b
	c.sides[0].mons = team(a)
	c.sides[1].mons = team(b)
	c.sides[0].item = "super_potion"
	c.sides[1].item = "super_potion"
	c.battle_size = size
	c.seed = sd
	c.turbo = true
	c.time_limit = TIME_LIMIT
	c["vgc_ai"] = m
	c["trainer_ai"] = m
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	var arena: Node = tb.arena
	var tai: Dictionary = arena.trainer_ai.duplicate()
	arena.move_used.connect(
		func(u, mv):
			var id := String(mv.get("id", ""))
			var label := "VGC" if bool(m[u.side]) else "antiga"
			var d: Dictionary = _use.get(label, {})
			var key := (
				id if id in WATCH else ("status" if float(mv.get("power", 0)) <= 0.0 else "dano")
			)
			d[key] = int(d.get(key, 0)) + 1
			_use[label] = d
	)
	for i in 60 * 60 * 20:
		await process_frame
		if tb._result_box.visible:
			break
	var sw := [0, 0]
	var it := [0, 0]
	for s in [0, 1]:
		var t = tai.get(s)
		if t is BattleTrainerAI:
			sw[s] = t.switches
			it[s] = t.items
	var r := {
		"outcome": String(tb.result.get("outcome", "?")),
		"time": float(tb.fight_time),
		"sw": sw,
		"it": it,
	}
	tb.queue_free()
	await process_frame
	return r
