class_name VoxelZoneGen
extends RefCounted
## Voxel zone generator (docs/VOXEL.md §5): design (data/voxel/<zone>.json) + map
## (data/maps/<zone>.json) -> a VoxelGrid (terrain, water beds, buildings, trees, props), the
## zone's TileGrid (BLOCKED / WATER / DOOR / NO_NPC / COVER, heights) and the metadata the runtime
## needs: lamp lights, each building's parts (walls / roof / upper slab) with rect and height for
## the camera fader, water surfaces, fountain anchors and the decor instances (flowers, tufts,
## pebbles, crops, small props) built at the 1/16 m detail scale.
## Deterministic: every random choice hashes the voxel / tile (VoxelGrid.hash01) or uses
## FastNoiseLite with a fixed seed. Bump VERSION whenever the output changes for the same inputs
## (the bake hash includes it, tests/world/test_voxel_zone.gd fails on a stale bake).

const VERSION := 1
const Y_MIN := -10  ## lowest voxel layer (-2.5 m): water beds and banks go down to here
const Y_LAYERS := 60  ## up to voxel 49 (12.5 m): roofs, chimneys, tall trees
const WATER_Y := -0.19  ## default water surface (m): a small bank under the ground top
const SOLID_H := 4.0  ## height of the tile colliders (m)
const CROWN_CELL := 8  ## metres per crown part cell (sway + see-through fading per cell)
const PART_CROWN0 := 32  ## first crown part id (buildings use 1..31)
const DECOR_CHUNK := 16.0  ## metres per decor MultiMesh chunk

var zone_id := ""
var d: VoxelDesign
var map: Dictionary = {}
var g: VoxelGrid
var tiles: TileGrid
## Per voxel column (index (x - ox) + sx * (z - oz)): top solid voxel y of the terrain.
var top := PackedInt32Array()
var wet := PackedByteArray()  ## 1 = water column (carved)
## Tile analysis (index over the design extent).
var walk_dist := PackedInt32Array()  ## Chebyshev distance to the nearest walkable tile
var water_dist := PackedInt32Array()
var tile_h := PackedFloat32Array()  ## decorative relief (m) per tile
## Tiles blocked / covered by what the generator placed (Vector2i -> true).
var blocks := {}
var covers := {}
var no_npc := {}
var meta := {
	"buildings": [],
	"lights": [],
	"water": [],
	"fountains": [],
	"parts": {},
	"crowns": [],
	"signs": [],
	"trees": 0,
}
## Decor at the detail scale: model name -> Array[Transform3D]; model name -> {"mesh", "sway",
## "shadow"} (VoxelFlora builds the meshes).
var decor := {}
var models := {}
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var timings := {}

var _ox := 0
var _oz := 0
var _sx := 0
var _sz := 0
var _next_part := 1


## Runs the whole generator for a zone; null when it has no design.
static func run(id: String) -> VoxelZoneGen:
	var gen := VoxelZoneGen.new()
	if not gen.setup(id):
		return null
	gen.generate()
	return gen


## Inputs hash: design JSON + map JSON + VERSION (the bake stores it).
static func input_hash(id: String) -> String:
	var dp := VoxelDesign.path_of(id)
	var mp := "res://data/maps/%s.json" % id
	var s := "v%d|" % VERSION
	s += FileAccess.get_file_as_string(dp) if FileAccess.file_exists(dp) else ""
	s += "|"
	s += FileAccess.get_file_as_string(mp) if FileAccess.file_exists(mp) else ""
	return s.md5_text()


func setup(id: String) -> bool:
	zone_id = id
	d = VoxelDesign.load_design(id)
	if d == null:
		return false
	var errs := d.validate()
	if not errs.is_empty():
		push_error("VoxelZoneGen %s: %s" % [id, "; ".join(errs)])
		return false
	var mp := "res://data/maps/%s.json" % id
	var mj = (
		JSON.parse_string(FileAccess.get_file_as_string(mp)) if FileAccess.file_exists(mp) else null
	)
	map = mj if mj is Dictionary else {}
	noise.seed = hash(id)
	noise.frequency = 0.08
	noise2.seed = hash(id) + 17
	noise2.frequency = 0.31
	var ext := d.extent()
	_ox = 4 * ext.position.x - 2
	_oz = 4 * ext.position.y - 2
	_sx = ext.size.x * 4
	_sz = ext.size.y * 4
	g = VoxelGrid.new(Vector3i(_ox, Y_MIN, _oz), Vector3i(_sx, Y_LAYERS, _sz))
	var r := d.rect
	tiles = TileGrid.new(r.position, r.size)
	top.resize(_sx * _sz)
	top.fill(-1)
	wet.resize(_sx * _sz)
	return true


func generate() -> void:
	var t0 := Time.get_ticks_msec()
	_analyse_tiles()
	_terrain_heights()
	_paint_terrain()
	_water_meta()
	_mark("terrain", t0)
	t0 = Time.get_ticks_msec()
	VoxelBuild.buildings(self)
	_mark("buildings", t0)
	t0 = Time.get_ticks_msec()
	VoxelProps.things(self)
	VoxelProps.objects(self)
	VoxelProps.signs(self)
	_mark("props", t0)
	t0 = Time.get_ticks_msec()
	_tile_grid()
	VoxelFlora.scatter(self)
	_mark("decor", t0)


func _mark(k: String, t0: int) -> void:
	timings[k] = Time.get_ticks_msec() - t0


# --- coordinates ---------------------------------------------------------------------------------


## First voxel (x or z) of tile t.
static func v0(t: int) -> int:
	return 4 * t - 2


## Tile of voxel x or z.
static func tile_of(v: int) -> int:
	return floori((v + 2) / 4.0)


func col(vx: int, vz: int) -> int:
	return (vx - _ox) + _sx * (vz - _oz)


func has_col(vx: int, vz: int) -> bool:
	return vx >= _ox and vz >= _oz and vx < _ox + _sx and vz < _oz + _sz


## Terrain top voxel y at a column (-1 = ground at y 0), Y_MIN - 1 outside.
func top_at(vx: int, vz: int) -> int:
	return top[col(vx, vz)] if has_col(vx, vz) else Y_MIN - 1


## Ground height (m) at a tile centre (top of the terrain under its central columns).
func ground_y(t: Vector2i) -> float:
	return (top_at(v0(t.x) + 2, v0(t.y) + 2) + 1) * VoxelGrid.VS


func is_wet_col(vx: int, vz: int) -> bool:
	return has_col(vx, vz) and wet[col(vx, vz)] == 1


func _ti(t: Vector2i) -> int:
	return (t.x - d.origin.x) + d.size.x * (t.y - d.origin.y)


func new_part(info: Dictionary) -> int:
	var p := _next_part
	_next_part += 1
	meta.parts[p] = info
	return p


## Crown part of the 8 m cell containing metre position (x, z).
func crown_part(x: float, z: float) -> int:
	var ext := d.extent_m()
	var cx := int(floor((x - ext.position.x) / CROWN_CELL))
	var cz := int(floor((z - ext.position.y) / CROWN_CELL))
	var ncx := int(ceil(ext.size.x / CROWN_CELL))
	var p := PART_CROWN0 + clampi(cx, 0, ncx - 1) + ncx * maxi(cz, 0)
	if not meta.parts.has(p):
		meta.parts[p] = {
			"kind": "crown",
			"rect":
			Rect2(
				ext.position.x + cx * CROWN_CELL,
				ext.position.y + cz * CROWN_CELL,
				CROWN_CELL,
				CROWN_CELL
			),
			"height": 6.0,
		}
		meta.crowns.append(p)
	return mini(p, 255)


func block(t: Vector2i) -> void:
	blocks[t] = true


func add_decor(model: String, xf: Transform3D) -> void:
	if not decor.has(model):
		decor[model] = []
	decor[model].append(xf)


func add_light(
	pos: Vector3, kind: String, color := Color(1.0, 0.78, 0.5), energy := 3.0, rng := 7.0
) -> void:
	meta.lights.append({"pos": pos, "kind": kind, "color": color, "energy": energy, "range": rng})


# --- tile analysis ---------------------------------------------------------------------------------


## A design tile a character could stand on (inside the rect, dry, nothing on it).
func walkable(t: Vector2i) -> bool:
	if not d.in_rect(t):
		return false
	if d.is_water(t):
		return false
	return d.thing_kind(t) == ""


func _analyse_tiles() -> void:
	var n := d.size.x * d.size.y
	walk_dist.resize(n)
	water_dist.resize(n)
	walk_dist.fill(1 << 20)
	water_dist.fill(1 << 20)
	var qw: Array[Vector2i] = []
	var qa: Array[Vector2i] = []
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			if walkable(t):
				walk_dist[_ti(t)] = 0
				qw.append(t)
			if d.is_wet(t):
				water_dist[_ti(t)] = 0
				qa.append(t)
	_bfs(qw, walk_dist)
	_bfs(qa, water_dist)


func _bfs(q: Array[Vector2i], dist: PackedInt32Array) -> void:
	var head := 0
	while head < q.size():
		var t: Vector2i = q[head]
		head += 1
		var dv := dist[_ti(t)] + 1
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var u := t + Vector2i(dx, dz)
				if not d.has_tile(u):
					continue
				var i := _ti(u)
				if dist[i] > dv:
					dist[i] = dv
					q.append(u)


func dist_walk(t: Vector2i) -> int:
	return walk_dist[_ti(t)] if d.has_tile(t) else 99


func dist_water(t: Vector2i) -> int:
	return water_dist[_ti(t)] if d.has_tile(t) else 99


# --- terrain ---------------------------------------------------------------------------------------


## Decorative relief outside the walkable town: low hills that rise with the distance to the nearest
## walkable tile and stay flat near water; the town itself is flat at y 0.
func _relief_of(t: Vector2i) -> float:
	var k := d.ground_kind(t)
	if k in VoxelDesign.WATER_KINDS or k in VoxelDesign.OVER_WATER:
		return 0.0
	var th := d.thing_kind(t)
	if th != "forest" and th != "" and th != "rock":
		return 0.0
	var dw := dist_walk(t)
	if dw < 3:
		return 0.0
	var ramp := clampf((dw - 2.5) / 5.0, 0.0, 1.0) * clampf((dist_water(t) - 1.5) / 3.0, 0.0, 1.0)
	var n := noise.get_noise_2d(t.x * 1.0, t.y * 1.0) * 0.5 + 0.5
	return ramp * (0.4 + 2.6 * n)


func _terrain_heights() -> void:
	tile_h.resize(d.size.x * d.size.y)
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			tile_h[_ti(t)] = _relief_of(t)
	# Columns: bilinear relief between tile centres (smooth slopes), quantised to voxels.
	for vz in range(_oz, _oz + _sz):
		var mz := (vz + 0.5) * VoxelGrid.VS
		for vx in range(_ox, _ox + _sx):
			var mx := (vx + 0.5) * VoxelGrid.VS
			var h := _bilinear_h(mx, mz)
			if h > 0.0:
				h += noise2.get_noise_2d(mx * 2.0, mz * 2.0) * 0.18
			top[col(vx, vz)] = maxi(roundi(h / VoxelGrid.VS), 0) - 1
	_carve_water()


func _tile_h_at(t: Vector2i) -> float:
	if not d.has_tile(t):
		return tile_h[_ti(
			Vector2i(
				clampi(t.x, d.origin.x, d.origin.x + d.size.x - 1),
				clampi(t.y, d.origin.y, d.origin.y + d.size.y - 1)
			)
		)]
	return tile_h[_ti(t)]


func _bilinear_h(mx: float, mz: float) -> float:
	var x0 := floori(mx)
	var z0 := floori(mz)
	var fx := mx - x0
	var fz := mz - z0
	var a := _tile_h_at(Vector2i(x0, z0))
	var b := _tile_h_at(Vector2i(x0 + 1, z0))
	var c := _tile_h_at(Vector2i(x0, z0 + 1))
	var e := _tile_h_at(Vector2i(x0 + 1, z0 + 1))
	var h := lerpf(lerpf(a, b, fx), lerpf(c, e, fx), fz)
	# Never raise the columns of a flat tile (the town, paths, shores) above 0.
	if _tile_h_at(Vector2i(roundi(mx), roundi(mz))) <= 0.0:
		return 0.0
	return h


func _wet_value(t: Vector2i) -> float:
	return 1.0 if d.is_wet(t) else 0.0


func _depth_of(t: Vector2i) -> float:
	match d.ground_kind(t):
		"deep":
			return 1.45
		"shallow":
			return 0.6
		"dock", "bridge":
			return 0.7
	return 0.0


## Smooth water outline at voxel resolution (bilinear between tile centres + noise), then a bed that
## slopes down from the shore (distance transform over the columns).
func _carve_water() -> void:
	var dist := PackedInt32Array()
	dist.resize(_sx * _sz)
	dist.fill(1 << 20)
	var q: Array[Vector2i] = []
	for vz in range(_oz, _oz + _sz):
		var mz := (vz + 0.5) * VoxelGrid.VS
		for vx in range(_ox, _ox + _sx):
			var mx := (vx + 0.5) * VoxelGrid.VS
			var x0 := floori(mx)
			var z0 := floori(mz)
			var fx := mx - x0
			var fz := mz - z0
			var v := lerpf(
				lerpf(_wet_value(Vector2i(x0, z0)), _wet_value(Vector2i(x0 + 1, z0)), fx),
				lerpf(_wet_value(Vector2i(x0, z0 + 1)), _wet_value(Vector2i(x0 + 1, z0 + 1)), fx),
				fz
			)
			v += noise2.get_noise_2d(mx * 3.0, mz * 3.0) * 0.22
			var i := col(vx, vz)
			if v > 0.5 and top[i] == -1:
				wet[i] = 1
			else:
				dist[i] = 0
				q.append(Vector2i(vx, vz))
	# Distance to the shore (in columns).
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var dv := dist[col(c.x, c.y)] + 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var u: Vector2i = c + o
			if not has_col(u.x, u.y):
				continue
			var j := col(u.x, u.y)
			if dist[j] > dv:
				dist[j] = dv
				q.append(u)
	for vz in range(_oz, _oz + _sz):
		var mz := (vz + 0.5) * VoxelGrid.VS
		for vx in range(_ox, _ox + _sx):
			var i := col(vx, vz)
			if wet[i] == 0:
				continue
			var mx := (vx + 0.5) * VoxelGrid.VS
			var x0 := floori(mx)
			var z0 := floori(mz)
			var fx := mx - x0
			var fz := mz - z0
			var want := lerpf(
				lerpf(_depth_of(Vector2i(x0, z0)), _depth_of(Vector2i(x0 + 1, z0)), fx),
				lerpf(_depth_of(Vector2i(x0, z0 + 1)), _depth_of(Vector2i(x0 + 1, z0 + 1)), fx),
				fz
			)
			var w := water_at(mx, mz)
			want = maxf(want, float(w.get("depth", 0.0)) * clampf(want / 1.45, 0.3, 1.0))
			var dm := minf(maxf(want, 0.3), 0.2 + dist[i] * 0.22)
			dm += noise2.get_noise_2d(mx * 1.7, mz * 1.7) * 0.12
			var dv := clampi(roundi(dm / VoxelGrid.VS), 1, 7)
			top[i] = maxi(floori(float(w.get("level", WATER_Y)) / VoxelGrid.VS) - dv, Y_MIN + 1)


## The design's water object (pond / stream) whose rect holds metre point (x, z), else {}.
func water_at(x: float, z: float) -> Dictionary:
	for o in d.objects:
		if String(o.get("kind", "")) != "water":
			continue
		var r: Array = o.rect
		if x >= r[0] - 0.5 and x < r[2] + 0.5 and z >= r[1] - 0.5 and z < r[3] + 0.5:
			return o
	return {}


## Water surfaces (metadata): one per design water object.
func _water_meta() -> void:
	for o in d.objects:
		if String(o.get("kind", "")) != "water":
			continue
		var r: Array = o.rect
		var f: Array = o.get("flow", [0, 0])
		var e := {
			"type": String(o.get("type", "pond")),
			"rect": Rect2(r[0] - 0.5, r[1] - 0.5, r[2] - r[0] + 1, r[3] - r[1] + 1),
			"level": float(o.get("level", WATER_Y)),
			"depth": float(o.get("depth", 1.0)),
			"flow": Vector2(float(f[0]), float(f[1])),
		}
		meta.water.append(e)


## Ground kind of a column (its tile's), with relief and water.
func _paint_terrain() -> void:
	var data := PackedByteArray()
	data.resize(_sx * _sz * Y_LAYERS * 4)
	var sxz := _sx * _sz
	for vz in range(_oz, _oz + _sz):
		var tz := tile_of(vz)
		var lz := vz - v0(tz)
		for vx in range(_ox, _ox + _sx):
			var tx := tile_of(vx)
			var lx := vx - v0(tx)
			var t := Vector2i(tx, tz)
			var i := col(vx, vz)
			var tp := top[i]
			var surf := _surface(t, vx, vz, lx, lz, tp)
			var sc: Color = surf[0]
			var sm: int = surf[1]
			var under: Color = surf[2]
			var um: int = surf[3]
			var base := (vx - _ox) + _sx * (vz - _oz)
			for y in range(Y_MIN, tp + 1):
				var c := sc
				var m := sm
				if y < tp:
					var depth := tp - y
					if depth <= 2:
						c = under
						m = um
					else:
						c = VoxelPal.at(VoxelPal.ROCK_DARK, Vector3i(vx, y, vz), 0.1, 3)
						m = VoxelMat.STONE
					if wet[i] == 1 and depth <= 2:
						c = VoxelPal.at(VoxelPal.BED_MUD, Vector3i(vx, y, vz), 0.1, 4)
						m = VoxelMat.BED
				var k := (base + sxz * (y - Y_MIN)) * 4
				data[k] = clampi(int(c.r * 255.0 + 0.5), 0, 255)
				data[k + 1] = clampi(int(c.g * 255.0 + 0.5), 0, 255)
				data[k + 2] = clampi(int(c.b * 255.0 + 0.5), 0, 255)
				data[k + 3] = m
	g.data = data
	g.part.resize(_sx * _sz * Y_LAYERS)
	g.part.fill(0)


## [top colour, top material, under colour, under material] of a terrain column.
func _surface(t: Vector2i, vx: int, vz: int, lx: int, lz: int, tp: int) -> Array:
	var v := Vector3i(vx, tp, vz)
	var i := col(vx, vz)
	if wet[i] == 1:
		var deep := clampf((-1.0 - tp) / 6.0, 0.0, 1.0)
		var bc := VoxelPal.BED_SAND.lerp(VoxelPal.BED_MUD, deep)
		bc = VoxelPal.vary(bc, VoxelGrid.hash01(vx, 0, vz, 5), 0.12)
		if VoxelGrid.hash01(vx, 1, vz, 6) < 0.08:
			bc = VoxelPal.at(VoxelPal.ROCK, v, 0.15, 7)
		return [bc, VoxelMat.BED, VoxelPal.BED_MUD, VoxelMat.BED]
	var kind := d.ground_kind(t)
	if tp > -1:  # relief: forest floor on top, earth under
		var c := _grass_color(VoxelPal.FOREST_FLOOR, vx, vz, 0.12)
		if VoxelGrid.hash01(vx, 2, vz, 8) < 0.12:
			c = VoxelPal.at(VoxelPal.MOSS, v, 0.1, 9)
		return [c, VoxelMat.GRASS, VoxelPal.at(VoxelPal.DIRT_DARK, v, 0.12, 10), VoxelMat.DIRT]
	var near_water := _near_wet(vx, vz, 1)
	match kind:
		"cobble":
			return [_cobble(t, vx, vz, lx, lz), VoxelMat.STONE, VoxelPal.CURB, VoxelMat.STONE]
		"slab":
			return [_slab(t, vx, vz, lx, lz), VoxelMat.SLAB, VoxelPal.SLAB_BORDER, VoxelMat.STONE]
		"dirt":
			return [_dirt(t, vx, vz, lx, lz), VoxelMat.DIRT, VoxelPal.DIRT_DARK, VoxelMat.DIRT]
		"soil":
			var furrow := (vx if _crop_rows_z(t) else vz) % 2 == 0
			var sc := VoxelPal.SOIL if furrow else VoxelPal.SOIL_DARK
			return [VoxelPal.at(sc, v, 0.08, 11), VoxelMat.DIRT, VoxelPal.SOIL_DARK, VoxelMat.DIRT]
		"sand", "shallow", "deep", "dock", "bridge":
			var c := VoxelPal.at(VoxelPal.SAND, v, 0.07, 12)
			if near_water:
				c = VoxelPal.at(VoxelPal.SAND_WET, v, 0.07, 13)
			elif _edge_mix(t, vx, vz, lx, lz, ["lawn", "meadow", "flowers", "forest_floor"], 0.35):
				c = _grass_color(VoxelPal.LAWN, vx, vz, 0.1)
				return [c, VoxelMat.GRASS, VoxelPal.DIRT_DARK, VoxelMat.DIRT]
			return [c, VoxelMat.SAND, VoxelPal.SAND_WET, VoxelMat.SAND]
		"forest_floor":
			var c := _grass_color(VoxelPal.FOREST_FLOOR, vx, vz, 0.12)
			var h := VoxelGrid.hash01(vx, 3, vz, 14)
			if h < 0.1:
				c = VoxelPal.at(VoxelPal.MOSS, v, 0.1, 15)
			elif h < 0.16:
				c = VoxelPal.at(VoxelPal.DIRT_DARK, v, 0.1, 16)
			return [c, VoxelMat.GRASS, VoxelPal.DIRT_DARK, VoxelMat.DIRT]
		"meadow":
			var c := _grass_color(VoxelPal.MEADOW, vx, vz, 0.14)
			if VoxelGrid.hash01(vx, 4, vz, 17) < 0.06:
				c = VoxelPal.at(VoxelPal.LAWN_DRY, v, 0.08, 18)
			return [c, VoxelMat.GRASS, VoxelPal.DIRT_DARK, VoxelMat.DIRT]
	# lawn, flowers
	var c := _grass_color(VoxelPal.LAWN, vx, vz, 0.1)
	if _edge_mix(t, vx, vz, lx, lz, ["dirt", "sand"], 0.22):
		c = _dirt(t, vx, vz, lx, lz)
		return [c, VoxelMat.DIRT, VoxelPal.DIRT_DARK, VoxelMat.DIRT]
	return [c, VoxelMat.GRASS, VoxelPal.DIRT_DARK, VoxelMat.DIRT]


func _grass_color(base: Color, vx: int, vz: int, amt: float) -> Color:
	var mx := vx * 0.25
	var mz := vz * 0.25
	var patch := noise.get_noise_2d(mx * 3.0, mz * 3.0)
	var c := base.lerp(VoxelPal.LAWN_LIGHT, clampf(patch * 0.8 + 0.15, 0.0, 0.6))
	var dry := noise2.get_noise_2d(mx * 0.7 + 40.0, mz * 0.7)
	if dry > 0.35:
		c = c.lerp(VoxelPal.LAWN_DRY, (dry - 0.35) * 0.8)
	return VoxelPal.vary(c, VoxelGrid.hash01(vx, 7, vz, 19), amt)


## Cobbles: 2-voxel stones in running bond, a darker curb row where the street meets other ground.
func _cobble(t: Vector2i, vx: int, vz: int, lx: int, lz: int) -> Color:
	if _edge_of(t, lx, lz, ["cobble", "slab"]):
		return VoxelPal.at(VoxelPal.CURB, Vector3i(vx, 0, vz), 0.08, 20)
	var sid := floori((vx + (vz & 1)) / 2.0)
	var h := VoxelGrid.hash01(sid, 9, vz, 21)
	var base := VoxelPal.COBBLE
	if h < 0.3:
		base = VoxelPal.COBBLE_DARK
	elif h < 0.5:
		base = VoxelPal.COBBLE_WARM
	return VoxelPal.vary(base, VoxelGrid.hash01(sid, 10, vz, 22), 0.07)


## Paving slabs: 2 x 2 voxels, warm stone, a border row against grass.
func _slab(t: Vector2i, vx: int, vz: int, lx: int, lz: int) -> Color:
	if _edge_of(t, lx, lz, ["slab", "cobble", "dock", "bridge"]):
		return VoxelPal.at(VoxelPal.SLAB_BORDER, Vector3i(vx, 0, vz), 0.06, 23)
	var sx := floori(vx / 2.0)
	var sz := floori(vz / 2.0)
	var base := VoxelPal.SLAB if (sx + sz) % 2 == 0 else VoxelPal.SLAB_DARK
	return VoxelPal.vary(base, VoxelGrid.hash01(sx, 11, sz, 24), 0.06)


func _dirt(t: Vector2i, vx: int, vz: int, lx: int, lz: int) -> Color:
	var v := Vector3i(vx, 0, vz)
	var h := VoxelGrid.hash01(vx, 12, vz, 25)
	if h < 0.05:
		return VoxelPal.at(VoxelPal.ROCK_LIGHT, v, 0.1, 26)
	var n := noise2.get_noise_2d(vx * 0.6, vz * 0.6)
	var c := VoxelPal.DIRT.lerp(VoxelPal.DIRT_DARK, clampf(n * 0.8 + 0.2, 0.0, 1.0))
	return VoxelPal.vary(c, VoxelGrid.hash01(vx, 13, vz, 27), 0.08)


## Crop rows run along z when the field is taller than wide.
func _crop_rows_z(t: Vector2i) -> bool:
	var up := d.ground_kind(t + Vector2i(0, -1)) == "soil"
	var down := d.ground_kind(t + Vector2i(0, 1)) == "soil"
	return up or down


## True on the outer voxel row of a tile whose neighbour on that side is not one of `same`.
func _edge_of(t: Vector2i, lx: int, lz: int, same: Array) -> bool:
	if lx == 0 and not d.ground_kind(t + Vector2i(-1, 0)) in same:
		return true
	if lx == 3 and not d.ground_kind(t + Vector2i(1, 0)) in same:
		return true
	if lz == 0 and not d.ground_kind(t + Vector2i(0, -1)) in same:
		return true
	if lz == 3 and not d.ground_kind(t + Vector2i(0, 1)) in same:
		return true
	return false


## Random voxels of the outer rows take the neighbour's ground when it is one of `kinds`.
func _edge_mix(t: Vector2i, vx: int, vz: int, lx: int, lz: int, kinds: Array, p: float) -> bool:
	var h := VoxelGrid.hash01(vx, 14, vz, 28)
	if h >= p:
		return false
	if lx == 0 and d.ground_kind(t + Vector2i(-1, 0)) in kinds:
		return true
	if lx == 3 and d.ground_kind(t + Vector2i(1, 0)) in kinds:
		return true
	if lz == 0 and d.ground_kind(t + Vector2i(0, -1)) in kinds:
		return true
	if lz == 3 and d.ground_kind(t + Vector2i(0, 1)) in kinds:
		return true
	return false


func _near_wet(vx: int, vz: int, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if is_wet_col(vx + dx, vz + dz):
				return true
	return false


# --- tile grid -------------------------------------------------------------------------------------


func _tile_grid() -> void:
	var r := d.rect
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var t := Vector2i(x, z)
			var f := 0
			if d.is_water(t):
				f |= TileGrid.WATER
			elif blocks.has(t) or d.thing_kind(t) != "":
				f |= TileGrid.BLOCKED
			if d.tch(t) == "d" and _is_real_door(t):
				f |= TileGrid.DOOR | TileGrid.BLOCKED
			if no_npc.has(t):
				f |= TileGrid.NO_NPC
			if covers.has(t):
				f |= TileGrid.COVER
			tiles.flags[(x - r.position.x) + (z - r.position.y) * r.size.x] = f
			tiles.set_height(t, maxf(ground_y(t), 0.0) if f & TileGrid.BLOCKED else 0.0)


## A 'd' tile that belongs to a map building with a door (not the shed's painted door).
func _is_real_door(t: Vector2i) -> bool:
	for b in meta.buildings:
		if b.get("door", Vector2i(-99999, 0)) == t and b.get("map", false):
			return true
	return false


# --- results ---------------------------------------------------------------------------------------


## Metadata as plain JSON-able values (the bake writes it next to the meshes).
func meta_json() -> Dictionary:
	var out := {
		"version": VERSION,
		"zone": zone_id,
		"grid_origin": [g.origin.x, g.origin.y, g.origin.z],
		"grid_size": [g.size.x, g.size.y, g.size.z],
		"water_y": WATER_Y,
		"trees": int(meta.trees),
		"buildings": [],
		"lights": [],
		"water": [],
		"fountains": [],
		"parts": {},
		"crowns": meta.crowns,
		"signs": meta.signs,
		"smoke": _jsonable(meta.get("smoke", [])),
		"beacons": _jsonable(meta.get("beacons", [])),
	}
	for b in meta.buildings:
		var e := {}
		for k in b:
			e[k] = _jsonable(b[k])
		out.buildings.append(e)
	for l in meta.lights:
		out.lights.append(
			{
				"pos": _jsonable(l.pos),
				"kind": l.kind,
				"color": l.color.to_html(false),
				"energy": l.energy,
				"range": l.range
			}
		)
	for w in meta.water:
		var e := {}
		for k in w:
			e[k] = _jsonable(w[k])
		out.water.append(e)
	for f in meta.fountains:
		out.fountains.append(_jsonable(f))
	for p in meta.parts:
		var e := {}
		for k in meta.parts[p]:
			e[k] = _jsonable(meta.parts[p][k])
		out.parts[str(p)] = e
	return out


static func _jsonable(v):
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [v.x, v.y, v.z]
		TYPE_RECT2, TYPE_RECT2I:
			return [v.position.x, v.position.y, v.size.x, v.size.y]
		TYPE_COLOR:
			return v.to_html(false)
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(_jsonable(x))
			return a
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[str(k)] = _jsonable(v[k])
			return o
	return v
