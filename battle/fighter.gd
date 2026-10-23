class_name BattleFighter
extends Node3D
## Lutador em tempo real: embrulha um Mon com HP, stamina/PP, cooldowns, estágios, status, pulo, dash e lunge.
## Toda a lógica roda em tick()/drive() chamados pela arena, então dá para simular sem tempo real.

signal fainted(f: BattleFighter)

const PP_REGEN := 0.2
const SPRINT_DRAIN := 0.3
const SPRINT_MULT := 1.6
const PLAYER_SPEED := 4.5
const AI_SPEED := 2.5 * 1.4
const JUMP_G := 23.8
const JUMP_HEIGHT_DEFAULT := 0.9
const JUMP_STAMINA := 0.15
const JUMP_LAND := 0.3
const STAGGER_TIME := 2.0
const PREPARE_STUN := 0.25
const KNOCKBACK_SCALE := 0.5
const KNOCK_DECAY := 30.0
const HIT_RANGE := 1.2
const DASH_REACH_FACTOR := 0.9
const ARC_STEP_M := 0.5
const ARC_STEP_TIME := 0.12
const LUNGE_SPEED := 10.0
const LUNGE_TIME := 0.2
const LUNGE_PREPARE := 0.15
const STRUGGLE_CD := 1.0
const STATUS_TIME := {"burn": 6.0, "poison": 6.0, "paralysis": 6.0, "sleep": 3.0, "leech": 6.0}
const CONFUSION_TIME := 4.0
const FLINCH_TIME := 0.5
const STAGE_KEYS := ["atk", "def", "spa", "spd", "spe", "acc"]
const STRUGGLE := {"id": "struggle", "name": "Struggle", "type": "none", "category": "physical",
	"kind": "lunge", "power": 50, "knockback": 5}
const STATUS_SHORT := {"burn": "BRN", "poison": "PSN", "paralysis": "PAR", "sleep": "SLP", "leech": "SEED"}

var arena: Node
var mon: Mon
var side := 0
var controller := "ai"
var ai: BattleAI
var opponent: BattleFighter
var last_hit_by: BattleFighter
var on_field := true
var trainer_item := ""
var item_used := false

var moves: Array = []
var types: Array = []
var level := 1
var stats := {}
var stages := {}
var crit_stage := 0
var hp := 1
var max_hp := 1
var pp_base := 100.0
var pp_max := 100.0
var stamina := 100.0

var move_cd := {}
var gcd_t := 0.0
var root_t := 0.0
var stun_t := 0.0
var stagger_t := 0.0
var trap_t := 0.0
var land_t := 0.0
var impact_t := 0.0
var evasion_t := 0.0
var evasion := 0.0
var confusion_t := 0.0
var status := ""
var status_t := 0.0
var status_tick := 0.0
var leech_source: BattleFighter

var prepare_t := 0.0
var prepare_id := ""
var prepare_cb := Callable()

var air_t := 0.0
var air_h := 0.0
var jump_height := JUMP_HEIGHT_DEFAULT
var jump_time := 0.0

var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 12.0
var dash_move := {}
var dash_miss: BattleFighter
var dash_hit := false
var dash_dodged := {}

var lunge_t := 0.0
var lunge_dir := Vector3.ZERO
var lunge_done := false
var struggle_cd := 0.0

var arc_step_t := 0.0
var arc_step_dir := Vector3.ZERO
var knock := Vector3.ZERO
var impact_knock := Vector3.ZERO
var velocity := Vector3.ZERO
var facing := Vector3.FORWARD
var sprinting := false

var cast_move := {}
var cast_n := 0
var look_h := 1.0

var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _base_color := Color.WHITE
var _flash_t := 0.0


func setup(m: Mon, s: int, ctrl: String) -> void:
	mon = m
	side = s
	controller = ctrl
	var sp := Dex.species(m.species)
	types = m.types
	level = m.level
	moves = m.moves.slice(0, 4)
	for k in StatCalc.STATS:
		stats[k] = m.stat(k)
	for k in STAGE_KEYS:
		stages[k] = 0
	max_hp = m.max_hp
	hp = clampi(m.hp, 0, max_hp)
	pp_base = m.pp_base
	pp_max = clampf(m.pp, 0.0, pp_base)
	stamina = pp_max
	jump_height = float(sp.get("jump_height_override", sp.get("jump_height", JUMP_HEIGHT_DEFAULT)))
	jump_time = sqrt(8.0 * jump_height / JUMP_G) if jump_height > 0.0 else 0.0
	look_h = clampf(float(sp.get("height_m", 1.0)) * 0.9, 0.45, 1.8)
	if m.status in Mon.PERSIST_STATUS:
		apply_status(m.status)
	ai = BattleAI.new(self)
	_build_visual()


func _build_visual() -> void:
	_base_color = Dex.type_color(String(types[0]))
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	var cap := CapsuleMesh.new()
	cap.radius = clampf(look_h * 0.32, 0.18, 0.5)
	cap.height = maxf(look_h, cap.radius * 2.0)
	cap.material = _mat
	_body = MeshInstance3D.new()
	_body.mesh = cap
	_body.position.y = cap.height * 0.5
	add_child(_body)
	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = cap.radius * 0.45
	nm.height = nm.radius * 2.0
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Dex.type_color(String(types[1])) if types.size() > 1 else Color.WHITE
	nm.material = nmat
	nose.mesh = nm
	_body.add_child(nose)
	nose.position = Vector3(0, cap.height * 0.2, -cap.radius)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = cap.radius + 0.12
	rm.outer_radius = cap.radius + 0.2
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(0.3, 0.6, 1.0) if side == 0 else Color(1.0, 0.3, 0.3)
	rm.material = rmat
	ring.mesh = rm
	ring.position.y = 0.03
	add_child(ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.position.y = cap.height + 0.45
	add_child(_label)
	refresh_label()


func refresh_label() -> void:
	if _label == null:
		return
	var st := String(STATUS_SHORT.get(status, ""))
	if stagger_t > 0.0:
		st = "TIRED"
	_label.text = "%s Lv%d%s\n%d/%d" % [mon.display_name, level, (" " + st) if st != "" else "", hp, max_hp]


func alive() -> bool:
	return hp > 0


func active() -> bool:
	return on_field and alive()


func head_pos(extra := 0.0) -> Vector3:
	return position + Vector3(0, look_h + extra, 0)


func pos2(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


func flat_to(t: Node3D) -> Vector3:
	var d := t.position - position
	d.y = 0.0
	return d


# --- Stats ---

func stat(k: String) -> float:
	return float(stats.get(k, 10)) * StatCalc.stage_mult(int(stages.get(k, 0)))


func crit_stat(k: String, attacking: bool) -> float:
	var st := int(stages.get(k, 0))
	st = maxi(st, 0) if attacking else mini(st, 0)
	return float(stats.get(k, 10)) * StatCalc.stage_mult(st)


## Dicionário no formato de Damage.compute (stats com estágios, burn à parte).
func damage_profile() -> Dictionary:
	var d := {"level": level, "types": types, "crit_stage": crit_stage, "burned": status == "burn", "terrain_mult": 1.0}
	for k in ["atk", "def", "spa", "spd"]:
		d[k] = stat(k)
	d["crit_atk"] = crit_stat("atk", true)
	d["crit_spa"] = crit_stat("spa", true)
	d["crit_def"] = crit_stat("def", false)
	d["crit_spd"] = crit_stat("spd", false)
	return d


func speed_factor() -> float:
	if is_instance_valid(opponent) and opponent.active():
		return StatCalc.battle_speed_factor(stat("spe"), opponent.stat("spe"))
	return 1.0


func can_act() -> bool:
	return alive() and stun_t <= 0.0 and stagger_t <= 0.0 and impact_t <= 0.0 and status != "sleep"


func is_airborne() -> bool:
	return air_t > 0.0


func may_start(mv: Dictionary) -> bool:
	return not is_airborne() or bool(mv.get("allowed_midair", true))


func min_move_cost() -> float:
	var best := INF
	for id in moves:
		var mv := Dex.move(id)
		if not mv.is_empty():
			best = minf(best, Dex.pp_cost(mv))
	return best if best < INF else 1.0


func out_of_pp() -> bool:
	return pp_max < min_move_cost()


func dash_reach() -> float:
	return look_h * DASH_REACH_FACTOR


## Dash/lunge passa por baixo de um alvo alto o bastante no ar.
func passes_under(t: BattleFighter) -> bool:
	return t.is_airborne() and (t.air_h - air_h) >= dash_reach()


func aim_dir() -> Vector3:
	if is_instance_valid(opponent) and opponent.active():
		var d := flat_to(opponent)
		if d.length() > 0.01:
			return d.normalized()
	return facing


# --- Recursos ---

func spend(cost: float, tired: float) -> bool:
	pp_max -= cost
	stamina = minf(stamina - tired, pp_max)
	mon.pp = pp_max
	return stamina < 0.0


func stagger() -> void:
	stagger_t = STAGGER_TIME
	stamina = 0.0
	sprinting = false
	popup("Exausto!", Color(1, 0.75, 0.35))
	refresh_label()


func can_jump() -> bool:
	return jump_height > 0.0 and root_t <= 0.0 and can_act() and trap_t <= 0.0 and stamina > 0.0 \
			and air_t <= 0.0 and land_t <= 0.0 and dash_t <= 0.0 and lunge_t <= 0.0


func start_jump() -> bool:
	if not can_jump():
		return false
	air_t = jump_time
	air_h = 0.0
	stamina = maxf(stamina - pp_max * JUMP_STAMINA, 0.0)
	return true


func can_sprint(moving: bool) -> bool:
	return moving and can_act() and root_t <= 0.0 and trap_t <= 0.0 and stamina > 0.0


# --- Preparação (windup enraizado antes de soltar o golpe) ---

func begin_prepare(id: String, secs: float, cb: Callable) -> void:
	prepare_id = id
	prepare_t = secs
	prepare_cb = cb
	root_t = maxf(root_t, secs)


func clear_prepare() -> void:
	prepare_t = 0.0
	prepare_id = ""
	prepare_cb = Callable()


func interrupt_prepare() -> void:
	if not prepare_cb.is_valid():
		return
	var id := prepare_id
	clear_prepare()
	root_t = 0.0
	stun_t = maxf(stun_t, PREPARE_STUN)
	if id != "":
		move_cd[id] = minf(float(move_cd.get(id, 0.0)), gcd_t)
	popup("Interrompido!", Color(0.9, 0.9, 0.9), 0.8)


func start_dash(mv: Dictionary, dir: Vector3, miss: BattleFighter) -> void:
	dash_move = mv
	dash_miss = miss
	dash_dir = dir
	dash_speed = float(mv.get("speed", 12.0))
	dash_t = float(mv.get("range", 3.0)) / dash_speed
	dash_hit = false
	dash_dodged.clear()
	facing = dir


func start_arc_step(dir: Vector3) -> void:
	if air_t > 0.0 or dash_t > 0.0 or lunge_t > 0.0:
		return
	if is_instance_valid(opponent) and flat_to(opponent).length() <= HIT_RANGE:
		return
	arc_step_dir = dir
	arc_step_t = ARC_STEP_TIME


## Sem PP: lunge com recuo de max_hp/4.
func struggle() -> bool:
	if struggle_cd > 0.0 or lunge_t > 0.0 or gcd_t > 0.0 or root_t > 0.0 or not can_act() or not may_start(STRUGGLE):
		return false
	struggle_cd = STRUGGLE_CD
	gcd_t = Dex.GLOBAL_COOLDOWN / speed_factor()
	var dir := aim_dir()
	popup("Desespero", Color(0.9, 0.9, 0.9), 1.0, 0.9)
	begin_prepare("", LUNGE_PREPARE, func() -> void:
		lunge_dir = dir
		lunge_t = LUNGE_TIME
		lunge_done = false)
	return true


# --- Status ---

func apply_status(s: String, source: BattleFighter = null) -> bool:
	if not alive():
		return false
	if s == "flinch":
		stun_t = maxf(stun_t, FLINCH_TIME)
		return true
	if s == "confusion":
		if confusion_t > 0.0:
			return false
		confusion_t = CONFUSION_TIME
		return true
	if status != "":
		return false
	status = s
	status_t = float(STATUS_TIME.get(s, 4.0))
	status_tick = 1.0
	if s == "leech":
		leech_source = source
	if s in Mon.PERSIST_STATUS:
		mon.status = s
	refresh_label()
	return true


func clear_status() -> void:
	status = ""
	status_t = 0.0
	leech_source = null
	mon.status = ""
	refresh_label()


func _tick_status(dt: float) -> void:
	if status == "":
		return
	status_t -= dt
	status_tick -= dt
	if status_tick <= 0.0:
		status_tick += 1.0
		match status:
			"burn":
				_dot(maxi(1, int(max_hp / 16.0)), "burn", Dex.type_color("fire"))
			"poison":
				_dot(maxi(1, int(max_hp / 12.0)), "poison", Dex.type_color("poison"))
			"leech":
				var d := maxi(1, int(max_hp / 16.0))
				_dot(d, "leech", Dex.type_color("grass"))
				if is_instance_valid(leech_source) and leech_source.alive():
					leech_source.heal(d)
	if status_t <= 0.0 and alive():
		clear_status()


func _dot(amount: int, why: String, col: Color) -> void:
	popup("-%d %s" % [amount, why], col, 0.8)
	take_damage(amount, Vector3.ZERO, 0.0)


func heal(n: int) -> void:
	if not alive():
		return
	hp = mini(hp + n, max_hp)
	mon.hp = hp
	refresh_label()


# --- Dano ---

static func impact_secs(hp_pct: float, crit: bool, eff: float, ko: bool, final_hit: bool) -> float:
	if not final_hit:
		return 0.05
	if ko:
		return 0.3
	if crit or eff > 1.0:
		return 0.22
	if hp_pct < 0.05:
		return 0.0
	return lerpf(0.08, 0.15, clampf((hp_pct - 0.05) / 0.45, 0.0, 1.0))


## Aplica dano; devolve o hit-stop aplicado. dir zero = DoT/recuo (sem hit-stop nem interrupção).
func take_damage(amount: int, dir: Vector3, knockback := 4.0, opts := {}) -> float:
	if not alive():
		return 0.0
	var has_dir := amount > 0 and dir.length_squared() > 0.0
	if has_dir:
		interrupt_prepare()
	var hp_before := hp
	var imp := 0.0
	var src: BattleFighter = opts.get("source")
	if has_dir and is_instance_valid(src):
		imp = impact_secs(float(amount) / float(maxi(max_hp, 1)), bool(opts.get("crit", false)),
				float(opts.get("eff", 1.0)), amount >= hp_before, bool(opts.get("final", true)))
		if imp > 0.0:
			impact_t = maxf(impact_t, imp)
			src.impact_t = maxf(src.impact_t, imp)
	hp = maxi(hp - amount, 0)
	mon.hp = hp
	var k := dir * knockback * KNOCKBACK_SCALE
	if impact_t > 0.0:
		impact_knock += k
	else:
		knock = k
	if status == "sleep" and knockback > 0.0:
		clear_status()
	if amount > 0:
		_flash_t = maxf(imp, 0.12)
	refresh_label()
	if hp == 0:
		_faint()
	return imp


func _faint() -> void:
	clear_prepare()
	dash_t = 0.0
	lunge_t = 0.0
	root_t = 0.0
	sprinting = false
	popup("%s desmaiou!" % mon.display_name, Color(1, 0.4, 0.4), 1.0, 1.2)
	preload("res://audio/cue.gd").sfx("faint")
	if _body:
		var cap := _body.mesh as CapsuleMesh
		_body.rotation.x = PI / 2.0
		_body.position.y = cap.radius
		_mat.albedo_color = _base_color.darkened(0.5)
		_label.visible = false
	fainted.emit(self)


func popup(text: String, col: Color, scale_k := 1.0, extra := 0.15) -> void:
	if arena:
		arena.popup(head_pos(extra), text, col, scale_k)


# --- Por frame ---

## Avança timers, status e stamina. dt já escalado pela velocidade da luta.
func tick(dt: float) -> void:
	if impact_t > 0.0:
		impact_t = maxf(impact_t - dt, 0.0)
		if impact_t <= 0.0 and impact_knock != Vector3.ZERO:
			knock += impact_knock
			impact_knock = Vector3.ZERO
		return
	if not alive():
		return
	stun_t = maxf(stun_t - dt, 0.0)
	root_t = maxf(root_t - dt, 0.0)
	trap_t = maxf(trap_t - dt, 0.0)
	land_t = maxf(land_t - dt, 0.0)
	evasion_t = maxf(evasion_t - dt, 0.0)
	confusion_t = maxf(confusion_t - dt, 0.0)
	struggle_cd = maxf(struggle_cd - dt, 0.0)
	for k in move_cd.keys():
		move_cd[k] = maxf(move_cd[k] - dt, 0.0)
	gcd_t = maxf(gcd_t - dt, 0.0)
	if prepare_t > 0.0:
		prepare_t = maxf(prepare_t - dt, 0.0)
		if prepare_t <= 0.0 and prepare_cb.is_valid():
			var cb := prepare_cb
			clear_prepare()
			root_t = 0.0
			if can_act():
				cb.call()
	_tick_status(dt)
	if stagger_t > 0.0:
		stagger_t = maxf(stagger_t - dt, 0.0)
		stamina = 0.0
		if stagger_t == 0.0:
			refresh_label()
	elif sprinting:
		stamina = maxf(stamina - pp_max * SPRINT_DRAIN * dt, 0.0)
		if stamina <= 0.0:
			sprinting = false
	elif stamina < pp_max:
		stamina = minf(pp_max, stamina + pp_max * PP_REGEN * speed_factor() * dt)
	elif stamina > pp_max:
		stamina = pp_max


## Move o corpo. want = direção desejada (comprimento <= 1), speed = m/s base.
func drive(dt: float, want: Vector3, speed: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= dt
		_mat.albedo_color = Color.WHITE if _flash_t > 0.0 else _tint()
	elif _mat:
		_mat.albedo_color = _tint()
	if impact_t > 0.0 or not alive():
		velocity = Vector3.ZERO
		return
	speed *= speed_factor()
	if status == "paralysis":
		speed *= 0.5
	if sprinting:
		speed *= SPRINT_MULT
	if not can_act() or root_t > 0.0:
		want = Vector3.ZERO
	if trap_t > 0.0:
		want = Vector3.ZERO
		dash_t = 0.0
		lunge_t = 0.0
		knock = Vector3.ZERO
	if air_t > 0.0:
		air_t = maxf(air_t - dt, 0.0)
		var jv := sqrt(2.0 * JUMP_G * jump_height)
		var t := jump_time - air_t
		air_h = maxf(jv * t - 0.5 * JUMP_G * t * t, 0.0)
		if air_t <= 0.0:
			air_h = 0.0
			land_t = JUMP_LAND
	if dash_t > 0.0:
		dash_t -= dt
		velocity = dash_dir * dash_speed
		_check_dash_hit()
	elif lunge_t > 0.0:
		lunge_t -= dt
		velocity = lunge_dir * LUNGE_SPEED
		_check_lunge_hit()
	elif arc_step_t > 0.0:
		arc_step_t -= dt
		var step := ARC_STEP_M / ARC_STEP_TIME
		if is_instance_valid(opponent):
			step = minf(step, (flat_to(opponent).length() - HIT_RANGE) / maxf(dt, 0.0001))
		step = maxf(step, 0.0)
		if step == 0.0:
			arc_step_t = 0.0
		velocity = arc_step_dir * step
	else:
		velocity = want * speed + knock
		if is_instance_valid(opponent) and opponent.active():
			var to_o := flat_to(opponent)
			if to_o.length() > 0.01:
				facing = to_o.normalized()
		elif want.length() > 0.1:
			facing = want.normalized()
	knock = knock.move_toward(Vector3.ZERO, KNOCK_DECAY * dt)
	position.x += velocity.x * dt
	position.z += velocity.z * dt
	position.y = air_h
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)


func _tint() -> Color:
	var c := _base_color
	match status:
		"burn":
			c = c.lerp(Color(1, 0.3, 0.1), 0.35)
		"poison":
			c = c.lerp(Color(0.6, 0.2, 0.8), 0.35)
		"paralysis":
			c = c.lerp(Color(1, 1, 0.2), 0.35)
		"sleep":
			c = c.darkened(0.4)
	if stagger_t > 0.0:
		c = c * Color(0.7, 0.7, 0.85)
	return c


func _check_dash_hit() -> void:
	if dash_hit:
		return
	for t in arena.targets_of(self):
		if t == dash_miss or flat_to(t).length() >= HIT_RANGE:
			continue
		if passes_under(t):
			if not dash_dodged.has(t.get_instance_id()):
				dash_dodged[t.get_instance_id()] = true
				t.popup("DESVIOU!", Color(0.75, 0.9, 1.0))
			continue
		dash_hit = true
		dash_t = 0.0
		arena.moves.hit(self, t, dash_move, dash_dir)
		return


func _check_lunge_hit() -> void:
	if lunge_done or not is_instance_valid(opponent) or not opponent.active():
		return
	if flat_to(opponent).length() >= HIT_RANGE:
		return
	lunge_done = true
	lunge_t = 0.0
	if passes_under(opponent):
		opponent.popup("DESVIOU!", Color(0.75, 0.9, 1.0))
		return
	arena.moves.hit(self, opponent, STRUGGLE, lunge_dir)
	if alive():
		take_damage(maxi(1, int(max_hp / 4.0)), Vector3.ZERO, 0.0)
		popup("Recuo", Color(0.9, 0.6, 0.6), 0.8)


## Depois de um item aplicado ao Mon: copia HP e status persistente de volta para o lutador.
func sync_after_item() -> void:
	hp = clampi(mon.hp, 0, max_hp)
	if mon.status == "" and status in Mon.PERSIST_STATUS:
		clear_status()
	refresh_label()


## Zera estágios e efeitos temporários e grava HP/PP/status persistentes no Mon.
func write_back() -> void:
	if not alive() and mon.hp > 0:
		return  # desmaiou em campo e foi revivido por item depois: não desfaz o Revive
	mon.hp = hp
	mon.pp = pp_max
	mon.status = status if status in Mon.PERSIST_STATUS else ""
