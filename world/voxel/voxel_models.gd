class_name VoxelModels
extends RefCounted
## Prop models of the voxel zones: street furniture built once into its own small VoxelGrid at the
## prop scale (PROP_VS = 1/8 m, half the world lattice, so a lamp post or a bench slat is not a
## 25 cm beam) and instanced like the trees (VoxelZoneBake: one volume + greedy mesh per model,
## MultiMesh per chunk, tall props one by one so the camera fader can see through them). They use
## the full voxel shader: AO, bevels, night glow (LAMP / WINDOW voxels), rain and snow.
## Models stand on their base centre: voxel (0, y, 0) is centred on the model origin in x / z
## (the instance is offset by half a voxel, see pivot()), y 0 sits on the ground. Front = +z.

const PROP_VS := 0.125
const WOOD_FENCE := Color("9a7a58")
const IRON := Color("2b3530")  ## dark bottle-green cast iron
const IRON_LIGHT := Color("4a5a50")
const GLASS_WARM := Color("f2dba4")
const BRASS := Color("c8a050")

## model -> [light offset from the base centre (m, model frame; just under the lantern so the
## light is never inside its own glass), colour, energy, range] for models that carry a light.
const LIGHTS := {
	"prop_lamp": [Vector3(0, 2.05, 0.22), Color(1.0, 0.8, 0.52), 3.2, 9.0],
	"prop_lamp_double": [Vector3(0, 1.6, 0.25), Color(1.0, 0.8, 0.52), 3.8, 10.0],
	"prop_lantern_post": [Vector3(0.25, 0.78, 0), Color(1.0, 0.74, 0.44), 1.8, 6.0],
	"prop_lantern": [Vector3(0, 0.36, 0.42), Color(1.0, 0.8, 0.52), 2.6, 8.0],
	"prop_wall_lantern": [Vector3(0, 0.55, 0.72), Color(1.0, 0.76, 0.48), 2.2, 6.5],
	"prop_wall_lamp_lab": [Vector3(0, 0.3, 0.5), Color(0.9, 0.92, 1.0), 2.4, 7.0],
}
const GUTTER := Color("5d5c62")
const COPPER := Color("9a6a48")
## Models drawn one instance per node so the camera fader can see through them (tall props).
const TALL := [
	"prop_lamp", "prop_lamp_double", "prop_lantern_post", "prop_laundry_post", "prop_arch"
]


static func names() -> PackedStringArray:
	return PackedStringArray(
		[
			"prop_lamp",
			"prop_lamp_double",
			"prop_lantern_post",
			"prop_lantern",
			"prop_bench",
			"prop_mailbox_red",
			"prop_mailbox_blue",
			"prop_signpost",
			"prop_barrel",
			"prop_barrel_water",
			"prop_crate",
			"prop_crates",
			"prop_hay",
			"prop_wheelbarrow",
			"prop_fence_post",
			"prop_fence_rail",
			"prop_gate_leaf",
			"prop_laundry_post",
			"prop_tool_rack",
			"prop_firewood",
			"prop_arch",
			"prop_gutter",
			"prop_nozzle",
			"prop_wall_lantern",
			"prop_wall_lamp_lab",
		]
	)


static func is_prop(model: String) -> bool:
	return model.begins_with("prop_")


## Model-space offset that centres voxel column (0, 0) on the instance origin.
static func pivot() -> Vector3:
	return Vector3(PROP_VS * 0.5, 0.0, PROP_VS * 0.5)


## Instance transform for a prop standing at metre point p, turned by `rot` quarter turns.
static func xform(p: Vector3, rot: int) -> Transform3D:
	var b := Basis(Vector3.UP, rot * PI * 0.5)
	return Transform3D(b, p - b * pivot())


static func build(model: String) -> VoxelGrid:
	match model:
		"prop_lamp":
			return _lamp(false)
		"prop_lamp_double":
			return _lamp(true)
		"prop_lantern_post":
			return _lantern_post()
		"prop_lantern":
			var lg := _grid(2, 9)
			_lantern(lg, Vector3i(0, 0, 0))
			return lg
		"prop_bench":
			return _bench()
		"prop_mailbox_red":
			return _mailbox(Color("c63a2a"))
		"prop_mailbox_blue":
			return _mailbox(Color("3a62a8"))
		"prop_signpost":
			return _signpost()
		"prop_barrel":
			return _barrel(false)
		"prop_barrel_water":
			return _barrel(true)
		"prop_crate":
			return _crates(false)
		"prop_crates":
			return _crates(true)
		"prop_hay":
			return _hay()
		"prop_wheelbarrow":
			return _wheelbarrow()
		"prop_fence_post":
			return _fence_post()
		"prop_fence_rail":
			return _fence_rail()
		"prop_gate_leaf":
			return _gate_leaf()
		"prop_laundry_post":
			return _laundry_post()
		"prop_tool_rack":
			return _tool_rack()
		"prop_firewood":
			return _firewood()
		"prop_arch":
			return _arch()
		"prop_gutter":
			return _gutter()
		"prop_nozzle":
			return _nozzle()
		"prop_wall_lantern":
			return _wall_lantern()
		"prop_wall_lamp_lab":
			return _wall_lamp_lab()
	if model.begins_with("prop_downpipe_"):
		return _downpipe(int(model.get_slice("_", 2)))
	return _crates(false)


static func _grid(r: int, h: int) -> VoxelGrid:
	return VoxelGrid.new(Vector3i(-r, 0, -r), Vector3i(2 * r + 1, h, 2 * r + 1))


static func _v(c: Color, x: int, y: int, z: int, amt := 0.05, salt := 0) -> Color:
	return VoxelPal.vary(c, VoxelGrid.hash01(x, y, z, 200 + salt), amt)


static func _box(
	g: VoxelGrid, a: Vector3i, b: Vector3i, c: Color, m: int, amt := 0.04, salt := 0
) -> void:
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				g.put(Vector3i(x, y, z), _v(c, x, y, z, amt, salt), m)


# --- lights ----------------------------------------------------------------------------------------


## Street lamp (3.1 m): a stone foot, a slim iron post with a collar, and a lantern whose warm glass
## core (glowing at night) sits between four thin corner posts under a pyramid cap and finial.
## `double`: a taller post with a crossbar carrying two lanterns (plaza).
static func _lamp(double: bool) -> VoxelGrid:
	var g := _grid(5 if double else 2, 30)
	var stone := Color("8a847c")
	_box(g, Vector3i(-1, 0, -1), Vector3i(1, 0, 1), stone, VoxelMat.STONE, 0.05)
	_box(g, Vector3i(-1, 1, -1), Vector3i(1, 1, 1), IRON, VoxelMat.METAL, 0.03)
	var top := 21 if double else 16
	for y in range(2, top + 1):
		g.put(Vector3i(0, y, 0), _v(IRON, 0, y, 0, 0.03), VoxelMat.METAL)
	# A slim collar: a cross of four studs around the post.
	for d: Vector3i in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]:
		g.put(Vector3i(0, 7, 0) + d, IRON_LIGHT, VoxelMat.METAL)
	if not double:
		_lantern(g, Vector3i(0, 17, 0))
		return g
	# Crossbar with scrolls and two hanging lanterns.
	for x in range(-4, 5):
		g.put(Vector3i(x, 21, 0), _v(IRON, x, 21, 0, 0.03), VoxelMat.METAL)
	for x in [-2, 2]:
		g.put(Vector3i(x, 20, 0), IRON, VoxelMat.METAL)
	_box(g, Vector3i(0, 22, 0), Vector3i(0, 23, 0), IRON, VoxelMat.METAL)
	for x in [-4, 4]:
		g.put(Vector3i(x, 20, 0), IRON, VoxelMat.METAL)
		_lantern(g, Vector3i(x, 14, 0), true)
	return g


## A lantern whose base plate is at y0: plate, a 3 x 4 x 3 glass body between four corner posts,
## a cap with a brass finial (`small`: one voxel shorter, hung from a hook up to the bar at y 21).
static func _lantern(g: VoxelGrid, o: Vector3i, small := false) -> void:
	var gh := 3 if small else 4
	_box(g, o + Vector3i(-1, 0, -1), o + Vector3i(1, 0, 1), IRON, VoxelMat.METAL, 0.03)
	g.put(o + Vector3i(0, -1, 0), IRON_LIGHT, VoxelMat.METAL)
	for y in range(1, gh + 1):
		for z in range(-1, 2):
			for x in range(-1, 2):
				var p := o + Vector3i(x, y, z)
				if x != 0 and z != 0:
					g.put(p, IRON, VoxelMat.METAL)
				else:
					g.put(p, _v(GLASS_WARM, p.x, p.y, p.z, 0.03), VoxelMat.LAMP)
	var cy := o.y + gh + 1
	_box(
		g,
		Vector3i(o.x - 1, cy, o.z - 1),
		Vector3i(o.x + 1, cy, o.z + 1),
		IRON,
		VoxelMat.METAL,
		0.03
	)
	for d in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]:
		g.put(Vector3i(o.x, cy, o.z) + d, IRON_LIGHT, VoxelMat.METAL)
	g.put(Vector3i(o.x, cy + 1, o.z), IRON, VoxelMat.METAL)
	if not small:
		g.put(Vector3i(o.x, cy + 2, o.z), BRASS, VoxelMat.METAL)
		return
	# Hook up to the bar.
	for y in range(cy + 2, 21):
		g.put(Vector3i(o.x, y, o.z), IRON, VoxelMat.METAL)


## Dock lantern post (1.6 m): a weathered timber post, a bracket and a small hanging lantern.
static func _lantern_post() -> VoxelGrid:
	var g := _grid(3, 14)
	var wood := Color("6a5038")
	for y in 13:
		g.put(Vector3i(0, y, 0), _v(wood, 0, y, 0, 0.08, 3), VoxelMat.WOOD)
	for x in range(0, 3):
		g.put(Vector3i(x, 13, 0), _v(wood.darkened(0.15), x, 13, 0, 0.05), VoxelMat.WOOD)
	g.put(Vector3i(1, 12, 0), wood.darkened(0.15), VoxelMat.WOOD)
	g.put(Vector3i(2, 12, 0), IRON, VoxelMat.METAL)
	_box(g, Vector3i(1, 7, -1), Vector3i(3, 7, 1), IRON, VoxelMat.METAL, 0.03)
	for y in range(8, 11):
		for z in range(-1, 2):
			for x in range(1, 4):
				var corner := x != 2 and z != 0
				g.put(
					Vector3i(x, y, z),
					IRON if corner else _v(GLASS_WARM, x, y, z, 0.03),
					VoxelMat.METAL if corner else VoxelMat.LAMP
				)
	_box(g, Vector3i(1, 11, -1), Vector3i(3, 11, 1), IRON, VoxelMat.METAL, 0.03)
	# A coil of rope at the foot.
	for p in [Vector3i(-1, 0, 1), Vector3i(-2, 0, 1), Vector3i(-2, 0, 0), Vector3i(-1, 1, 1)]:
		g.put(p, Color("c8b48a"), VoxelMat.CLOTH)
	return g


# --- furniture -------------------------------------------------------------------------------------


## Park bench facing +z: cast-iron ends with armrests, five seat slats, a two-slat backrest.
static func _bench() -> VoxelGrid:
	var g := _grid(4, 8)
	var wood := Color("b07a48")
	for x in [-4, 4]:
		for z in [-2, 1]:
			for y in 3:
				g.put(Vector3i(x, y, z), IRON, VoxelMat.METAL)
		for z in range(-2, 2):
			g.put(Vector3i(x, 3, z), IRON, VoxelMat.METAL)
		for y in range(4, 8):
			g.put(Vector3i(x, y, -2), IRON, VoxelMat.METAL)
		g.put(Vector3i(x, 5, 0), IRON_LIGHT, VoxelMat.METAL)
		g.put(Vector3i(x, 5, 1), IRON_LIGHT, VoxelMat.METAL)
		g.put(Vector3i(x, 4, 1), IRON, VoxelMat.METAL)
	for x in range(-3, 4):
		for z in range(-2, 2):
			var c := wood if (z % 2 == 0) else wood.darkened(0.1)
			g.put(Vector3i(x, 3, z), _v(c, x, 3, z, 0.05), VoxelMat.WOOD)
		for y in [5, 7]:
			g.put(Vector3i(x, y, -2), _v(wood.darkened(0.04), x, y, -2, 0.05), VoxelMat.WOOD)
		g.put(Vector3i(x, 6, -2), _v(wood.darkened(0.25), x, 6, -2, 0.04), VoxelMat.WOOD)
	return g


## Mailbox on a post (1.4 m): a painted box with an arched lid, a slot, the raised flag.
static func _mailbox(col: Color) -> VoxelGrid:
	var g := _grid(3, 12)
	var post := Color("6a4a30")
	for y in 7:
		g.put(Vector3i(0, y, 0), _v(post, 0, y, 0, 0.06), VoxelMat.WOOD)
	_box(g, Vector3i(-1, 6, -1), Vector3i(1, 6, 1), post.darkened(0.15), VoxelMat.WOOD)
	for z in range(-2, 3):
		for y in range(7, 10):
			for x in range(-1, 2):
				var c := col
				if z == 2 and y >= 8 and x == 0:
					c = col.darkened(0.45)
				g.put(Vector3i(x, y, z), _v(c, x, y, z, 0.03), VoxelMat.PAINT)
		g.put(Vector3i(0, 10, z), _v(col.lightened(0.08), 0, 10, z, 0.03), VoxelMat.PAINT)
	g.put(Vector3i(0, 9, 3), Color("d8c070"), VoxelMat.METAL)
	for y in range(8, 11):
		g.put(Vector3i(2, y, -1), IRON, VoxelMat.METAL)
	g.put(Vector3i(2, 11, -1), Color("f0c830"), VoxelMat.PAINT)
	g.put(Vector3i(2, 11, 0), Color("f0c830"), VoxelMat.PAINT)
	g.put(Vector3i(2, 10, 0), Color("e0b020"), VoxelMat.PAINT)
	return g


## Wooden sign (1.4 m): two posts, a framed board with painted lines of text, a small roof.
static func _signpost() -> VoxelGrid:
	var g := _grid(5, 12)
	var post := Color("5e4430")
	var board := Color("c8a678")
	for x in [-4, 4]:
		for y in 10:
			g.put(Vector3i(x, y, 0), _v(post, x, y, 0, 0.06), VoxelMat.WOOD)
	for y in range(4, 10):
		for x in range(-4, 5):
			var edge := x == -4 or x == 4 or y == 4 or y == 9
			var c := post.lightened(0.05) if edge else board
			if not edge and (y == 7 or y == 6) and x > -3 and x < 3 - (1 if y == 6 else 0):
				c = Color("4a3426")
			g.put(Vector3i(x, y, 0), _v(c, x, y, 0, 0.04, 1), VoxelMat.WOOD)
	for x in range(-5, 6):
		for z in range(-1, 2):
			g.put(Vector3i(x, 10, z), _v(Color("8a4a2c"), x, 10, z, 0.05, 2), VoxelMat.ROOF)
		g.put(Vector3i(x, 11, 0), _v(Color("6e3a22"), x, 11, 0, 0.05, 2), VoxelMat.ROOF)
	return g


## Barrel (0.85 m): staves with a bulge, two iron hoops, a planked lid or rain water.
static func _barrel(water: bool) -> VoxelGrid:
	var g := _grid(3, 8)
	var wood := Color("8e5c36")
	for y in 7:
		var r := 2.9
		if y == 0 or y == 6:
			r = 2.1
		elif y == 1 or y == 5:
			r = 2.6
		for z in range(-3, 4):
			for x in range(-3, 4):
				var d := Vector2(x, z).length()
				if d > r:
					continue
				var c := _v(wood, int(atan2(z, x) * 3.0), 0, 0, 0.12, 4)
				var m := VoxelMat.WOOD
				if y == 1 or y == 5:
					c = Color("3e3a38")
					m = VoxelMat.METAL
				if y == 6 and d < r - 0.9:
					if water:
						c = Color("2c4a56")
						m = VoxelMat.GLASS
					else:
						c = _v(wood.lightened(0.12), x, 6, 0, 0.06, 5)
				g.put(Vector3i(x, y, z), c, m)
	return g


## Crate (0.5 m): dark frame, plank faces with a diagonal brace; `stack`: two crates and one on top.
static func _crates(stack: bool) -> VoxelGrid:
	var g := _grid(4, 9)
	if not stack:
		_crate(g, Vector3i(-2, 0, -2), 4)
		return g
	_crate(g, Vector3i(-4, 0, -2), 4)
	_crate(g, Vector3i(0, 0, -1), 4)
	_crate(g, Vector3i(-2, 4, -1), 3)
	return g


static func _crate(g: VoxelGrid, a: Vector3i, n: int) -> void:
	for y in n:
		for z in n:
			for x in n:
				var ex := x == 0 or x == n - 1
				var ey := y == 0 or y == n - 1
				var ez := z == 0 or z == n - 1
				var edges := int(ex) + int(ey) + int(ez)
				var c := Color("b08a62")
				if edges >= 2:
					c = Color("6e4630")
				elif (ex and y == z) or (ez and x == y):
					c = Color("8a5e3e")
				g.put(
					a + Vector3i(x, y, z), _v(c, a.x + x, a.y + y, a.z + z, 0.04, 6), VoxelMat.WOOD
				)


## Hay bale (0.5 x 0.5 x 0.9 m) tied with two strings, a few loose straws on top.
static func _hay() -> VoxelGrid:
	var g := _grid(4, 5)
	var hay := Color("e0c066")
	for y in 4:
		for z in range(-2, 2):
			for x in range(-3, 4):
				var c := hay.darkened(0.12) if (y + x) % 3 == 0 else hay
				if x == -2 or x == 2:
					c = Color("a8763a")
				g.put(Vector3i(x, y, z), _v(c, x, y, z, 0.07, 7), VoxelMat.HAY)
	g.put(Vector3i(-1, 4, 0), hay.lightened(0.1), VoxelMat.HAY)
	g.put(Vector3i(1, 4, -1), hay.lightened(0.05), VoxelMat.HAY)
	return g


## Wheelbarrow (1.1 m long, front +z): a tilted tray, one wheel, legs and two handles.
static func _wheelbarrow() -> VoxelGrid:
	var g := _grid(4, 6)
	var tray := Color("4f7a6a")
	for z in range(-2, 3):
		for x in range(-2, 3):
			var wall := absi(x) == 2 or z == -2 or z == 2
			var y := 2
			g.put(Vector3i(x, y, z), _v(tray.darkened(0.1), x, y, z, 0.04), VoxelMat.METAL)
			if wall:
				g.put(Vector3i(x, 3, z), _v(tray, x, 3, z, 0.04), VoxelMat.METAL)
	# Soil in the tray.
	for z in range(-1, 2):
		for x in range(-1, 2):
			g.put(Vector3i(x, 3, z), _v(VoxelPal.SOIL, x, 3, z, 0.08), VoxelMat.DIRT)
	for y in range(0, 3):
		g.put(Vector3i(0, y, 3), Color("2a2828"), VoxelMat.METAL)
	g.put(Vector3i(0, 1, 4), Color("2a2828"), VoxelMat.METAL)
	g.put(Vector3i(0, 1, 2), Color("2a2828"), VoxelMat.METAL)
	for x in [-2, 2]:
		g.put(Vector3i(x, 0, -2), Color("3a3634"), VoxelMat.METAL)
		g.put(Vector3i(x, 1, -2), Color("3a3634"), VoxelMat.METAL)
		for z in range(-4, -2):
			g.put(Vector3i(x, 3, z), Color("8a6440"), VoxelMat.WOOD)
	return g


# --- fences and yard -------------------------------------------------------------------------------


## Fence post at a tile centre (0.9 m) with a cap; rails come as separate models.
static func _fence_post() -> VoxelGrid:
	var g := _grid(0, 8)
	for y in 7:
		g.put(Vector3i(0, y, 0), _v(WOOD_FENCE.darkened(0.15), 0, y, 0, 0.06, 8), VoxelMat.WOOD)
	g.put(Vector3i(0, 7, 0), WOOD_FENCE.darkened(0.3), VoxelMat.WOOD)
	return g


## Two split rails from a post to the next tile's post (1 m along +x; turned for the z rails).
static func _fence_rail() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(1, 0, 0), Vector3i(7, 7, 1))
	for x in range(1, 8):
		for y in [2, 5]:
			var sag := 1 if (y == 5 and x >= 3 and x <= 5) else 0
			g.put(Vector3i(x, y - sag, 0), _v(WOOD_FENCE, x, y, 0, 0.08, 9), VoxelMat.WOOD)
	return g


## An open garden gate leaf (0.9 m wide) hinged at x 0, swung along +x.
static func _gate_leaf() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(0, 0, 0), Vector3i(8, 8, 1))
	var w := WOOD_FENCE.lightened(0.05)
	for x in range(0, 7):
		for y in range(1, 7):
			var frame := y == 1 or y == 6 or x == 0 or x == 6 or x == y
			if frame or x % 2 == 0:
				g.put(
					Vector3i(x, y, 0),
					_v(w if frame else w.darkened(0.08), x, y, 0, 0.05),
					VoxelMat.WOOD
				)
	g.put(Vector3i(0, 4, 0), IRON, VoxelMat.METAL)
	g.put(Vector3i(0, 2, 0), IRON, VoxelMat.METAL)
	return g


## Laundry pole (1.9 m) with a crossbar; the line and the clothes are decor.
static func _laundry_post() -> VoxelGrid:
	var g := _grid(2, 16)
	var wood := Color("7a5a3c")
	for y in 15:
		g.put(Vector3i(0, y, 0), _v(wood, 0, y, 0, 0.06), VoxelMat.WOOD)
	for z in range(-2, 3):
		g.put(Vector3i(0, 15, z), _v(wood.darkened(0.1), 0, 15, z, 0.06), VoxelMat.WOOD)
	return g


## Tool rack against a shed wall (front +z): a board with a rake, a spade and a hoe.
static func _tool_rack() -> VoxelGrid:
	var g := _grid(4, 13)
	var board := Color("7a5236")
	for x in range(-4, 5):
		g.put(Vector3i(x, 10, -1), _v(board, x, 10, 0, 0.06), VoxelMat.WOOD)
	var handle := Color("b08a5a")
	var steel := Color("8a8c90")
	for t in 3:
		var x := -3 + t * 3
		for y in range(2, 11):
			g.put(Vector3i(x, y, 0), _v(handle, x, y, 0, 0.05), VoxelMat.WOOD)
		match t:
			0:  # rake
				for dx in range(-1, 2):
					g.put(Vector3i(x + dx, 1, 0), steel, VoxelMat.METAL)
					g.put(Vector3i(x + dx, 0, 0), steel.darkened(0.2), VoxelMat.METAL)
			1:  # spade
				for y in range(0, 2):
					for dx in range(-1, 2):
						g.put(Vector3i(x + dx, y, 0), steel, VoxelMat.METAL)
			2:  # hoe
				g.put(Vector3i(x, 1, 0), steel, VoxelMat.METAL)
				g.put(Vector3i(x + 1, 1, 0), steel, VoxelMat.METAL)
				g.put(Vector3i(x + 1, 0, 0), steel.darkened(0.2), VoxelMat.METAL)
	return g


## Stacked firewood (0.9 x 0.6 m): log ends facing +z.
static func _firewood() -> VoxelGrid:
	var g := _grid(4, 6)
	for y in 5:
		for x in range(-3, 4):
			if y == 4 and absi(x) > 2:
				continue
			for z in range(-2, 2):
				var end := z == 1
				var ring := (x + y) % 2 == 0
				var c := Color("6a4a30")
				if end:
					c = Color("c8a472") if ring else Color("b08c5c")
				g.put(Vector3i(x, y, z), _v(c, x, y, z, 0.06, 10), VoxelMat.WOOD)
	return g


## Rose arch over a garden gateway (2.6 m, posts 1.75 m apart along x): timber posts and an arched
## top, overgrown with leaves and red and pink roses.
static func _arch() -> VoxelGrid:
	var g := _grid(8, 22)
	var wood := Color("8a6a48")
	var spots: Array[Vector3i] = []
	for x in [-7, 7]:
		for y in 18:
			g.put(Vector3i(x, y, 0), _v(wood, x, y, 0, 0.06), VoxelMat.WOOD)
			spots.append(Vector3i(x, y, 0))
	for x in range(-7, 8):
		var y := 18 + roundi(2.6 * (1.0 - pow(x / 7.0, 2.0)))
		for z in [-1, 0, 1]:
			g.put(Vector3i(x, y, z), _v(wood.darkened(0.08), x, y, z, 0.05), VoxelMat.WOOD)
		spots.append(Vector3i(x, y, 0))
	var leaf := VoxelPal.LEAF.darkened(0.05)
	for sp in spots:
		for o in [
			Vector3i(1, 0, 0),
			Vector3i(-1, 0, 0),
			Vector3i(0, 0, 1),
			Vector3i(0, 0, -1),
			Vector3i(0, 1, 1),
			Vector3i(0, 1, -1),
			Vector3i(0, -1, 1)
		]:
			var q: Vector3i = sp + o
			if g.solid(q) or not g.has(q):
				continue
			var h := VoxelGrid.hash01(q.x, q.y, q.z, 230)
			var grow := 0.25 + clampf(q.y / 22.0, 0.0, 1.0) * 0.5
			if h > grow:
				continue
			var c := _v(leaf if h > grow * 0.4 else VoxelPal.LEAF_LIGHT, q.x, q.y, q.z, 0.08)
			var m := VoxelMat.LEAVES
			if VoxelGrid.hash01(q.x, q.y, q.z, 231) < 0.22:
				c = Color("d8283a") if (q.x + q.y) % 3 != 0 else Color("f27a9a")
				m = VoxelMat.FLOWER
			g.put(q, c, m)
	return g


# --- building furniture ----------------------------------------------------------------------------


## One metre of half-round eaves gutter along x (voxels -4..3, so segments abut), U profile open
## at the top, a bracket at one end. Hung under the eaves edge (VoxelBuild).
static func _gutter() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-4, 0, -1), Vector3i(8, 2, 3))
	for x in range(-4, 4):
		g.put(Vector3i(x, 0, 0), _v(GUTTER, x, 0, 0, 0.03), VoxelMat.METAL)
		for z in [-1, 1]:
			g.put(Vector3i(x, 1, z), _v(GUTTER.lightened(0.08), x, 1, z, 0.03), VoxelMat.METAL)
		g.put(Vector3i(x, 1, 0), Color("3a3c40"), VoxelMat.METAL)
	g.put(Vector3i(-4, 0, -1), IRON, VoxelMat.METAL)
	return g


## Downpipe `h` voxels tall: a swan neck at the top reaching 3 voxels out (+z) into the gutter,
## brackets every metre, and a shoe kicking out at the foot.
static func _downpipe(h: int) -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-1, 0, -1), Vector3i(3, h + 1, 6))
	for y in range(0, h - 3):
		g.put(Vector3i(0, y, 0), _v(GUTTER, 0, y, 0, 0.03), VoxelMat.METAL)
		if y % 8 == 4:
			for x in [-1, 1]:
				g.put(Vector3i(x, y, 0), IRON, VoxelMat.METAL)
			g.put(Vector3i(0, y, -1), IRON, VoxelMat.METAL)
	g.put(Vector3i(0, 0, 1), GUTTER.darkened(0.1), VoxelMat.METAL)
	g.put(Vector3i(0, 0, 2), GUTTER.darkened(0.1), VoxelMat.METAL)
	for z in range(0, 4):
		g.put(Vector3i(0, h - 3 + mini(z, 1), z), _v(GUTTER, 0, h, z, 0.03), VoxelMat.METAL)
	for y in range(h - 2, h + 1):
		g.put(Vector3i(0, y, 3), _v(GUTTER, 0, y, 3, 0.03), VoxelMat.METAL)
	g.put(Vector3i(0, h - 1, 4), GUTTER.lightened(0.1), VoxelMat.METAL)
	g.put(Vector3i(0, h - 1, 2), GUTTER.lightened(0.1), VoxelMat.METAL)
	return g


## Porch lantern on a wall (origin on the wall face, front +z): a back plate, a curled arm and a
## small four-post lantern with warm glass hanging from it.
static func _wall_lantern() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-2, 0, 0), Vector3i(5, 12, 6))
	for y in range(5, 10):
		g.put(Vector3i(0, y, 0), IRON, VoxelMat.METAL)
	g.put(Vector3i(-1, 7, 0), IRON, VoxelMat.METAL)
	g.put(Vector3i(1, 7, 0), IRON, VoxelMat.METAL)
	for z in range(1, 5):
		g.put(Vector3i(0, 9, z), IRON, VoxelMat.METAL)
	g.put(Vector3i(0, 10, 4), IRON, VoxelMat.METAL)
	g.put(Vector3i(0, 8, 3), IRON, VoxelMat.METAL)
	g.put(Vector3i(0, 8, 1), IRON, VoxelMat.METAL)
	_box(g, Vector3i(-1, 7, 2), Vector3i(1, 7, 4), IRON, VoxelMat.METAL, 0.03)
	for y in range(4, 7):
		for z in range(2, 5):
			for x in range(-1, 2):
				var corner := x != 0 and z != 3
				g.put(
					Vector3i(x, y, z),
					IRON if corner else _v(GLASS_WARM, x, y, z, 0.03),
					VoxelMat.METAL if corner else VoxelMat.LAMP
				)
	_box(g, Vector3i(-1, 3, 2), Vector3i(1, 3, 4), IRON, VoxelMat.METAL, 0.03)
	g.put(Vector3i(0, 2, 3), Color("c8a050"), VoxelMat.METAL)
	return g


## The lab's wall lamp: a slim brushed-metal box with a cool white lens facing down and out.
static func _wall_lamp_lab() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-2, 0, 0), Vector3i(5, 6, 4))
	var steel := Color("8c949c")
	_box(g, Vector3i(-2, 2, 0), Vector3i(2, 4, 0), steel, VoxelMat.METAL, 0.02)
	_box(g, Vector3i(-2, 4, 1), Vector3i(2, 4, 2), steel, VoxelMat.METAL, 0.02)
	_box(g, Vector3i(-2, 3, 2), Vector3i(2, 3, 2), steel.darkened(0.2), VoxelMat.METAL, 0.02)
	_box(g, Vector3i(-1, 3, 1), Vector3i(1, 3, 1), Color("f4f6ff"), VoxelMat.LAMP, 0.01)
	return g


## Fountain nozzle on the basin coping (round, so any yaw): a carved stone bud with a brass ring.
static func _nozzle() -> VoxelGrid:
	var g := _grid(2, 4)
	var stone := VoxelPal.SLAB.lightened(0.05)
	for z in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) + absi(z) > 3:
				continue
			g.put(Vector3i(x, 0, z), _v(stone.darkened(0.08), x, 0, z, 0.04), VoxelMat.STONE)
	for z in range(-1, 2):
		for x in range(-1, 2):
			if absi(x) + absi(z) > 1:
				continue
			g.put(Vector3i(x, 1, z), _v(stone, x, 1, z, 0.04), VoxelMat.STONE)
			g.put(Vector3i(x, 2, z), BRASS, VoxelMat.METAL)
	g.put(Vector3i(0, 2, 0), Color("2a3236"), VoxelMat.METAL)
	return g
