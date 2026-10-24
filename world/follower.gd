class_name WorldFollower
extends Node3D
## Os Pokémon fora da bola andando com o jogador (Game.companions do original): um WorldCompanion por
## Mon de Game.out, quantos estiverem fora ao mesmo tempo. Guarda o rastro do jogador (player.gd
## trail_point) e roda as regras do game.gd do original que mexem com eles: roda em volta do jogador
## parado, ações pelo humor (_companion_tick), busca de fruta (_fetch_tick) e pedido de descanso
## (_tired_tick). Teleportes (portas, zonas) põem todos ao lado do jogador.

const GROUP := "ow_follower_mgr"
const TRAIL_STEP := 0.4  ## player.gd TRAIL_STEP / TRAIL_MAX
const TRAIL_MAX := 64
const SNAP := 6.0  ## o jogador pulou mais que isto num quadro (teleporte): recomeça o rastro
## game.gd do original.
const ACT_PICK_S := 0.5
const RING_RADIUS := 1.8
const RING_COME_RADIUS := 1.2
const RING_RAIN_RADIUS := 0.8
const RAIN_WET := 0.4
const FETCH_LEAD := 0.5
const FETCH_ARRIVE := 1.0
const FETCH_BERRY_M := 0.3
const FETCH_EXCLAIM_S := 1.8
const BUMP_RANGE := 0.55
const LEDGE_HOP_DROP := 0.4
const BERRY_ORAN_SPRITE := "res://original/assets/sprites/picnic/berry_oran.png"

var companions: Dictionary = {}  ## Mon -> WorldCompanion
var _trail: Array[Vector3] = []  ## mais novo primeiro
var _last_at := Vector3.INF

var _act_now := 0.0
var _still_s := 0.0
var _act_pick_t := 0.0
var _come_owner: WorldCompanion = null

var _fetch_owner: WorldCompanion = null
var _fetch_phase := ""
var _fetch_left := 0.0
var _fetch_spot := Vector3.INF
var _fetch_item := "oran_berry"
var _fetch_sprite := ""
var _fetch_carry: Sprite3D = null
var _fetch_last_s := -1000000000.0
var _fetch_last_tier := "Wary"
var _fetch_last_cave := false
var _drop_n := 0

var _tired_phase: Dictionary = {}  ## Mon -> fase
var _tired_left: Dictionary = {}
var _last_ask: Dictionary = {}
var _tired_frac: Dictionary = {}
var _rest_tick_t := 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	var p := Overworld.player_of(self)
	if p == null:
		return
	_track_trail(p)
	_sync(p)
	_companion_tick(delta, p)
	_fetch_tick(delta, p)
	_tired_tick(delta, p)


## O companheiro desse Mon (null se está na bola).
func companion_of(m: Mon) -> WorldCompanion:
	var c = companions.get(m)
	return c if is_instance_valid(c) and not c.leaving else null


# --- Rastro ---


func _track_trail(p: OverworldPlayer) -> void:
	var at: Vector3 = p.visual_position()
	if _trail.is_empty() or (_last_at.is_finite() and at.distance_to(_last_at) > SNAP):
		_trail = [at, at - p.facing * 1.0]
		for c in companions.values():
			if is_instance_valid(c):
				_place_near(c, p)
	elif Vector2(at.x - _trail[0].x, at.z - _trail[0].z).length() >= TRAIL_STEP:
		_trail.push_front(at)
		if _trail.size() > TRAIL_MAX:
			_trail.resize(TRAIL_MAX)
	_last_at = at


## Ponto do rastro `metres` atrás do ponto mais novo (player.gd trail_point).
func trail_point(metres: float) -> Vector3:
	if _trail.is_empty():
		return global_position
	var acc := 0.0
	for i in range(1, _trail.size()):
		acc += Vector2(_trail[i - 1].x - _trail[i].x, _trail[i - 1].z - _trail[i].z).length()
		if acc >= metres:
			return _trail[i]
	return _trail[-1]


func _place_near(c: WorldCompanion, p: OverworldPlayer) -> void:
	var a := randf() * TAU
	c.global_position = p.global_position + Vector3(cos(a), 0, sin(a)) * 1.2  # respawn_companion
	if c.look and c.look.has_method("reset_motion"):
		c.look.reset_motion()


# --- Game.out -> nós ---


func _sync(p: OverworldPlayer) -> void:
	Game.prune_out()
	for m in companions.keys():
		if not Game.out.has(m):
			var c = companions[m]
			if is_instance_valid(c):
				if c == _fetch_owner:
					_end_fetch()
				c.leave()
			companions.erase(m)
	for m in Game.out:
		if companions.has(m) and is_instance_valid(companions[m]):
			continue
		var c := WorldCompanion.new()
		c.mon = m
		c.manager = self
		c.name = "Companion_%s" % m.species
		add_child(c)
		# send_out do original: cai 2 m à frente do jogador.
		var at: Vector3 = p.global_position + p.facing * 2.0
		at.y = c.ground_y(at, p.global_position.y)
		c.global_position = at
		companions[m] = c


func _outs() -> Array:
	var r: Array = []
	for m in Game.out:
		var c := companion_of(m)
		if c:
			r.append(c)
	return r


func _busy(p: OverworldPlayer) -> bool:
	if Game.is_busy() or p.ui_blocking() or p._world_blocks():
		return true
	var hud := Overworld.hud_of(self)
	return hud != null and hud.has_method("is_dialog_open") and hud.is_dialog_open()


func _picnic() -> bool:
	return get_tree().get_first_node_in_group("picnic") != null


# --- Ações pelo humor (_companion_tick do original) ---


func _companion_tick(delta: float, p: OverworldPlayer) -> void:
	_act_now += delta
	_bump_all(p)
	if _busy(p):
		_clear_actions()
		return
	if _picnic():
		return
	var still := Vector2(p.velocity.x, p.velocity.z).length() < 0.1
	_still_s = _still_s + delta if still else 0.0
	var layout := _ring_layout(p)
	if not still:
		_clear_actions()
		return
	_act_pick_t -= delta
	if _act_pick_t > 0.0:
		return
	_act_pick_t = ACT_PICK_S
	_assign_actions(layout)


func _ring_layout(p: OverworldPlayer) -> Dictionary:
	var outs := _outs()
	var rain := _rain()
	var night := _night()
	for k in outs.size():
		var c: WorldCompanion = outs[k]
		c.ring_slot = k
		c.ring_count = outs.size()
		c.ring_radius = RING_RAIN_RADIUS if rain else RING_RADIUS
		c.come_radius = RING_RAIN_RADIUS if rain else RING_COME_RADIUS
		c.night = night
	return {"outs": outs, "weather": "rain" if rain else "", "night": night}


func _rain() -> bool:
	var w := get_tree().get_first_node_in_group(WorldWeather.GROUP)
	return w != null and not bool(w.get("indoor")) and float(w.get("wet")) > RAIN_WET


func _night() -> bool:
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
	return tod != null and String(tod.get("period")) == "night"


func _assign_actions(layout: Dictionary) -> void:
	var outs: Array = layout["outs"]
	for c: WorldCompanion in outs:
		if c.act != WorldCompanion.Act.NONE:
			continue
		var a := CompanionActions.pick(
			CompanionActions.tier_of(c.mon.friend),
			_still_s,
			outs.size(),
			layout["weather"],
			layout["night"]
		)
		match a:
			CompanionActions.COME:
				# Só um vem até o jogador por vez.
				if (
					_come_owner == null
					or not is_instance_valid(_come_owner)
					or _come_owner.act != WorldCompanion.Act.COME
				):
					_come_owner = c
					c.set_act(WorldCompanion.Act.COME)
			CompanionActions.ORBIT:
				c.set_act(WorldCompanion.Act.ORBIT)
			CompanionActions.NAP:
				c.set_act(WorldCompanion.Act.NAP)
			CompanionActions.PLAY:
				c.set_act(WorldCompanion.Act.PLAY)


func _clear_actions() -> void:
	_come_owner = null
	for c: WorldCompanion in _outs():
		if c.act != WorldCompanion.Act.NONE and not _is_tired_act(c.act):
			if c.act != WorldCompanion.Act.FETCH:
				c.clear_act()


func _is_tired_act(a: int) -> bool:
	return a in [WorldCompanion.Act.ASK, WorldCompanion.Act.SIT, WorldCompanion.Act.REST]


func _bump_all(p: OverworldPlayer) -> void:
	var list := _outs()
	for a in list.size():
		for b in range(a + 1, list.size()):
			_bump_pair(list[a], list[b], false)
	for c in list:
		_bump_pair(c, p, true)


func _bump_pair(a: WorldCompanion, b: Node3D, player_b: bool) -> void:
	var d: float = a.global_position.distance_to(b.global_position)
	if d > BUMP_RANGE or d < 0.001:
		return
	var dir: Vector3 = (a.global_position - b.global_position) / d
	a.bump(dir)
	if not player_b:
		(b as WorldCompanion).bump(-dir)


# --- Busca de fruta (_fetch_tick do original) ---


func _fetch_tick(delta: float, p: OverworldPlayer) -> void:
	if _busy(p) or _picnic():
		_end_fetch()
		return
	if _fetch_owner != null:
		if is_instance_valid(_fetch_owner) and _fetch_owner.act == WorldCompanion.Act.FETCH:
			_fetch_advance(delta, p)
			return
		_end_fetch()
	_fetch_maybe_start(p)


func _fetch_maybe_start(p: OverworldPlayer) -> void:
	if not CompanionActions.fetch_due(_fetch_last_tier, _act_now, _fetch_last_s, _fetch_last_cave):
		return
	var eligible: Array = []
	for c: WorldCompanion in _outs():
		if c.mon.hp > 0 and c.act == WorldCompanion.Act.NONE and not c.hopping:
			eligible.append(c)
	if eligible.is_empty():
		return
	var c: WorldCompanion = eligible[randi() % eligible.size()]
	_start_fetch(c, p, CompanionActions.tier_of(c.mon.friend))


func _start_fetch(c: WorldCompanion, p: OverworldPlayer, tier: String) -> void:
	_fetch_owner = c
	_fetch_phase = CompanionActions.FETCH_SPOT
	_fetch_left = CompanionActions.FETCH_SPOT_S
	_fetch_spot = _fetch_spot_for(p, c)
	_fetch_last_cave = in_cave()
	_fetch_item = CompanionActions.fetch_item(_fetch_last_cave, randi())
	if _fetch_item == CompanionActions.BERRY_ORAN:
		_fetch_sprite = WorldPicnic.berry_for_slot(randi())
	else:
		_fetch_sprite = WorldPicnic.mushroom_for_slot(
			randi(), _fetch_item == CompanionActions.MUSHROOM_BIG
		)
	c.fetch_target = Vector3.INF
	c.set_act(WorldCompanion.Act.FETCH)
	_fetch_last_tier = tier
	_fetch_last_s = _act_now
	c.emote("bang", FETCH_EXCLAIM_S)


func _fetch_advance(delta: float, p: OverworldPlayer) -> void:
	var c := _fetch_owner
	if _fetch_phase == CompanionActions.FETCH_TRAVEL:
		c.fetch_target = _fetch_spot
	elif _fetch_phase == CompanionActions.FETCH_RETURN:
		c.fetch_target = p.global_position
	else:
		c.fetch_target = Vector3.INF
	var arrived: bool = (
		c.fetch_target.is_finite()
		and (
			(
				Vector2(
					c.global_position.x - c.fetch_target.x, c.global_position.z - c.fetch_target.z
				)
				. length()
			)
			<= FETCH_ARRIVE
		)
	)
	var prev := _fetch_phase
	var r: Array = CompanionActions.fetch_step(_fetch_phase, _fetch_left, delta, arrived)
	_fetch_phase = r[0]
	_fetch_left = float(r[1])
	if _fetch_phase == prev:
		return
	match _fetch_phase:
		CompanionActions.FETCH_RETURN:
			_carry(c)
		CompanionActions.FETCH_DELIVER:
			_drop(p)
			_end_fetch()


## A fruta (ou cogumelo) cai no chão à frente do jogador como item para pegar com E.
func _drop(p: OverworldPlayer) -> void:
	var pos: Vector3 = p.global_position + p.facing * FETCH_LEAD
	_drop_n += 1
	var node := ItemBall.new()
	node.uid = "fetch_%d" % _drop_n
	node.item_id = _fetch_item
	node.count = 1
	node.ball_visible = false
	node.npc_name = String(Dex.item(_fetch_item).get("name", _fetch_item))
	node.name = "Fetch_%d" % _drop_n
	var s := _berry_sprite(_fetch_sprite)
	if s:
		s.position.y = 0.15
		node.add_child(s)
	p.get_parent().add_child(node)
	node.global_position = pos


func _berry_sprite(path: String) -> Sprite3D:
	if path == "" or not ResourceLoader.exists(path):
		path = BERRY_ORAN_SPRITE
		if not ResourceLoader.exists(path):
			return null
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = FETCH_BERRY_M / 16.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


func _carry(c: WorldCompanion) -> void:
	var s := _berry_sprite(_fetch_sprite)
	if s == null:
		return
	s.position = Vector3(0, c.head_height() + 0.35, 0)
	c.add_child(s)
	_fetch_carry = s


func _end_fetch() -> void:
	if is_instance_valid(_fetch_owner):
		_fetch_owner.clear_act()
	if is_instance_valid(_fetch_carry):
		_fetch_carry.queue_free()
	_fetch_carry = null
	_fetch_owner = null
	_fetch_phase = ""
	_fetch_left = 0.0
	_fetch_spot = Vector3.INF


## Ponto a 3-5 m do jogador, no mapa e no mesmo nível do chão (até 0,4 m de diferença).
func _fetch_spot_for(p: OverworldPlayer, c: WorldCompanion) -> Vector3:
	var rect := _map_rect()
	for k in 8:
		var a := randf() * TAU
		var d := randf_range(CompanionActions.FETCH_MIN_D, CompanionActions.FETCH_MAX_D)
		var t: Vector3 = p.global_position + Vector3(cos(a), 0.0, sin(a)) * d
		if rect != Rect2() and not rect.grow(2.0).has_point(Vector2(t.x, t.z)):
			continue
		var g := c.ground_hit(t, p.global_position.y)
		if not is_finite(g) or absf(g - p.global_position.y) > LEDGE_HOP_DROP:
			continue
		return Vector3(t.x, g, t.z)
	var a2 := randf() * TAU
	var near: Vector3 = (
		p.global_position + Vector3(cos(a2), 0.0, sin(a2)) * CompanionActions.FETCH_MIN_D
	)
	near.y = c.ground_y(near, p.global_position.y)
	return near


func _world() -> Node:
	return get_tree().get_first_node_in_group(Overworld.GROUP)


func _map_rect() -> Rect2:
	var w := _world()
	if w == null or String(w.get("location_kind")) != "zone" or not w.has_method("zone_rect"):
		return Rect2()
	return w.zone_rect(String(w.get("location_id")))


## Numa caverna (salas do CaveBuilder) ele traz cogumelo e busca 3x menos.
func in_cave() -> bool:
	var w := _world()
	if w == null or String(w.get("location_kind")) != "interior":
		return false
	var rooms = w.get("interiors")
	var room = rooms.get(String(w.get("location_id"))) if rooms is Dictionary else null
	return room != null and is_instance_valid(room) and room.has_meta("cave_dark")


# --- Cansaço e descanso (_tired_tick / rest_with do original) ---


func _tired_tick(delta: float, p: OverworldPlayer) -> void:
	if _busy(p) or _picnic():
		_clear_tired()
		return
	var walking := Vector2(p.velocity.x, p.velocity.z).length() > 0.1
	for c: WorldCompanion in _outs():
		var m := c.mon
		var phase := String(_tired_phase.get(m, CompanionActions.PHASE_NONE))
		if phase == CompanionActions.PHASE_ASK or phase == CompanionActions.PHASE_SIT:
			var step: Array = CompanionActions.ask_step(
				phase, float(_tired_left.get(m, 0.0)), delta
			)
			_tired_phase[m] = step[0]
			_tired_left[m] = float(step[1])
			if int(step[2]) != 0:
				m.set_friend(m.friend + int(step[2]))
			if step[0] != phase:
				if step[0] == CompanionActions.PHASE_SIT:
					c.set_act(WorldCompanion.Act.SIT)
				elif step[0] == CompanionActions.PHASE_NONE:
					c.clear_act()
		elif phase == CompanionActions.PHASE_REST:
			var left := float(_tired_left.get(m, 0.0)) - delta
			_tired_left[m] = left
			if left <= 0.0:
				_tired_phase[m] = CompanionActions.PHASE_NONE
				Game.resting.erase(m)
				c.clear_act()
		elif (
			walking
			and c.act == WorldCompanion.Act.NONE
			and m.hp > 0
			and CompanionActions.tired(m.hp, m.max_hp, m.pp, m.pp_base)
			and CompanionActions.can_ask(_act_now, float(_last_ask.get(m, -1000000000000.0)))
		):
			_tired_phase[m] = CompanionActions.PHASE_ASK
			_tired_left[m] = CompanionActions.ASK_WAIT_S
			_last_ask[m] = _act_now
			c.set_act(WorldCompanion.Act.ASK)
	_rest_tick_t += delta
	while _rest_tick_t >= WorldPicnic.TICK:
		_rest_tick_t -= WorldPicnic.TICK
		_rest_regen_tick()


## E no companheiro que está pedindo: descansam juntos 20 s (+5 de amizade, HP e PP do piquenique).
func rest_with(c: WorldCompanion) -> bool:
	var m := c.mon
	if not Game._can_friend(c.index()) or c.hopping:
		return false
	if String(_tired_phase.get(m, CompanionActions.PHASE_NONE)) != CompanionActions.PHASE_ASK:
		return false
	m.set_friend(m.friend + CompanionActions.REST_FRIEND)
	_tired_phase[m] = CompanionActions.PHASE_REST
	_tired_left[m] = CompanionActions.REST_S
	_last_ask[m] = _act_now
	Game.resting[m] = true
	c.set_act(WorldCompanion.Act.REST)
	return true


func _rest_regen_tick() -> void:
	for m in _tired_phase.keys():
		if String(_tired_phase[m]) != CompanionActions.PHASE_REST or not Game.out.has(m):
			continue
		if m.hp <= 0:
			continue
		var step: Array = WorldPicnic.hp_step(m.hp, m.max_hp, float(_tired_frac.get(m, 0.0)))
		m.hp = int(step[0])
		_tired_frac[m] = float(step[1])
		m.pp = WorldPicnic.pp_step(m.pp, m.pp_base, Game.PP_WORLD_REGEN)


func _clear_tired() -> void:
	var active := false
	for m in _tired_phase.keys():
		if String(_tired_phase[m]) != CompanionActions.PHASE_NONE:
			active = true
		_tired_phase[m] = CompanionActions.PHASE_NONE
		_tired_left[m] = 0.0
	Game.resting.clear()
	if not active:
		return
	for c: WorldCompanion in _outs():
		if _is_tired_act(c.act):
			c.clear_act()
