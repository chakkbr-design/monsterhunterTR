class_name VoxelPal
extends RefCounted
## Concept B ("Vila de pedra") colours for the voxel zones (sRGB, the voxel shaders linearise) and
## deterministic per-voxel variation: the same voxel always gets the same shade (VoxelGrid.hash01),
## so a re-bake only changes what the design changed. Palette sources: the concept art and the
## Pixel Lab crate / rock / berry sprites (assets/pixellab/objects).

# Ground.
const LAWN := Color("5e9c3c")
const LAWN_LIGHT := Color("7bb44a")
const LAWN_DRY := Color("98a84a")
const MEADOW := Color("6aa244")
const FOREST_FLOOR := Color("3f6e2e")
const MOSS := Color("4d7a2a")
const DIRT := Color("8a6440")
const DIRT_DARK := Color("6b4a2e")
const SOIL := Color("5a3b24")
const SOIL_DARK := Color("432b1a")
const SAND := Color("d8c48e")
const SAND_WET := Color("b8a070")
const BED_SAND := Color("b29a6a")
const BED_MUD := Color("5d5a3e")
const BED_GRAVEL := Color("8c8676")
const COBBLE := Color("a7a3a6")
const COBBLE_DARK := Color("85808a")
const COBBLE_WARM := Color("b4aa9c")
const CURB := Color("6f6b70")
const SLAB := Color("c9bfae")
const SLAB_DARK := Color("ada291")
const SLAB_BORDER := Color("8f8a86")
const ROCK := Color("8a8a84")  # pixellab rock: a8a89c / 87867b / 6f675d / 5b5360
const ROCK_LIGHT := Color("a8a89c")
const ROCK_DARK := Color("5f5a5c")
const ROCK_BLUE := Color("576978")

# Plants.
const LEAF := Color("4f8f36")
const LEAF_LIGHT := Color("86c04e")
const LEAF_DARK := Color("2f5f2c")
const LEAF_BLUE := Color("2e5a46")
const PINE := Color("2c5a3a")
const PINE_LIGHT := Color("41784a")
const BIRCH_LEAF := Color("8cc152")
const CHERRY := Color("f2a7c3")
const CHERRY_LIGHT := Color("fbd3e2")
const CHERRY_DARK := Color("d97aa0")
const APPLE := Color("d8282a")  # pixellab berry: da1a1a / ca2126
const HEDGE := Color("3d7a30")
const HEDGE_LIGHT := Color("5c9a3a")
const BARK := Color("5e4030")
const BARK_DARK := Color("43302a")
const BIRCH_BARK := Color("e6e2d6")

# Buildings.
const STONE_WALL := Color("a59d92")
const STONE_WALL_LIGHT := Color("bdb4a6")
const STONE_WALL_DARK := Color("847c74")
const PLASTER := Color("efe6d2")
const TIMBER := Color("5a3a28")
const WOOD := Color("8e5c36")  # pixellab crate: 7b4a35 / a98463 / 8e5c36 / 593828
const WOOD_LIGHT := Color("a98463")
const WOOD_DARK := Color("593828")
const ROOF := Color("e0702c")
const ROOF_LIGHT := Color("ef8a44")
const ROOF_DARK := Color("b9561f")
const WINDOW := Color("ffd9a0")
const WINDOW_FRAME := Color("f4efe6")
const LAMP := Color("ffd890")
const METAL := Color("3a383d")
const FLOOR := Color("a07048")


## c lightened / darkened by up to `amt` from the hash h in [0, 1).
static func vary(c: Color, h: float, amt: float) -> Color:
	var k := (h - 0.5) * 2.0 * amt
	return c.lightened(k) if k > 0.0 else c.darkened(-k)


## Deterministic shade of c for voxel v (salt separates uses).
static func at(c: Color, v: Vector3i, amt: float, salt := 0) -> Color:
	return vary(c, VoxelGrid.hash01(v.x, v.y, v.z, salt), amt)


static func hex(s: String, fallback: Color) -> Color:
	return Color.from_string(s, fallback) if s != "" else fallback
