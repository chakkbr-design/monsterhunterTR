extends Node3D
## Arena de batalha em tempo real. Contrato: start(player_party, enemies, opts) e signal finished(result).
## opts: {kind: "wild"|"trainer", trainer_id?, can_run?, autoplay? (IA controla o jogador), seed?, speed?,
##        battle_size? (selvagem 2 = 2x1 com aliado IA; treinador sempre 1), trainer_item?, game? (bolsa injetada)}.
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
const BATTLE_SIZE := 2
const ITEM_CD := 3.0
const SUPPORT_HEAL_AT := 0.5
const MODAL_SLOW := 0.2
const CONTROL_SWAP_CD := 0.3
const ALLY_MODE_NAMES := ["ATTACK", "DEFEND", "SUPPORT"]
const ALLY_MODE_COLORS := [Color(1.0, 0.5, 0.4), Color(0.5, 0.75, 1.0), Color(0.55, 1.0, 0.6)]
const BATTLE_ITEM_CATEGORIES := ["medicine", "berries"]

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
var player: BattleFighter  # o mon que o jogador controla
var ally: BattleFighter    # 2º mon do jogador (IA), só em batalha selvagem
var ally_mode := 0         # BattleAI.ATTACK / DEFEND / SUPPORT
var item_cd := 0.0         # cooldown global de itens (bolsa rápida e cura do SUPPORT)
var menu := ""             # "" | "bag" | "party" (abre com interact; a luta fica a MODAL_SLOW)
var menu_sel := 0
var menu_target := 0
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
var _trainer_item := ""
var _battle_size := 1
var _f_was_down := false
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
		var tr := Dex.trainer(String(o.get("trainer_id", "")))
		_think_scale = float(tr.get("ai_think_scale", 1.0))
		_trainer_item = String(o.get("trainer_item", tr.get("item", "")))
	# Selvagem: até BATTLE_SIZE mons do jogador (2x1). Treinador: sempre 1x1.
	_battle_size = 1 if kind != "wild" else clampi(int(o.get("battle_size", BATTLE_SIZE)), 1, BATTLE_SIZE)
	if not InputMap.has_action("move_1"):
		load("res://core/controls.gd").register()
	_build()
	var pi := _next_healthy(-1)
	var ei := _next_enemy(-1)
	if pi < 0 or ei < 0:
		_end("lose" if pi < 0 else "win", 0.0)
		return
	_send_player(pi, Vector3(0, 0, START_GAP / 2.0))
	if _battle_size >= 2:
		var ai_i := _next_healthy(pi)
		if ai_i >= 0:
			_send_ally(ai_i, Vector3(1.6, 0, START_GAP / 2.0 + 0.4))
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


## Próximo mon da party com HP que ainda não está em campo.
func _next_healthy(after: int) -> int:
	var busy := _field_mons()
	for k in party.size():
		var i := (after + 1 + k) % party.size()
		if i != after and not party[i].is_fainted() and not busy.has(party[i]):
			return i
	return -1


## Mons do jogador vivos em campo (controlado e aliado).
func _field_mons() -> Array:
	var out: Array = []
	for f in [player, ally]:
		if is_instance_valid(f) and f.active():
			out.append(f.mon)
	return out


func _player_ctrl() -> String:
	return "ai" if opts.get("autoplay", false) else "player"


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
	player = _spawn(party[i], 0, _player_ctrl(), at)
	player.set_meta("party_index", i)
	_bind()
	player.popup("Go, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)


func _send_ally(i: int, at: Vector3) -> void:
	ally = _spawn(party[i], 0, "ai", at)
	ally.set_meta("party_index", i)
	_bind()
	ally.popup("Go, %s!" % ally.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)


func _send_enemy(i: int) -> void:
	enemy_index = i
	enemy = _spawn(enemies[i], 1, "ai", Vector3(0, 0, -START_GAP / 2.0))
	enemy.ai.think_scale = _think_scale
	enemy.ai.think = WILD_OPENING_DELAY if kind == "wild" else TRAINER_SWAP_HOLD
	enemy.trainer_item = _trainer_item if kind == "trainer" else ""
	_participants.clear()
	_bind()


## Reaponta oponentes: os mons do jogador miram o inimigo; o inimigo mira o controlado
## (o selvagem reavalia sozinho entre os dois em BattleAI.pick_target).
func _bind() -> void:
	if not is_instance_valid(enemy):
		return
	for f in [player, ally]:
		if is_instance_valid(f) and f.active():
			f.opponent = enemy
			if enemy.alive():
				_participants[f.mon.get_instance_id()] = f.mon
	var cur := enemy.opponent
	if kind != "wild" or not (is_instance_valid(cur) and cur.active() and cur.side == 0):
		enemy.opponent = player if is_instance_valid(player) and player.active() else ally


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
	dt *= fight_speed * (MODAL_SLOW if menu != "" else 1.0)
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
	hud.refresh(player, enemy, raw, ally, {"ally_mode": ALLY_MODE_NAMES[ally_mode], "item_cd": item_cd,
		"menu": _menu_text() if menu != "" else ""})


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
	item_cd = maxf(item_cd - dt, 0.0)
	_support_heal()
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
	var live: Array = fighters.filter(func(f): return f.active() and f.dash_t <= 0.0 and not f.is_airborne())
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: BattleFighter = live[i]
			var b: BattleFighter = live[j]
			var d := b.position - a.position
			d.y = 0.0
			var min_d := 0.8
			if d.length() < min_d:
				var n := d.normalized() if d.length() > 0.001 else Vector3.FORWARD
				var push := (min_d - d.length()) * 0.5
				a.position -= n * push
				b.position += n * push


## `ally_mode` (F) vem do núcleo; sem a ação, lê a tecla F direto.
func _ally_mode_pressed() -> bool:
	if InputMap.has_action("ally_mode"):
		return Input.is_action_just_pressed("ally_mode")
	var down := Input.is_physical_key_pressed(KEY_F)
	var hit := down and not _f_was_down
	_f_was_down = down
	return hit


func _player_input(f: BattleFighter) -> Vector3:
	if manual:
		return Vector3.ZERO
	if menu != "":
		f.sprinting = false
		_menu_input()
		return Vector3.ZERO
	if Input.is_action_just_pressed("interact"):
		open_menu("bag")
		return Vector3.ZERO
	if _ally_mode_pressed():
		cycle_ally_mode()
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

## Tab: com aliado em campo troca qual dos dois o jogador controla (instantâneo);
## sem aliado, recolhe o controlado e manda o próximo mon saudável da party.
func swap() -> bool:
	if is_instance_valid(ally) and ally.active():
		return swap_control()
	if not is_instance_valid(player):
		return false
	var nxt := _next_healthy(int(player.get_meta("party_index", 0)))
	return nxt >= 0 and send_in(nxt)


func swap_control() -> bool:
	if state != "fight" or _swap_cd > 0.0 or not is_instance_valid(player) or not player.active() \
			or not is_instance_valid(ally) or not ally.active():
		return false
	var old := player
	player = ally
	ally = old
	for f in [player, ally]:
		f.sprinting = false
		f.velocity = Vector3.ZERO
	player.controller = _player_ctrl()
	ally.controller = "ai"
	ally.ai.think = maxf(ally.ai.think, 0.3)
	_swap_cd = CONTROL_SWAP_CD
	player.popup("Go, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
	return true


## Manda o mon `i` da party para campo. as_ally = no lugar do aliado (só selvagem 2x1);
## senão substitui o controlado. Respeita o cooldown de troca.
func send_in(i: int, as_ally := false) -> bool:
	if state != "fight" or _swap_cd > 0.0 or i < 0 or i >= party.size():
		return false
	var m: Mon = party[i]
	if m.is_fainted() or _field_mons().has(m):
		return false
	if as_ally:
		if _battle_size < 2 or not is_instance_valid(player) or not player.active():
			return false
		var at := player.position + Vector3(1.6, 0, 0.4)
		if is_instance_valid(ally) and ally.active():
			at = ally.position
			_recall(ally)
		at.y = 0.0
		_send_ally(i, at)
	else:
		if not is_instance_valid(player) or not player.alive():
			return false
		if player.dash_t > 0.0 or player.lunge_t > 0.0 or player.root_t > 0.0:
			return false
		var at := player.position
		at.y = 0.0
		_recall(player)
		_send_player(i, at)
	_swap_cd = SWAP_CD
	return true


func cycle_ally_mode() -> int:
	ally_mode = (ally_mode + 1) % ALLY_MODE_NAMES.size()
	if is_instance_valid(ally) and ally.active():
		ally.popup(ALLY_MODE_NAMES[ally_mode], ALLY_MODE_COLORS[ally_mode], 1.0, 0.9)
	hud.banner("Ally mode: %s" % ALLY_MODE_NAMES[ally_mode], 1.0)
	return ally_mode


# --- Itens na batalha ---

## Itens de batalha (remédios e frutas com efeito de HP/cura/revive) que existem na bolsa.
func battle_items() -> Array:
	var g := _game()
	var out: Array = []
	if g == null:
		return out
	var ids: Array = g.bag.keys()
	ids.sort()
	for id in ids:
		var it := Dex.item(String(id))
		var fx: Dictionary = it.get("effect", {})
		if int(g.bag[id]) > 0 and String(it.get("category", "")) in BATTLE_ITEM_CATEGORIES \
				and (fx.has("hp") or fx.has("cure") or fx.has("revive")):
			out.append(String(id))
	return out


## Lutador vivo em campo para este Mon (null se está na party ou desmaiado).
func _active_fighter_of(m: Mon) -> BattleFighter:
	for f in fighters:
		if is_instance_valid(f) and f.mon == m and f.active():
			return f
	return null


## Usa `id` da bolsa no mon `m` (padrão: o controlado). Custa o cooldown global de itens (3 s)
## e trava os golpes do controlado por 1 GCD. Bloqueado com o controlado exausto (stagger).
func use_item(id: String, m: Mon = null) -> bool:
	if state != "fight" or not is_instance_valid(player):
		return false
	if m == null:
		m = player.mon
	var g := _game()
	if g == null or int(g.bag.get(id, 0)) <= 0:
		hud.banner("You don't have any %s left!" % Dex.item(id).get("name", id), 1.2)
		return false
	if item_cd > 0.0:
		return false
	if player.stagger_t > 0.0:
		hud.banner("Too exhausted to use an item!", 1.2)
		return false
	var f := _active_fighter_of(m)
	var fx: Dictionary = Dex.item(id).get("effect", {})
	var text := ""
	var before := m.hp
	if f and String(fx.get("cure", "")) == "confusion" and f.confusion_t > 0.0:
		f.confusion_t = 0.0  # confusão só existe na luta: o núcleo não a vê no Mon
		g.take_item(id)
		text = "%s snapped out of confusion!" % m.display_name
	else:
		if f:
			m.hp = f.hp
		text = g.use_item(id, m)
		if text == "":
			hud.banner("It won't have any effect.", 1.2)
			return false
		if f:
			f.sync_after_item()
	item_cd = ITEM_CD
	player.gcd_t = maxf(player.gcd_t, Dex.GLOBAL_COOLDOWN)
	close_menu()
	hud.banner("Used %s! %s" % [Dex.item(id).get("name", id), text], 1.8)
	if f:
		if m.hp > before:
			f.popup("+%d HP" % (m.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
		fx_disc(f.position, 0.9, Color(0.6, 1.0, 0.65), 0.5)
	return true


## Melhor item de HP da bolsa para `missing` de HP (o menor que cobre tudo; senão o maior).
func best_heal_item(missing: int) -> String:
	var g := _game()
	if g == null:
		return ""
	var best := ""
	var best_amt := 0
	for id in g.bag:
		if int(g.bag[id]) <= 0:
			continue
		var e: Dictionary = Dex.item(String(id)).get("effect", {})
		if not e.has("hp"):
			continue
		var amt: int = 9999 if str(e.hp) == "full" else int(e.hp)
		if best == "" or (amt >= missing and (best_amt < missing or amt < best_amt)) or (best_amt < missing and amt > best_amt):
			best = String(id)
			best_amt = amt
	return best


## SUPPORT: o aliado usa o melhor item de cura no controlado quando ele cai abaixo de 50% de HP.
func _support_heal() -> void:
	if ally_mode != BattleAI.SUPPORT or item_cd > 0.0:
		return
	if not (is_instance_valid(ally) and ally.active() and ally.can_act() and is_instance_valid(player) and player.active()):
		return
	if float(player.hp) / maxf(player.max_hp, 1) >= SUPPORT_HEAL_AT:
		return
	var id := best_heal_item(player.max_hp - player.hp)
	if id == "":
		return
	var before := player.hp
	player.mon.hp = player.hp
	var text: String = _game().use_item(id, player.mon)
	if text == "":
		return
	player.sync_after_item()
	item_cd = ITEM_CD
	hud.banner("%s used a %s! %s" % [ally.mon.display_name, Dex.item(id).get("name", id), text], 1.8)
	player.popup("+%d HP" % (player.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
	fx_disc(player.position, 0.9, Color(0.6, 1.0, 0.65), 0.5)


func item_used_by_trainer(f: BattleFighter, item_name: String) -> void:
	hud.banner("The trainer used a %s on %s!" % [item_name, f.mon.display_name], 1.4)


# --- Menu rápido (bolsa / party) ---

func open_menu(page: String) -> void:
	if state != "fight":
		return
	menu = page
	menu_sel = 0
	menu_target = int(player.get_meta("party_index", 0)) if is_instance_valid(player) else 0


func close_menu() -> void:
	menu = ""


func _menu_input() -> void:
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause"):
		close_menu()
		return
	if Input.is_action_just_pressed("swap_mon"):
		open_menu("party" if menu == "bag" else "bag")
		return
	var n := battle_items().size() if menu == "bag" else party.size()
	if Input.is_action_just_pressed("move_forward"):
		menu_sel = wrapi(menu_sel - 1, 0, maxi(n, 1))
	if Input.is_action_just_pressed("move_back"):
		menu_sel = wrapi(menu_sel + 1, 0, maxi(n, 1))
	if menu == "bag":
		if Input.is_action_just_pressed("move_left"):
			menu_target = wrapi(menu_target - 1, 0, maxi(party.size(), 1))
		if Input.is_action_just_pressed("move_right"):
			menu_target = wrapi(menu_target + 1, 0, maxi(party.size(), 1))
		var items := battle_items()
		for k in mini(items.size(), 4):
			if Input.is_action_just_pressed("move_%d" % (k + 1)):
				use_item(items[k], party[menu_target])
				return
		if Input.is_action_just_pressed("jump") and menu_sel < items.size():
			use_item(items[menu_sel], party[menu_target])
	else:
		if Input.is_action_just_pressed("jump") and send_in(menu_sel):
			close_menu()
		elif _ally_mode_pressed() and send_in(menu_sel, true):
			close_menu()


func _menu_text() -> String:
	var g := _game()
	var lines: Array = []
	if menu == "bag":
		var items := battle_items()
		menu_sel = clampi(menu_sel, 0, maxi(items.size() - 1, 0))
		var tgt: Mon = party[clampi(menu_target, 0, party.size() - 1)]
		lines.append("BAG   (Tab: party)   target < %s %d/%d >" % [tgt.display_name, tgt.hp, tgt.max_hp])
		if items.is_empty():
			lines.append("  (no battle items)")
		for k in items.size():
			var id: String = items[k]
			lines.append("%s %s%s x%d" % [">" if k == menu_sel else " ", ("%d " % (k + 1)) if k < 4 else "  ",
				Dex.item(id).get("name", id), int(g.bag[id])])
		lines.append("W/S select  A/D target  Space/1-4 use  E close")
		if item_cd > 0.0:
			lines.append("Item cooldown %.1fs" % item_cd)
	else:
		lines.append("PARTY   (Tab: bag)")
		for k in party.size():
			var m: Mon = party[k]
			var tag := ""
			if is_instance_valid(player) and player.mon == m and player.active():
				tag = " [control]"
			elif is_instance_valid(ally) and ally.mon == m and ally.active():
				tag = " [ally]"
			elif m.is_fainted():
				tag = " [fainted]"
			lines.append("%s %s Lv%d %d/%d%s" % [">" if k == menu_sel else " ", m.display_name, m.level, m.hp, m.max_hp, tag])
		lines.append("W/S select  Space send in" + ("  F send as ally" if _battle_size >= 2 else "") + "  E close")
	return "\n".join(lines)


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


## Estado do jogador (bolsa). opts.game permite injetar uma instância de core/game.gd nos testes.
func _game() -> Node:
	var g = opts.get("game")
	if g is Node and is_instance_valid(g):
		return g
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
	return _active_fighter_of(m)


## Depois de XP/EV o Mon recalcula stats; o lutador em campo acompanha.
func _sync_from_mon(f: BattleFighter) -> void:
	f.level = f.mon.level
	for k in StatCalc.STATS:
		f.stats[k] = f.mon.stat(k)
	f.max_hp = f.mon.max_hp
	f.hp = clampi(f.mon.hp, 0, f.max_hp)
	f.refresh_label()


func _player_fainted(f: BattleFighter) -> void:
	if f == ally or (f == player and is_instance_valid(ally) and ally.active()):
		# Ainda sobra um mon em campo: se era o controlado, o controle passa para o aliado. Ninguém novo entra.
		if f == player:
			player = ally
			player.controller = _player_ctrl()
			player.sprinting = false
			player.popup("Go, %s!" % player.mon.display_name, Color(0.7, 0.9, 1.0), 1.0, 0.8)
		ally = null
		if menu != "" and not is_instance_valid(player):
			close_menu()
		_bind()
		later(FAINT_CLEAR, func() -> void:
			if is_instance_valid(f) and fighters.has(f):
				_recall(f))
		return
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
