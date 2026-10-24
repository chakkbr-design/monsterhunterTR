class_name WildMon
extends CharacterBody3D
## Wild mon roaming the map, drawn with the original art (gfx CreatureSprite: PMD Idle/Walk, capsule
## placeholder only if gfx/ is missing). Passive wanders, flee runs, aggressive charges.

const GROUP := "ow_wild"
const LAYER := 4
const SPEED := 2.5  ## creature.gd move_speed (also the CreatureSprite walk-rate base)
const TOUCH := 1.1
const CHASE := 6.0
const FLEE := 5.0
const PEACE_AFTER_RUN := 4.0

enum Behaviour { PASSIVE, FLEE, AGGRESSIVE }

var mon: Mon
var behaviour := Behaviour.PASSIVE
var roams := true  ## false: stays put
var swimmer := false  ## pond mon (SpawnZone mode "swim"): swims about, never leaves the water
var ambusher := false  ## jumped out of tall grass: never roams, always freed after its battle
var peace_timer := 0.0
var home := Vector3.ZERO

var _wander_t := 0.0
var _wander_to := Vector3.ZERO
var _engaging := false
var look: Node3D  ## CreatureSprite (null = placeholder capsule)
var _phys_prev := Vector3.INF  ## last two physics positions: the look is drawn between them (no 60 Hz stepping)
var _phys_cur := Vector3.INF

const CREATURE_SPRITE := "res://gfx/creature_sprite.gd"


static func spawn(m: Mon, entry: Dictionary, parent: Node, pos: Vector3) -> WildMon:
	var w := WildMon.new()
	w.mon = m
	w.behaviour = {"flee": Behaviour.FLEE, "aggressive": Behaviour.AGGRESSIVE}.get(
		String(entry.get("behaviour", "passive")), Behaviour.PASSIVE
	)
	parent.add_child(w)
	w.global_position = pos
	w.home = pos
	w._wander_to = pos
	return w


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = Overworld.WALL_LAYER | SpawnZone.WATER_LAYER
	var r := 0.25 + 0.03 * clampi(mon.level, 1, 10)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = r * 3.0
	col.shape = cap
	col.position.y = r * 1.5
	add_child(col)
	if ResourceLoader.exists(CREATURE_SPRITE):
		look = load(CREATURE_SPRITE).new()
		look.name = "Look"
		look.species = String(mon.species)
		add_child(look)
		return  # the original shows no floating tags; the HUD prompt names the mon
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = r * 3.0
	var types := mon.types
	cm.material = Overworld._mat(
		Dex.type_color(String(types[0])) if not types.is_empty() else Color.GRAY
	)
	mi.mesh = cm
	mi.position.y = r * 1.5
	add_child(mi)
	var tag := Label3D.new()
	tag.text = "%s Nv%d" % [mon.display_name, mon.level]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 72
	tag.outline_size = 14
	tag.modulate = (
		{Behaviour.AGGRESSIVE: Color(1, 0.55, 0.5), Behaviour.FLEE: Color(0.7, 0.85, 1)}
		. get(behaviour, Color.WHITE)
	)
	tag.position.y = r * 3.0 + 0.35
	add_child(tag)


func _physics_process(delta: float) -> void:
	peace_timer = maxf(peace_timer - delta, 0.0)  # also for swimmers (roams = false), or they stay unengageable
	_phys_prev = global_position
	_phys_cur = global_position
	if Game.is_busy() or ambusher or not roams or not visible:
		velocity = Vector3.ZERO
		return
	var dir := _swim_logic(delta) if swimmer else _wander_logic(delta)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = -0.5 if is_on_floor() else velocity.y - OverworldPlayer.GRAVITY * delta
	move_and_slide()
	_phys_cur = global_position
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))


func _process(_delta: float) -> void:
	if look == null:
		return
	if not global_position.is_equal_approx(_phys_cur):  # moved outside physics (spawn, pop-out tween)
		_phys_prev = global_position
		_phys_cur = global_position
	look.position = to_local(
		_phys_prev.lerp(_phys_cur, Engine.get_physics_interpolation_fraction())
	)


func _wander_logic(delta: float) -> Vector3:
	var p := Overworld.player_of(self)
	var to: Vector3 = p.global_position - global_position if p else Vector3.INF
	to.y = 0.0
	var d := to.length()
	# Distance before can_act(): it walks the modal autoloads, too costly for every mon every tick.
	if (
		behaviour != Behaviour.PASSIVE
		and d < maxf(CHASE, FLEE)
		and peace_timer <= 0.0
		and p.can_act()
		and Game.first_healthy() >= 0
	):
		if behaviour == Behaviour.AGGRESSIVE:
			if d < TOUCH:
				engage()
				return Vector3.ZERO
			if d < CHASE:
				return to.normalized()
		if behaviour == Behaviour.FLEE and d < FLEE:
			return -to.normalized() * 1.3
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander_to = home + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		if randf() < 0.35:
			_wander_to = global_position
	var v := _wander_to - global_position
	v.y = 0.0
	return Vector3.ZERO if v.length() < 0.2 else v.normalized() * 0.6


## SpawnZone "swim": water no longer blocks it, and its wander stays inside the water
## (original spawn_zone.gd:79-86 + combatant swim).
func make_swimmer() -> void:
	swimmer = true
	collision_mask = Overworld.WALL_LAYER


func _in_water(at: Vector3) -> bool:
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = at + Vector3(0, 0.5, 0)
	pq.collision_mask = SpawnZone.WATER_LAYER
	return not get_world_3d().direct_space_state.intersect_point(pq, 1).is_empty()


func _swim_logic(delta: float) -> Vector3:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 3.5)
		_wander_to = global_position
		if randf() >= 0.35:
			for i in 6:
				var c := home + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
				if _in_water(c):
					_wander_to = c
					break
	var v := _wander_to - global_position
	v.y = 0.0
	if v.length() < 0.2:
		return Vector3.ZERO
	if not _in_water(global_position + v.normalized() * 0.6):
		_wander_to = global_position  # the shore: wait for the next goal
		return Vector3.ZERO
	return v.normalized() * 0.6


## Pop-up tween for grass ambushes.
func pop_out() -> void:
	var at := position
	position = at + Vector3(0, -0.8, 0)
	var tw := create_tween()
	(
		tw
		. tween_property(self, "position", at + Vector3(0, 1.3, 0), 0.2)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tw.tween_property(self, "position", at, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await tw.finished


## Starts a wild battle against this mon. Freed afterwards unless the player ran away.
func engage() -> void:
	if _engaging:
		return
	var ow := Overworld.of(self)
	if ow == null:
		return
	_engaging = true
	var p := Overworld.player_of(self)
	if p:
		p.face_toward(global_position)
	visible = false  # the arena spawns its own body for the enemy
	var r := await ow.battle([mon], {"kind": "wild", "can_run": true})
	_engaging = false
	if not ambusher and (r.is_empty() or String(r.get("outcome", "")) == "run"):
		visible = true
		peace_timer = PEACE_AFTER_RUN
		return
	queue_free()
