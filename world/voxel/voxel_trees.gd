class_name VoxelTrees
extends RefCounted
## Trees and bushes of the voxel zones: a small library of models (species x variants), each built
## once into its own VoxelGrid on the 0.25 m lattice with the base centre at the model origin, then
## instanced (MultiMesh) in quarter turns at lattice-aligned spots, so hundreds of forest trees cost
## a few models. Crowns are clustered blobs shaded dark inside / bright on top, with per-voxel
## variation; apples, blossoms and birch bark marks are voxels too.
## place() picks the instances from the design: one per tree character in the things layer, and a
## jittered scatter over the forest ('F') tiles with species by area (pines on the outer belts,
## birches near water, oaks elsewhere) and bushes in the gaps.

const SPECIES := {
	"oak": 4,
	"pine": 3,
	"birch": 3,
	"cherry": 2,
	"apple": 2,
	"sapling": 2,
	"bush": 3,
	"shrub": 2,
	"willow": 2,
}
const SWAY := {
	"oak": 0.012,
	"pine": 0.008,
	"birch": 0.016,
	"cherry": 0.012,
	"apple": 0.012,
	"sapling": 0.02,
	"bush": 0.0,
	"shrub": 0.0,
	"willow": 0.016,
}
const FOREST_STEP := 2.5  ## metres between forest tree candidates
const FINE_VS := 0.125  ## lattice of the fine models (bushes): half the world voxel
const FINE := ["bush", "shrub"]


## Every model name of the library ("oak_0", "oak_1", ...).
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in SPECIES:
		for v in SPECIES[s]:
			out.append("%s_%d" % [s, v])
	return out


static func species_of(model: String) -> String:
	return model.substr(0, model.rfind("_"))


## Voxel edge (m) a model is built at: the world lattice, or FINE_VS for bushes.
static func model_vs(model: String) -> float:
	return FINE_VS if species_of(model) in FINE else VoxelGrid.VS


## Builds one model's grid (origin chosen so the base centre is at model (0, 0, 0)).
static func build(model: String) -> VoxelGrid:
	var sp := species_of(model)
	var v := int(model.substr(model.rfind("_") + 1))
	var sd := hash(model)
	match sp:
		"pine":
			return _pine(v, sd)
		"birch":
			return _birch(v, sd)
		"cherry":
			return _broadleaf(
				v, sd, VoxelPal.CHERRY, VoxelPal.CHERRY_LIGHT, VoxelPal.CHERRY_DARK, 0.85, false
			)
		"apple":
			return _broadleaf(
				v, sd, VoxelPal.LEAF, VoxelPal.LEAF_LIGHT, VoxelPal.LEAF_DARK, 0.72, true
			)
		"sapling":
			return _sapling(v, sd)
		"bush":
			return _bush(v, sd, 1.0)
		"shrub":
			return _bush(v, sd, 0.7)
		"willow":
			return _willow(v, sd)
	return _broadleaf(v, sd, VoxelPal.LEAF, VoxelPal.LEAF_LIGHT, VoxelPal.LEAF_DARK, 1.0, false)


static func _grid(r: int, h: int) -> VoxelGrid:
	return VoxelGrid.new(Vector3i(-r, 0, -r), Vector3i(2 * r, h, 2 * r))


## Leaf colour: dark under / inside, bright on top and on the sunny (south-east) side.
static func _leaf(
	v: Vector3i, c: Vector3, r: Vector3, base: Color, light: Color, dark: Color, salt: int
) -> Color:
	var up := clampf((v.y + 0.5 - c.y) / r.y, -1.0, 1.0)
	var side := clampf(((v.x - c.x) * 0.4 + (v.z - c.z) * 0.6) / maxf(r.x, 1.0), -1.0, 1.0)
	var k := up * 0.6 + side * 0.25
	var col := (
		base.lerp(light, clampf(k, 0.0, 1.0)) if k > 0.0 else base.lerp(dark, clampf(-k, 0.0, 1.0))
	)
	var h := VoxelGrid.hash01(v.x, v.y, v.z, salt)
	if h < 0.08:
		col = col.darkened(0.18)
	elif h > 0.94:
		col = col.lightened(0.15)
	return VoxelPal.vary(col, VoxelGrid.hash01(v.x, v.y, v.z, salt + 1), 0.06)


## A lumpy blob of leaves: ellipsoid with hashed bumps and a few holes on the surface.
static func _blob(
	g: VoxelGrid, c: Vector3, r: Vector3, cols: Array, salt: int, holes := 0.12
) -> void:
	for y in range(floori(c.y - r.y) - 1, ceili(c.y + r.y) + 2):
		for z in range(floori(c.z - r.z) - 1, ceili(c.z + r.z) + 2):
			for x in range(floori(c.x - r.x) - 1, ceili(c.x + r.x) + 2):
				var d := Vector3(
					(x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y, (z + 0.5 - c.z) / r.z
				)
				var l := d.length()
				var bump := (VoxelGrid.hash01(x >> 1, y >> 1, z >> 1, salt) - 0.5) * 0.35
				if l > 1.0 + bump:
					continue
				if l > 0.82 and VoxelGrid.hash01(x, y, z, salt + 2) < holes:
					continue
				var v := Vector3i(x, y, z)
				if g.solid(v) and g.mat_at(v) != VoxelMat.LEAVES:
					continue
				g.put(v, _leaf(v, c, r, cols[0], cols[1], cols[2], salt), VoxelMat.LEAVES)


static func _trunk(g: VoxelGrid, h: int, col: Color, salt: int, roots := true) -> void:
	for y in h:
		for z in [-1, 0]:
			for x in [-1, 0]:
				var c := VoxelPal.vary(col, VoxelGrid.hash01(x, y >> 1, z, salt), 0.08)
				if VoxelGrid.hash01(x, y, z, salt + 3) < 0.15:
					c = c.darkened(0.15)
				g.put(Vector3i(x, y, z), c, VoxelMat.BARK)
	if roots:
		for o in [Vector3i(-2, 0, 0), Vector3i(1, 0, -1), Vector3i(0, 0, 1), Vector3i(-1, 0, -2)]:
			if VoxelGrid.hash01(o.x, 0, o.z, salt + 4) < 0.75:
				g.put(o, col.darkened(0.12), VoxelMat.BARK)


## Oak / cherry / apple: trunk with two branches into a crown of 5-7 blobs.
static func _broadleaf(
	v: int, sd: int, base: Color, light: Color, dark: Color, size: float, fruit: bool
) -> VoxelGrid:
	var g := _grid(13, 32)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var th := int((8 + v % 3) * (0.85 + size * 0.15))
	_trunk(g, th + 3, VoxelPal.BARK, sd)
	var cy := th + 5.0 * size + 1.0
	var rr := Vector3(8.5, 6.0, 8.5) * size
	var cols := [base, light, dark]
	# Branches.
	for k in 2:
		var dx := 1 if k == 0 else -2
		for s in 4:
			g.put(
				Vector3i(dx + (s if k == 0 else -s) / 2, th + s, (k * 2 - 1) * (s / 3)),
				VoxelPal.BARK,
				VoxelMat.BARK
			)
	_blob(g, Vector3(0, cy, 0), rr, cols, sd)
	var n := 5 + v % 3
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.4, 0.4)
		var d := rng.randf_range(0.45, 0.75) * rr.x
		var c := Vector3(cos(a) * d, cy + rng.randf_range(-1.5, 3.0) * size, sin(a) * d)
		var r := Vector3.ONE * rng.randf_range(3.5, 5.5) * size
		r.y *= 0.8
		_blob(g, c, r, cols, sd + i * 7)
	_blob(
		g,
		Vector3(rng.randf_range(-1, 1), cy + rr.y * 0.6, rng.randf_range(-1, 1)),
		Vector3(5, 3.5, 5) * size,
		cols,
		sd + 99
	)
	if fruit:
		for z in g.size.z:
			for y in g.size.y:
				for x in g.size.x:
					var p := g.origin + Vector3i(x, y, z)
					if (
						g.mat_at(p) != VoxelMat.LEAVES
						or VoxelGrid.hash01(p.x, p.y, p.z, sd + 5) > 0.035
					):
						continue
					if (
						g.solid(p + Vector3i(0, -1, 0))
						and g.solid(p + Vector3i(1, 0, 0))
						and g.solid(p + Vector3i(0, 0, 1))
						and g.solid(p + Vector3i(-1, 0, 0))
					):
						continue
					g.put(
						p,
						VoxelPal.vary(VoxelPal.APPLE, VoxelGrid.hash01(p.x, p.y, p.z, 6), 0.1),
						VoxelMat.FLOWER
					)
	return g


static func _birch(v: int, sd: int) -> VoxelGrid:
	var g := _grid(9, 36)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var th := 12 + v * 2
	for y in th + 6:
		for z in [-1, 0]:
			for x in [-1, 0]:
				var c := VoxelPal.vary(VoxelPal.BIRCH_BARK, VoxelGrid.hash01(x, y, z, sd), 0.05)
				if VoxelGrid.hash01(x + z * 3, y, 0, sd + 1) < 0.22:
					c = Color("3a3634")
				g.put(Vector3i(x, y, z), c, VoxelMat.BARK)
	var cols := [
		VoxelPal.BIRCH_LEAF, VoxelPal.BIRCH_LEAF.lightened(0.18), VoxelPal.LEAF.darkened(0.1)
	]
	var cy := th + 9.0
	_blob(g, Vector3(0, cy, 0), Vector3(5.5, 9.0, 5.5), cols, sd, 0.2)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		_blob(
			g,
			Vector3(cos(a) * 3.5, cy + rng.randf_range(-4, 5), sin(a) * 3.5),
			Vector3(3.5, 3.0, 3.5),
			cols,
			sd + i * 5,
			0.2
		)
	return g


static func _pine(v: int, sd: int) -> VoxelGrid:
	var g := _grid(9, 40)
	var th := 4 + v
	for y in th + 24:
		for z in [-1, 0]:
			for x in [-1, 0]:
				g.put(
					Vector3i(x, y, z),
					VoxelPal.vary(VoxelPal.BARK_DARK, VoxelGrid.hash01(x, y, z, sd), 0.08),
					VoxelMat.BARK
				)
	var tiers := 6 + v
	var y0 := th
	for t in tiers:
		var r := lerpf(7.5 + v * 0.5, 1.8, float(t) / tiers)
		var ty := y0 + t * 4
		for dy in 4:
			var rr := r * (1.0 - dy * 0.22)
			for z in range(-ceili(rr) - 1, ceili(rr) + 1):
				for x in range(-ceili(rr) - 1, ceili(rr) + 1):
					var d := Vector2(x + 0.5, z + 0.5).length()
					var jag := (VoxelGrid.hash01(x, ty, z, sd + t) - 0.5) * 1.6
					if d > rr + jag:
						continue
					var p := Vector3i(x, ty + dy - (1 if d > rr * 0.7 and dy == 0 else 0), z)
					var k := float(dy) / 3.0 * 0.6 + clampf(d / maxf(r, 1.0), 0.0, 1.0) * 0.4
					var c := VoxelPal.PINE.lerp(VoxelPal.PINE_LIGHT, k * 0.8)
					if VoxelGrid.hash01(p.x, p.y, p.z, sd + 9) < 0.1:
						c = c.darkened(0.2)
					g.put(
						p,
						VoxelPal.vary(c, VoxelGrid.hash01(p.x, p.y, p.z, sd + 2), 0.06),
						VoxelMat.LEAVES
					)
	var tip := y0 + tiers * 4
	for y in range(tip, tip + 3):
		g.put(Vector3i(-1, y, -1), VoxelPal.PINE_LIGHT, VoxelMat.LEAVES)
		g.put(Vector3i(0, y, 0), VoxelPal.PINE, VoxelMat.LEAVES)
	return g


static func _sapling(v: int, sd: int) -> VoxelGrid:
	var g := _grid(5, 14)
	for y in 5 + v:
		g.put(Vector3i(0, y, 0), VoxelPal.BARK, VoxelMat.BARK)
	var cols := [VoxelPal.LEAF_LIGHT.darkened(0.1), VoxelPal.LEAF_LIGHT, VoxelPal.LEAF]
	_blob(g, Vector3(0.5, 7.5 + v, 0.5), Vector3(3.2, 3.0, 3.2), cols, sd, 0.15)
	return g


## Weeping willow (water side): a stout leaning trunk, a low dome and long strands of pale leaves
## hanging almost to the ground all around it.
static func _willow(v: int, sd: int) -> VoxelGrid:
	var g := _grid(12, 30)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var th := 9 + v * 2
	for y in th + 4:
		var lean := y / 6
		for z in [-1, 0]:
			for x in [-1, 0]:
				var c := VoxelPal.vary(VoxelPal.BARK_DARK, VoxelGrid.hash01(x, y >> 1, z, sd), 0.08)
				g.put(Vector3i(x + lean, y, z), c, VoxelMat.BARK)
	var top := Vector3(th / 6 + 0.5, th + 4.0, 0.0)
	var cols := [Color("86ac4c"), Color("a8cc62"), Color("587e36")]
	_blob(g, top, Vector3(7.5, 4.0, 7.5), cols, sd, 0.2)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
		_blob(
			g,
			top + Vector3(cos(a) * 4.5, rng.randf_range(-1.0, 1.5), sin(a) * 4.5),
			Vector3(4.0, 2.8, 4.0),
			cols,
			sd + 11 + i,
			0.2
		)
	# Strands: from the crown's lower rim, columns of leaves hanging 3-10 voxels.
	var hang: Array[Vector3i] = []
	for z in g.size.z:
		for x in g.size.x:
			var p := g.origin + Vector3i(x, 0, z)
			var lowest := -1
			for y in range(th - 2, g.size.y):
				if g.mat_at(Vector3i(p.x, y, p.z)) == VoxelMat.LEAVES:
					lowest = y
					break
			if lowest < 0:
				continue
			var r := Vector2(p.x + 0.5 - top.x, p.z + 0.5 - top.z).length()
			if r < 3.5 or VoxelGrid.hash01(p.x, 5, p.z, sd + 3) > 0.62:
				continue
			hang.append(Vector3i(p.x, lowest, p.z))
	for h in hang:
		var n := 3 + int(VoxelGrid.hash01(h.x, 6, h.z, sd + 4) * 8.0)
		for k in range(1, n + 1):
			var y := h.y - k
			if y < 2:
				break
			var t := float(k) / n
			var c := (cols[0] as Color).lerp(cols[1], t * 0.8)
			g.put(
				Vector3i(h.x, y, h.z),
				VoxelPal.vary(c, VoxelGrid.hash01(h.x, y, h.z, sd + 5), 0.06),
				VoxelMat.LEAVES
			)
	return g


## Round bush (or a smaller, darker forest shrub); variant 2 flowers. Built on the fine lattice
## (FINE_VS, model_vs): two voxels per world voxel, so the leaves read as clusters, not cubes.
static func _bush(v: int, sd: int, s: float) -> VoxelGrid:
	var k := 2.0
	var g := _grid(9, 14)
	var cols := [VoxelPal.HEDGE, VoxelPal.HEDGE_LIGHT, VoxelPal.LEAF_DARK]
	if s < 1.0:
		cols = [VoxelPal.LEAF_DARK, VoxelPal.LEAF, VoxelPal.LEAF_BLUE]
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	_blob(g, Vector3(0, 2.0 * s + 0.5, 0) * k, Vector3(3.4, 2.6, 3.4) * s * k, cols, sd, 0.1)
	# Three to five smaller lobes around the core make an irregular, clumpy outline.
	var n := 3 + v % 3
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.5, 0.5)
		var d := rng.randf_range(1.4, 2.0) * s * k
		var c := Vector3(cos(a) * d, rng.randf_range(1.8, 3.0) * s * k, sin(a) * d)
		_blob(g, c, Vector3.ONE * rng.randf_range(1.5, 2.1) * s * k, cols, sd + 3 + i, 0.14)
	# Twigs at the base.
	for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, -1), Vector3i(0, 0, 1)]:
		g.put(o, VoxelPal.BARK, VoxelMat.BARK)
		g.put(o + Vector3i.UP, VoxelPal.BARK.darkened(0.1), VoxelMat.BARK)
	if v == 2 and s >= 1.0:
		for z in g.size.z:
			for y in g.size.y:
				for x in g.size.x:
					var p := g.origin + Vector3i(x, y, z)
					if (
						g.solid(p)
						and not g.solid(p + Vector3i.UP)
						and VoxelGrid.hash01(p.x, p.y, p.z, sd) < 0.16
					):
						g.put(
							p,
							Color("f6f0f4") if (p.x + p.z) % 3 == 0 else Color("f2a7c3"),
							VoxelMat.FLOWER
						)
	elif v == 1 and s >= 1.0:
		# Berries.
		for z in g.size.z:
			for y in g.size.y:
				for x in g.size.x:
					var p := g.origin + Vector3i(x, y, z)
					if (
						g.solid(p)
						and g.mat_at(p) == VoxelMat.LEAVES
						and not g.solid(p + Vector3i(0, 0, 1))
						and VoxelGrid.hash01(p.x, p.y, p.z, sd + 8) < 0.04
					):
						g.put(p, Color("b8283a"), VoxelMat.FLOWER)
	return g


# --- placement -----------------------------------------------------------------------------------


## Fills gen.meta.trees with {"model", "pos": Vector3, "rot": quarter turns}.
static func place(gen: VoxelZoneGen) -> void:
	var list: Array = []
	var d := gen.d
	var taken := {}
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			var k := d.thing_kind(t)
			var sp := ""
			match k:
				"oak", "cherry", "apple", "birch", "pine", "sapling":
					sp = k
				"bush":
					sp = "bush"
			if sp == "":
				continue
			var ov: Dictionary = d.trees.get(t, {})
			sp = String(ov.get("species", sp))
			var m := "%s_%d" % [sp, int(VoxelGrid.hash01(t.x, 7, t.y, 61) * SPECIES[sp])]
			list.append(_inst(gen, m, Vector2(t.x, t.y), t))
			taken[t] = true
			if sp != "bush":
				_cover(gen, t, 2)
	# Forest scatter.
	var ext := d.extent_m()
	var nx := ceili(ext.size.x / FOREST_STEP)
	var nz := ceili(ext.size.y / FOREST_STEP)
	for cz in nz:
		for cx in nx:
			var h1 := VoxelGrid.hash01(cx, 11, cz, 62)
			var h2 := VoxelGrid.hash01(cx, 12, cz, 63)
			var px := ext.position.x + (cx + 0.2 + h1 * 0.6) * FOREST_STEP
			var pz := ext.position.y + (cz + 0.2 + h2 * 0.6) * FOREST_STEP
			px = roundf(px * 4.0) / 4.0
			pz = roundf(pz * 4.0) / 4.0
			var t := Vector2i(roundi(px), roundi(pz))
			if d.thing_kind(t) != "forest" or taken.has(t):
				continue
			var dw := gen.dist_walk(t)
			var dwat := gen.dist_water(t)
			var sp := "oak"
			var n := gen.noise.get_noise_2d(px * 0.7, pz * 0.7)
			if dwat <= 3:
				var hw := VoxelGrid.hash01(cx, 13, cz, 64)
				sp = "willow" if dwat <= 2 and hw < 0.35 else ("birch" if hw < 0.7 else "oak")
			elif n > 0.18 or dw > 9:
				sp = "pine"
			elif n < -0.3:
				sp = "birch"
			if dw <= 1 and VoxelGrid.hash01(cx, 14, cz, 65) < 0.35:
				sp = "bush"
			if sp != "bush" and occludes(gen, t):
				var hl := VoxelGrid.hash01(cx, 17, cz, 69)
				sp = "sapling" if hl < 0.3 else ("bush" if hl < 0.65 else "shrub")
			var m := "%s_%d" % [sp, int(VoxelGrid.hash01(cx, 15, cz, 66) * SPECIES[sp])]
			list.append(_inst(gen, m, Vector2(px, pz), t))
			taken[t] = true
			# Undergrowth between the trunks.
			var h3 := VoxelGrid.hash01(cx, 16, cz, 67)
			if h3 < 0.55:
				var qx := roundf((px + (h3 - 0.27) * 4.0) * 4.0) / 4.0
				var qz := roundf((pz + 1.1) * 4.0) / 4.0
				var u := Vector2i(roundi(qx), roundi(qz))
				if d.thing_kind(u) == "forest" and not taken.has(u):
					list.append(_inst(gen, "shrub_%d" % (int(h3 * 3.6) % 2), Vector2(qx, qz), u))
					taken[u] = true
	gen.meta.tree_list = list
	gen.meta.trees = list.size()


## True when a tall tree on tile t could stand between the camera (12 m south of the player,
## looking north) and a player on some walkable tile up to 9 m north of it.
static func occludes(gen: VoxelZoneGen, t: Vector2i) -> bool:
	for dz in range(1, 10):
		for dx in range(-3, 4):
			if gen.walkable(t + Vector2i(dx, -dz)):
				return true
	return false


static func _inst(gen: VoxelZoneGen, model: String, p: Vector2, t: Vector2i) -> Dictionary:
	var y := gen.ground_y(t)
	if gen.d.has_tile(t):
		y = (gen.top_at(VoxelGrid.vox(p.x), VoxelGrid.vox(p.y)) + 1) * VoxelGrid.VS
	gen.block(t)
	return {
		"model": model,
		"pos": Vector3(p.x, y, p.y),
		"rot": int(VoxelGrid.hash01(roundi(p.x * 4.0), 3, roundi(p.y * 4.0), 68) * 4.0),
	}


## Walkable tiles within r of a town tree are under its canopy.
static func _cover(gen: VoxelZoneGen, t: Vector2i, r: int) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r + 1:
				gen.covers[t + Vector2i(dx, dz)] = true
