class_name InteriorLook
extends RefCounted
## Original art for the interiors (visual only; InteriorRoom keeps its collision boxes):
## textured floors/walls with the original interior_surface shader (textures/interior/*), and the
## original's Kenney furniture models fitted exactly into each furniture box of InteriorDefs,
## recoloured with the original prop_model.gd palette.

const PALETTE := {
	"wood": Color(0.74, 0.54, 0.32), "woodDark": Color(0.52, 0.36, 0.22), "carpet": Color(0.34, 0.6, 0.45),
	"carpetBlue": Color(0.34, 0.44, 0.68), "carpetDarker": Color(0.26, 0.44, 0.36), "plant": Color(0.3, 0.58, 0.3),
	"lamp": Color(0.95, 0.88, 0.68),
}
## Furniture name (InteriorDefs, Portuguese) -> Kenney model of the original. Unlisted names stay boxes.
const FURNITURE := {
	"Planta": "furniture/pottedPlant", "Estante": "furniture/bookcaseClosedWide", "Mesa": "furniture/table",
	"Rocha": "nature/rock_largeA", "Banco": "furniture/bench", "Prateleira": "furniture/bookcaseOpenLow",
	"Carteira": "furniture/desk", "Tapete": "furniture/rugRectangle", "TV": "furniture/televisionModern",
	"Caixa": "furniture/cardboardBoxClosed", "Cadeira": "furniture/chair", "Vitrine": "furniture/tableGlass",
	"Videogame": "furniture/cabinetTelevision", "Travesseiro": "furniture/pillow", "Escrivaninha": "furniture/desk",
	"Computador": "furniture/computerScreen", "Cama": "furniture/bedSingle", "Bancada": "furniture/kitchenBar",
	"Balcão": "furniture/kitchenBar", "Sofá": "furniture/loungeSofa", "Geladeira": "furniture/kitchenFridge",
	"Fogão": "furniture/kitchenStove", "Pia": "furniture/kitchenSink", "Lâmpada": "furniture/lampRoundFloor",
}

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
	if id.contains("pokemon_center") or id.contains("mart") or id.contains("museum") or id.contains("gate"):
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
		m = WorldFx.shader_mat("interior_surface", {"albedo_tex": tex, "use_tex": true,
				"tint": Color.WHITE.lerp(tint, 0.25), "tiles_per_meter": 0.5})
	else:
		m = MapBuilder.mat(tint)
	_surf[key] = m
	return m


## Kenney model for a furniture entry, scaled per axis to fill `size` exactly, base on the floor at
## `center` (box centre). null when the name has no model or the model is missing.
static func furniture(parent: Node3D, fname: String, center: Vector3, size: Vector3, tint: Color) -> Node3D:
	var id: String = FURNITURE.get(fname, "")
	if id == "" or not WorldProps.exists(id):
		return null
	var pal := PALETTE.duplicate()
	pal["carpet"] = tint
	var inst := WorldProps.place(parent, id, parent.global_position, {"palette": pal})
	if inst == null:
		return null
	inst.position = Vector3.ZERO
	inst.scale = Vector3.ONE
	var bb := WorldProps.bounds(inst, true)
	var s := Vector3(size.x / maxf(bb.size.x, 0.001), size.y / maxf(bb.size.y, 0.001), size.z / maxf(bb.size.z, 0.001))
	inst.scale = s
	var bottom := Vector3(bb.get_center().x * s.x, bb.position.y * s.y, bb.get_center().z * s.z)
	inst.position = center - Vector3(0, size.y / 2.0, 0) - bottom
	inst.name = "Model_%s" % fname
	return inst
