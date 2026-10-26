class_name VoxelFlora
extends RefCounted
## Decor of the voxel zones at the detail scale (VoxelMat.DETAIL = 1/16 m): grass tufts, flowers,
## clover, pebbles, reeds, lily pads, ferns, mushrooms, fallen leaves and petals, the crops, a crow,
## door mats and sign lettering. Each model is a small VoxelGrid meshed by VoxelMesher.colored and
## instanced by MultiMesh; scatter() picks the instances per tile from the ground kind with
## deterministic hashes (the same design always gives the same meadow).

const S := 16  ## detail voxels per metre
## model -> sway (voxel_detail.gdshader `sway`, m per m^2 of height)
const SWAY := {
	"tuft_0": 2.2,
	"tuft_1": 2.2,
	"tuft_2": 2.2,
	"tuft_tall": 1.6,
	"tuft_dry": 2.0,
	"tuft_dark": 2.0,
	"reed_0": 0.9,
	"reed_1": 0.9,
	"fern_0": 1.6,
	"fern_1": 1.6,
	"wheat": 1.4,
	"flower_red": 3.0,
	"flower_yellow": 3.0,
	"flower_white": 3.0,
	"flower_pink": 3.0,
	"flower_blue": 3.0,
	"flower_purple": 3.0,
	"daisy": 2.5,
	"carrot": 2.0,
}
const FLOWERS := [
	"flower_red", "flower_yellow", "flower_white", "flower_pink", "flower_blue", "flower_purple"
]
const FLOWER_COLS := {
	"flower_red": [Color("e0383a"), Color("f6d046")],
	"flower_yellow": [Color("f6d046"), Color("d08a24")],
	"flower_white": [Color("f8f4ee"), Color("f2c640")],
	"flower_pink": [Color("f294b8"), Color("fbe0ea")],
	"flower_blue": [Color("5a86e0"), Color("f8f4ee")],
	"flower_purple": [Color("9a5ad0"), Color("f6d046")],
}
## 3 x 5 pixel font for sign lettering (rows top to bottom).
const FONT := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"L": ["100", "100", "100", "100", "111"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"T": ["111", "010", "010", "010", "010"],
	" ": ["000", "000", "000", "000", "000"],
}


## Model name -> {"grid": VoxelGrid, "pivot": Vector3 (detail voxels), "sway": float}.
static func build(name: String) -> Dictionary:
	var g: VoxelGrid
	if name.begins_with("text:"):
		g = _text(name.substr(5))
		return {"grid": g, "pivot": Vector3(g.size.x / 2.0, 0, 0), "sway": 0.0}
	match name:
		"tuft_0", "tuft_1", "tuft_2":
			g = _tuft(int(name.right(1)), VoxelPal.LAWN, VoxelPal.LAWN_LIGHT, 4)
		"tuft_tall":
			g = _tuft(3, VoxelPal.MEADOW, VoxelPal.LAWN_LIGHT, 7)
		"tuft_dry":
			g = _tuft(4, VoxelPal.LAWN_DRY, Color("c8c070"), 5)
		"tuft_dark":
			g = _tuft(5, VoxelPal.FOREST_FLOOR, VoxelPal.MOSS, 5)
		"clover":
			g = _clover()
		"daisy":
			g = _daisy()
		"pebble_0", "pebble_1", "pebble_2":
			g = _pebble(int(name.right(1)))
		"shell":
			g = _shell()
		"reed_0", "reed_1":
			g = _reed(int(name.right(1)))
		"lily_0", "lily_1":
			g = _lily(int(name.right(1)))
		"fern_0", "fern_1":
			g = _fern(int(name.right(1)))
		"mushroom_red", "mushroom_brown":
			g = _mushroom(name == "mushroom_red")
		"leaves":
			g = _litter([Color("b8642a"), Color("d8a040"), Color("8a4a26")], 5)
		"petals":
			g = _litter([VoxelPal.CHERRY, VoxelPal.CHERRY_LIGHT, VoxelPal.CHERRY_DARK], 4)
		"wheat":
			g = _wheat()
		"cabbage":
			g = _cabbage()
		"carrot":
			g = _carrot()
		"pumpkin":
			g = _pumpkin()
		"crow":
			g = _crow()
		"doormat":
			g = _doormat()
		_:
			if FLOWER_COLS.has(name):
				g = _flower(FLOWER_COLS[name][0], FLOWER_COLS[name][1], hash(name))
			else:
				g = _pebble(0)
	return {
		"grid": g,
		"pivot": Vector3(g.size.x / 2.0, 0, g.size.z / 2.0),
		"sway": float(SWAY.get(name, 0.0))
	}


static func _grid(sx: int, sy: int, sz: int) -> VoxelGrid:
	return VoxelGrid.new(Vector3i.ZERO, Vector3i(sx, sy, sz))


static func _c(c: Color, x: int, y: int, z: int, amt := 0.08) -> Color:
	return VoxelPal.vary(c, VoxelGrid.hash01(x, y, z, 90), amt)


static func _tuft(v: int, base: Color, tip: Color, h: int) -> VoxelGrid:
	var g := _grid(5, h + 2, 5)
	var spots := [Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 1), Vector2i(0, 1), Vector2i(4, 3)]
	var n := 3 + v % 2
	for i in n:
		var s: Vector2i = spots[(i + v) % spots.size()]
		var bh := h - (i % 3) + (v % 2)
		for y in bh:
			var k := float(y) / maxf(bh - 1, 1)
			g.put(Vector3i(s.x, y, s.y), _c(base.lerp(tip, k), s.x, y, s.y + v), VoxelMat.GRASS)
	return g


static func _clover() -> VoxelGrid:
	var g := _grid(6, 2, 6)
	for p in [
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
		Vector2i(4, 3),
		Vector2i(4, 4),
		Vector2i(3, 4),
		Vector2i(2, 4)
	]:
		g.put(Vector3i(p.x, 0, p.y), _c(Color("4f9a3a"), p.x, 0, p.y), VoxelMat.GRASS)
	g.put(Vector3i(4, 1, 4), Color("f8f4ee"), VoxelMat.FLOWER)
	return g


static func _flower(petal: Color, eye: Color, sd: int) -> VoxelGrid:
	var g := _grid(5, 9, 5)
	var h := 5 + sd % 3
	for y in h:
		g.put(Vector3i(2, y, 2), _c(Color("4a8a34"), 2, y, sd), VoxelMat.GRASS)
	g.put(Vector3i(3, 2, 2), Color("5aa040"), VoxelMat.GRASS)
	g.put(Vector3i(1, 3, 2), Color("5aa040"), VoxelMat.GRASS)
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		g.put(Vector3i(2 + o.x, h, 2 + o.y), _c(petal, o.x, h, o.y, 0.06), VoxelMat.FLOWER)
	g.put(Vector3i(2, h, 2), eye, VoxelMat.FLOWER)
	g.put(Vector3i(2, h + 1, 2), _c(petal, 0, h + 1, 0, 0.06), VoxelMat.FLOWER)
	return g


static func _daisy() -> VoxelGrid:
	var g := _grid(7, 5, 7)
	for k in 3:
		var p: Vector2i = [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 5)][k]
		var h := 2 + k % 2
		for y in h:
			g.put(Vector3i(p.x, y, p.y), Color("4a8a34"), VoxelMat.GRASS)
		g.put(
			Vector3i(p.x, h, p.y), Color("f8f4ee") if k != 1 else Color("f6d046"), VoxelMat.FLOWER
		)
	return g


static func _pebble(v: int) -> VoxelGrid:
	var g := _grid(4, 2, 4)
	var col: Color = [VoxelPal.ROCK_LIGHT, VoxelPal.ROCK, Color("b8aa98")][v % 3]
	var cells: Array = [
		[Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(1, 0, 2), Vector3i(1, 1, 1)],
		[Vector3i(1, 0, 1), Vector3i(2, 0, 2)],
		[
			Vector3i(0, 0, 1),
			Vector3i(1, 0, 1),
			Vector3i(2, 0, 1),
			Vector3i(1, 0, 2),
			Vector3i(2, 0, 2),
			Vector3i(1, 1, 1),
			Vector3i(2, 1, 2)
		]
	][v % 3]
	for c in cells:
		g.put(c, _c(col, c.x, c.y, c.z, 0.1), VoxelMat.STONE)
	return g


static func _shell() -> VoxelGrid:
	var g := _grid(3, 1, 3)
	g.put(Vector3i(1, 0, 1), Color("f4e6d8"), VoxelMat.STONE)
	g.put(Vector3i(0, 0, 1), Color("e8c8b8"), VoxelMat.STONE)
	return g


static func _reed(v: int) -> VoxelGrid:
	var g := _grid(5, 20, 5)
	var stems := [Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 1)]
	for i in stems.size():
		var s: Vector2i = stems[i]
		var h := 12 + ((i + v) * 3) % 6
		for y in h:
			g.put(
				Vector3i(s.x, y, s.y),
				_c(Color("6a8a3a").lerp(Color("a0b050"), float(y) / h), s.x, y, s.y),
				VoxelMat.GRASS
			)
		if i == 0 or v == 1:
			for y in range(h, h + 3):
				g.put(Vector3i(s.x, y, s.y), Color("6a4026"), VoxelMat.GRASS)
	return g


static func _lily(v: int) -> VoxelGrid:
	var g := _grid(7, 2, 7)
	for z in 7:
		for x in 7:
			var d := Vector2(x - 3, z - 3).length()
			if d > 3.2 or (x >= 3 and z == 3 and x > 3):
				continue
			g.put(Vector3i(x, 0, z), _c(Color("3f8a3a"), x, 0, z, 0.1), VoxelMat.LEAVES)
	if v == 1:
		g.put(Vector3i(2, 1, 2), Color("f6b8d0"), VoxelMat.FLOWER)
		g.put(Vector3i(3, 1, 2), Color("fbe0ea"), VoxelMat.FLOWER)
		g.put(Vector3i(2, 1, 3), Color("fbe0ea"), VoxelMat.FLOWER)
	return g


static func _fern(v: int) -> VoxelGrid:
	var g := _grid(11, 7, 11)
	for k in 5 + v:
		var a := TAU * k / (5.0 + v) + v
		for s in 6:
			var x := 5 + roundi(cos(a) * s * 0.9)
			var z := 5 + roundi(sin(a) * s * 0.9)
			var y := roundi(s * 1.4 - s * s * 0.18)
			g.put(
				Vector3i(x, maxi(y, 0), z),
				_c(Color("3e7a32").lerp(Color("6aa648"), s / 6.0), x, y, z),
				VoxelMat.LEAVES
			)
	return g


static func _mushroom(red: bool) -> VoxelGrid:
	var g := _grid(5, 5, 5)
	for y in 2:
		g.put(Vector3i(2, y, 2), Color("efe6d2"), VoxelMat.WOOD)
	var cap := Color("d03a2c") if red else Color("9a6a40")
	for z in range(1, 4):
		for x in range(1, 4):
			g.put(Vector3i(x, 2, z), cap, VoxelMat.WOOD)
	g.put(Vector3i(2, 3, 2), cap, VoxelMat.WOOD)
	if red:
		g.put(Vector3i(1, 2, 1), Color("f8f4ee"), VoxelMat.WOOD)
		g.put(Vector3i(3, 3, 2), Color("f8f4ee"), VoxelMat.WOOD)
	return g


static func _litter(cols: Array, n: int) -> VoxelGrid:
	var g := _grid(8, 1, 8)
	for i in n:
		var x := int(VoxelGrid.hash01(i, 0, n, 91) * 8)
		var z := int(VoxelGrid.hash01(i, 1, n, 92) * 8)
		g.put(Vector3i(x, 0, z), cols[i % cols.size()], VoxelMat.FLOWER)
	return g


static func _wheat() -> VoxelGrid:
	var g := _grid(6, 16, 6)
	for i in 6:
		var x := 1 + (i * 2) % 5
		var z := 1 + (i * 3) % 4
		var h := 10 + i % 3
		for y in h:
			g.put(Vector3i(x, y, z), _c(Color("b8a040"), x, y, z), VoxelMat.CROP)
		for y in range(h, h + 3):
			g.put(Vector3i(x, y, z), _c(Color("e8c860"), x, y, z), VoxelMat.CROP)
	return g


static func _cabbage() -> VoxelGrid:
	var g := _grid(7, 5, 7)
	for y in 5:
		for z in 7:
			for x in 7:
				var d := Vector3(x - 3, (y - 1.2) * 1.3, z - 3).length()
				if d > 3.2:
					continue
				var c := Color("8ab868") if d < 2.0 else Color("5f9a4c")
				g.put(Vector3i(x, y, z), _c(c, x, y, z), VoxelMat.CROP)
	return g


static func _carrot() -> VoxelGrid:
	var g := _grid(5, 8, 5)
	g.put(Vector3i(2, 0, 2), Color("e07a28"), VoxelMat.CROP)
	for i in 4:
		var o: Vector2i = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1)][i]
		for y in range(1, 5 + i % 2):
			g.put(
				Vector3i(2 + o.x * (y / 2), y, 2 + o.y * (y / 2)),
				_c(Color("4f9a3a"), i, y, 0),
				VoxelMat.CROP
			)
	return g


static func _pumpkin() -> VoxelGrid:
	var g := _grid(8, 6, 8)
	for y in 5:
		for z in 8:
			for x in 8:
				var d := Vector3((x - 3.5) / 3.6, (y - 1.8) / 2.2, (z - 3.5) / 3.2).length()
				if d > 1.0:
					continue
				var c := Color("e08a2a") if (x % 3) != 0 else Color("c86a1e")
				g.put(Vector3i(x, y, z), _c(c, x, y, z, 0.05), VoxelMat.CROP)
	g.put(Vector3i(4, 5, 4), Color("5a7a2a"), VoxelMat.CROP)
	g.put(Vector3i(5, 5, 4), Color("4f9a3a"), VoxelMat.CROP)
	return g


static func _crow() -> VoxelGrid:
	var g := _grid(6, 4, 3)
	for p in [
		Vector3i(1, 1, 1),
		Vector3i(2, 1, 1),
		Vector3i(3, 1, 1),
		Vector3i(2, 2, 1),
		Vector3i(3, 2, 1),
		Vector3i(0, 1, 1),
		Vector3i(4, 2, 1)
	]:
		g.put(p, Color("1e1c22"), VoxelMat.CLOTH)
	g.put(Vector3i(5, 2, 1), Color("e8b030"), VoxelMat.CLOTH)
	g.put(Vector3i(2, 0, 1), Color("e8b030"), VoxelMat.CLOTH)
	return g


static func _doormat() -> VoxelGrid:
	var g := _grid(14, 1, 8)
	for z in 8:
		for x in 14:
			var edge := x == 0 or x == 13 or z == 0 or z == 7
			g.put(
				Vector3i(x, 0, z),
				Color("7a3a2a") if edge else _c(Color("a8643a"), x, 0, z, 0.06),
				VoxelMat.CLOTH
			)
	return g


## Lettering: 3 x 5 glyphs, one detail voxel deep, standing in the x/y plane.
static func _text(s: String) -> VoxelGrid:
	var w := s.length() * 4 - 1
	var g := _grid(maxi(w, 1), 5, 1)
	for i in s.length():
		var gl: Array = FONT.get(s[i].to_upper(), FONT[" "])
		for row in 5:
			for col in 3:
				if String(gl[row])[col] == "1":
					g.put(Vector3i(i * 4 + col, 4 - row, 0), Color("f3e3b0"), VoxelMat.PAINT)
	return g


# --- scatter ---------------------------------------------------------------------------------------


static func _xf(p: Vector3, yaw: float, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p)


## A point on tile t at sub-position (u, v) in [0, 1) with its terrain height.
static func _spot(gen: VoxelZoneGen, t: Vector2i, u: float, v: float) -> Vector3:
	var x := t.x - 0.5 + u
	var z := t.y - 0.5 + v
	var vx := VoxelGrid.vox(x)
	var vz := VoxelGrid.vox(z)
	return Vector3(x, (gen.top_at(vx, vz) + 1) * VoxelGrid.VS, z)


static func scatter(gen: VoxelZoneGen) -> void:
	var d := gen.d
	var crop_of := {}
	for c in d.crops:
		var r: Array = c.rect
		for z in range(int(r[1]), int(r[3]) + 1):
			for x in range(int(r[0]), int(r[2]) + 1):
				crop_of[Vector2i(x, z)] = String(c.crop)
	var cherry := {}
	for e in gen.meta.get("tree_list", []):
		if String(e.model).begins_with("cherry"):
			var p: Vector3 = e.pos
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					cherry[Vector2i(roundi(p.x) + dx, roundi(p.z) + dz)] = true
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			_tile(gen, t, crop_of, cherry)
	# Door mats and sign lettering.
	for b in gen.meta.buildings:
		if b.has("door") and String(b.style) != "shed":
			var dt: Vector2i = b.door
			gen.add_decor("doormat", _xf(Vector3(dt.x, 0.0, dt.y + 0.72), 0.0))
	for tx in gen.meta.get("texts", []):
		gen.add_decor("text:" + String(tx.text), Transform3D(Basis(), tx.pos))


static func _tile(gen: VoxelZoneGen, t: Vector2i, crop_of: Dictionary, cherry: Dictionary) -> void:
	var d := gen.d
	var kind := d.ground_kind(t)
	var th := d.thing_kind(t)
	var h0 := VoxelGrid.hash01(t.x, 30, t.y, 93)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t) ^ 0x5eed
	if th == "crop":
		var crop := String(crop_of.get(t, "cabbage"))
		var n := 2 if crop in ["pumpkin", "cabbage"] else 4
		for i in n:
			var u := 0.25 + 0.5 * (i % 2)
			var v := 0.25 + 0.5 * (i / 2) if n == 4 else 0.3 + 0.4 * i
			if n == 2:
				u = 0.5
			gen.add_decor(
				crop, _xf(_spot(gen, t, u, v), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
			)
		return
	if th != "" and th != "forest":
		if th in ["fence", "hedge", "lamp", "bench"] and kind in ["lawn", "meadow"]:
			_tufts(gen, t, rng, 1, "tuft_0")
		return
	if gen.blocks.has(t) and th != "forest":
		return
	match kind:
		"lawn":
			var n := 1 + int(h0 * 3.0)
			if gen.dist_walk(t) == 0 and _next_to(gen, t, ["cobble", "slab", "dirt"]):
				n += 2
			_tufts(gen, t, rng, n, "")
			if h0 < 0.12:
				gen.add_decor(
					"clover", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			elif h0 > 0.9:
				gen.add_decor(
					"daisy", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			elif h0 > 0.86:
				gen.add_decor(
					_patch_flower(gen, t),
					_xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
		"meadow":
			for i in 4 + int(h0 * 3.0):
				var m: String = (
					"tuft_tall"
					if rng.randf() < 0.55
					else ("tuft_dry" if rng.randf() < 0.3 else "tuft_1")
				)
				gen.add_decor(
					m,
					_xf(
						_spot(gen, t, rng.randf(), rng.randf()),
						rng.randf() * TAU,
						rng.randf_range(0.8, 1.25)
					)
				)
			if h0 < 0.5:
				gen.add_decor(
					_patch_flower(gen, t),
					_xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			if h0 > 0.8:
				gen.add_decor(
					"daisy", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
		"flowers":
			var main := _patch_flower(gen, t)
			for i in 7 + int(h0 * 4.0):
				var m := (
					main if rng.randf() < 0.7 else String(FLOWERS[rng.randi() % FLOWERS.size()])
				)
				gen.add_decor(
					m,
					_xf(
						_spot(gen, t, rng.randf_range(0.05, 0.95), rng.randf_range(0.05, 0.95)),
						rng.randf() * TAU,
						rng.randf_range(0.85, 1.2)
					)
				)
			_tufts(gen, t, rng, 2, "tuft_2")
		"forest_floor":
			var near := gen.dist_walk(t) <= 6
			if not near and h0 > 0.45:
				return
			if h0 < 0.35:
				gen.add_decor(
					"fern_%d" % (rng.randi() % 2),
					_xf(
						_spot(gen, t, rng.randf(), rng.randf()),
						rng.randf() * TAU,
						rng.randf_range(0.8, 1.3)
					)
				)
			if h0 > 0.92:
				gen.add_decor(
					"mushroom_red" if h0 > 0.97 else "mushroom_brown",
					_xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			if h0 > 0.4 and h0 < 0.7:
				gen.add_decor(
					"leaves", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			_tufts(gen, t, rng, 1, "tuft_dark")
		"sand":
			if h0 < 0.35:
				gen.add_decor(
					"pebble_%d" % (rng.randi() % 3),
					_xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			if h0 > 0.93:
				gen.add_decor(
					"shell", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			if _next_to(gen, t, ["lawn", "meadow"]):
				_tufts(gen, t, rng, 1, "tuft_dry")
		"dirt", "soil":
			if h0 < 0.2:
				gen.add_decor(
					"pebble_%d" % (rng.randi() % 3),
					_xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU)
				)
			if _next_to(gen, t, ["lawn", "meadow"]) and h0 > 0.5:
				_tufts(gen, t, rng, 1, "tuft_0")
		"cobble", "slab":
			if h0 < 0.05 and _next_to(gen, t, ["lawn", "meadow", "flowers"]):
				_tufts(gen, t, rng, 1, "tuft_0")
		"shallow", "deep":
			var shore := _next_to(gen, t, ["lawn", "meadow", "sand", "forest_floor", "flowers"])
			if shore and kind == "shallow" and h0 < 0.55:
				for i in 2 + int(h0 * 4.0):
					gen.add_decor(
						"reed_%d" % (rng.randi() % 2),
						_xf(
							(
								_spot(gen, t, rng.randf(), rng.randf()) * Vector3(1, 0, 1)
								+ Vector3(0, -0.5, 0)
							),
							rng.randf() * TAU,
							rng.randf_range(0.85, 1.2)
						)
					)
			elif not shore and h0 > 0.84:
				var w := gen.water_at(t.x, t.y)
				var lvl := float(w.get("level", VoxelZoneGen.WATER_Y))
				var lp := Vector3(
					t.x + rng.randf_range(-0.3, 0.3), lvl + 0.005, t.y + rng.randf_range(-0.3, 0.3)
				)
				gen.add_decor(
					"lily_%d" % (1 if h0 > 0.95 else 0),
					_xf(lp, rng.randf() * TAU, rng.randf_range(0.9, 1.3))
				)
	if cherry.has(t) and kind in ["lawn", "slab", "cobble", "meadow", "flowers"]:
		for i in 2:
			gen.add_decor("petals", _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU))


static func _tufts(
	gen: VoxelZoneGen, t: Vector2i, rng: RandomNumberGenerator, n: int, model: String
) -> void:
	for i in n:
		var m := model if model != "" else "tuft_%d" % (rng.randi() % 3)
		gen.add_decor(
			m,
			_xf(
				_spot(gen, t, rng.randf(), rng.randf()),
				rng.randf() * TAU,
				rng.randf_range(0.8, 1.2)
			)
		)


static func _next_to(gen: VoxelZoneGen, t: Vector2i, kinds: Array) -> bool:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if gen.d.ground_kind(t + o) in kinds:
			return true
	return false


## Flower colour of the noise patch a tile is in (beds read as colour groups).
static func _patch_flower(gen: VoxelZoneGen, t: Vector2i) -> String:
	var n := gen.noise.get_noise_2d(t.x * 2.3 + 100.0, t.y * 2.3) * 0.5 + 0.5
	return String(FLOWERS[clampi(int(n * FLOWERS.size()), 0, FLOWERS.size() - 1)])
