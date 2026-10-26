extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_grid_motion.gd
## (also passes at --fixed-fps 144). Grid movement of humans (docs/VOXEL.md §6) on the real
## RouteWorld with the voxel Pallet on the grid (its baked TileGrid; forced on as well): tap turns, hold walks whole tiles, chained steps at constant speed (the
## follower never sees the player stop), run, walls and NPCs bump, a lock mid-step finishes the step,
## teleports re-snap, save_position on tile centres, an old save inside a wall lands on a free tile,
## the front tile wins the focus, a dialogue closed with E stays closed (the E buffer never keeps a
## press the HUD ignored; the realistic case needs the 144 run), the door enters by pushing (not by
## walking past or standing in its old walk-in area), the post-warp input hold, the seam with free Route 1 both ways, NPC wander on
## tiles (never on the player or each other) and the Oak scene walking on tile lines. A small
## synthetic grid world checks the two-tile ledge hop, one grass roll per tile, Repel per tile and a
## trainer's approach along tile lines. The sheet steps (alternating feet) on every moving frame.
## Never writes user://save.json.

const HZ := 60.0

var _fails := 0
var game: Node
var w: Node3D
var p: CharacterBody3D
var Player: GDScript  ## loaded in _run: these scripts need the autoloads (Game)
var Motion: GDScript
var Grid: GDScript
var _hz := HZ


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func secs(s: float) -> int:
	return int(ceil(s * _hz))


func release_all() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint", "interact"]:
		Input.action_release(a)


## True when `v` sits on a tile centre (XZ within 1 cm).
func on_centre(v: Vector3) -> bool:
	return absf(v.x - roundf(v.x)) < 0.01 and absf(v.z - roundf(v.z)) < 0.01


## True when `v` lies on a tile line (between two tile centres along an axis).
func on_line(v: Vector3) -> bool:
	return absf(v.x - roundf(v.x)) < 0.01 or absf(v.z - roundf(v.z)) < 0.01


## Puts the player on tile (x, z) facing `f` and lets it settle.
func put(x: int, z: int, f := Vector3(0, 0, 1)) -> void:
	release_all()
	await frames(2)
	p.global_position = Vector3(x, 0.0, z)
	p.facing = f
	await frames(4)


func _run() -> void:
	Player = load("res://world/player.gd")
	Motion = load("res://world/grid/grid_motion.gd")
	Grid = load("res://world/grid/tile_grid.gd")
	game = root.get_node("/root/Game")
	game.save_path = OS.get_user_data_dir().path_join("test_grid_motion_save.json")
	game.save_enabled = false
	_hz = float(Engine.physics_ticks_per_second)
	Player.force_zones = {"pallet_town": "grid"}
	var story = root.get_node_or_null("Story")
	if story:
		story.auto_advance = true
		story.auto_answer = true
	await _old_save_in_wall()
	game.flags["got_starter"] = true  # no Oak at the north edge for the movement checks
	game.last_save = {}
	await _open({"zone": "pallet_town", "spawn": "start"})
	check(p.grid_active(), "Pallet forced onto the grid: the player walks on it")
	check(on_centre(p.global_position), "start spawn on a tile centre (%s)" % p.global_position)
	var g = w.builders.pallet_town.grid
	check(
		g != null and not g.has_meta("probed") and g == w.grid_at(Vector3(0, 0, 0)),
		"the zone's baked tile grid is used (no probe)"
	)
	Player.force_zones = {}
	check(w.grid_at(Vector3(0, 0, 0)) == g, "Pallet walks on the grid by itself (map: grid)")
	Player.force_zones = {"pallet_town": "grid"}
	check(w.grid_at(Vector3(0, 0, -30)) == null, "Route 1 stays free")
	check(w.grid_at(w.interior("player_house").global_position) == null, "interiors stay free")
	await _tap_and_hold()
	await _constant_speed()
	await _run_speed()
	await _blocking()
	await _mid_step_lock()
	await _teleports()
	await _focus()
	await _doors()
	await _seam()
	await _npc_wander()
	await _oak_scene()
	await _synthetic()
	Player.force_zones = {}
	print("[grid motion] %d failed" % _fails)
	quit(1 if _fails else 0)


func _open(req: Dictionary) -> void:
	if w:
		w.queue_free()
		await frames(2)
	game.spawn_request = req
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(8)
	p = get_first_node_in_group("ow_player")
	for i in 600:
		if w.builders.has("pallet_town") and w.builders.pallet_town.is_built and p.grid_active():
			break
		await physics_frame
	await frames(10)


## A save from an older layout inside what is now the player's house: lands on a free tile centre.
func _old_save_in_wall() -> void:
	game.spawn_request = {}
	game.last_save = {"pos": [-8.0, 0.0, -8.4], "zone": "pallet_town"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(30)
	p = get_first_node_in_group("ow_player")
	var g = w.builders.pallet_town.grid
	var c: Vector2i = Grid.cell_of(p.global_position)
	check(
		g != null and on_centre(p.global_position) and not g.blocked(c),
		"old save inside a house: snapped to a free tile (%s)" % p.global_position
	)
	check(
		p.global_position.distance_to(Vector3(-8, 0, -8.4)) < 4.0,
		"and near the saved spot (%.1f m)" % p.global_position.distance_to(Vector3(-8, 0, -8.4))
	)
	w.queue_free()
	w = null
	await frames(2)


func _tap_and_hold() -> void:
	await put(2, -2)
	check(p.global_position.is_equal_approx(Vector3(2, 0, -2)), "put on (2, -2)")
	# A tap of a new direction (shorter than TURN_DELAY) only turns.
	Input.action_press("move_right")
	await frames(3)
	Input.action_release("move_right")
	await frames(20)
	check(p.facing.is_equal_approx(Vector3(1, 0, 0)), "tap turns (facing %s)" % p.facing)
	check(p.global_position.is_equal_approx(Vector3(2, 0, -2)), "tap does not move")
	# A tap toward the facing walks one whole tile.
	Input.action_press("move_right")
	await frames(1)
	Input.action_release("move_right")
	await frames(30)
	check(
		p.global_position.is_equal_approx(Vector3(3, 0, -2)),
		"tap toward the facing walks one tile (%s)" % p.global_position
	)
	# Holding walks whole tiles on one axis and stops on a centre after the release.
	var off_axis := 0.0
	Input.action_press("move_right")
	for i in secs(0.62):
		await physics_frame
		off_axis = maxf(off_axis, absf(p.global_position.z + 2.0))
	Input.action_release("move_right")
	await frames(30)
	check(off_axis < 0.001, "walks straight along x (off %.4f)" % off_axis)
	check(
		on_centre(p.global_position) and p.global_position.x > 4.5,
		"hold walks whole tiles, ends on a centre (%s)" % p.global_position
	)
	# A new direction held long enough: turn, then walk.
	var x0: float = p.global_position.x
	Input.action_press("move_back")
	await frames(secs(0.5))
	Input.action_release("move_back")
	await frames(30)
	check(
		on_centre(p.global_position) and p.global_position.z > -1.5 and p.global_position.x == x0,
		"held new direction turns and walks (%s)" % p.global_position
	)
	p.face_toward(p.global_position + Vector3(1, 0, 0.4))
	check(p.facing.is_equal_approx(Vector3(1, 0, 0)), "face_toward snaps to an axis on the grid")


func _constant_speed() -> void:
	await put(-16, -2, Vector3(1, 0, 0))
	var cam = get_first_node_in_group("ow_camera")
	var steps: Array = []
	var rel: Array = []
	var vmin := INF
	var last: Vector3 = p.global_position
	var tiles := [0]
	var slid := 0
	var feet := {}
	p.step_finished.connect(func(_c): tiles[0] += 1)
	Input.action_press("move_right")
	for i in secs(2.5):
		await physics_frame
		var now: Vector3 = p.global_position
		if p.sprite and absf(now.x - last.x) > 0.001:
			if not p.sprite.moving or p.sprite.step_col < 0:
				slid += 1
			feet[p.sprite.step_col] = true
		steps.append(now.x - last.x)
		last = now
		vmin = minf(vmin, Vector2(p.velocity.x, p.velocity.z).length())
		var vis: Node3D = p.sprite if p.sprite else p
		rel.append(vis.global_position.x - (cam.camera as Camera3D).global_position.x)
	Input.action_release("move_right")
	await frames(30)
	var want: float = p.walk_speed / _hz
	var worst := 0.0
	for i in range(1, steps.size()):
		worst = maxf(worst, absf(steps[i] - want))
	check(worst < 0.0015, "chained steps at constant speed (worst %.4f m/tick off)" % worst)
	check(vmin > 3.9, "velocity never drops between tiles (min %.2f m/s)" % vmin)
	check(tiles[0] >= 9, "walked %d tiles in 2.5 s" % tiles[0])
	var jit := 0.0
	for i in range(rel.size() / 2, rel.size()):
		jit = maxf(jit, absf(rel[i] - rel[i - 1]))
	check(jit < 0.005, "sprite steady against the camera (worst %.4f m/frame)" % jit)
	if p.sprite:
		check(slid == 0, "the sheet steps on every moving frame (%d slid)" % slid)
		check(feet.has(1) and feet.has(2) and feet.has(0), "feet alternate (%s)" % [feet.keys()])
	check(on_centre(p.global_position), "stops on a centre (%s)" % p.global_position)


func _run_speed() -> void:
	await put(-16, -2, Vector3(1, 0, 0))
	Input.action_press("sprint")
	Input.action_press("move_right")
	var x0: float = p.global_position.x
	await frames(secs(1.0))
	var x1: float = p.global_position.x
	Input.action_release("move_right")
	Input.action_release("sprint")
	await frames(30)
	check(absf((x1 - x0) - p.run_speed) < 0.2, "runs at run_speed (%.2f m in 1 s)" % (x1 - x0))
	check(on_centre(p.global_position), "run stops on a centre")


func _blocking() -> void:
	# The player house's south wall north of (-10, -4).
	await put(-10, -4, Vector3(0, 0, -1))
	Input.action_press("move_forward")
	var bumped := false
	var anim := false
	for i in 30:
		await physics_frame
		bumped = bumped or p._bumping
		anim = anim or (p.sprite != null and p.sprite.moving)
	Input.action_release("move_forward")
	await frames(5)
	check(p.global_position.is_equal_approx(Vector3(-10, 0, -4)), "a wall blocks")
	check(bumped and (p.sprite == null or anim), "pushing into it bumps (walk in place)")
	# The Audio "bump" sfx when the synth has it (Audio._sfx_last), else the player's own thud.
	var au := root.get_node_or_null("Audio")
	var sfx_played: bool = au != null and au.has_sfx("bump") and au._sfx_last.has("bump")
	check(sfx_played or p.get_node_or_null("Bump") != null, "bump sound played")
	# The lab assistant stands on tile (8, 15).
	await put(8, 14, Vector3(0, 0, 1))
	Input.action_press("move_back")
	await frames(30)
	Input.action_release("move_back")
	await frames(5)
	check(p.global_position.is_equal_approx(Vector3(8, 0, 14)), "an NPC blocks its tile")


func _mid_step_lock() -> void:
	await put(-10, -2, Vector3(1, 0, 0))
	Input.action_press("move_right")
	await frames(4)
	p.locked = true
	await frames(40)
	Input.action_release("move_right")
	check(
		p.global_position.is_equal_approx(Vector3(-9, 0, -2)),
		"a lock mid-step finishes that step and no more (%s)" % p.global_position
	)
	p.locked = false
	await frames(5)


func _teleports() -> void:
	await put(0, -2)
	p.global_position = Vector3(0.3, 0.4, -1.65)
	await frames(30)
	check(
		p.global_position.distance_to(Vector3(0, 0, -2)) < 0.01,
		"teleport off-centre: glides back onto the tile (%s)" % p.global_position
	)
	p.global_position = Vector3(-8.0, 0.0, -8.0)  # inside the player house
	await frames(10)
	var c: Vector2i = Grid.cell_of(p.global_position)
	check(
		on_centre(p.global_position) and not w.builders.pallet_town.grid.blocked(c),
		"teleport into a wall: snaps to a free tile (%s)" % p.global_position
	)
	# Mid-step the save is the target tile centre.
	await put(-10, -2, Vector3(1, 0, 0))
	Input.action_press("move_right")
	await frames(5)
	var sp: Vector3 = p.save_position()
	var se: Array = w.save_extra().pos
	Input.action_release("move_right")
	await frames(20)
	check(
		on_centre(sp) and sp.is_equal_approx(Vector3(-9, 0, -2)),
		"save_position mid-step = target tile centre (%s)" % sp
	)
	check(
		Vector3(se[0], se[1], se[2]).is_equal_approx(sp) and w.save_extra().zone == "pallet_town",
		"save_extra saves that centre"
	)


func _focus() -> void:
	await put(8, 14, Vector3(0, 0, 1))
	await frames(2)
	check(
		p.focus != null and String(p.focus.npc_name).begins_with("Assistente"),
		"front tile: the lab assistant (%s)" % [p.focus]
	)
	await put(8, 14, Vector3(1, 0, 0))
	await frames(2)
	check(p.focus == null, "facing away: nothing (%s)" % [p.focus])
	# The town sign stands on tile (-3, -13).
	await put(-3, -12, Vector3(0, 0, -1))
	await frames(2)
	check(p.focus != null and p.focus.name == "PalletSign", "front tile: the town sign")
	await _no_retalk()


## One tap of `action` on process frames (a real key: down for two frames, then up).
func tap_frames(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame


## A dialogue closed with E stays closed. The HUD ignores E for 0.25 s after a dialogue closes; a
## press it ignores must not come back later from the grid's E buffer. Above 60 Hz the E that
## closed the box reached the next physics tick with the player already free, was buffered, and
## opened the same dialogue again once the HUD re-armed (about 1 close in 4 at 144 Hz).
func _no_retalk() -> void:
	var hud := get_first_node_in_group("ow_hud")
	var story = root.get_node_or_null("Story")
	var auto: bool = story != null and story.auto_advance
	if story:
		story.auto_advance = false  # the test closes the dialogue itself
	await put(8, 14, Vector3(0, 0, 1))
	await frames(2)
	# Deterministic at any rate: close the box without input, then press E inside the re-arm.
	Input.action_press("interact")
	await frames(1)
	Input.action_release("interact")
	await frames(2)
	var opened: bool = hud.is_dialog_open()
	var guard := 0
	while hud.is_dialog_open() and guard < 10:
		hud.advanced.emit()
		await process_frame
		guard += 1
	await frames(2)
	Input.action_press("interact")  # the HUD rejects it (just closed)
	await frames(1)
	Input.action_release("interact")
	var again := false
	for i in secs(1.0):
		await physics_frame
		again = again or hud.is_dialog_open()
	check(opened and not again, "an E the HUD ignored right after a dialogue does not talk later")
	while hud.is_dialog_open():
		hud.advanced.emit()
		await process_frame
	# The real flow, closed with E on varying frames (fails about 1 in 4 at 144 Hz without the fix).
	var hz := roundi(1.0 / maxf(root.get_process_delta_time(), 0.001))  # process frames per second
	var reopened := 0
	var tries := 0
	for trial in 6:
		await frames(20)
		for i in trial:
			await process_frame
		await tap_frames("interact")
		for i in 30:
			if hud.is_dialog_open():
				break
			await process_frame
		if not hud.is_dialog_open():
			continue
		tries += 1
		guard = 0
		while hud.is_dialog_open() and guard < 20:
			for i in roundi(0.35 * hz) + trial:
				await process_frame
			await tap_frames("interact")
			guard += 1
		var back := false
		for i in secs(1.2):
			await physics_frame
			back = back or hud.is_dialog_open()
		if back:
			reopened += 1
			while hud.is_dialog_open():
				hud.advanced.emit()
				await process_frame
	check(
		tries == 6 and reopened == 0,
		(
			"a dialogue closed with E stays closed (%d of %d re-opened at %d fps)"
			% [reopened, tries, hz]
		)
	)
	if story:
		story.auto_advance = auto


func _doors() -> void:
	var b = w.builders.pallet_town
	var door = b.get_node("Door_player_house")
	var front: Vector2i = Motion.door_cell(door) + Vector2i(0, 1)
	# Standing in the old walk-in area does not enter on the grid.
	await put(front.x, front.y, Vector3(0, 0, 1))
	p.global_position = door.global_position + Vector3(0, 0, 0.3)
	await frames(40)
	check(w.location_id == "pallet_town", "standing in the walk-in area does not enter")
	check(
		on_centre(p.global_position) and Grid.cell_of(p.global_position) == front,
		"pushed off the doorstep onto the tile in front (%s)" % p.global_position
	)
	# Walking past along the facade does not enter.
	await put(front.x - 1, front.y, Vector3(1, 0, 0))
	Input.action_press("move_right")
	await frames(secs(1.1))
	Input.action_release("move_right")
	await frames(30)
	check(w.location_id == "pallet_town", "walking past the door does not enter")
	# Facing it: the prompt; pushing into it from the tile in front enters.
	await put(front.x, front.y, Vector3(0, 0, -1))
	await frames(40)
	check(p.focus == door, "facing the door focuses it (%s)" % [p.focus])
	Input.action_press("move_forward")
	var entered := false
	for i in 60:
		await physics_frame
		if w.location_id == "player_house":
			entered = true
			break
	Input.action_release("move_forward")
	check(entered, "pushing into the door enters the house")
	check(not p.grid_active(), "free movement inside")
	await frames(30)
	# Back out with the key toward the door still held: the warp hold keeps the player still.
	Input.action_press("move_forward")
	await w.go_to_zone("pallet_town", "player_house_door")
	var at0: Vector3 = p.global_position
	await frames(6)
	check(
		p.global_position.is_equal_approx(at0) and p.facing.is_equal_approx(Vector3(0, 0, 1)),
		"held key ignored right after the warp"
	)
	Input.action_release("move_forward")
	await frames(30)
	check(
		w.location_id == "pallet_town" and on_centre(p.global_position) and p.grid_active(),
		"back out on the grid, not re-entered (%s)" % p.global_position
	)


func _seam() -> void:
	var r1_built := func() -> bool: return w.builders.has("route_1") and w.builders.route_1.is_built
	await put(0, -16, Vector3(0, 0, -1))
	for i in 600:
		if r1_built.call():
			break
		await physics_frame
	check(r1_built.call(), "Route 1 streamed in")
	# Grid -> free: walk north over z -19.5 without a stop.
	var vmin := INF
	var vmin_z := 0.0
	var left_grid := false
	Input.action_press("move_forward")
	for i in secs(2.0):
		await physics_frame
		var z := p.global_position.z
		if z > -21.5 and z < -17.5:
			var v := Vector2(p.velocity.x, p.velocity.z).length()
			if v < vmin:
				vmin = v
				vmin_z = z
		left_grid = left_grid or (p.global_position.z < -19.6 and not p.grid_active())
	Input.action_release("move_forward")
	await frames(10)
	check(left_grid, "free movement past z -19.5 (Route 1)")
	check(vmin > 3.9, "no stop at the seam (min %.2f m/s at z %.2f)" % [vmin, vmin_z])
	check(p.global_position.z < -22.0, "kept walking into Route 1 (z %.2f)" % p.global_position.z)
	# Free -> grid: from an off-tile spot in Route 1 back south.
	p.global_position = Vector3(0.35, p.global_position.y, -21.3)
	await frames(10)
	vmin = INF
	Input.action_press("move_back")
	for i in secs(1.0):
		await physics_frame
		if p.global_position.z > -21.0 and p.global_position.z < -17.5:
			vmin = minf(vmin, Vector2(p.velocity.x, p.velocity.z).length())
	Input.action_release("move_back")
	await frames(30)
	check(p.grid_active(), "back on the grid in Pallet")
	check(vmin > 3.0, "entered the grid without a stop (min %.2f m/s)" % vmin)
	check(
		on_centre(p.global_position) and p.global_position.z > -19.0,
		"and stopped on a tile centre (%s)" % p.global_position
	)


func _npc_wander() -> void:
	var b = w.builders.pallet_town
	var lily = b.get_node_or_null("NPC_Girl")
	check(lily != null and lily.wander_radius > 0.0, "Lily wanders")
	if lily == null:
		return
	var other = load("res://world/npc.gd").new()
	other.name = "GridWalker"
	other.npc_name = "Teste"
	other.wander_radius = 2.0
	# A tile Lily (who has wandered since Pallet loaded) neither stands on nor is stepping into.
	var spawn := Vector2i(-4, 6)
	for c in [Vector2i(-4, 6), Vector2i(-3, 6), Vector2i(-4, 7), Vector2i(-3, 7)]:
		spawn = c
		if not lily._grid.claimed(c) and Grid.cell_of(lily.global_position) != c:
			break
	other.position = Vector3(spawn.x, 0, spawn.y)
	b.add_child(other)
	await put(-5, 6, Vector3(1, 0, 0))
	var off_tile := 0
	var on_player := 0
	var on_other := 0
	var moved := 0.0
	var start: Vector3 = lily.global_position
	var min_d := INF
	for i in secs(16.0):
		await physics_frame
		lily._wander_t = minf(lily._wander_t, 0.3)
		other._wander_t = minf(other._wander_t, 0.3)
		for n in [lily, other]:
			if not on_line(n.global_position):
				off_tile += 1
			min_d = minf(
				min_d,
				(
					Vector2(
						n.global_position.x - p.global_position.x,
						n.global_position.z - p.global_position.z
					)
					. length()
				)
			)
		if Grid.cell_of(lily.global_position) == Grid.cell_of(other.global_position):
			on_other += 1
		if Grid.cell_of(lily.global_position) == Grid.cell_of(p.global_position):
			on_player += 1
		moved = maxf(moved, lily.global_position.distance_to(start))
		# The player paces east-west through the meadow they share.
		if i % secs(0.6) == 0:
			release_all()
			Input.action_press("move_right" if (i / secs(0.6)) % 2 == 0 else "move_left")
	release_all()
	await frames(30)
	check(moved > 0.9, "Lily walked whole tiles (%.1f m)" % moved)
	check(off_tile == 0, "wanderers always on tile lines (%d samples off)" % off_tile)
	check(on_other == 0, "wanderers never share a tile (%d)" % on_other)
	check(on_player == 0 and min_d > 0.6, "never on the player (min %.2f m)" % min_d)
	check(on_centre(lily.global_position) or lily._gstep, "Lily rests on a centre")
	other.queue_free()


## The Oak scene in a grid Pallet: the walks run on tile lines and the scene ends on the lab.
func _oak_scene() -> void:
	var story = root.get_node_or_null("Story")
	if story == null:
		check(false, "Story autoload")
		return
	game.flags.erase("got_starter")
	game.flags.erase("oak_stopped")
	game.party.clear()
	await put(0, -13, Vector3(0, 0, -1))
	var fired := [false]
	story.cutscene_started.connect(func(id): fired[0] = fired[0] or id == "oak_stop")
	var off_line := 0
	var min_gap := INF
	var samples := 0
	Input.action_press("move_forward")
	for i in secs(30.0):
		await physics_frame
		if fired[0]:
			Input.action_release("move_forward")
		if w.location_id != "pallet_town":
			break
		var oak = w.get_node_or_null("Story_oak_out")
		if not fired[0] or not story.is_running():
			continue
		samples += 1
		if not on_line(p.global_position):
			off_line += 1
		if oak:
			if not on_line(oak.global_position):
				off_line += 1
			min_gap = minf(min_gap, oak.global_position.distance_to(p.global_position))
	release_all()
	check(fired[0], "oak_stop fired walking north on the grid")
	check(
		samples > 30 and off_line == 0,
		"scene walks on tile lines (%d of %d off)" % [off_line, samples]
	)
	check(min_gap > 0.9 and min_gap < 1.1, "Oak stops one tile away (%.2f m)" % min_gap)
	for i in secs(40.0):
		if not story.is_running():
			break
		await physics_frame
	check(w.location_id == "oak_lab", "scene ends in the lab (%s)" % w.location_id)
	check(not p.locked and not p.grid_active(), "free and unlocked in the lab")
	game.flags["got_starter"] = true


## A tiny grid world: a 0.9 m terrace (z <= -1) whose edge row z = 0 is a ledge, ground below, a
## tall-grass patch east. Checks the two-tile hop, one roll per tile in grass and Repel per tile.
func _synthetic() -> void:
	if w:
		w.queue_free()
		w = null
		await frames(2)
	var src := GDScript.new()
	src.source_code = (
		"extends Overworld\nvar g: TileGrid\nfunc grid_at(pos: Vector3) -> TileGrid:\n"
		+ "\treturn g if g and g.has(Vector2i(roundi(pos.x), roundi(pos.z))) else null\n"
	)
	src.reload()
	var world: Node3D = src.new()
	world.seed_party = false
	var g = Grid.new(Vector2i(-4, -6), Vector2i(12, 12))
	for z in range(-6, 6):
		for x in range(-4, 8):
			var c := Vector2i(x, z)
			g.set_height(c, 0.9 if z < 0 else 0.0)
			if z == 0 and x <= 1:
				g.set_flag(c, Grid.LEDGE)
			if x == -4 or x == 7 or z == -6 or z == 5:
				g.set_flag(c, Grid.BLOCKED)
	world.g = g
	root.add_child(world)
	_box(world, Vector3(1.5, -0.5, 0), Vector3(16, 1, 16))  # ground, top at 0
	_box(world, Vector3(1.5, 0.45, -3.75), Vector3(16, 0.9, 6.5))  # terrace, top 0.9 (z <= -0.5)
	var grass = load("res://world/tall_grass.gd").new()
	grass.table_id = "route_1"
	grass.size = Vector3(3, 1, 4)
	grass.position = Vector3(5, 0, 2.5)  # tiles x 4..6, z 1..4
	world.add_child(grass)
	var pl: CharacterBody3D = Player.new()
	world.add_child(pl)
	pl.global_position = Vector3(0, 0.9, -2)
	pl.facing = Vector3(0, 0, 1)
	p = pl
	await frames(10)
	check(pl.grid_active() and on_centre(pl.global_position), "synthetic: on the grid")
	# Off the terrace: one step, then the hop over the ledge row onto z = 1.
	var hopped := false
	var peak := -INF
	var land := Vector3.INF
	var hop_from := Vector3.INF
	Input.action_press("move_back")
	for i in secs(1.4):
		await physics_frame
		if pl.has_meta("ledge_hopping"):
			if not hopped:
				hop_from = pl.global_position
			hopped = true
			peak = maxf(peak, pl.global_position.y)
		elif hopped and not land.is_finite():
			land = pl.global_position
			Input.action_release("move_back")
	Input.action_release("move_back")
	await frames(30)
	check(hopped and peak > 0.9, "ledge: hop in an arc (peak %.2f)" % peak)
	check(
		hop_from.distance_to(Vector3(0, 0.9, -1)) < 0.25,
		"ledge: hops from the last terrace tile (%s)" % hop_from
	)
	check(
		land.distance_to(Vector3(0, 0, 1)) < 0.02,
		"ledge: lands two tiles out on a centre (%s)" % land
	)
	check(not pl.locked and pl.is_physics_processing(), "ledge: controls back")
	await frames(10)
	pl.global_position = Vector3(0, 0, 1)
	pl.facing = Vector3(0, 0, -1)
	await frames(5)
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	await frames(5)
	check(pl.global_position.is_equal_approx(Vector3(0, 0, 1)), "ledge: a wall from below")
	# Grass: one roll per tile inside the patch (1 m each), Repel spent per tile.
	var counter := GDScript.new()
	counter.source_code = (
		"extends EncounterRate\nvar calls := 0\nvar dist := 0.0\n"
		+ "func walk(d: float, rate: float, rng: RandomNumberGenerator, blocked := false) -> bool:\n"
		+ "\tcalls += 1\n\tdist += d\n\treturn false\n"
	)
	counter.reload()
	pl.enc = counter.new()
	pl.global_position = Vector3(5, 0, 0)
	pl.facing = Vector3(0, 0, 1)
	game.repel_steps = 0
	await frames(5)
	Input.action_press("move_back")
	var t0 := 0
	while pl.global_position.z < 3.99 and t0 < secs(3.0):
		await physics_frame
		t0 += 1
	Input.action_release("move_back")
	await frames(30)
	check(
		pl.enc.calls == 4 and is_equal_approx(pl.enc.dist, 4.0),
		"grass: one 1 m roll per tile (%d rolls, %.1f m)" % [pl.enc.calls, pl.enc.dist]
	)
	game.repel_steps = 10
	pl.global_position = Vector3(1, 0, 2)
	pl.facing = Vector3(1, 0, 0)
	await frames(5)
	Input.action_press("move_right")
	await frames(secs(0.72))
	Input.action_release("move_right")
	await frames(30)
	var walked := roundi(pl.global_position.x - 1)
	check(
		walked >= 2 and game.repel_steps == 10 - walked,
		"Repel: one step per tile (%d tiles, %d left)" % [walked, game.repel_steps]
	)
	game.repel_steps = 0
	await _trainer_approach(world, pl)
	world.queue_free()
	await frames(2)


## A trainer that spotted the player walks on tile lines to the tile next to it.
func _trainer_approach(world: Node3D, pl: CharacterBody3D) -> void:
	pl.global_position = Vector3(2, 0, 2)
	pl.facing = Vector3(-1, 0, 0)
	await frames(5)
	var tr = load("res://world/trainer.gd").new()
	tr.trainer_id = "test_youngster"
	tr.position = Vector3(-2, 0, 3.3)
	world.add_child(tr)
	tr.sight = 0.0  # no real spot (and battle) here: the approach alone
	await frames(5)
	var off := 0
	var n := [0]
	var watch := func() -> void:
		while is_instance_valid(tr) and n[0] >= 0:
			if not on_line(tr.global_position):
				off += 1
			n[0] += 1
			await process_frame
	watch.call()
	await tr._grid_approach(pl)
	var samples: int = n[0]
	n[0] = -1
	check(
		tr.global_position.distance_to(Vector3(1, 0, 2)) < 0.01,
		"trainer stops on the tile next to the player (%s)" % tr.global_position
	)
	check(samples > 10 and off == 0, "trainer walks on tile lines (%d of %d off)" % [off, samples])
	tr.queue_free()
	await frames(2)


func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	parent.add_child(b)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.global_position = at
