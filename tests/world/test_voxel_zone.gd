extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_voxel_zone.gd
## The voxel Pallet Town (docs/VOXEL.md §5). The committed bake is fresh: its hash matches the
## design, the map and the generator sources. The gameplay of data/maps/pallet_town.json sits on
## the baked tile grid: free tile centres, water for swim zones, doors with a free doorstep. Every
## place the story needs can be reached on foot from "start". The colliders are exactly the blocked
## and water tiles. The zone loads fast, both blocking and streamed.
## The scripts are loaded by path: a SceneTree script compiles before the autoloads exist.

const ZONE := "pallet_town"
const MAX_BAKE_MB := 10.0
const MAX_LOAD_MS := 3000  ## blocking build from a fresh bake (headless)
const MAX_STREAM_FRAME_MS := 400  ## longest frame while streaming the zone in (headless)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _fails := 0
var bake_s: GDScript
var gen_s: GDScript


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
	b.get_parent().queue_free()
	await frames(2)
	await _stream()
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


## Streamed like route_world._stream_in: the bake loads on a thread, the nodes come a few per frame.
func _stream() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var b = load("res://world/voxel/voxel_zone.gd").new()
	b.zone_id = ZONE
	b.items_per_frame = 60
	holder.add_child(b)
	var t0 := Time.get_ticks_usec()
	b.build()
	var worst := 0
	var last := Time.get_ticks_usec()
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
	var pond := Rect2()
	for w in b.bake.meta.get("water", []):
		if String(w.get("type", "")) == "pond":
			var r: Array = w.rect
			pond = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
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
