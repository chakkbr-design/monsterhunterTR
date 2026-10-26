extends SceneTree
## Screenshots of the continuous sky on a small voxel village (needs a GPU or lavapipe):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan \
##     --resolution 1600x900 --script res://tests/world/shot_sky_voxel.gd -- \
##     --out=/tmp/sky/vox [--hours=05:30,12:00] [--weather=rain] [--weathers=clear,rain,storm]
##     [--quality=alto] [--wide] [--focus=x,z (camera focus in m)] [--water-debug=1..6]
##     [--settle=N (frames before each picture, default 50)]
## Saves <out>_<HHMM>.png for 05:30, 06:30, 08:00, 12:00, 16:00, 17:45, 18:30, 19:15, 21:00 and 00:30
## by default; with --weathers, <out>_<weather>_<HHMM>.png for each weather and hour (the weather
## snaps to its settled look: wet ground, lying snow), and for "storm" also <..>_bolt.png, a frame
## right after a lightning strike in view. The scene is built like a voxel zone: stone and plaster houses with WINDOW voxels,
## lamp posts (LAMP voxels + OmniLights in NightLights), trees with swaying crowns, a cobble
## crossroads, a pond (carved BED + WaterSurface), a vegetable patch, flowers and three people,
## seen through the overworld camera (pitch 32°, 12 m, FOV 35°) and lit by the real
## WorldTimeOfDay, voxel_env.tres, wind, weather, ambience and post-fx.

const HOURS := [
	"05:30", "06:30", "08:00", "12:00", "16:00", "17:45", "18:30", "19:15", "21:00", "00:30"
]
const RIG_SCRIPT := (
	"extends Node3D\nfunc yaw() -> float:\n\treturn 0.0\n"
	+ "func set_zone_look(_look: Dictionary) -> void:\n\tpass\n"
)
const STONE_A := Color(0.6, 0.6, 0.62)
const STONE_B := Color(0.47, 0.47, 0.5)
const MORTAR := Color(0.36, 0.35, 0.36)
const ROOF_A := Color(0.88, 0.44, 0.17)
const ROOF_B := Color(0.73, 0.34, 0.12)
const PLASTER := Color(0.91, 0.87, 0.78)
const TIMBER := Color(0.36, 0.23, 0.14)
const WINDOW := Color(0.98, 0.66, 0.34)  ## warm amber: paler window colours read cream under AgX
const GRASS := Color(0.36, 0.58, 0.22)
const LEAF := Color(0.24, 0.48, 0.2)
const METAL := Color(0.16, 0.16, 0.18)
const WATER_Y := -0.12  ## pond surface 12 cm under the bank (gfx/water, shot_water_scene)
const FOUNTAIN_V := Vector3i(-20, 0, 13)  ## voxel at the fountain's centre column

var out := "user://shot_sky_voxel"
var hours: Array = HOURS.duplicate()
var wide := false
var focus := Vector3(-0.5, 0.4, 1.0)
var water_debug := 0
var weathers: Array = []
var settle := 50
var world: Node3D
var tod: WorldTimeOfDay
var wx: WorldWeather


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hours="):
			hours = Array(a.substr(8).split(","))
		elif a.begins_with("--weather="):
			WorldWeather.forced = a.substr(10)
		elif a == "--wide":
			wide = true
		elif a.begins_with("--focus="):
			var f := a.substr(8).split(",")
			focus = Vector3(float(f[0]), 0.4, float(f[1]))
		elif a.begins_with("--water-debug="):
			water_debug = int(a.substr(14))
		elif a.begins_with("--weathers="):
			weathers = Array(a.substr(11).split(","))
		elif a.begins_with("--settle="):
			settle = int(a.substr(9))
	if WorldWeather.forced == "":
		WorldWeather.forced = "clear"
	_run.call_deferred()


func _paint(base: Color, amt: float, salt := 0) -> Callable:
	return func(v: Vector3i) -> Color:
		var h := VoxelGrid.hash01(v.x, v.y, v.z, salt)
		return (
			base.lightened(amt * (h - 0.5) * 2.0)
			if h > 0.5
			else base.darkened(amt * (0.5 - h) * 2.0)
		)


func _cobble(v: Vector3i) -> Color:
	var row := floori(v.z / 2.0)
	var mortar := posmod(v.z, 2) == 0 and posmod(v.x + row, 3) == 0
	mortar = (
		mortar
		or (
			posmod(v.x + (row % 2) * 2, 3) == 0
			and posmod(v.z, 2) == 1
			and VoxelGrid.hash01(v.x, 0, v.z, 9) > 0.55
		)
	)
	if mortar:
		return MORTAR.darkened(0.1 * VoxelGrid.hash01(v.x, 1, v.z))
	var h := VoxelGrid.hash01(floori(v.x / 3.0), 0, row, 3)
	return STONE_A.lerp(STONE_B, h * 0.8).lightened(0.06 * VoxelGrid.hash01(v.x, 2, v.z))


func _stone_wall(v: Vector3i) -> Color:
	var course := floori(v.y / 2.0)
	var off := (course % 2) * 2
	if (
		posmod(v.y, 2) == 1 and VoxelGrid.hash01(v.x, v.y, v.z, 5) > 0.3
		or posmod(v.x + v.z + off, 4) == 0
	):
		return MORTAR.lightened(0.1)
	var h := VoxelGrid.hash01(floori((v.x + v.z + off) / 4.0), course, 0, 7)
	return Color(0.66, 0.65, 0.63).lerp(Color(0.5, 0.5, 0.52), h)


func _run() -> void:
	world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	world.add_child(sun)
	var rig := Node3D.new()
	var rs := GDScript.new()
	rs.source_code = RIG_SCRIPT
	rs.reload()
	rig.set_script(rs)
	rig.add_to_group("ow_camera")
	rig.position = focus
	world.add_child(rig)
	var cam := Camera3D.new()
	cam.fov = 35.0
	cam.far = 220.0
	var pitch := deg_to_rad(32.0 if not wide else 48.0)
	var dist := 12.0 if not wide else 26.0
	cam.position = Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0, 0)
	rig.add_child(cam)
	cam.make_current()
	for n: Node in [WorldPostFx.new(), WorldWind.new()]:
		n.name = "PostFX" if n is WorldPostFx else "Wind"
		world.add_child(n)
	tod = WorldTimeOfDay.new()
	tod.name = "TimeOfDay"
	world.add_child(tod)
	wx = WorldWeather.new()
	wx.name = "Weather"
	world.add_child(wx)
	var amb := WorldAmbient.new()
	amb.name = "Ambient"
	world.add_child(amb)
	tod.apply_location({"env": "voxel_env.tres"}, false)
	_build_village()
	_people()
	GfxQuality.apply_all(root)
	print("tier ", GfxQuality.NAMES[GfxQuality.tier()])
	for i in 30:
		await process_frame
	if weathers.is_empty():
		weathers = [""]
	for wname in weathers:
		if wname != "":
			WorldWeather.forced = wname
		for h in hours:
			tod.set_minute(SkyCycle.parse_hm(h))
			wx.snap()
			for i in settle:
				await process_frame
			var tag := String(h).replace(":", "")
			if wname != "":
				tag = "%s_%s" % [wname, tag]
			await _save("%s_%s.png" % [out, tag])
			if wname == "mist":  # the same frame with the ground mist switched off, to compare
				WorldWeather.mist_enabled = false
				for i in 2:
					await process_frame
				await _save("%s_%s_off.png" % [out, tag])
				WorldWeather.mist_enabled = true
			if wname == "storm":
				var l := wx.lightning
				l.strike(l.focus + Vector3(5.5, 0.0, -1.5))  # beside the player, in view
				for i in 2:
					await process_frame
				await _save("%s_%s_bolt.png" % [out, tag])
	quit(0)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	var st := tod.state
	print(
		(
			"saved %s exposure %.2f sun %.2f moon %.2f ambient %.2f sdfgi %s"
			% [
				path,
				st.exposure,
				st.sun_energy,
				st.moon_energy,
				st.ambient_energy,
				tod.env.sdfgi_enabled
			]
		)
	)


func _build_village() -> void:
	var g := VoxelGrid.new(Vector3i(-80, -8, -76), Vector3i(160, 48, 120))
	# Ground: grass over dirt.
	g.fill(
		Vector3i(-80, -8, -76),
		Vector3i(79, -4, 43),
		Color(0.42, 0.32, 0.22),
		VoxelMat.DIRT,
		0,
		_paint(Color(0.42, 0.32, 0.22), 0.1)
	)
	g.fill(
		Vector3i(-80, -3, -76),
		Vector3i(79, -1, 43),
		GRASS,
		VoxelMat.GRASS,
		0,
		_paint(GRASS, 0.14, 1)
	)
	# Cobble crossroads: east-west street and a north-south lane.
	g.fill(Vector3i(-80, -2, -6), Vector3i(79, -1, 5), STONE_A, VoxelMat.STONE, 0, _cobble)
	g.fill(Vector3i(-5, -2, -76), Vector3i(4, -1, -6), STONE_A, VoxelMat.STONE, 0, _cobble)
	# Kerb stones along the street.
	for x in range(-80, 80):
		if x < -5 or x > 4:
			g.put(
				Vector3i(x, -1, -7),
				STONE_B.darkened(0.1 * VoxelGrid.hash01(x, 0, 0)),
				VoxelMat.SLAB
			)
		g.put(Vector3i(x, -1, 6), STONE_B.darkened(0.1 * VoxelGrid.hash01(x, 0, 1)), VoxelMat.SLAB)
	# Gravel path to the houses' doors.
	g.fill(
		Vector3i(-30, -1, -14),
		Vector3i(-26, -1, -8),
		Color(0.62, 0.56, 0.47),
		VoxelMat.GRAVEL,
		0,
		_paint(Color(0.62, 0.56, 0.47), 0.15, 2)
	)
	g.fill(
		Vector3i(24, -1, -14),
		Vector3i(28, -1, -8),
		Color(0.62, 0.56, 0.47),
		VoxelMat.GRAVEL,
		0,
		_paint(Color(0.62, 0.56, 0.47), 0.15, 2)
	)
	_stone_house(g, Vector3i(-46, 0, -42), Vector3i(-11, 0, -15), 1)
	_plaster_house(g, Vector3i(10, 0, -40), Vector3i(42, 0, -15), 3)
	_veg_patch(g, Vector3i(-70, 0, -32), Vector3i(-52, 0, -16))
	_pond(g, Vector3(24.0, 0.0, 16.0), Vector2(14.0, 8.0))
	_fountain(g, FOUNTAIN_V)
	for p in [
		Vector3i(-58, 0, -54), Vector3i(54, 0, -54), Vector3i(-38, 0, 28), Vector3i(66, 0, -14)
	]:
		_tree(g, p, 4)
	for p in [
		Vector3i(-40, 0, -12), Vector3i(-17, 0, -12), Vector3i(16, 0, -12), Vector3i(37, 0, -12)
	]:
		_bush(g, p)
	var lamps := [
		Vector3i(-9, 0, -9),
		Vector3i(8, 0, -9),
		Vector3i(-40, 0, 8),
		Vector3i(22, 0, 8),
		Vector3i(-9, 0, -44)
	]
	for p in lamps:
		_lamp_post(g, p)
	# Stray pebbles.
	for i in 70:
		var x := int(VoxelGrid.hash01(i, 0, 0, 11) * 150.0) - 75
		var z := int(VoxelGrid.hash01(i, 0, 0, 12) * 110.0) - 70
		if not g.solid(Vector3i(x, 0, z)) and g.mat_at(Vector3i(x, -1, z)) == VoxelMat.GRASS:
			g.put(
				Vector3i(x, 0, z),
				STONE_B.lightened(0.2 * VoxelGrid.hash01(i, 1, 0)),
				VoxelMat.STONE
			)
	for mi in VoxelMat.instances(g, "V", {2: {"sway": 0.035, "sway_base": 2.2}}):
		world.add_child(mi)
	for p in lamps:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.76, 0.46)
		l.light_energy = 3.5
		l.omni_range = 6.5
		l.omni_attenuation = 1.3
		l.position = Vector3((p.x + 0.5) * 0.25, 3.05, (p.z + 0.5) * 0.25)
		world.add_child(l)
		var nl := NightLights.new()
		nl.light = l
		world.add_child(nl)
	var w := WaterSurface.make(Vector2(7.5, 4.5), {"kind": "pond", "depth": 0.6})
	w.position = Vector3(6.0, WATER_Y, 4.0)
	world.add_child(w)
	if water_debug > 0:
		WaterSurface.set_param(w, "debug_view", water_debug)
	_fountain_fx()
	_flowers()


func _stone_house(g: VoxelGrid, lo: Vector3i, hi: Vector3i, roof_part: int) -> void:
	var h := 12
	g.fill(
		Vector3i(lo.x, 0, lo.z),
		Vector3i(hi.x, h - 1, hi.z),
		STONE_A,
		VoxelMat.STONE,
		0,
		_stone_wall
	)
	g.fill(
		Vector3i(lo.x + 2, 0, lo.z + 2),
		Vector3i(hi.x - 2, h - 1, hi.z - 2),
		Color.BLACK,
		VoxelMat.AIR
	)
	# Plinth and corner quoins.
	g.fill(
		Vector3i(lo.x - 1, 0, hi.z + 1),
		Vector3i(hi.x + 1, 0, hi.z + 1),
		STONE_B.darkened(0.15),
		VoxelMat.STONE
	)
	for x in [lo.x, hi.x]:
		for y in range(0, h, 2):
			g.put(Vector3i(x, y, hi.z), Color(0.74, 0.73, 0.7), VoxelMat.STONE)
	# Door, frame and step.
	var cx := (lo.x + hi.x) / 2
	g.fill(
		Vector3i(cx - 1, 0, hi.z),
		Vector3i(cx + 1, 6, hi.z),
		Color(0.43, 0.27, 0.15),
		VoxelMat.WOOD,
		0,
		_paint(Color(0.43, 0.27, 0.15), 0.08, 4)
	)
	g.fill(
		Vector3i(cx - 2, 7, hi.z), Vector3i(cx + 2, 7, hi.z), Color(0.75, 0.74, 0.7), VoxelMat.SLAB
	)
	g.fill(
		Vector3i(cx - 2, -1, hi.z + 1),
		Vector3i(cx + 2, -1, hi.z + 2),
		Color(0.7, 0.69, 0.66),
		VoxelMat.SLAB
	)
	# Windows with sills (two floors' worth on the front, one on the sides).
	for wx in [lo.x + 5, lo.x + 12, hi.x - 14, hi.x - 7]:
		if absi(wx + 1 - cx) < 4:
			continue
		g.fill(Vector3i(wx, 4, hi.z), Vector3i(wx + 2, 7, hi.z), WINDOW, VoxelMat.WINDOW)
		g.fill(Vector3i(wx + 1, 4, hi.z), Vector3i(wx + 1, 7, hi.z), TIMBER, VoxelMat.WOOD)
		g.fill(
			Vector3i(wx - 1, 3, hi.z + 1),
			Vector3i(wx + 3, 3, hi.z + 1),
			Color(0.78, 0.77, 0.73),
			VoxelMat.SLAB
		)
	for wz in [lo.z + 8, lo.z + 18]:
		g.fill(Vector3i(hi.x, 4, wz), Vector3i(hi.x, 7, wz + 2), WINDOW, VoxelMat.WINDOW)
		g.fill(Vector3i(lo.x, 4, wz), Vector3i(lo.x, 7, wz + 2), WINDOW, VoxelMat.WINDOW)
	_roof(g, lo, hi, h, roof_part, ROOF_A, ROOF_B)
	# Chimney.
	g.fill(
		Vector3i(hi.x - 8, h, lo.z + 6),
		Vector3i(hi.x - 6, h + 14, lo.z + 8),
		Color(0.55, 0.33, 0.25),
		VoxelMat.BRICK,
		roof_part,
		_paint(Color(0.55, 0.33, 0.25), 0.12, 6)
	)


func _plaster_house(g: VoxelGrid, lo: Vector3i, hi: Vector3i, roof_part: int) -> void:
	var h := 11
	g.fill(
		Vector3i(lo.x, 0, lo.z), Vector3i(hi.x, 2, hi.z), STONE_A, VoxelMat.STONE, 0, _stone_wall
	)
	g.fill(
		Vector3i(lo.x, 3, lo.z),
		Vector3i(hi.x, h - 1, hi.z),
		PLASTER,
		VoxelMat.PLASTER,
		0,
		_paint(PLASTER, 0.05, 8)
	)
	g.fill(
		Vector3i(lo.x + 2, 0, lo.z + 2),
		Vector3i(hi.x - 2, h - 1, hi.z - 2),
		Color.BLACK,
		VoxelMat.AIR
	)
	for x in range(lo.x, hi.x + 1, 8):
		g.fill(Vector3i(x, 3, hi.z), Vector3i(x, h - 1, hi.z), TIMBER, VoxelMat.WOOD)
	g.fill(Vector3i(hi.x, 3, hi.z), Vector3i(hi.x, h - 1, hi.z), TIMBER, VoxelMat.WOOD)
	g.fill(Vector3i(lo.x, h - 1, hi.z), Vector3i(hi.x, h - 1, hi.z), TIMBER, VoxelMat.WOOD)
	g.fill(Vector3i(lo.x, 3, hi.z), Vector3i(hi.x, 3, hi.z), TIMBER, VoxelMat.WOOD)
	var cx := (lo.x + hi.x) / 2
	g.fill(
		Vector3i(cx - 1, 0, hi.z), Vector3i(cx + 1, 6, hi.z), Color(0.3, 0.42, 0.55), VoxelMat.WOOD
	)
	g.fill(
		Vector3i(cx - 2, -1, hi.z + 1),
		Vector3i(cx + 2, -1, hi.z + 2),
		Color(0.7, 0.69, 0.66),
		VoxelMat.SLAB
	)
	for wx in [lo.x + 3, lo.x + 10, hi.x - 12, hi.x - 5]:
		if absi(wx + 1 - cx) < 4:
			continue
		g.fill(Vector3i(wx, 5, hi.z), Vector3i(wx + 2, 7, hi.z), WINDOW, VoxelMat.WINDOW)
		g.fill(
			Vector3i(wx - 1, 4, hi.z + 1),
			Vector3i(wx + 3, 4, hi.z + 1),
			Color(0.5, 0.3, 0.2),
			VoxelMat.WOOD
		)
		g.fill(
			Vector3i(wx - 1, 5, hi.z + 1),
			Vector3i(wx + 3, 5, hi.z + 1),
			Color(0.85, 0.3, 0.32),
			VoxelMat.FLOWER,
			0,
			_paint(Color(0.85, 0.3, 0.32), 0.3, 10)
		)
	_roof(g, lo, hi, h, roof_part, Color(0.8, 0.36, 0.2), Color(0.66, 0.28, 0.14))


## Stepped gable roof, ridge along x, with overhangs and gable walls.
func _roof(g: VoxelGrid, lo: Vector3i, hi: Vector3i, h: int, prt: int, a: Color, b: Color) -> void:
	var depth := hi.z - lo.z + 1
	var steps := depth / 2 + 1
	for i in steps:
		var z0 := lo.z - 2 + i
		var z1 := hi.z + 2 - i
		if z0 > z1:
			break
		var c := a if i % 2 == 0 else b
		g.fill(
			Vector3i(lo.x - 2, h + i, z0),
			Vector3i(hi.x + 2, h + i, z1),
			c,
			VoxelMat.ROOF,
			prt,
			_paint(c, 0.05, 20 + i)
		)
		if z1 - z0 > 2:
			g.fill(
				Vector3i(lo.x, h + i, z0 + 2),
				Vector3i(lo.x, h + i, z1 - 2),
				Color(0.62, 0.6, 0.57),
				VoxelMat.STONE,
				prt
			)
			g.fill(
				Vector3i(hi.x, h + i, z0 + 2),
				Vector3i(hi.x, h + i, z1 - 2),
				Color(0.62, 0.6, 0.57),
				VoxelMat.STONE,
				prt
			)


func _veg_patch(g: VoxelGrid, lo: Vector3i, hi: Vector3i) -> void:
	g.fill(
		Vector3i(lo.x, -1, lo.z),
		Vector3i(hi.x, -1, hi.z),
		Color(0.36, 0.25, 0.16),
		VoxelMat.DIRT,
		0,
		_paint(Color(0.36, 0.25, 0.16), 0.1, 30)
	)
	for z in range(lo.z + 1, hi.z, 3):
		for x in range(lo.x + 1, hi.x, 2):
			var c := Color(0.36, 0.62, 0.2).lerp(
				Color(0.55, 0.7, 0.25), VoxelGrid.hash01(x, 0, z, 31)
			)
			g.put(Vector3i(x, 0, z), c, VoxelMat.CROP)
			if VoxelGrid.hash01(x, 1, z, 32) > 0.4:
				g.put(Vector3i(x, 1, z), c.lightened(0.1), VoxelMat.CROP)
			if VoxelGrid.hash01(x, 2, z, 33) > 0.8:
				g.put(Vector3i(x, 1, z), Color(0.9, 0.35, 0.2), VoxelMat.CROP)
	for x in range(lo.x - 1, hi.x + 2, 4):
		g.fill(
			Vector3i(x, 0, hi.z + 1),
			Vector3i(x, 2, hi.z + 1),
			Color(0.5, 0.36, 0.22),
			VoxelMat.WOOD
		)
	g.fill(
		Vector3i(lo.x - 1, 2, hi.z + 1),
		Vector3i(hi.x + 1, 2, hi.z + 1),
		Color(0.55, 0.4, 0.25),
		VoxelMat.WOOD
	)


func _pond(g: VoxelGrid, c: Vector3, s: Vector2) -> void:
	for x in range(int(c.x - s.x) - 3, int(c.x + s.x) + 4):
		for z in range(int(c.z - s.y) - 3, int(c.z + s.y) + 4):
			var d := Vector2((x + 0.5 - c.x) / s.x, (z + 0.5 - c.z) / s.y).length()
			var n := VoxelGrid.hash01(x, 0, z, 40) * 0.08
			if d < 0.92 + n:
				var depth := clampi(int((1.0 - d) * 6.0) + 1, 1, 4)
				for y in range(-depth, 0):
					g.clear(Vector3i(x, y, z))
				g.put(
					Vector3i(x, -depth - 1, z),
					Color(0.62, 0.55, 0.4).darkened(0.08 * depth),
					VoxelMat.BED
				)
			elif d < 1.08 + n:
				g.put(
					Vector3i(x, -1, z),
					Color(0.55, 0.54, 0.52).lerp(
						Color(0.42, 0.42, 0.44), VoxelGrid.hash01(x, 0, z, 41)
					),
					VoxelMat.STONE
				)
				if VoxelGrid.hash01(x, 1, z, 42) > 0.8:
					g.put(Vector3i(x, 0, z), Color(0.5, 0.5, 0.5), VoxelMat.STONE)


## Small stone fountain: a round basin (rim 0.5 m, bed carved 0.25 m below the ground) and a
## pedestal with a little bowl; FountainFx adds the water, a jet, spouts and the night light.
func _fountain(g: VoxelGrid, c: Vector3i) -> void:
	for x in range(c.x - 6, c.x + 6):
		for z in range(c.z - 6, c.z + 6):
			var r := Vector2(x + 0.5 - c.x, z + 0.5 - c.z).length()
			var stone := Color(0.7, 0.69, 0.66).lerp(
				Color(0.58, 0.57, 0.56), VoxelGrid.hash01(x, 0, z, 80)
			)
			if r < 4.1:
				for y in range(-1, 2):
					g.clear(Vector3i(x, y, z))
				g.put(Vector3i(x, -2, z), Color(0.5, 0.56, 0.55), VoxelMat.BED)
			elif r < 5.3:
				for y in range(-1, 2):
					g.put(Vector3i(x, y, z), stone.darkened(0.08 * (1 - y)), VoxelMat.STONE)
			elif r < 6.0:
				g.put(Vector3i(x, -1, z), stone.darkened(0.12), VoxelMat.SLAB)
	g.cylinder(c.x, c.z, 1.1, -1, 5, Color(0.66, 0.65, 0.62), VoxelMat.STONE)
	for x in range(c.x - 2, c.x + 2):
		for z in range(c.z - 2, c.z + 2):
			g.put(Vector3i(x, 6, z), Color(0.72, 0.71, 0.68), VoxelMat.STONE)


func _fountain_fx() -> void:
	var f := FountainFx.new()
	f.name = "Fountain"
	f.position = Vector3(FOUNTAIN_V.x, 0, FOUNTAIN_V.z) * 0.25
	world.add_child(f)
	(
		f
		. setup(
			{
				"basins": [{"pos": Vector3(0, 0.36, 0), "size": Vector2(2.2, 2.2), "depth": 0.6}],
				"jets":
				[
					{"pos": Vector3(0, 1.78, 0), "height": 0.7, "count": 1},
					{
						"pos": Vector3(0, 0.42, 0),
						"height": 0.3,
						"count": 5,
						"radius": 0.95,
						"reach": -0.5
					},
				],
				"light": Color(0.62, 0.9, 1.0),
			}
		)
	)


func _tree(g: VoxelGrid, p: Vector3i, r: int) -> void:
	g.cylinder(p.x + 0.5, p.z + 0.5, 1.3, 0, 9, Color(0.38, 0.25, 0.15), VoxelMat.BARK)
	var leaf := _paint(LEAF, 0.22, 50 + p.x)
	g.ellipsoid(
		Vector3(p.x + 0.5, 14, p.z + 0.5),
		Vector3(r * 2.2, r * 1.6, r * 2.2),
		LEAF,
		VoxelMat.LEAVES,
		2,
		leaf
	)
	g.ellipsoid(
		Vector3(p.x + 3.5, 18, p.z - 1.5),
		Vector3(r * 1.4, r * 1.2, r * 1.4),
		LEAF,
		VoxelMat.LEAVES,
		2,
		leaf
	)


func _bush(g: VoxelGrid, p: Vector3i) -> void:
	g.ellipsoid(
		Vector3(p.x + 0.5, 1.0, p.z + 0.5),
		Vector3(3.5, 2.5, 2.5),
		Color(0.2, 0.42, 0.17),
		VoxelMat.LEAVES,
		0,
		_paint(Color(0.2, 0.42, 0.17), 0.2, 60)
	)
	for i in 4:
		var q := Vector3i(
			p.x - 2 + int(VoxelGrid.hash01(p.x, i, 0, 61) * 5.0),
			2,
			p.z - 1 + int(VoxelGrid.hash01(p.z, i, 0, 62) * 3.0)
		)
		g.put(q, Color(0.95, 0.85, 0.3) if i % 2 == 0 else Color(0.95, 0.45, 0.55), VoxelMat.FLOWER)


func _lamp_post(g: VoxelGrid, p: Vector3i) -> void:
	g.fill(
		Vector3i(p.x - 1, 0, p.z - 1),
		Vector3i(p.x + 1, 0, p.z + 1),
		Color(0.4, 0.4, 0.42),
		VoxelMat.STONE
	)
	g.fill(Vector3i(p.x, 1, p.z), Vector3i(p.x, 9, p.z), METAL, VoxelMat.METAL)
	# Lantern: glass panes between metal corner posts, under a metal cap.
	for y in [11, 12]:
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var corner: bool = dx != 0 and dz != 0
				g.put(
					Vector3i(p.x + dx, y, p.z + dz),
					METAL if corner else Color(1.0, 0.82, 0.5),
					VoxelMat.METAL if corner else VoxelMat.LAMP
				)
	g.fill(Vector3i(p.x - 1, 10, p.z - 1), Vector3i(p.x + 1, 10, p.z + 1), METAL, VoxelMat.METAL)
	g.fill(Vector3i(p.x - 1, 13, p.z - 1), Vector3i(p.x + 1, 13, p.z + 1), METAL, VoxelMat.METAL)
	g.put(Vector3i(p.x, 14, p.z), METAL, VoxelMat.METAL)


func _flowers() -> void:
	var cols := [
		Color(0.95, 0.3, 0.35),
		Color(0.98, 0.85, 0.3),
		Color(0.95, 0.95, 0.95),
		Color(0.7, 0.45, 0.95)
	]
	for ci in cols.size():
		var fl := VoxelGrid.new(Vector3i.ZERO, Vector3i(3, 5, 3))
		fl.fill(Vector3i(1, 0, 1), Vector3i(1, 2, 1), Color(0.25, 0.55, 0.2), VoxelMat.FLOWER)
		fl.put(Vector3i(1, 3, 1), cols[ci], VoxelMat.FLOWER)
		fl.put(Vector3i(0, 3, 1), cols[ci], VoxelMat.FLOWER)
		fl.put(Vector3i(2, 3, 1), cols[ci], VoxelMat.FLOWER)
		fl.put(Vector3i(1, 3, 0), cols[ci], VoxelMat.FLOWER)
		fl.put(Vector3i(1, 3, 2), cols[ci], VoxelMat.FLOWER)
		fl.put(Vector3i(1, 4, 1), cols[ci].lightened(0.3), VoxelMat.FLOWER)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = VoxelMesher.colored(fl, VoxelMat.DETAIL, Vector3(1.5, 0, 1.5))
		var pts: Array = []
		for i in 160:
			var x := -16.0 + VoxelGrid.hash01(i, ci, 0, 70) * 32.0
			var z := -12.0 + VoxelGrid.hash01(i, ci, 0, 71) * 20.0
			if absf(z) < 2.0 or absf(x) < 1.6 or (x > 2.0 and x < 10.0 and z > 1.5 and z < 6.5):
				continue
			if Vector2(x, z).distance_to(Vector2(FOUNTAIN_V.x, FOUNTAIN_V.z) * 0.25) < 1.7:
				continue
			if z < -3.0 and ((x > -12.0 and x < -2.5) or (x > 2.2 and x < 11.0)):
				continue
			pts.append(Vector3(x, 0, z))
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 1.3), pts[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = VoxelMat.detail_material({"sway": 0.6})
		world.add_child(mmi)


func _people() -> void:
	var who := [
		["trainer", Vector3(0, 0, 0.5)],
		["npc_kid", Vector3(-2.4, 0, 2.6)],
		["npc_lass", Vector3(3.0, 0, -2.5)]
	]
	for e in who:
		var holder := Node3D.new()
		holder.position = e[1]
		world.add_child(holder)
		var tex := CharSprite.sheet(e[0])
		if tex:
			var s := CharSprite.make(tex)
			s.follow_parent = false
			s.facing = Vector3(0, 0, 1)
			holder.add_child(s)
		else:
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 1.5, 0.4)
			box.mesh = bm
			box.position.y = 0.75
			holder.add_child(box)
