extends RefCounted
## Voxel diorama for the water work (tests/gfx/shot_water.gd, tests/gfx/test_water.gd): a pond with
## a stepped sand / silt bed, rocks, reeds, lily pads, pebbles and water plants, a wooden dock with
## a trainer, a kid wading in the shallows, a stream on a terrace that drops into the pond as a
## cascade (FountainFx sheet feeding the pond), a three-tier stone fountain (crown jets, top jet,
## overflow curtains, underwater light), lamp posts, trees and a cottage for the reflections.
## Ground top is y = 0 (docs/VOXEL.md); the terrace in the north is 0.5 m higher.

const WATER_Y := -0.12  ## pond surface: 12 cm under the bank, 13 cm over the first bed step
const STREAM_Y := 0.38
const POND := Vector2(-3.5, 0.75)  ## pond centre (x, z)
const POND_R := Vector2(4.6, 3.3)
const FOUNTAIN := Vector3(7.5, 0.0, 1.5)
const TERRACE_Z := -6.0  ## the terrace (ground top 0.5) is z < -6
const ARENA := Vector2(-11.0, 5.5)  ## a battle-style round pond (scaled like the arena does)
const ARENA_R0 := 1.8

var g: VoxelGrid
var root: Node3D
var pond: MeshInstance3D
var stream: MeshInstance3D
var arena_pond: MeshInstance3D
var fountain: FountainFx
var cascade: FountainFx
var lamps: Array[OmniLight3D] = []
var spots := {}  ## named points of interest (camera targets)


static func _paint(base: Color, amt: float) -> Callable:
	return func(v: Vector3i) -> Color:
		var h := VoxelGrid.hash01(v.x, v.y, v.z, 7)
		return base.lightened(amt * h) if h > 0.5 else base.darkened(amt * (1.0 - h))


## Pond outline: normalised distance from the centre (< 1 inside), wobbly ellipse.
static func pond_q(x: float, z: float) -> float:
	var d := Vector2((x - POND.x) / POND_R.x, (z - POND.y) / POND_R.y)
	var a := atan2(d.y, d.x)
	var r := 1.0 + 0.12 * sin(2.0 * a + 1.0) + 0.08 * sin(3.0 * a + 2.0) + 0.05 * sin(5.0 * a)
	return d.length() / r


## Bed depth of the pond in voxels below the ground top (1 = the shallow shelf, 5 = 1.25 m).
static func pond_steps(q: float) -> int:
	return clampi(1 + int(floor((1.0 - q) * 6.0)), 1, 5)


func build(parent: Node3D) -> Dictionary:
	root = Node3D.new()
	root.name = "WaterDiorama"
	parent.add_child(root)
	g = VoxelGrid.from_box(Vector3(-15, -2.0, -13), Vector3(15, 6.5, 9))
	_ground()
	_pond_bed()
	_stream_bed()
	_arena_bed()
	_fountain_stone()
	_dock()
	_rocks()
	_trees()
	_cottage()
	for p in [Vector3(1.0, 0, 3.75), Vector3(-9.0, 0, -1.0), Vector3(4.5, 0, 4.75)]:
		_lamp(p)
	_lamp(Vector3(10.5, 0, -2.0))
	_lamp(Vector3(-4.25, 0, -3.25))  # north bank: reflects in the pond from the low view
	var parts := {2: {"sway": 0.035, "sway_base": 2.0}, 3: {"sway": 0.035, "sway_base": 2.0}}
	parts[4] = {"sway": 0.035, "sway_base": 2.5}
	for mi in VoxelMat.instances(g, "Vox", parts):
		root.add_child(mi)
	_water()
	_decor()
	_people()
	return spots


# ---------------------------------------------------------------- terrain


func _ground() -> void:
	var grass := Color(0.36, 0.6, 0.22)
	g.fill(Vector3i(-60, -8, -52), Vector3i(59, -4, 35), Color(0.45, 0.45, 0.47), VoxelMat.STONE)
	g.fill(
		Vector3i(-60, -3, -52),
		Vector3i(59, -2, 35),
		Color(0.45, 0.32, 0.2),
		VoxelMat.DIRT,
		0,
		_paint(Color(0.45, 0.32, 0.2), 0.1)
	)
	g.fill(Vector3i(-60, -1, -52), Vector3i(59, -1, 35), grass, VoxelMat.GRASS, 0, _grass_paint())
	# Terrace (north): two more layers, the front face of mossy stone.
	var tz := VoxelGrid.vox(TERRACE_Z) - 1
	g.fill(
		Vector3i(-60, -1, -52),
		Vector3i(59, 0, tz),
		Color(0.45, 0.32, 0.2),
		VoxelMat.DIRT,
		0,
		_paint(Color(0.45, 0.32, 0.2), 0.1)
	)
	g.fill(Vector3i(-60, 1, -52), Vector3i(59, 1, tz), grass, VoxelMat.GRASS, 0, _grass_paint())
	for x in range(-60, 60):
		for y in range(-1, 2):
			var h := VoxelGrid.hash01(x, y, tz, 3)
			var c := Color(0.5, 0.5, 0.48).darkened(0.25 * h)
			if y == 1 and h > 0.55:
				c = Color(0.3, 0.48, 0.2)
			g.put(Vector3i(x, y, tz), c, VoxelMat.STONE if y < 1 or h <= 0.55 else VoxelMat.MOSS)
	# Fountain plaza: cut stone in rings.
	for x in range(16, 46):
		for z in range(-10, 21):
			var c := VoxelGrid.centre(Vector3i(x, -1, z))
			var d := Vector2(c.x - FOUNTAIN.x, c.z - FOUNTAIN.z).length()
			if d < 3.3 + 0.2 * VoxelGrid.hash01(x, 0, z, 9):
				var ring := int(d / 0.5)
				var base := Color(0.68, 0.66, 0.62) if ring % 2 == 0 else Color(0.6, 0.58, 0.55)
				var h := VoxelGrid.hash01(x, -1, z, 2)
				g.put(Vector3i(x, -1, z), base.darkened(0.12 * h), VoxelMat.SLAB)
	# A cobble path from the plaza to the dock.
	for x in range(-18, 17):
		for z in range(16, 21):
			if g.mat_at(Vector3i(x, -1, z)) == VoxelMat.GRASS:
				var m := (posmod(x, 3) == 0) or (posmod(z + (x / 3) * 2, 3) == 0)
				var col := (
					Color(0.44, 0.42, 0.4)
					if m
					else Color(0.66, 0.64, 0.6).darkened(0.15 * VoxelGrid.hash01(x, 0, z))
				)
				g.put(Vector3i(x, -1, z), col, VoxelMat.STONE)


func _grass_paint() -> Callable:
	return func(v: Vector3i) -> Color:
		var h := VoxelGrid.hash01(v.x, v.y, v.z, 5)
		var n := VoxelGrid.hash01(v.x >> 2, 0, v.z >> 2, 6)
		var c := Color(0.36, 0.6, 0.22).lerp(Color(0.46, 0.66, 0.24), n * 0.6)
		return c.lightened(0.1 * h) if h > 0.5 else c.darkened(0.1 * (1.0 - h))


func _bed_color(v: Vector3i, steps: int) -> Color:
	var h := VoxelGrid.hash01(v.x, v.y, v.z, 11)
	var n := VoxelGrid.hash01(v.x >> 1, 0, v.z >> 1, 12)
	var sand := Color(0.8, 0.72, 0.52)
	var silt := Color(0.46, 0.43, 0.32)
	var c := sand.lerp(silt, clampf((steps - 1) / 4.0, 0.0, 1.0))
	if n > 0.82 and steps >= 3:
		c = c.lerp(Color(0.3, 0.42, 0.2), 0.6)  # algae
	if h > 0.93:
		c = Color(0.52, 0.5, 0.48)  # gravel
	return c.lightened(0.06 * h) if h > 0.5 else c.darkened(0.08 * (1.0 - h))


func _pond_bed() -> void:
	for x in range(-60, 60):
		for z in range(-52, 36):
			var c := VoxelGrid.centre(Vector3i(x, 0, z))
			var q := pond_q(c.x, c.z)
			var steps := 0
			if q < 1.0:
				steps = pond_steps(q)
			elif q < 1.12 and c.z > POND.y:
				# A sandy beach on the south bank.
				g.put(Vector3i(x, -1, z), _bed_color(Vector3i(x, -1, z), 1), VoxelMat.SAND)
			# Lower inflow channel from the cascade.
			var cx := -2.0
			if c.z > TERRACE_Z and c.z < POND.y - 1.0 and absf(c.x - cx) < 0.8:
				steps = maxi(steps, 2 if absf(c.x - cx) < 0.5 else 1)
			if steps == 0:
				continue
			for y in range(-steps, 0):
				g.clear(Vector3i(x, y, z))
			var bv := Vector3i(x, -steps - 1, z)
			g.put(bv, _bed_color(bv, steps), VoxelMat.BED)


## Bowl carved for the largest pond (1.25 x r0), like the arena lane does.
func _arena_bed() -> void:
	var rmax := ARENA_R0 * 1.25
	for x in range(VoxelGrid.vox(ARENA.x - rmax) - 1, VoxelGrid.vox(ARENA.x + rmax) + 2):
		for z in range(VoxelGrid.vox(ARENA.y - rmax) - 1, VoxelGrid.vox(ARENA.y + rmax) + 2):
			var c := VoxelGrid.centre(Vector3i(x, 0, z))
			var r := Vector2(c.x - ARENA.x, c.z - ARENA.y).length()
			if r >= rmax:
				continue
			var steps := clampi(1 + int(floor((1.0 - r / rmax) * 4.0)), 1, 3)
			for y in range(-steps, 0):
				g.clear(Vector3i(x, y, z))
			var bv := Vector3i(x, -steps - 1, z)
			var h := VoxelGrid.hash01(x, 0, z, 41)
			var col := Color(0.62, 0.52, 0.36).lerp(Color(0.4, 0.36, 0.28), (steps - 1) / 2.0)
			g.put(bv, col.darkened(0.12 * h), VoxelMat.BED)


func _stream_bed() -> void:
	var tz := VoxelGrid.vox(TERRACE_Z) - 1
	for z in range(-52, tz + 1):
		var zc := (z + 0.5) * VoxelGrid.VS
		var cx := -2.0 + 0.45 * sin(zc * 0.55)
		for x in range(-20, 0):
			var xc := (x + 0.5) * VoxelGrid.VS
			var d := absf(xc - cx)
			if d > 0.8:
				continue
			var deep := d < 0.5
			g.clear(Vector3i(x, 1, z))
			if deep:
				g.clear(Vector3i(x, 0, z))
			var bv := Vector3i(x, -1 if deep else 0, z)
			var h := VoxelGrid.hash01(x, 0, z, 21)
			var c := Color(0.62, 0.58, 0.5).darkened(0.2 * h)
			if h > 0.85:
				c = Color(0.5, 0.5, 0.52)
			g.put(bv, c, VoxelMat.BED)
	# Stones in the current (their tops stick out of the water).
	for p in [Vector2(-2.1, -8.0), Vector2(-1.6, -10.4), Vector2(-2.5, -11.8), Vector2(-1.9, -6.9)]:
		var v := VoxelGrid.vox3(Vector3(p.x, 0.0, p.y))
		g.ellipsoid(
			Vector3(v.x + 0.5, 1.2, v.z + 0.5),
			Vector3(1.4, 1.6, 1.2),
			Color(0.55, 0.55, 0.53),
			VoxelMat.STONE,
			0,
			_paint(Color(0.55, 0.55, 0.53), 0.18)
		)
	# The lip of the cascade: a flat stone sill.
	for x in range(-12, -4):
		g.put(Vector3i(x, 0, tz), Color(0.62, 0.6, 0.56), VoxelMat.SLAB)
		g.clear(Vector3i(x, 1, tz))


# ---------------------------------------------------------------- fountain (stone)


func _fountain_stone() -> void:
	var fx := FOUNTAIN.x * 4.0
	var fz := FOUNTAIN.z * 4.0
	var stone := Color(0.78, 0.76, 0.72)
	var dark := Color(0.6, 0.58, 0.55)
	var p_stone := _paint(stone, 0.08)
	# Lower basin: floor 0.25 m below ground, wall ring 1.5-1.75 m, rim top 0.5.
	for x in range(int(fx) - 8, int(fx) + 9):
		for z in range(int(fz) - 8, int(fz) + 9):
			var d := Vector2(x + 0.5 - fx, z + 0.5 - fz).length() * VoxelGrid.VS
			if d < 1.5:
				g.clear(Vector3i(x, -1, z))
				var bv := Vector3i(x, -2, z)
				var h := VoxelGrid.hash01(x, 0, z, 4)
				var c := Color(0.42, 0.56, 0.6) if (x + z) % 2 == 0 else Color(0.36, 0.5, 0.56)
				g.put(bv, c.darkened(0.1 * h), VoxelMat.BED)
			elif d < 1.75:
				for y in range(-1, 2):
					g.put(Vector3i(x, y, z), p_stone.call(Vector3i(x, y, z)), VoxelMat.STONE)
				g.put(Vector3i(x, 1, z), stone.lightened(0.08), VoxelMat.SLAB)
			elif d < 2.0:
				g.put(Vector3i(x, 0, z), dark, VoxelMat.STONE)  # plinth step
	# Pedestal, mid basin (floor top 1.0, rim top 1.5), column, top bowl (floor 2.0, rim 2.25).
	g.cylinder(fx, fz, 1.6, -2, 2, dark, VoxelMat.STONE, 0, _paint(dark, 0.06))
	g.cylinder(fx, fz, 4.0, 3, 3, stone, VoxelMat.STONE, 0, p_stone)
	for y in [4, 5]:
		for x in range(int(fx) - 5, int(fx) + 6):
			for z in range(int(fz) - 5, int(fz) + 6):
				var d := Vector2(x + 0.5 - fx, z + 0.5 - fz).length()
				if d >= 3.0 and d < 4.0:
					g.put(
						Vector3i(x, y, z), stone if y == 4 else stone.lightened(0.08), VoxelMat.SLAB
					)
	g.cylinder(fx, fz, 1.0, 4, 6, dark, VoxelMat.STONE, 0, _paint(dark, 0.06))
	g.cylinder(fx, fz, 2.2, 7, 7, stone, VoxelMat.STONE, 0, p_stone)
	for x in range(int(fx) - 3, int(fx) + 4):
		for z in range(int(fz) - 3, int(fz) + 4):
			var d := Vector2(x + 0.5 - fx, z + 0.5 - fz).length()
			if d >= 1.4 and d < 2.2:
				g.put(Vector3i(x, 8, z), stone.lightened(0.08), VoxelMat.SLAB)
	# Bowl floors read as the bed (caustics, no rain wetness).
	for x in range(int(fx) - 4, int(fx) + 5):
		for z in range(int(fz) - 4, int(fz) + 5):
			var d := Vector2(x + 0.5 - fx, z + 0.5 - fz).length()
			if d < 3.0 and g.mat_at(Vector3i(x, 3, z)) != 0 and d > 1.0:
				g.put(Vector3i(x, 3, z), Color(0.44, 0.58, 0.62), VoxelMat.BED)
			if d < 1.4 and d > 0.6:
				g.put(Vector3i(x, 7, z), Color(0.44, 0.58, 0.62), VoxelMat.BED)
	# Overflow notches in the mid basin rim (N, E, S, W).
	for x in range(int(fx) - 5, int(fx) + 6):
		for z in range(int(fz) - 5, int(fz) + 6):
			var c := Vector2(x + 0.5 - fx, z + 0.5 - fz)
			if c.length() >= 3.0 and c.length() < 4.2 and (absf(c.x) < 1.0 or absf(c.y) < 1.0):
				g.clear(Vector3i(x, 5, z))
	# Nozzle.
	g.put(Vector3i(floori(fx), 8, floori(fz)), Color(0.55, 0.5, 0.35), VoxelMat.METAL)
	spots["fountain"] = FOUNTAIN + Vector3(0, 0.8, 0)


func _dock() -> void:
	# 1 m wide, from the south bank (z 4.5) to z 1.5 over the water; deck top 0.25 on posts.
	var x0 := VoxelGrid.vox(-4.5)
	var x1 := VoxelGrid.vox(-3.5) - 1
	for z in range(VoxelGrid.vox(1.5), VoxelGrid.vox(5.0)):
		for x in range(x0, x1 + 1):
			var plank := Color(0.56, 0.38, 0.22) if z % 2 == 0 else Color(0.5, 0.33, 0.19)
			var h := VoxelGrid.hash01(x, 0, z, 31)
			g.put(Vector3i(x, 0, z), plank.darkened(0.1 * h), VoxelMat.WOOD)
	for z in [VoxelGrid.vox(1.5), VoxelGrid.vox(3.0)]:
		for x in [x0, x1]:
			for y in range(-1, -8, -1):
				if g.solid(Vector3i(x, y, z)):
					break
				g.put(Vector3i(x, y, z), Color(0.36, 0.24, 0.14), VoxelMat.WOOD)
	spots["dock"] = Vector3(-4.0, 0.25, 1.9)


func _rocks() -> void:
	var rock := Color(0.56, 0.55, 0.52)
	var spots_r := [
		[Vector3(-8.3, 0.0, -0.8), Vector3(2.4, 2.0, 2.0)],
		[Vector3(-7.6, 0.0, 3.4), Vector3(1.8, 1.4, 1.6)],
		[Vector3(-0.3, 0.0, -1.6), Vector3(2.2, 1.8, 1.8)],
		[Vector3(-5.6, -0.6, 0.0), Vector3(2.0, 3.0, 1.7)],  # in the pond, top above the water
		[Vector3(0.6, 0.0, 2.2), Vector3(1.4, 1.2, 1.4)],
		[Vector3(-3.0, 0.5, -6.6), Vector3(1.6, 1.4, 1.4)],
		[Vector3(-0.9, 0.5, -6.5), Vector3(1.8, 1.6, 1.6)],
	]
	for r in spots_r:
		var c: Vector3 = r[0]
		var rad: Vector3 = r[1]
		g.ellipsoid(c * 4.0, rad, rock, VoxelMat.STONE, 0, _paint(rock, 0.2))
		# Moss on top.
		var top := VoxelGrid.vox3(c) + Vector3i(0, int(rad.y) - 1, 0)
		for dx in range(-1, 2):
			for dz in range(-1, 1):
				var v := top + Vector3i(dx, 0, dz)
				if g.solid(v) and not g.solid(v + Vector3i(0, 1, 0)):
					g.put(v, Color(0.34, 0.5, 0.22), VoxelMat.MOSS)
	# A crate stuck in the shallows.
	var cp := Vector2(-7.3, 2.6)
	var cr := VoxelGrid.vox3(Vector3(cp.x, -pond_steps(pond_q(cp.x, cp.y)) * VoxelGrid.VS, cp.y))
	g.fill(
		cr,
		cr + Vector3i(1, 1, 1),
		Color(0.55, 0.37, 0.2),
		VoxelMat.WOOD,
		0,
		_paint(Color(0.55, 0.37, 0.2), 0.12)
	)


func _trees() -> void:
	var trees := [Vector3(-8.0, 0.5, -9.0), Vector3(-12.0, 0.5, -7.5), Vector3(1.5, 0.5, -10.0)]
	for i in trees.size():
		var p: Vector3 = trees[i]
		var v := VoxelGrid.vox3(p)
		var hgt := 12 + i * 2
		g.fill(
			v,
			v + Vector3i(1, hgt, 1),
			Color(0.4, 0.27, 0.16),
			VoxelMat.BARK,
			0,
			_paint(Color(0.4, 0.27, 0.16), 0.1)
		)
		var leaf := Color(0.26, 0.5, 0.2) if i != 1 else Color(0.3, 0.55, 0.22)
		g.ellipsoid(
			Vector3(v.x + 1, v.y + hgt + 3, v.z + 1),
			Vector3(7, 5.5, 7),
			leaf,
			VoxelMat.LEAVES,
			2 + i,
			_paint(leaf, 0.25),
			true
		)
		g.ellipsoid(
			Vector3(v.x - 2, v.y + hgt + 6, v.z + 2),
			Vector3(4, 3.5, 4),
			leaf.lightened(0.08),
			VoxelMat.LEAVES,
			2 + i,
			_paint(leaf.lightened(0.08), 0.25),
			true
		)


func _cottage() -> void:
	var lo := VoxelGrid.vox3(Vector3(4.0, 0.5, -12.0))
	var hi := VoxelGrid.vox3(Vector3(10.0, 0.5, -7.5))
	var wall := Color(0.92, 0.88, 0.8)
	g.fill(lo, Vector3i(hi.x, lo.y + 11, hi.z), wall, VoxelMat.PLASTER, 0, _paint(wall, 0.05))
	g.fill(
		lo + Vector3i(1, 0, 1), Vector3i(hi.x - 1, lo.y + 11, hi.z - 1), Color.BLACK, VoxelMat.AIR
	)
	g.fill(
		lo,
		Vector3i(hi.x, lo.y + 1, hi.z),
		Color(0.55, 0.53, 0.5),
		VoxelMat.STONE,
		0,
		_paint(Color(0.55, 0.53, 0.5), 0.1)
	)
	for x in [lo.x, lo.x + 8, hi.x - 8, hi.x]:
		g.fill(
			Vector3i(x, lo.y + 2, hi.z),
			Vector3i(x, lo.y + 11, hi.z),
			Color(0.36, 0.23, 0.14),
			VoxelMat.WOOD
		)
	for wx in [lo.x + 3, hi.x - 6]:
		g.fill(
			Vector3i(wx, lo.y + 4, hi.z),
			Vector3i(wx + 3, lo.y + 7, hi.z),
			Color(1.0, 0.78, 0.45),
			VoxelMat.WINDOW
		)
	var dx := (lo.x + hi.x) / 2
	g.fill(
		Vector3i(dx - 1, lo.y, hi.z),
		Vector3i(dx + 1, lo.y + 8, hi.z),
		Color(0.45, 0.28, 0.16),
		VoxelMat.WOOD
	)
	for i in 10:
		var c := Color(0.86, 0.43, 0.18) if i % 2 == 0 else Color(0.74, 0.34, 0.13)
		g.fill(
			Vector3i(lo.x - 1, lo.y + 12 + i, lo.z - 1 + i),
			Vector3i(hi.x + 1, lo.y + 12 + i, hi.z + 1 - i),
			c,
			VoxelMat.ROOF,
			1
		)
	spots["cottage"] = Vector3(7.0, 2.0, -7.5)


func _lamp(p: Vector3) -> void:
	var v := VoxelGrid.vox3(p)
	var base := g.top_y(v.x, v.z, -1) + 1
	g.fill(
		Vector3i(v.x, base, v.z),
		Vector3i(v.x, base + 9, v.z),
		Color(0.18, 0.18, 0.2),
		VoxelMat.METAL
	)
	g.fill(
		Vector3i(v.x - 1, base, v.z - 1),
		Vector3i(v.x + 1, base, v.z + 1),
		Color(0.3, 0.3, 0.32),
		VoxelMat.METAL
	)
	g.fill(
		Vector3i(v.x - 1, base + 10, v.z - 1),
		Vector3i(v.x + 1, base + 11, v.z + 1),
		Color(1.0, 0.82, 0.5),
		VoxelMat.LAMP
	)
	g.fill(
		Vector3i(v.x - 1, base + 12, v.z - 1),
		Vector3i(v.x + 1, base + 12, v.z + 1),
		Color(0.2, 0.2, 0.22),
		VoxelMat.METAL
	)
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.76, 0.46)
	ol.light_energy = 0.0
	ol.omni_range = 7.5
	ol.omni_attenuation = 0.9
	ol.position = VoxelGrid.centre(Vector3i(v.x, base + 10, v.z)) + Vector3(0, 0.1, 0)
	root.add_child(ol)
	lamps.append(ol)


# ---------------------------------------------------------------- water


func _water() -> void:
	# Pond: one plane over the pond and the lower inflow channel (never overlap two surfaces).
	pond = WaterSurface.make(Vector2(10.5, 10.75), {"kind": "pond", "depth": 1.0})
	pond.name = "Pond"
	pond.position = Vector3(-3.5, WATER_Y, -0.625)
	root.add_child(pond)
	stream = WaterSurface.make(
		Vector2(3.5, 7.0), {"kind": "stream", "flow": Vector2(0, 0.7), "depth": 0.35}
	)
	stream.name = "Stream"
	stream.position = Vector3(-2.0, STREAM_Y, -9.5)
	root.add_child(stream)
	spots["pond"] = Vector3(POND.x, 0.0, POND.y)
	# Battle-style pond: an ellipse surface over the bowl, shrunk to 80 % (a drying pond).
	arena_pond = WaterSurface.make(
		Vector2(2, 2) * ARENA_R0, {"kind": "pond", "shape": "ellipse", "depth": 0.6}
	)
	arena_pond.name = "ArenaPond"
	arena_pond.position = Vector3(ARENA.x, WATER_Y, ARENA.y)
	arena_pond.scale = Vector3(0.8, 1.0, 0.8)
	root.add_child(arena_pond)
	spots["arena"] = Vector3(ARENA.x, 0.0, ARENA.y)
	spots["stream"] = Vector3(-2.0, 0.4, -7.0)
	# Cascade: the stream spills over the terrace sill into the pond.
	cascade = FountainFx.new()
	cascade.name = "Cascade"
	root.add_child(cascade)
	(
		cascade
		. setup(
			{
				"sheets":
				[
					{
						"from": Vector3(-2.0, STREAM_Y, TERRACE_Z),
						"to": Vector3(-2.0, WATER_Y, TERRACE_Z + 0.45),
						"width": 1.3
					}
				],
				"surfaces": [pond],
			}
		)
	)
	# Fountain: three tiers.
	fountain = FountainFx.new()
	fountain.name = "Fountain"
	fountain.position = FOUNTAIN
	root.add_child(fountain)
	(
		fountain
		. setup(
			{
				"basins":
				[
					{"pos": Vector3(0, 0.38, 0), "size": Vector2(3.25, 3.25), "depth": 0.6},
					{"pos": Vector3(0, 1.4, 0), "size": Vector2(1.75, 1.75), "depth": 0.4},
					{"pos": Vector3(0, 2.17, 0), "size": Vector2(0.95, 0.95), "depth": 0.17},
				],
				"jets":
				[
					{"pos": Vector3(0, 2.26, 0), "height": 0.75, "count": 1},
					{
						"pos": Vector3(0, 0.55, 0),
						"height": 0.42,
						"count": 6,
						"radius": 1.6,
						"reach": -0.9
					},
				],
				"sheets":
				[
					{"from": Vector3(0, 1.3, -1.0), "to": Vector3(0, 0.38, -1.34), "width": 0.42},
					{"from": Vector3(1.0, 1.3, 0), "to": Vector3(1.34, 0.38, 0), "width": 0.42},
					{"from": Vector3(0, 1.3, 1.0), "to": Vector3(0, 0.38, 1.34), "width": 0.42},
					{"from": Vector3(-1.0, 1.3, 0), "to": Vector3(-1.34, 0.38, 0), "width": 0.42},
				],
				"curtains":
				[{"centre": Vector3(0, 2.24, 0), "radius": 0.55, "drop": 0.84, "flare": 0.08}],
				"light": Color(0.62, 0.9, 1.0),
			}
		)
	)


# ---------------------------------------------------------------- decor (detail voxels)


## `weather` 0 keeps rain and snow off decor that sits under the water (weeds).
func _detail_mm(mesh: Mesh, xforms: Array, sway: float, weather := 1.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = VoxelMat.detail_material(
		{"sway": sway, "backlight": 0.25, "weather": weather}
	)
	root.add_child(mmi)
	return mmi


func _bed_top(x: float, z: float) -> float:
	var v := VoxelGrid.vox3(Vector3(x, 0, z))
	var t := g.top_y(v.x, v.z, -100)
	return (t + 1) * VoxelGrid.VS


func _on_bed(x: float, z: float) -> bool:
	var v := VoxelGrid.vox3(Vector3(x, 0, z))
	return g.mat_at(Vector3i(v.x, g.top_y(v.x, v.z, -100), v.z)) in [VoxelMat.BED, VoxelMat.SAND]


func _decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# Reeds: stalks with cattails, on the north-west bank and in the shallows.
	var reeds: Array[Mesh] = []
	for k in 3:
		var rg := VoxelGrid.new(Vector3i(-3, 0, -3), Vector3i(7, 20, 7))
		for s in 5 + k:
			var sx := (s * 37 + k * 11) % 5 - 2
			var sz := (s * 23 + k * 5) % 5 - 2
			var hgt := 10 + (s * 7 + k * 3) % 8
			for y in hgt:
				var c := Color(0.32, 0.55, 0.2).lerp(Color(0.55, 0.62, 0.28), float(y) / hgt)
				rg.put(Vector3i(sx, y, sz), c, VoxelMat.FLOWER)
			if s % 2 == 0:
				for y in range(hgt, hgt + 3):
					rg.put(Vector3i(sx, y, sz), Color(0.45, 0.28, 0.14), VoxelMat.FLOWER)
				rg.put(Vector3i(sx, hgt + 3, sz), Color(0.4, 0.5, 0.2), VoxelMat.FLOWER)
		reeds.append(VoxelMesher.colored(rg, VoxelMat.DETAIL))
	var reed_xf := [[], [], []]
	for i in 70:
		var a := rng.randf_range(2.2, 4.3)
		var q := rng.randf_range(0.86, 1.1)
		var p := Vector2(POND.x + cos(a) * POND_R.x * q, POND.y + sin(a) * POND_R.y * q)
		var y := _bed_top(p.x, p.y)
		reed_xf[i % 3].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y, p.y))
		)
	for k in 3:
		_detail_mm(reeds[k], reed_xf[k], 0.5)
	# Lily pads (some in flower).
	var pads: Array[Mesh] = []
	for k in 2:
		var lg := VoxelGrid.new(Vector3i(-5, 0, -5), Vector3i(11, 3, 11))
		for x in range(-4, 5):
			for z in range(-4, 5):
				if x * x + z * z <= 17 and not (x > 0 and absi(z) <= x / 2):
					var c := Color(0.25, 0.5, 0.2) if (x + z) % 3 != 0 else Color(0.3, 0.58, 0.22)
					lg.put(Vector3i(x, 0, z), c, VoxelMat.FLOWER)
		if k == 1:
			for p in [Vector3i(-1, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, -1), Vector3i(0, 1, 1)]:
				lg.put(p, Color(0.98, 0.62, 0.78), VoxelMat.FLOWER)
			lg.put(Vector3i(0, 1, 0), Color(1.0, 0.9, 0.4), VoxelMat.FLOWER)
			lg.put(Vector3i(0, 2, 0), Color(1.0, 0.72, 0.85), VoxelMat.FLOWER)
		pads.append(VoxelMesher.colored(lg, VoxelMat.DETAIL, Vector3(0.5, 0.5, 0.5)))
	var pad_xf := [[], []]
	for p in [
		Vector2(-6.4, 2.2),
		Vector2(-6.0, 2.6),
		Vector2(-5.5, 2.4),
		Vector2(-1.6, 3.0),
		Vector2(-1.2, 2.7),
		Vector2(-2.3, -1.4),
		Vector2(-6.6, -1.2),
		Vector2(-7.0, -0.7),
		Vector2(-2.0, 2.9),
	]:
		var i: int = pad_xf[0].size() + pad_xf[1].size()
		pad_xf[1 if i % 3 == 0 else 0].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, WATER_Y + 0.005, p.y))
		)
	_detail_mm(pads[0], pad_xf[0], 0.0)
	_detail_mm(pads[1], pad_xf[1], 0.0)
	# Pebbles on the bed and the beach; water plants in the deep.
	var peb := VoxelGrid.new(Vector3i(-2, 0, -2), Vector3i(4, 2, 4))
	peb.fill(Vector3i(-1, 0, -1), Vector3i(0, 0, 1), Color(0.58, 0.56, 0.52), VoxelMat.STONE)
	peb.put(Vector3i(1, 0, 0), Color(0.5, 0.48, 0.45), VoxelMat.STONE)
	peb.put(Vector3i(-1, 1, 0), Color(0.66, 0.64, 0.6), VoxelMat.STONE)
	var peb2 := VoxelGrid.new(Vector3i(-1, 0, -1), Vector3i(3, 1, 2))
	peb2.fill(Vector3i(-1, 0, -1), Vector3i(1, 0, 0), Color(0.62, 0.5, 0.38), VoxelMat.STONE)
	var peb_xf := [[], []]
	for i in 160:
		var a := rng.randf() * TAU
		var q := sqrt(rng.randf()) * 1.08
		var p := Vector2(POND.x + cos(a) * POND_R.x * q, POND.y + sin(a) * POND_R.y * q)
		if not _on_bed(p.x, p.y):
			continue
		peb_xf[i % 2].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, _bed_top(p.x, p.y), p.y))
		)
	_detail_mm(VoxelMesher.colored(peb, VoxelMat.DETAIL), peb_xf[0], 0.0)
	_detail_mm(VoxelMesher.colored(peb2, VoxelMat.DETAIL), peb_xf[1], 0.0)
	var weed := VoxelGrid.new(Vector3i(-2, 0, -2), Vector3i(5, 14, 5))
	for s in 4:
		var hgt := 6 + s * 2
		for y in hgt:
			var off := int(round(sin(y * 0.6 + s) * 1.0))
			weed.put(
				Vector3i(s % 2 - 1 + off, y, s / 2 - 1),
				Color(0.18, 0.38, 0.2).lightened(0.03 * y),
				VoxelMat.FLOWER
			)
	var weed_xf := []
	for i in 26:
		var a := rng.randf() * TAU
		var q := sqrt(rng.randf()) * 0.55
		var p := Vector2(POND.x + cos(a) * POND_R.x * q, POND.y + sin(a) * POND_R.y * q)
		weed_xf.append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, _bed_top(p.x, p.y), p.y))
		)
	_detail_mm(VoxelMesher.colored(weed, VoxelMat.DETAIL), weed_xf, 0.35, 0.0)
	# Flowers around the fountain plaza and on the bank.
	var fl := VoxelGrid.new(Vector3i(-1, 0, -1), Vector3i(3, 5, 3))
	fl.fill(Vector3i(0, 0, 0), Vector3i(0, 2, 0), Color(0.25, 0.5, 0.2), VoxelMat.FLOWER)
	for p in [
		Vector3i(0, 3, 0),
		Vector3i(-1, 3, 0),
		Vector3i(1, 3, 0),
		Vector3i(0, 3, -1),
		Vector3i(0, 3, 1)
	]:
		fl.put(
			p,
			Color(1.0, 0.85, 0.3) if p == Vector3i(0, 3, 0) else Color(0.95, 0.35, 0.4),
			VoxelMat.FLOWER
		)
	var fl_xf := []
	for i in 90:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.5, 4.4)
		fl_xf.append(
			Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU),
				Vector3(FOUNTAIN.x + cos(a) * r, 0, FOUNTAIN.z + sin(a) * r)
			)
		)
	_detail_mm(VoxelMesher.colored(fl, VoxelMat.DETAIL), fl_xf, 0.6)


# ---------------------------------------------------------------- people (2D sprites)


## Tiny pixel figure (16 x 28 px, 0.05 m per pixel like the game's CharSprite).
static func figure(cap: Color, shirt: Color, pants: Color) -> ImageTexture:
	var img := Image.create(16, 28, false, Image.FORMAT_RGBA8)
	var skin := Color(0.98, 0.8, 0.62)
	var hair := Color(0.2, 0.14, 0.1)
	var line := Color(0.12, 0.1, 0.12)
	var rect := func(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				img.set_pixel(x, y, c)
	rect.call(4, 1, 11, 4, cap)
	rect.call(3, 4, 13, 5, cap.darkened(0.25))
	rect.call(4, 6, 11, 11, skin)
	rect.call(4, 6, 4, 9, hair)
	rect.call(11, 6, 11, 9, hair)
	img.set_pixel(6, 8, line)
	img.set_pixel(9, 8, line)
	rect.call(3, 12, 12, 19, shirt)
	rect.call(2, 13, 2, 18, skin)
	rect.call(13, 13, 13, 18, skin)
	rect.call(7, 12, 8, 19, shirt.lightened(0.25))
	rect.call(4, 20, 11, 24, pants)
	rect.call(7, 22, 8, 24, Color(0, 0, 0, 0))
	rect.call(3, 25, 6, 26, line)
	rect.call(9, 25, 12, 26, line)
	return ImageTexture.create_from_image(img)


static func blob() -> ImageTexture:
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 16:
			var d := Vector2((x - 7.5) / 7.5, (y - 7.5) / 6.5)
			if d.length() < 1.0:
				var c := Color(0.45, 0.62, 0.95) if d.y < 0.35 else Color(0.95, 0.92, 0.85)
				if d.length() > 0.86:
					c = Color(0.15, 0.2, 0.35)
				img.set_pixel(x, y, c)
	for p in [Vector2i(5, 5), Vector2i(10, 5)]:
		img.set_pixel(p.x, p.y, Color(0.08, 0.08, 0.12))
	return ImageTexture.create_from_image(img)


func _sprite(tex: Texture2D, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.05
	s.offset = Vector2(0, tex.get_height() * 0.5)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.position = pos
	root.add_child(s)
	return s


func _people() -> void:
	_sprite(
		figure(Color(0.85, 0.15, 0.15), Color(0.2, 0.35, 0.75), Color(0.25, 0.25, 0.35)),
		spots["dock"]
	)
	# A kid wading on the shallow shelf (feet 13 cm under the water).
	var wade := Vector3(-1.1, -0.25, 3.0)
	_sprite(figure(Color(0.2, 0.6, 0.3), Color(0.95, 0.75, 0.2), Color(0.35, 0.3, 0.25)), wade)
	_sprite(blob(), Vector3(-0.4, 0.5, -7.6))
	_sprite(
		figure(Color(0.25, 0.3, 0.8), Color(0.85, 0.3, 0.3), Color(0.2, 0.2, 0.25)),
		FOUNTAIN + Vector3(-0.6, 0, 2.4)
	)
	spots["wade"] = wade
