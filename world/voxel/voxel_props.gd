class_name VoxelProps
extends RefCounted
## Everything that stands on a voxel zone's tiles besides buildings and trees (VoxelZoneGen):
## hedges, fences, low walls, gate pillars, street lamps, benches, planters, a well, barrels,
## crates, boulders, a scarecrow, the fountain, the gate arch, the dock with its boat, the bridge,
## and the signs / mailboxes of the map JSON (drawn here, so SignPost skips its model). Each piece
## is built in the zone grid on the 0.25 m lattice; lamps register their light in the metadata.

const WOOD_FENCE := Color("9a8064")
const STONE_LOW := Color("9a948c")


static func things(gen: VoxelZoneGen) -> void:
	VoxelTrees.place(gen)
	var d := gen.d
	var done := {}
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			match d.thing_kind(t):
				"hedge":
					_hedge(gen, t)
				"fence":
					_fence(gen, t)
				"wall":
					_low_wall(gen, t)
				"pillar":
					_pillar(gen, t)
				"lamp":
					_lamp(gen, t)
				"bench":
					_bench(gen, t)
				"planter":
					_planter(gen, t)
				"barrel":
					_barrel(gen, t)
				"crate":
					_crate(gen, t)
				"rock":
					_rock(gen, t, 1.0)
				"scarecrow":
					_scarecrow(gen, t)
				"well":
					if not done.has(t):
						var grp := _group(gen, t, "e", done)
						_well(gen, grp)
				"forest":
					_forest_floor(gen, t)
	_deck(gen)


static func objects(gen: VoxelZoneGen) -> void:
	for o in gen.d.objects:
		match String(o.get("kind", "")):
			"fountain":
				var r: Array = o.rect
				_fountain(gen, Rect2i(r[0], r[1], r[2] - r[0] + 1, r[3] - r[1] + 1))
			"gate":
				_gate(gen, o)


# --- helpers ---------------------------------------------------------------------------------------


## First free voxel layer above the terrain at the tile centre.
static func base(gen: VoxelZoneGen, t: Vector2i) -> int:
	return gen.top_at(VoxelZoneGen.v0(t.x) + 2, VoxelZoneGen.v0(t.y) + 2) + 1


static func _v0(t: int) -> int:
	return VoxelZoneGen.v0(t)


## Connected tiles carrying the same things character (4-neighbour flood fill).
static func _group(gen: VoxelZoneGen, t: Vector2i, ch: String, done: Dictionary) -> Rect2i:
	var q: Array[Vector2i] = [t]
	var lo := t
	var hi := t
	done[t] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var u: Vector2i = c + o
			if not done.has(u) and gen.d.tch(u) == ch:
				done[u] = true
				q.append(u)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


static func _connects(gen: VoxelZoneGen, t: Vector2i, kinds: Array) -> bool:
	return gen.d.thing_kind(t) in kinds


static func _put(gen: VoxelZoneGen, v: Vector3i, c: Color, m: int, amt := 0.06, salt := 0) -> void:
	gen.g.put(v, VoxelPal.vary(c, VoxelGrid.hash01(v.x, v.y, v.z, 70 + salt), amt), m)


static func _box(
	gen: VoxelZoneGen, a: Vector3i, b: Vector3i, c: Color, m: int, amt := 0.06, salt := 0
) -> void:
	for y in range(a.y, b.y + 1):
		for z in range(a.z, b.z + 1):
			for x in range(a.x, b.x + 1):
				_put(gen, Vector3i(x, y, z), c, m, amt, salt)


static func light_at(v: Vector3i) -> Vector3:
	return VoxelGrid.centre(v)


# --- vegetation in the grid --------------------------------------------------------------------------


## Clipped hedge: fills the whole tile 1.0-1.5 m high, lumpy top, ragged where it ends.
static func _hedge(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var x0 := _v0(t.x)
	var z0 := _v0(t.y)
	var join := ["hedge", "pillar", "wall", "forest", "fence"]
	var open_n := not _connects(gen, t + Vector2i(0, -1), join)
	var open_s := not _connects(gen, t + Vector2i(0, 1), join)
	var open_w := not _connects(gen, t + Vector2i(-1, 0), join)
	var open_e := not _connects(gen, t + Vector2i(1, 0), join)
	for z in range(z0, z0 + 4):
		for x in range(x0, x0 + 4):
			var edge := (
				(open_n and z == z0)
				or (open_s and z == z0 + 3)
				or (open_w and x == x0)
				or (open_e and x == x0 + 3)
			)
			var h := 5 + (1 if VoxelGrid.hash01(x >> 1, 0, z >> 1, 71) > 0.6 else 0)
			if edge:
				h -= 1 if VoxelGrid.hash01(x, 1, z, 72) < 0.5 else 0
			for y in range(y0, y0 + h):
				var k := float(y - y0) / h
				var c := VoxelPal.HEDGE.lerp(VoxelPal.LEAF_DARK, clampf(0.6 - k, 0.0, 0.6))
				if y == y0 + h - 1:
					c = VoxelPal.HEDGE_LIGHT
				if edge and VoxelGrid.hash01(x, y, z, 73) < 0.12:
					continue
				var hh := VoxelGrid.hash01(x, y, z, 74)
				if hh < 0.05:
					c = c.darkened(0.2)
				elif hh > 0.985 and y > y0 + 2:
					c = Color("f4eef0")  # tiny blossoms
				gen.g.put(Vector3i(x, y, z), VoxelPal.vary(c, hh, 0.06), VoxelMat.LEAVES)


## Forest floor clutter in the grid: mossy boulders and fallen logs (decor adds ferns, mushrooms).
static func _forest_floor(gen: VoxelZoneGen, t: Vector2i) -> void:
	var h := VoxelGrid.hash01(t.x, 21, t.y, 75)
	if h < 0.025:
		_rock(gen, t, 0.7 + h * 10.0)
	elif (
		h < 0.035
		and gen.d.thing_kind(t + Vector2i(1, 0)) == "forest"
		and gen.d.thing_kind(t + Vector2i(2, 0)) == "forest"
	):
		var y0 := base(gen, t)
		var z := _v0(t.y) + 1
		for x in range(_v0(t.x), _v0(t.x) + 10):
			for dz in 2:
				for dy in 2:
					var c := VoxelPal.BARK.darkened(0.1 if (x + dy) % 3 == 0 else 0.0)
					if x == _v0(t.x) or x == _v0(t.x) + 9:
						c = Color("b49a72")  # cut end
					if dy == 1 and VoxelGrid.hash01(x, 0, dz, 76) < 0.35:
						c = VoxelPal.MOSS
					var top := gen.top_at(x, z + dz) + 1
					gen.g.put(Vector3i(x, maxi(top, y0) + dy, z + dz), c, VoxelMat.BARK)


# --- structures --------------------------------------------------------------------------------------


static func _fence(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var px := _v0(t.x) + 1
	var pz := _v0(t.y) + 1
	var join := ["fence", "pillar", "wall"]
	for y in range(y0, y0 + 4):
		_put(gen, Vector3i(px, y, pz), WOOD_FENCE.darkened(0.12), VoxelMat.WOOD, 0.05)
	_put(gen, Vector3i(px, y0 + 4, pz), WOOD_FENCE.darkened(0.25), VoxelMat.WOOD, 0.04)
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _connects(gen, t + o, join):
			continue
		for s in range(1, 4):
			for ry in [y0 + 1, y0 + 3]:
				var v := Vector3i(px + o.x * s, ry, pz + o.y * s)
				_put(gen, v, WOOD_FENCE, VoxelMat.WOOD, 0.07, 1)


static func _low_wall(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var x0 := _v0(t.x)
	var z0 := _v0(t.y)
	var join := ["wall", "pillar", "hedge"]
	var cells := {}
	for z in range(z0 + 1, z0 + 3):
		for x in range(x0 + 1, x0 + 3):
			cells[Vector2i(x, z)] = true
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _connects(gen, t + o, join):
			continue
		for w in [1, 2]:
			if o.x != 0:
				cells[Vector2i(x0 + (3 if o.x > 0 else 0), z0 + w)] = true
			else:
				cells[Vector2i(x0 + w, z0 + (3 if o.y > 0 else 0))] = true
	for c in cells:
		for y in range(y0, y0 + 3):
			var col := VoxelBuild.stone(c.x + c.y, y, STONE_LOW, 3)
			var m := VoxelMat.STONE
			if y == y0 + 2 and VoxelGrid.hash01(c.x, y, c.y, 77) < 0.4:
				col = VoxelPal.MOSS
				m = VoxelMat.MOSS
			gen.g.put(Vector3i(c.x, y, c.y), col, m)


## Gate pillar: 1 m square stone shaft, a wider cap and a lantern on top.
static func _pillar(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var x0 := _v0(t.x)
	var z0 := _v0(t.y)
	for y in range(y0, y0 + 11):
		for z in range(z0, z0 + 4):
			for x in range(x0, x0 + 4):
				var c := VoxelBuild.stone(x + z * 3, y, VoxelPal.STONE_WALL, 4)
				if y < y0 + 2:
					c = c.darkened(0.12)
				gen.g.put(Vector3i(x, y, z), c, VoxelMat.STONE)
	_box(
		gen,
		Vector3i(x0 - 1, y0 + 11, z0 - 1),
		Vector3i(x0 + 4, y0 + 11, z0 + 4),
		VoxelPal.STONE_WALL_LIGHT,
		VoxelMat.STONE,
		0.05
	)
	_box(
		gen,
		Vector3i(x0 + 1, y0 + 12, z0 + 1),
		Vector3i(x0 + 2, y0 + 12, z0 + 2),
		VoxelPal.METAL,
		VoxelMat.METAL
	)
	_box(
		gen,
		Vector3i(x0 + 1, y0 + 13, z0 + 1),
		Vector3i(x0 + 2, y0 + 14, z0 + 2),
		VoxelPal.LAMP,
		VoxelMat.LAMP,
		0.03
	)
	_box(
		gen,
		Vector3i(x0 + 1, y0 + 15, z0 + 1),
		Vector3i(x0 + 2, y0 + 15, z0 + 2),
		VoxelPal.METAL,
		VoxelMat.METAL
	)
	gen.add_light(
		Vector3(t.x, (y0 + 14) * VoxelGrid.VS, t.y), "lamp", Color(1.0, 0.8, 0.52), 2.6, 8.0
	)


## Street lamp: stone foot, slim iron post, a glass lantern with a cap and finial.
static func _lamp(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var px := _v0(t.x) + 1
	var pz := _v0(t.y) + 1
	_box(
		gen,
		Vector3i(px, y0, pz),
		Vector3i(px + 1, y0 + 1, pz + 1),
		VoxelPal.STONE_WALL_DARK,
		VoxelMat.STONE
	)
	for y in range(y0 + 2, y0 + 9):  # 3.4 m in all: low enough not to hide the player behind it
		_put(gen, Vector3i(px, y, pz), VoxelPal.METAL, VoxelMat.METAL, 0.04)
	var hy := y0 + 9
	for y in range(hy, hy + 3):
		for z in range(pz - 1, pz + 2):
			for x in range(px - 1, px + 2):
				var corner := (x != px) and (z != pz)
				if y == hy:
					_put(gen, Vector3i(x, y, z), VoxelPal.METAL, VoxelMat.METAL, 0.03)
				elif corner:
					_put(gen, Vector3i(x, y, z), VoxelPal.METAL, VoxelMat.METAL, 0.03)
				else:
					gen.g.put(Vector3i(x, y, z), VoxelPal.LAMP, VoxelMat.LAMP)
	_box(
		gen,
		Vector3i(px - 1, hy + 3, pz - 1),
		Vector3i(px + 1, hy + 3, pz + 1),
		VoxelPal.METAL,
		VoxelMat.METAL,
		0.03
	)
	_put(gen, Vector3i(px, hy + 4, pz), VoxelPal.METAL, VoxelMat.METAL)
	gen.add_light(
		VoxelGrid.centre(Vector3i(px, hy + 1, pz)) + Vector3(0, 0.1, 0),
		"lamp",
		Color(1.0, 0.8, 0.52),
		3.2,
		9.0
	)


## Wooden bench facing the nearest paved / walkable neighbour.
static func _bench(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var f := Vector2i(0, 1)
	var best := -1
	for o in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var u: Vector2i = t + o
		if not gen.walkable(u):
			continue
		var k := gen.d.ground_kind(u)
		var score := 2 if k in ["slab", "cobble"] else 1
		if o == Vector2i(0, 1):
			score += 1
		if score > best:
			best = score
			f = o
	var x0 := _v0(t.x)
	var z0 := _v0(t.y)
	for a in 4:  # along the bench
		for b in 4:  # 0 = back ... 3 = front
			var x: int = x0 + (a if f.x == 0 else (b if f.x > 0 else 3 - b))
			var z: int = z0 + (a if f.y == 0 else (b if f.y > 0 else 3 - b))
			var end := a == 0 or a == 3
			if b >= 1 and b <= 2:
				gen.g.put(
					Vector3i(x, y0 + 1, z),
					VoxelBuild.planks(a, b, VoxelPal.WOOD_LIGHT, 5),
					VoxelMat.WOOD
				)
				if end:
					gen.g.put(Vector3i(x, y0, z), VoxelPal.METAL, VoxelMat.METAL)
			if b == 0:
				for y in [y0 + 2, y0 + 3]:
					gen.g.put(
						Vector3i(x, y, z),
						VoxelBuild.planks(a, y, VoxelPal.WOOD_LIGHT, 6),
						VoxelMat.WOOD
					)
				if end:
					gen.g.put(Vector3i(x, y0 + 1, z), VoxelPal.METAL, VoxelMat.METAL)
					gen.g.put(Vector3i(x, y0, z), VoxelPal.METAL, VoxelMat.METAL)


## Stone planter with soil and either a round shrub or flowers.
static func _planter(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var x0 := _v0(t.x)
	var z0 := _v0(t.y)
	for y in range(y0, y0 + 2):
		for z in range(z0, z0 + 4):
			for x in range(x0, x0 + 4):
				var rim := x == x0 or x == x0 + 3 or z == z0 or z == z0 + 3
				if rim:
					gen.g.put(
						Vector3i(x, y, z),
						VoxelBuild.stone(x + z, y, VoxelPal.STONE_WALL_LIGHT, 7),
						VoxelMat.STONE
					)
				elif y == y0 + 1:
					_put(gen, Vector3i(x, y, z), VoxelPal.SOIL, VoxelMat.DIRT)
				else:
					_put(gen, Vector3i(x, y, z), VoxelPal.SOIL_DARK, VoxelMat.DIRT)
	if VoxelGrid.hash01(t.x, 5, t.y, 78) < 0.5:
		var cols := [VoxelPal.HEDGE, VoxelPal.HEDGE_LIGHT, VoxelPal.LEAF_DARK]
		VoxelTrees._blob(
			gen.g, Vector3(x0 + 2, y0 + 3.5, z0 + 2), Vector3(2.2, 2.0, 2.2), cols, hash(t), 0.05
		)
	else:
		var kinds := ["flower_red", "flower_yellow", "flower_white", "flower_pink", "flower_blue"]
		for k in 5:
			var p := Vector3(
				t.x + (k % 2 - 0.5) * 0.3 + (0.1 if k == 4 else 0.0),
				(y0 + 2) * VoxelGrid.VS,
				t.y + (k / 2 - 0.5) * 0.3
			)
			if k == 4:
				p = Vector3(t.x, (y0 + 2) * VoxelGrid.VS, t.y)
			var pick: String = kinds[int(VoxelGrid.hash01(t.x, k, t.y, 79) * kinds.size())]
			gen.add_decor(pick, Transform3D(Basis(Vector3.UP, k * 1.3), p))


static func _barrel(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var cx := _v0(t.x) + 2.0
	var cz := _v0(t.y) + 2.0
	for y in range(y0, y0 + 4):
		var band := y == y0 or y == y0 + 3
		for z in range(_v0(t.y), _v0(t.y) + 4):
			for x in range(_v0(t.x), _v0(t.x) + 4):
				var dx := x + 0.5 - cx
				var dz := z + 0.5 - cz
				if dx * dx + dz * dz > 3.6:
					continue
				var c := VoxelPal.vary(VoxelPal.WOOD, VoxelGrid.hash01(x + z * 5, 0, 0, 80), 0.1)
				var m := VoxelMat.WOOD
				if band:
					c = Color("4a4642")
					m = VoxelMat.METAL
				gen.g.put(Vector3i(x, y, z), c, m)
	_box(
		gen,
		Vector3i(_v0(t.x) + 1, y0 + 4, _v0(t.y) + 1),
		Vector3i(_v0(t.x) + 2, y0 + 4, _v0(t.y) + 2),
		VoxelPal.WOOD_DARK,
		VoxelMat.WOOD
	)


## Pixel Lab crate colours: light faces, dark edges; sometimes a second crate on top.
static func _crate(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var x0 := _v0(t.x)
	var z0 := _v0(t.y) + 1
	_crate_box(gen, Vector3i(x0, y0, z0), 3)
	if VoxelGrid.hash01(t.x, 9, t.y, 81) < 0.6:
		_crate_box(gen, Vector3i(x0 + 1, y0 + 3, z0), 2)


static func _crate_box(gen: VoxelZoneGen, a: Vector3i, n: int) -> void:
	for y in n:
		for z in n:
			for x in n:
				var edges := (
					int(x == 0 or x == n - 1)
					+ int(y == 0 or y == n - 1)
					+ int(z == 0 or z == n - 1)
				)
				var c := Color("a98463") if edges < 2 else Color("7b4a35")
				if edges == 3:
					c = Color("593828")
				_put(gen, a + Vector3i(x, y, z), c, VoxelMat.WOOD, 0.04)


static func _rock(gen: VoxelZoneGen, t: Vector2i, s: float) -> void:
	var y0 := base(gen, t)
	var h := VoxelGrid.hash01(t.x, 3, t.y, 82)
	var c := Vector3(_v0(t.x) + 2.0 + (h - 0.5), y0 - 0.5, _v0(t.y) + 2.0)
	var r := Vector3(2.4 + h * 0.6, 1.8 + h * 0.5, 2.2 + h * 0.4) * s
	_boulder(gen, c, r, hash(t))
	_boulder(gen, c + Vector3(1.6, -0.3, 1.0) * s, r * 0.55, hash(t) + 1)


static func _boulder(gen: VoxelZoneGen, c: Vector3, r: Vector3, salt: int) -> void:
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		for z in range(floori(c.z - r.z) - 1, ceili(c.z + r.z) + 1):
			for x in range(floori(c.x - r.x) - 1, ceili(c.x + r.x) + 1):
				var d := Vector3(
					(x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y, (z + 0.5 - c.z) / r.z
				)
				var bump := (VoxelGrid.hash01(x >> 1, y, z >> 1, salt) - 0.5) * 0.3
				if d.length() > 1.0 + bump:
					continue
				var v := Vector3i(x, y, z)
				var col := VoxelPal.ROCK.lerp(
					VoxelPal.ROCK_LIGHT, clampf(d.y * 0.6 + 0.3, 0.0, 1.0)
				)
				var hh := VoxelGrid.hash01(x, y, z, salt + 1)
				if hh < 0.15:
					col = VoxelPal.ROCK_DARK
				elif hh < 0.22:
					col = VoxelPal.ROCK_BLUE
				var m := VoxelMat.STONE
				if d.y > 0.45 and d.z < 0.2 and VoxelGrid.hash01(x, y, z, salt + 2) < 0.55:
					col = VoxelPal.MOSS
					m = VoxelMat.MOSS
				gen.g.put(v, VoxelPal.vary(col, VoxelGrid.hash01(x, y, z, salt + 3), 0.05), m)


static func _scarecrow(gen: VoxelZoneGen, t: Vector2i) -> void:
	var y0 := base(gen, t)
	var px := _v0(t.x) + 1
	var pz := _v0(t.y) + 2
	for y in range(y0, y0 + 8):
		_put(gen, Vector3i(px, y, pz), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
	for x in range(px - 3, px + 4):
		_put(gen, Vector3i(x, y0 + 6, pz), VoxelPal.WOOD, VoxelMat.WOOD)
	var shirt := Color("b8432f")
	_box(
		gen,
		Vector3i(px - 1, y0 + 3, pz - 1),
		Vector3i(px + 1, y0 + 6, pz),
		shirt,
		VoxelMat.CLOTH,
		0.08
	)
	for x in [px - 2, px + 2]:
		_put(gen, Vector3i(x, y0 + 6, pz - 1), shirt, VoxelMat.CLOTH)
		_put(gen, Vector3i(x, y0 + 5, pz - 1), Color("e2c46a"), VoxelMat.HAY)
	_box(
		gen,
		Vector3i(px - 1, y0 + 7, pz - 1),
		Vector3i(px + 1, y0 + 9, pz + 1),
		Color("e2c46a"),
		VoxelMat.HAY,
		0.1
	)
	gen.g.put(Vector3i(px - 1, y0 + 8, pz + 1), Color("2a2522"), VoxelMat.CLOTH)
	gen.g.put(Vector3i(px + 1, y0 + 8, pz + 1), Color("2a2522"), VoxelMat.CLOTH)
	_box(
		gen,
		Vector3i(px - 2, y0 + 10, pz - 2),
		Vector3i(px + 2, y0 + 10, pz + 2),
		Color("6a4a2e"),
		VoxelMat.CLOTH,
		0.05
	)
	_box(
		gen,
		Vector3i(px - 1, y0 + 11, pz - 1),
		Vector3i(px + 1, y0 + 12, pz + 1),
		Color("6a4a2e"),
		VoxelMat.CLOTH,
		0.05
	)
	gen.add_decor(
		"crow",
		Transform3D(Basis(Vector3.UP, 0.6), Vector3(t.x + 0.65, (y0 + 7) * VoxelGrid.VS, t.y))
	)


## A 2 x 2 tile well: stone ring, dark water, two posts with a small gable roof and a bucket.
static func _well(gen: VoxelZoneGen, r: Rect2i) -> void:
	var t := r.position
	var y0 := base(gen, t)
	var cx := _v0(r.position.x) + r.size.x * 2.0
	var cz := _v0(r.position.y) + r.size.y * 2.0
	var ro := r.size.x * 2.0 - 0.4
	for y in range(y0, y0 + 3):
		for z in range(floori(cz - ro) - 1, ceili(cz + ro) + 1):
			for x in range(floori(cx - ro) - 1, ceili(cx + ro) + 1):
				var dd := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
				if dd > ro:
					continue
				var v := Vector3i(x, y, z)
				if dd > ro - 1.6:
					gen.g.put(v, VoxelBuild.stone(x + z, y, VoxelPal.STONE_WALL, 8), VoxelMat.STONE)
				elif y == y0:
					gen.g.put(v, Color("2a4652"), VoxelMat.GLASS)
	var ix := floori(cx)
	var iz := floori(cz)
	for x in [ix - 3, ix + 2]:
		for y in range(y0 + 3, y0 + 10):
			_put(gen, Vector3i(x, y, iz), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
	for x in range(ix - 3, ix + 3):
		_put(gen, Vector3i(x, y0 + 9, iz), VoxelPal.WOOD, VoxelMat.WOOD)
	for k in 4:
		for x in range(ix - 4, ix + 4):
			for s in [-1, 1]:
				var z: int = iz + (k * s if s > 0 else -k - 1) + (1 if s > 0 else 0)
				gen.g.put(
					Vector3i(x, y0 + 13 - k, z),
					VoxelBuild.roof_tile(x, k, VoxelPal.ROOF_DARK, 9),
					VoxelMat.ROOF
				)
	_box(gen, Vector3i(ix - 1, y0 + 6, iz), Vector3i(ix, y0 + 7, iz), VoxelPal.WOOD, VoxelMat.WOOD)
	_put(gen, Vector3i(ix, y0 + 8, iz), Color("4a4642"), VoxelMat.METAL)
	for tt in VoxelBuild._tiles(r):
		gen.block(tt)


# --- big objects -----------------------------------------------------------------------------------


## Three-tier stone fountain in the tiles of rect r (FountainFx adds the water): a round lower basin
## (coping 0.5 m high over a plinth step, mosaic floor a voxel under the plaza), a pedestal carrying
## a round middle bowl with four overflow notches, a slim column and a small top bowl with the
## nozzle. The water levels sit 12 cm under each rim; meta.fountains holds the FountainFx spec:
## basins, the top jet, a crown of arcs from the coping, spout sheets from the notches and the top
## bowl's overflow curtain.
static func _fountain(gen: VoxelZoneGen, r: Rect2i) -> void:
	var cx := _v0(r.position.x) + r.size.x * 2.0  # voxel coordinates of the centre
	var cz := _v0(r.position.y) + r.size.y * 2.0
	var s := r.size.x / 5.0  # 1 for the 5 x 5 tile fountain
	var r_plinth := 9.8 * s
	var r_out := 8.8 * s  # basin wall
	var r_in := 7.4 * s
	var stone := VoxelPal.STONE_WALL_LIGHT
	var cope := VoxelPal.SLAB.lightened(0.1)
	var mosaic := [Color("4f8f96"), Color("5ea3a6"), Color("e8e2d2"), Color("3d7480")]
	var x0 := floori(cx - r_plinth) - 1
	var x1 := ceili(cx + r_plinth) + 1
	var z0 := floori(cz - r_plinth) - 1
	var z1 := ceili(cz + r_plinth) + 1
	for z in range(z0, z1):
		for x in range(x0, x1):
			var dd := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
			var ang := atan2(z + 0.5 - cz, x + 0.5 - cx)
			if dd >= r_plinth:
				continue
			if dd >= r_out + 0.6:  # plinth step around the basin
				var pc := VoxelBuild.stone(int(ang * 9.0), 0, VoxelPal.STONE_WALL_DARK, 10)
				gen.g.put(Vector3i(x, 0, z), pc, VoxelMat.STONE)
				continue
			if dd >= r_in:  # basin wall, the coping overhangs it by a voxel
				for y in range(-2, 2):
					var c := VoxelBuild.stone(int(ang * 10.0), y, stone, 11)
					var m := VoxelMat.STONE
					if y == 1:
						c = VoxelPal.vary(cope, VoxelGrid.hash01(x, 1, z, 83), 0.04)
						m = VoxelMat.SLAB
					elif dd >= r_out:
						if y < 0:
							continue
						c = VoxelBuild.stone(int(ang * 9.0), 0, VoxelPal.STONE_WALL_DARK, 10)
					gen.g.put(Vector3i(x, y, z), c, m)
				continue
			# Basin: plaza layer cleared, mosaic floor one voxel down.
			gen.g.put(Vector3i(x, -1, z), Color.BLACK, 0)
			var ring := int(dd / 1.6)
			var mc: Color = mosaic[(ring + (1 if (x + z) % 5 == 0 else 0)) % mosaic.size()]
			gen.g.put(
				Vector3i(x, -2, z),
				VoxelPal.vary(mc, VoxelGrid.hash01(x, 0, z, 84), 0.05),
				VoxelMat.BED
			)
	var dark := VoxelPal.STONE_WALL
	# Pedestal (r 0.4 m) up to the middle bowl, its floor, rim and notches (N, E, S, W).
	gen.g.cylinder(cx, cz, 1.6, -2, 2, dark, VoxelMat.STONE, 0, _paint(dark, 0.06, 85))
	gen.g.cylinder(cx, cz, 4.0, 3, 3, stone, VoxelMat.STONE, 0, _paint(stone, 0.06, 86))
	for y in [4, 5]:
		for z in range(floori(cz) - 5, floori(cz) + 6):
			for x in range(floori(cx) - 5, floori(cx) + 6):
				var c := Vector2(x + 0.5 - cx, z + 0.5 - cz)
				if c.length() < 3.0 or c.length() >= 4.0:
					continue
				if y == 5 and (absf(c.x) < 1.0 or absf(c.y) < 1.0):
					continue  # overflow notch
				gen.g.put(Vector3i(x, y, z), stone if y == 4 else cope, VoxelMat.SLAB)
	# Column and the top bowl (r 0.55 m, rim top 2.25 m).
	gen.g.cylinder(cx, cz, 1.0, 4, 6, dark, VoxelMat.STONE, 0, _paint(dark, 0.06, 87))
	gen.g.cylinder(cx, cz, 2.2, 7, 7, stone, VoxelMat.STONE, 0, _paint(stone, 0.06, 88))
	for z in range(floori(cz) - 3, floori(cz) + 4):
		for x in range(floori(cx) - 3, floori(cx) + 4):
			var dd := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
			if dd >= 1.4 and dd < 2.2:
				gen.g.put(Vector3i(x, 8, z), cope, VoxelMat.SLAB)
	# Bowl floors read as the bed (caustics, never wet), the nozzle is brass.
	for z in range(floori(cz) - 4, floori(cz) + 5):
		for x in range(floori(cx) - 4, floori(cx) + 5):
			var dd := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
			if dd < 3.0 and dd > 1.0:
				gen.g.put(Vector3i(x, 3, z), Color(0.44, 0.58, 0.62), VoxelMat.BED)
			if dd < 1.4 and dd > 0.6:
				gen.g.put(Vector3i(x, 7, z), Color(0.44, 0.58, 0.62), VoxelMat.BED)
	gen.g.put(Vector3i(floori(cx), 8, floori(cz)), Color(0.62, 0.52, 0.3), VoxelMat.METAL)
	# Flowers in the corners of the fountain's square (outside the plinth).
	for k in 4:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var sz := -1.0 if k < 2 else 1.0
		var p := Vector3(cx * VoxelGrid.VS, 0.0, cz * VoxelGrid.VS) + Vector3(sx, 0, sz) * 2.2 * s
		for i in 3:
			var o := Vector3(
				VoxelGrid.hash01(k, i, 1, 89) - 0.5, 0, VoxelGrid.hash01(k, i, 2, 89) - 0.5
			)
			gen.add_decor(
				VoxelFlora.FLOWERS[(k * 2 + i) % VoxelFlora.FLOWERS.size()],
				Transform3D(Basis(Vector3.UP, i * 2.1), p + o * 0.3)
			)
	var centre := Vector3(cx * VoxelGrid.VS, 0.0, cz * VoxelGrid.VS)
	var low := 0.38
	var lower := (r_in * VoxelGrid.VS) * 2.0 + 0.05
	(
		gen
		. meta
		. fountains
		. append(
			{
				"centre": centre,
				"basins":
				[
					{
						"pos": centre + Vector3(0, low, 0),
						"size": Vector2(lower, lower),
						"depth": 0.6
					},
					{"pos": centre + Vector3(0, 1.4, 0), "size": Vector2(1.55, 1.55), "depth": 0.4},
					{
						"pos": centre + Vector3(0, 2.17, 0),
						"size": Vector2(0.75, 0.75),
						"depth": 0.17
					},
				],
				"jets":
				[
					{"pos": centre + Vector3(0, 2.26, 0), "height": 0.8, "count": 1},
					{
						"pos": centre + Vector3(0, 0.55, 0),
						"height": 0.42,
						"count": 8,
						"radius": 2.0 * s,
						"reach": -0.75
					},
				],
				"sheets":
				[
					{
						"from": centre + Vector3(0, 1.3, -1.0),
						"to": centre + Vector3(0, low, -1.4),
						"width": 0.42
					},
					{
						"from": centre + Vector3(1.0, 1.3, 0),
						"to": centre + Vector3(1.4, low, 0),
						"width": 0.42
					},
					{
						"from": centre + Vector3(0, 1.3, 1.0),
						"to": centre + Vector3(0, low, 1.4),
						"width": 0.42
					},
					{
						"from": centre + Vector3(-1.0, 1.3, 0),
						"to": centre + Vector3(-1.4, low, 0),
						"width": 0.42
					},
				],
				"curtains":
				[
					{
						"centre": centre + Vector3(0, 2.24, 0),
						"radius": 0.55,
						"drop": 0.84,
						"flare": 0.08
					}
				],
				"light": Color(0.62, 0.9, 1.0),
			}
		)
	)


## Paint callable: c varied per voxel (VoxelGrid.fill / cylinder).
static func _paint(c: Color, amt: float, salt: int) -> Callable:
	return func(v: Vector3i) -> Color: return VoxelPal.at(c, v, amt, salt)


## Town gate: an arch beam between the two pillars with a hanging name board.
static func _gate(gen: VoxelZoneGen, o: Dictionary) -> void:
	var a: Array = o.from
	var b: Array = o.to
	var t0 := Vector2i(int(a[0]), int(a[1]))
	var t1 := Vector2i(int(b[0]), int(b[1]))
	var y0 := base(gen, t0)
	var z0 := _v0(t0.y)
	var xa := _v0(t0.x) + 4
	var xb := _v0(t1.x) - 1
	for x in range(xa - 4, xb + 5):
		for y in [y0 + 9, y0 + 10]:
			for z in [z0 + 1, z0 + 2]:
				gen.g.put(
					Vector3i(x, y, z),
					VoxelBuild.planks(x, y, VoxelPal.WOOD_DARK, 14),
					VoxelMat.WOOD
				)
	# Brackets.
	for x in [xa, xb]:
		gen.g.put(Vector3i(x, y0 + 8, z0 + 2), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
	# Name board hanging under the beam (lettering is decor).
	var bw := 12
	var bx := floori((xa + xb) / 2.0) - bw / 2 + 1
	for x in range(bx, bx + bw):
		for y in [y0 + 7, y0 + 8]:
			gen.g.put(
				Vector3i(x, y, z0 + 2), VoxelBuild.planks(x, y, Color("6b4a30"), 15), VoxelMat.WOOD
			)
	for x in [bx - 1, bx + bw]:
		for y in [y0 + 7, y0 + 8]:
			gen.g.put(Vector3i(x, y, z0 + 2), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
	var text := String(o.get("sign", ""))
	if text != "":
		var p := Vector3(
			((bx + bx + bw) / 2.0) * VoxelGrid.VS,
			(y0 + 7) * VoxelGrid.VS + 0.1,
			(z0 + 3) * VoxelGrid.VS + 0.005
		)
		gen.meta.get_or_add("texts", []).append({"text": text, "pos": p, "color": "f3e3b0"})
	for x in range(xa, xb + 1):
		gen.covers[Vector2i(VoxelZoneGen.tile_of(x), t0.y)] = true
	# Wandering NPCs never stand in the gateway (the way into Route 1 stays open).
	for z in range(t0.y, t0.y + 3):
		for x in range(t0.x + 1, t1.x):
			gen.no_npc[Vector2i(x, z)] = true


## Docks and bridges: plank decks over the carved water, posts, railings, a moored boat.
static func _deck(gen: VoxelZoneGen) -> void:
	var d := gen.d
	var boat_done := false
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			var k := d.ground_kind(t)
			if k != "dock" and k != "bridge":
				continue
			var along_x := (
				d.ground_kind(t + Vector2i(1, 0)) == k or d.ground_kind(t + Vector2i(-1, 0)) == k
			)
			var x0 := _v0(t.x)
			var z0 := _v0(t.y)
			for vz in range(z0, z0 + 4):
				for vx in range(x0, x0 + 4):
					var u := vx if along_x else vz
					var plank := VoxelPal.vary(Color("9b7652"), VoxelGrid.hash01(u, 0, 0, 84), 0.1)
					if u % 4 == 0:
						plank = plank.darkened(0.2)
					gen.g.put(Vector3i(vx, -1, vz), plank, VoxelMat.WOOD)
					gen.g.put(
						Vector3i(vx, -2, vz),
						Color("5a4030") if (vx == x0 or vz == z0) else plank.darkened(0.3),
						VoxelMat.WOOD
					)
			# Posts down to the bed at the outer corners.
			for c in [
				Vector2i(x0, z0),
				Vector2i(x0 + 3, z0 + 3),
				Vector2i(x0, z0 + 3),
				Vector2i(x0 + 3, z0)
			]:
				var side := Vector2i(1 if c.x > x0 else -1, 1 if c.y > z0 else -1)
				var outer := (
					not d.is_wet(t + Vector2i(side.x, 0))
					if along_x
					else not d.is_wet(t + Vector2i(0, side.y))
				)
				if (t.x + t.y) % 2 != 0:
					continue
				var bed := gen.top_at(c.x, c.y)
				for y in range(bed + 1, -2):
					gen.g.put(Vector3i(c.x, y, c.y), Color("4e3a2c"), VoxelMat.WOOD)
				if k == "dock" and outer:
					gen.g.put(Vector3i(c.x, 0, c.y), Color("4e3a2c"), VoxelMat.WOOD)
			if k == "bridge":
				# Railings on the bridge's two water sides.
				var sides := (
					[Vector2i(0, -1), Vector2i(0, 1)]
					if along_x
					else [Vector2i(-1, 0), Vector2i(1, 0)]
				)
				for s in sides:
					if d.ground_kind(t + s) == k:
						continue
					for i in 4:
						var vx: int = x0 + (i if along_x else (0 if s.x < 0 else 3))
						var vz: int = z0 + ((0 if s.y < 0 else 3) if along_x else i)
						gen.g.put(Vector3i(vx, 3, vz), VoxelPal.WOOD_LIGHT, VoxelMat.WOOD)
						if i == 0:
							for y in range(0, 4):
								gen.g.put(Vector3i(vx, y, vz), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
						if i == 2:
							gen.g.put(Vector3i(vx, 1, vz), VoxelPal.WOOD, VoxelMat.WOOD)
			elif (
				not boat_done
				and d.ground_kind(t + Vector2i(-1, 0)) in VoxelDesign.WATER_KINDS
				and along_x
			):
				_boat(gen, Vector3i(x0 - 3, -2, z0 + 5))
				boat_done = true


## A little rowboat floating by the dock (hull just above the water line).
static func _boat(gen: VoxelZoneGen, a: Vector3i) -> void:
	var length := 10
	var hw := [1, 2, 2, 2, 2, 2, 2, 2, 1, 0]
	for i in length:
		var w: int = hw[i]
		for dz in range(-w, w + 1):
			var x := a.x - i
			var edge := absi(dz) == w
			gen.g.put(Vector3i(x, a.y, a.z + dz), Color("7a5236"), VoxelMat.WOOD)
			if edge or i == 0 or i == length - 1:
				gen.g.put(
					Vector3i(x, a.y + 1, a.z + dz),
					Color("e8e2d2") if not edge else Color("2f5f8a"),
					VoxelMat.WOOD
				)
		if i == 4:
			for dz in range(-w + 1, w):
				gen.g.put(Vector3i(a.x - i, a.y + 1, a.z + dz), Color("8a6446"), VoxelMat.WOOD)


## Signs and mailboxes from the map JSON (SignPost draws only its prompt for voxel zones).
static func signs(gen: VoxelZoneGen) -> void:
	for s in gen.map.get("signs", []):
		var p: Array = s.get("pos", [0, 0])
		var t := Vector2i(roundi(float(p[0])), roundi(float(p[1])))
		var y0 := base(gen, t)
		var x0 := _v0(t.x)
		var z0 := _v0(t.y)
		var mailbox := String(s.get("model", "")).contains("mailbox")
		if mailbox:
			var col := (
				Color("c8402c") if String(s.get("name", "")).contains("Player") else Color("3c64a8")
			)
			for y in range(y0, y0 + 3):
				_put(gen, Vector3i(x0 + 1, y, z0 + 2), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
			_box(
				gen,
				Vector3i(x0, y0 + 3, z0 + 1),
				Vector3i(x0 + 2, y0 + 4, z0 + 3),
				col,
				VoxelMat.PAINT,
				0.04
			)
			_put(gen, Vector3i(x0 + 1, y0 + 4, z0 + 3), col.darkened(0.4), VoxelMat.PAINT)
			_put(gen, Vector3i(x0 + 3, y0 + 4, z0 + 2), Color("e8d44a"), VoxelMat.PAINT)
			_put(gen, Vector3i(x0 + 3, y0 + 5, z0 + 2), Color("e8d44a"), VoxelMat.PAINT)
		else:
			for x in [x0, x0 + 3]:
				for y in range(y0, y0 + 4):
					_put(gen, Vector3i(x, y, z0 + 2), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
			for x in range(x0, x0 + 4):
				for y in [y0 + 2, y0 + 3]:
					gen.g.put(
						Vector3i(x, y, z0 + 2),
						VoxelBuild.planks(x, y, VoxelPal.WOOD_LIGHT, 16),
						VoxelMat.WOOD
					)
				gen.g.put(Vector3i(x, y0 + 4, z0 + 2), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
				gen.g.put(Vector3i(x, y0 + 4, z0 + 1), VoxelPal.WOOD_DARK, VoxelMat.WOOD)
		gen.block(t)
		gen.meta.signs.append({"name": String(s.get("name", "")), "tile": [t.x, t.y]})
