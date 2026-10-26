class_name ArenaPropsVox
extends RefCounted
## Voxel looks of the live props (BattleProps: tree, berry bush, Voltorb, crystal, boulder, geyser,
## Beedrill hive, spore mushrooms, Oran berry) and of the field objects (BattleField crates and
## rocks, with the Pixel Lab crate / rock palettes). Same rules as ArenaVoxels: cached models,
## quarter turns from the position hash, never the battle RNG, nothing under fast_sim.
## Every prop node is a holder at the prop's base (the game turns, squashes and moves it as before:
## tree fall, Voltorb pulse, boulder roll) with the model in a child turned by a quarter turn.

const VS := ArenaVoxels.VS
const FINE := ArenaVoxels.FINE
const DETAIL := ArenaVoxels.DETAIL
const CTX := ArenaVoxels.CTX
const BODY := ArenaVoxels.BODY
const TOP := ArenaVoxels.TOP
## Variants of each cached prop model.
const VARIANTS := 3


static func _jit(c: Color, v: Vector3i, amt := 0.06, salt := 0) -> Color:
	return ArenaPalette.jit(c, v, amt, salt)


static func _h(v: Vector3i, salt := 0) -> float:
	return VoxelGrid.hash01(v.x, v.y, v.z, salt)


static func _variant(p: Vector3, salt: int) -> int:
	return (
		int(VoxelGrid.hash01(roundi(p.x * 4.0), salt, roundi(p.z * 4.0), 13) * VARIANTS) % VARIANTS
	)


## Holder at `at` with the model inside (quarter turn); metas "mats" copied to the holder.
static func _holder(m: ArenaVoxels.Model, name: String, at: Vector3, params := {}) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.position = at
	var body := ArenaVoxels.instance(m, "Model", params)
	body.rotation.y = PI * 0.5 * ArenaVoxels.quarter(at, 11)
	root.add_child(body)
	root.set_meta("mats", body.get_meta("mats"))
	return root


## Prop node for BattleProps item `o` (kind, pos, r, y). Metas: "mats"; trees and bushes "canopy"
## (the material to tint), crystals "crystal".
static func prop(o: Dictionary, sc: String) -> Node3D:
	var kind := String(o.kind)
	var v := _variant(o.pos, hash(kind) & 0xff)
	var key := "%s_%s_%d" % [kind, sc, v]
	var node: Node3D
	match kind:
		"tree":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _tree_grid(sc, v))
			node = _holder(m, "Prop_tree", o.pos, {TOP: {"sway": 0.035, "sway_base": 1.2}})
			node.set_meta("canopy", ArenaVoxels.mat_of(node, TOP))
		"bush":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _bush_grid(sc, v), FINE)
			node = _holder(m, "Prop_bush", o.pos)
			node.set_meta("canopy", ArenaVoxels.mat_of(node, BODY))
		"voltorb":
			var m := ArenaVoxels.cached(
				"voltorb", func() -> VoxelGrid: return _voltorb_grid(), DETAIL
			)
			node = _holder(m, "Prop_voltorb", o.pos)
		"crystal":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _crystal_grid(v), FINE)
			node = _holder(m, "Prop_crystal", o.pos, {BODY: {"emit_always": 0.9}})
			node.set_meta("crystal", ArenaVoxels.mat_of(node, BODY))
		"boulder":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _boulder_grid(v), FINE)
			node = _holder(m, "Prop_boulder", o.pos)
			node.position.y = float(o.get("y", 0.0)) + BattleProps.BOULDER_R
		"geyser":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _geyser_grid(sc, v), FINE)
			node = _holder(m, "Prop_geyser", o.pos)
		"hive":
			var m := ArenaVoxels.cached(key, func() -> VoxelGrid: return _hive_grid(v), FINE)
			node = _holder(m, "Prop_hive", o.pos)
		"mushroom":
			var m := ArenaVoxels.cached(
				key, func() -> VoxelGrid: return _mushroom_grid(float(o.r), v), DETAIL
			)
			node = _holder(m, "Prop_mushroom", o.pos)
	return node


## Oran berry (bobbing on the ground).
static func berry() -> Node3D:
	var m := ArenaVoxels.cached("oran", func() -> VoxelGrid: return _berry_grid(), DETAIL)
	return ArenaVoxels.instance(m, "Berry")


## Field crate (BattleField), Pixel Lab crate palette.
static func crate(at: Vector3) -> Node3D:
	var m := ArenaVoxels.cached("crate", func() -> VoxelGrid: return _crate_grid(), FINE)
	return _holder(m, "Field_crate", at)


## Field rock (BattleField), Pixel Lab rock palette.
static func rock(at: Vector3) -> Node3D:
	var v := _variant(at, 21)
	var m := ArenaVoxels.cached("fieldrock_%d" % v, func() -> VoxelGrid: return _rock_grid(v), FINE)
	return _holder(m, "Field_rock", at)


# --- Models ---


## Tree at VS (trunk part BODY, crown part TOP): oak, snowy pine on the mountain, drooping willow in
## the swamp.
static func _tree_grid(sc: String, variant: int) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var g := VoxelGrid.new(Vector3i(-5, -1, -5), Vector3i(10, 14, 10))
	var salt := 101 + variant
	g.fill(Vector3i(-2, -1, -2), Vector3i(1, -1, 1), Color.BLACK, VoxelMat.DIRT, CTX)
	var trunk_top := 5 if sc == "montanha" else 6 + variant % 2
	for y in trunk_top + 1:
		for z in range(-1, 1):
			for x in range(-1, 1):
				var v := Vector3i(x, y, z)
				var c: Color = p.bark if (x + z + y) % 3 != 0 else p.bark_dark
				g.put(v, _jit(c, v, 0.05, salt), VoxelMat.BARK, BODY)
	# Roots.
	for d in [Vector3i(-2, 0, 0), Vector3i(1, 0, -1), Vector3i(0, 0, 1), Vector3i(-1, 0, -2)]:
		if _h(d, salt) < 0.8:
			g.put(d, _jit(p.bark_dark, d, 0.05, salt), VoxelMat.BARK, BODY)
	if sc == "montanha":
		# Pine: stacked layers narrowing upwards, snow on each.
		for y in range(3, 13):
			var rad := 3.6 * (1.0 - float(y - 3) / 10.5) + (0.6 if y % 3 == 0 else 0.0)
			for z in range(-5, 5):
				for x in range(-5, 5):
					var d := Vector2(x + 0.5, z + 0.5).length()
					if d > rad:
						continue
					var v := Vector3i(x, y, z)
					var c: Color = p.leaves_dark if d < rad - 1.0 else p.leaves
					g.put(v, _jit(c, v, 0.06, salt), VoxelMat.LEAVES, TOP)
		for z in range(-5, 5):
			for x in range(-5, 5):
				for y in range(12, 2, -1):
					var v := Vector3i(x, y, z)
					if g.solid(v) and not g.solid(v + Vector3i(0, 1, 0)) and _h(v, salt) < 0.7:
						g.put(v, _jit(p.snow, v, 0.03, salt), VoxelMat.SNOW, TOP)
		return g
	var blobs := [
		[Vector3(0, 8.4, 0), Vector3(3.7, 2.9, 3.7)],
		[Vector3(1.3, 9.8, -0.8), Vector3(2.6, 2.2, 2.6)],
		[Vector3(-1.2, 9.2, 1.1), Vector3(2.5, 2.1, 2.5)],
	]
	if variant == 1:
		blobs[1] = [Vector3(-1.0, 10.0, -1.0), Vector3(2.8, 2.0, 2.8)]
	var paint := func(v: Vector3i) -> Color:
		var hv := _h(v, salt)
		var c: Color = p.leaves
		if v.y < 7 or hv < 0.25:
			c = p.leaves_dark
		elif hv > 0.86 or v.y > 10:
			c = p.leaves_light
		return _jit(c, v, 0.05, salt)
	for b in blobs:
		g.ellipsoid(b[0], b[1], p.leaves, VoxelMat.LEAVES, TOP, paint)
	if sc == "pantano":
		# Willow strands hanging from the crown's rim.
		for z in range(-5, 5):
			for x in range(-5, 5):
				var d := Vector2(x + 0.5, z + 0.5).length()
				if d < 2.8 or d > 4.2 or _h(Vector3i(x, 0, z), salt) > 0.45:
					continue
				var low := 3 + int(_h(Vector3i(x, 1, z), salt) * 3.0)
				for y in range(low, 8):
					var v := Vector3i(x, y, z)
					if not g.solid(v):
						g.put(v, _jit(p.leaves_dark, v, 0.06, salt), VoxelMat.LEAVES, TOP)
	return g


## Berry bush (FINE): round leafy mound with blue Oran berries.
static func _bush_grid(sc: String, variant: int) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var g := VoxelGrid.new(Vector3i(-6, -1, -6), Vector3i(12, 8, 12))
	var salt := 201 + variant
	g.fill(Vector3i(-4, -1, -4), Vector3i(3, -1, 3), Color.BLACK, VoxelMat.DIRT, CTX)
	var leaf: Color = Color(p.leaves).darkened(0.12)
	var paint := func(v: Vector3i) -> Color:
		var hv := _h(v, salt)
		if hv > 0.93:
			return Color("3a6fd8") if hv > 0.965 else Color("2f5fd0")
		var c := leaf if v.y > 1 else Color(p.leaves_dark)
		if hv < 0.2:
			c = p.leaves_dark
		elif hv > 0.8:
			c = p.leaves
		return _jit(c, v, 0.05, salt)
	g.ellipsoid(Vector3(0, 2.6, 0), Vector3(4.2, 3.0, 4.2), leaf, VoxelMat.LEAVES, BODY, paint)
	var a := TAU * float(variant) / VARIANTS
	g.ellipsoid(
		Vector3(cos(a) * 2.5, 2.0, sin(a) * 2.5),
		Vector3(2.6, 2.2, 2.6),
		leaf,
		VoxelMat.LEAVES,
		BODY,
		paint,
		true
	)
	return g


## Sleeping Voltorb (DETAIL): red top, thin black seam, white bottom, closed eyes.
static func _voltorb_grid() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-6, -1, -6), Vector3i(12, 13, 12))
	g.fill(Vector3i(-4, -1, -4), Vector3i(3, -1, 3), Color.BLACK, VoxelMat.DIRT, CTX)
	for y in 12:
		for z in range(-6, 6):
			for x in range(-6, 6):
				var c3 := Vector3(x + 0.5, y + 0.5 - 6.0, z + 0.5)
				if c3.length() > 6.0:
					continue
				var v := Vector3i(x, y, z)
				var col := Color("f2f2f2") if _h(v, 3) < 0.85 else Color("d6d6dc")
				if y >= 6:
					col = Color("d8322a") if _h(v, 3) < 0.85 else Color("b82620")
					if c3.y > 3.5 and c3.x < -1.0 and c3.z < 1.0:
						col = Color("ff8a80")  # shine
				if y == 6 and c3.length() > 4.8:
					col = Color("1a1a1a")  # seam
				# Closed eyes on the +z side: two slanted dashes.
				if z >= 4 and y in [8, 9]:
					var ex := x + (1 if y == 9 else 0)
					if (ex >= -4 and ex <= -2) or (ex >= 1 and ex <= 3):
						col = Color("1a1a1a")
				g.put(v, col, VoxelMat.SEAT, BODY)
	return g


## Crystal cluster (FINE): three leaning shards on a stone foot.
static func _crystal_grid(variant: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-6, -1, -6), Vector3i(12, 14, 12))
	var salt := 301 + variant
	g.fill(Vector3i(-3, -1, -3), Vector3i(2, -1, 2), Color.BLACK, VoxelMat.STONE, CTX)
	var pal := [Color("3a8fb8"), Color("5cc0e0"), Color("9fe4f6"), Color("e8fbff")]
	var shards := [
		[Vector2(0, 0), 1.9, 11, Vector2(0.0, 0.0)],
		[Vector2(2.2, 1.0), 1.3, 7, Vector2(0.28, 0.1)],
		[Vector2(-2.0, -1.2), 1.2, 6, Vector2(-0.25, -0.15)],
	]
	if variant == 1:
		shards[1][0] = Vector2(1.0, -2.2)
		shards[1][3] = Vector2(0.1, -0.3)
	for s in shards:
		var base: Vector2 = s[0]
		var rad: float = s[1]
		var tall: int = s[2]
		var lean: Vector2 = s[3]
		for y in tall:
			var k := 1.0 - maxf(float(y) - tall * 0.6, 0.0) / (tall * 0.4 + 0.01)
			var c2 := base + lean * y
			var rr := maxf(rad * k, 0.5)
			for z in range(-6, 6):
				for x in range(-6, 6):
					var d := Vector2(x + 0.5, z + 0.5) - c2
					if absf(d.x) + absf(d.y) * 0.6 > rr * 1.25 or d.length() > rr:
						continue
					var v := Vector3i(x, y, z)
					var edge := d.length() > rr - 0.9
					var col: Color = pal[2] if edge else pal[1]
					if (x + y * 2) % 7 == 0:
						col = pal[3]
					elif _h(v, salt) < 0.2:
						col = pal[0]
					g.put(v, col, VoxelMat.CRYSTAL, BODY)
	for i in 6:
		var a := TAU * i / 6.0 + float(variant)
		var v := Vector3i(roundi(cos(a) * 2.6), 0, roundi(sin(a) * 2.6))
		if not g.solid(v):
			g.put(v, _jit(Color("6a6864"), v, 0.08, salt), VoxelMat.STONE, BODY)
	return g


## Boulder (FINE), centred on its middle (it rolls around it).
static func _boulder_grid(variant: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-4, -4, -4), Vector3i(8, 8, 8))
	var pal := [Color("5a5550"), Color("78716a"), Color("948c82"), Color("b0a89c")]
	var salt := 401 + variant
	for y in range(-4, 4):
		for z in range(-4, 4):
			for x in range(-4, 4):
				var c3 := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var v := Vector3i(x, y, z)
				if c3.length() > 4.1 - _h(v, salt) * 0.7:
					continue
				var k := 1 if _h(v, salt + 1) < 0.5 else 2
				if (x * 3 + y * 5 + z) % 11 == 0:
					k = 0
				elif c3.y > 2.5 and _h(v, salt + 2) > 0.6:
					k = 3
				g.put(v, _jit(pal[k], v, 0.04, salt), VoxelMat.STONE, BODY)
	return g


## Geyser vent (FINE): crater of grey stones with a mineral crust and a dark wet hole.
static func _geyser_grid(sc: String, variant: int) -> VoxelGrid:
	var p := ArenaPalette.of(sc)
	var n := 7
	var g := VoxelGrid.new(Vector3i(-n, -1, -n), Vector3i(n * 2, 4, n * 2))
	var salt := 501 + variant
	for z in range(-n, n):
		for x in range(-n, n):
			var d := Vector2(x + 0.5, z + 0.5).length()
			var v := Vector3i(x, 0, z)
			if d > 6.4:
				continue
			g.put(Vector3i(x, -1, z), Color.BLACK, VoxelMat.STONE, CTX)
			if d < 2.0:
				g.put(v, Color("1c2a33"), VoxelMat.BED, BODY)
			elif d < 3.6:
				var c := Color("6fb7c9") if _h(v, salt) < 0.6 else Color("a6dde8")
				g.put(v, c, VoxelMat.STONE, BODY)
				g.put(
					v + Vector3i(0, 1, 0),
					_jit(Color("dce8e4"), v, 0.06, salt),
					VoxelMat.STONE,
					BODY
				)
				if _h(v, salt + 1) < 0.3:
					g.put(
						v + Vector3i(0, 2, 0),
						_jit(Color(p.stone), v, 0.08, salt),
						VoxelMat.STONE,
						BODY
					)
			elif d < 5.2 or _h(v, salt) < 0.4:
				g.put(v, _jit(Color("5e5a55"), v, 0.08, salt), VoxelMat.STONE, BODY)
	return g


## Beedrill hive (FINE) on a stump.
static func _hive_grid(variant: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-4, -1, -4), Vector3i(8, 12, 8))
	var salt := 601 + variant
	g.fill(Vector3i(-3, -1, -3), Vector3i(2, -1, 2), Color.BLACK, VoxelMat.DIRT, CTX)
	var wood := func(v: Vector3i) -> Color:
		if v.y == 3:
			var ring := Vector2(v.x + 0.5, v.z + 0.5).length() < 1.6
			return Color("8a6240") if ring else Color("6e4a2c")
		return _jit(Color("553720") if (v.x + v.z) % 2 == 0 else Color("3d2614"), v, 0.05, salt)
	g.cylinder(0.0, 0.0, 2.7, 0, 3, Color("553720"), VoxelMat.BARK, BODY, wood)
	var comb := func(v: Vector3i) -> Color:
		if v.y % 2 == 0:
			return Color("2a2216") if _h(v, salt) < 0.85 else Color("4a3a1c")
		return _jit(Color("e0b030") if _h(v, salt) < 0.75 else Color("c8962a"), v, 0.04, salt)
	g.ellipsoid(
		Vector3(0, 6.6, 0), Vector3(2.7, 3.6, 2.7), Color("e0b030"), VoxelMat.HAY, BODY, comb
	)
	# Entrance.
	for v in [Vector3i(0, 6, 2), Vector3i(-1, 6, 2), Vector3i(0, 6, 1), Vector3i(-1, 6, 1)]:
		g.put(v, Color("120c06"), VoxelMat.HAY, BODY)
	return g


## Spore mushrooms (DETAIL): five purple caps with white dots on pale stems.
static func _mushroom_grid(r: float, variant: int) -> VoxelGrid:
	var n := ceili(r / DETAIL)
	var g := VoxelGrid.new(Vector3i(-n, -1, -n), Vector3i(n * 2, 9, n * 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mushroom_%d" % variant)
	var cap := func(v: Vector3i) -> Color:
		if _h(v, 701) > 0.84:
			return Color("f4eee4")
		return Color("a8509a") if _h(v, 702) < 0.7 else Color("8a3e86")
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf()
		var d := rng.randf_range(0.15, r * 0.7) / DETAIL
		var c := Vector2(cos(a) * d, sin(a) * d)
		var k := rng.randf_range(0.75, 1.2)
		var stem := roundi(3.0 * k)
		var cx := roundi(c.x)
		var cz := roundi(c.y)
		g.fill(Vector3i(cx - 1, -1, cz - 1), Vector3i(cx, -1, cz), Color.BLACK, VoxelMat.DIRT, CTX)
		g.fill(
			Vector3i(cx - 1, 0, cz - 1),
			Vector3i(cx, stem, cz),
			Color("e8e0cc"),
			VoxelMat.PLASTER,
			BODY
		)
		var rad := Vector3(3.2 * k, 1.8 * k, 3.2 * k)
		g.ellipsoid(
			Vector3(cx, stem + 1.2, cz), rad, Color("a8509a"), VoxelMat.CLOTH, BODY, cap, true
		)
	return g


## Oran berry (DETAIL): blue ball with a leaf.
static func _berry_grid() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-3, -3, -3), Vector3i(6, 8, 6))
	for y in range(-3, 3):
		for z in range(-3, 3):
			for x in range(-3, 3):
				if Vector3(x + 0.5, y + 0.5, z + 0.5).length() > 2.7:
					continue
				var v := Vector3i(x, y, z)
				g.put(
					v, Color("2f5fd0") if _h(v, 9) < 0.75 else Color("5a86ea"), VoxelMat.SEAT, BODY
				)
	for v in [Vector3i(0, 3, 0), Vector3i(0, 4, 0), Vector3i(1, 4, 0), Vector3i(-1, 3, 0)]:
		g.put(v, Color("3f8a34"), VoxelMat.LEAVES, BODY)
	return g


## Crate (FINE, 0.75 m): dark frame, planks and a cross brace, Pixel Lab crate palette.
static func _crate_grid() -> VoxelGrid:
	var pal: Array = BattleTerrain._palette("crate")
	var g := VoxelGrid.new(Vector3i(-4, -1, -4), Vector3i(8, 8, 8))
	g.fill(Vector3i(-4, -1, -4), Vector3i(3, -1, 3), Color.BLACK, VoxelMat.DIRT, CTX)
	for y in 6:
		for z in range(-3, 3):
			for x in range(-3, 3):
				var v := Vector3i(x, y, z)
				var ex := x == -3 or x == 2
				var ey := y == 0 or y == 5
				var ez := z == -3 or z == 2
				# The art's darkest quantile is its black outline: the frame uses the dark brown.
				var c: Color = Color(pal[2]).lerp(pal[3], 0.25)
				if int(ex) + int(ey) + int(ez) >= 2:
					c = Color(pal[1]).darkened(0.1)  # frame
				elif (ex or ez) and (y == x + 3 or y == 2 - x or y == z + 3 or y == 2 - z):
					c = Color(pal[1]).lerp(pal[2], 0.45)  # brace
				elif y % 2 == 1:
					c = Color(pal[2]).lerp(pal[3], 0.7)
				g.put(v, _jit(c, v, 0.04, 11), VoxelMat.WOOD, BODY)
	return g


## Rock (FINE): a big stone and a small one, Pixel Lab rock palette.
static func _rock_grid(variant: int) -> VoxelGrid:
	var pal: Array = BattleTerrain._palette("stone")
	var g := VoxelGrid.new(Vector3i(-6, -1, -6), Vector3i(12, 7, 12))
	var salt := 801 + variant
	var stones := [[Vector3(-0.5, 0, -0.5), 4.2, 4.4], [Vector3(2.9, 0, 2.2), 2.3, 2.4]]
	for s in stones:
		var c0: Vector3 = s[0]
		var rr: float = s[1]
		var hh: float = s[2]
		for z in range(-6, 6):
			for x in range(-6, 6):
				var d := Vector2(x + 0.5 - c0.x, z + 0.5 - c0.z).length() / rr
				if d > 1.0:
					continue
				g.put(Vector3i(x, -1, z), Color.BLACK, VoxelMat.STONE, CTX)
				var top := roundi(
					hh * sqrt(1.0 - d * d) + (_h(Vector3i(x, 0, z), salt) - 0.5) * 1.4
				)
				for y in maxi(top, 1):
					var v := Vector3i(x, y, z)
					var k := 1 if y < top - 1 else 2
					var hv := _h(v, salt)
					if hv > 0.88:
						k = 3
					elif hv < 0.12 or (x + y * 2) % 9 == 0:
						k = 0
					g.put(v, _jit(pal[k], v, 0.03, salt), VoxelMat.STONE, BODY)
	return g
