extends SceneTree
## Screenshots of the water (needs a GPU or lavapipe):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan \
##     --resolution 1600x900 --script res://tests/gfx/shot_water.gd -- --out=/tmp/water.png \
##     [--hour=noon|morning|golden|dusk|night] [--weather=clear|rain|storm|snow|windy]
##     [--view=pond,fountain,stream,near,far,wide,low,arena,jets,puddle] [--wait=frames]
##     [--freeze=0..1] [--debug=1..6] [--arena-kind=sea|puddle|fountain|stream]
## Builds the voxel diorama of tests/gfx/shot_water_scene.gd (pond, stream + cascade, three-tier
## fountain, dock, sprites) under a simple sun + sky that reads the same globals as the water
## (the sky lane owns the real environment), sets the time-of-day and weather globals directly and
## saves one PNG per view (<out>_<view>.png when several views are asked for).
## Views: pond / fountain / stream = game camera (12 m, pitch 32, fov 35); near / far = battle
## action camera at 6 m and 22 m; wide = overview; low = grazing view for reflections; arena = the
## battle-style ellipse pond scaled to 80 %; jets = the fountain at 6 m; puddle = the path puddle.

const Scene := preload("res://tests/gfx/shot_water_scene.gd")

const HOURS := {
	"noon":
	{
		"el": 58.0,
		"az": 200.0,
		"sun": Color(1.0, 0.96, 0.9),
		"energy": 2.3,
		"top": Color(0.33, 0.55, 0.86),
		"hor": Color(0.72, 0.83, 0.93),
		"amb": 1.0,
		"amount": 1.0,
		"lamps": 0.0,
		"windows": 0.0,
	},
	"morning":
	{
		"el": 22.0,
		"az": 115.0,
		"sun": Color(1.0, 0.86, 0.68),
		"energy": 1.9,
		"top": Color(0.4, 0.58, 0.85),
		"hor": Color(0.92, 0.84, 0.74),
		"amb": 0.85,
		"amount": 0.95,
		"lamps": 0.0,
		"windows": 0.0,
	},
	"golden":
	{
		"el": 9.0,
		"az": 290.0,
		"sun": Color(1.0, 0.62, 0.32),
		"energy": 2.0,
		"top": Color(0.36, 0.45, 0.7),
		"hor": Color(1.0, 0.7, 0.45),
		"amb": 0.7,
		"amount": 0.9,
		"lamps": 0.25,
		"windows": 0.4,
	},
	"dusk":
	{
		"el": 2.5,
		"az": 295.0,
		"sun": Color(0.95, 0.45, 0.35),
		"energy": 0.6,
		"top": Color(0.13, 0.15, 0.32),
		"hor": Color(0.78, 0.44, 0.38),
		"amb": 0.45,
		"amount": 0.2,
		"lamps": 1.0,
		"windows": 1.0,
	},
	"night":
	{
		"el": 38.0,
		"az": 160.0,
		"sun": Color(0.55, 0.65, 1.0),
		"energy": 0.22,
		"top": Color(0.015, 0.025, 0.07),
		"hor": Color(0.05, 0.07, 0.15),
		"amb": 0.3,
		"amount": 0.0,
		"lamps": 1.0,
		"windows": 1.0,
	},
}

## [target offset from a scene spot, distance, pitch, yaw, fov]
const VIEWS := {
	"pond": ["pond", Vector3(0.5, 0, 0.4), 12.0, 32.0, 0.0, 35.0],
	"fountain": ["fountain", Vector3(0, -0.6, 0.3), 12.0, 32.0, 0.0, 35.0],
	"stream": ["stream", Vector3(0, 0, 0.8), 12.0, 32.0, 0.0, 35.0],
	"near": ["wade", Vector3(-1.2, 0.4, -1.0), 6.0, 22.0, -20.0, 45.0],
	"far": ["pond", Vector3(4.5, 0, -0.5), 22.0, 36.0, 0.0, 45.0],
	"wide": ["pond", Vector3(5.0, 0, -2.0), 30.0, 48.0, 0.0, 40.0],
	"low": ["pond", Vector3(0.5, 0.2, -0.5), 9.0, 13.0, 12.0, 40.0],
	"arena": ["arena", Vector3(0, 0, 0), 7.0, 30.0, 0.0, 45.0],
	"jets": ["fountain", Vector3(0, 0.9, 0), 6.0, 18.0, 25.0, 45.0],
	"puddle": ["puddle", Vector3(0, 0, -0.4), 5.0, 32.0, 0.0, 45.0],
}

var out := "user://shot_water.png"
var hour := "noon"
var weather := "clear"
var views: PackedStringArray = ["pond"]
var wait := 14
var freeze := -1.0
var debug := 0
var arena_kind := ""
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var scene: Scene


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hour="):
			hour = a.substr(7)
		elif a.begins_with("--weather="):
			weather = a.substr(10)
		elif a.begins_with("--view="):
			views = a.substr(7).split(",")
		elif a.begins_with("--wait="):
			wait = int(a.substr(7))
		elif a.begins_with("--freeze="):
			freeze = float(a.substr(9))
		elif a.begins_with("--debug="):
			debug = int(a.substr(8))
		elif a.begins_with("--arena-kind="):
			arena_kind = a.substr(13)
	_run.call_deferred()


func _g(n: String, v: Variant) -> void:
	RenderingServer.global_shader_parameter_set(n, v)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	get_root().add_child(root)
	scene = Scene.new()
	scene.build(root)
	print("diorama built in %d ms" % (Time.get_ticks_msec() - t0))
	_light(root)
	if freeze >= 0.0:
		WaterSurface.set_freeze(scene.pond, freeze)
	if arena_kind != "":
		# Try another kind on the battle pond (sea, puddle, fountain...).
		var m := WaterSurface.material({"kind": arena_kind, "shape": "ellipse", "depth": 0.6})
		m.set_shader_parameter("size", Vector2(2, 2) * Scene.ARENA_R0)
		scene.arena_pond.material_override = m
	if debug:
		for w in [scene.pond, scene.stream] + scene.fountain.basins:
			WaterSurface.set_param(w, "debug_view", debug)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	for v in views:
		if not VIEWS.has(v):
			push_error("view? " + v)
			continue
		var d: Array = VIEWS[v]
		var target: Vector3 = scene.spots[d[0]] + d[1]
		var dist: float = d[2]
		var pitch := deg_to_rad(d[3])
		var yaw := deg_to_rad(d[4])
		cam.fov = d[5]
		cam.far = 200.0
		var off := Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
		cam.position = target + Basis(Vector3.UP, yaw) * off
		cam.look_at(target)
		for i in wait:
			await process_frame
		var img := get_root().get_texture().get_image()
		var path := out if views.size() == 1 else out.get_basename() + "_" + v + ".png"
		img.save_png(path)
		print("saved ", path)
	quit(0)


func _light(root: Node3D) -> void:
	var h: Dictionary = HOURS.get(hour, HOURS.noon)
	var el := deg_to_rad(h.el)
	var az := deg_to_rad(h.az)
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()
	var top: Color = h.top
	var hor: Color = h.hor
	var energy: float = h.energy
	var amount: float = h.amount
	var amb: float = h.amb
	var lamps: float = h.lamps
	_g("wind_dir", Vector2(1.0, -0.35).normalized())
	_g("wind_strength", 1.0)
	_g("wind_gust", 0.0)
	match weather:
		"rain", "storm":
			var grey := Color(0.42, 0.46, 0.52) if weather == "rain" else Color(0.22, 0.24, 0.3)
			top = top.lerp(grey, 0.85)
			hor = hor.lerp(grey.lightened(0.2), 0.85)
			energy *= 0.3
			amount *= 0.12
			amb *= 0.85
			lamps = maxf(lamps, 0.4 if weather == "rain" else 0.8)
			_g("rain_amount", 1.0)
			_g("rain_wet", 1.0)
			_g("rain_puddle", 0.6)
			_g("cloud_cover", 1.0)
			_g("wind_strength", 1.6)
			_g("wind_gust", 0.6 if weather == "rain" else 1.2)
			if weather == "storm":
				_g("lightning_flash", 0.7)
			_rain(root)
		"snow":
			top = top.lerp(Color(0.72, 0.76, 0.82), 0.8)
			hor = hor.lerp(Color(0.86, 0.88, 0.9), 0.8)
			energy *= 0.55
			amount *= 0.35
			_g("snow_cover", 0.9)
			_g("cloud_cover", 0.8)
			_snow(root)
		"windy":
			_g("wind_strength", 2.2)
			_g("wind_gust", 1.0)
	_g("sun_dir_world", to_sun)
	_g("sun_color_world", h.sun)
	_g("sun_amount", amount)
	_g("sky_top_color", top)
	_g("sky_horizon_color", hor)
	_g("night_lamps", lamps)
	_g("night_windows", h.windows)
	sun = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	sun.light_energy = energy
	sun.light_color = h.sun
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	root.add_child(sun)
	for l in scene.lamps:
		l.light_energy = 3.0 * lamps
		l.visible = lamps > 0.01
	scene.fountain.set_night(lamps)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = amb
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


func _rain(root: Node3D) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 2500
	gp.lifetime = 0.8
	gp.preprocess = 1.0
	gp.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	gp.visibility_aabb = AABB(Vector3(-20, -2, -16), Vector3(40, 14, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 0.2, 12)
	pm.direction = Vector3(0.15, -1, -0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3.ZERO
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.85, 0.95, 0.28)
	q.material = m
	gp.draw_pass_1 = q
	gp.position = Vector3(0, 9, -1)
	root.add_child(gp)


func _snow(root: Node3D) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 1500
	gp.lifetime = 6.0
	gp.preprocess = 6.0
	gp.visibility_aabb = AABB(Vector3(-20, -12, -16), Vector3(40, 16, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 0.2, 12)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Alpha-blended so flakes below the water line are hidden (opaque ones would show refracted).
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.95)
	q.material = m
	gp.draw_pass_1 = q
	gp.position = Vector3(0, 9, -1)
	root.add_child(gp)


const SKY := """
shader_type sky;
global uniform vec4 sky_top_color;
global uniform vec4 sky_horizon_color;
global uniform vec3 sun_dir_world;
global uniform vec4 sun_color_world;
global uniform float sun_amount;
global uniform float lightning_flash;
vec3 lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(lin(sky_horizon_color.rgb), lin(sky_top_color.rgb), sqrt(h));
	if (d.y < 0.0) {
		c = lin(sky_horizon_color.rgb) * mix(1.0, 0.45, clamp(-d.y * 3.0, 0.0, 1.0));
	}
	float s = max(dot(d, normalize(sun_dir_world)), 0.0);
	c += lin(sun_color_world.rgb) * (pow(s, 900.0) * 30.0 + pow(s, 12.0) * 0.25) * sun_amount;
	COLOR = c * (1.0 + lightning_flash * 4.0);
}
"""
