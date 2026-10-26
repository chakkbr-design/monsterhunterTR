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
	"tulip_red": 2.6,
	"tulip_yellow": 2.6,
	"tulip_pink": 2.6,
	"lavender": 2.4,
	"sunflower": 0.9,
	"poppy": 3.0,
	"bluebell": 2.6,
	"forget_me_not": 2.0,
	"marigold": 2.0,
	"iris": 1.6,
	"weed_0": 1.4,
	"weed_1": 1.4,
	"weed_2": 1.2,
	"corn": 0.9,
	"tomato": 0.8,
	"grass_clump": 1.8,
}
## Garden flowers (beds, planters, window boxes): the noise patches of a bed pick one of these.
const FLOWERS := [
	"flower_red",
	"flower_yellow",
	"flower_white",
	"flower_pink",
	"flower_blue",
	"flower_purple",
	"tulip_red",
	"tulip_yellow",
	"tulip_pink",
	"lavender",
	"marigold",
	"rose",
]
## Wild flowers of the lawns, meadows and forest edges.
const WILD := ["daisy", "poppy", "forget_me_not", "bluebell", "flower_white", "flower_yellow"]
## Underwater weeds (decor material with weather 0: no rain or snow on them).
const WEEDS := ["weed_0", "weed_1", "weed_2"]
## Growth stage per row parity (tile z even / odd) of each crop: 0 seedlings, 1 young, 2 ripe.
const CROP_STAGES := {
	"lettuce": [2, 1],
	"cabbage": [1, 2],
	"strawberry": [2, 1],
	"pumpkin": [2, 1],
	"corn": [2, 2],
	"wheat": [2, 2],
	"tomato": [1, 2],
	"carrot": [0, 2],
}
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


## Model name -> {"grid": VoxelGrid, "pivot": Vector3 (detail voxels), "sway": float, "weather":
## 0 (under water: no rain / snow) or 1, "backlight": float (petals glow against the sun)}.
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
		"tulip_red", "tulip_yellow", "tulip_pink":
			var tc := {"tulip_red": "e03a3a", "tulip_yellow": "f4d23c", "tulip_pink": "f08cb4"}
			g = _tulip(Color(tc[name]), hash(name))
		"lavender":
			g = _lavender()
		"sunflower":
			g = _sunflower()
		"poppy":
			g = _poppy()
		"bluebell":
			g = _bluebell()
		"forget_me_not":
			g = _forget_me_not()
		"marigold":
			g = _marigold()
		"rose":
			g = _rose()
		"iris":
			g = _iris()
		"weed_0", "weed_1", "weed_2":
			g = _weed(int(name.right(1)))
		"flat_stone":
			g = _flat_stone()
		"corn":
			g = _corn()
		"tomato":
			g = _tomato()
		"lettuce":
			g = _lettuce()
		"strawberry":
			g = _strawberry()
		"grass_clump":
			g = _tuft(6, VoxelPal.LAWN, VoxelPal.LAWN_LIGHT, 8)
		"sprout":
			g = _sprout()
		"windfall":
			g = _windfall()
		"ivy_0", "ivy_1":
			g = _ivy(int(name.right(1)))
		"watering_can":
			g = _watering_can()
		_:
			if FLOWER_COLS.has(name):
				g = _flower(FLOWER_COLS[name][0], FLOWER_COLS[name][1], hash(name))
			else:
				g = _pebble(0)
	var lit := name in FLOWERS or name in WILD or name in ["sunflower", "iris", "petals"]
	return {
		"grid": g,
		"pivot": Vector3(g.size.x / 2.0, 0, g.size.z / 2.0),
		"sway": float(SWAY.get(name, 0.0)),
		"weather": 0.0 if name in WEEDS else 1.0,
		"backlight": 0.35 if lit or name.begins_with("lily") else 0.0,
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
	var col: Color = [
		VoxelPal.ROCK_LIGHT, VoxelPal.ROCK, Color("b8aa98"), Color("c9b9a0"), Color("7d7f86")
	][v % 5]
	if v >= 3:
		var cells2: Array = [
			[Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(3, 0, 2)],
			[Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(2, 0, 2), Vector3i(1, 1, 1)],
		][v - 3]
		for c in cells2:
			g.put(c, _c(col, c.x, c.y, c.z + v, 0.1), VoxelMat.STONE)
		return g
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


## Ivy climbing a wall corner (0.5 m x 1.6 m panel, two voxels deep, wall side at z 0): woody
## stems branching up from the foot, leaves of two greens around them, thinning towards the top.
static func _ivy(v: int) -> VoxelGrid:
	var g := _grid(9, 26, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + v * 17
	var tips: Array[Vector2i] = [Vector2i(4, 0)]
	var stems: Array[Vector2i] = []
	for i in 3 + v:
		var p: Vector2i = tips[rng.randi() % tips.size()]
		var h := rng.randi_range(8, 24)
		for k in h:
			if rng.randf() < 0.3:
				p.x = clampi(p.x + (1 if rng.randf() < 0.5 else -1), 0, 8)
			p.y += 1
			if p.y >= 26:
				break
			stems.append(p)
		tips.append(p)
	for st in stems:
		g.put(Vector3i(st.x, st.y, 0), Color("5a4630"), VoxelMat.BARK)
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q := st + o
			var thin := float(q.y) / 26.0
			if rng.randf() < 0.25 + thin * 0.45 or q.x < 0 or q.x > 8:
				continue
			var c := Color("3f6a2c") if rng.randf() < 0.55 else Color("5f8f3a")
			if not g.solid(Vector3i(q.x, q.y, 0)):
				g.put(Vector3i(q.x, q.y, 0), _c(c, q.x, q.y, 0), VoxelMat.LEAVES)
			if rng.randf() < 0.5:
				g.put(Vector3i(q.x, q.y, 1), _c(c.lightened(0.06), q.x, q.y, 1), VoxelMat.LEAVES)
	return g


## Two or three fallen apples in the grass.
static func _windfall() -> VoxelGrid:
	var g := _grid(8, 2, 8)
	for a: Vector2i in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 6)]:
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var p := a + o
			g.put(Vector3i(p.x, 0, p.y), _c(VoxelPal.APPLE, p.x, 0, p.y, 0.08), VoxelMat.FLOWER)
		g.put(
			Vector3i(a.x, 1, a.y), _c(VoxelPal.APPLE.lightened(0.1), a.x, 1, a.y), VoxelMat.FLOWER
		)
	return g


## A seedling: a short stem and two seed leaves (young crop rows).
static func _sprout() -> VoxelGrid:
	var g := _grid(5, 4, 3)
	var stem := Color("6aa848")
	g.put(Vector3i(2, 0, 1), stem, VoxelMat.CROP)
	g.put(Vector3i(2, 1, 1), stem, VoxelMat.CROP)
	for x in [0, 1, 3, 4]:
		var y := 2 if x == 1 or x == 3 else 3
		g.put(Vector3i(x, y, 1), _c(Color("8cc85a"), x, y, 1), VoxelMat.CROP)
	return g


## A galvanised watering can (0.4 m): round-ish body, a long spout with a rose, a top handle.
static func _watering_can() -> VoxelGrid:
	var g := _grid(10, 7, 5)
	var zinc := Color("9aa4a6")
	for y in range(0, 4):
		for z in range(0, 5):
			for x in range(2, 7):
				if (x == 2 or x == 6) and (z == 0 or z == 4):
					continue
				var zc := zinc.darkened(0.08 if y == 0 else 0.0)
				g.put(Vector3i(x, y, z), _c(zc, x, y, z, 0.03), VoxelMat.METAL)
	for i in 3:
		g.put(Vector3i(7 + i, 2 + i, 2), _c(zinc, 7 + i, 2 + i, 2, 0.03), VoxelMat.METAL)
	g.put(Vector3i(9, 5, 2), zinc.darkened(0.2), VoxelMat.METAL)
	for x in range(3, 6):
		g.put(Vector3i(x, 6, 2), zinc.darkened(0.1), VoxelMat.METAL)
	g.put(Vector3i(3, 5, 2), zinc.darkened(0.1), VoxelMat.METAL)
	g.put(Vector3i(5, 5, 2), zinc.darkened(0.1), VoxelMat.METAL)
	g.put(Vector3i(1, 2, 2), zinc.darkened(0.1), VoxelMat.METAL)
	g.put(Vector3i(1, 3, 2), zinc.darkened(0.1), VoxelMat.METAL)
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


## Tulip: straight stem, two blade leaves, a cup of petals open at the top.
static func _tulip(c: Color, sd: int) -> VoxelGrid:
	var g := _grid(5, 10, 5)
	var h := 6 + sd % 2
	for y in h:
		g.put(Vector3i(2, y, 2), _c(Color("4a8a34"), 2, y, sd), VoxelMat.GRASS)
	for k in 4:
		var leaf := Color("5f9a42").lerp(Color("7ab050"), k / 4.0)
		g.put(Vector3i(1 if k < 2 else 0, k, 2), leaf, VoxelMat.GRASS)
		g.put(Vector3i(3, k, 2 if k < 3 else 3), leaf.darkened(0.08), VoxelMat.GRASS)
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		g.put(Vector3i(2 + o.x, h, 2 + o.y), c.darkened(0.15), VoxelMat.FLOWER)
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		g.put(Vector3i(2 + o.x, h + 1, 2 + o.y), _c(c, o.x, h + 1, o.y, 0.05), VoxelMat.FLOWER)
		g.put(Vector3i(2 + o.x, h + 2, 2 + o.y), c.lightened(0.12), VoxelMat.FLOWER)
	g.put(Vector3i(2, h + 1, 2), Color("f2d060"), VoxelMat.FLOWER)
	return g


## Lavender: a tuft of grey-green stems ending in purple spikes.
static func _lavender() -> VoxelGrid:
	var g := _grid(7, 12, 7)
	var spots := [Vector2i(3, 3), Vector2i(1, 2), Vector2i(5, 2), Vector2i(2, 5), Vector2i(4, 5)]
	for i in spots.size():
		var s: Vector2i = spots[i]
		var h := 6 + (i * 3) % 3
		for y in h:
			g.put(Vector3i(s.x, y, s.y), _c(Color("7a9a6a"), s.x, y, s.y), VoxelMat.GRASS)
		for y in range(h, h + 4):
			var pc := Color("8a6ad0") if (y + i) % 2 == 0 else Color("a88ae0")
			g.put(Vector3i(s.x, y, s.y), _c(pc, s.x, y, s.y, 0.05), VoxelMat.FLOWER)
	return g


## Sunflower: a tall stem with two leaves and a big head facing south (+z).
static func _sunflower() -> VoxelGrid:
	var g := _grid(7, 19, 5)
	for y in 14:
		g.put(Vector3i(3, y, 2), _c(Color("4a8a34"), 3, y, 2), VoxelMat.GRASS)
	for p in [
		Vector3i(2, 5, 2),
		Vector3i(1, 5, 2),
		Vector3i(1, 6, 2),
		Vector3i(4, 9, 2),
		Vector3i(5, 9, 2)
	]:
		g.put(p, Color("5f9a42"), VoxelMat.GRASS)
	g.put(Vector3i(5, 10, 2), Color("5f9a42"), VoxelMat.GRASS)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) == 2 and absi(dy) == 2:
				continue
			var ring := absi(dx) == 2 or absi(dy) == 2
			var c := Color("f6c82a") if ring else Color("6a4022")
			if not ring and dx == 0 and dy == 0:
				c = Color("4a2a16")
			g.put(Vector3i(3 + dx, 15 + dy, 3), _c(c, dx, dy, 3, 0.05), VoxelMat.FLOWER)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			g.put(Vector3i(3 + dx, 15 + dy, 2), Color("4f8a30"), VoxelMat.GRASS)
	return g


## Poppy: a thin stem with a red cup and a dark eye.
static func _poppy() -> VoxelGrid:
	var g := _grid(5, 8, 5)
	for y in 5:
		g.put(Vector3i(2, y, 2), _c(Color("6a9a4a"), 2, y, 0), VoxelMat.GRASS)
	g.put(Vector3i(1, 1, 2), Color("6a9a4a"), VoxelMat.GRASS)
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		g.put(
			Vector3i(2 + o.x, 5, 2 + o.y), _c(Color("e03028"), o.x, 5, o.y, 0.06), VoxelMat.FLOWER
		)
	g.put(Vector3i(2, 5, 2), Color("2a2020"), VoxelMat.FLOWER)
	return g


## Bluebell: an arching stem with three hanging blue bells.
static func _bluebell() -> VoxelGrid:
	var g := _grid(5, 8, 5)
	for y in 6:
		g.put(Vector3i(2, y, 2), _c(Color("4f8a3a"), 2, y, 0), VoxelMat.GRASS)
	g.put(Vector3i(3, 6, 2), Color("4f8a3a"), VoxelMat.GRASS)
	for p in [Vector3i(3, 5, 2), Vector3i(1, 4, 2), Vector3i(2, 3, 3), Vector3i(4, 5, 2)]:
		g.put(p, _c(Color("5a6ad8"), p.x, p.y, p.z, 0.08), VoxelMat.FLOWER)
	g.put(Vector3i(1, 5, 2), Color("4f8a3a"), VoxelMat.GRASS)
	for p in [Vector3i(1, 0, 1), Vector3i(3, 0, 3), Vector3i(1, 1, 1)]:
		g.put(p, Color("5f9a42"), VoxelMat.GRASS)
	return g


## Forget-me-not: a low clump strewn with tiny blue flowers.
static func _forget_me_not() -> VoxelGrid:
	var g := _grid(6, 3, 6)
	for z in 6:
		for x in 6:
			if Vector2(x - 2.5, z - 2.5).length() > 2.6:
				continue
			g.put(Vector3i(x, 0, z), _c(Color("4a8a3a"), x, 0, z, 0.1), VoxelMat.GRASS)
			var h := VoxelGrid.hash01(x, 1, z, 96)
			if h < 0.35:
				var fc := Color("6a9ae8") if h > 0.05 else Color("f8f4ee")
				g.put(Vector3i(x, 1, z), fc, VoxelMat.FLOWER)
			elif h < 0.6:
				g.put(Vector3i(x, 1, z), Color("5a9a42"), VoxelMat.GRASS)
	return g


## Marigold: a bushy orange pompom.
static func _marigold() -> VoxelGrid:
	var g := _grid(5, 6, 5)
	for y in 2:
		g.put(Vector3i(2, y, 2), Color("4a8a34"), VoxelMat.GRASS)
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		g.put(Vector3i(2 + o.x * 2, 1, 2 + o.y * 2), Color("5f9a42"), VoxelMat.GRASS)
	for y in [2, 3]:
		for z in range(1, 4):
			for x in range(1, 4):
				if y == 3 and (x != 2 and z != 2):
					continue
				var c := Color("f08a1a") if (x + z + y) % 2 == 0 else Color("f6a830")
				g.put(Vector3i(x, y, z), c, VoxelMat.FLOWER)
	g.put(Vector3i(2, 4, 2), Color("d86a10"), VoxelMat.FLOWER)
	return g


## Rose: a small dark-green bush with red and pink blooms on top.
static func _rose() -> VoxelGrid:
	var g := _grid(6, 6, 6)
	for y in 5:
		for z in 6:
			for x in 6:
				var dd := Vector3(x - 2.5, (y - 2.0) * 1.2, z - 2.5).length()
				if dd > 2.7 + (VoxelGrid.hash01(x, y, z, 97) - 0.5) * 0.6:
					continue
				var c := Color("2f6a2c") if dd < 1.8 else Color("3d7a30")
				g.put(Vector3i(x, y, z), _c(c, x, y, z, 0.08), VoxelMat.LEAVES)
	for z in 6:
		for x in 6:
			for y in range(4, -1, -1):
				if g.solid(Vector3i(x, y, z)):
					if VoxelGrid.hash01(x, y, z, 98) < 0.3:
						var rc := Color("d8283a") if (x + z) % 3 != 0 else Color("f0607a")
						g.put(Vector3i(x, y + 1 if y < 4 else y, z), rc, VoxelMat.FLOWER)
					break
	return g


## Iris: sword leaves and a violet flower (pond banks).
static func _iris() -> VoxelGrid:
	var g := _grid(5, 12, 5)
	for k in 3:
		var p: Vector2i = [Vector2i(2, 2), Vector2i(1, 2), Vector2i(3, 3)][k]
		var h := 8 - k * 2
		for y in h:
			var dx := 1 if (k == 1 and y > h - 3) else 0
			g.put(
				Vector3i(p.x - dx, y, p.y),
				_c(Color("4a8a4a").lerp(Color("6aa25a"), float(y) / h), p.x, y, p.y),
				VoxelMat.GRASS
			)
	for p in [Vector3i(2, 8, 2), Vector3i(1, 9, 2), Vector3i(3, 9, 2), Vector3i(2, 9, 1)]:
		g.put(p, Color("6a4ac8"), VoxelMat.FLOWER)
	g.put(Vector3i(2, 10, 2), Color("8a6ae0"), VoxelMat.FLOWER)
	g.put(Vector3i(2, 9, 3), Color("f2c83a"), VoxelMat.FLOWER)
	return g


## Underwater weed: wavy strands (variants 0 / 1) or a broad-leaved clump (2).
static func _weed(v: int) -> VoxelGrid:
	var h := 12 + v * 4
	var g := _grid(6, h + 1, 6)
	var base := Color("2e5a2a") if v != 1 else Color("3a5a24")
	var tip := Color("5a8a3a") if v != 1 else Color("8a9a3a")
	if v == 2:
		for k in 5:
			var a := k * 1.3
			for y in h - 4 - k:
				var x := 3 + roundi(cos(a) * minf(y * 0.3, 2.0))
				var z := 3 + roundi(sin(a) * minf(y * 0.3, 2.0))
				g.put(
					Vector3i(clampi(x, 0, 5), y, clampi(z, 0, 5)),
					_c(base.lerp(tip, float(y) / h), x, y, z),
					VoxelMat.LEAVES
				)
		return g
	for i in 3:
		var s: Vector2i = [Vector2i(2, 2), Vector2i(4, 3), Vector2i(2, 4)][i]
		var hh := h - i * 3
		for y in hh:
			var x := s.x + roundi(sin(y * 0.55 + i * 2.0) * 0.8)
			g.put(
				Vector3i(clampi(x, 0, 5), y, s.y),
				_c(base.lerp(tip, float(y) / hh), x, y, i),
				VoxelMat.LEAVES
			)
	return g


## A flat stepping stone set into the lawn.
static func _flat_stone() -> VoxelGrid:
	var g := _grid(8, 1, 6)
	for z in 6:
		for x in 8:
			if Vector2((x - 3.5) / 4.0, (z - 2.5) / 3.0).length() > 1.0:
				continue
			g.put(Vector3i(x, 0, z), _c(Color("a8a29a"), x >> 1, 0, z >> 1, 0.08), VoxelMat.STONE)
	return g


## Corn: a tall stalk with long leaves, a cob and a tassel.
static func _corn() -> VoxelGrid:
	var g := _grid(7, 27, 7)
	for y in 22:
		g.put(Vector3i(3, y, 3), _c(Color("6a9a3a"), 3, y, 3), VoxelMat.CROP)
	for k in 4:
		var y0 := 6 + k * 4
		var o: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][k]
		for s in range(1, 4):
			g.put(
				Vector3i(3 + o.x * s, y0 - (s >> 1), 3 + o.y * s),
				Color("7aaa44").darkened(0.05 * s),
				VoxelMat.CROP
			)
	for y in range(12, 16):
		g.put(Vector3i(4, y, 3), Color("e8c040") if y < 15 else Color("7a9a44"), VoxelMat.CROP)
	for y in range(22, 25):
		g.put(Vector3i(3, y, 3), Color("d8c070"), VoxelMat.CROP)
	g.put(Vector3i(2, 24, 3), Color("d8c070"), VoxelMat.CROP)
	return g


## Tomato: a cane with the vine climbing it and red fruit.
static func _tomato() -> VoxelGrid:
	var g := _grid(6, 16, 6)
	for y in 15:
		g.put(Vector3i(3, y, 3), Color("a07a4a"), VoxelMat.WOOD)
	for y in range(1, 13):
		for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var p := Vector3i(3 + o.x, y, 3 + o.y)
			var h := VoxelGrid.hash01(p.x, y, p.z, 99)
			if h < 0.5:
				g.put(p, _c(Color("4f8a34"), p.x, y, p.z), VoxelMat.CROP)
			elif h < 0.58 and y < 10:
				g.put(p, Color("d82a1a"), VoxelMat.CROP)
	return g


## Lettuce: a pale-green rosette.
static func _lettuce() -> VoxelGrid:
	var g := _grid(6, 3, 6)
	for y in 3:
		var r := 2.8 - y * 0.9
		for z in 6:
			for x in 6:
				if Vector2(x - 2.5, z - 2.5).length() > r:
					continue
				var c: Color = [Color("6ab04a"), Color("8ac860"), Color("b0e080")][y]
				g.put(Vector3i(x, y, z), _c(c, x, y, z, 0.06), VoxelMat.CROP)
	return g


## Strawberry: a low clump of leaves with red berries and a white flower.
static func _strawberry() -> VoxelGrid:
	var g := _grid(6, 3, 6)
	for z in 6:
		for x in 6:
			var dd := Vector2(x - 2.5, z - 2.5).length()
			if dd > 2.7:
				continue
			var h := VoxelGrid.hash01(x, 0, z, 100)
			if dd > 1.8 and h < 0.3:
				g.put(Vector3i(x, 0, z), Color("e02a3a"), VoxelMat.CROP)
			elif h < 0.85:
				g.put(Vector3i(x, int(dd < 1.5), z), _c(Color("3f8a34"), x, 0, z), VoxelMat.CROP)
	g.put(Vector3i(2, 2, 3), Color("f8f4ee"), VoxelMat.FLOWER)
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
	var shade := {}  # lawn tiles under a town tree (fallen leaves, mushrooms)
	for e in gen.meta.get("tree_list", []):
		var p: Vector3 = e.pos
		var tt := Vector2i(roundi(p.x), roundi(p.z))
		var sp := VoxelTrees.species_of(String(e.model))
		if sp == "cherry":
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					cherry[tt + Vector2i(dx, dz)] = true
		elif sp in ["oak", "apple", "birch"] and d.thing_kind(tt) != "forest":
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if dx * dx + dz * dz <= 5:
						shade[tt + Vector2i(dx, dz)] = sp
	for z in d.size.y:
		for x in d.size.x:
			var t := Vector2i(x, z) + d.origin
			_tile(gen, t, crop_of, cherry)
			if shade.has(t) and d.ground_kind(t) in ["lawn", "meadow"] and not gen.blocks.has(t):
				_under_tree(gen, t, String(shade[t]))
	# Door mats and sign lettering.
	for b in gen.meta.buildings:
		if b.has("door") and String(b.style) != "shed":
			var dt: Vector2i = b.door
			gen.add_decor("doormat", _xf(Vector3(dt.x, 0.0, dt.y + 0.72), 0.0))
	for tx in gen.meta.get("texts", []):
		gen.add_decor("text:" + String(tx.text), Transform3D(Basis(), tx.pos))


## Litter under a town tree: fallen leaves, now and then a mushroom or a windfall apple.
static func _under_tree(gen: VoxelZoneGen, t: Vector2i, sp: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t) ^ 0x1eaf
	var h := rng.randf()
	if h < 0.55:
		_put(gen, t, rng, "leaves", rng.randf_range(0.8, 1.2))
	if h < 0.12:
		_put(gen, t, rng, "mushroom_brown" if h < 0.09 else "mushroom_red", 0.8)
	if sp == "apple" and h > 0.7:
		_put(gen, t, rng, "windfall")


static func _tile(gen: VoxelZoneGen, t: Vector2i, crop_of: Dictionary, cherry: Dictionary) -> void:
	var d := gen.d
	var kind := d.ground_kind(t)
	var th := d.thing_kind(t)
	var h0 := VoxelGrid.hash01(t.x, 30, t.y, 93)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(t) ^ 0x5eed
	if th == "crop":
		_crops(gen, t, String(crop_of.get(t, "cabbage")), rng)
		return
	if th != "" and th != "forest":
		if th in ["fence", "hedge", "lamp", "bench", "pillar"] and kind in ["lawn", "meadow"]:
			_tufts(gen, t, rng, 1, "tuft_0")
			if th == "fence" and h0 < 0.3:
				_put(gen, t, rng, "sunflower" if h0 < 0.12 else "grass_clump")
		return
	if gen.blocks.has(t) and th != "forest":
		return
	match kind:
		"lawn":
			var n := 1 + int(h0 * 3.0)
			var by_path := gen.dist_walk(t) == 0 and _next_to(gen, t, ["cobble", "slab", "dirt"])
			if by_path:
				n += 2
				if h0 < 0.35:
					_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
			_tufts(gen, t, rng, n, "")
			if h0 < 0.12:
				_put(gen, t, rng, "clover")
			elif h0 > 0.9:
				_put(gen, t, rng, "daisy")
			elif h0 > 0.8:
				_put(gen, t, rng, WILD[rng.randi() % WILD.size()])
			elif h0 > 0.76:
				_put(gen, t, rng, _patch_flower(gen, t))
			if h0 > 0.45 and h0 < 0.5:
				_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
		"meadow":
			for i in 4 + int(h0 * 3.0):
				var m: String = (
					"tuft_tall"
					if rng.randf() < 0.55
					else ("tuft_dry" if rng.randf() < 0.3 else "tuft_1")
				)
				_put(gen, t, rng, m, rng.randf_range(0.8, 1.25))
			if h0 < 0.55:
				_put(gen, t, rng, WILD[int(h0 * 97.0) % WILD.size()])
			if h0 < 0.2:
				_put(gen, t, rng, WILD[int(h0 * 53.0) % WILD.size()])
			if h0 > 0.85:
				_put(gen, t, rng, "grass_clump")
			if h0 > 0.95:
				_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
		"flowers":
			if h0 < 0.4:
				gen.meta.get_or_add("butterflies", []).append(Vector3(t.x, 0.55, t.y))
			var main := _patch_flower(gen, t)
			var n := 6 + int(h0 * 4.0)
			if main == "rose" or main == "lavender":
				n = 3 + int(h0 * 2.0)
			for i in n:
				var m := (
					main if rng.randf() < 0.75 else String(FLOWERS[rng.randi() % FLOWERS.size()])
				)
				var p := _spot(gen, t, rng.randf_range(0.08, 0.92), rng.randf_range(0.08, 0.92))
				gen.add_decor(m, _xf(p, rng.randf() * TAU, rng.randf_range(0.85, 1.2)))
			_tufts(gen, t, rng, 2, "tuft_2")
			if _next_to_thing(gen, t, ["fence", "hedge"]) and h0 < 0.25:
				_put(gen, t, rng, "sunflower")
		"forest_floor":
			var near := gen.dist_walk(t) <= 6
			if not near and h0 > 0.45:
				return
			if h0 < 0.35:
				_put(gen, t, rng, "fern_%d" % (rng.randi() % 2), rng.randf_range(0.8, 1.3))
			if h0 > 0.92:
				_put(gen, t, rng, "mushroom_red" if h0 > 0.97 else "mushroom_brown")
			if h0 > 0.4 and h0 < 0.7:
				_put(gen, t, rng, "leaves")
			if near and h0 > 0.35 and h0 < 0.42:
				_put(gen, t, rng, "bluebell")
				_put(gen, t, rng, "bluebell")
			_tufts(gen, t, rng, 1, "tuft_dark")
		"sand":
			if h0 < 0.45:
				_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
			if h0 < 0.15:
				_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
			if h0 > 0.93:
				_put(gen, t, rng, "shell")
			if _next_to(gen, t, ["lawn", "meadow"]):
				_tufts(gen, t, rng, 1, "tuft_dry")
			if _next_to(gen, t, ["shallow"]) and h0 > 0.6 and h0 < 0.75:
				_put(gen, t, rng, "iris")
		"dirt", "soil":
			if h0 < 0.3:
				_put(gen, t, rng, "pebble_%d" % (rng.randi() % 5))
			if _next_to(gen, t, ["lawn", "meadow"]) and h0 > 0.5:
				_tufts(gen, t, rng, 1, "tuft_0")
		"cobble", "slab":
			if h0 < 0.05 and _next_to(gen, t, ["lawn", "meadow", "flowers"]):
				_tufts(gen, t, rng, 1, "tuft_0")
		"shallow", "deep":
			_water_tile(gen, t, kind, h0, rng)
	if cherry.has(t) and kind in ["lawn", "slab", "cobble", "meadow", "flowers"]:
		for i in 2:
			_put(gen, t, rng, "petals")


## Reeds and irises along the shallow shore, lily pads on open water, weeds on the deeper bed.
static func _water_tile(
	gen: VoxelZoneGen, t: Vector2i, kind: String, h0: float, rng: RandomNumberGenerator
) -> void:
	var shore := _next_to(gen, t, ["lawn", "meadow", "sand", "forest_floor", "flowers"])
	var w := gen.water_at(t.x, t.y)
	var lvl := float(w.get("level", VoxelZoneGen.WATER_Y))
	var stream := String(w.get("type", "pond")) == "stream"
	if shore and kind == "shallow" and h0 < 0.55:
		for i in 2 + int(h0 * 4.0):
			_put(gen, t, rng, "reed_%d" % (rng.randi() % 2), rng.randf_range(0.85, 1.2))
		if h0 < 0.12:
			_put(gen, t, rng, "iris")
		return
	if not shore and not stream and h0 > 0.8:
		var lp := Vector3(
			t.x + rng.randf_range(-0.3, 0.3), lvl + 0.005, t.y + rng.randf_range(-0.3, 0.3)
		)
		gen.add_decor(
			"lily_%d" % (1 if h0 > 0.93 else 0),
			_xf(lp, rng.randf() * TAU, rng.randf_range(0.9, 1.3))
		)
	if h0 > 0.15 and h0 < 0.6:
		for i in 1 + int(h0 * 3.0):
			var p := _spot(gen, t, rng.randf(), rng.randf())
			var depth := lvl - p.y
			if depth < 0.3:
				continue
			var m: String = WEEDS[rng.randi() % WEEDS.size()]
			var sc := clampf(depth / 1.3, 0.35, 1.0) * rng.randf_range(0.8, 1.05)
			gen.add_decor(m, _xf(p, rng.randf() * TAU, sc))


## Crop plants of a 'c' tile: rows of two or four per tile, at the growth stage of the tile's row
## (CROP_STAGES: 0 seedlings, 1 young, 2 ripe), so each bed shows plants at different ages.
static func _crops(
	gen: VoxelZoneGen, t: Vector2i, crop: String, rng: RandomNumberGenerator
) -> void:
	var stages: Array = CROP_STAGES.get(crop, [2, 2])
	var stage := int(stages[posmod(t.y, stages.size())])
	if stage == 0:
		for i in 6:
			var u := 0.2 + 0.3 * (i % 3) + rng.randf_range(-0.04, 0.04)
			var v := 0.3 + 0.4 * (i / 3)
			gen.add_decor(
				"sprout", _xf(_spot(gen, t, u, v), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
			)
		return
	var n := 2 if crop in ["pumpkin", "cabbage", "tomato"] else 4
	var sc := rng.randf_range(0.5, 0.62) if stage == 1 else 1.0
	for i in n:
		var u := 0.25 + 0.5 * (i % 2)
		var v := 0.25 + 0.5 * (i / 2) if n == 4 else 0.3 + 0.4 * i
		if n == 2:
			u = 0.5
		gen.add_decor(
			crop, _xf(_spot(gen, t, u, v), rng.randf() * TAU, sc * rng.randf_range(0.9, 1.15))
		)


## One instance of model m at a random spot of tile t (random yaw, scale s).
static func _put(
	gen: VoxelZoneGen, t: Vector2i, rng: RandomNumberGenerator, m: String, s := 1.0
) -> void:
	gen.add_decor(m, _xf(_spot(gen, t, rng.randf(), rng.randf()), rng.randf() * TAU, s))


static func _next_to_thing(gen: VoxelZoneGen, t: Vector2i, kinds: Array) -> bool:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if gen.d.thing_kind(t + o) in kinds:
			return true
	return false


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
