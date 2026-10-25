extends SceneTree
## Bateria grande de lutas para balancear (Caio, 2026-10-25): times, golpes, habilidades, clima, nível da
## IA e formato sorteados pela semente, cada luta gravando a telemetria completa (BattleTelemetry) em
## out/<semente>.json. Roda em turbo (passos de 1x, o resultado não muda; ver tests/balance/turbo_check.gd).
## Rodar várias em paralelo (tools/battery.sh) e analisar com tools/battery_report.py.
## Opções (depois de --): n=N, seed=N, out=DIR, mode=energy|vgc, size=1|2|mix, weather=mix|none,
## pace=X (damage_pace), think=mix|1, team=N (Pokémon por lado, padrão 6), limit=S,
## scenario=campo|lagoa|pedreira|misto (omitido ou aleatorio = sorteado por luta).

const Cfg := preload("res://ui/training/training_config.gd")
const SCENE := "res://ui/training/training_battle.tscn"
const WEATHERS := ["", "", "", "sun", "rain", "sand", "hail"]

var n := 10
var seed0 := 1
var out := "user://battery"
var mode := "energy"
var size := "mix"
var weather := "mix"
var pace := -1.0
var think := "mix"
var team := 6
var limit := 420
var scenario := ""
var extra := {}
var turbo := true


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"n":
				n = int(kv[1])
			"seed":
				seed0 = int(kv[1])
			"out":
				out = kv[1]
			"mode":
				mode = kv[1]
			"size":
				size = kv[1]
			"weather":
				weather = kv[1]
			"pace":
				pace = float(kv[1])
			"think":
				think = kv[1]
			"team":
				team = int(kv[1])
			"limit":
				limit = int(kv[1])
			"turbo":
				turbo = kv[1] != "0"
			"scenario":
				scenario = kv[1] if Cfg.SCENARIOS.has(kv[1]) else ""
			_:
				# Qualquer outra chave vira opts da arena (número quando der).
				extra[kv[0]] = float(kv[1]) if kv[1].is_valid_float() else kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	Cfg.path = "user://battery_cfg_%d.json" % seed0
	var t0 := Time.get_ticks_msec()
	for k in n:
		var sd := seed0 + k
		var r := await _one(sd)
		print("seed %d %s %dx%d -> %-7s %6.1fs" % [sd, r.mode, r.size, r.size, r.outcome, r.time])
	print("fim: %d lutas em %.0f s" % [n, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


func _one(sd: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var c := Cfg.default_config()
	Cfg.randomize_sides(c, rng)
	for s in 2:
		c.sides[s].mons = c.sides[s].mons.slice(0, team)
		if think == "mix":
			c.sides[s].think_scale = [0.8, 1.0, 1.0, 1.2][rng.randi() % 4]
	var sz := int(size) if size != "mix" else 1 + rng.randi() % 2
	var w: String = WEATHERS[rng.randi() % WEATHERS.size()] if weather == "mix" else ""
	c.battle_mode = mode
	c.battle_size = sz
	c.seed = sd
	c.scenario = scenario
	c.turbo = turbo
	c.time_limit = limit
	if w != "":
		c.weather = w
	var path := "%s/%d.json" % [out, sd]
	var eo := {"telemetry": path}
	eo["telemetry_meta"] = {
		"seed": sd,
		"mode": mode,
		"size": sz,
		"weather": w,
		"think": [c.sides[0].think_scale, c.sides[1].think_scale],
		"pace": pace,
		"extra": extra,
		"scenario": scenario,
	}
	if pace > 0.0:
		eo["damage_pace"] = pace
	eo.merge(extra, true)
	c.extra_opts = eo
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	for i in 60 * 60 * 30:
		await process_frame
		if tb._result_box.visible:
			break
	var r := {
		"mode": mode,
		"size": sz,
		"outcome": String(tb.result.get("outcome", "?")),
		"time": float(tb.fight_time),
	}
	tb.queue_free()
	await process_frame
	return r
