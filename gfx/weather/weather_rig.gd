class_name WeatherRig
extends Node3D
## Weather particles and ground mist shared by the overworld (WorldWeather, following the camera
## focus) and the energy-mode training stadium (BattleWeatherFx, fixed over the field and stands):
## - rain: thin streaks aligned to their velocity (rain.gdshader, lit by the scene), slanted by the
##   wind; a drop that hits the collision heightfield (ground, roofs, trees, water) dies there and
##   leaves a splash (ring + pixel crown, splash sub-emitter), so no rain falls inside a house;
## - snow: pixel flakes swirling down with the wind; they settle on what they hit and fade there;
## - mist: a few low lit sheets (mist.gdshader), always below knee height (Caio's no-veil rule);
## - the collision heightfield (GPUParticlesCollisionHeightField3D): snapped to a 1 m grid around
##   the focus instead of following the camera every frame, refreshed a few times per second while
##   something falls (characters walking under the rain), never capturing the weather layer itself.
## Owners set rain / snow / mist (0..1), wind (m/s) and call update(focus, camera) every frame.
## Amounts come from the covered area, the density and the graphics budget
## (GfxQuality.particles()); set_budget() rebuilds them when the tier changes.

const RAIN_H := 13.0  ## m above the ground where drops are born
const RAIN_SPEED := Vector2(11.0, 14.0)
const SNOW_H := 7.5
const MIST_HEIGHTS := [0.05, 0.2, 0.38, 0.6]
const FIELD_HEIGHT := 60.0
const FIELD_SNAP := 1.0
const REFRESH := 0.3  ## s between heightfield refreshes while rain or snow falls
const RAIN_DENSITY := 7.0  ## drops in the air per square metre at full rain
const SNOW_DENSITY := 3.5
const AMOUNT_MAX := 16000

var area := Vector2(18.0, 18.0)  ## half extents (m) of the covered area
var follow := true  ## true: follows update()'s focus; false: fixed on `center`
var center := Vector3.ZERO
var budget := 1.0
var rain_density := RAIN_DENSITY
var snow_density := SNOW_DENSITY
var collide := true
var mist_enabled := true
var field_resolution := GPUParticlesCollisionHeightField3D.RESOLUTION_512

var rain := 0.0
var snow := 0.0
var mist := 0.0
var wind := Vector2.ZERO  ## horizontal wind, m/s
var ground_y := 0.0

var rain_p: GPUParticles3D
var splash_p: GPUParticles3D
var snow_p: GPUParticles3D
var field: GPUParticlesCollisionHeightField3D
var mist_sheets: Array[MeshInstance3D] = []

var _rain_mat: ShaderMaterial
var _snow_mat: ShaderMaterial
var _refresh_t := 0.0
var _focus := Vector3.ZERO
var _built := false


## A rig with `opts` (area, follow, center, budget, rain_density, snow_density, collide, mist,
## resolution), ready to add to the tree.
static func make(opts := {}) -> WeatherRig:
	var r := WeatherRig.new()
	r.name = String(opts.get("name", "WeatherRig"))
	r.area = opts.get("area", r.area)
	r.follow = bool(opts.get("follow", true))
	r.center = opts.get("center", Vector3.ZERO)
	r.ground_y = r.center.y
	r.budget = float(opts.get("budget", GfxQuality.particles()))
	r.rain_density = float(opts.get("rain_density", RAIN_DENSITY))
	r.snow_density = float(opts.get("snow_density", SNOW_DENSITY))
	r.collide = bool(opts.get("collide", true))
	r.mist_enabled = bool(opts.get("mist", true))
	r.field_resolution = int(opts.get("resolution", r.field_resolution))
	return r


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	_focus = center
	if collide:
		_build_field()
	_build_rain()
	_build_snow()
	if mist_enabled:
		_build_mist()
	update(center, null, 0.0)


## Rain drops at full rain on this tier.
func rain_amount() -> int:
	return clampi(int(area.x * area.y * 4.0 * rain_density * budget), 200, AMOUNT_MAX)


func snow_amount() -> int:
	return clampi(int(area.x * area.y * 4.0 * snow_density * budget), 150, AMOUNT_MAX)


## New particle budget (graphics tier): the emitters restart with the new amounts.
func set_budget(b: float) -> void:
	budget = maxf(b, 0.1)
	if rain_p:
		rain_p.amount = rain_amount()
		splash_p.amount = clampi(rain_p.amount / 3, 100, 6000)
	if snow_p:
		snow_p.amount = snow_amount()


func _particles(n: String, amount: int, life: float, h: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.local_coords = false
	p.emitting = false
	p.amount = amount
	p.amount_ratio = 0.0
	p.lifetime = life
	p.layers = WeatherKit.LAYER
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.collision_base_size = 0.02
	p.visibility_aabb = AABB(
		Vector3(-area.x - 10.0, -h - 6.0, -area.y - 10.0),
		Vector3(area.x * 2.0 + 20.0, h + 12.0, area.y * 2.0 + 20.0)
	)
	add_child(p)
	return p


func _build_field() -> void:
	field = GPUParticlesCollisionHeightField3D.new()
	field.name = "RainCollision"
	field.size = Vector3(area.x * 2.0 + 8.0, FIELD_HEIGHT, area.y * 2.0 + 8.0)
	field.resolution = field_resolution
	field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	field.follow_camera_enabled = false
	field.heightfield_mask = 0xFFFFF & ~WeatherKit.LAYER
	field.cull_mask = WeatherKit.LAYER
	add_child(field)


func _build_rain() -> void:
	rain_p = _particles("Rain", rain_amount(), (RAIN_H + 3.0) / RAIN_SPEED.x, RAIN_H)
	rain_p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	# One process step per rendered frame (no fixed_fps): with fixed steps a slow frame runs the
	# drops several times and each step resets the sub-emitter's queue, losing most splashes.
	rain_p.fixed_fps = 0
	rain_p.preprocess = 1.5  # the sky is full of drops from the first frame of a shower
	var pm := ShaderMaterial.new()
	pm.shader = load("res://gfx/weather/rain_particles.gdshader")
	pm.set_shader_parameter("extents", Vector3(area.x, 0.6, area.y))
	pm.set_shader_parameter("speed", RAIN_SPEED)
	pm.set_shader_parameter("splashes", collide)
	rain_p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.42)
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://gfx/weather/rain.gdshader")
	q.material = _rain_mat
	rain_p.draw_pass_1 = q
	if not collide:
		return
	splash_p = _particles("Splashes", clampi(rain_p.amount / 3, 100, 6000), 0.3, RAIN_H)
	splash_p.emitting = true
	splash_p.amount_ratio = 1.0  # a sub-emitter's capacity: the drops decide how many splash
	splash_p.fixed_fps = 0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://gfx/weather/splash_particles.gdshader")
	splash_p.process_material = sm
	splash_p.draw_passes = 2
	var ring := PlaneMesh.new()
	ring.size = Vector2(0.26, 0.26)
	ring.material = _splash_mat(WeatherKit.ring_tex(), false)
	splash_p.draw_pass_1 = ring
	var crown := QuadMesh.new()
	crown.size = Vector2(0.26, 0.26)
	crown.center_offset = Vector3(0.0, 0.12, 0.0)
	var cm := _splash_mat(WeatherKit.crown_sheet(), true)
	crown.material = cm
	splash_p.draw_pass_2 = crown
	rain_p.sub_emitter = rain_p.get_path_to(splash_p)


## Splash look: lit (never glowing at night), alpha from the particle colour; the crown is a
## billboard that plays its 4 frames over the splash's life.
static func _splash_mat(tex: Texture2D, crown: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.albedo_color = Color(0.9, 0.94, 1.0, 0.32 if not crown else 0.8)
	m.roughness = 0.2
	m.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_NEAREST if crown else BaseMaterial3D.TEXTURE_FILTER_LINEAR
	)
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if crown:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = false
	return m


func _build_snow() -> void:
	snow_p = _particles("Snow", snow_amount(), 11.0, SNOW_H)
	snow_p.fixed_fps = 30
	snow_p.preprocess = 6.0  # snow that starts (or a forced snap) fills the whole column at once
	_snow_mat = ShaderMaterial.new()
	_snow_mat.shader = load("res://gfx/weather/snow_particles.gdshader")
	_snow_mat.set_shader_parameter("extents", Vector3(area.x, 0.8, area.y))
	snow_p.process_material = _snow_mat
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.11)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = WeatherKit.flake_sheet()
	m.albedo_color = Color(0.97, 0.98, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 4
	m.particles_anim_v_frames = 1
	m.roughness = 0.9
	m.disable_receive_shadows = true
	m.backlight_enabled = true
	m.backlight = Color(0.5, 0.5, 0.55)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.6, 0.7)
	m.emission_energy_multiplier = 0.06
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA  # no giant flakes on the lens
	m.distance_fade_min_distance = 1.5
	m.distance_fade_max_distance = 4.0
	q.material = m
	snow_p.draw_pass_1 = q


func _build_mist() -> void:
	var sh := load("res://gfx/weather/mist.gdshader") as Shader
	for i in MIST_HEIGHTS.size():
		var mi := MeshInstance3D.new()
		mi.name = "Mist%d" % i
		var pm := PlaneMesh.new()
		pm.size = area * 2.0 + Vector2(8.0, 8.0)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("layer", float(i) / maxf(MIST_HEIGHTS.size() - 1, 1))
		m.set_shader_parameter("radius", maxf(area.x, area.y) + 2.0)
		# Under every other transparent thing (sprites drawn after it stay crisp above the mist).
		m.render_priority = -20 + i
		mi.material_override = m
		mi.layers = WeatherKit.LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		mist_sheets.append(mi)


## Per frame: moves the emitters (follow rigs), snaps and refreshes the heightfield, applies the
## levels and the wind. `cam` (optional) puts more of the rain between the lens and the focus.
func update(focus: Vector3, cam: Camera3D, delta: float) -> void:
	if not _built:
		return
	var at := focus if follow else center
	_focus = at
	var gy := at.y if follow else ground_y
	var back := Vector3.ZERO
	if cam and follow:
		var b := cam.global_transform.basis.z
		back = Vector3(b.x, 0.0, b.z).normalized() * minf(area.y * 0.25, 5.0)
	var w3 := Vector3(wind.x, 0.0, wind.y)
	var fall_t := RAIN_H / ((RAIN_SPEED.x + RAIN_SPEED.y) * 0.5)
	var any := rain > 0.002 or snow > 0.002
	if rain_p:
		var rp := Vector3(at.x, gy + RAIN_H, at.z) + back - w3 * fall_t
		if not follow:
			rp = Vector3(center.x, ground_y + RAIN_H, center.z) - w3 * fall_t
		rain_p.global_position = rp
		var pm := rain_p.process_material as ShaderMaterial
		pm.set_shader_parameter("wind", w3)
		_emit(rain_p, rain)
		if splash_p:
			splash_p.global_position = rp
	if snow_p:
		var sp := Vector3(at.x, gy + SNOW_H, at.z) + back - w3 * 0.7 * SNOW_H
		if not follow:
			sp = Vector3(center.x, ground_y + SNOW_H, center.z) - w3 * 0.7 * SNOW_H
		snow_p.global_position = sp
		_snow_mat.set_shader_parameter("wind", w3)
		_emit(snow_p, snow)
	if field:
		var c := at if follow else center
		var s := Vector3(
			snappedf(c.x, FIELD_SNAP), gy + FIELD_HEIGHT * 0.5 - 10.0, snappedf(c.z, FIELD_SNAP)
		)
		if not s.is_equal_approx(field.global_position):
			field.global_position = s
			_refresh_t = REFRESH
		_refresh_t -= delta
		if any and _refresh_t <= 0.0 and field.is_inside_tree():
			_refresh_t = REFRESH
			RenderingServer.particles_collision_height_field_update(field.get_base())
	var m := clampf(mist, 0.0, 1.0)
	for mi in mist_sheets:
		mi.visible = m > 0.003
		if not mi.visible:
			continue
		var h := float(MIST_HEIGHTS[mist_sheets.find(mi)])
		mi.global_position = Vector3(snappedf(at.x, 1.0), gy + h, snappedf(at.z, 1.0))
		var mm := mi.material_override as ShaderMaterial
		mm.set_shader_parameter("density", m)
		mm.set_shader_parameter("center", at)


func _emit(p: GPUParticles3D, k: float) -> void:
	p.amount_ratio = clampf(k, 0.0, 1.0)
	p.emitting = k > 0.002


## Covered area's centre right now (the focus for follow rigs).
func focus() -> Vector3:
	return _focus
