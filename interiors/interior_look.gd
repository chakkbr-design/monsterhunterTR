class_name InteriorLook
extends RefCounted
## Original art for the interiors (visual only; InteriorRoom keeps its collision boxes):
## textured floors/walls with the original interior_surface shader (textures/interior/*), and the
## original's Kenney furniture models placed in each furniture box of InteriorDefs, recoloured with
## the original prop_model.gd palette. Like the original scenes (prop_model.gd: one uniform
## model_scale per piece, ~2.2 for Kenney furniture) a model keeps its own proportions: it is scaled
## uniformly (the original's scale, shrunk only to fit the box footprint), turned to lie along the box
## and to face the room, and counters / shelves / benches repeat along long boxes.

const PALETTE := {
	"wood": Color(0.74, 0.54, 0.32),
	"woodDark": Color(0.52, 0.36, 0.22),
	"carpet": Color(0.34, 0.6, 0.45),
	"carpetBlue": Color(0.34, 0.44, 0.68),
	"carpetDarker": Color(0.26, 0.44, 0.36),
	"plant": Color(0.3, 0.58, 0.3),
	"lamp": Color(0.95, 0.88, 0.68),
}
## Furniture name (InteriorDefs, Portuguese) -> [Kenney model, uniform scale, repeat along the box].
## Scales are the original scenes' prop_model.gd model_scale for that model (scenes/interiors/*.tscn);
## 0.0 = stretched to the box (flat rugs, rocks). A list of such entries stacks the pieces (a TV on
## its cabinet); the bottom piece is dropped when the box does not stand on the floor (the PC
## terminal's screen on its desk). [] = drawn by another piece (the bed model has its pillow).
## Unlisted names stay boxes.
const FURNITURE := {
	"Planta": ["furniture/pottedPlant", 2.4],
	"Estante": ["furniture/bookcaseClosedWide", 2.4, true],
	"Mesa": ["furniture/table", 2.4],
	"Rocha": ["nature/rock_largeA", 0.0],
	"Banco": ["furniture/benchCushionLow", 2.2, true],
	"Prateleira": ["furniture/bookcaseOpen", 1.9, true],
	"Carteira": ["furniture/desk", 2.0],
	"Tapete": ["furniture/rugRectangle", 0.0],
	"TV": [["furniture/cabinetTelevision", 2.0], ["furniture/televisionModern", 1.8]],
	"Caixa": ["furniture/cardboardBoxClosed", 2.2],
	"Cadeira": ["furniture/chair", 2.2],
	"Vitrine": ["furniture/tableGlass", 2.0],
	"Travesseiro": [],
	"Escrivaninha": ["furniture/desk", 2.2],
	"Computador": [["furniture/desk", 2.2], ["furniture/computerScreen", 2.2]],
	"Cama": ["furniture/bedSingle", 2.2],
	"Bancada": ["furniture/kitchenBar", 2.2, true],
	"Balcão": ["furniture/kitchenBar", 2.2, true],
	"Sofá": ["furniture/loungeSofa", 2.2],
	"Geladeira": ["furniture/kitchenFridge", 2.2],
	"Fogão": ["furniture/kitchenStove", 2.2],
	"Pia": ["furniture/kitchenSink", 2.2],
	"Lâmpada": ["furniture/lampRoundFloor", 2.2],
}
## Most a repeated piece may be stretched along the box (the original fences stretch the same way).
const MAX_STRETCH := 1.25

static var _surf := {}


## Floor / wall texture for a room id (and the rock rooms of the gym / caves).
static func floor_tex(id: String) -> String:
	if id.contains("pokemon_center"):
		return "textures/interior/floor_center.png"
	if id.contains("mart"):
		return "textures/interior/floor_mart.png"
	if id.contains("lab"):
		return "textures/interior/floor_lab.png"
	if id.contains("gym"):
		return "textures/interior/floor_rock.png"
	if id.contains("moon") or id.contains("cave"):
		return "textures/interior/cave_floor.png"
	if id.contains("museum") or id.contains("gate") or id.contains("school"):
		return "textures/floor_tile.png"
	return "textures/interior/floor_wood.png"


static func wall_tex(id: String) -> String:
	if id.contains("lab"):
		return "textures/interior/wall_lab.png"
	if id.contains("gym"):
		return "textures/interior/wall_rock.png"
	if id.contains("moon") or id.contains("cave"):
		return "textures/interior/cave_wall.png"
	if (
		id.contains("pokemon_center")
		or id.contains("mart")
		or id.contains("museum")
		or id.contains("gate")
	):
		return "textures/wall.png"
	return "textures/interior/wallpaper_cream.png"


## interior_surface material (world-space tiled pixel texture), tinted toward the room's colour.
static func surface(tex_rel: String, tint: Color) -> Material:
	var key := "%s|%s" % [tex_rel, tint]
	if _surf.has(key):
		return _surf[key]
	var tex := WorldFx.tex(tex_rel)
	var m: Material
	if tex:
		m = WorldFx.shader_mat(
			"interior_surface",
			{
				"albedo_tex": tex,
				"use_tex": true,
				"tint": Color.WHITE.lerp(tint, 0.25),
				"tiles_per_meter": 0.5
			}
		)
	else:
		m = MapBuilder.mat(tint)
	_surf[key] = m
	return m


## Kenney model(s) for a furniture entry in the box `size` centred at `center` (parent space): base on
## the box floor, centred in it, uniformly scaled (see FURNITURE). The front (+Z) faces the camera
## (+Z) for pieces along x and the room centre for pieces along z; `face_to` (parent space, e.g. the
## table of a chair) overrides it. null when the name has no model or the model is missing.
static func furniture(
	parent: Node3D,
	fname: String,
	center: Vector3,
	size: Vector3,
	tint: Color,
	face_to := Vector3.INF
) -> Node3D:
	if not FURNITURE.has(fname):
		return null
	var spec: Array = FURNITURE[fname]
	var parts: Array = spec if not spec.is_empty() and spec[0] is Array else [spec]
	var bottom := center.y - size.y / 2.0
	if parts.size() > 1 and bottom > 0.05:
		parts = parts.slice(1)
	var root := Node3D.new()
	root.name = "Model_%s" % fname
	parent.add_child(root)
	if spec.is_empty():
		return root
	var pal := PALETTE.duplicate()
	pal["carpet"] = tint
	var y := bottom
	for part: Array in parts:
		var id := String(part[0])
		if not WorldProps.exists(id):
			root.free()
			return null
		var top := _piece(
			root,
			id,
			float(part[1]),
			part.size() > 2 and bool(part[2]),
			center,
			size,
			y,
			pal,
			face_to
		)
		y = top
	return root


## Places one piece (repeated when `tile`) with its base at height y; returns the height of its top.
static func _piece(
	root: Node3D,
	id: String,
	canon: float,
	tile: bool,
	center: Vector3,
	size: Vector3,
	y: float,
	pal: Dictionary,
	face_to: Vector3
) -> float:
	var lb := MapBuilder.model_box(id)
	if canon <= 0.0:  # stretched to the box (rugs, rocks)
		var inst := WorldProps.place(root, id, root.global_position, {"palette": pal})
		var sc := Vector3(
			size.x / maxf(lb.size.x, 0.001),
			size.y / maxf(lb.size.y, 0.001),
			size.z / maxf(lb.size.z, 0.001)
		)
		inst.scale = sc
		inst.position = (
			Vector3(center.x, y, center.z)
			- Vector3(lb.get_center().x * sc.x, lb.position.y * sc.y, lb.get_center().z * sc.z)
		)
		return y + size.y
	var box_x := size.x >= size.z  # the box lies along x
	var model_x := lb.size.x >= lb.size.z  # the model's long side is its local x
	var rot := 0.0
	if face_to != Vector3.INF:  # the cardinal direction toward face_to
		var to := Vector2(face_to.x - center.x, face_to.z - center.z)
		if absf(to.x) > absf(to.y):
			rot = 90.0 if to.x > 0.0 else -90.0
		else:
			rot = 0.0 if to.y > 0.0 else 180.0
	else:  # long side along the box (square boxes keep the model as it is)
		var square := absf(size.x - size.z) < 0.1 * maxf(size.x, size.z)
		if (model_x if square else box_x) != model_x:
			rot = 90.0 if center.x < 0.0 else -90.0  # along z: front toward the room centre
	var quarter := absf(rot) == 90.0
	var ex := lb.size.z if quarter else lb.size.x  # model extent along room x / z at scale 1
	var ez := lb.size.x if quarter else lb.size.z
	var m_long := ex if box_x else ez
	var m_short := ez if box_x else ex
	var b_long := size.x if box_x else size.z
	var b_short := size.z if box_x else size.x
	var s := minf(canon, b_short / maxf(m_short, 0.001))
	var n := 1
	var k := 1.0
	if tile:
		n = maxi(1, roundi(b_long / maxf(m_long * s, 0.001)))
		k = b_long / (n * m_long * s)
		if n == 1:
			if k < 1.0:
				s *= k
			k = clampf(k, 1.0, MAX_STRETCH)
	else:
		s = minf(s, b_long / maxf(m_long, 0.001))
	# The stretch k runs along the box's long side, in the model's own axes.
	var local := Vector3(s * k, s, s) if box_x != quarter else Vector3(s, s, s * k)
	var full := Basis(Vector3.UP, deg_to_rad(rot)) * Basis.from_scale(local)
	var off := full * Vector3(lb.get_center().x, lb.position.y, lb.get_center().z)
	var axis := Vector3(1, 0, 0) if box_x else Vector3(0, 0, 1)
	for i in n:
		var at := (
			Vector3(center.x, y, center.z)
			+ axis * ((i + 0.5) / n - 0.5) * (b_long if tile else 0.0)
		)
		var inst := WorldProps.place(root, id, root.global_position, {"palette": pal})
		inst.transform = Transform3D(full, at - off)
	return y + lb.size.y * s
