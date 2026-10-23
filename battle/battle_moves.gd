class_name BattleMoves
extends RefCounted
## Uso e entrega dos golpes (por `kind`), acerto geométrico, dano e efeitos secundários.

const MISSABLE := ["dash", "arc", "multi_arc", "whip", "projectile", "beam", "aoe_target", "zone"]
const STATUS_IMMUNE := {"burn": "fire", "poison": "poison", "paralysis": "electric", "leech": "grass"}
const STAT_NAMES := {"atk": "Ataque", "def": "Defesa", "spa": "At. Esp.", "spd": "Def. Esp.", "spe": "Velocidade", "acc": "Precisão"}
const STATUS_WORDS := {"burn": "QUEIMADO!", "poison": "ENVENENADO!", "paralysis": "PARALISADO!", "sleep": "DORMINDO!",
	"leech": "SEMEADO!", "flinch": "HESITOU!", "confusion": "CONFUSO!"}
const PARALYSIS_FAIL := 0.2
const CONFUSION_CHANCE := 0.33
const AI_ROLL_MEAN := 0.925

var arena: Node
var rng: RandomNumberGenerator


func _init(a: Node, r: RandomNumberGenerator) -> void:
	arena = a
	rng = r


func can_afford(user: BattleFighter, id: String, careful := true) -> bool:
	var mv := Dex.move(id)
	if mv.is_empty() or user.pp_max < Dex.pp_cost(mv):
		return false
	return not careful or user.stamina >= Dex.fatigue(mv) or rng.randf() < 0.1


## Checa, debita PP/stamina, aplica cooldowns e solta (ou prepara) o golpe. Falso se não saiu.
func use(user: BattleFighter, id: String, feedback := false) -> bool:
	var mv := Dex.move(id)
	if mv.is_empty() or not user.can_act():
		return false
	if float(user.move_cd.get(id, 0.0)) > 0.0 or user.gcd_t > 0.0 or user.root_t > 0.0 or user.dash_t > 0.0 \
			or user.lunge_t > 0.0 or not user.may_start(mv):
		return false
	var cost := Dex.pp_cost(mv)
	if user.pp_max < cost:
		if feedback:
			user.popup("PP insuficiente!", Color(1, 0.6, 0.4))
		return false
	var exhausted := user.spend(cost, Dex.fatigue(mv))
	var sf := user.speed_factor()
	user.move_cd[id] = Dex.cooldown(mv) / sf
	user.gcd_t = Dex.GLOBAL_COOLDOWN / sf
	if user.status == "paralysis" and rng.randf() < PARALYSIS_FAIL:
		user.popup("Paralisado!", Dex.type_color("electric"))
		return true
	var prepare := Dex.prepare_time(mv)
	if exhausted:
		_stagger_after(user, mv, prepare)
	if prepare <= 0.0:
		deliver(user, mv)
	else:
		user.begin_prepare(id, prepare, deliver.bind(user, mv))
	return true


func _stagger_after(user: BattleFighter, mv: Dictionary, prepare: float) -> void:
	var delay := prepare + float(mv.get("windup", 0.0)) + float(mv.get("duration", 0.0)) + 0.25
	if mv.get("kind", "") == "dash":
		delay = prepare + float(mv.get("range", 3.0)) / float(mv.get("speed", 12.0)) + 0.1
	arena.later(delay, func() -> void:
		if is_instance_valid(user) and user.alive():
			user.stagger())


func acc_mult(stage: int) -> float:
	return (3.0 + stage) / 3.0 if stage >= 0 else 3.0 / (3.0 - stage)


func hit_chance(user: BattleFighter, mv: Dictionary) -> float:
	var acc := float(mv.get("accuracy", 0.0))
	if acc <= 0.0 or not String(mv.get("kind", "")) in MISSABLE:
		return 1.0
	return clampf(acc * acc_mult(int(user.stages.get("acc", 0))) / 100.0, 0.0, 1.0)


func targets_of(user: BattleFighter) -> Array:
	return arena.targets_of(user)


func deliver(user: BattleFighter, mv: Dictionary) -> void:
	if not is_instance_valid(user) or not user.alive():
		return
	var dir := user.aim_dir()
	var aimed: BattleFighter = user.opponent if is_instance_valid(user.opponent) and user.opponent.active() else null
	var miss: BattleFighter = null
	var kind := String(mv.get("kind", ""))
	var acc := float(mv.get("accuracy", 0.0))
	var eff_acc := acc * acc_mult(int(user.stages.get("acc", 0)))
	if aimed and acc > 0.0 and kind in MISSABLE and eff_acc < 100.0 and rng.randf() * 100.0 >= eff_acc:
		miss = aimed
		if kind != "multi_arc":
			dir = _miss_dir(user, aimed, mv, dir)
		_announce_miss(user, aimed, mv)
	if user.confusion_t > 0.0 and rng.randf() < CONFUSION_CHANCE:
		user.popup("Está confuso!", Dex.type_color("psychic"))
		dir = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
	user.facing = dir
	user.popup(String(mv.get("name", mv.get("id", "?"))), Dex.type_color(String(mv.get("type", "normal"))), 1.0, 0.75)
	if kind == "arc" or kind == "multi_arc":
		user.start_arc_step(dir)
	if mv.has("magnitude"):
		var roll := _roll_magnitude(mv.magnitude)
		mv = mv.duplicate()
		mv.power = int(roll[1])
		user.popup("Magnitude %d" % int(roll[0]), Dex.type_color(String(mv.type)), 1.0, 1.0)
	user.cast_move = mv
	user.cast_n += 1
	match kind:
		"dash":
			user.start_dash(mv, dir, miss)
		"arc":
			_arc(user, mv, dir, miss)
		"multi_arc":
			_multi_arc(user, mv, miss, 0)
		"whip":
			_whip(user, mv, dir, miss)
		"projectile":
			_projectiles(user, mv, dir, mv.has("drain"), miss)
		"homing":
			_projectiles(user, mv, dir, true, null)
		"stream":
			_stream(user, mv, dir)
		"beam":
			_beam(user, mv, dir, miss)
		"aoe_self":
			_aoe_self(user, mv)
		"aoe_target":
			_aoe_target(user, mv, dir, miss)
		"zone":
			_zone(user, mv, dir, miss)
		"self_buff":
			_self_buff(user, mv)
		"debuff_aoe":
			_debuff(user, mv)
		"clones":
			user.evasion_t = float(mv.get("duration", 5.0))
			user.evasion = float(mv.get("evasion", 0.4))
			user.popup("EVASÃO+!", Color(0.95, 0.6, 0.9))
		_:
			_arc(user, mv, dir, miss)


func _miss_dir(user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3) -> Vector3:
	var dist := maxf(user.flat_to(target).length(), 0.5)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var deg := 0.0
	match String(mv.get("kind", "")):
		"arc", "multi_arc", "whip":
			deg = float(mv.get("angle", 90)) / 2.0 + 25.0
		"projectile":
			deg = float(mv.get("spread", 0)) / 2.0 + rad_to_deg(atan2(1.4, dist)) + 6.0
		"beam":
			deg = rad_to_deg(atan2(float(mv.get("width", 0.8)) / 2.0 + 1.1, dist)) + 4.0
		_:
			deg = rad_to_deg(atan2(1.4, dist)) + 6.0
	return dir.rotated(Vector3.UP, side * deg_to_rad(minf(deg, 80.0)))


func _announce_miss(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> void:
	var delay := 0.15
	var dist := user.flat_to(target).length()
	match String(mv.get("kind", "")):
		"projectile":
			delay = dist / float(mv.get("speed", 12.0))
		"dash":
			delay = minf(dist, float(mv.get("range", 3.0))) / float(mv.get("speed", 12.0))
		"beam", "aoe_target":
			delay = float(mv.get("windup", 0.6)) + 0.1
	arena.later(delay, func() -> void:
		if is_instance_valid(target) and target.active():
			target.popup("Errou!", Color(0.75, 0.85, 1.0)))


func _roll_magnitude(table: Array) -> Array:
	var total := 0.0
	for row in table:
		total += float(row[2])
	var r := rng.randf() * total
	for row in table:
		r -= float(row[2])
		if r <= 0.0:
			return row
	return table[-1]


# --- Dano esperado (IA) ---

func expected_damage(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if not is_instance_valid(target) or not target.alive():
		return 0.0
	var power := float(mv.get("power", 0.0))
	if power <= 0.0:
		return 0.0
	var eff := Dex.effectiveness(String(mv.get("type", "")), target.types)
	if eff <= 0.0:
		return 0.0
	var kind := String(mv.get("kind", ""))
	if kind == "dash" and target.is_airborne():
		var lift := user.jump_height if user.jump_height > 0.0 else 0.0
		if target.air_h - lift >= user.dash_reach():
			return 0.0
	if kind in ["aoe_self", "aoe_target"] and String(mv.get("type", "")) == "ground" and target.is_airborne():
		return 0.0
	var physical: bool = mv.get("category", "") == "physical"
	var a := user.stat("atk" if physical else "spa")
	if physical and user.status == "burn":
		a *= Damage.BURN_ATK_MULT
	var d := target.stat("def" if physical else "spd")
	var hits := float(mv.get("hits", mv.get("count", 1)))
	var base := ((2.0 * float(user.level) / 5.0 + 2.0) * power * a / maxf(d, 1.0)) / 50.0 + 2.0
	var stab := 1.5 if mv.get("type") in user.types else 1.0
	var score := base * hits * stab * eff * AI_ROLL_MEAN * hit_chance(user, mv)
	if bool(mv.get("self_destruct", false)):
		score *= clampf(1.0 - float(user.hp) / maxf(float(user.max_hp), 1.0), 0.0, 1.0)
	return score


# --- Acerto ---

func hit(user: BattleFighter, target: BattleFighter, mv: Dictionary, dir: Vector3, power_scale := 1.0, final := true) -> void:
	if not is_instance_valid(target) or not target.active() or not is_instance_valid(user):
		return
	if target.evasion_t > 0.0 and rng.randf() < target.evasion:
		target.popup("Errou!", Color(0.9, 0.9, 1.0))
		return
	var power := float(mv.get("power", 0)) * power_scale
	if power > 0.0:
		var m := mv
		if power_scale != 1.0:
			m = mv.duplicate()
			m.power = power
		var res := Damage.compute(user.damage_profile(), target.damage_profile(), m, rng)
		var eff := float(res.eff)
		if eff == 0.0:
			target.popup("Sem efeito...", Color(0.7, 0.7, 0.7))
			return
		var dmg := int(res.damage)
		var hp_before := target.hp
		target.last_hit_by = user
		target.take_damage(dmg, dir, float(mv.get("knockback", 4.0)),
				{"source": user, "crit": res.crit, "eff": eff, "final": final})
		if mv.has("drain") and user.alive():
			user.heal(maxi(1, int(float(dmg) * float(mv.drain))))
		var col := Color(1, 0.75, 0.15) if eff > 1.0 else (Color(0.55, 0.58, 0.66) if eff < 1.0 else Color(0.95, 0.3, 0.25))
		target.popup(str(dmg), col, 1.5 if res.crit else 1.0, 0.35)
		preload("res://audio/cue.gd").sfx("crit" if res.crit else ("hit_super" if eff > 1.0 else ("hit_weak" if eff < 1.0 else "hit")))
		if res.crit:
			target.popup("CRÍTICO!", Color(1, 0.55, 0.3), 1.0, 0.6)
		if eff > 1.0:
			target.popup("SUPEREFETIVO!", Color(1, 0.8, 0.2), 1.0, 0.85)
		elif eff < 1.0:
			target.popup("Pouco efetivo", Color(0.7, 0.7, 0.8), 1.0, 0.85)
		arena.note_hit(user, target, mv, dmg, hp_before)
	var ef = mv.get("effect")
	if ef is Dictionary and target.alive() and rng.randf() < float(ef.get("chance", 0.0)):
		if ef.has("stat"):
			change_stage(user if ef.get("self", false) else target, String(ef.stat), int(ef.stages))
		else:
			var st := String(ef.status)
			if STATUS_IMMUNE.get(st, "-") in target.types:
				target.popup("Imune a %s" % st, Color(0.8, 0.8, 0.8))
			elif target.apply_status(st, user):
				target.popup(String(STATUS_WORDS.get(st, st.to_upper() + "!")), Color(1, 0.9, 0.6))


func change_stage(c: BattleFighter, k: String, delta: int) -> void:
	if delta == 0 or not is_instance_valid(c):
		return
	var cur := int(c.stages.get(k, 0))
	var nv := clampi(cur + delta, -6, 6)
	var name := String(STAT_NAMES.get(k, k))
	if nv == cur:
		c.popup("%s não %s mais!" % [name, "sobe" if delta > 0 else "desce"], Color(0.8, 0.8, 0.8))
		return
	c.stages[k] = nv
	var word := ("subiu" if absi(delta) == 1 else "subiu muito") if delta > 0 else ("caiu" if absi(delta) == 1 else "caiu muito")
	c.popup("%s %s!" % [name, word], Color(0.6, 0.9, 1.0) if delta > 0 else Color(1.0, 0.6, 0.6))


# --- Entregas ---

func in_cone(user: BattleFighter, t: BattleFighter, dir: Vector3, r: float, half: float) -> bool:
	var to := user.flat_to(t)
	var d := to.length()
	if d > r + 0.4:
		return false
	return d < 0.6 or dir.angle_to(to / d) <= half


func _arc(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter, final := true) -> void:
	var r := float(mv.get("range", 1.8))
	var half := deg_to_rad(float(mv.get("angle", 90))) / 2.0
	arena.fx_cone(user.position + Vector3(0, user.look_h * 0.4, 0), dir, r, half, Dex.type_color(String(mv.type)), 0.15)
	for t in targets_of(user):
		if t != miss and in_cone(user, t, dir, r, half):
			var to := user.flat_to(t)
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else dir, 1.0, final)


func _multi_arc(user: BattleFighter, mv: Dictionary, miss: BattleFighter, i: int) -> void:
	var hits := int(mv.get("hits", 3))
	if i >= hits or not is_instance_valid(user) or not user.can_act():
		return
	var d := user.aim_dir()
	if is_instance_valid(miss):
		d = _miss_dir(user, miss, mv, d)
	_arc(user, mv, d, miss, i == hits - 1)
	arena.later(float(mv.get("interval", 0.2)), _multi_arc.bind(user, mv, miss, i + 1))


func _whip(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	var reach := float(mv.get("range", 3.5))
	var tips := int(mv.get("tips", 1))
	var tip_r := float(mv.get("tip_radius", 0.6))
	var spread := float(mv.get("spread", 0.0))
	var already := {}
	for i in tips:
		var tipdir := dir.rotated(Vector3.UP, deg_to_rad(spread * (i - (tips - 1) / 2.0)))
		var stop := reach
		var victim: BattleFighter = null
		for t in targets_of(user):
			if t == miss or already.has(t.get_instance_id()):
				continue
			var to_t := user.flat_to(t)
			var ahead := to_t.dot(tipdir)
			if ahead < 0.0:
				continue
			var along := minf(ahead, reach)
			if (to_t - tipdir * along).length() > tip_r:
				continue
			if victim == null or along < stop:
				stop = along
				victim = t
		arena.fx_beam(user.position + Vector3(0, user.look_h * 0.4, 0), tipdir, stop, 0.08, Dex.type_color(String(mv.type)), 0.2)
		if victim != null:
			already[victim.get_instance_id()] = true
			var to := user.flat_to(victim)
			hit(user, victim, mv, to.normalized() if to.length() > 0.01 else dir)


func _projectiles(user: BattleFighter, mv: Dictionary, dir: Vector3, homing: bool, miss: BattleFighter, i := 0) -> void:
	var n := int(mv.get("count", 1))
	if i >= n or not is_instance_valid(user) or not user.alive():
		return
	var spread := deg_to_rad(float(mv.get("spread", 0.0)))
	var d := dir
	if homing and not mv.has("drain"):
		d = dir.rotated(Vector3.UP, rng.randf_range(-1.3, 1.3))
	elif n > 1:
		d = dir.rotated(Vector3.UP, lerpf(-spread / 2.0, spread / 2.0, float(i) / (n - 1)))
	var target: BattleFighter = user.opponent if is_instance_valid(user.opponent) else null
	arena.spawn_projectile(user, mv, d, homing, miss, target)
	if homing:
		arena.later(0.08, _projectiles.bind(user, mv, dir, homing, miss, i + 1))
	else:
		_projectiles(user, mv, dir, homing, miss, i + 1)


func _stream(user: BattleFighter, mv: Dictionary, dir: Vector3) -> void:
	var dur := float(mv.get("duration", 1.0))
	var tick := float(mv.get("tick", 0.15))
	var r := float(mv.get("range", 5.0))
	var half := deg_to_rad(float(mv.get("angle", 35))) / 2.0
	user.root_t = maxf(user.root_t, dur)
	var lock: BattleFighter = null
	var best := -2.0
	for t in targets_of(user):
		if in_cone(user, t, dir, r, half):
			var dt := dir.dot(user.flat_to(t).normalized())
			if dt > best:
				best = dt
				lock = t
	var state := {"dir": dir, "hit": {}, "left": int(ceil(dur / tick))}
	_stream_tick(user, mv, lock, state, r, half, tick)


func _stream_tick(user: BattleFighter, mv: Dictionary, lock: BattleFighter, state: Dictionary, r: float, half: float, tick: float) -> void:
	if state.left <= 0 or not is_instance_valid(user) or not user.can_act():
		return
	state.left -= 1
	if user.confusion_t <= 0.0 and is_instance_valid(lock) and lock.active():
		var to := user.flat_to(lock)
		if to.length() > 0.01:
			state.dir = to.normalized()
	var dir: Vector3 = state.dir
	user.facing = dir
	arena.fx_cone(user.position + Vector3(0, user.look_h * 0.5, 0), dir, r, half, Dex.type_color(String(mv.type)), tick)
	for t in targets_of(user):
		if mv.get("once", false) and state.hit.has(t.get_instance_id()):
			continue
		if in_cone(user, t, dir, r, half):
			state.hit[t.get_instance_id()] = true
			var to := user.flat_to(t)
			hit(user, t, mv, to.normalized() if to.length() > 0.01 else dir, 1.0, state.left == 0)
	arena.later(tick, _stream_tick.bind(user, mv, lock, state, r, half, tick))


func _beam(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	var windup := float(mv.get("windup", 0.6))
	var r := float(mv.get("range", 14.0))
	var w := float(mv.get("width", 0.8))
	user.root_t = maxf(user.root_t, windup + 0.25 + float(mv.get("root", 1.0)))
	var col := Dex.type_color(String(mv.type))
	arena.fx_beam(user.position + Vector3(0, 0.05, 0), dir, r, w, col * Color(1, 1, 1, 0.35), windup)
	arena.later(windup, func() -> void:
		if not is_instance_valid(user) or not user.alive():
			return
		arena.fx_beam(user.position + Vector3(0, user.look_h * 0.5, 0), dir, r, w, col, 0.25)
		for t in targets_of(user):
			if t == miss:
				continue
			var to := user.flat_to(t)
			var along := to.dot(dir)
			if along > -0.5 and along < r and (to - dir * along).length() < w / 2.0 + 0.5:
				hit(user, t, mv, dir))


func _ground_immune(mv: Dictionary, t: BattleFighter) -> bool:
	return String(mv.get("type", "")) == "ground" and t.is_airborne()


func _aoe_self(user: BattleFighter, mv: Dictionary) -> void:
	var windup := float(mv.get("windup", 0.4))
	var radius := float(mv.get("radius", 4.0))
	user.root_t = maxf(user.root_t, windup + 0.1)
	var col := Dex.type_color(String(mv.type))
	arena.fx_disc(user.position, radius, col * Color(1, 1, 1, 0.3), windup)
	arena.later(windup, func() -> void:
		if not is_instance_valid(user) or not user.alive():
			return
		arena.fx_disc(user.position, radius, col, 0.25)
		for t in targets_of(user):
			var to := user.flat_to(t)
			if to.length() <= radius and not _ground_immune(mv, t):
				hit(user, t, mv, to.normalized() if to.length() > 0.01 else user.facing)
		if mv.get("self_destruct", false):
			arena.later(0.3, func() -> void:
				if is_instance_valid(user) and user.alive():
					user.take_damage(user.hp, Vector3.ZERO, 0.0)))


func _area_point(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> Vector3:
	var rng_m := float(mv.get("range", 8.0))
	var radius := float(mv.get("radius", 2.0))
	var at := user.pos2(user.position) + dir * rng_m * 0.6
	var t: BattleFighter = user.opponent
	if is_instance_valid(t) and t.active() and user.flat_to(t).length() <= rng_m:
		at = user.pos2(t.position)
	if miss != null:
		var side := dir.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
		at += side * (radius + rng.randf_range(0.9, 1.5))
	return at


func _aoe_target(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	var windup := float(mv.get("windup", 1.0))
	var radius := float(mv.get("radius", 2.0))
	var at := _area_point(user, mv, dir, miss)
	var col := Dex.type_color(String(mv.type))
	arena.fx_disc(at, radius, col * Color(1, 1, 1, 0.3), windup)
	arena.later(windup, func() -> void:
		if not is_instance_valid(user) or not user.alive():
			return
		arena.fx_disc(at, radius, col, 0.25)
		for t in targets_of(user):
			if t == miss or _ground_immune(mv, t):
				continue
			var to: Vector3 = t.pos2(t.position) - at
			if to.length() <= radius:
				hit(user, t, mv, to.normalized() if to.length() > 0.05 else dir)
				if mv.has("trap") and t.alive():
					t.trap_t = maxf(t.trap_t, float(mv.trap)))


func _zone(user: BattleFighter, mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	var at := _area_point(user, mv, dir, miss)
	var radius := float(mv.get("radius", 2.0))
	var dur := float(mv.get("duration", 4.0))
	var tick := float(mv.get("tick", 0.5))
	arena.fx_disc(at, radius, Dex.type_color(String(mv.type)) * Color(1, 1, 1, 0.45), dur)
	_zone_tick(user, mv, at, radius, tick, int(ceil(dur / tick)))


func _zone_tick(user: BattleFighter, mv: Dictionary, at: Vector3, radius: float, tick: float, left: int) -> void:
	if left <= 0 or not is_instance_valid(user) or not user.alive():
		return
	for t in targets_of(user):
		var to: Vector3 = t.pos2(t.position) - at
		if to.length() <= radius:
			hit(user, t, mv, Vector3.ZERO if to.length() < 0.05 else to.normalized(), 1.0, false)
	arena.later(tick, _zone_tick.bind(user, mv, at, radius, tick, left - 1))


func _self_buff(user: BattleFighter, mv: Dictionary) -> void:
	var st := String(mv.get("stat", ""))
	if st == "crit":
		var before := user.crit_stage
		user.crit_stage = mini(user.crit_stage + int(mv.get("stages", 1)), 4)
		user.popup("Está se concentrando!" if user.crit_stage != before else "Já está concentrado!", Color(1, 0.8, 0.4))
	elif st == "evasion":
		user.evasion_t = float(mv.get("duration", 5.0))
		user.evasion = float(mv.get("evasion", 0.4))
		user.popup("EVASÃO+!", Color(0.95, 0.6, 0.9))
	else:
		change_stage(user, st, int(mv.get("stages", 1)))


func _debuff(user: BattleFighter, mv: Dictionary) -> void:
	var radius := float(mv.get("radius", 6.0))
	arena.fx_disc(user.position, radius, Dex.type_color(String(mv.type)) * Color(1, 1, 1, 0.25), 0.3)
	for t in targets_of(user):
		if user.flat_to(t).length() <= radius:
			change_stage(t, String(mv.get("stat", "")), int(mv.get("stages", -1)))
