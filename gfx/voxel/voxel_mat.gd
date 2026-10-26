class_name VoxelMat
extends RefCounted
## Voxel material ids (the alpha byte of every VoxelGrid cell) and their lighting properties,
## packed into a 256x1 lookup texture read by voxel.gdshader:
##   R roughness, G emission class (EMIT_*), B porosity (how dark/glossy rain makes it),
##   A flag bits (F_*). Colour is never here: every voxel carries its own sRGB colour.
## Add new ids at the end; never renumber (baked zones store these numbers).

const DETAIL := 0.0625  ## edge of a decor ("detail") voxel: 4 per world voxel, 16 per metre

const AIR := 0
const STONE := 1  ## cobbles, rocks, walls of stone
const GRASS := 2
const DIRT := 3
const SAND := 4
const WOOD := 5
const ROOF := 6
const PLASTER := 7
const LEAVES := 8
const BARK := 9
const WINDOW := 10  ## glows at night (night_windows)
const LAMP := 11  ## glows at night (night_lamps)
const METAL := 12
const BED := 13  ## under water (caustics, never wet)
const FLOWER := 14
const CROP := 15
const SNOW := 16
const ICE := 17
const LAVA := 18  ## always glows
const CRYSTAL := 19  ## always glows (dim)
const SLAB := 20  ## cut stone paving
const BRICK := 21
const CLOTH := 22
const SEAT := 23  ## stadium plastic
const PAINT := 24  ## field lines, emblems
const SCREEN := 25  ## scoreboards (always glows)
const MOSS := 26
const GRAVEL := 27
const FIRE := 28  ## always glows, warm
const HAY := 29
const GLASS := 30  ## plain glass (no night glow)
const FLOODLIGHT := 31  ## stadium lamps (glow with night_lamps, much brighter)

const EMIT_NONE := 0
const EMIT_WINDOW := 1
const EMIT_LAMP := 2
const EMIT_ALWAYS := 3
const EMIT_FLOOD := 4

const F_SNOW := 1  ## snow settles on its exposed tops
const F_PUDDLE := 2  ## flat exposed tops collect puddles
const F_FOLIAGE := 4  ## back-lit (leaves, petals)
const F_METAL := 8
const F_BED := 16
const F_GLOSS := 32

## id: [roughness, emission, porosity, flags]
const TABLE := {
	STONE: [0.82, EMIT_NONE, 0.45, F_SNOW | F_PUDDLE],
	GRASS: [0.95, EMIT_NONE, 0.75, F_SNOW],
	DIRT: [0.95, EMIT_NONE, 0.85, F_SNOW | F_PUDDLE],
	SAND: [0.92, EMIT_NONE, 0.7, F_SNOW | F_PUDDLE],
	WOOD: [0.78, EMIT_NONE, 0.55, F_SNOW],
	ROOF: [0.6, EMIT_NONE, 0.3, F_SNOW],
	PLASTER: [0.88, EMIT_NONE, 0.45, F_SNOW],
	LEAVES: [0.8, EMIT_NONE, 0.3, F_SNOW | F_FOLIAGE],
	BARK: [0.92, EMIT_NONE, 0.6, F_SNOW],
	WINDOW: [0.12, EMIT_WINDOW, 0.0, F_GLOSS],
	LAMP: [0.25, EMIT_LAMP, 0.0, F_GLOSS],
	METAL: [0.35, EMIT_NONE, 0.0, F_SNOW | F_METAL],
	BED: [0.9, EMIT_NONE, 0.0, F_BED],
	FLOWER: [0.8, EMIT_NONE, 0.2, F_FOLIAGE],
	CROP: [0.85, EMIT_NONE, 0.4, F_SNOW | F_FOLIAGE],
	SNOW: [0.7, EMIT_NONE, 0.1, F_SNOW],
	ICE: [0.06, EMIT_NONE, 0.0, F_GLOSS],
	LAVA: [0.6, EMIT_ALWAYS, 0.0, 0],
	CRYSTAL: [0.08, EMIT_ALWAYS, 0.0, F_GLOSS],
	SLAB: [0.55, EMIT_NONE, 0.35, F_SNOW | F_PUDDLE],
	BRICK: [0.86, EMIT_NONE, 0.5, F_SNOW],
	CLOTH: [0.92, EMIT_NONE, 0.8, F_SNOW],
	SEAT: [0.4, EMIT_NONE, 0.05, F_SNOW],
	PAINT: [0.9, EMIT_NONE, 0.6, F_SNOW | F_PUDDLE],
	SCREEN: [0.3, EMIT_ALWAYS, 0.0, F_GLOSS],
	MOSS: [0.97, EMIT_NONE, 0.8, F_SNOW | F_FOLIAGE],
	GRAVEL: [0.95, EMIT_NONE, 0.6, F_SNOW | F_PUDDLE],
	FIRE: [0.7, EMIT_ALWAYS, 0.0, 0],
	HAY: [0.95, EMIT_NONE, 0.7, F_SNOW],
	GLASS: [0.08, EMIT_NONE, 0.0, F_GLOSS],
	FLOODLIGHT: [0.2, EMIT_FLOOD, 0.0, F_GLOSS],
}

static var _lut: ImageTexture
static var _shaders := {}


static func lut() -> ImageTexture:
	if _lut:
		return _lut
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color8(230, 0, 128, F_SNOW))
	img.set_pixel(0, 0, Color8(255, 0, 0, 0))
	for id in TABLE:
		var r: Array = TABLE[id]
		img.set_pixel(id, 0, Color8(int(r[0] * 255.0), r[1], int(r[2] * 255.0), r[3]))
	_lut = ImageTexture.create_from_image(img)
	return _lut


static func shader(name := "voxel") -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load("res://gfx/voxel/%s.gdshader" % name)
	return _shaders[name]


## Material for greedy meshes of `g` (pass its texture/tops if already built to share them).
static func material(
	g: VoxelGrid, tex: Texture3D = null, tops: Texture2D = null, params := {}
) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("voxel")
	m.set_shader_parameter("vox", tex if tex else g.texture())
	m.set_shader_parameter("tops", tops if tops else g.tops_texture())
	m.set_shader_parameter("mat_lut", lut())
	m.set_shader_parameter("grid_origin", g.origin)
	m.set_shader_parameter("grid_size", g.size)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Material for VoxelMesher.colored() models (decor at the detail scale).
static func detail_material(params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("voxel_detail")
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Greedy-meshes `g` and returns one MeshInstance3D per part (named "<prefix><part>"), all sharing
## one material unless `part_params` gives a part its own uniforms (e.g. {3: {"sway": 0.05}}).
static func instances(g: VoxelGrid, prefix := "Voxels", part_params := {}) -> Array:
	var meshes := VoxelMesher.greedy(g)
	var tex := g.texture()
	var tops := g.tops_texture()
	var base := material(g, tex, tops)
	var out := []
	for prt in meshes:
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [prefix, prt]
		mi.mesh = meshes[prt]
		mi.material_override = (
			material(g, tex, tops, part_params[prt]) if part_params.has(prt) else base
		)
		out.append(mi)
	return out
