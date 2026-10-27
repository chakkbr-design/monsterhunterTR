class_name BattleTelemetry
extends RefCounted
## Telemetria da luta (opts.telemetry = caminho do arquivo .json): tudo o que acontece na luta, para a
## bateria de testes analisar depois (tests/balance/battery.gd + tools/battery_report.py).
##
## - meta: semente, modo, formato, cenário, times (espécie, tipos, golpes, habilidade, stats).
## - events: golpe usado (custo, energia, distância, alto/água/grama, intenção e estado da IA), acerto
##   (dano, crítico, eficácia, HP antes, KO, segundos desde a entrada do alvo), sorteio de status (chance e
##   se pegou), status aplicado/curado, dano residual, desmaio, entrada, esquiva, eventos do terreno, passivas.
## - samples: a cada SAMPLE s, o estado de cada lutador em campo (posição, chão, HP, energia, status,
##   estágios, estado da IA, alvo, distância, parede, água, alto, grama, descanso, corrida, ânimo, comando).
## - track (para montar vídeo, tools/video/): a cada TRACK s de vídeo, a vida de todo Pokémon dos dois
##   times (em campo ou no banco), quem está em campo e o estado da arena. O relógio do vídeo (vt) é o
##   tempo real de quadro (frame(), uma vez por quadro de física, desde a arena começar): conta a
##   abertura, as trocas paradas e a câmera lenta, que o t da luta não conta. Todo evento leva o vt.

const SAMPLE := 0.25
const TRACK := 0.1

var arena: Node
var path := ""
var t := 0.0
var _sample_t := 0.0
var events: Array = []
var samples: Array = []
var ids := {}
var entered_at := {}
var meta := {}
var _n := 0
## Relógio do vídeo (segundos reais de quadro desde a arena começar) e a linha do tempo da vida.
var vt := 0.0
var _track_t := 0.0
var track: Array = []
## Quadro desenhado quando a arena começou (com --write-movie, o quadro do vídeo onde vt = 0).
var frame0 := 0


func _init(a: Node, p: String) -> void:
	arena = a
	path = p
	arena.move_used.connect(_on_move)
	arena.dodged.connect(func(f, what): ev("dodge", {"who": uid(f), "what": what}))
	frame0 = Engine.get_frames_drawn()


## Id curto e estável do lutador: lado, posição no time e espécie ("0:2:pikachu").
func uid(f) -> String:
	if not is_instance_valid(f):
		return ""
	var k: int = f.get_instance_id()
	if not ids.has(k):
		var team: Array = arena.party if f.side == 0 else arena.enemies
		ids[k] = "%d:%d:%s" % [f.side, team.find(f.mon), f.mon.species]
	return ids[k]


func ev(kind: String, data: Dictionary) -> void:
	data["t"] = snappedf(t, 0.01)
	data["vt"] = snappedf(vt, 0.001)
	data["ev"] = kind
	events.append(data)


func _where(f) -> Dictionary:
	var out := {}
	var ter = arena.get("terrain")
	if ter:
		out["gy"] = snappedf(f.ground_y, 0.01)
		if ter.on_high(f):
			out["high"] = true
		if ter.in_water(f):
			out["water"] = true
		if ter.has_method("in_grass") and ter.in_grass(f):
			out["grass"] = true
	return out


func _on_move(user, mv: Dictionary) -> void:
	var d := {
		"who": uid(user),
		"move": String(mv.get("id", "")),
		"type": String(mv.get("type", "")),
		"cat": String(mv.get("category", "")),
		"bp": int(mv.get("bp", mv.get("power", 0))),
		"kind": String(mv.get("kind", "")),
		"cost": user.pp_cost_of(mv),
		"en": snappedf(user.pp_max, 0.1),
		"hp": snappedf(float(user.hp) / maxf(user.max_hp, 1), 0.01),
	}
	if is_instance_valid(user.opponent):
		d["tgt"] = uid(user.opponent)
		d["dist"] = snappedf(user.flat_to(user.opponent).length(), 0.01)
	if user.ai:
		d["ai"] = user.ai.tag
		d["why"] = user.ai.why
		if user.ai.get("plan") != null:
			d["plan"] = String(user.ai.plan)
	d.merge(_where(user))
	ev("move", d)


func hit(user, target, mv: Dictionary, dmg: int, hp_before: int, crit: bool, eff: float) -> void:
	var k: int = target.get_instance_id()
	var d := {
		"who": uid(user),
		"tgt": uid(target),
		"move": String(mv.get("id", "")),
		"dmg": dmg,
		"hp0": hp_before,
		"max": target.max_hp,
		"frac": snappedf(float(dmg) / maxf(target.max_hp, 1), 0.001),
		"crit": crit,
		"eff": eff,
		"ko": dmg >= hp_before,
		"since_in": snappedf(t - float(entered_at.get(k, 0.0)), 0.01),
	}
	var w := _where(target)
	for key in w:
		d["t_" + key] = w[key]
	ev("hit", d)


func status_roll(user, target, mv: Dictionary, st: String, chance: float, got: bool) -> void:
	ev(
		"status_roll",
		{
			"who": uid(user),
			"tgt": uid(target),
			"move": String(mv.get("id", "")),
			"st": st,
			"chance": snappedf(chance, 0.001),
			"got": got,
		}
	)


func enter(f) -> void:
	entered_at[f.get_instance_id()] = t
	ev("enter", {"who": uid(f), "hp": f.hp, "max": f.max_hp})


func faint(f) -> void:
	var k: int = f.get_instance_id()
	ev(
		"faint",
		{
			"who": uid(f),
			"by": uid(f.last_hit_by),
			"on_field": snappedf(t - float(entered_at.get(k, 0.0)), 0.01),
		}
	)


## Qualquer outra coisa (terreno, passivas, status, residual): kind + dados livres com lutadores já
## convertidos pelo chamador (use uid()).
func note(kind: String, data := {}) -> void:
	ev(kind, data)


func step(dt: float) -> void:
	t += dt
	_sample_t -= dt
	if _sample_t > 0.0:
		return
	_sample_t = SAMPLE
	var rows: Array = []
	for f in arena.fighters:
		if not is_instance_valid(f) or not f.on_field or not f.alive():
			continue
		var r := {
			"id": uid(f),
			"x": snappedf(f.position.x, 0.01),
			"z": snappedf(f.position.z, 0.01),
			"hp": snappedf(float(f.hp) / maxf(f.max_hp, 1), 0.001),
			"en": snappedf(f.pp_max, 0.1),
		}
		r.merge(_where(f))
		if f.status != "":
			r["st"] = f.status
		var stg := {}
		for k in f.stages:
			if int(f.stages[k]) != 0:
				stg[k] = int(f.stages[k])
		if not stg.is_empty():
			r["stg"] = stg
		if f.fly_h > 0.2:
			r["fly"] = snappedf(f.fly_h, 0.01)
		if f.sprinting:
			r["run"] = true
		if f.stun_t > 0.0:
			r["stun"] = true
		if f.mood_state != "":
			r["mood"] = f.mood_state
		if BattleEnergy.resting(f):
			r["rest"] = true
		if f.ai:
			r["ai"] = f.ai.tag
			r["int"] = f.ai.intent
			r["cmd"] = f.ai.ally_mode()
			if f.ai.get("plan") != null:
				r["plan"] = String(f.ai.plan)
		if is_instance_valid(f.opponent):
			r["tgt"] = uid(f.opponent)
			r["d"] = snappedf(f.flat_to(f.opponent).length(), 0.01)
		var rc: Rect2 = arena.rect
		var p: Vector3 = f.position
		r["wall"] = snappedf(
			minf(
				minf(p.x - rc.position.x, rc.end.x - p.x), minf(p.z - rc.position.y, rc.end.y - p.z)
			),
			0.01
		)
		rows.append(r)
	samples.append({"t": snappedf(t, 0.01), "f": rows})


## Um quadro de física (dt real, uma vez por quadro, mesmo com a arena em vários passos): anda o
## relógio do vídeo e grava a vida dos dois times a cada TRACK s.
func frame(dt: float) -> void:
	vt += dt
	_track_t -= dt
	if _track_t > 0.0:
		return
	_track_t = TRACK
	track.append(snapshot())


## Vida de todo Pokémon dos dois times agora: {vt, t, st, hp: [[hp, ...], [...]], on: [[i, ...], [...]]}.
## hp em pontos de batalha (os do banco convertidos do Mon), on = índices no time de quem está em campo.
func snapshot() -> Dictionary:
	var by_mon := {}
	for f in arena.fighters:
		if is_instance_valid(f):
			by_mon[f.mon] = f
	var hp: Array = [[], []]
	var on: Array = [[], []]
	for side in 2:
		var team: Array = arena.party if side == 0 else arena.enemies
		for i in team.size():
			var m = team[i]
			var f = by_mon.get(m)
			if f and f.on_field and f.alive():
				hp[side].append(maxi(f.hp, 0))
				on[side].append(i)
			elif m.is_fainted():
				hp[side].append(0)
			else:
				hp[side].append(BattleFighter.hp_from_mon(m.hp))
	return {
		"vt": snappedf(vt, 0.001),
		"t": snappedf(t, 0.01),
		"st": String(arena.get("state")),
		"hp": hp,
		"on": on,
	}


func finish(result: Dictionary) -> void:
	if path == "":
		return
	var teams: Array = [[], []]
	for side in 2:
		for m in arena.party if side == 0 else arena.enemies:
			teams[side].append(
				{
					"sp": m.species,
					"name": m.display_name,
					"lv": m.level,
					"max": BattleFighter.hp_from_mon(m.max_hp),
					"types": Dex.species(m.species).get("types", []),
					"moves":
					m.moves.map(func(e): return String(e.id) if e is Dictionary else String(e)),
					"ability": m.ability if m.get("ability") != null else "",
					"hp_end": m.hp,
					"fainted": m.is_fainted(),
				}
			)
	track.append(snapshot())
	var out := {
		"meta": meta,
		"result":
		{
			"outcome": String(result.get("outcome", "")),
			"time": snappedf(t, 0.01),
			"vt": snappedf(vt, 0.001),
		},
		"video":
		{
			"frame0": frame0,
			"physics_fps": Engine.physics_ticks_per_second,
			"track_step": TRACK,
		},
		"teams": teams,
		"events": events,
		"samples": samples,
		"track": track,
	}
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(out))
		fa.close()
