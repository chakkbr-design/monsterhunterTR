class_name BattleAI
extends RefCounted
## IA de luta: intervalo de decisão, golpe com menos acertos até o KO, banda de distância com strafe,
## punição na recuperação do oponente, esquiva lateral/pulo contra dash e sprint ao se aproximar.

const THINK_MIN := 1.2
const THINK_MAX := 2.0
const THINK_RETRY := 0.25
const RECOVER := 0.5
const LOW_HP := 0.35
const KITE_MULT := 1.5
const MELEE_BAND := 3.6
const FAR_GAP := 2.0
const BAND_MAX := 3.5
const BAND_NEAR_RATIO := 0.7
const TACTIC_MISS_MULT := 1.5
const DODGE_TIME := 0.35
const WAIT_STRAFE := 0.6
const WAIT_RADIAL := 0.35
const JUMP_SHARP := 0.8
const JUMP_ERR := 0.44
const JUMP_ERR_SLOPE := 0.28
const JUMP_MISS_LIN := 0.54
const JUMP_MISS_QUAD := 0.475
const JUMP_MISS_MAX := 0.52
const JUMP_LATE := 0.25
const JUMP_CLEAR := 0.95
const JUMP_RESERVE := 0.1
const SPRINT_MIN := 0.4
const SPRINT_KEEP := 0.15
const SPRINT_REACT := 0.35
const SLOP_BASE := 0.8
const SLOP_MAX := 1.0
const SLOP_KNEE := 1.3
const SLOP_KNEE_VALUE := 0.8
const KIT_LOW_HP := 0.5
const KIT_STAT_DEPTH := 2
const KIT_STAT_SLOP := 0.4

var f: BattleFighter
var think_scale := 1.0
var think := 0.0
var recover_t := 0.0
var punished := false
var tactic_on := true
var dodge_t := 0.0
var strafe := 1.0
var jump_threat := ""
var jump_at := 0.0
var jump_done := false
var sprint_want := false
var sprint_seen := false
var react_t := 0.0


func _init(fighter: BattleFighter) -> void:
	f = fighter


func _rng() -> RandomNumberGenerator:
	return f.arena.rng


func error_chance() -> float:
	if think_scale <= SLOP_BASE:
		return 0.0
	if think_scale <= SLOP_KNEE:
		var t := (think_scale - SLOP_BASE) / (SLOP_KNEE - SLOP_BASE)
		return SLOP_KNEE_VALUE * t * t * (3.0 - 2.0 * t)
	return lerpf(SLOP_KNEE_VALUE, SLOP_MAX, clampf((think_scale - SLOP_KNEE) / (1.6 - SLOP_KNEE), 0.0, 1.0))


func _jump_error() -> float:
	return maxf(JUMP_ERR + JUMP_ERR_SLOPE * (think_scale - JUMP_SHARP), 0.0)


func _jump_miss() -> float:
	var d := maxf(think_scale - JUMP_SHARP, 0.0)
	return minf(JUMP_MISS_MAX, JUMP_MISS_LIN * d + JUMP_MISS_QUAD * d * d)


func _tactic_ok() -> bool:
	return _rng().randf() >= minf(1.0, _jump_miss() * TACTIC_MISS_MULT)


func in_range(id: String, d: float) -> bool:
	var mv := Dex.move(id)
	match String(mv.get("kind", "")):
		"dash", "arc", "multi_arc", "whip":
			return d < float(mv.get("range", 2.0)) + 0.6
		"aoe_self", "debuff_aoe":
			return d < float(mv.get("radius", 3.0))
		"stream":
			return d < float(mv.get("range", 5.0))
		"self_buff", "clones":
			return true
		_:
			return d < float(mv.get("range", 10.0))


func reach() -> float:
	var r := 0.0
	for id in f.moves:
		var mv := Dex.move(id)
		if float(mv.get("power", 0)) <= 0.0:
			continue
		match String(mv.get("kind", "")):
			"dash", "arc", "multi_arc", "whip":
				r = maxf(r, float(mv.get("range", 2.0)) + 0.6)
			"aoe_self":
				r = maxf(r, float(mv.get("radius", 3.0)))
			_:
				r = maxf(r, minf(float(mv.get("range", 10.0)), 6.0))
	return r


func band() -> Vector2:
	var r := reach()
	if r <= 0.0:
		return Vector2(1.8, 3.0)
	var far := minf(r * 0.9, BAND_MAX)
	return Vector2(far * BAND_NEAR_RATIO, far)


func move_ready(d: float) -> bool:
	if f.moves.is_empty() or f.gcd_t > 0.0:
		return false
	for id in f.moves:
		if float(f.move_cd.get(id, 0.0)) <= 0.0 and in_range(id, d) and f.stamina >= Dex.fatigue(Dex.move(id)):
			return true
	return false


## Um passo de IA: devolve a direção desejada e ajusta f.sprinting; pode disparar golpes.
func step(dt: float) -> Vector3:
	f.sprinting = false
	var opp := f.opponent
	if not is_instance_valid(opp) or not opp.active():
		return Vector3.ZERO
	if recover_t > 0.0:
		recover_t -= dt
		think -= dt
		return Vector3.ZERO
	var to_o := f.flat_to(opp)
	var d := to_o.length()
	var dir := to_o / maxf(d, 0.001)
	if not f.moves.is_empty():
		var punish := _punish(d)
		if not punish:
			punished = false
		think -= dt
		var fire := think <= 0.0
		if punish and not punished and tactic_on:
			fire = true
			punished = true
		if fire and f.can_act():
			tactic_on = _tactic_ok()
			var used := _use_best_move(d)
			think = (_rng().randf_range(THINK_MIN, THINK_MAX) if used else THINK_RETRY) * think_scale
	if f.out_of_pp() and d > 1.4:
		return dir
	if _rng().randf() < 0.002:
		strafe *= -1.0
	var side_v := Vector3(-dir.z, 0.0, dir.x) * strafe
	var b := band()
	var r := reach()
	var low := float(f.hp) <= float(f.max_hp) * LOW_HP
	var kite := Vector2(b.x * 1.2, b.y * KITE_MULT) if low else b
	var slip := opp.root_t > 0.0 and d < b.y + 1.0
	var want: Vector3
	if slip:
		want = (side_v - dir * 0.4).normalized()
	elif d > kite.y:
		want = (dir + side_v * 0.3).normalized()
	elif d < kite.x:
		want = (-dir + side_v * 0.5).normalized() * (1.0 if low else 0.8)
	elif move_ready(d) and tactic_on:
		want = Vector3.ZERO
	elif tactic_on:
		var centre := (b.x + b.y) * 0.5
		var radial := dir * clampf((centre - d) / maxf(b.y - b.x, 0.1), -1.0, 1.0)
		want = (side_v * WAIT_STRAFE + radial * WAIT_RADIAL).normalized()
	else:
		want = side_v * 0.35
	want += f.arena.edge_push(f)
	if want.length() > 1.0:
		want = want.normalized()
	var closing := d > kite.y and (r <= MELEE_BAND or d > r + FAR_GAP)
	var reason := closing or slip or (low and d < b.y)
	var dodge := _dodge(dt, d, side_v)
	if dodge != Vector3.ZERO:
		f.sprinting = f.can_sprint(true)
		return dodge
	if _try_jump(dt, d):
		return want
	f.sprinting = _sprint(dt, reason) and f.can_sprint(want.length() > 0.1)
	return want


func _punish(d: float) -> bool:
	var opp := f.opponent
	if not f.can_act():
		return false
	var orec := opp.ai.recover_t if opp.ai and opp.controller == "ai" else 0.0
	if orec <= 0.0 and opp.gcd_t <= 0.0:
		return false
	return move_ready(d)


func _use_best_move(d: float) -> bool:
	if f.out_of_pp():
		if d < 2.2:
			return f.struggle()
		return false
	var avail: Array = f.moves.filter(func(id): return f.gcd_t <= 0.0 and float(f.move_cd.get(id, 0.0)) <= 0.0 \
			and in_range(id, d) and f.arena.moves.can_afford(f, id))
	if avail.is_empty():
		return false
	if _immune_only(avail) and _has_connecting_move():
		return false
	if f.arena.moves.use(f, pick(avail)):
		recover_t = RECOVER
		return true
	return false


func _dmg(id: String) -> float:
	return f.arena.moves.expected_damage(f, f.opponent, Dex.move(id))


func _immune_only(avail: Array) -> bool:
	for id in avail:
		if float(Dex.move(id).get("power", 0)) <= 0.0 or _dmg(id) > 0.0:
			return false
	return true


func _has_connecting_move() -> bool:
	for id in f.moves:
		if float(Dex.move(id).get("power", 0)) > 0.0 and _dmg(id) > 0.0:
			return true
	return false


func pick(avail: Array) -> String:
	var dmg := {}
	for id in avail:
		if float(Dex.move(id).get("power", 0)) > 0.0:
			dmg[id] = _dmg(id)
	var usable: Array = avail.filter(func(id): return not dmg.has(id) or dmg[id] > 0.0)
	var pool: Array = usable if not usable.is_empty() else avail
	var best := best_move(pool, dmg)
	if best != "" and dmg.get(best, 0.0) >= float(f.opponent.hp):
		return best
	var rng := _rng()
	if rng.randf() < error_chance():
		return String(pool[rng.randi() % pool.size()])
	var has_hit := dmg.values().any(func(v): return v > 0.0)
	var kit: Array = pool.filter(func(id): return _worth_status(id, has_hit))
	if not kit.is_empty():
		return String(kit[rng.randi() % kit.size()])
	return best if best != "" else String(pool[rng.randi() % pool.size()])


## Golpe com menos acertos até o KO; empate vai para o de maior dano.
func best_move(pool: Array, dmg: Dictionary) -> String:
	var best := ""
	var best_turns := INF
	var best_dmg := 0.0
	var hp := maxf(float(f.opponent.hp), 1.0)
	for id in pool:
		var d: float = dmg.get(id, 0.0)
		if d <= 0.0:
			continue
		var turns := ceilf(hp / d)
		if turns < best_turns or (turns == best_turns and d > best_dmg):
			best = id
			best_turns = turns
			best_dmg = d
	return best


func _worth_status(id: String, has_damage: bool) -> bool:
	var mv := Dex.move(id)
	if float(mv.get("power", 0)) > 0.0:
		return false
	if float(f.hp) / maxf(f.max_hp, 1) < KIT_LOW_HP:
		return false
	var stack_ok := not has_damage or error_chance() >= KIT_STAT_SLOP
	var opp := f.opponent
	match String(mv.get("kind", "")):
		"self_buff":
			var st := String(mv.get("stat", ""))
			var delta := int(mv.get("stages", 1))
			var cur := f.crit_stage if st == "crit" else int(f.stages.get(st, 0))
			if st == "evasion":
				return f.evasion_t <= 0.0
			var moved := cur * signi(delta)
			return delta != 0 and (moved <= 0 or stack_ok) and moved < KIT_STAT_DEPTH
		"debuff_aoe":
			var cur2 := int(opp.stages.get(String(mv.get("stat", "")), 0))
			return (cur2 >= 0 or stack_ok) and cur2 > -KIT_STAT_DEPTH
		"clones":
			return f.evasion_t <= 0.0
	var ef = mv.get("effect")
	if ef is Dictionary and ef.has("status"):
		var st2 := String(ef.status)
		if st2 == "confusion":
			return opp.confusion_t <= 0.0
		return opp.status == "" and not BattleMoves.STATUS_IMMUNE.get(st2, "-") in opp.types
	if ef is Dictionary and ef.has("stat"):
		var cur3 := int(opp.stages.get(String(ef.stat), 0))
		return (cur3 >= 0 or stack_ok) and cur3 > -KIT_STAT_DEPTH
	return false


# --- Esquiva ---

func _aimed_at_me(dir: Vector3) -> bool:
	var to_me := f.position - f.opponent.position
	to_me.y = 0.0
	if to_me.length() < 0.01:
		return true
	return to_me.normalized().dot(Vector3(dir.x, 0.0, dir.z).normalized()) > 0.6


func _incoming_body_attack(d: float) -> Vector3:
	var o := f.opponent
	if o.dash_t > 0.0 and d - BattleFighter.HIT_RANGE <= float(o.dash_move.get("range", 0.0)):
		return o.dash_dir if _aimed_at_me(o.dash_dir) else Vector3.ZERO
	if o.lunge_t > 0.0 and d - BattleFighter.HIT_RANGE <= BattleFighter.LUNGE_SPEED * BattleFighter.LUNGE_TIME:
		return o.lunge_dir if _aimed_at_me(o.lunge_dir) else Vector3.ZERO
	return Vector3.ZERO


func _can_clear(att: BattleFighter) -> bool:
	return f.jump_height * JUMP_CLEAR >= att.dash_reach()


func _dodge(dt: float, d: float, side_v: Vector3) -> Vector3:
	var incoming := _incoming_body_attack(d) != Vector3.ZERO and not _can_clear(f.opponent)
	if not incoming or not f.can_act():
		dodge_t = 0.0
		return Vector3.ZERO
	if dodge_t <= 0.0:
		if not tactic_on:
			return Vector3.ZERO
		dodge_t = DODGE_TIME
	dodge_t -= dt
	return side_v.normalized()


func _jump_threat(d: float) -> String:
	if not f.can_act() or f.jump_height <= 0.0:
		return ""
	var o := f.opponent
	var sig := "@%d" % o.cast_n
	var mv := o.cast_move
	if o.root_t > 0.0 and String(mv.get("kind", "")) == "aoe_self" and String(mv.get("type", "")) == "ground" \
			and d <= float(mv.get("radius", 0.0)):
		return "quake" + sig
	if _incoming_body_attack(d) != Vector3.ZERO and _can_clear(o):
		return "dash" + sig
	return ""


func _jump_lead(threat: String, d: float) -> float:
	var o := f.opponent
	if threat.begins_with("quake"):
		return maxf(o.root_t - 0.1, 0.0)
	if o.dash_t > 0.0:
		return maxf((d - BattleFighter.HIT_RANGE) / maxf(o.dash_speed, 1.0), 0.0)
	return maxf((d - BattleFighter.HIT_RANGE) / BattleFighter.LUNGE_SPEED, 0.0)


func _try_jump(dt: float, d: float) -> bool:
	var threat := _jump_threat(d)
	if threat == "":
		jump_threat = ""
		jump_done = false
		return false
	var rng := _rng()
	if threat != jump_threat:
		jump_threat = threat
		jump_done = false
		var window := f.jump_time
		var err := rng.randf_range(-1.0, 1.0) * _jump_error() * window
		jump_at = maxf(_jump_lead(threat, d) - window * 0.5 + err, 0.0)
		if rng.randf() < _jump_miss():
			jump_at += JUMP_LATE + _jump_error() * window
	if jump_done or f.air_t > 0.0 or f.land_t > 0.0 or f.dash_t > 0.0 or f.lunge_t > 0.0:
		return false
	jump_at -= dt
	if jump_at > 0.0 or f.stamina < f.pp_max * (BattleFighter.JUMP_STAMINA + JUMP_RESERVE):
		return false
	if f.start_jump():
		jump_done = true
		return true
	return false


func _sprint(dt: float, reason: bool) -> bool:
	var pool := f.stamina / maxf(f.pp_max, 0.001)
	if sprint_want and not (reason and pool > SPRINT_KEEP):
		sprint_want = false
	if not reason or pool <= 0.0:
		sprint_seen = false
		return false
	if sprint_want:
		return true
	if pool < SPRINT_MIN:
		return false
	if not sprint_seen:
		sprint_seen = true
		react_t = SPRINT_REACT * maxf(think_scale, 0.05)
	react_t -= dt
	if react_t > 0.0:
		return false
	react_t = SPRINT_REACT * maxf(think_scale, 0.05)
	sprint_want = true
	return true
