extends Node3D
## Arena de batalha em tempo real. Contrato: start(player_party, enemies, opts) e signal finished(result).
## opts: {kind: "wild"|"trainer", trainer_id?, can_run?, autoplay? (IA controla o jogador), seed?, speed?}.
## Com `manual = true` nada anda sozinho: quem chama step(dt) (testes headless).

signal finished(result: Dictionary)

const ARENA_SIZE := 12.0
const START_GAP := 6.0
const WILD_OPENING_DELAY := 0.5
const TRAINER_SWAP_HOLD := 0.5
const INTRO_TIME := 1.2
const FAINT_CLEAR := 1.0
const NEXT_TRAINER_MON := 1.4
const SWAP_CD := 1.0
const CAM_DIST := 5.0
const CAM_HEIGHT := 3.4
const CAM_TURN := deg_to_rad(110.0)
const BALL_FLIGHT := 0.5
const BALL_SHAKE := 0.6
const BALL_ORDER := ["poke_ball", "great_ball", "ultra_ball"]
const LOG_MAX := 400

var manual := false
var rng := RandomNumberGenerator.new()
var moves: BattleMoves
var hud: BattleHUD
var fight_speed := 1.0
var opts := {}
var kind := "wild"
var party: Array = []
var enemies: Array = []
var enemy_index := 0
var player: BattleFighter
var enemy: BattleFighter
var fighters: Array = []
var projectiles: Array = []
var state := "idle"
var result := {}
var exp_log: Array = []
var log_lines: Array = []
var hits := 0
var rect := Rect2(-ARENA_SIZE / 2.0, -ARENA_SIZE / 2.0, ARENA_SIZE, ARENA_SIZE)

var _state_t := 0.0
var _end_delay := 0.0
var _events: Array = []
var _fx: Array = []
var _popups: Array = []
var _participants := {}
var _cam: Camera3D
var _prev_cam: Camera3D
var _yaw := 0.0
var _swap_cd := 0.0
var _capture := {}
var _think_scale := 1.0
var _built := false


func _physics_process(delta: float) -> void:
	if not manual:
		step(delta)


func start(player_party: Array, enemy_list: Array, o: Dictionary) -> void:
	opts = o
	party = player_party
	enemies = enemy_list
	kind = String(o.get("kind", "wild"))
	fight_speed = float(o.get("speed", 1.0))
	if o.has("seed"):
		rng.seed = int(o.seed)
	else:
		rng.randomize()
	moves = BattleMoves.new(self, rng)
	if kind == "trainer":
		_think_scale = float(Dex.trainer(String(o.get("trainer_id", ""))).get("ai_think_scale", 1.0))
	if not InputMap.has_action("move_1"):
		load("res://core/controls.gd").register()
	_build()
	var pi := _next_healthy(-1)
	var ei := _next_enemy(-1)
	if pi < 0 or ei < 0:
		_end("lose" if pi < 0 else "win", 0.0)
		return
	_send_player(pi, Vector3(0, 0, START_GAP / 2.0))
	_send_enemy(ei)
	var e: Mon = enemies[ei]
	hud.banner(("A wild %s appeared!" % e.display_name) if kind == "wild" else ("Trainer sent out %s!" % e.display_name), INTRO_TIME)
	state = "intro"
	_state_t = 0.0
	_update_camera(1.0)


# --- Montagem ---

func _build() -> void:
	if _built:
		return
	_built = true
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.45, 0.3)
	pm.material = fm
	floor_mi.mesh = pm
	floor_mi.position.y = 0.01
	add_child(floor_mi)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.85)
	for i in 4:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(ARENA_SIZE, 0.05, 0.08) if i < 2 else Vector3(0.08, 0.05, ARENA_SIZE)
		bm.material = lm
		b.mesh = bm
		var h := ARENA_SIZE / 2.0
		b.position = [Vector3(0, 0.03, -h), Vector3(0, 0.03, h), Vector3(-h, 0.03, 0), Vector3(h, 0.03, 0)][i]
		add_child(b)
	var mid := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.4
	tm.outer_radius = 1.5
	tm.material = lm
	mid.mesh = tm
	mid.position.y = 0.02
	add_child(mid)
	_prev_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	_cam = Camera3D.new()
	_cam.fov = 60.0
	add_child(_cam)
	_cam.make_current()
	hud = BattleHUD.new()
	add_child(hud)


func _next_healthy(after: int) -> int:
	for k in party.size():
		var i := (after + 1 + k) % party.size()
		if i != after and not party[i].is_fainted():
			return i
	return -1


func _next_enemy(after: int) -> int:
	for i in range(after + 1, enemies.size()):
		if not enemies[i].is_fainted():
			return i
	return -1


func _spawn(m: Mon, side: int, ctrl: String, at: Vector3) -> BattleFighter:
	var f := BattleFighter.new()
	f.arena = self
	add_child(f)
	f.setup(m, side, ctrl)
	f.position = at
	f.facing = Vector3(0, 0, -1) if side == 0 else Vector3(0, 0, 1)
	f.fainted.connect(_on_fainted)
	fighters.append(f)
	return f


func _send_player(i: int, at: Vector3) -> void:
	var ctrl := "ai" if opts.get("autoplay", false) else "player"
	player = _spawn(party[i], 0, ctrl, at)
	player.set_meta("party_index", i)
	_bind()
	player.popup("Go, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)


func _send_enemy(i: int) -> void:
	enemy_index = i
	enemy = _spawn(enemies[i], 1, "ai", Vector3(0, 0, -START_GAP / 2.0))
	enemy.ai.think_scale = _think_scale
	enemy.ai.think = WILD_OPENING_DELAY if kind == "wild" else TRAINER_SWAP_HOLD
	_participants.clear()
	_bind()


func _bind() -> void:
	if is_instance_valid(player) and is_instance_valid(enemy):
		player.opponent = enemy
		enemy.opponent = player
		if player.alive() and enemy.alive():
			_participants[player.mon.get_instance_id()] = player.mon


func targets_of(user: BattleFighter) -> Array:
	var out: Array = []
	for f in fighters:
		if f != user and is_instance_valid(f) and f.side != user.side and f.active():
			out.append(f)
	return out


func later(delay: float, cb: Callable) -> void:
	_events.append({"t": delay, "cb": cb})


func edge_push(f: BattleFighter) -> Vector3:
	var p := Vector3.ZERO
	var inner := rect.grow(-2.0)
	if f.position.x < inner.position.x:
		p.x = (inner.position.x - f.position.x) / 2.0
	elif f.position.x > inner.end.x:
		p.x = (inner.end.x - f.position.x) / 2.0
	if f.position.z < inner.position.y:
		p.z = (inner.position.y - f.position.z) / 2.0
	elif f.position.z > inner.end.y:
		p.z = (inner.end.y - f.position.z) / 2.0
	return p


func note_hit(_user: BattleFighter, _target: BattleFighter, _mv: Dictionary, _dmg: int, _hp_before: int) -> void:
	hits += 1


# --- Laço ---

func step(dt: float) -> void:
	if state == "idle" or state == "done":
		return
	var raw := dt
	dt *= fight_speed
	_state_t += dt
	_tick_fx(raw)
	match state:
		"intro":
			if _state_t >= INTRO_TIME:
				state = "fight"
				hud.banner("Fight!", 0.8)
		"fight":
			_fight_step(dt)
		"capture":
			_capture_step(dt)
		"ending":
			if _state_t >= _end_delay:
				_finish()
				return
	if not manual:
		_camera_input(raw)
	_update_camera(raw)
	hud.refresh(player, enemy, raw)


func _fight_step(dt: float) -> void:
	var evs := _events
	_events = []
	for e in evs:
		e.t -= dt
		if e.t <= 0.0:
			e.cb.call()
		else:
			_events.append(e)
	if state != "fight":
		return
	_swap_cd = maxf(_swap_cd - dt, 0.0)
	for f in fighters:
		if f.on_field:
			f.tick(dt)
	for f in fighters.duplicate():
		if not f.on_field or state != "fight":
			continue
		var want := Vector3.ZERO
		var speed := BattleFighter.AI_SPEED
		if f.alive():
			if f.controller == "player":
				want = _player_input(f)
				speed = BattleFighter.PLAYER_SPEED
			elif f.controller == "ai" and f.impact_t <= 0.0:
				want = f.ai.step(dt)
		f.drive(dt, want, speed)
		var bounds := rect.grow(-0.5)
		f.position.x = clampf(f.position.x, bounds.position.x, bounds.end.x)
		f.position.z = clampf(f.position.z, bounds.position.y, bounds.end.y)
	_separate()
	for p in projectiles:
		p.step(dt, self)
	for p in projectiles.filter(func(q): return q.done):
		projectiles.erase(p)
		p.queue_free()


func _separate() -> void:
	if not (is_instance_valid(player) and is_instance_valid(enemy) and player.active() and enemy.active()):
		return
	if player.dash_t > 0.0 or enemy.dash_t > 0.0 or player.is_airborne() or enemy.is_airborne():
		return
	var d := enemy.position - player.position
	d.y = 0.0
	var min_d := 0.8
	if d.length() < min_d:
		var n := d.normalized() if d.length() > 0.001 else Vector3.FORWARD
		var push := (min_d - d.length()) * 0.5
		player.position -= n * push
		enemy.position += n * push


func _player_input(f: BattleFighter) -> Vector3:
	if manual:
		return Vector3.ZERO
	var i := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_action_just_pressed("jump"):
		f.start_jump()
	f.sprinting = Input.is_action_pressed("sprint") and f.can_sprint(i.length() > 0.1)
	for k in mini(f.moves.size(), 4):
		if Input.is_action_just_pressed("move_%d" % (k + 1)) and f.can_act():
			if f.out_of_pp():
				f.struggle()
			else:
				moves.use(f, String(f.moves[k]), true)
	if Input.is_action_just_pressed("swap_mon"):
		swap()
	if Input.is_action_just_pressed("run_away"):
		run_away()
	if Input.is_action_just_pressed("throw_ball"):
		throw_ball()
	return Vector3(i.x, 0.0, i.y).rotated(Vector3.UP, _yaw)


# --- Ações do jogador ---

func swap() -> bool:
	if state != "fight" or _swap_cd > 0.0 or not is_instance_valid(player) or not player.alive():
		return false
	if player.dash_t > 0.0 or player.lunge_t > 0.0 or player.root_t > 0.0:
		return false
	var cur := int(player.get_meta("party_index", 0))
	var nxt := _next_healthy(cur)
	if nxt < 0 or nxt == cur:
		return false
	var at := player.position
	at.y = 0.0
	_recall(player)
	_send_player(nxt, at)
	_swap_cd = SWAP_CD
	return true


## Tira o lutador de campo (fica escondido até a arena ser liberada; callbacks pendentes seguem válidos).
func _recall(f: BattleFighter) -> void:
	f.write_back()
	f.on_field = false
	f.visible = false
	fighters.erase(f)


func run_away() -> bool:
	if state != "fight":
		return false
	if kind != "wild" or not opts.get("can_run", true):
		hud.banner("No! There's no running from a trainer battle!" if kind != "wild" else "Can't escape!")
		return false
	hud.banner("Got away safely!", 1.0)
	_end("run", 0.6)
	return true


func _game() -> Node:
	return get_node_or_null("/root/Game") if is_inside_tree() else null


func _pick_ball() -> String:
	var g := _game()
	if g == null:
		return String(opts.get("ball", "poke_ball"))
	var order: Array = BALL_ORDER.duplicate()
	for id in Capture.ball_ids():
		if not order.has(id):
			order.append(id)
	for id in order:
		if int(g.bag.get(id, 0)) > 0:
			return id
	return ""


func throw_ball() -> bool:
	if state != "fight" or kind != "wild" or not is_instance_valid(enemy) or not enemy.active() or not player.alive():
		if kind != "wild" and state == "fight":
			hud.banner("You can't catch a trainer's Pokémon!")
		return false
	var ball_id := _pick_ball()
	if ball_id == "":
		hud.banner("No Poké Balls left!")
		return false
	var g := _game()
	if g:
		g.take_item(ball_id)
	var res := Capture.throw_ball(enemy.max_hp, enemy.hp, enemy.mon.catch_rate(), ball_id, enemy.status, enemy.level)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(Dex.item(ball_id).get("top", "#e3352b")))
	sm.material = mat
	ball.mesh = sm
	add_child(ball)
	var from := player.position + Vector3(0, player.look_h, 0)
	ball.position = from
	_capture = {"ball": ball, "id": ball_id, "res": res, "from": from,
		"to": enemy.position + Vector3(0, 0.16, 0), "shown": mini(int(res.shakes), 3)}
	hud.banner("Go, %s!" % Dex.item(ball_id).get("name", "Ball"), 0.8)
	state = "capture"
	_state_t = 0.0
	return true


func _capture_step(_dt: float) -> void:
	var ball: MeshInstance3D = _capture.ball
	var t := _state_t
	if t < BALL_FLIGHT:
		var s := t / BALL_FLIGHT
		ball.position = _capture.from.lerp(_capture.to, s) + Vector3(0, 1.2 * 4.0 * s * (1.0 - s), 0)
		return
	enemy.visible = false
	ball.position = _capture.to
	var shake_t := t - BALL_FLIGHT
	var shown: int = _capture.shown
	if shake_t < shown * BALL_SHAKE:
		var ph := fmod(shake_t, BALL_SHAKE) / BALL_SHAKE
		ball.rotation.z = sin(ph * TAU) * 0.45 if ph < 0.5 else 0.0
		return
	ball.rotation.z = 0.0
	if _capture.res.caught:
		enemy.mon.ball = _capture.id
		hud.banner("Gotcha! %s was caught!" % enemy.mon.display_name, 2.0)
		_end("caught", 1.6, {"caught_mon": enemy.mon})
		return
	ball.queue_free()
	enemy.visible = true
	hud.banner(Capture.fail_line(int(_capture.res.shakes)), 1.4)
	_capture = {}
	state = "fight"
	_state_t = 0.0


# --- Desmaio, XP e fim ---

func _on_fainted(f: BattleFighter) -> void:
	if state == "ending" or state == "done":
		return
	later(FAINT_CLEAR, func() -> void:
		if is_instance_valid(f) and not f.alive():
			f.on_field = false
			f.visible = false)
	if f.side == 1:
		_enemy_fainted(f)
	else:
		_player_fainted(f)


func _enemy_fainted(f: BattleFighter) -> void:
	var killer := f.last_hit_by
	if is_instance_valid(killer) and killer.side == 0:
		var got := killer.mon.add_evs(f.mon.ev_yield())
		if not got.is_empty():
			_sync_from_mon(killer)
	_award_exp(f.mon)
	var nxt := _next_enemy(enemy_index)
	if kind == "trainer" and nxt >= 0:
		hud.banner("Trainer is about to send out %s!" % enemies[nxt].display_name, NEXT_TRAINER_MON)
		later(NEXT_TRAINER_MON, func() -> void:
			_recall(f)
			_send_enemy(nxt))
		return
	hud.banner(("Wild %s fainted! You won!" % f.mon.display_name) if kind == "wild" else "You defeated the trainer!", 2.0)
	_end("win", 2.0)


func _award_exp(defeated: Mon) -> void:
	var receivers: Array = _participants.values().filter(func(m): return not m.is_fainted())
	if receivers.is_empty():
		return
	for m in receivers:
		var amount := maxi(1, int(defeated.exp_yield(m.level, kind == "trainer") / float(receivers.size())))
		var events: Array = m.add_exp(amount)
		exp_log.append({"mon": m, "amount": amount, "events": events})
		var f := _fighter_of(m)
		if f:
			f.popup("+%d EXP" % amount, Color(0.7, 1.0, 0.7), 1.0, 1.0)
			for e in events:
				if e.type == "level":
					f.popup("Grew to Lv %d!" % e.level, Color(1, 1, 0.5), 1.2, 1.3)
				elif e.type == "move" and e.learned:
					f.popup("Learned %s!" % Dex.move(e.move).get("name", e.move), Color(0.7, 0.9, 1.0), 1.0, 1.5)
			_sync_from_mon(f)


func _fighter_of(m: Mon) -> BattleFighter:
	for f in fighters:
		if f.mon == m:
			return f
	return null


## Depois de XP/EV o Mon recalcula stats; o lutador em campo acompanha.
func _sync_from_mon(f: BattleFighter) -> void:
	f.level = f.mon.level
	for k in StatCalc.STATS:
		f.stats[k] = f.mon.stat(k)
	f.max_hp = f.mon.max_hp
	f.hp = clampi(f.mon.hp, 0, f.max_hp)
	f.refresh_label()


func _player_fainted(f: BattleFighter) -> void:
	var nxt := _next_healthy(int(f.get_meta("party_index", 0)))
	if nxt < 0:
		hud.banner("You have no more Pokémon that can fight!", 2.0)
		_end("lose", 2.0)
		return
	var at := f.position
	at.y = 0.0
	later(FAINT_CLEAR, func() -> void:
		_recall(f)
		_send_player(nxt, at))


func _end(outcome: String, delay: float, extra := {}) -> void:
	result = {"outcome": outcome}
	result.merge(extra)
	state = "ending"
	_state_t = 0.0
	_end_delay = delay


func _finish() -> void:
	state = "done"
	for f in fighters:
		if is_instance_valid(f):
			f.write_back()
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	_events.clear()
	if _capture.has("ball") and is_instance_valid(_capture.ball):
		_capture.ball.queue_free()
	result["exp"] = exp_log
	if is_instance_valid(_prev_cam) and _prev_cam.is_inside_tree():
		_prev_cam.make_current()
	elif _cam:
		_cam.clear_current(false)
	if hud:
		hud.visible = false
	finished.emit(result)


# --- Câmera ---

func _camera_input(dt: float) -> void:
	if Input.is_action_pressed("cam_left"):
		_yaw -= CAM_TURN * dt
	if Input.is_action_pressed("cam_right"):
		_yaw += CAM_TURN * dt


func _update_camera(dt: float) -> void:
	if _cam == null or not is_instance_valid(player):
		return
	var focus := player.position * Vector3(1, 0, 1)
	var look := focus
	if is_instance_valid(enemy) and enemy.on_field:
		look = focus.lerp(enemy.position * Vector3(1, 0, 1), 0.35)
	var want := focus + Vector3(0, CAM_HEIGHT, CAM_DIST).rotated(Vector3.UP, _yaw)
	_cam.position = _cam.position.lerp(want, clampf(dt * 6.0, 0.0, 1.0))
	if _cam.position.distance_to(look) > 0.1 and _cam.is_inside_tree():
		_cam.look_at(to_global(look + Vector3(0, 0.6, 0)), Vector3.UP)


# --- Efeitos placeholder ---

func popup(at: Vector3, text: String, col: Color, scale_k := 1.0) -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_MAX:
		log_lines.pop_front()
	var stack := 0
	for p in _popups:
		if p.t < 0.35 and p.at.distance_to(at) < 0.6:
			stack += 1
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = int(44 * scale_k)
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = col
	l.position = at + Vector3(0, 0.28 * stack, 0)
	add_child(l)
	_popups.append({"node": l, "t": 0.0, "at": at, "base": l.position})


func _fx_node(mesh: Mesh, xf: Transform3D, col: Color, life: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	col.a = minf(col.a, 0.6)
	mat.albedo_color = col
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	add_child(mi)
	_fx.append({"node": mi, "t": maxf(life, 0.05), "life": maxf(life, 0.05), "mat": mat, "a": col.a})


func fx_disc(center: Vector3, radius: float, col: Color, life: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	_fx_node(cm, Transform3D(Basis(), Vector3(center.x, 0.04, center.z)), col, life)


func fx_cone(origin: Vector3, dir: Vector3, r: float, half: float, col: Color, life: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * tan(minf(half, 1.3))
	cm.height = r
	cm.radial_segments = 16
	var yv := -dir.normalized()
	var xv := yv.cross(Vector3.UP)
	xv = xv.normalized() if xv.length() > 0.01 else Vector3.RIGHT
	var zv := xv.cross(yv)
	var b := Basis(xv, yv, zv.normalized() * 0.25)
	col.a = 0.35
	_fx_node(cm, Transform3D(b, origin + dir * r * 0.5), col, life)


func fx_beam(origin: Vector3, dir: Vector3, length: float, width: float, col: Color, life: float) -> void:
	if length <= 0.01:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.15, length)
	var b := Basis.looking_at(dir.normalized(), Vector3.UP) if absf(dir.normalized().y) < 0.99 else Basis()
	_fx_node(bm, Transform3D(b, origin + dir.normalized() * length * 0.5), col, life)


func spawn_projectile(user: BattleFighter, mv: Dictionary, dir: Vector3, homing: bool, miss: BattleFighter, target: BattleFighter) -> void:
	var p := BattleProjectile.new()
	add_child(p)
	p.setup(user, mv, dir, homing, miss, target)
	projectiles.append(p)


func _tick_fx(dt: float) -> void:
	for e in _fx.duplicate():
		e.t -= dt
		if e.t <= 0.0:
			e.node.queue_free()
			_fx.erase(e)
		else:
			e.mat.albedo_color.a = e.a * clampf(e.t / minf(e.life, 0.2), 0.0, 1.0)
	for p in _popups.duplicate():
		p.t += dt
		var l: Label3D = p.node
		l.position = p.base + Vector3(0, 0.9 * p.t, 0)
		l.modulate.a = clampf((1.1 - p.t) / 0.4, 0.0, 1.0)
		if p.t >= 1.1:
			l.queue_free()
			_popups.erase(p)
