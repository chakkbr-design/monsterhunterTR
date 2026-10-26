extends SceneTree
## Screenshot of the voxel core (needs a GPU or lavapipe):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan \
##     --script res://tests/gfx/shot_voxel.gd -- --out=/tmp/voxel.png [--night] [--rain] [--snow]
## A small cottage, a tree with a swaying crown, cobbles, a pond bed with the water surface and
## detail flowers under a sun + sky environment, to eyeball shading, AO, bevels and weather.

var out := "user://shot_voxel.png"
var night := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--night":
			night = true
		elif a == "--rain":
			RenderingServer.global_shader_parameter_set("rain_wet", 1.0)
			RenderingServer.global_shader_parameter_set("rain_puddle", 0.7)
			RenderingServer.global_shader_parameter_set("rain_amount", 1.0)
		elif a == "--snow":
			RenderingServer.global_shader_parameter_set("snow_cover", 0.9)
	_run.call_deferred()


func _paint(base: Color, amt: float) -> Callable:
	return func(v: Vector3i) -> Color:
		var h := VoxelGrid.hash01(v.x, v.y, v.z)
		return base.lightened(amt * h) if h > 0.5 else base.darkened(amt * (1.0 - h))


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var g := VoxelGrid.new(Vector3i(-40, -8, -40), Vector3i(80, 48, 80))
	# Ground: grass with a cobble road and a pond bed.
	g.fill(
		Vector3i(-40, -3, -40),
		Vector3i(39, -1, 39),
		Color(0.32, 0.55, 0.2),
		VoxelMat.GRASS,
		0,
		_paint(Color(0.32, 0.55, 0.2), 0.12)
	)
	g.fill(
		Vector3i(-6, -1, -40),
		Vector3i(5, -1, 39),
		Color(0.6, 0.6, 0.62),
		VoxelMat.STONE,
		0,
		func(v: Vector3i) -> Color:
			var m := (posmod(v.x, 3) == 0) or (posmod(v.z + (v.x / 3) * 2, 3) == 0)
			return (
				Color(0.42, 0.41, 0.4)
				if m
				else Color(0.66, 0.65, 0.66).darkened(0.15 * VoxelGrid.hash01(v.x, 0, v.z))
			)
	)
	for x in range(-36, -14):
		for z in range(8, 26):
			var d := Vector2(x + 25, z - 17).length()
			if d < 9.0:
				var depth := int(clamp((9.0 - d) * 0.6, 1, 4))
				for y in range(-depth, 0):
					g.clear(Vector3i(x, y, z))
				g.put(Vector3i(x, -depth - 1, z), Color(0.76, 0.68, 0.5), VoxelMat.BED)
	# Cottage: plaster walls, timber, windows, stepped roof (part 1).
	var wall := Color(0.92, 0.88, 0.8)
	g.fill(
		Vector3i(10, 0, -20), Vector3i(30, 11, -6), wall, VoxelMat.PLASTER, 0, _paint(wall, 0.05)
	)
	g.fill(Vector3i(11, 0, -19), Vector3i(29, 11, -7), Color.BLACK, VoxelMat.AIR)
	for x in [10, 20, 30]:
		g.fill(Vector3i(x, 0, -6), Vector3i(x, 11, -6), Color(0.36, 0.23, 0.14), VoxelMat.WOOD)
	g.fill(Vector3i(13, 4, -6), Vector3i(16, 7, -6), Color(1.0, 0.75, 0.4), VoxelMat.WINDOW)
	g.fill(Vector3i(24, 4, -6), Vector3i(27, 7, -6), Color(1.0, 0.75, 0.4), VoxelMat.WINDOW)
	g.fill(Vector3i(19, 0, -6), Vector3i(21, 8, -6), Color(0.45, 0.28, 0.16), VoxelMat.WOOD)
	for i in 9:
		var c := Color(0.85, 0.42, 0.18) if i % 2 == 0 else Color(0.72, 0.33, 0.13)
		g.fill(Vector3i(9, 12 + i, -21 + i), Vector3i(31, 12 + i, -5 - i), c, VoxelMat.ROOF, 1)
	# Tree: trunk static, crown part 2 (sways).
	g.fill(Vector3i(-14, 0, -14), Vector3i(-13, 9, -13), Color(0.4, 0.26, 0.15), VoxelMat.BARK)
	g.ellipsoid(
		Vector3(-13, 13, -13),
		Vector3(6, 5, 6),
		Color(0.25, 0.5, 0.2),
		VoxelMat.LEAVES,
		2,
		_paint(Color(0.26, 0.5, 0.2), 0.25)
	)
	# Lamp post.
	g.fill(Vector3i(-8, 0, 2), Vector3i(-8, 10, 2), Color(0.2, 0.2, 0.22), VoxelMat.METAL)
	g.fill(Vector3i(-9, 11, 1), Vector3i(-7, 12, 3), Color(1.0, 0.8, 0.45), VoxelMat.LAMP)
	for mi in VoxelMat.instances(g, "V", {2: {"sway": 0.04, "sway_base": 2.0}}):
		root.add_child(mi)
	var w := WaterSurface.make(Vector2(5, 5), {"kind": "pond"})
	w.position = Vector3(-6.25, -0.06, 4.25)
	root.add_child(w)
	# Detail flowers.
	var fl := VoxelGrid.new(Vector3i.ZERO, Vector3i(3, 5, 3))
	fl.fill(Vector3i(1, 0, 1), Vector3i(1, 3, 1), Color(0.2, 0.55, 0.2), VoxelMat.FLOWER)
	fl.put(Vector3i(1, 4, 1), Color(0.95, 0.3, 0.35), VoxelMat.FLOWER)
	fl.put(Vector3i(0, 3, 1), Color(0.95, 0.3, 0.35), VoxelMat.FLOWER)
	fl.put(Vector3i(2, 3, 1), Color(0.95, 0.3, 0.35), VoxelMat.FLOWER)
	var fm := VoxelMesher.colored(fl, VoxelMat.DETAIL, Vector3(1.5, 0, 1.5))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = fm
	mm.instance_count = 60
	for i in 60:
		mm.set_instance_transform(
			i,
			Transform3D(
				Basis(), Vector3(-3.5 + (i % 10) * 0.4 + 0.1 * (i / 10), 0, -4 + (i / 10) * 0.45)
			)
		)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = VoxelMat.detail_material({"sway": 0.6})
	root.add_child(mmi)
	# Light + environment.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35 if not night else -50, 140, 0)
	sun.light_energy = 2.2 if not night else 0.15
	sun.light_color = Color(1.0, 0.92, 0.8) if not night else Color(0.5, 0.6, 0.9)
	sun.shadow_enabled = true
	root.add_child(sun)
	if night:
		RenderingServer.global_shader_parameter_set("night_lamps", 1.0)
		RenderingServer.global_shader_parameter_set("night_windows", 1.0)
		var ol := OmniLight3D.new()
		ol.position = Vector3(-2.0, 2.9, 0.5)
		ol.light_color = Color(1.0, 0.75, 0.45)
		ol.light_energy = 3.0
		ol.omni_range = 7.0
		root.add_child(ol)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	if night:
		psm.sky_top_color = Color(0.02, 0.03, 0.08)
		psm.sky_horizon_color = Color(0.05, 0.07, 0.14)
		psm.ground_horizon_color = Color(0.05, 0.07, 0.14)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0 if not night else 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 35.0
	root.add_child(cam)
	cam.position = Vector3(0, 9.5, 17)
	cam.look_at(Vector3(0, 1.0, -3))
	for i in 20:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit(0)
