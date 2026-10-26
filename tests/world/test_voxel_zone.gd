extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_voxel_zone.gd
## The voxel Pallet Town (docs/VOXEL.md §5). The committed bake is fresh: its hash matches the
## design, the map and the generator sources. The gameplay of data/maps/pallet_town.json sits on
## the baked tile grid: free tile centres, water for swim zones, doors with a free doorstep. Every
## place the story needs can be reached on foot from "start". The colliders are exactly the blocked
## and water tiles. The zone loads fast, both blocking and streamed. In the real RouteWorld the
## player walks it with the move keys, tile by tile: from "start" to every mailbox and sign, into
## every house and back out, to every NPC, the pond shore and the north gate.
## The scripts are loaded by path: a SceneTree script compiles before the autoloads exist.

const ZONE := "pallet_town"
const MAX_BAKE_MB := 10.0
const MAX_LOAD_MS := 3000  ## blocking build from a fresh bake (headless)
## Longest frame while streaming the zone in (headless, blocking bake load included; about 30 ms
## alone, 60-90 ms when the tail of the scenery and the colliders came in one frame each).
const MAX_STREAM_FRAME_MS := 75
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _fails := 0
var bake_s: GDScript
var gen_s: GDScript
var Motion: GDScript
var Player: GDScript
var w: Node  ## the RouteWorld of the walk
var p: Node3D  ## its player
var _held := ""  ## the move key held by the walk
var _steps := 0  ## tiles walked


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	bake_s = load("res://world/voxel/voxel_zone_bake.gd")
	gen_s = load("res://world/voxel/voxel_zone_gen.gd")
	_bake()
	var b = await _build(0)
	check(b.is_built and not b.stale, "zone built from the bake (stale %s)" % b.stale)
	check(b.load_ms < MAX_LOAD_MS, "blocking build in %d ms (< %d)" % [b.load_ms, MAX_LOAD_MS])
	var grid: TileGrid = b.grid
	check(grid != null and grid.size.x > 1, "tile grid from the bake")
	_placement(b, grid)
	_doors(b, grid)
	_reach(b, grid)
	_colliders(b, grid)
	_art(b)
	b.get_parent().queue_free()
	await frames(2)
	await _stream()
	await _walk()
	print("[voxel zone] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


# --- bake ----------------------------------------------------------------------------------------


func _bake() -> void:
	var j: Dictionary = bake_s.read_json(ZONE)
	check(not j.is_empty(), "baked json exists (%s)" % bake_s.json_path(ZONE))
	check(
		String(j.get("hash", "")) == gen_s.input_hash(ZONE),
		"bake is fresh for the design and map (re-run tools/voxel/bake_zone.gd -- zone=%s)" % ZONE
	)
	check(
		String(j.get("source_hash", "")) == bake_s.source_hash(),
		"bake made by the current generator sources (re-run tools/voxel/bake_zone.gd)"
	)
	check(int(j.get("version", -1)) == gen_s.VERSION, "bake version %s" % j.get("version"))
	var path: String = bake_s.res_path(ZONE)
	var f := FileAccess.open(path, FileAccess.READ)
	var mb := f.get_length() / 1048576.0 if f else INF
	check(mb < MAX_BAKE_MB, "bake %.2f MB (< %.0f MB)" % [mb, MAX_BAKE_MB])


func _build(per_frame: int):
	var holder := Node3D.new()
	root.add_child(holder)
	var b = load("res://world/voxel/voxel_zone.gd").new()
	b.zone_id = ZONE
	b.items_per_frame = per_frame
	holder.add_child(b)
	b.build()
	if not b.is_built:
		await b.built
	await frames(2)
	print("  built in %d ms: %s" % [b.load_ms, b.counts])
	return b


## Art contracts: every prop light sits outside its model (a light inside a voxel is shadowed),
## the street furniture is there, house furniture (gutters, porch lantern, window-box flowers)
## fades with its house, the greenhouse panes are see-through and left alone by the fader, the
## chimneys smoke, butterflies fly over the beds, deep snow buries the flowers.
func _art(b) -> void:
	var models: GDScript = load("res://world/voxel/voxel_models.gd")
	var vs: float = models.PROP_VS
	for m in models.LIGHTS:
		var g = models.build(m)
		var off: Vector3 = models.LIGHTS[m][0]
		var v := Vector3i(roundi(off.x / vs), floori(off.y / vs), roundi(off.z / vs))
		check(not g.solid(v), "prop %s: its light %s is outside the model" % [m, off])
	var counts: Dictionary = b.counts
	check(int(counts.get("props", 0)) > 100, "street furniture: %d props" % counts.get("props", 0))
	check(int(counts.get("smoke", 0)) >= 2, "chimney smoke: %d plumes" % counts.get("smoke", 0))
	check(b.butterflies != null, "butterflies over the flower beds")
	check(int(counts.get("laundry", 0)) >= 1, "a washing line with clothes")
	check(int(counts.get("flags", 0)) >= 1, "a flag in the breeze")
	var grid: TileGrid = b.grid
	check(grid != null and grid.blocked(Vector2i(-22, 17)), "the washing line blocks its tiles")
	# A lone town tree fades for a player right behind it (north, under the crown): its fader rect
	# starts south of the player, so the rig counts it as between the player and the eye.
	var oak: Rect2 = Rect2()
	for n in b.find_children("*", "MultiMeshInstance3D", true, false):
		if not n.has_meta("rect"):
			continue
		var r: Rect2 = n.get_meta("rect")
		if r.has_point(Vector2(-21, 23)) and float(n.get_meta("height", 0.0)) > 3.0:
			oak = r
	check(oak.has_area(), "the oak at (-21, 22) has its own fader")
	check(
		oak.position.y > 20.0 and oak.position.y < 22.5,
		"oak fader rect starts south of a player at (-21, 20): %s" % oak
	)
	_faders(b)
	var house: Node3D = b.houses.get("player_house")
	var furn := 0
	for gi in house.get_meta("geoms", []):
		if gi is MultiMeshInstance3D:
			furn += 1
	check(furn > 0, "player house furniture fades with the house (%d multimeshes)" % furn)
	var gh: Node3D = b.houses.get("lab_greenhouse")
	var glass := false
	if gh:
		for ch in gh.get_children():
			if ch is MeshInstance3D and String(ch.name).begins_with("Glass"):
				glass = ch.transparency > 0.0 and not gh.get_meta("geoms").has(ch)
	check(glass, "the greenhouse panes are see-through and outside the fader")
	b.set_snow(0.9)
	var buried: Array = b._buried
	var hidden := not buried.is_empty() and buried.all(func(m) -> bool: return not m.visible)
	check(hidden, "deep snow buries %d flower / tall grass multimeshes" % buried.size())
	b.set_snow(0.0)
	check(buried.all(func(m) -> bool: return m.visible), "they come back when it melts")


## Camera faders: only lone geometry fades. A forest chunk never fades as a whole (it turned shrubs
## metres from the player into a murky ghost at the lab door): its tall trees that can hide a
## walkable tile fade one by one, low shrubs and bushes never. The town gate's arch (beam, board
## and lettering) fades like a house: right north of it the board hid the player.
func _faders(b) -> void:
	var chunk_faders: Array[String] = []
	var low: Array[String] = []
	var lone := 0
	for n in b.get_node("Trees").get_children():
		if not n is MultiMeshInstance3D or not n.has_meta("rect"):
			continue
		var mm: MultiMesh = n.multimesh
		if mm.instance_count != 1:
			chunk_faders.append(n.name)
		if not String(n.name).begins_with("prop_") and mm.mesh and mm.mesh.get_aabb().size.y <= 2.0:
			low.append(n.name)
		lone += 1
	check(
		chunk_faders.is_empty(), "no multi-tree chunk is a fader (%s)" % [chunk_faders.slice(0, 4)]
	)
	check(low.is_empty(), "no shrub or bush 2 m or lower is a fader (%s)" % [low.slice(0, 4)])
	var split := int(b.counts.get("lone_trees", 0))
	check(split > 20, "forest trees near the walkable tiles fade one by one (%d)" % split)
	print("  %d tree / prop faders, %d forest trees split out" % [lone, split])
	var gate: Node3D = null
	for id in b.houses:
		if String(id).begins_with("gate_"):
			gate = b.houses[id]
	check(gate != null, "the town gate's arch has its own fader")
	if gate == null:
		return
	var r: Rect2 = gate.get_meta("rect")
	var names: Array[String] = []
	for gi in gate.get_meta("geoms", []):
		names.append(String(gi.name))
	check(
		r.has_point(Vector2(0, -19)) and float(gate.get_meta("height")) > 2.0,
		"the gate fader covers the gateway (0, -19): %s, %.2f m" % [r, gate.get_meta("height")]
	)
	check(
		(
			names.any(func(nm: String) -> bool: return nm.begins_with("Arch"))
			and names.any(func(nm: String) -> bool: return nm.begins_with("text_"))
		),
		"the arch and its lettering fade together (%s)" % [names]
	)
	check(b.houses.size() == 6, "5 houses + the gate (%s)" % [b.houses.keys()])


## Streamed like route_world._stream_in: the bake loads on a thread (not headless), the nodes come
## within a time budget per frame. The frames are timed from the call, so the synchronous start
## (map, bake load headless) counts too. Old faders of the freed blocking build are gone from the
## registry once the zone registers again.
func _stream() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var b = load("res://world/voxel/voxel_zone.gd").new()
	b.zone_id = ZONE
	b.items_per_frame = 60
	holder.add_child(b)
	check(
		not load("res://world/voxel/voxel_zone.gd").threaded_load(),
		"headless: the bake loads blocking (dummy renderer)"
	)
	var t0 := Time.get_ticks_usec()
	b.build()
	var worst := 0
	var last := t0
	var n := 0
	while not b.is_built and Time.get_ticks_usec() - t0 < 30000000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		n += 1
	var total := (Time.get_ticks_usec() - t0) / 1000
	print("  streamed in %d ms over %d frames, longest frame %d ms" % [total, n, worst / 1000])
	check(b.is_built and not b.stale, "streamed build finished")
	check(
		worst / 1000 < MAX_STREAM_FRAME_MS,
		"no long stall while streaming (%d ms < %d)" % [worst / 1000, MAX_STREAM_FRAME_MS]
	)
	var dead := 0
	var live := 0
	var cells: Dictionary = load("res://world/props.gd")._cells
	for k in cells:
		for o in cells[k]:
			if is_instance_valid(o):
				live += 1
			else:
				dead += 1
	check(
		dead == 0,
		"fader registry: no faders of the freed build left (%d dead, %d live)" % [dead, live]
	)
	holder.queue_free()
	await frames(2)
	await _cut_short()


## A streamed build cut short: the zone leaves the tree while its worker task unpacks the colour
## volume (the scene changed: it resumes off the tree and stops quietly) or is freed (the zone
## unloaded or the game closed: _exit_tree waits for the task). An unwaited task aborted the
## engine at exit ("double free or corruption"), so this run would end with a crash, not exit 0.
func _cut_short() -> void:
	for freed in [false, true]:
		var holder := Node3D.new()
		root.add_child(holder)
		var b = load("res://world/voxel/voxel_zone.gd").new()
		b.zone_id = ZONE
		b.items_per_frame = 60
		holder.add_child(b)
		b.build()
		var running := false
		for i in 300:
			if b._vol_task >= 0:
				running = true
				break
			await process_frame
		check(running, "cut short: caught the build while its volume task runs")
		var kids: int = b.get_child_count()
		if freed:
			holder.queue_free()
			await frames(30)
			check(not is_instance_valid(b), "cut short: the zone freed mid-build")
		else:
			holder.remove_child(b)
			await frames(30)
			check(
				not b.is_built and b._vol_task == -1 and b.get_child_count() == kids,
				(
					"cut short: off the tree the build stops (built %s, task %d)"
					% [b.is_built, b._vol_task]
				)
			)
			b.free()
			holder.queue_free()
			await frames(2)


# --- placement -----------------------------------------------------------------------------------


static func _tile(a: Array) -> Vector2i:
	return Vector2i(roundi(float(a[0])), roundi(float(a[1])))


static func _centred(a: Array) -> bool:
	return (
		absf(float(a[0]) - roundf(float(a[0]))) < 0.01
		and absf(float(a[1]) - roundf(float(a[1]))) < 0.01
	)


static func _free(grid: TileGrid, c: Vector2i) -> bool:
	return grid.has(c) and not grid.blocked(c)


func _on_free(grid: TileGrid, what: String, a: Array) -> void:
	var c := _tile(a)
	check(
		_centred(a) and _free(grid, c),
		"%s on a free tile centre %s (flags %d)" % [what, c, grid.flag(c)]
	)


func _placement(b, grid: TileGrid) -> void:
	var d: Dictionary = b.data
	for name in b.arrivals:
		var at: Vector3 = b.arrivals[name]
		_on_free(grid, "arrival '%s'" % name, [at.x, at.z])
	for e in d.get("npcs", []):
		_on_free(grid, "npc %s" % e.get("node", e.name), e.pos)
	for e in d.get("pets", []):
		_on_free(grid, "pet %s" % e.node, e.pos)
	for e in d.get("items", []):
		_on_free(grid, "item %s" % e.get("uid", e.item), e.pos)
	for e in d.get("spawn_zones", []):
		var c := _tile(e.pos)
		if String(e.get("mode", "")) == "swim":
			check(
				_centred(e.pos) and grid.has_flag(c, TileGrid.WATER),
				"swim zone %s centred on water %s" % [e.name, c]
			)
		else:
			_on_free(grid, "spawn zone %s" % e.name, e.pos)
	# Signs and mailboxes are drawn in voxels: their own tile is solid, read from a free neighbour.
	for e in d.get("signs", []):
		var c := _tile(e.pos)
		var readable := false
		for dv in DIRS:
			readable = readable or _free(grid, c + dv)
		check(
			_centred(e.pos) and grid.has_flag(c, TileGrid.BLOCKED) and readable,
			"sign %s on a tile centre, solid, readable from a free tile" % e.name
		)


func _doors(b, grid: TileGrid) -> void:
	for e in b.data.get("buildings", []):
		var dr: Dictionary = e.get("door", {})
		check(dr.has("tile"), "building %s has a door tile" % e.id)
		if not dr.has("tile"):
			continue
		var t := _tile(dr.tile)
		check(grid.has_flag(t, TileGrid.DOOR), "door %s tile %s has the DOOR flag" % [e.id, t])
		check(_free(grid, t + Vector2i(0, 1)), "door %s: free tile in front" % e.id)
		var at: Vector3 = b.arrivals.get(String(dr.get("spawn", "")), Vector3.INF)
		check(
			Vector2(at.x, at.z).is_equal_approx(Vector2(t.x, t.y + 1)),
			"door %s: arrival '%s' on the doorstep (%s)" % [e.id, dr.get("spawn"), at]
		)
		check(b.get_node_or_null("Door_%s" % e.id) != null, "Door_%s placed" % e.id)


# --- reachability --------------------------------------------------------------------------------


func _reach(b, grid: TileGrid) -> void:
	var d: Dictionary = b.data
	var start: Vector3 = b.arrivals.get("start", Vector3.INF)
	var seen := {}
	var queue: Array[Vector2i] = [Vector2i(roundi(start.x), roundi(start.z))]
	seen[queue[0]] = true
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for dv in DIRS:
			var n := c + dv
			if not seen.has(n) and _free(grid, n):
				seen[n] = true
				queue.append(n)
	print("  %d tiles reachable from start" % seen.size())
	# No sealed pocket: a nearest-free-tile snap (an old save) never lands where nothing leads out.
	var lost: Array[Vector2i] = []
	for z in grid.size.y:
		for x in grid.size.x:
			var c := Vector2i(x, z) + grid.origin
			if _free(grid, c) and not seen.has(c):
				lost.append(c)
	check(
		lost.is_empty(),
		"every free tile is reachable from start (%d are not: %s)" % [lost.size(), lost.slice(0, 8)]
	)
	var goals := {"north gate": Vector2i(0, -19)}
	for e in d.get("buildings", []):
		var t := _tile(e.door.tile)
		goals["%s doorstep" % e.id] = t + Vector2i(0, 1)
	for e in d.get("npcs", []):
		goals[String(e.get("node", e.name))] = _tile(e.pos)
	for e in d.get("items", []):
		goals["item %s" % e.get("uid", "")] = _tile(e.pos)
	for e in d.get("spawn_zones", []):
		if String(e.get("mode", "")) != "swim":
			goals["spawn zone %s" % e.name] = _tile(e.pos)
	for name in goals:
		check(seen.has(goals[name]), "reachable from start: %s %s" % [name, goals[name]])
	for e in d.get("signs", []):
		var c := _tile(e.pos)
		var ok := false
		for dv in DIRS:
			ok = ok or seen.has(c + dv)
		check(ok, "reachable from start: a tile next to sign %s" % e.name)
	# The pond shore: a reachable tile next to the pond's water.
	var pond := _pond(b)
	check(pond.has_area(), "the pond is in the bake metadata")
	var shore := 0
	for c in seen:
		for dv in DIRS:
			var n: Vector2i = c + dv
			if grid.has_flag(n, TileGrid.WATER) and pond.has_point(Vector2(n.x, n.y)):
				shore += 1
				break
	check(shore > 10, "reachable from start: the pond shore (%d tiles)" % shore)


# --- colliders -----------------------------------------------------------------------------------


## Every tile centre inside the zone rect: covered by a wall box exactly when the tile is blocked
## (not water), by a Water body box exactly when it is water.
func _colliders(b, grid: TileGrid) -> void:
	var got := {}
	for body in [b.get_node("Solids"), b.get_node("Water")]:
		var code := 1 if body.name == "Solids" else 2
		for cs in body.get_children():
			if not cs is CollisionShape3D or not cs.shape is BoxShape3D:
				continue
			var sz: Vector3 = cs.shape.size
			var p: Vector3 = cs.position
			if p.y + sz.y / 2.0 < 0.5:
				continue  # the ground slab
			for z in range(ceili(p.z - sz.z / 2.0), floori(p.z + sz.z / 2.0) + 1):
				for x in range(ceili(p.x - sz.x / 2.0), floori(p.x + sz.x / 2.0) + 1):
					got[Vector2i(x, z)] = int(got.get(Vector2i(x, z), 0)) | code
	var r: Rect2 = b.rect
	var bad: Array[String] = []
	var tiles := 0
	for z in range(ceili(r.position.y), floori(r.end.y) + 1):
		for x in range(ceili(r.position.x), floori(r.end.x) + 1):
			var c := Vector2i(x, z)
			if not r.has_point(Vector2(x, z)):
				continue
			tiles += 1
			var f := grid.flag(c)
			var want := 2 if f & TileGrid.WATER else (1 if f & TileGrid.BLOCKED else 0)
			var have := int(got.get(c, 0))
			if have != want:
				bad.append("%s want %d got %d" % [c, want, have])
	check(
		bad.is_empty(),
		(
			"colliders match the tile grid over %d tiles (%d off: %s)"
			% [tiles, bad.size(), bad.slice(0, 6)]
		)
	)


# --- walking -------------------------------------------------------------------------------------


func _walk() -> void:
	Motion = load("res://world/grid/grid_motion.gd")
	Player = load("res://world/player.gd")
	var game = root.get_node("/root/Game")
	game.save_path = OS.get_user_data_dir().path_join("test_voxel_zone_save.json")
	game.save_enabled = false
	game.flags["got_starter"] = true  # no Oak at the north edge
	game.last_save = {}
	Player.force_zones = {}
	var story = root.get_node_or_null("Story")
	if story:
		story.auto_advance = true
		story.auto_answer = true
	game.spawn_request = {"zone": ZONE, "spawn": "start"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(8)
	p = get_first_node_in_group("ow_player")
	for i in 900:
		if w.builders.has(ZONE) and w.builders[ZONE].is_built and p.grid_active():
			break
		await physics_frame
	await frames(10)
	check(p.grid_active(), "walk: the player starts on Pallet's grid (map movement: grid)")
	var b = w.builders[ZONE]
	var g: TileGrid = b.grid
	var t0 := Time.get_ticks_msec()
	var steps0: int = _steps
	await _visit(b, g, "PlayerMailbox")
	await _enter(b, g, "player_house")
	await _visit(b, g, "RivalMailbox")
	await _enter(b, g, "rival_house")
	await _visit(b, g, "PalletSign")
	await _visit(b, g, "NPC_OldMan")
	var gate := Vector2i(0, -19)
	check(
		await _walk_to(g, func(c: Vector2i) -> bool: return c == gate, "the north gate"),
		"walk: reached the north gate %s" % gate
	)
	await _visit(b, g, "NPC_Girl")
	var pond := _pond(b)
	var shore := func(c: Vector2i) -> bool:
		for dv in DIRS:
			if g.has_flag(c + dv, TileGrid.WATER) and pond.has_point(Vector2(c + dv)):
				return true
		return false
	check(await _walk_to(g, shore, "the pond shore"), "walk: reached the pond shore")
	await _visit(b, g, "NPC_Scientist")
	await _visit(b, g, "LabSign")
	await _enter(b, g, "lab")
	print(
		(
			"  walked %d tiles in %.1f s (real), %d failed"
			% [_steps - steps0, (Time.get_ticks_msec() - t0) / 1000.0, _fails]
		)
	)
	_release()
	w.queue_free()
	await frames(4)


func _release() -> void:
	for a in Player.MOVES:
		Input.action_release(a)
	_held = ""


## The move key that walks toward grid direction `d` under the current camera.
func _key(d: Vector2i) -> String:
	for a in Player.MOVES:
		var s: Vector2i = Player.MOVES[a]
		if Motion.card(Motion.vec(s).rotated(Vector3.UP, p._camera_yaw())) == d:
			return a
	return ""


func _hold(a: String) -> void:
	if a == _held:
		return
	if _held != "":
		Input.action_release(_held)
	if a != "":
		Input.action_press(a)
	_held = a


## First step from `from` toward the nearest tile where goal holds, over tiles the player may step
## into right now (NPC claims and bodies included). ZERO when already there, MAX when cut off.
func _next_step(g: TileGrid, from: Vector2i, goal: Callable) -> Vector2i:
	if goal.call(from):
		return Vector2i.ZERO
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for dv in DIRS:
			var n := c + dv
			if prev.has(n) or not Motion.spot_free(g, n, p):
				continue
			prev[n] = c
			if goal.call(n):
				var s := n
				while prev[s] != from:
					s = prev[s]
				return s - from
			queue.append(n)
	return Vector2i.MAX


## Walks with the move keys to a tile where goal holds, planning again at every tile (wandering
## NPCs step into the way) and stopping on its centre. False after `limit` seconds of game time.
func _walk_to(g: TileGrid, goal: Callable, what: String, limit := 45.0) -> bool:
	var cell: Vector2i = p._cell
	var dir := _next_step(g, cell, goal)
	var n := 0
	while n < int(limit * Engine.physics_ticks_per_second):
		if p._cell != cell or n % 20 == 0:
			if p._cell != cell:
				_steps += 1
			cell = p._cell
			dir = _next_step(g, cell, goal)
		if dir == Vector2i.ZERO:
			_hold("")
			if not p._stepping:
				await frames(4)
				return Motion.card(p.global_position - Vector3(cell.x, 0, cell.y)) == Vector2i.ZERO
		else:
			_hold("" if dir == Vector2i.MAX else _key(dir))
		await physics_frame
		n += 1
	_release()
	print("  walk to %s stopped at %s (next %s)" % [what, p._cell, dir])
	return false


## Taps the key toward `d` (shorter than the turn delay): the player only turns. Nothing when `d`
## is not one tile along an axis (a wandering NPC stepped away).
func _face(d: Vector2i) -> void:
	_release()
	await frames(2)
	var a := _key(d)
	if a == "":
		return
	Input.action_press(a)
	await frames(2)
	Input.action_release(a)
	await frames(12)


func _cell_of(n: Node3D) -> Vector2i:
	return Vector2i(roundi(n.global_position.x), roundi(n.global_position.z))


## Walks next to the node `node_name` (an NPC, a sign, a mailbox), faces it and checks that it is
## the focus (the talk / read prompt). Tries again when a wandering NPC stepped away meanwhile.
func _visit(b, g: TileGrid, node_name: String) -> void:
	var n: Node3D = b.find_child(node_name, true, false)
	check(n != null, "walk: %s in the zone" % node_name)
	if n == null:
		return
	var ok := false
	for attempt in 3:
		var at := _cell_of(n)
		var next_to := func(c: Vector2i) -> bool: return (c - at).length_squared() == 1
		if not await _walk_to(g, next_to, node_name):
			break
		await _face(_cell_of(n) - p._cell)
		if p.focus == n:
			ok = true
			break
	check(ok, "walk: reached and faced %s at %s (focus %s)" % [node_name, _cell_of(n), p.focus])


## Walks to the doorstep of building `id`, pushes north into the door, checks the interior is
## entered, then comes back out through the door's arrival point onto the grid.
func _enter(b, g: TileGrid, id: String) -> void:
	var dr: Dictionary = {}
	for e in b.data.get("buildings", []):
		if e.id == id:
			dr = e.door
	var front := _tile(dr.tile) + Vector2i(0, 1)
	var there := await _walk_to(g, func(c: Vector2i) -> bool: return c == front, "%s door" % id)
	check(there, "walk: reached the %s doorstep %s" % [id, front])
	if not there:
		return
	_hold(_key(Vector2i(0, -1)))
	var entered := false
	for i in 120:
		await physics_frame
		if w.location_id != ZONE:
			entered = true
			break
	_release()
	check(
		entered, "walk: pushing north on the doorstep enters %s (now in %s)" % [id, w.location_id]
	)
	if not entered:
		return
	await frames(30)
	var game = root.get_node("/root/Game")
	for i in 1200:  # a story scene inside (auto-advanced) ends first
		if not game.is_busy() and not p.locked and not w.traveling:
			break
		await physics_frame
	await w.go_to_zone(ZONE, String(dr.spawn))
	await frames(30)
	check(
		w.location_id == ZONE and p.grid_active() and p._cell == front,
		"walk: back out of %s on the doorstep %s on the grid (%s)" % [id, front, p.global_position]
	)


static func _pond(b) -> Rect2:
	for e in b.bake.meta.get("water", []):
		if String(e.get("type", "")) == "pond":
			var r: Array = e.rect
			return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return Rect2()
