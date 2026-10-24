class_name WorldPicnic
extends Node3D
## Piquenique do menu de pausa (world/picnic.gd do original): toalha e cesta no chão, todos os
## Pokémon de pé saem da bola e sentam em roda com uma fruta cada; enquanto o jogador não anda eles
## recuperam HP (2% a cada 3 s) e PP (4x o ritmo do mundo), e quem ficar 20 s ganha +10 de amizade.
## Andar (ou uma batalha) encerra.

const TICK := 0.25
const HP_RATE := 0.02
const HP_WINDOW := 3.0
const PP_MULT := 4.0
const FRIEND_BONUS := 10
const FRIEND_STAY_S := 20.0

const CLOTH := Vector2(3.2, 2.4)
const CLOTH_TEX := "res://original/assets/textures/picnic_cloth.png"
const BASKET_TEX := "res://original/assets/sprites/picnic/basket.png"
const CLOTH_Y := 0.02
const RING_RADIUS := 0.95
const SIT_RADIUS := 0.7
const RING_COME := 1.0
const IN_S := 0.2
const OUT_S := 0.2
const SETTLE_S := 1.0
const SEND_WAIT_S := 3.0
const APPLY_S := 0.5
const CHASE_LOOP_A := 1.7
const CHASE_LOOP_B := 1.3
const CHASE_ANG_RATE := 1.5
const EAT_DIST := 0.6
const EAT_WAIT_S := 5.0
const BASKET_M := 0.5
const BERRY_M := 0.3

const BERRY_SPRITES := [
	"res://original/assets/sprites/picnic/berry_oran.png",
	"res://original/assets/sprites/picnic/berry_sitrus.png",
	"res://original/assets/sprites/picnic/berry_leppa.png",
	"res://original/assets/sprites/picnic/berry_lum.png",
]
const MUSHROOM_TINY_SPRITES := [
	"res://original/assets/sprites/prop_mushroom_tiny_tan.png",
	"res://original/assets/sprites/prop_mushroom_tiny_blue.png",
	"res://original/assets/sprites/prop_mushroom_tiny_cluster.png",
	"res://original/assets/sprites/prop_mushroom_tiny_pair.png",
]
const MUSHROOM_BIG_SPRITES := [
	"res://original/assets/sprites/prop_mushroom_big_red.png",
	"res://original/assets/sprites/prop_mushroom_big_violet.png",
	"res://original/assets/sprites/prop_mushroom_big_orange.png",
]

## Sem leitura de teclado (testes): end() só quando chamado.
var manual := false

var _player: OverworldPlayer
var _prop: Node3D
var _t := 0.0
var _regen_t := 0.0
var _settle_t := SETTLE_S
var _eat_t := 0.0
var _ended := false
var _stay: Dictionary = {}  ## Mon -> s no piquenique
var _hp_frac: Dictionary = {}
var _ring_ready := false
var _expected := 0
var _berries: Dictionary = {}  ## Mon -> Sprite3D
var _fed: Dictionary = {}
var _act_of: Dictionary = {}
var _apply_t := 0.0
var _chase_angle_of: Dictionary = {}
var _chasers: Array = []


static func hp_gain(max_hp: int) -> float:
	return float(max_hp) * HP_RATE * (TICK / HP_WINDOW)


static func pp_gain(pp_base: float, world_regen: float) -> float:
	return pp_base * world_regen * PP_MULT * TICK


static func hp_step(hp: int, max_hp: int, frac: float) -> Array:
	var f := frac + hp_gain(max_hp)
	var whole := int(floor(f))
	if whole > 0:
		f -= float(whole)
		hp = mini(max_hp, hp + whole)
	return [hp, f]


static func pp_step(pp: float, pp_base: float, world_regen: float) -> float:
	return minf(pp_base, pp + pp_gain(pp_base, world_regen))


static func friend_bonus(stayed_s: float) -> int:
	return FRIEND_BONUS if stayed_s >= FRIEND_STAY_S else 0


static func berry_for_slot(slot: int) -> String:
	return BERRY_SPRITES[posmod(slot, BERRY_SPRITES.size())]


static func mushroom_for_slot(slot: int, big: bool) -> String:
	var arr := MUSHROOM_BIG_SPRITES if big else MUSHROOM_TINY_SPRITES
	return arr[posmod(slot, arr.size())]


static func berry_offset(slot: int, count: int) -> Vector3:
	var n := maxi(count, 1)
	var ang := TAU * float(slot) / float(n)
	return Vector3(cos(ang), 0.0, sin(ang)) * RING_RADIUS


## _can_picnic do menu do original: alguém fora da bola e o jogador em chão firme.
static func can_start(p: OverworldPlayer) -> bool:
	if p == null or not is_instance_valid(p) or Game.out.is_empty():
		return false
	return p.is_on_floor() and not p.ui_blocking() and not Game.is_busy()


func begin(player: OverworldPlayer) -> void:
	_player = player
	add_to_group("picnic")
	global_position = player.global_position
	_build_prop()
	player.locked = true
	player.velocity = Vector3.ZERO
	_prop.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(_prop, "scale", Vector3.ONE, IN_S).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_send_all()


func _send_all() -> void:
	_expected = 0
	for i in Game.party.size():
		if Game.party[i].hp > 0:
			_expected += 1
	for i in Game.party.size():
		if not Game.is_out(i) and Game.party[i].hp > 0:
			Game.send_out(i)


func is_active() -> bool:
	return not _ended


func _process(delta: float) -> void:
	if _ended:
		return
	_t += delta
	if (not manual and _movement_input()) or Game.is_busy():
		end()
		return
	_track(delta)
	if not _ring_ready:
		if _outs().size() >= _expected or _t >= SEND_WAIT_S:
			_setup_ring()
			_ring_ready = true
	elif _settle_t > 0.0:
		_settle_t -= delta
	else:
		_eat_tick(delta)
		_assign_tick(delta)
		_chase_tick(delta)
	_regen_t += delta
	while _regen_t >= TICK:
		_regen_t -= TICK
		_regen_tick()


func _movement_input() -> bool:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1


func end() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group("picnic")
	for m in _stay.keys():
		if friend_bonus(float(_stay[m])) > 0 and Game.out.has(m):
			m.set_friend(m.friend + FRIEND_BONUS)
	for c in _companions():
		c.clear_act()
	for b in _berries.values():
		if is_instance_valid(b):
			b.queue_free()
	_berries.clear()
	if is_instance_valid(_player):
		_player.locked = false
	if _prop == null:
		queue_free()
		return
	var tw := create_tween()
	(
		tw
		. tween_property(_prop, "scale", Vector3.ONE * 0.05, OUT_S)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tw.tween_callback(queue_free)


## Mons fora da bola que já têm o nó no mundo.
func _outs() -> Array:
	var r: Array = []
	var mgr := _manager()
	for m in Game.out:
		if mgr == null or mgr.companion_of(m) != null:
			r.append(m)
	return r


func _companions() -> Array:
	var r: Array = []
	var mgr := _manager()
	if mgr == null:
		return r
	for m in Game.out:
		var c = mgr.companion_of(m)
		if c:
			r.append(c)
	return r


func _manager() -> WorldFollower:
	return get_tree().get_first_node_in_group(WorldFollower.GROUP) as WorldFollower


func _companion(m: Mon) -> WorldCompanion:
	var mgr := _manager()
	return mgr.companion_of(m) if mgr else null


func _setup_ring() -> void:
	var outs := _outs()
	for k in outs.size():
		var m: Mon = outs[k]
		var c := _companion(m)
		if c:
			c.clear_act()
			c.ring_slot = k
			c.ring_count = outs.size()
			c.ring_radius = RING_RADIUS
			c.come_radius = RING_COME
		_stay[m] = 0.0
		_hp_frac[m] = 0.0
		_fed[m] = false
		_act_of[m] = ""
		var b := _make_berry(k, outs.size())
		if b:
			_berries[m] = b
			_prop.add_child(b)
	_settle_t = SETTLE_S


func _assign_act(m: Mon, a: String) -> void:
	var c := _companion(m)
	if c == null or String(_act_of.get(m, "")) == a:
		return
	_act_of[m] = a
	if a != CompanionActions.PICNIC_CHASE:
		c.chase_goal = Vector3.INF
		_chase_angle_of.erase(m)
	match a:
		CompanionActions.PICNIC_CHASE:
			c.set_act(WorldCompanion.Act.PLAY)
		CompanionActions.PICNIC_NAP:
			c.set_act(WorldCompanion.Act.NAP)
		CompanionActions.PICNIC_SIT:
			c.set_act(WorldCompanion.Act.SIT)
			c.sit_target = _sit_target(c)
		_:
			c.set_act(WorldCompanion.Act.CHAT)


func _assign_tick(delta: float) -> void:
	_apply_t += delta
	if _apply_t < APPLY_S:
		return
	_apply_t = 0.0
	var acts := activities()
	_chasers = []
	for m in _outs():
		_assign_act(m, String(acts.get(m, CompanionActions.PICNIC_SIT)))
		if String(acts.get(m, "")) == CompanionActions.PICNIC_CHASE:
			_chasers.append(m)


## Atividade de cada Mon fora da bola agora (CompanionActions.picnic_assign).
func activities() -> Dictionary:
	var outs := _outs()
	var mons: Array = []
	for m in outs:
		(
			mons
			. append(
				{
					"hp": _frac(float(m.hp), float(m.max_hp)),
					"pp": _frac(float(m.pp), float(m.pp_base)),
					"mood": CompanionActions.tier_of(m.friend),
				}
			)
		)
	var acts: Array = CompanionActions.picnic_assign(mons, _t)
	var out := {}
	for k in outs.size():
		out[outs[k]] = acts[k]
	return out


static func _frac(value: float, base: float) -> float:
	return 1.0 if base <= 0.0 else value / base


## Os que brincam correm numa elipse em volta do jogador.
func _chase_tick(delta: float) -> void:
	if _chasers.size() < 2 or not is_instance_valid(_player):
		return
	for slot in _chasers.size():
		var m: Mon = _chasers[slot]
		var c := _companion(m)
		if c == null:
			continue
		if c.act != WorldCompanion.Act.PLAY:
			c.set_act(WorldCompanion.Act.PLAY)
		var d := c.global_position - _player.global_position
		var ang: float = float(
			_chase_angle_of.get(m, atan2(d.z / CHASE_LOOP_B, d.x / CHASE_LOOP_A))
		)
		ang = fposmod(ang + CHASE_ANG_RATE * delta, TAU)
		_chase_angle_of[m] = ang
		var goal: Vector3 = (
			_player.global_position + Vector3(cos(ang) * CHASE_LOOP_A, 0.0, sin(ang) * CHASE_LOOP_B)
		)
		goal.y = _player.global_position.y
		c.chase_goal = goal


func _sit_target(c: WorldCompanion) -> Vector3:
	var n := maxi(c.ring_count, 1)
	var ang := TAU * float(c.ring_slot) / float(n)
	var t: Vector3 = _player.global_position + Vector3(cos(ang), 0.0, sin(ang)) * SIT_RADIUS
	t.y = _player.global_position.y
	return t


## Cada um come a sua fruta ao chegar perto dela (ou depois de 5 s a fruta some).
func _eat_tick(delta: float) -> void:
	_eat_t += delta
	for m in _berries.keys():
		if _fed.get(m, false):
			continue
		var c := _companion(m)
		var berry = _berries[m]
		var arrived: bool = (
			c != null
			and is_instance_valid(berry)
			and c.global_position.distance_to(berry.global_position) < EAT_DIST
		)
		if arrived or _eat_t >= EAT_WAIT_S:
			if arrived:
				c.react_feed()
			if is_instance_valid(berry):
				berry.queue_free()
			_berries[m] = null
			_fed[m] = true
			_assign_act(m, String(activities().get(m, CompanionActions.PICNIC_SIT)))


func _track(delta: float) -> void:
	for m in _stay.keys():
		if not Game.out.has(m):
			_stay.erase(m)
			_hp_frac.erase(m)
			continue
		_stay[m] = float(_stay[m]) + delta


## A cada 0,25 s: HP pelo hp_step e PP 4x o ritmo do mundo para quem está fora da bola.
func _regen_tick() -> void:
	for m in Game.out:
		if m.hp <= 0:
			continue
		var step := hp_step(m.hp, m.max_hp, float(_hp_frac.get(m, 0.0)))
		m.hp = int(step[0])
		_hp_frac[m] = float(step[1])
		m.pp = pp_step(m.pp, m.pp_base, Game.PP_WORLD_REGEN)


func stayed(m: Mon) -> float:
	return float(_stay.get(m, 0.0))


func _build_prop() -> void:
	_prop = Node3D.new()
	_prop.name = "PicnicProp"
	add_child(_prop)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = CLOTH
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(CLOTH_TEX):
		mat.albedo_texture = load(CLOTH_TEX)
	else:
		mat.albedo_color = Color(0.85, 0.3, 0.3)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.material = mat
	mi.mesh = pm
	mi.position.y = CLOTH_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prop.add_child(mi)
	if ResourceLoader.exists(BASKET_TEX):
		var s := Sprite3D.new()
		s.texture = load(BASKET_TEX)
		s.pixel_size = BASKET_M / 24.0
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.offset = Vector2(0, 12)
		s.position = Vector3(CLOTH.x * 0.5 - 0.35, CLOTH_Y, -(CLOTH.y * 0.5 - 0.35))
		_prop.add_child(s)


func _make_berry(slot: int, count: int) -> Sprite3D:
	var path := berry_for_slot(slot)
	if not ResourceLoader.exists(path):
		return null
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = BERRY_M / 16.0
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	s.position = berry_offset(slot, count) + Vector3(0.0, CLOTH_Y + 0.02, 0.0)
	return s
