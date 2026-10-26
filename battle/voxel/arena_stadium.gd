class_name ArenaStadium
extends Node3D
## Voxel stadium around the energy-mode training field (docs/VOXEL.md §7), built once per training
## scene (TrainingBattle._build_stage; never under fast_sim, never in VGC). Visual only: no
## physics bodies at all, so the arena's wall queries (layer 1) never see it.
## Layout (metres, field centre at the origin; the field is 48 x 28, its barrier at 24.5 x 14.5):
## - a bowl of stands (StadiumParts) whose front walls run on |x| = IN_X and |z| = IN_Z: 10 m
##   sections on the long sides, 8 m sections on the ends (the middle one holds that side's players'
##   tunnel, behind its trainer), four corner pieces; 12 rows rising 0.5 m per metre, so the +z
##   stand stays under the action camera's sight lines (30 degrees from the field edge);
## - the crowd (ArenaCrowd), perimeter boards with pixel lettering, flags on the parapets;
## - four floodlight towers on the outer corners (SpotLight3D, shadows only on the two back ones)
##   whose FLOODLIGHT voxels glow with the night_lamps global (faint in daylight);
## - the main scoreboard on the back stand (team names, Poke Balls left, clock, scenario, series)
##   with the big Poke Ball emblem, and a board behind each end for that side's trainer;
## - the concourse between the field floor (ArenaFloor) and the stands, the outer plaza, lawns,
##   hedges, lamp posts and trees out to the fog, the sky (stadium_sky.gdshader) and the
##   Environment (AgX, SSAO, glow, depth fog) with the sun.
## Moods (time of day, MOODS): "dia", "tarde" (sunset) and "noite"; theme(scenario) retints the
## surroundings and darkens the sky for caverna (night) and pantano (overcast). BattleBiomes still
## dims the sun and sets the ambient colour per scenario on top of the mood.
## Light ownership during a training fight: the stadium owns its sun, ambient, fog and floodlights
## and the night_lamps, night_windows, sun_dir_world, sun_color_world, sun_amount, sky_top_color
## and sky_horizon_color globals (written only when they change, back to the project defaults when
## it leaves). The battle weather (BattleWeatherFx) owns rain_amount, rain_wet, rain_puddle,
## snow_cover, cloud_cover and lightning_flash, and asks for the rest through
## weather_light(cloud, flash): clouds dim and soften the sun, lift the ambient, grey the fog and
## the sky globals (the sky shader greys itself from cloud_cover) and switch the floodlights on in a
## dark storm; a lightning flash spikes the ambient (and the sky flashes from lightning_flash).
## Live API: score(info), cheer(side, amount), wave(), set_mood(mood), theme(scenario),
## weather_light(cloud, flash), weather_area().

const Cfg := preload("res://ui/training/training_config.gd")
const Kit := preload("res://ui/ui_kit.gd")
const FLAG_SHADER := preload("res://battle/voxel/flag.gdshader")

## Stand front walls (half extents).
const IN_X := 30.0
const IN_Z := 20.0
## Sections: long sides (along x) and ends (along z), voxels.
const LONG_V := 40
const END_V := 32
## Floodlight masts (voxels) and their spots.
const MAST_V := 104
const TOWER_OUT := 2.25
## Ground out to here (m) and the plaza ring around the stands (m).
const GROUND_HALF := Vector2(150, 140)
const PLAZA := 10
## Colour grading of the stadium environment (saturation).
const SATURATION := 1.08
## Battle weather (weather_light): cloud 1 takes this much of the sun and of its shadow, adds this
## much ambient, pulls the depth fog this much closer and darkens its grey, takes this much of the
## saturation; a lightning flash multiplies the ambient by 1 + FLASH_AMBIENT x flash (the flash's
## own light gives the direction); a storm this cloudy turns the floodlights on (spots energy, lamp
## glow) even by day. Rain and snow cover the bowl out to the parapet plus WEATHER_PAD (m).
const CLOUD_SUN_DIM := 0.62
const CLOUD_SHADOW := 0.55
const CLOUD_AMBIENT := 0.15
const CLOUD_FOG := 0.25
const CLOUD_FOG_DARK := 0.3
const CLOUD_DESAT := 0.3
const FLASH_AMBIENT := 1.3
const STORM_LIGHTS := Vector2(0.45, 0.85)
const STORM_SPOTS := 2.2
const STORM_LAMPS := 0.55
const WEATHER_PAD := 1.0
## Floodlight falloff and colour unless the mood sets its own (MOODS spot_att, spot_color).
const SPOT_ATT := 0.35
const SPOT_COLOR := Color(1.0, 0.95, 0.86)
## Perimeter board: one panel (m) and its texture (px).
## Fan banners on the parapets: size (m), texture size (1/16 m texels) and their cheers.
const BANNER := Vector2(4.0, 1.0)
const BANNER_PX := Vector2i(64, 16)
const BANNER_CHEERS := ["VAI!", "FORCA", "GO GO", "OLE!", "UHUL!", "VAMOS"]
const PANEL := Vector2(2.5, 1.0)
const PANEL_PX := Vector2i(40, 16)
const SPONSORS := [
	"LIGA KANTO",
	"SILPH CO.",
	"POKE MART",
	"CENTRO POKEMON",
	"LAB. CARVALHO",
	"PALLET",
	"TREINO",
	"DEVON",
]
const PANEL_COLORS := [
	[Color("e23a2e"), Color("f8f4ea")],
	[Color("1f2a44"), Color("f2c230")],
	[Color("2f6fd8"), Color("f8f4ea")],
	[Color("f2c230"), Color("1f2a44")],
	[Color("36a456"), Color("f8f4ea")],
	[Color("f8f4ea"), Color("e23a2e")],
	[Color("8b4fb8"), Color("f8f4ea")],
	[Color("e47a2e"), Color("1f2a44")],
]
## Moods: sun (elevation, azimuth in degrees; azimuth 0 = from +z, the camera side), colours and
## energies, sky, fog, lamps (night_lamps), windows (night_windows), spots (floodlight energy) and,
## optionally, spot_att (floodlight distance falloff, SPOT_ATT) and spot_color (SPOT_COLOR).
const MOODS := {
	"dia":
	{
		"elev": 52.0,
		"azim": 32.0,
		"sun": Color(1.0, 0.95, 0.86),
		"sun_e": 1.35,
		"ambient": Color(0.6, 0.64, 0.74),
		"amb_e": 0.55,
		"top": Color(0.26, 0.5, 0.88),
		"horizon": Color(0.6, 0.77, 0.95),
		"ground": Color(0.4, 0.45, 0.38),
		"glow": Color(1.0, 0.92, 0.75),
		"disc": Color(1.0, 0.97, 0.88),
		"cloud": Color(1.0, 1.0, 1.0),
		"cloud_shade": Color(0.74, 0.79, 0.88),
		"clouds": 0.42,
		"stars": 0.0,
		"fog": Color(0.64, 0.77, 0.93),
		"fog_begin": 110.0,
		"fog_end": 380.0,
		"lamps": 0.05,
		"windows": 0.0,
		"spots": 0.0,
		"exposure": 1.0,
	},
	"tarde":
	{
		"elev": 11.0,
		"azim": -58.0,
		"sun": Color(1.0, 0.62, 0.34),
		"sun_e": 1.6,
		"ambient": Color(0.56, 0.48, 0.58),
		"amb_e": 0.5,
		"top": Color(0.2, 0.26, 0.52),
		"horizon": Color(0.98, 0.6, 0.38),
		"ground": Color(0.3, 0.26, 0.28),
		"glow": Color(1.0, 0.55, 0.25),
		"disc": Color(1.0, 0.78, 0.5),
		"cloud": Color(1.0, 0.7, 0.5),
		"cloud_shade": Color(0.5, 0.38, 0.52),
		"clouds": 0.5,
		"stars": 0.0,
		"fog": Color(0.86, 0.6, 0.5),
		"fog_begin": 70.0,
		"fog_end": 300.0,
		"lamps": 0.5,
		"windows": 0.75,
		"spots": 1.5,
		"exposure": 1.0,
	},
	"noite":
	{
		"elev": 38.0,
		"azim": 40.0,
		"sun": Color(0.55, 0.66, 1.0),
		"sun_e": 0.22,
		"ambient": Color(0.22, 0.26, 0.4),
		"amb_e": 0.6,
		"top": Color(0.01, 0.02, 0.06),
		"horizon": Color(0.06, 0.09, 0.17),
		"ground": Color(0.03, 0.04, 0.05),
		"glow": Color(0.4, 0.5, 0.8),
		"disc": Color(0.9, 0.93, 1.0),
		"cloud": Color(0.2, 0.24, 0.34),
		"cloud_shade": Color(0.08, 0.1, 0.16),
		"clouds": 0.3,
		"stars": 1.0,
		"fog": Color(0.05, 0.07, 0.13),
		"fog_begin": 60.0,
		"fog_end": 260.0,
		"lamps": 1.0,
		"windows": 1.0,
		# Floodlit night, darker than day: cooler lamps with a steeper falloff leave pools of light
		# on the court and dimmer gaps (field about 0.65x of "dia" in the action camera).
		"spots": 3.0,
		"spot_att": 0.6,
		"spot_color": Color(0.85, 0.9, 1.0),
		"exposure": 1.0,
	},
}
## Scenario looks of the surroundings: lawn and tree theme, and sky / light overrides of the mood.
const THEMES := {
	# Areia e neve claras: um pouco menos de exposição para o piso não estourar no branco.
	"praia": {"lawn": "sand", "trees": "palm", "sky": {"exposure": 0.93}},
	"montanha":
	{
		"lawn": "snow",
		"trees": "montanha",
		"sky": {"exposure": 0.86, "sun": Color(0.94, 0.96, 1.0), "horizon": Color(0.7, 0.8, 0.92)},
	},
	"vulcao":
	{
		"lawn": "ash",
		"trees": "dead",
		"sky":
		{
			"horizon": Color(0.78, 0.5, 0.4),
			"top": Color(0.36, 0.3, 0.38),
			"fog": Color(0.6, 0.42, 0.36),
			"fog_begin": 55.0,
			"fog_end": 240.0,
			"clouds": 0.7,
			"cloud": Color(0.55, 0.45, 0.45),
			"cloud_shade": Color(0.3, 0.24, 0.26),
			"spots": 1.2,
			"lamps": 0.35,
		},
	},
	"caverna": {"lawn": "dark", "trees": "campo", "night": true},
	"pantano":
	{
		"lawn": "swamp",
		"trees": "pantano",
		"sky":
		{
			"horizon": Color(0.56, 0.62, 0.56),
			"top": Color(0.4, 0.46, 0.46),
			"fog": Color(0.5, 0.56, 0.5),
			"fog_begin": 40.0,
			"fog_end": 190.0,
			"clouds": 0.85,
			"cloud": Color(0.7, 0.74, 0.7),
			"cloud_shade": Color(0.46, 0.5, 0.48),
			"disc": Color(0.8, 0.82, 0.78),
			"glow": Color(0.6, 0.62, 0.55),
			"spots": 2.0,
			"lamps": 0.6,
			"windows": 0.5,
		},
	},
}
const LAWNS := {
	"green": [Color("5d9e3c"), Color("54933a"), Color("6aad48"), Color("3f7d2c")],
	"sand": [Color("dcc58f"), Color("d2b983"), Color("e4d09e"), Color("b9a06c")],
	"snow": [Color("eaf0f6"), Color("dfe7f0"), Color("f4f7fb"), Color("b9c4cf")],
	"ash": [Color("5e5651"), Color("544c47"), Color("6a615b"), Color("3d3633")],
	"dark": [Color("3f6a34"), Color("38602f"), Color("47753a"), Color("2c4a24")],
	"swamp": [Color("5a6e38"), Color("4e6232"), Color("667a40"), Color("3a4a26")],
}
const C_PAVE := [Color("b8b1a4"), Color("aaa396"), Color("c3bcaf")]
const C_HEDGE := Color("3d7a34")
const FLOWERS := [
	Color("e8574a"), Color("f2c94c"), Color("f4f0e6"), Color("e38bb8"), Color("8a6ad8")
]

static var _models := {}
static var _ground_tex := {}
static var _ring_tex := {}

var mood := "dia"
var scenario := ""
var names := ["Time A", "Time B"]
var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var spots: Array[SpotLight3D] = []
var tunnel_lights: Array[OmniLight3D] = []
var cheer_a := 0.0
var cheer_b := 0.0
## What the battle weather asks of the light now (weather_light): cloud cover and lightning flash.
var cloud := 0.0
var flash := 0.0
var _mood_now := {}
var _ground_mi: MeshInstance3D
var _ground_grid: VoxelGrid
var _ring_mi: MeshInstance3D
var _ring_grid: VoxelGrid
var _trees: Node3D
var _boards := {}  ## "main" / "a" / "b" -> {labels..., balls: [Sprite3D]}
var _ball_tex := []
var _score_key := ""
var _wave_t := -1.0
## Battle weather on the light (weather_light): the sun and ambient energies without it (the mood
## times BattleBiomes), what we last set and the factors we applied, and the globals this stadium
## wrote (restored to the project defaults when it leaves).
var _sun_base := -1.0
var _sun_set := -1.0
var _amb_base := -1.0
var _amb_set := -1.0
var _k_sun := 1.0
var _k_amb := 1.0
var _globals := {}


## Builds the stadium (opts: mood, names [side 0, side 1]).
static func build(opts := {}) -> ArenaStadium:
	var s := ArenaStadium.new()
	s.name = "Stadium"
	s.mood = String(opts.get("mood", "dia"))
	if not MOODS.has(s.mood):
		s.mood = "dia"
	var nm: Array = opts.get("names", [])
	if nm.size() == 2:
		s.names = [String(nm[0]), String(nm[1])]
	s._build()
	return s


func _build() -> void:
	add_to_group(BattleWeatherFx.LIGHT_GROUP)
	_build_env()
	_build_stands()
	_build_towers()
	_build_boards()
	_build_scoreboards()
	_build_flags()
	_build_banners()
	_build_ground()
	_build_ring()
	_trees = Node3D.new()
	_trees.name = "Trees"
	add_child(_trees)
	theme("")


## Leaving (back to the setup or the title): every global it wrote goes back to the project's
## default, so the next scene (the overworld's TimeOfDay writes its own on start) begins clean.
func _exit_tree() -> void:
	for n in _globals:
		var v = BattleWeatherFx.global_default(n)
		if v != null:
			RenderingServer.global_shader_parameter_set(n, v)
	_globals.clear()


## A shader global, written only when it changes.
func _global(n: String, v) -> void:
	if _globals.has(n) and _globals[n] == v:
		return
	_globals[n] = v
	RenderingServer.global_shader_parameter_set(n, v)


## Last value this stadium wrote to a shader global (null if never; tests).
func global_value(n: String):
	return _globals.get(n)


# --- Model cache ---


static func _model(key: String, make: Callable, vs := VoxelGrid.VS) -> ArenaVoxels.Model:
	if not _models.has(key):
		_models[key] = ArenaVoxels.model(make.call(), vs)
	return _models[key]


## Node3D at `origin` whose local x / z axes point along `along` / `out` (y up).
static func _frame(along: Vector3, out: Vector3, origin: Vector3) -> Transform3D:
	return Transform3D(Basis(along, Vector3.UP, out), origin)


# --- Stands ---


func _build_stands() -> void:
	var root := Node3D.new()
	root.name = "Stands"
	add_child(root)
	var long_n := roundi(IN_X * 2.0 / (LONG_V * VoxelGrid.VS))
	var end_n := roundi(IN_Z * 2.0 / (END_V * VoxelGrid.VS))
	var long_m := LONG_V * VoxelGrid.VS
	var end_m := END_V * VoxelGrid.VS
	for i in long_n:
		# Back (-z): along -x from x = IN_X; front (+z): along +x from x = -IN_X.
		_section(
			root,
			"Back%d" % i,
			LONG_V,
			{"vomit": true, "salt": i},
			_frame(Vector3.LEFT, Vector3.FORWARD, Vector3(IN_X - i * long_m, 0, -IN_Z))
		)
		_section(
			root,
			"Front%d" % i,
			LONG_V,
			{"vomit": true, "salt": 10 + i},
			_frame(Vector3.RIGHT, Vector3.BACK, Vector3(-IN_X + i * long_m, 0, IN_Z))
		)
	for i in end_n:
		var mid := i == end_n / 2
		# +x end (side 1): along -z from z = IN_Z; -x end (side 0): along +z from z = -IN_Z.
		_section(
			root,
			"EndB%d" % i,
			END_V,
			{"vomit": not mid, "tunnel": 1 if mid else -1, "salt": 20 + i},
			_frame(Vector3.FORWARD, Vector3.RIGHT, Vector3(IN_X, 0, IN_Z - i * end_m))
		)
		_section(
			root,
			"EndA%d" % i,
			END_V,
			{"vomit": not mid, "tunnel": 0 if mid else -1, "salt": 30 + i},
			_frame(Vector3.BACK, Vector3.LEFT, Vector3(-IN_X, 0, -IN_Z + i * end_m))
		)
		if mid:
			for side in 2:
				var l := OmniLight3D.new()
				l.name = "TunnelLight%d" % side
				l.light_color = Color(1.0, 0.82, 0.55)
				l.omni_range = 7.0
				l.light_energy = 0.0
				var sx := -1.0 if side == 0 else 1.0
				l.position = Vector3(sx * (IN_X + 1.5), 2.0, 0)
				root.add_child(l)
				tunnel_lights.append(l)
	var corners := [
		_frame(Vector3.RIGHT, Vector3.BACK, Vector3(IN_X, 0, IN_Z)),
		_frame(Vector3.FORWARD, Vector3.RIGHT, Vector3(IN_X, 0, -IN_Z)),
		_frame(Vector3.LEFT, Vector3.FORWARD, Vector3(-IN_X, 0, -IN_Z)),
		_frame(Vector3.BACK, Vector3.LEFT, Vector3(-IN_X, 0, IN_Z)),
	]
	var cm := _model("corner", func() -> VoxelGrid: return StadiumParts.corner(5))
	var cseats := StadiumParts.corner_seats()
	for i in corners.size():
		var node := ArenaVoxels.instance(cm, "Corner%d" % i)
		node.transform = corners[i]
		root.add_child(node)
		node.add_child(ArenaCrowd.section(cseats, corners[i], 50 + i))


func _section(root: Node3D, name: String, len_v: int, opts: Dictionary, xf: Transform3D) -> void:
	var key := (
		"bank_%d_%s_%d_%d"
		% [
			len_v,
			str(opts.get("vomit", false)),
			int(opts.get("tunnel", -1)),
			int(opts.get("salt", 0)) % 3
		]
	)
	var o := opts.duplicate()
	o.salt = int(opts.get("salt", 0)) % 3
	var m := _model(key, func() -> VoxelGrid: return StadiumParts.bank(len_v, o))
	var node := ArenaVoxels.instance(m, name)
	node.transform = xf
	root.add_child(node)
	node.add_child(
		ArenaCrowd.section(StadiumParts.bank_seats(len_v, o), xf, int(opts.get("salt", 0)))
	)


# --- Floodlights ---


func _build_towers() -> void:
	var root := Node3D.new()
	root.name = "Floodlights"
	add_child(root)
	var mast := _model("mast", func() -> VoxelGrid: return StadiumParts.mast(MAST_V))
	var head := _model("lamp_head", func() -> VoxelGrid: return StadiumParts.lamp_head())
	var out := StadiumParts.DEPTH + VoxelGrid.VS + TOWER_OUT
	var top := (MAST_V + 1) * VoxelGrid.VS
	var i := 0
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var at := Vector3(sx * (IN_X + out), 0, sz * (IN_Z + out))
			var m := ArenaVoxels.instance(mast, "Mast%d" % i)
			m.position = at
			root.add_child(m)
			var aim := Vector3(-sx * 7.0, 0.0, -sz * 3.0)
			var h := ArenaVoxels.instance(head, "Head%d" % i, {}, false)
			h.position = at + Vector3(0, top + 0.5, 0)
			root.add_child(h)
			# Lamps face the field (the model looks along -z): turn, then tilt down.
			var to := aim - h.position
			h.basis = Basis.looking_at(to.normalized(), Vector3.UP)
			var l := SpotLight3D.new()
			l.name = "Spot%d" % i
			l.light_color = SPOT_COLOR
			l.spot_range = 130.0
			l.spot_angle = 36.0
			l.spot_angle_attenuation = 0.6
			l.spot_attenuation = SPOT_ATT
			l.light_energy = 0.0
			l.shadow_enabled = sz < 0.0  # the two back towers only
			l.shadow_bias = 0.04
			# Low glint: on the ponds (water.gdshader, SPECULAR_AMOUNT = 2 x this) a floodlight
			# leaves a highlight, not a clipped white blob.
			l.light_specular = 0.12
			var lp := h.position + to.normalized() * 1.5 + Vector3(0, 2.0, 0)
			l.transform = Transform3D(Basis.looking_at((aim - lp).normalized(), Vector3.UP), lp)
			root.add_child(l)
			spots.append(l)
			i += 1


# --- Perimeter boards ---


## One mesh with every board panel on the stands' front walls (facing the field), textured from an
## atlas of pixel sponsor panels, slightly emissive (LED boards).
func _build_boards() -> void:
	var atlas := _board_atlas()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_designs := SPONSORS.size()
	var k := 0
	var y0 := 0.27
	var y1 := y0 + PANEL.y
	# Each run: start, direction along the wall, normal (towards the field), length.
	var runs := [
		[Vector3(-IN_X, 0, -IN_Z + 0.02), Vector3.RIGHT, Vector3.BACK, IN_X * 2.0],
		[Vector3(IN_X, 0, IN_Z - 0.02), Vector3.LEFT, Vector3.FORWARD, IN_X * 2.0],
		[Vector3(IN_X - 0.02, 0, -IN_Z), Vector3.BACK, Vector3.LEFT, IN_Z * 2.0],
		[Vector3(-IN_X + 0.02, 0, IN_Z), Vector3.FORWARD, Vector3.RIGHT, IN_Z * 2.0],
	]
	for r in runs:
		var start: Vector3 = r[0]
		var dir: Vector3 = r[1]
		var nrm: Vector3 = r[2]
		var length: float = r[3]
		var n := floori(length / PANEL.x)
		for i in n:
			var a := start + dir * (i * PANEL.x)
			var b := a + dir * PANEL.x
			var mid := (a + b) * 0.5
			if absf(mid.z) < 3.0 and absf(absf(mid.x) - IN_X) < 0.1:
				continue  # tunnel mouth
			var d := (k * 3 + i) % n_designs
			k += 1
			var u0 := float(d) / n_designs
			var u1 := float(d + 1) / n_designs
			var q := [
				[Vector3(a.x, y0, a.z), Vector2(u0, 1)],
				[Vector3(a.x, y1, a.z), Vector2(u0, 0)],
				[Vector3(b.x, y1, b.z), Vector2(u1, 0)],
				[Vector3(b.x, y0, b.z), Vector2(u1, 1)],
			]
			# Clockwise seen from the field (the front face).
			var order := (
				[0, 1, 2, 0, 2, 3] if dir.cross(Vector3.UP).dot(nrm) > 0.0 else [0, 2, 1, 0, 3, 2]
			)
			for j in order:
				st.set_normal(nrm)
				st.set_uv(q[j][1])
				st.add_vertex(q[j][0])
	var mi := MeshInstance3D.new()
	mi.name = "Boards"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.emission_enabled = true
	mat.emission_texture = atlas
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.5
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _board_atlas() -> ImageTexture:
	var n := SPONSORS.size()
	var img := Image.create(PANEL_PX.x * n, PANEL_PX.y, false, Image.FORMAT_RGBA8)
	for i in n:
		var cols: Array = PANEL_COLORS[i % PANEL_COLORS.size()]
		var bg: Color = cols[0]
		var fg: Color = cols[1]
		var x0 := i * PANEL_PX.x
		img.fill_rect(Rect2i(x0, 0, PANEL_PX.x, PANEL_PX.y), bg)
		img.fill_rect(Rect2i(x0, 0, PANEL_PX.x, 1), bg.darkened(0.35))
		img.fill_rect(Rect2i(x0, PANEL_PX.y - 1, PANEL_PX.x, 1), bg.darkened(0.35))
		img.fill_rect(Rect2i(x0, 0, 1, PANEL_PX.y), bg.darkened(0.25))
		var text: String = SPONSORS[i]
		var words := text.split(" ")
		if PixelText.width(text) <= PANEL_PX.x - 4:
			PixelText.draw_centred(img, text, x0, x0 + PANEL_PX.x, 5, fg)
		else:
			PixelText.draw_centred(img, words[0], x0, x0 + PANEL_PX.x, 2, fg)
			PixelText.draw_centred(img, " ".join(words.slice(1)), x0, x0 + PANEL_PX.x, 9, fg)
	return ImageTexture.create_from_image(img)


# --- Scoreboards ---


func _build_scoreboards() -> void:
	_ball_tex = [
		ImageTexture.create_from_image(StadiumParts.ball_image(16, true)),
		ImageTexture.create_from_image(StadiumParts.ball_image(16, false)),
	]
	# Main board on the back stand: legs on the top walkway, facing the field (+z).
	var w_v := 72
	var h_v := 28
	var legs_v := 12
	var bm := _model("board_main", func() -> VoxelGrid: return StadiumParts.board(w_v, h_v, legs_v))
	var main := ArenaVoxels.instance(bm, "MainBoard")
	var walk_d := (StadiumParts.FRONT_V + StadiumParts.ROWS * StadiumParts.ROW_V + 3) * VoxelGrid.VS
	main.position = Vector3(0, StadiumParts.TOP_V * VoxelGrid.VS, -IN_Z - walk_d)
	main.rotation.y = PI
	add_child(main)
	var em := _model("emblem", func() -> VoxelGrid: return StadiumParts.emblem(10))
	var e := ArenaVoxels.instance(em, "Emblem")
	var by := (legs_v + 1) * VoxelGrid.VS
	e.position = Vector3(0, by + 4.0, -0.5)
	main.add_child(e)
	var b := {}
	var w := w_v * VoxelGrid.VS
	for side in 2:
		# Seen from the field, side A (-x) is on the left: local +x after the half turn.
		var sx := 1.0 if side == 0 else -1.0
		var cx := sx * (w * 0.5 - 3.4)
		b["name%d" % side] = _label(main, Vector3(cx, by + 5.6, -0.06), 110, 0.011)
		b["count%d" % side] = _label(main, Vector3(cx, by + 2.5, -0.06), 90, 0.011)
		b["balls%d" % side] = _balls(main, Vector3(cx, by + 4.0, -0.07), 1.0)
	b["clock"] = _label(main, Vector3(0, by + 0.95, -0.6), 120, 0.009)
	b["scene"] = _label(main, Vector3(w * 0.5 - 3.4, by + 0.95, -0.06), 80, 0.009)
	b["series"] = _label(main, Vector3(-(w * 0.5 - 3.4), by + 0.95, -0.06), 80, 0.009)
	_boards["main"] = b
	# End boards on stilts behind each end, facing the field and turned towards the camera side.
	var eb := _model("board_end", func() -> VoxelGrid: return StadiumParts.board(36, 20, 36))
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var node := ArenaVoxels.instance(eb, "EndBoard%d" % side)
		node.position = Vector3(sx * (IN_X + StadiumParts.DEPTH + 4.0), 0, -4.0)
		var turn := PI * 0.5 + deg_to_rad(28.0)
		node.rotation.y = -turn if side == 0 else turn
		add_child(node)
		var y := 37 * VoxelGrid.VS
		var eb_d := {}
		eb_d["name"] = _label(node, Vector3(0, y + 3.7, -0.06), 110, 0.0075)
		eb_d["balls"] = _balls(node, Vector3(0, y + 2.3, -0.07), 0.85)
		eb_d["clock"] = _label(node, Vector3(0, y + 0.9, -0.06), 90, 0.007)
		_boards["end%d" % side] = eb_d


func _label(parent: Node3D, at: Vector3, size: int, px: float) -> Label3D:
	var l := Label3D.new()
	l.font = Kit.title_font()
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = Color(1.5, 1.45, 1.3)
	l.position = at
	l.set_meta("px", px)
	l.rotation.y = PI  # faces -z (the board's front)
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


## Row of six Poke Ball sprites centred on `at`, `step` m apart (the team's slots).
func _balls(parent: Node3D, at: Vector3, step: float) -> Array:
	var out: Array = []
	for i in 6:
		var s := Sprite3D.new()
		s.texture = _ball_tex[0]
		s.pixel_size = step * 0.85 / 16.0
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.double_sided = false
		s.rotation.y = PI
		s.position = at + Vector3((i - 2.5) * step, 0, 0)
		s.set_meta("cx", at.x)
		s.set_meta("step", step)
		s.modulate = Color(1.3, 1.3, 1.3)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(s)
		out.append(s)
	return out


## Live scoreboard info (TrainingBattle._refresh_info): names [a, b], alive: [[bool...], [bool...]],
## clock (String), scene (String), series (String).
func score(info: Dictionary) -> void:
	var key := str(info)
	if key == _score_key:
		return
	_score_key = key
	var nm: Array = info.get("names", names)
	var alive: Array = info.get("alive", [[], []])
	var mb: Dictionary = _boards.get("main", {})
	for side in 2:
		var team: Array = alive[side] if side < alive.size() else []
		var up := team.count(true)
		var text := String(nm[side]).to_upper()
		if mb.has("name%d" % side):
			_fit(mb["name%d" % side], text, 8)
			mb["count%d" % side].text = "%d/%d" % [up, team.size()]
			_set_balls(mb["balls%d" % side], team)
		var eb: Dictionary = _boards.get("end%d" % side, {})
		if not eb.is_empty():
			_fit(eb.name, text, 9)
			eb.clock.text = String(info.get("clock", ""))
			_set_balls(eb.balls, team)
	if mb.has("clock"):
		mb.clock.text = String(info.get("clock", ""))
		_fit(mb.scene, String(info.get("scene", "")).to_upper(), 10)
		mb.series.text = String(info.get("series", ""))


## Sets a board label, shrinking it when the text is longer than `fit` characters.
static func _fit(l: Label3D, text: String, fit: int) -> void:
	l.text = text
	l.pixel_size = float(l.get_meta("px")) * minf(1.0, float(fit) / maxf(1.0, text.length()))


func _set_balls(balls: Array, team: Array) -> void:
	for i in balls.size():
		var s: Sprite3D = balls[i]
		s.visible = i < team.size()
		if i < team.size():
			s.texture = _ball_tex[0 if team[i] else 1]
		# Centre the row on the team size.
		s.position.x = (
			float(s.get_meta("cx")) + (i - (team.size() - 1) * 0.5) * float(s.get_meta("step"))
		)


# --- Flags ---


func _build_flags() -> void:
	var root := Node3D.new()
	root.name = "Flags"
	add_child(root)
	var designs := _flag_textures()
	var pole := _model("pole", _pole_grid)
	var wind := WorldWind.BASE_DIR.normalized()
	var yaw := atan2(-wind.y, wind.x)
	var h := StadiumParts.HEIGHT
	var back := (StadiumParts.DEPTH_V - 1) * VoxelGrid.VS
	var spots_at: Array = []
	# Back and ends only: a pole on the +z parapet would poke into the action camera's sight lines.
	for i in 7:
		var x := -IN_X + i * 10.0
		spots_at.append(Vector3(x, h, -IN_Z - back))
	for i in 6:
		var z := -IN_Z + i * 8.0
		spots_at.append(Vector3(-IN_X - back, h, z))
		spots_at.append(Vector3(IN_X + back, h, z))
	var mat_base := ShaderMaterial.new()
	mat_base.shader = FLAG_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.0)
	quad.center_offset = Vector3(0.8, 0, 0)
	quad.subdivide_width = 12
	quad.subdivide_depth = 2
	for i in spots_at.size():
		var at: Vector3 = spots_at[i]
		var p := ArenaVoxels.instance(pole, "Pole%d" % i)
		p.position = at
		root.add_child(p)
		var f := MeshInstance3D.new()
		f.name = "Flag%d" % i
		f.mesh = quad
		var m := mat_base.duplicate() as ShaderMaterial
		m.set_shader_parameter("tex", designs[i % designs.size()])
		m.set_shader_parameter("phase", float(i) * 1.37)
		f.material_override = m
		f.position = at + Vector3(0, 3.35, 0)
		f.rotation.y = yaw
		root.add_child(f)


## Fan banners hanging on the inner face of the back and end parapets (over the top walkway, facing
## the field): cloth quads waving gently with the wind (flag.gdshader, hang mode), in the colours of
## the side whose fans sit there. None on the camera side and none behind the main scoreboard.
func _build_banners() -> void:
	var root := Node3D.new()
	root.name = "Banners"
	add_child(root)
	var mat_base := ShaderMaterial.new()
	mat_base.shader = FLAG_SHADER
	mat_base.set_shader_parameter("hang", 1.0)
	mat_base.set_shader_parameter("span", BANNER.y)
	mat_base.set_shader_parameter("amp", 0.05)
	var quad := QuadMesh.new()
	quad.size = BANNER
	quad.center_offset = Vector3(0, -BANNER.y * 0.5, 0)
	quad.subdivide_width = 16
	quad.subdivide_depth = 4
	var inner := (StadiumParts.DEPTH_V - StadiumParts.PARA_V) * VoxelGrid.VS - 0.09
	var top := StadiumParts.HEIGHT - 0.12
	var spots_at: Array = []  # [position, yaw, team]
	for x in [-25.0, -15.0, 15.0, 25.0]:
		spots_at.append([Vector3(x, top, -IN_Z - inner), 0.0, 0 if x < 0.0 else 1])
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		spots_at.append([Vector3(-IN_X - inner, top, z), PI * 0.5, 0])
		spots_at.append([Vector3(IN_X + inner, top, z), -PI * 0.5, 1])
	var designs := [_banner_textures(0), _banner_textures(1)]
	for i in spots_at.size():
		var s: Array = spots_at[i]
		var b := MeshInstance3D.new()
		b.name = "Banner%d" % i
		b.mesh = quad
		var m := mat_base.duplicate() as ShaderMaterial
		var texs: Array = designs[int(s[2])]
		m.set_shader_parameter("tex", texs[i % texs.size()])
		m.set_shader_parameter("phase", float(i) * 2.11)
		b.material_override = m
		b.position = s[0]
		b.rotation.y = float(s[1])
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b)


## Banner designs of a side (BANNER_PX images): team colour with a cheer and Poke Balls, white with
## the cheer in the team colour, and team stripes with a big ball.
static func _banner_textures(team: int) -> Array:
	var c: Color = StadiumParts.TEAM[team]
	var dk: Color = StadiumParts.TEAM_DARK[team]
	var white := Color("f4f2ec")
	var w := BANNER_PX.x
	var h := BANNER_PX.y
	var out: Array = []
	for d in 3:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cheer: String = BANNER_CHEERS[(team * 3 + d) % BANNER_CHEERS.size()]
		match d:
			0:
				img.fill(c)
				img.fill_rect(Rect2i(0, 0, w, 2), white)
				img.fill_rect(Rect2i(0, h - 2, w, 2), white)
				PixelText.draw_centred(img, cheer, 10, w - 10, 3, white, 2)
				_flag_ball(img, Vector2(5.5, h * 0.5), 4.0)
				_flag_ball(img, Vector2(w - 5.5, h * 0.5), 4.0)
			1:
				img.fill(white)
				img.fill_rect(Rect2i(0, 0, w, 1), dk)
				img.fill_rect(Rect2i(0, h - 1, w, 1), dk)
				PixelText.draw_centred(img, cheer, 0, w, 3, c, 2)
			_:
				for x in w:
					img.fill_rect(Rect2i(x, 0, 1, h), c if ((x + 8) / 8) % 2 == 0 else dk)
				_flag_ball(img, Vector2(w * 0.5, h * 0.5), 6.5)
		# Ragged bottom edge (a few transparent texels) so the cloth reads as cloth.
		for x in range(0, w, 5):
			img.set_pixel(x, h - 1, Color(0, 0, 0, 0))
		out.append(ImageTexture.create_from_image(img))
	return out


static func _pole_grid() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-1, -1, -1), Vector3i(2, 18, 2))
	for y in 16:
		g.put(Vector3i(0, y, 0), StadiumParts.C_METAL, VoxelMat.METAL, ArenaVoxels.BODY)
	g.put(Vector3i(0, 16, 0), Color("e8c050"), VoxelMat.METAL, ArenaVoxels.BODY)
	g.put(Vector3i(0, -1, 0), Color.BLACK, VoxelMat.STONE, ArenaVoxels.CTX)
	return g


## Flag designs (pixel images, 1/16 m texels): the two teams with a ball, the Poke Ball, the league
## (blue and yellow), green and white, orange stripes.
static func _flag_textures() -> Array:
	var out: Array = []
	var w := 26
	var h := 16
	for d in 6:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		match d:
			0, 1:
				var c: Color = StadiumParts.TEAM[d]
				img.fill(c)
				img.fill_rect(Rect2i(0, h - 3, w, 3), c.darkened(0.3))
				_flag_ball(img, Vector2(w * 0.55, h * 0.45), 4.5)
			2:
				img.fill(Color("f4f2ec"))
				img.fill_rect(Rect2i(0, 0, w, h / 2), Color("e23a2e"))
				img.fill_rect(Rect2i(0, h / 2 - 1, w, 2), Color("1e1e22"))
				_flag_ball(img, Vector2(w * 0.5, h * 0.5), 3.0)
			3:
				img.fill(Color("2a5bb8"))
				img.fill_rect(Rect2i(0, h / 3, w, h / 3), Color("f2c230"))
			4:
				for x in w:
					img.fill_rect(
						Rect2i(x, 0, 1, h), Color("36a456") if (x / 4) % 2 == 0 else Color("f4f2ec")
					)
			_:
				for y in h:
					img.fill_rect(
						Rect2i(0, y, w, 1), Color("e47a2e") if (y / 3) % 2 == 0 else Color("f4f2ec")
					)
		img.fill_rect(Rect2i(0, 0, 1, h), Color("6f7a86"))
		out.append(ImageTexture.create_from_image(img))
	return out


static func _flag_ball(img: Image, c: Vector2, r: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				continue
			var col := Color("f4f2ec")
			if y + 0.5 < c.y:
				col = Color("f4f2ec") if d < r * 0.35 else Color("e23a2e").lightened(0.15)
			if d > r - 1.0 or absf(y + 0.5 - c.y) < 0.8:
				col = Color("1e1e22")
			img.set_pixel(x, y, col)


# --- Ground: concourse ring (0.25 m), plaza and lawns (1 m) ---


## Concourse between the field floor (ArenaFloor: field + MARGIN) and the stands' front walls, at
## the lattice of the floor so they meet seamlessly; painted like the floor's surround (theme()).
func _build_ring() -> void:
	var g := ArenaVoxels.box(Vector3(-IN_X, -0.25, -IN_Z), Vector3(IN_X, 0.0, IN_Z))
	_ring_grid = g
	_paint_ring("campo")
	var m := ArenaVoxels.model(g)
	var node := ArenaVoxels.instance(m, "Concourse", {}, false)
	add_child(node)
	_ring_mi = node.get_child(0) as MeshInstance3D


func _paint_ring(sc: String) -> void:
	var g := _ring_grid
	var p := ArenaPalette.of(sc if sc != "" else "campo")
	var half := Cfg.ARENA_ENERGY * 0.5 + Vector2.ONE * ArenaFloor.MARGIN
	for z in range(g.origin.z, g.origin.z + g.size.z):
		for x in range(g.origin.x, g.origin.x + g.size.x):
			var v := Vector3i(x, -1, z)
			var c := VoxelGrid.centre(v)
			if absf(c.x) < half.x and absf(c.z) < half.y:
				g.clear(v)
				continue
			var out: Array = ArenaFloor.surround_voxel(p, x, z)
			# Gutter along the stand walls, the trainers' carpet from the tunnel.
			if absf(c.x) > IN_X - 0.25 or absf(c.z) > IN_Z - 0.25:
				out = [Color("4f4a44"), VoxelMat.STONE]
			elif absf(c.z) < 1.0 and absf(c.x) > half.x - 0.25:
				var side := 0 if c.x < 0.0 else 1
				var tc: Color = StadiumParts.TEAM[side]
				if absf(c.z) > 0.75:
					tc = Color("f4f2ec")
				out = [ArenaPalette.jit(tc, v, 0.03), VoxelMat.CLOTH]
			g.put(v, out[0], out[1], ArenaVoxels.BODY)


## Plaza (paving ring around the stands, avenues out to the edge), hedges, flowerbeds and lawns on
## 1 m voxels, from the stands out to GROUND_HALF. The inner rectangle (field + concourse) is open.
func _build_ground() -> void:
	var g := VoxelGrid.new(
		Vector3i(-int(GROUND_HALF.x), -1, -int(GROUND_HALF.y)),
		Vector3i(int(GROUND_HALF.x) * 2, 2, int(GROUND_HALF.y) * 2)
	)
	_ground_grid = g
	_paint_ground("green")
	var m := ArenaVoxels.model(g, 1.0)
	var node := ArenaVoxels.instance(m, "Ground", {}, true)
	add_child(node)
	_ground_mi = node.get_child(0) as MeshInstance3D
	_build_lamps()


## Distance (m) from (x, z) out of the stands' outer footprint (<= 0 inside).
static func _out_of_stands(x: float, z: float) -> float:
	var ox := absf(x) - (IN_X + StadiumParts.DEPTH + 0.25)
	var oz := absf(z) - (IN_Z + StadiumParts.DEPTH + 0.25)
	return maxf(ox, oz)


static func _avenue(x: float, z: float) -> bool:
	return absf(x) < 3.0 or absf(z) < 3.0


func _paint_ground(lawn: String) -> void:
	var g := _ground_grid
	var cols: Array = LAWNS.get(lawn, LAWNS.green)
	var snowy := lawn == "snow"
	for z in range(g.origin.z, g.origin.z + g.size.z):
		for x in range(g.origin.x, g.origin.x + g.size.x):
			var c := Vector2(x + 0.5, z + 0.5)
			var v := Vector3i(x, -1, z)
			var up := Vector3i(x, 0, z)
			g.clear(up)
			if absf(c.x) < IN_X and absf(c.y) < IN_Z:
				g.clear(v)
				continue
			var d := _out_of_stands(c.x, c.y)
			var h := VoxelGrid.hash01(x, 3, z, 21)
			var col: Color
			var mat := VoxelMat.GRASS
			if d < PLAZA or (_avenue(c.x, c.y) and d < GROUND_HALF.y):
				var pv: Color = C_PAVE[(posmod(x, 2) + posmod(z, 2) * 2 + int(h * 2.0)) % 3]
				if absi(roundi(d) - PLAZA) <= 0 and d < PLAZA:
					pv = Color("8f887c")
				col = pv
				mat = VoxelMat.SLAB
				if snowy:
					col = col.lerp(Color("e6ecf2"), 0.55)
			else:
				var stripe := posmod(floori((c.x if absf(c.x) > absf(c.y) else c.y) / 4.0), 2)
				col = cols[stripe]
				var n := ArenaPalette.noise(c.x / 9.0, c.y / 9.0, 4)
				if n > 0.7:
					col = cols[3].lerp(col, 0.5)
				elif h > 0.97:
					col = cols[2]
				if lawn == "sand":
					mat = VoxelMat.SAND
				elif snowy:
					mat = VoxelMat.SNOW
				# Hedge with gaps at the avenues, flowerbeds inside it.
				if (
					d >= PLAZA
					and d < PLAZA + 1
					and not _avenue(c.x, c.y)
					and absf(c.x) > 6.0
					and absf(c.y) > 6.0
				):
					var hc := C_HEDGE if not snowy else Color("e6ecf2")
					if lawn == "ash":
						hc = Color("4a443f")
					g.put(up, ArenaPalette.jit(hc, up, 0.08), VoxelMat.LEAVES, ArenaVoxels.BODY)
				elif d >= PLAZA - 2 and d < PLAZA and posmod(floori((c.x + c.y) / 3.0), 4) == 0:
					if not _avenue(c.x, c.y) and lawn in ["green", "dark", "swamp"]:
						var fc: Color = FLOWERS[
							int(VoxelGrid.hash01(x / 3, 0, z / 3, 8) * FLOWERS.size())
							% FLOWERS.size()
						]
						g.put(v, ArenaPalette.jit(fc, v, 0.08), VoxelMat.FLOWER, ArenaVoxels.BODY)
						continue
			g.put(v, ArenaPalette.jit(col, v, 0.04), mat, ArenaVoxels.BODY)


func _build_lamps() -> void:
	var lamp := _model("plaza_lamp", _lamp_grid)
	var root := Node3D.new()
	root.name = "Lamps"
	add_child(root)
	var ox := IN_X + StadiumParts.DEPTH + PLAZA - 1.5
	var oz := IN_Z + StadiumParts.DEPTH + PLAZA - 1.5
	var pts: Array = []
	var step := 9.0
	var nx := floori(ox * 2.0 / step)
	var nz := floori(oz * 2.0 / step)
	for i in nx + 1:
		var x := -ox + i * ox * 2.0 / nx
		pts.append(Vector3(x, 0, -oz))
		pts.append(Vector3(x, 0, oz))
	for i in range(1, nz):
		var z := -oz + i * oz * 2.0 / nz
		pts.append(Vector3(-ox, 0, z))
		pts.append(Vector3(ox, 0, z))
	for i in pts.size():
		var p: Vector3 = pts[i]
		if _avenue(p.x, p.z):
			continue
		var n := ArenaVoxels.instance(lamp, "Lamp%d" % i)
		n.position = p
		root.add_child(n)


static func _lamp_grid() -> VoxelGrid:
	var g := VoxelGrid.new(Vector3i(-2, -1, -2), Vector3i(4, 17, 4))
	for y in 14:
		g.put(Vector3i(0, y, 0), Color("3b4048"), VoxelMat.METAL, ArenaVoxels.BODY)
	g.put(Vector3i(0, 0, 0), Color("2b2f35"), VoxelMat.METAL, ArenaVoxels.BODY)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			g.put(Vector3i(dx, 14, dz), Color("ffe2a0"), VoxelMat.LAMP, ArenaVoxels.BODY)
			g.put(Vector3i(dx, 15, dz), Color("3b4048"), VoxelMat.METAL, ArenaVoxels.BODY)
	return g


## Trees on the lawns (MultiMesh per model part, a few sectors so they cull): denser further out.
static func _tree_grid(kind: String, v: int) -> VoxelGrid:
	match kind:
		"palm":
			return StadiumParts.palm(v)
		"dead":
			return StadiumParts.dead_tree(v)
	return ArenaPropsVox._tree_grid(kind, v)


func _plant_trees(kind: String, tint: Color) -> void:
	for c in _trees.get_children():
		_trees.remove_child(c)  # out now, so the new ones keep their names
		c.queue_free()
	var vars: Array = []
	for v in 3:
		var key := "%s_%s_%d" % ["tree", kind, v]
		vars.append(ArenaVoxels.cached(key, func() -> VoxelGrid: return _tree_grid(kind, v)))
	# Placement on a jittered 6 m grid, by position hash only.
	var by := {}  # "variant_sector" -> Array[Transform3D]
	var cell := 6.0
	var nx := int(GROUND_HALF.x / cell)
	var nz := int(GROUND_HALF.y / cell)
	for iz in range(-nz, nz):
		for ix in range(-nx, nx):
			var hx := VoxelGrid.hash01(ix, 1, iz, 61)
			var hz := VoxelGrid.hash01(ix, 2, iz, 61)
			var p := Vector3((ix + 0.15 + hx * 0.7) * cell, 0, (iz + 0.15 + hz * 0.7) * cell)
			var d := _out_of_stands(p.x, p.z)
			if (
				d < PLAZA + 2.5
				or absf(p.x) > GROUND_HALF.x - 2.0
				or absf(p.z) > GROUND_HALF.y - 2.0
			):
				continue
			if absf(p.x) < 5.0 or absf(p.z) < 5.0:
				continue  # avenues
			var dens := clampf(0.18 + (d - PLAZA) * 0.012, 0.18, 0.75)
			if VoxelGrid.hash01(ix, 3, iz, 61) > dens:
				continue
			var v := int(VoxelGrid.hash01(ix, 4, iz, 61) * 3.0) % 3
			var s := 1.9 + VoxelGrid.hash01(ix, 5, iz, 61) * 0.9
			var t := Transform3D(
				Basis(Vector3.UP, VoxelGrid.hash01(ix, 6, iz, 61) * TAU).scaled(Vector3(s, s, s)), p
			)
			var sector := ("n" if p.z < 0.0 else "s") + ("w" if p.x < 0.0 else "e")
			var near := "1" if d < PLAZA + 30.0 else "0"
			var k := "%d_%s%s" % [v, sector, near]
			if not by.has(k):
				by[k] = []
			by[k].append(t)
	for k in by:
		var v := int(String(k).get_slice("_", 0))
		var m: ArenaVoxels.Model = vars[v]
		var xs: Array = by[k]
		var near := String(k).ends_with("1")
		for prt in m.meshes:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m.meshes[prt]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i])
			var mi := MultiMeshInstance3D.new()
			mi.name = "Trees_%s_%d" % [k, prt]
			mi.multimesh = mm
			var pp := {"voxel": m.vs, "tint": tint}
			if prt == ArenaVoxels.TOP:
				pp["sway"] = 0.012
				pp["sway_base"] = 2.5
			mi.material_override = VoxelMat.material(m.grid, m.tex, m.tops, pp)
			if not near:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_trees.add_child(mi)


# --- Environment, sun and moods ---


func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://battle/voxel/stadium_sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = SATURATION
	env.adjustment_contrast = 1.04
	world_env = WorldEnvironment.new()
	world_env.name = "StadiumEnv"
	world_env.environment = env
	add_child(world_env)
	# Follows Opções > Gráficos (SSAO quality; never MSAA, which empties the water's depth reads).
	GfxQuality.track(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	set_mood(mood)


## Time of day (MOODS key). Sets the sun, sky, ambient, fog, lamps and floodlights; a scenario
## theme (theme()) may darken it further afterwards.
func set_mood(m: String) -> void:
	mood = m if MOODS.has(m) else "dia"
	var md: Dictionary = MOODS[mood].duplicate()
	_apply(md, true)


## Applies a mood dictionary; `light` false leaves the sun energy and the ambient colour alone
## (BattleBiomes has already scaled them for this fight).
func _apply(md: Dictionary, light: bool) -> void:
	_mood_now = md
	var elev := deg_to_rad(float(md.elev))
	var azim := deg_to_rad(float(md.azim))
	var to_sun := Vector3(sin(azim) * cos(elev), sin(elev), cos(azim) * cos(elev))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.BACK)
	sun.light_color = md.sun
	if light:
		_sun_base = float(md.sun_e)
		_amb_base = float(md.amb_e)
		_sun_set = -1.0  # a fresh base: not someone else's change
		_amb_set = -1.0
		env.ambient_light_color = md.ambient
	env.tonemap_exposure = float(md.get("exposure", 1.0))
	sky_mat.set_shader_parameter("top_color", md.top)
	sky_mat.set_shader_parameter("horizon_color", md.horizon)
	sky_mat.set_shader_parameter("ground_color", md.ground)
	sky_mat.set_shader_parameter("glow_color", md.glow)
	sky_mat.set_shader_parameter("disc_color", md.disc)
	sky_mat.set_shader_parameter("cloud_color", md.cloud)
	sky_mat.set_shader_parameter("cloud_shade", md.cloud_shade)
	sky_mat.set_shader_parameter("clouds", float(md.clouds))
	sky_mat.set_shader_parameter("stars", float(md.stars))
	sky_mat.set_shader_parameter("sun_dir", to_sun)
	sky_mat.set_shader_parameter("disc_energy", 1.4 if float(md.stars) > 0.0 else 6.0)
	sky_mat.set_shader_parameter("disc_size", 0.03 if float(md.stars) > 0.0 else 0.04)
	var windows := float(md.windows)
	_global("night_windows", windows)
	for l in tunnel_lights:
		l.light_energy = 1.4 * windows
		l.visible = windows > 0.05
	# The water reads the sun and the sky from the globals (TimeOfDay does it in the world).
	_global("sun_dir_world", to_sun)
	_global("sun_color_world", md.sun)
	_light()


## The battle weather asks for its light (BattleWeatherFx in training, every frame while there is
## weather; 0, 0 when the fight ends): `c` 0..1 how overcast, `f` 0..1 the lightning flash. The
## sky shader reads cloud_cover and lightning_flash itself; this does the light the stadium owns.
func weather_light(c: float, f := 0.0) -> void:
	c = clampf(c, 0.0, 1.0)
	f = clampf(f, 0.0, 1.0)
	var same := is_equal_approx(c, cloud) and is_equal_approx(f, flash)
	if (
		same
		and is_equal_approx(sun.light_energy, _sun_set)
		and is_equal_approx(env.ambient_light_energy, _amb_set)
	):
		return
	cloud = c
	flash = f
	_light()


## Ground the battle weather covers (BattleWeatherFx sizes its rain and snow from it): the field
## and the whole bowl of stands out to the parapet, centred on the field.
func weather_area() -> Rect2:
	var hx := IN_X + StadiumParts.DEPTH + WEATHER_PAD
	var hz := IN_Z + StadiumParts.DEPTH + WEATHER_PAD
	return Rect2(global_position.x - hx, global_position.z - hz, hx * 2.0, hz * 2.0)


## Sun, ambient, fog, floodlights and the light globals from the mood (_mood_now) and the weather.
## A sun or ambient energy someone else changed since we last set it (BattleBiomes scales them at
## the start of a fight and puts them back at its end) becomes the new base, minus our factor.
func _light() -> void:
	var md := _mood_now
	if md.is_empty() or sun == null or env == null:
		return
	if _sun_base < 0.0 or (_sun_set >= 0.0 and not is_equal_approx(sun.light_energy, _sun_set)):
		_sun_base = sun.light_energy / maxf(_k_sun, 0.05)
	if (
		_amb_base < 0.0
		or (_amb_set >= 0.0 and not is_equal_approx(env.ambient_light_energy, _amb_set))
	):
		_amb_base = env.ambient_light_energy / maxf(_k_amb, 0.05)
	var c := cloud
	_k_sun = 1.0 - CLOUD_SUN_DIM * c
	_k_amb = (1.0 + CLOUD_AMBIENT * c) * (1.0 + FLASH_AMBIENT * flash)
	_sun_set = _sun_base * _k_sun
	_amb_set = _amb_base * _k_amb
	sun.light_energy = _sun_set
	sun.shadow_opacity = 1.0 - CLOUD_SHADOW * c
	env.ambient_light_energy = _amb_set
	env.adjustment_saturation = SATURATION * (1.0 - CLOUD_DESAT * c)
	# Rain haze: the distance (outer stands, trees) fades into a darker grey; the field stays clear.
	env.fog_light_color = overcast(md.fog, c) * (1.0 - CLOUD_FOG_DARK * c)
	env.fog_depth_begin = float(md.fog_begin) * (1.0 - CLOUD_FOG * c)
	env.fog_depth_end = float(md.fog_end) * (1.0 - CLOUD_FOG * 2.0 * c)
	# A dark storm switches the floodlights on, even by day.
	var storm := smoothstep(STORM_LIGHTS.x, STORM_LIGHTS.y, c)
	var se := maxf(float(md.spots), STORM_SPOTS * storm)
	for l in spots:
		l.light_energy = se
		l.visible = se > 0.01
		l.spot_attenuation = float(md.get("spot_att", SPOT_ATT))
		l.light_color = md.get("spot_color", SPOT_COLOR)
	_global("night_lamps", maxf(float(md.lamps), STORM_LAMPS * storm))
	var elev := deg_to_rad(float(md.elev))
	_global("sun_amount", clampf(float(md.sun_e) * sin(elev) * 1.2, 0.0, 1.0) * _k_sun)
	_global("sky_top_color", overcast(md.top, c))
	_global("sky_horizon_color", overcast(md.horizon, c))


## A sky / fog colour under cloud `c`: towards a dim blue-grey of its own brightness, the same
## blend stadium_sky.gdshader applies to the dome (so the water's sky globals match the sky).
static func overcast(col: Color, c: float) -> Color:
	var l := col.get_luminance()
	var grey := Color(l * 0.9 * 0.82, l * 0.93 * 0.82, l * 0.82)
	return col.lerp(grey, 0.75 * clampf(c, 0.0, 1.0))


## Retints the surroundings for the scenario and applies its sky (caverna: night; pantano:
## overcast; vulcao: hazy red). Called after the fight's arena started (BattleBiomes already set
## the sun energy and ambient colour), so it never touches those.
func theme(sc: String) -> void:
	var th: Dictionary = THEMES.get(sc, {})
	var lawn := String(th.get("lawn", "green"))
	if scenario == "" or sc != scenario:
		_paint_ground(lawn)
		_refresh_grid(_ground_mi, _ground_grid)
		_paint_ring(sc if sc != "" else "campo")
		_refresh_grid(_ring_mi, _ring_grid)
		var kind := String(th.get("trees", "campo"))
		_plant_trees(kind, th.get("tree_tint", Color.WHITE))
	scenario = sc if sc != "" else "campo"
	var md: Dictionary = MOODS[mood].duplicate()
	if bool(th.get("night", false)):
		md = MOODS.noite.duplicate()
	md.merge(th.get("sky", {}), true)
	_apply(md, false)


static func _refresh_grid(mi: MeshInstance3D, g: VoxelGrid) -> void:
	if mi == null:
		return
	var mat := mi.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("vox", g.texture())
		mat.set_shader_parameter("tops", g.tops_texture())


# --- Crowd ---


## The fans of `side` cheer (a knockout for their side, a big hit); amount 0..1 adds up.
func cheer(side: int, amount := 1.0) -> void:
	if side == 0:
		cheer_a = clampf(cheer_a + amount, 0.0, 1.0)
	else:
		cheer_b = clampf(cheer_b + amount, 0.0, 1.0)


## A Mexican wave around the bowl (starting on the camera's left).
func wave() -> void:
	_wave_t = 0.0
	ArenaCrowd.material().set_shader_parameter("wave_a0", PI * 0.75)


func waving() -> bool:
	return _wave_t >= 0.0


func _process(dt: float) -> void:
	cheer_a = move_toward(cheer_a, 0.0, dt * 0.3)
	cheer_b = move_toward(cheer_b, 0.0, dt * 0.3)
	if _wave_t >= 0.0:
		_wave_t += dt
		if _wave_t > ArenaCrowd.WAVE_SECS:
			_wave_t = -1.0
	var m := ArenaCrowd.material()
	m.set_shader_parameter("cheer_a", cheer_a)
	m.set_shader_parameter("cheer_b", cheer_b)
	m.set_shader_parameter("wave_tw", _wave_t)
