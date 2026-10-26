class_name ArenaFloor
extends Node3D
## Voxel floor of the energy-mode training field (docs/VOXEL.md §7): one voxel layer whose top is
## exactly y = 0, painted per 1 m tile with the scenario's ground (turf, meadow, quarry, beach,
## ruins, snow, basalt, cave, swamp), white chalk lines (the boundary where the fighters stop, the
## centre line and circle, the trainer boxes) and the barrier on the real bounds of the court (gaps
## for the trainers; montanha keeps its cliff instead of the back wall). Outside the barrier, up to
## MARGIN m, the concourse paving (the stadium goes beyond it).
## - The painted floor and the barrier are cached per scenario + size (_base); each fight copies the
##   floor, opens the pond holes and lava channels, paints the shores, the tall-grass ground and the
##   scorched rims, and marks the footprints of what stands on it as context cells (part CTX_FOOT in
##   the layer above, never meshed) so the floor gets voxel AO around their bases. forget() clears a
##   footprint when the thing goes away (hill collapse, crate broken).
## - Under fast_sim nothing is built (BattleTerrain.voxel_vis).

## Floor beyond the court on each side (m).
const MARGIN := 4.0
## Barrier: thickness and height (camera side lower), gap half-width for the trainers.
const WALL := 0.5
const WALL_H := 0.75
const WALL_H_FRONT := 0.5
const GATE := 1.5
## Centre circle radius.
const CIRCLE_R := 4.5
## Trainer box (beyond the barrier, around the trainer spot) and the half-width of the carpet
## from it to the players' tunnel.
const BOX := Vector2(1.75, 1.5)
const CARPET := 1.0
## Ring of the Poke Ball "button" painted on the centre spot.
const BUTTON_R := 0.95
const FLOOR_PART := 1
const CTX_FOOT := 2

const VS := VoxelGrid.VS

static var _base := {}

var terrain  ## BattleTerrain
var grid: VoxelGrid
var mat: ShaderMaterial
var _feet := {}  ## Vector2i key -> Array of footprint cells (Vector3i)


## Builds the floor of this fight (BattleTerrain.setup, after every obstacle is placed).
static func build(ter) -> ArenaFloor:
	var arena: Node = ter.arena
	var rc: Rect2 = arena.rect
	var sc: String = ter.scenario
	var back: bool = not (sc == "montanha" and not ter.biomes.cliff.is_empty())
	var key := (
		"%s_%.1f_%.1f_%.1f_%.1f_%d"
		% [sc, rc.position.x, rc.position.y, rc.size.x, rc.size.y, int(back)]
	)
	if not _base.has(key):
		if _base.size() > 24:
			_base.clear()
		_base[key] = _make_base(sc, rc, back)
	var base: Dictionary = _base[key]
	var f := ArenaFloor.new()
	f.name = "ArenaFloor"
	f.terrain = ter
	var bg: VoxelGrid = base.grid
	f.grid = VoxelGrid.new(bg.origin, bg.size)
	f.grid.data = bg.data.duplicate()
	f.grid.part = bg.part.duplicate()
	f._carve(ter)
	var meshes := VoxelMesher.greedy(f.grid)
	f.mat = VoxelMat.material(f.grid)
	if meshes.has(FLOOR_PART):
		var mi := MeshInstance3D.new()
		mi.name = "Floor"
		mi.mesh = meshes[FLOOR_PART]
		mi.material_override = f.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(mi)
	var wall := ArenaVoxels.instance(base.barrier, "Barrier")
	f.add_child(wall)
	arena.add_child(f)
	return f


## Footprint key of something standing at `p`.
static func foot_key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0))


## The thing at `p` is gone: its footprint stops darkening the floor.
func forget(p: Vector3) -> void:
	var k := foot_key(p)
	if not _feet.has(k):
		return
	for v in _feet[k]:
		grid.put(v, Color.BLACK, VoxelMat.AIR)
	_feet.erase(k)
	mat.set_shader_parameter("vox", grid.texture())
	mat.set_shader_parameter("tops", grid.tops_texture())


# --- Per fight ---


func _carve(ter) -> void:
	var p := ArenaPalette.of(ter.scenario)
	for g in ter.grass:
		var gr := float(g.r)
		var lush := func(v: Vector3i, d: float) -> void:
			if d > gr - 0.1 and VoxelGrid.hash01(v.x, 1, v.z, 9) < 0.5:
				return
			var c: Color = Color(p.grass_dark).lerp(p.grass, 0.25 * VoxelGrid.hash01(v.x, 2, v.z))
			grid.put(v, ArenaPalette.jit(c, v, 0.06), VoxelMat.GRASS, FLOOR_PART)
		_paint_disc(g.pos, gr + 0.15, lush)
	for o in ter.obstacles:
		if o.kind != "pond":
			_foot(o.pos, float(o.r) - 0.1)
	# Ponds: every shore first, then every hole (a shore must not refill a neighbour's hole).
	for clear in [false, true]:
		for o in ter.obstacles:
			if o.kind != "pond":
				continue
			var rh := ArenaVoxels.pond_hole(float(o.r0))
			var hole := func(v: Vector3i, d: float) -> void:
				if clear:
					if d < rh:
						grid.clear(v)
						grid.clear(v + Vector3i(0, 1, 0))
				elif d >= rh and (d < rh + 0.5 or VoxelGrid.hash01(v.x, 3, v.z, 4) < 0.45):
					var c: Color = Color(p.shore).darkened(0.12 if d < rh + 0.3 else 0.0)
					grid.put(v, ArenaPalette.jit(c, v, 0.07), int(p.shore_mat), FLOOR_PART)
			_paint_disc(o.pos, rh + 0.75, hole)
	var bio = ter.biomes
	# Lava: scorched rims first, then the channels (a rim must not refill the next cell's channel).
	for clear in [false, true]:
		for c in bio.lava:
			var at: Vector3 = c.pos
			var dir: Vector3 = c.dir
			var nrm := Vector3(-dir.z, 0.0, dir.x)
			var channel := func(v: Vector3i, _d: float) -> void:
				var q := VoxelGrid.centre(v)
				var rel := Vector3(q.x - at.x, 0.0, q.z - at.z)
				var a := absf(rel.dot(dir))
				var b := absf(rel.dot(nrm))
				if clear:
					if a <= 0.5 and b <= 0.5:
						grid.clear(v)
				elif b < 0.95 and a < 0.75 and VoxelGrid.hash01(v.x, 5, v.z, 6) < 0.8:
					var col := (
						Color("3a1a12") if VoxelGrid.hash01(v.x, 6, v.z) < 0.7 else Color("6a2414")
					)
					grid.put(v, col, VoxelMat.STONE, FLOOR_PART)
			_paint_disc(at, 1.4, channel)
	for s in bio.solids:
		_foot(s.pos, float(s.r))
	for at in ter.crate_spots:
		_foot(at, 0.3)
	for it in ter.props.items:
		if it.kind in ["tree", "crystal", "voltorb", "hive", "bush"]:
			_foot(it.pos, float(BattleProps.SOLID_R.get(it.kind, 0.4)) * 0.8)
	for py in ter.ground.extras.pylons:
		_foot(py.pos, 0.3)


## Calls f(v, d) for every floor voxel (y = -1) whose centre is within `r` of `at`.
func _paint_disc(at: Vector3, r: float, f: Callable) -> void:
	var a := VoxelGrid.vox3(Vector3(at.x - r, -0.1, at.z - r))
	var b := VoxelGrid.vox3(Vector3(at.x + r, -0.1, at.z + r))
	for z in range(a.z, b.z + 1):
		for x in range(a.x, b.x + 1):
			var v := Vector3i(x, -1, z)
			if not grid.has(v):
				continue
			var c := VoxelGrid.centre(v)
			var d := Vector2(c.x - at.x, c.z - at.z).length()
			if d < r:
				f.call(v, d)


## Context cells (layer y = 0) under something of radius `r` at `p`.
func _foot(p: Vector3, r: float) -> void:
	var cells: Array = []
	var mark := func(v: Vector3i, _d: float) -> void:
		var up := v + Vector3i(0, 1, 0)
		if grid.solid(v) and not grid.solid(up):
			grid.put(up, Color.BLACK, VoxelMat.STONE, CTX_FOOT)
			cells.append(up)
	_paint_disc(p, maxf(r, 0.2), mark)
	if not cells.is_empty():
		var k := foot_key(p)
		_feet[k] = (_feet.get(k, []) as Array) + cells


# --- Cached base: painted floor, lines and the barrier ---


static func _make_base(sc: String, rc: Rect2, back: bool) -> Dictionary:
	var p := ArenaPalette.of(sc)
	var lo := rc.position - Vector2(MARGIN, MARGIN)
	var hi := rc.end + Vector2(MARGIN, MARGIN)
	var g := ArenaVoxels.box(Vector3(lo.x, -VS, lo.y), Vector3(hi.x, VS, hi.y))
	var style := String(p.floor)
	var stop := rc.grow(-0.5)  # where the fighters stop (BattleArena clamp)
	var lx0 := VoxelGrid.vox(stop.position.x) - 1
	var lx1 := VoxelGrid.vox(stop.end.x)
	var lz0 := VoxelGrid.vox(stop.position.y) - 1
	var lz1 := VoxelGrid.vox(stop.end.y)
	var mid := rc.get_center()
	var line: Color = p.line
	for z in range(g.origin.z, g.origin.z + g.size.z):
		for x in range(g.origin.x, g.origin.x + g.size.x):
			var v := Vector3i(x, -1, z)
			var c := VoxelGrid.centre(v)
			var inside := rc.has_point(Vector2(c.x, c.z))
			var out: Array = _court(style, p, x, z) if inside else _surround(p, x, z)
			var lined := false
			if inside and x >= lx0 and x <= lx1 and z >= lz0 and z <= lz1:
				lined = x == lx0 or x == lx1 or z == lz0 or z == lz1
				lined = lined or absf(c.x - mid.x) < 0.13
				var d := Vector2(c.x - mid.x, c.z - mid.y).length()
				# Centre circle and a Poke Ball "button" (ring and dot) on the centre line.
				lined = lined or absf(d - CIRCLE_R) < 0.17 or d < 0.3
				lined = lined or absf(d - BUTTON_R) < 0.13
			elif not inside:
				lined = _box_line(rc, c)
				var lane := _trainer_lane(rc, c)
				if lane >= 0:
					out = _lane_voxel(lane, rc, c, v, out)
			if lined:
				out = [ArenaPalette.jit(line, v, 0.02), VoxelMat.PAINT]
			g.put(v, out[0], out[1], FLOOR_PART)
	var wall := _barrier_grid(p, rc, back)
	# The barrier's foot darkens the floor around it.
	for z in range(wall.origin.z, wall.origin.z + wall.size.z):
		for x in range(wall.origin.x, wall.origin.x + wall.size.x):
			if wall.solid(Vector3i(x, 0, z)) and wall.part_at(Vector3i(x, 0, z)) != 0:
				g.put(Vector3i(x, 0, z), Color.BLACK, VoxelMat.STONE, CTX_FOOT)
	return {"grid": g, "barrier": ArenaVoxels.model(wall)}


## Court voxel (colour, material) for the floor style.
static func _court(style: String, p: Dictionary, x: int, z: int) -> Array:
	var v := Vector3i(x, -1, z)
	var tx := floori((x + 2) / 4.0)
	var tz := floori((z + 2) / 4.0)
	var lx := x - (tx * 4 - 2)
	var lz := z - (tz * 4 - 2)
	var hv := VoxelGrid.hash01(x, 7, z, 3)
	var ht := VoxelGrid.hash01(tx, 8, tz, 3)
	var tone := (ht - 0.5) * 0.08
	var n1 := ArenaPalette.noise(tx / 6.0, tz / 6.0, 5)
	var n2 := ArenaPalette.noise(tx / 4.0 + 17.0, tz / 4.0, 6)
	var c: Color
	var m := VoxelMat.GRASS
	match style:
		"turf":
			if n1 > 0.76 and hv < 0.75 + (n1 - 0.76) * 4.0:
				return [_tone(p.dirt, tone, v, 0.06), VoxelMat.DIRT]
			c = p.turf_a if posmod(floori(tx / 3.0), 2) == 0 else p.turf_b
			if hv > 0.96:
				c = p.grass_light
			elif hv < 0.04:
				c = p.grass_dark
		"meadow":
			c = Color(p.grass).lerp(p.grass_dark, n2 * 0.6)
			if n1 > 0.8 and hv < 0.8:
				return [_tone(p.sand, tone, v, 0.05), VoxelMat.SAND]
			if hv > 0.992:
				return [Color("f4f0e0") if ht < 0.5 else Color("f0d850"), VoxelMat.FLOWER]
			if hv > 0.93:
				c = p.grass_light
		"mixed":
			if n1 + (hv - 0.5) * 0.12 > 0.52:
				return [_tone(p.dirt, tone, v, 0.07), VoxelMat.DIRT]
			c = p.grass if hv > 0.08 else p.grass_dark
		"quarry":
			if n2 > 0.6:
				var mortar := lx == 0 or lz == 0
				return [
					_tone(Color(p.slab).darkened(0.25 if mortar else 0.0), tone, v, 0.03),
					VoxelMat.SLAB
				]
			if n1 > 0.7:
				return [_tone(p.dirt, tone, v, 0.07), VoxelMat.DIRT]
			c = p.gravel
			m = VoxelMat.GRAVEL
			if hv > 0.93:
				c = Color(p.stone_light)
			elif hv < 0.08:
				c = Color(p.stone_dark)
		"beach":
			c = p.sand
			m = VoxelMat.SAND
			if n1 > 0.68:
				c = Color(p.sand).lerp(p.sand_wet, 0.45)
			if hv > 0.996:
				return [Color("f6efe4") if ht < 0.6 else Color("f0b8b0"), VoxelMat.PLASTER]
		"ruins":
			if n1 > 0.7 and ht < 0.55:
				return [_tone(p.grass if hv < 0.6 else p.dirt, tone, v, 0.07), VoxelMat.GRASS]
			if lx == 0 or lz == 0:
				var moss := hv < 0.35
				return [
					_tone(
						Color(p.grass_dark) if moss else Color(p.slab).darkened(0.3), 0.0, v, 0.05
					),
					VoxelMat.MOSS if moss else VoxelMat.SLAB
				]
			c = Color(p.slab).darkened(0.08 if ht < 0.3 else 0.0)
			m = VoxelMat.SLAB
			if hv < 0.04:
				c = c.darkened(0.25)  # cracks
		"snowfield":
			if n1 > 0.74 and hv < 0.94:
				return [_tone(p.stone, tone, v, 0.07), VoxelMat.STONE]
			c = p.snow
			m = VoxelMat.SNOW
			if hv < 0.15:
				c = c.darkened(0.05)
		"basalt":
			c = p.stone
			m = VoxelMat.STONE
			if n1 > 0.55:
				c = Color(p.stone).lerp(Color("5a5450"), 0.6)
				m = VoxelMat.GRAVEL
			if absf(ArenaPalette.noise(x / 9.0, z / 9.0, 8) - 0.5) < 0.025:
				if hv > 0.985:
					return [Color("ff8a2a"), VoxelMat.LAVA]
				return [Color("4a1a10"), VoxelMat.STONE]
			if hv < 0.06:
				c = Color(p.stone_dark)
		"cave":
			c = p.stone
			m = VoxelMat.STONE
			if n1 > 0.66:
				c = Color(p.stone).lerp(Color("3f5a3a"), 0.7)
				m = VoxelMat.MOSS
			if hv > 0.997:
				return [Color("7fe0f4"), VoxelMat.CRYSTAL]
			if hv < 0.07:
				c = Color(p.stone_dark)
		"swamp":
			c = Color(p.grass).lerp(p.grass_dark, n2)
			m = VoxelMat.MOSS
			if n1 > 0.58:
				return [_tone(Color(p.dirt).darkened(0.1), tone, v, 0.06), VoxelMat.DIRT]
			if hv > 0.95:
				c = Color(p.grass).lightened(0.12)
		_:
			c = p.grass
	return [_tone(c, tone, v, 0.05), m]


static func _tone(c: Color, tone: float, v: Vector3i, amt: float) -> Color:
	c = c.lightened(tone) if tone > 0.0 else c.darkened(-tone)
	return ArenaPalette.jit(c, v, amt)


## Concourse voxel outside the court: 1 m slabs with dark joints.
static func _surround(p: Dictionary, x: int, z: int) -> Array:
	var v := Vector3i(x, -1, z)
	var tx := floori((x + 2) / 4.0)
	var tz := floori((z + 2) / 4.0)
	var ht := VoxelGrid.hash01(tx, 9, tz, 4)
	var mt := int(p.surround_mat)
	var c: Color = p.surround
	if mt == VoxelMat.SLAB and (x - (tx * 4 - 2) == 0 or z - (tz * 4 - 2) == 0):
		c = c.darkened(0.22)
	return [_tone(c, (ht - 0.5) * 0.08, v, 0.03), mt]


## Side (0 at -x, 1 at +x) whose trainer box or carpet holds `c`, or -1.
static func _trainer_lane(rc: Rect2, c: Vector3) -> int:
	var mid := rc.get_center()
	var az := absf(c.z - mid.y)
	if az > BOX.y:
		return -1
	var t := absf(c.x - mid.x) - (rc.size.x * 0.5 + WALL)
	if t < 0.0 or (t > BOX.x and az > CARPET):
		return -1
	return 0 if c.x < mid.x else 1


## Trainer box (painted in the side's colour over the surround) and the carpet from the box to the
## players' tunnel (ArenaStadium continues it on the concourse), white edges.
static func _lane_voxel(side: int, rc: Rect2, c: Vector3, v: Vector3i, under: Array) -> Array:
	var team: Color = StadiumParts.TEAM[side]
	var t := absf(c.x - rc.get_center().x) - (rc.size.x * 0.5 + WALL)
	if t <= BOX.x:
		return [ArenaPalette.jit(Color(under[0]).lerp(team, 0.42), v, 0.03), VoxelMat.PAINT]
	var az := absf(c.z - rc.get_center().y)
	var col := Color("f4f2ec") if az > CARPET - VS else team
	return [ArenaPalette.jit(col, v, 0.03), VoxelMat.CLOTH]


## Concourse voxel for (x, z) outside the court (the stadium ring uses the same look).
static func surround_voxel(p: Dictionary, x: int, z: int) -> Array:
	return _surround(p, x, z)


## Trainer box outline on the concourse (around each trainer spot, beyond the barrier gate): the
## two long sides and the far end, one voxel wide, inside the box.
static func _box_line(rc: Rect2, c: Vector3) -> bool:
	var mid := rc.get_center()
	var az := absf(c.z - mid.y)
	if az > BOX.y:
		return false
	for sx in [-1.0, 1.0]:
		var t: float = (c.x - (mid.x + sx * (rc.size.x * 0.5 + WALL))) * sx
		if t < 0.0 or t > BOX.x:
			continue
		if az > BOX.y - VS or t > BOX.x - VS:
			return true
	return false


## Barrier on the real bounds of the court: padded wall WALL m thick outside the rect, WALL_H tall
## (WALL_H_FRONT on the camera side, +z), with a white cap, posts at the corners and at the trainer
## gates. `back` false: no wall on -z (the montanha cliff stands there).
static func _barrier_grid(p: Dictionary, rc: Rect2, back: bool) -> VoxelGrid:
	var lo := rc.position - Vector2(WALL, WALL)
	var hi := rc.end + Vector2(WALL, WALL)
	var g := ArenaVoxels.box(
		Vector3(lo.x - VS, -VS, lo.y - VS), Vector3(hi.x + VS, 1.25, hi.y + VS)
	)
	var nw := roundi(WALL / VS)
	var x0 := VoxelGrid.vox(rc.position.x) - nw
	var x1 := VoxelGrid.vox(rc.end.x)
	var z0 := VoxelGrid.vox(rc.position.y) - nw
	var z1 := VoxelGrid.vox(rc.end.y)
	var mid := rc.get_center()
	var gate := VoxelGrid.vox(GATE)
	var gz := VoxelGrid.vox(mid.y)
	var hn := roundi(WALL_H / VS)
	var hf := roundi(WALL_H_FRONT / VS)
	for z in range(z0, z1 + nw):
		for x in range(x0, x1 + nw):
			var side := x < x0 + nw or x >= x1
			var back_w := z < z0 + nw
			var front_w := z >= z1
			if not (side or back_w or front_w):
				continue
			if back_w and not back:
				continue
			var end_w := back_w or front_w
			if side and not end_w and z >= gz - gate and z < gz + gate:
				continue  # trainer gate
			var top := hf if front_w else hn
			if (side and end_w) or (side and (z == gz - gate - 1 or z == gz + gate)):
				top += 1  # posts
			for y in top:
				var v := Vector3i(x, y, z)
				var c: Color = p.pad
				var mt := VoxelMat.CLOTH
				if y == top - 1:
					c = p.cap
					mt = VoxelMat.PLASTER
				elif posmod(z if side and not end_w else x, 8) == 0:
					c = p.pad_dark
				g.put(v, ArenaPalette.jit(c, v, 0.03), mt, 1)
	# Floor under and around the wall as context (AO at its foot).
	for z in range(g.origin.z, g.origin.z + g.size.z):
		for x in range(g.origin.x, g.origin.x + g.size.x):
			var near := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					near = near or g.solid(Vector3i(x + dx, 0, z + dz))
			if near:
				g.put(Vector3i(x, -1, z), Color.BLACK, VoxelMat.STONE, 0)
	return g
