class_name ArenaPalette
extends RefCounted
## Colours and materials of the voxel training field per scenario (docs/VOXEL.md §7): floor painted
## per 1 m tile, relief, pond beds, tall grass and props. Variation only comes from position hashes
## (VoxelGrid.hash01 / noise() below), never from the battle RNG.

## Base palette (campo); SCENES overrides keys per scenario.
const BASE := {
	# Court floor ("floor" picks the tile style in ArenaFloor).
	"floor": "turf",
	"turf_a": Color("5aa63a"),
	"turf_b": Color("4f9734"),
	"grass": Color("5ea23d"),
	"grass_dark": Color("3e7d2c"),
	"grass_light": Color("86c45a"),
	"dirt": Color("8b6a45"),
	"dirt_dark": Color("6b4e31"),
	"stone": Color("8f8d88"),
	"stone_dark": Color("686661"),
	"stone_light": Color("b5b2aa"),
	"sand": Color("dcc58f"),
	"sand_wet": Color("b39a68"),
	"gravel": Color("9b9184"),
	"slab": Color("aaa59b"),
	"snow": Color("eaf0f7"),
	"line": Color("f3f3ed"),
	# Outside the barrier (concourse paving).
	"surround": Color("b8b3a7"),
	"surround_mat": VoxelMat.SLAB,
	# Barrier padding.
	"pad": Color("2f5fb8"),
	"pad_dark": Color("244c97"),
	"cap": Color("eef0f2"),
	# Relief.
	"hill_top": Color("5ea23d"),
	"hill_top_mat": VoxelMat.GRASS,
	"hill_side": Color("8b6a45"),
	"hill_side_mat": VoxelMat.DIRT,
	"peak": Color("8c8a86"),
	"peak_top": Color("b2afa7"),
	"peak_top_mat": VoxelMat.STONE,
	"peak_vein": Color(0, 0, 0, 0),  ## glowing vein colour (vulcão lava, caverna crystal); a = 0 none
	# Ponds.
	"shore": Color("cdb27a"),
	"shore_mat": VoxelMat.SAND,
	"bed": Color("a99169"),
	"bed_deep": Color("6c5f47"),
	"pebble": Color("8a8478"),
	"water": Color(0.14, 0.45, 0.52, 0.6),  ## WaterSurface tint (rgb colour, a = opacity)
	# Tall grass blades (dark -> light).
	"blades": [Color("2c6a28"), Color("3c8a33"), Color("57a843"), Color("92d064")],
	# Trees and bushes.
	"leaves": Color("3f8f35"),
	"leaves_dark": Color("2c6d2a"),
	"leaves_light": Color("6bb84a"),
	"bark": Color("6a4a2e"),
	"bark_dark": Color("4c3420"),
}

const SCENES := {
	"campo": {},
	"lagoa":
	{
		"floor": "meadow",
		"grass": Color("58a04a"),
		"grass_dark": Color("3c7f37"),
		"turf_a": Color("58a04a"),
		"hill_top": Color("58a04a"),
	},
	"pedreira":
	{
		"floor": "quarry",
		"hill_top": Color("a39a8c"),
		"hill_top_mat": VoxelMat.GRAVEL,
		"hill_side": Color("8a7660"),
		"hill_side_mat": VoxelMat.STONE,
		"peak": Color("948b80"),
		"peak_top": Color("b9b1a4"),
		"shore": Color("a39a8c"),
		"shore_mat": VoxelMat.GRAVEL,
		"blades": [Color("4e6a2a"), Color("6a8a3a"), Color("8aa84e"), Color("b8c87a")],
	},
	"misto": {"floor": "mixed"},
	"praia":
	{
		"floor": "beach",
		"hill_top": Color("e2cc98"),
		"hill_top_mat": VoxelMat.SAND,
		"hill_side": Color("c9b07c"),
		"hill_side_mat": VoxelMat.SAND,
		"peak": Color("a08a70"),
		"peak_top": Color("c2ad90"),
		"blades": [Color("6a7a32"), Color("8a9a44"), Color("b0b85e"), Color("d8d68a")],
		"surround": Color("d4c49a"),
		"surround_mat": VoxelMat.SAND,
	},
	"ruinas":
	{
		"floor": "ruins",
		"slab": Color("b9ae95"),
		"peak": Color("a39880"),
		"peak_top": Color("c2b89c"),
		"surround": Color("a69c86"),
	},
	"montanha":
	{
		"floor": "snowfield",
		"line": Color("2f4f9a"),
		"hill_top": Color("eef3f8"),
		"hill_top_mat": VoxelMat.SNOW,
		"hill_side": Color("6e737b"),
		"hill_side_mat": VoxelMat.STONE,
		"peak": Color("6a6f78"),
		"peak_top": Color("f0f4f8"),
		"peak_top_mat": VoxelMat.SNOW,
		"shore": Color("8a8f96"),
		"shore_mat": VoxelMat.GRAVEL,
		"bed": Color("7d8288"),
		"bed_deep": Color("4f545a"),
		"water": Color(0.22, 0.52, 0.64, 0.55),
		"surround": Color("dfe6ee"),
		"surround_mat": VoxelMat.SNOW,
		"leaves": Color("2f6a45"),
		"leaves_dark": Color("1f4f35"),
		"leaves_light": Color("4f8a60"),
	},
	"vulcao":
	{
		"floor": "basalt",
		"line": Color("e6dccd"),
		"stone": Color("4a403b"),
		"stone_dark": Color("2c2522"),
		"stone_light": Color("675a52"),
		"hill_top": Color("6e6058"),
		"hill_top_mat": VoxelMat.GRAVEL,
		"hill_side": Color("43372f"),
		"hill_side_mat": VoxelMat.STONE,
		"peak": Color("3a312d"),
		"peak_top": Color("6a5b52"),
		"peak_vein": Color("ff7a1a"),
		"shore": Color("3c3532"),
		"shore_mat": VoxelMat.GRAVEL,
		"bed": Color("4c4a44"),
		"bed_deep": Color("2a2826"),
		"water": Color(0.1, 0.46, 0.42, 0.62),
		"surround": Color("4a4440"),
		"surround_mat": VoxelMat.SLAB,
		"pad": Color("a8341c"),
		"pad_dark": Color("86271a"),
	},
	"caverna":
	{
		"floor": "cave",
		"stone": Color("45464f"),
		"stone_dark": Color("2a2a32"),
		"stone_light": Color("60616c"),
		"hill_top": Color("4a5c40"),
		"hill_top_mat": VoxelMat.MOSS,
		"hill_side": Color("3a3b44"),
		"hill_side_mat": VoxelMat.STONE,
		"peak": Color("3d3e48"),
		"peak_top": Color("575866"),
		"peak_vein": Color("6fd8f0"),
		"shore": Color("3e3f48"),
		"shore_mat": VoxelMat.GRAVEL,
		"bed": Color("34353d"),
		"bed_deep": Color("1e1f25"),
		"water": Color(0.08, 0.24, 0.45, 0.66),
		"surround": Color("3a3a42"),
		"surround_mat": VoxelMat.SLAB,
		"pad": Color("5a3f9a"),
		"pad_dark": Color("47317c"),
	},
	"pantano":
	{
		"floor": "swamp",
		"grass": Color("5a7a36"),
		"grass_dark": Color("3f5a28"),
		"dirt": Color("5a4630"),
		"dirt_dark": Color("40311f"),
		"hill_top": Color("5d7a38"),
		"hill_top_mat": VoxelMat.MOSS,
		"hill_side": Color("4d3d2a"),
		"hill_side_mat": VoxelMat.DIRT,
		"shore": Color("4a3d2a"),
		"shore_mat": VoxelMat.DIRT,
		"bed": Color("3e3424"),
		"bed_deep": Color("2a2418"),
		"water": Color(0.24, 0.3, 0.12, 0.74),
		"blades": [Color("4a5a24"), Color("667a32"), Color("8a9a48"), Color("b4bc6a")],
		"surround": Color("6a6450"),
		"leaves": Color("4a6a30"),
		"leaves_dark": Color("334a22"),
		"leaves_light": Color("6f8f44"),
	},
}

static var _cache := {}


## Palette of `sc` (BASE + overrides).
static func of(sc: String) -> Dictionary:
	if _cache.has(sc):
		return _cache[sc]
	var p := BASE.duplicate()
	p.merge(SCENES.get(sc, {}), true)
	_cache[sc] = p
	return p


## `c` lightened or darkened by up to `amt` from the voxel hash (per-voxel jitter).
static func jit(c: Color, v: Vector3i, amt := 0.06, salt := 0) -> Color:
	var h := VoxelGrid.hash01(v.x, v.y, v.z, salt) * 2.0 - 1.0
	return c.lightened(amt * h) if h > 0.0 else c.darkened(-amt * h)


## Smooth value noise in [0, 1) on a grid of 1-unit cells (deterministic, from hash01).
static func noise(x: float, z: float, salt := 0) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := VoxelGrid.hash01(ix, 0, iz, salt)
	var b := VoxelGrid.hash01(ix + 1, 0, iz, salt)
	var c := VoxelGrid.hash01(ix, 0, iz + 1, salt)
	var d := VoxelGrid.hash01(ix + 1, 0, iz + 1, salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


## Deterministic RNG for the looks of something at `p` (never the battle RNG).
static func rng_at(p: Vector3, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s_%d_%d" % [salt, roundi(p.x * 8.0), roundi(p.z * 8.0)])
	return r
