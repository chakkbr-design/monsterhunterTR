class_name OverworldPlayer
extends CharacterBody3D
## Overworld avatar: camera-relative movement, sprint, jump, tall-grass rolls and interaction focus.

const GROUP := "ow_player"
const LAYER := 2
const MASK := 1 | 8 | 16  # walls + NPCs + water (MapBuilder.WATER_LAYER)
const GRAVITY := 20.0
const TALK_RANGE := 2.0
const ENGAGE_RANGE := 3.5

@export var walk_speed := 4.0
@export var run_speed := 7.0
@export var jump_velocity := 7.0
@export var color := Color(0.85, 0.2, 0.2)

var locked := false  ## scripted freeze (dialogue, ambush alert, trainer spotted)
var facing := Vector3.FORWARD
var enc := EncounterRate.new()
var focus: Node3D

var _grass: Array[TallGrass] = []
var _rng := RandomNumberGenerator.new()
var _model: Node3D
var _alert: Label3D
var sprite: CharSprite  ## the original trainer sheet (walk / run), null = capsule placeholder
var _phys_prev := Vector3.ZERO  ## body position at the last two physics ticks: the visuals are drawn
var _phys_cur := Vector3.ZERO  ## between them so they don't step at the physics rate on faster screens
var _step_t := 0.0  ## footstep clock: each footstep spends one Repel step (original player.gd:124-134)


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	_rng.randomize()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	add_child(col)
	_model = Node3D.new()
	add_child(_model)
	_build_look()
	_alert = WorldNpc.make_alert(2.3)
	add_child(_alert)
	Game.battle_finished.connect(_on_battle_finished)
	_phys_prev = global_position
	_phys_cur = global_position


## Original trainer sheet (red, or green for a girl) with its run sheet; capsule if missing.
func _build_look() -> void:
	var girl := String(Game.get("player_gender")) in ["female", "girl", "f", "menina"]
	var walk := CharSprite.sheet("trainer_green.png" if girl else "trainer.png")
	if walk:
		sprite = CharSprite.make(
			walk, CharSprite.sheet("trainer_green_run.png" if girl else "trainer_run.png")
		)
		sprite.follow_parent = false
		add_child(sprite)
		return
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.6
	cm.material = Overworld._mat(color)
	body.mesh = cm
	body.position.y = 0.8
	_model.add_child(body)
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.18, 0.3)
	bm.material = Overworld._mat(Color(0.1, 0.1, 0.1))
	nose.mesh = bm
	nose.position = Vector3(0, 1.45, -0.3)  # cap brim marks the facing
	_model.add_child(nose)


func _on_battle_finished(_r: Dictionary) -> void:
	enc.battle_ended()


func can_act() -> bool:
	return not locked and not Game.is_busy() and not ui_blocking() and not _world_blocks()


## True while a modal UI autoload (LearnMove, PauseMenu) is open. Both are optional.
func ui_blocking() -> bool:
	for path in ["/root/LearnMove", "/root/PauseMenu", "/root/PCStorage", "/root/Evolution"]:
		var n := get_node_or_null(path)
		if n and n.has_method("is_open") and n.is_open():
			return true
	var st := get_node_or_null("/root/Story")
	if st and st.has_method("is_running") and st.is_running():
		return true
	return false


func _world_blocks() -> bool:
	var ow := Overworld.of(self)
	return ow != null and ow.blocks_player()


func show_alert(on: bool) -> void:
	_alert.visible = on


func face_toward(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length() > 0.01:
		facing = to.normalized()


func _physics_process(delta: float) -> void:
	var active := can_act()
	var dir := Vector3.ZERO
	if active:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, _camera_yaw())
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = jump_velocity if active and Input.is_action_just_pressed("jump") else -0.5
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	_phys_prev = before
	move_and_slide()
	_phys_cur = global_position
	if dir.length() > 0.1:
		facing = dir.normalized()
	if sprite:
		var run := Input.is_action_pressed("sprint") and dir.length() > 0.1
		sprite.facing = facing
		sprite.moving = dir.length() > 0.1 and is_on_floor()
		sprite.speed = run_speed if run else walk_speed
		sprite.set_running(run)
	_model.rotation.y = lerp_angle(
		_model.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-14.0 * delta)
	)
	var moving := dir.length() > 0.1
	_footstep(delta, moving and active and is_on_floor(), Input.is_action_pressed("sprint"))
	if active and not _grass.is_empty():
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		var patch: TallGrass = _grass[-1]
		if enc.walk(moved, WildTable.rate(patch.table()), _rng, _repelled()):
			_ambush(patch)
	if active:
		_party_keys()
	_update_focus(active)


## Teclas 1-6 fora da batalha (_party_key do original): manda ou recolhe aquele Pokémon.
func _party_keys() -> void:
	for i in Game.PARTY_MAX:
		var a := "party_%d" % (i + 1)
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			var msg: String = Game.party_key(i)
			var hud := Overworld.hud_of(self)
			if msg != "" and hud:
				hud.toast(msg, 2.5)


## Original footstep cadence (0.32 s walking, 0.24 s running): each one spends a Repel step.
func _footstep(delta: float, stepping: bool, running: bool) -> void:
	var gap := 0.24 if running else 0.32
	if not stepping:
		_step_t = gap
		return
	_step_t += delta
	if _step_t < gap:
		return
	_step_t = 0.0
	var g := get_node_or_null("/root/Game")
	if g and g.has_method("repel_step") and g.repel_step():
		var hud := Overworld.hud_of(self)
		if hud:
			hud.toast("O efeito do Repel acabou.", 2.5)


## Repel on: no tall-grass encounters at all (original player.gd:211, _grass_step).
func _repelled() -> bool:
	var g := get_node_or_null("/root/Game")
	return g != null and g.has_method("repel_active") and g.repel_active()


## Where the player is drawn this frame (between the last two physics ticks). Camera and follower track this.
func visual_position() -> Vector3:
	if not global_position.is_equal_approx(_phys_cur):  # teleported outside physics: no blending
		_phys_prev = global_position
		_phys_cur = global_position
	return _phys_prev.lerp(_phys_cur, Engine.get_physics_interpolation_fraction())


func _process(_delta: float) -> void:
	var off := to_local(visual_position())
	_model.position = off
	_alert.position = off + Vector3(0, 2.3, 0)
	if sprite:
		sprite.position = off


func _camera_yaw() -> float:
	var rig := get_tree().get_first_node_in_group(OverworldCamera.GROUP) as OverworldCamera
	return rig.yaw() if rig else 0.0


## O mais perto de [node, alcance, cone] na frente do jogador (ou a menos de 1,3 m).
func _nearest(cands: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c in cands:
		var to: Vector3 = c[0].global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < c[1] and d < best_d and (d < 1.3 or facing.dot(to / maxf(d, 0.001)) > c[2]):
			best = c[0]
			best_d = d
	return best


func _update_focus(active: bool) -> void:
	var cands: Array = []  # [node, reach, cone]
	for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		cands.append([n, TALK_RANGE, 0.4])
	if not Game.party.is_empty():
		for w in get_tree().get_nodes_in_group(WildMon.GROUP):
			if w.visible and w.peace_timer <= 0.0:
				cands.append([w, ENGAGE_RANGE, 0.5])
	var best: Node3D = _nearest(cands)
	if best == null:  # E carinho, F comida; NPCs e selvagens têm a vez (o companheiro anda colado)
		var mine: Array = []
		for c in get_tree().get_nodes_in_group(WorldCompanion.GROUP):
			if c.visible:
				mine.append([c, TALK_RANGE, 0.4])
		best = _nearest(mine)
	focus = best
	var hud := Overworld.hud_of(self)
	if hud == null:
		return
	hud.set_prompt(_prompt_for(focus) if active and focus else "")
	if active and focus and hud.can_interact() and Input.is_action_just_pressed("interact"):
		_interact(focus)
	elif (
		active
		and focus is WorldCompanion
		and InputMap.has_action("feed")
		and Input.is_action_just_pressed("feed")
	):
		(focus as WorldCompanion).feed()


func _prompt_for(n: Node3D) -> String:
	if n is WildMon:
		return "E: Batalhar com %s" % (n as WildMon).mon.display_name
	if n.has_method("prompt"):
		return n.prompt()
	return "E: Falar"


func _interact(n: Node3D) -> void:
	if n is WildMon:
		(n as WildMon).engage()
		return
	locked = true
	face_toward(n.global_position)
	await n.interact(self)
	locked = false


func _ambush(patch: TallGrass) -> void:
	if Game.party.is_empty():
		return
	var entry := WildTable.pick(patch.table(), "grass", _rng)
	if entry.is_empty():
		return
	locked = true
	patch.shake()
	show_alert(true)
	await get_tree().create_timer(0.6).timeout
	show_alert(false)
	var w := WildMon.spawn(
		Overworld.mon_from_entry(entry, _rng), entry, get_parent(), global_position + facing * 2.2
	)
	w.ambusher = true
	await w.pop_out()
	await w.engage()
	locked = false


func enter_grass(patch: TallGrass) -> void:
	if not _grass.has(patch):
		if _grass.is_empty():
			enc.enter_grass()
		_grass.append(patch)


func exit_grass(patch: TallGrass) -> void:
	_grass.erase(patch)
