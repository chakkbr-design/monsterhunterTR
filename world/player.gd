class_name OverworldPlayer
extends CharacterBody3D
## Overworld avatar: camera-relative movement, sprint, tall-grass rolls and interaction focus (no jump,
## like the original player.gd; ledges hop on their own).
##
## Grid zones (docs/VOXEL.md §6, Overworld.grid_at not null) walk Pokémon-style instead: four
## directions, one 1 m tile at a time. A tap turns; holding walks after TURN_DELAY (at once when the key
## matches the facing); held steps chain at constant speed with no stop frame; walk_speed / run_speed
## as in free zones. Walls, water, ledges and doors come from the TileGrid; people, signs and pets on
## the NPC layer block the tile they stand in, and NPC claims keep walkers apart. Pushing into a wall
## bumps, into a door enters it, off a ledge hops two tiles. Grass rolls once per tile, Repel counts
## tiles, E talks to the tile ahead. Positions written by anything else (Story tweens, the battle
## arena, teleports, tests) are noticed, and the player glides (or snaps) back onto a free tile centre
## once it may move. The body moves kinematically in XZ, so no curb or wandering pet can trap it
## between tiles; move_and_slide only refreshes the floor contact.

signal step_finished(cell: Vector2i)  ## grid zones: reached the centre of a tile
signal walk_done  ## a grid_walk reached its last tile

const GROUP := "ow_player"
const LAYER := 2
const MASK := 1 | 8 | 16  # walls + NPCs + water (MapBuilder.WATER_LAYER)
const GRAVITY := 20.0
const TALK_RANGE := 2.0
const ENGAGE_RANGE := 3.5
const TURN_DELAY := 0.1  ## grid: a press of a new direction shorter than this only turns
const ARRIVE_HOLD := 0.2  ## grid: movement input ignored this long after being put down (warps)
const BUMP_GAP := 0.4  ## grid: seconds between bump sounds while pushing into something
const SNAP_FAR := 1.6  ## grid: farther than this off a free tile centre, snap instead of gliding
const INTERACT_BUFFER := 0.25  ## grid: an E pressed mid-step still talks when the step ends
const HOP_TIME := 0.5  ## grid: the two-tile ledge hop
const MOVES := {
	"move_forward": Vector2i(0, -1),
	"move_back": Vector2i(0, 1),
	"move_left": Vector2i(-1, 0),
	"move_right": Vector2i(1, 0)
}
const Synth := preload("res://audio/synth.gd")

## Tests: "grid" walks every outdoor zone of a RouteWorld on the grid, "free" none, "" follows each
## zone (its map's "movement" or baked grid).
static var force_mode := ""
## Tests: zone id -> "grid" | "free", over force_mode and the map.
static var force_zones: Dictionary = {}
static var _bump_wav: AudioStreamWAV

@export var walk_speed := 4.0
@export var run_speed := 7.0
@export var color := Color(0.85, 0.2, 0.2)

var locked := false  ## scripted freeze (dialogue, ambush alert, trainer spotted)
var facing := Vector3.FORWARD  ## unit XZ vector; one of the four axes in grid zones
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
var _tick_end := Vector3.INF  ## position at the end of the last physics tick (spots Story tweens)

# Grid movement.
var _grid: TileGrid  ## grid of the tile stood on (null = free movement)
var _cell := Vector2i.ZERO  ## logical tile: the one stood on, or the target while stepping
var _prev_cell := Vector2i.ZERO  ## the tile being left while stepping
var _stepping := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _seg := 1.0
var _t := 0.0
var _step_speed := 4.0
var _step_run := false
var _scripted := false  ## the current step belongs to a grid_walk
var _glide := false  ## the current step only puts the body back onto its tile centre
var _parity := 0  ## alternates the foot of each step
var _turn_wait := 0.0
var _arrive_hold := 0.0
var _bumping := false
var _bump_cd := 0.0
var _settle := false  ## off the tile centre: glide back when free to move
var _place_snap := false  ## inside something or far off: snap to the nearest free tile
var _last_written := Vector3.INF  ## where the grid tick left the body (anything else moved it)
var _held: Array[String] = []  ## held move actions, the last pressed last
var _script: Array[Vector2i] = []  ## grid_walk tiles still to walk
var _script_active := false
var _script_speed := 3.5
var _interact_buf := 0.0
var _just_placed := false
var _bump_player: AudioStreamPlayer


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


## Turns toward `pos` (onto the nearest of the four axes in grid zones).
func face_toward(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length() > 0.01:
		facing = to.normalized()
		if _grid:
			facing = GridMotion.vec(GridMotion.card(to))


func _physics_process(delta: float) -> void:
	var g := _grid if _stepping else _grid_now()
	if g == null:
		if _grid != null:
			_leave_grid()
		_free_tick(delta)
		return
	_grid = g
	_grid_tick(delta)


## Free movement (every zone not on the grid): analog, camera-relative, move_and_slide.
func _free_tick(delta: float) -> void:
	var active := can_act()
	# A Story / trainer tween moved the locked body since the last tick: the sheet walks with it.
	var tweened := (
		not active
		and _tick_end.is_finite()
		and (
			Vector2(global_position.x - _tick_end.x, global_position.z - _tick_end.z).length()
			> 0.3 * delta
		)
	)
	var dir := Vector3.ZERO
	if active:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, _camera_yaw())
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	_phys_prev = before
	move_and_slide()
	_phys_cur = global_position
	_tick_end = global_position
	if dir.length() > 0.1:
		facing = dir.normalized()
	if sprite:
		var run := Input.is_action_pressed("sprint") and dir.length() > 0.1
		sprite.facing = facing
		sprite.moving = (dir.length() > 0.1 and is_on_floor()) or tweened
		sprite.speed = run_speed if run else walk_speed
		sprite.step_col = -1
		sprite.set_running(run)
	_turn_model(delta)
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


func _turn_model(delta: float) -> void:
	_model.rotation.y = lerp_angle(
		_model.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-14.0 * delta)
	)


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
	_repel_step()


## One Repel step (a footstep in free zones, a tile in grid zones), with the toast when it runs out.
func _repel_step() -> void:
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


## O mais perto de [node, alcance, cone] na frente do jogador (ou a menos de `omni` m).
func _nearest(cands: Array, omni := 1.3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c in cands:
		var to: Vector3 = c[0].global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < c[1] and d < best_d and (d < omni or facing.dot(to / maxf(d, 0.001)) > c[2]):
			best = c[0]
			best_d = d
	return best


func _update_focus(active: bool) -> void:
	var grid := _grid != null
	var best: Node3D = null
	if grid:
		# The tile ahead first; then only about straight ahead within the next tile.
		best = _grid_focus()
		if best == null:
			var near: Array = []
			for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
				near.append([n, 1.5, 0.75])
			best = _nearest(near, 0.0)
	if best == null:
		var cands: Array = []  # [node, reach, cone]
		if not grid:
			for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
				cands.append([n, TALK_RANGE, 0.4])
		if not Game.party.is_empty():
			for w in get_tree().get_nodes_in_group(WildMon.GROUP):
				if w.visible and w.peace_timer <= 0.0:
					cands.append([w, ENGAGE_RANGE, 0.5])
		best = _nearest(cands)
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
	var idle := active and not (grid and (_stepping or _settle))
	# Only a press the HUD would take is kept: above 60 Hz the E that closed a dialogue can reach
	# the next physics tick with the player already free, and a buffered copy of it outlived the
	# HUD's re-arm and opened the same dialogue again.
	if grid and active and Input.is_action_just_pressed("interact") and hud.can_interact():
		_interact_buf = INTERACT_BUFFER
	hud.set_prompt(_prompt_for(focus) if idle and focus else "")
	var pressed := Input.is_action_just_pressed("interact") or (grid and _interact_buf > 0.0)
	if idle and focus and hud.can_interact() and pressed:
		_interact_buf = 0.0
		_interact(focus)
	elif (
		idle
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


# --- grid movement (docs/VOXEL.md §6) -------------------------------------------------------------


## True while the player walks on the tile grid.
func grid_active() -> bool:
	return _grid != null


## Where a save should put the player: the tile centre stood on (the target tile while stepping) in
## grid zones, the body position elsewhere.
func save_position() -> Vector3:
	if _grid == null:
		return global_position
	var c := _center(_cell)
	return c if c.is_finite() else global_position


## Tiles the player holds (NPCs never step there): the one stood on, plus the one being left mid-step.
func occupied_cells() -> Array[Vector2i]:
	if _grid == null:
		return [TileGrid.cell_of(global_position)]
	var out: Array[Vector2i] = [_cell]
	if _stepping and _prev_cell != _cell:
		out.append(_prev_cell)
	return out


## RouteWorld._put_player: the body was just put down (spawn, door, warp, load). Drops any step,
## takes the tile under it and ignores movement for ARRIVE_HOLD, so a key still held from the trip
## does not walk straight back out through the door.
func on_placed() -> void:
	_stepping = false
	_bumping = false
	_settle = false
	_place_snap = false
	_turn_wait = 0.0
	_arrive_hold = ARRIVE_HOLD
	_finish_script()
	_grid = _grid_now()
	_cell = TileGrid.cell_of(global_position)
	_prev_cell = _cell
	_phys_prev = global_position
	_phys_cur = global_position
	_last_written = global_position
	_tick_end = global_position
	_just_placed = true
	if _grid:
		if GridMotion.card(facing) != Vector2i.ZERO:
			facing = GridMotion.vec(GridMotion.card(facing))
		_moved_outside()


## Waits (a second at most) for a step in progress to end, so a cutscene starts on a tile centre.
func settle() -> void:
	var n := 0
	while _stepping and not _scripted and n < 60 and is_inside_tree():
		await get_tree().physics_frame
		n += 1


## After a cutscene: back onto a free tile centre (a glide once the player may move again).
func resnap() -> void:
	if _grid and not _stepping:
		_moved_outside()


## Story walk in grid zones: tile by tile, axis-aligned (the longer leg last; last_axis 0 = end along
## x, 1 = along z), animated, through anything like the old tweens; returns on the target tile centre.
## Elsewhere the old straight tween.
func grid_walk(to: Vector3, speed := 3.5, last_axis := -1) -> void:
	if _grid == null:
		_grid = _grid_now()
	if _grid == null or not is_inside_tree():
		await StoryNpc.tween_node(self, to, speed)
		return
	_finish_script()
	if not _stepping and not global_position.is_equal_approx(_last_written):
		_moved_outside()
	var path := GridMotion.axis_path(_cell, TileGrid.cell_of(to), last_axis)
	if path.is_empty() and not _stepping and _settle:
		path = [_cell]  # just back onto the centre
	if path.is_empty() and not _stepping:
		return
	_script = path
	_script_speed = speed
	_script_active = true
	await walk_done


func _finish_script() -> void:
	_script.clear()
	if _script_active:
		_script_active = false
		walk_done.emit()


func _grid_now() -> TileGrid:
	if force_mode == "free" or not is_inside_tree():
		return null
	var ow := Overworld.of(self)
	return ow.grid_at(global_position) if ow else null


func _leave_grid() -> void:
	_grid = null
	_stepping = false
	_bumping = false
	_settle = false
	_place_snap = false
	_finish_script()
	if sprite:
		sprite.step_col = -1


func _grid_tick(delta: float) -> void:
	var active := can_act()
	var frozen := Game.is_busy() or _world_blocks()
	if not global_position.is_equal_approx(_last_written):
		_moved_outside()
	_phys_prev = global_position
	var start := global_position
	_arrive_hold = maxf(_arrive_hold - delta, 0.0)
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_interact_buf = maxf(_interact_buf - delta, 0.0)
	if _interact_buf < 0.0001:  # 0.25 - 15 / 60 leaves 5e-17: it ends on the tick it should
		_interact_buf = 0.0
	var want := _want_dir()
	if not active or _arrive_hold > 0.0:
		want = Vector2i.ZERO
	if frozen:
		_bumping = false
	else:
		if _place_snap and not _stepping:
			_snap_to_free()
		if not _stepping and _script.is_empty():
			if active:
				_idle(delta, want)
			else:
				_bumping = false
		if _stepping or not _script.is_empty():
			_advance(delta, want)  # a step started this tick moves this tick (no dead frame)
	var moved := global_position - start
	velocity = Vector3(moved.x / delta, 0.0, moved.z / delta)
	if _just_placed:  # a door / warp put the body somewhere else this tick
		_just_placed = false
		velocity = Vector3.ZERO
	_refresh_floor()
	_phys_cur = global_position
	_last_written = global_position
	_tick_end = global_position
	_animate()
	_turn_model(delta)
	_update_focus(active)
	if active:
		_party_keys()


## The body was moved by something else (teleport, Story tween, battle arena, ledge hop, test): take
## the tile under it, and glide or snap back onto a free centre once allowed to move.
func _moved_outside() -> void:
	_stepping = false
	_bumping = false
	_cell = TileGrid.cell_of(global_position)
	_prev_cell = _cell
	var c := _center(_cell)
	var off := (
		Vector2(global_position.x - c.x, global_position.z - c.z).length() if c.is_finite() else 0.0
	)
	_settle = off > 0.02 or (c.is_finite() and absf(global_position.y - c.y) > 0.05)
	_place_snap = off > SNAP_FAR or not _tile_free(_cell)
	_last_written = global_position


func _snap_to_free() -> void:
	_place_snap = false
	var c := GridMotion.nearest(_cell, _tile_free, global_position)
	var at := _center(c)
	if not at.is_finite():
		return
	global_position = at
	_cell = c
	_prev_cell = c
	_settle = false
	_phys_prev = at
	_phys_cur = at


## Standing on a tile centre, free to move: turn, walk, bump or settle.
func _idle(delta: float, want: Vector2i) -> void:
	if want == Vector2i.ZERO:
		_turn_wait = 0.0
		_bumping = false
		if _settle:
			_begin_step(_cell, false, true)
		return
	if _settle:
		# Off the centre (came in from a free zone, a cutscene or a battle): on to the tile ahead in
		# the held direction, or back onto this one.
		_set_facing(want)
		var ahead := TileGrid.cell_of(global_position + GridMotion.vec(want) * 0.5)
		if ahead != _cell and _check(_cell, ahead).get("ok", false):
			_begin_step(ahead, false)
		else:
			_begin_step(_cell, false, true)
		return
	if want != _face4():
		_set_facing(want)
		_turn_wait = TURN_DELAY
		_bumping = false
		return
	if _turn_wait > 0.0:
		_turn_wait -= delta
		if _turn_wait > 0.0:
			return
	_try_step(want)


## Starts a step toward `d` when the tile ahead allows it; enters doors, hops ledges, bumps otherwise.
func _try_step(d: Vector2i) -> bool:
	_set_facing(d)
	var to := _cell + d
	var e := _check(_cell, to)
	if e.has("door"):
		_bumping = false
		if not (e.door as WorldDoor).walk_in(self):
			_bump()
		return false
	if e.has("hop"):
		_hop(to, e.hop)
		return false
	if not e.get("ok", false):
		_bump()
		return false
	_begin_step(to, false)
	return true


func _begin_step(to: Vector2i, scripted: bool, glide := false) -> void:
	var at := _center(to)
	if not at.is_finite():
		at = Vector3(to.x, global_position.y, to.y)
	_prev_cell = _cell if _cell != to else TileGrid.cell_of(global_position)
	_from = global_position
	_to = at
	_seg = maxf(Vector2(_to.x - _from.x, _to.z - _from.z).length(), 0.001)
	_t = 0.0
	_cell = to
	_stepping = true
	_bumping = false
	_settle = false
	_turn_wait = 0.0
	_scripted = scripted
	_glide = glide
	_step_run = not scripted and Input.is_action_pressed("sprint")
	_step_speed = _script_speed if scripted else (run_speed if _step_run else walk_speed)
	_parity = 1 - _parity


## Moves along the current step. At its end the tile arrives and, with the key still held (or a
## grid_walk going on), the next step starts and takes the rest of this tick's distance, so the speed
## never dips between tiles.
func _advance(delta: float, want: Vector2i) -> void:
	if not _stepping and not _next_script_step():
		return
	var left := _step_speed * delta
	while _stepping:
		var rem := _seg * (1.0 - _t)
		if left < rem - 0.00001:  # a tick that ends right on the centre arrives in that tick
			_t += left / _seg
			_put_on_step()
			return
		left = maxf(left - rem, 0.0)
		_t = 1.0
		_stepping = false
		_put_on_step()
		_arrived()
		var speed := _step_speed
		if _script_active:
			if not _next_script_step():
				return
		else:
			var w := want if can_act() and _arrive_hold <= 0.0 else Vector2i.ZERO
			if w == Vector2i.ZERO or (_interact_buf > 0.0 and _grid_focus() != null):
				return
			var g := _grid_now()
			if g == null:
				# Walked off into a free zone: the rest of this tick goes on freely (no stop at the
				# seam), the free tick takes the same input from the next tick.
				if left > 0.00001:
					move_and_collide(GridMotion.vec(w) * left)
				return
			_grid = g
			if not _try_step(w):
				return  # bump, door (maybe already through it) or ledge hop
		left *= _step_speed / maxf(speed, 0.001)  # the new step may run or walk


func _next_script_step() -> bool:
	if _script.is_empty():
		_finish_script()
		return false
	var c: Vector2i = _script.pop_front()
	var d := GridMotion.card(GridMotion.vec(c - _cell))
	if d != Vector2i.ZERO:
		_set_facing(d)
	_begin_step(c, true)
	return true


## Body position along the step: XZ straight; the height rises early / drops late on a curb.
func _put_on_step() -> void:
	var p := _from.lerp(_to, _t)
	if _to.y > _from.y:
		p.y = lerpf(_from.y, _to.y, smoothstep(0.0, 0.5, _t))
	else:
		p.y = lerpf(_from.y, _to.y, smoothstep(0.5, 1.0, _t))
	global_position = p


## A tile reached: Repel counts it and tall grass rolls once (the free zones' metre-based rate).
func _arrived() -> void:
	step_finished.emit(_cell)
	if _scripted or _glide or not can_act():
		return
	_repel_step()
	if _grass.is_empty():
		return
	var patch := _patch_at(_to)
	if patch and enc.walk(1.0, WildTable.rate(patch.table()), _rng, _repelled()):
		_ambush(patch)


## The grass patch (of those the body overlaps) whose box holds `at`.
func _patch_at(at: Vector3) -> TallGrass:
	for i in range(_grass.size() - 1, -1, -1):
		var patch := _grass[i]
		if not is_instance_valid(patch):
			continue
		var lp := patch.to_local(at)
		if absf(lp.x) <= patch.size.x * 0.5 + 0.01 and absf(lp.z) <= patch.size.z * 0.5 + 0.01:
			return patch
	return null


## Grid zones: what stands in the tile ahead, or across a counter (the tile after a blocked one).
func _grid_focus() -> Node3D:
	var f := _face4()
	if f == Vector2i.ZERO:
		return null
	var ahead := _cell + f
	var n := _in_tile(ahead)
	if n == null:
		var g := _grid_of(ahead)
		if g and g.blocked(ahead) and not g.has_flag(ahead, TileGrid.DOOR):
			n = _in_tile(ahead + f)
	return n


## The interactable whose origin is in (or within 0.1 m of) tile `c`; the most central one.
func _in_tile(c: Vector2i) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		if not n is Node3D:
			continue
		var p: Vector3 = n.global_position
		var d := maxf(absf(p.x - c.x), absf(p.z - c.y))
		if d <= 0.6 and d < best_d:
			best = n
			best_d = d
	return best


## What a step from `from` to the neighbouring `to` meets: {"ok": true}, {"door": WorldDoor},
## {"hop": landing tile} or {} (blocked).
func _check(from: Vector2i, to: Vector2i) -> Dictionary:
	var d := to - from
	var door := _door_ahead(from, d)
	if door:
		return {"door": door}
	var tg := _grid_of(to)
	if tg == null:
		# Seam into a free zone (Pallet's north road into Route 1): its colliders decide.
		return {"ok": _free_clear(to)} if _in_some_zone(to) else {}
	if tg.has_flag(to, TileGrid.LEDGE):
		var land := to + d
		return {"hop": land} if _can_hop(tg, from, to, land) else {}
	if not _tile_free(to, tg):
		return {}
	var here := _center(from)
	if here.is_finite() and absf(tg.height(to) - here.y) > GridMotion.MAX_RISE:
		return {}
	return {"ok": true}


## Static and dynamic test of one tile: walls, water, door and ledge tiles, NPC claims, people and
## signs standing there (and live walls on probed grids).
func _tile_free(c: Vector2i, tg: TileGrid = null) -> bool:
	if tg == null:
		tg = _grid_of(c)
	if tg == null:
		return _in_some_zone(c) and _free_clear(c)
	if tg.blocked(c) or tg.has_flag(c, TileGrid.DOOR | TileGrid.LEDGE):
		return false
	if tg.claimed(c, self) or GridMotion.blocker_at(get_tree(), c, self) != null:
		return false
	if tg.has_meta("probed") and GridMotion.live_blocked(get_world_3d().direct_space_state, tg, c):
		return false
	return true


func _grid_of(c: Vector2i) -> TileGrid:
	if _grid and _grid.has(c):
		return _grid
	var ow := Overworld.of(self) if is_inside_tree() else null
	if ow == null:
		return null
	var g := ow.grid_at(Vector3(c.x, global_position.y, c.y))
	return g if g and g.has(c) else null


## Tile centre of `c` in whichever grid holds it; on free ground the ground height under it (INF
## when there is no ground).
func _center(c: Vector2i) -> Vector3:
	var g := _grid_of(c)
	if g:
		return g.center(c)
	var y := _ground_y(c)
	return Vector3(c.x, y, c.y) if is_finite(y) else Vector3.INF


func _in_some_zone(c: Vector2i) -> bool:
	var ow := Overworld.of(self) if is_inside_tree() else null
	return ow != null and ow.has_method("zone_at") and ow.zone_at(Vector3(c.x, 0.0, c.y)) != ""


func _ground_y(c: Vector2i) -> float:
	if not is_inside_tree():
		return INF
	var from := Vector3(c.x, global_position.y + 1.5, c.y)
	var q := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * 4.0, Overworld.WALL_LAYER, [get_rid()]
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else INF


## A free-zone tile at a seam: ground under it and nothing solid (walls, NPCs, water) in its box.
func _free_clear(c: Vector2i) -> bool:
	var y := _ground_y(c)
	if not is_finite(y) or absf(y - global_position.y) > GridMotion.MAX_RISE:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = GridMotion.PROBE_SIZE
	q.shape = box
	q.collision_mask = MASK
	q.exclude = [get_rid()]
	q.transform = Transform3D(
		Basis(), Vector3(c.x, y + GridMotion.PROBE_LIFT + GridMotion.PROBE_SIZE.y * 0.5, c.y)
	)
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## The door the player pushes into from tile `from` going `d`: a WorldDoor on the edge ahead (or just
## inside the tile ahead) whose inside lies that way.
func _door_ahead(from: Vector2i, d: Vector2i) -> WorldDoor:
	var dv := GridMotion.vec(d)
	var edge := Vector3(from.x + d.x * 0.5, 0.0, from.y + d.y * 0.5)
	for n in get_tree().get_nodes_in_group(WorldNpc.GROUP):
		if not n is WorldDoor or GridMotion.door_inward(n).dot(dv) < 0.7:
			continue
		var off: Vector3 = n.global_position - edge
		off.y = 0.0
		var along := off.dot(dv)
		if absf(off.dot(Vector3(-dv.z, 0.0, dv.x))) <= 0.6 and along >= -0.45 and along <= 1.0:
			return n
	return null


## A ledge tile hops down its outward side (the WorldLedge's +Z, or toward a lower landing tile).
func _can_hop(tg: TileGrid, from: Vector2i, ledge: Vector2i, land: Vector2i) -> bool:
	var lg := _ledge_node(ledge)
	var d := ledge - from
	if lg:
		if GridMotion.card(lg.global_transform.basis.z) != d:
			return false
	elif not (tg.height(land) < tg.height(from) - 0.2):
		return false
	var lt := _grid_of(land)
	return lt != null and _tile_free(land, lt)


func _ledge_node(c: Vector2i) -> WorldLedge:
	var ow := Overworld.of(self) if is_inside_tree() else null
	if ow == null:
		return null
	for b in ow.get_children():
		for n in b.get_children():
			if n is WorldLedge and (n as WorldLedge).covers(Vector3(c.x, 0.0, c.y)):
				return n
	return null


func _hop(ledge: Vector2i, land: Vector2i) -> void:
	var dest := _center(land)
	if not dest.is_finite():
		return
	_bumping = false
	_stepping = false
	_parity = 1 - _parity
	_cell = land
	_prev_cell = land
	var lg := _ledge_node(ledge)
	if lg:
		lg.hop_to(self, dest, HOP_TIME)
	else:
		WorldLedge.jump(self, dest, HOP_TIME)


func _bump() -> void:
	_bumping = true
	if _bump_cd > 0.0:
		return
	_bump_cd = BUMP_GAP
	var au := get_node_or_null("/root/Audio")
	if au == null:
		return
	if au.has_method("has_sfx") and au.has_sfx("bump"):
		au.sfx("bump")
		return
	var vol = au.get("sfx_vol")
	if vol != null and float(vol) <= 0.0:
		return
	if _bump_player == null:
		_bump_player = AudioStreamPlayer.new()
		_bump_player.name = "Bump"
		_bump_player.stream = bump_stream()
		add_child(_bump_player)
	_bump_player.volume_db = -3.0 + (linear_to_db(float(vol)) if vol != null else 0.0)
	_bump_player.play()


## The wall bump: a soft low thud with a tiny click, chiptune like audio/synth.gd.
static func bump_stream() -> AudioStreamWAV:
	if _bump_wav == null:
		var b := PackedFloat32Array()
		b.resize(int(0.14 * Synth.RATE))
		Synth.voice(
			b,
			0.0,
			0.06,
			{
				"wave": "triangle",
				"f0": 170.0,
				"f1": 62.0,
				"vol": 0.55,
				"d": 0.04,
				"s": 0.45,
				"r": 0.05
			}
		)
		Synth.voice(b, 0.0, 0.012, {"wave": "noise", "f0": 1800.0, "vol": 0.1, "r": 0.015})
		_bump_wav = Synth.to_wav(b, false)
	return _bump_wav


## Held direction as a world tile step: the last pressed of the held keys, turned by the camera yaw.
func _want_dir() -> Vector2i:
	for a in MOVES:
		var on := InputMap.has_action(a) and Input.get_action_strength(a) > 0.3
		var i := _held.find(a)
		if on and i < 0:
			_held.append(a)
		elif not on and i >= 0:
			_held.remove_at(i)
	if _held.is_empty():
		return Vector2i.ZERO
	var s: Vector2i = MOVES[_held[-1]]
	return GridMotion.card(GridMotion.vec(s).rotated(Vector3.UP, _camera_yaw()))


func _face4() -> Vector2i:
	return GridMotion.card(facing)


func _set_facing(d: Vector2i) -> void:
	if d != Vector2i.ZERO:
		facing = GridMotion.vec(d)


## move_and_slide only for the floor contact (is_on_floor for ledges, picnics, tests): straight down,
## against walls alone, XZ kept exactly where the step put it.
func _refresh_floor() -> void:
	var keep := velocity
	var mask := collision_mask
	var at := global_position
	collision_mask = Overworld.WALL_LAYER
	velocity = Vector3(0.0, -0.5, 0.0)
	move_and_slide()
	collision_mask = mask
	global_position = Vector3(at.x, global_position.y if is_on_floor() else at.y, at.z)
	velocity = keep


## The sheet: one foot forward for the first half of each step (alternating feet), standing for the
## second; walking in place, slower, while pushing into something; feet apart over a ledge.
func _animate() -> void:
	if sprite == null:
		return
	sprite.facing = facing
	if has_meta(WorldLedge.HOP_META):
		sprite.moving = true
		sprite.step_col = 1 + _parity
		return
	sprite.moving = _stepping or _bumping
	if _stepping:
		sprite.step_col = (1 + _parity) if _t < 0.5 else 0
		sprite.speed = _step_speed
		sprite.set_running(_step_run)
	else:
		sprite.step_col = -1
		sprite.speed = walk_speed * 0.5
		sprite.set_running(false)
