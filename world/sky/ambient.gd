class_name WorldAmbient
extends Node3D
## The original's camera-following ambience in one node: fireflies (night, firefly shader),
## pollen motes (day, drift with the wind gusts), falling leaves from nearby trees
## (MapBuilder.leaf_points) and the cloud-shadow plane (cloud_shadow shader).
## Gated by WorldTimeOfDay (set_period_mult via the "day_ambient" group) and the rain
## (WorldWeather.camera_cover).

const LEAVES_MAX := 12
const LEAF_RADIUS := 15.0
const LEAF_SIZE := 0.22

var _fireflies: GPUParticles3D
var _pollen: GPUParticles3D
var _pollen_pm: ParticleProcessMaterial
var _clouds: MeshInstance3D
var _leaves: Node3D
var _leaf_mesh: QuadMesh
var _leaf_tex: Array = []
var _live: Array = []
var _leaf_t := 0.0
var _night := 0.0
var _day := 1.0
var _last_cover := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("day_ambient")
	_fireflies = _make_fireflies()
	add_child(_fireflies)
	_pollen = _make_pollen()
	add_child(_pollen)
	_clouds = MeshInstance3D.new()
	_clouds.name = "CloudShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2(280, 280)
	_clouds.mesh = pm
	_clouds.material_override = WorldFx.shader_mat("cloud_shadow")
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.layers = WeatherKit.LAYER  # never a ceiling in the rain's collision heightfield
	add_child(_clouds)
	_leaves = Node3D.new()
	_leaves.name = "Leaves"
	add_child(_leaves)
	_leaf_mesh = QuadMesh.new()
	_leaf_mesh.size = Vector2(LEAF_SIZE, LEAF_SIZE)
	for i in 3:
		var t := WorldFx.tex("textures/fx/leaf_green_%d.png" % i)
		if t:
			_leaf_tex.append(t)


## Called by WorldTimeOfDay through the "day_ambient" group (1 = full day, 0 = night).
func set_period_mult(day: float) -> void:
	_day = day
	_night = 1.0 - day


func _cover() -> float:
	var w := get_tree().get_first_node_in_group(WorldWeather.GROUP)
	if w == null:
		return 0.0
	var c: Dictionary = w.camera_cover()
	return maxf(float(c.wet), float(c.snow))


func _process(delta: float) -> void:
	var rig := get_tree().get_first_node_in_group("ow_camera") as Node3D
	if rig == null:
		return
	var f := rig.global_position
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP) as WorldTimeOfDay
	var indoor := tod != null and tod.indoor
	var cover := _cover()
	if cover > 0.6 and _last_cover < 0.3:  # weather snapped (F9, --weather): no pollen in the rain
		_pollen.restart()
		_fireflies.restart()
	_last_cover = cover
	_fireflies.global_position = f + Vector3(0, 1.0, 0)
	_fireflies.amount_ratio = 0.0 if indoor else clampf(_night * (1.0 - cover), 0.0, 1.0)
	_fireflies.emitting = _fireflies.amount_ratio > 0.01
	_pollen.global_position = f + Vector3(0, 1.5, 0)
	_pollen.amount_ratio = 0.0 if indoor else clampf(_day * (1.0 - cover), 0.0, 1.0)
	_pollen.emitting = _pollen.amount_ratio > 0.01
	_clouds.visible = not indoor
	_clouds.global_position = Vector3(f.x, f.y + 1.0, f.z)
	var wind := get_tree().get_first_node_in_group(WorldWind.GROUP) as WorldWind
	var g := wind.gust() if wind else 0.0
	var wd := wind.dir if wind else Vector2(1, 0)
	_pollen_pm.direction = Vector3(wd.x, 0.25, wd.y)
	_pollen_pm.initial_velocity_min = 0.05 + 0.5 * g
	_pollen_pm.initial_velocity_max = 0.2 + 1.2 * g
	_leaf_t -= delta
	if _leaf_t <= 0.0:
		_leaf_t = _rng.randf_range(0.6, 1.6) * (1.0 - 0.7 * g)
		if _live.size() < LEAVES_MAX and _day > 0.05 and not indoor and cover < 0.5:
			_spawn_leaf(f)
	_update_leaves(delta, g, wd)


func _spawn_leaf(focus: Vector3) -> void:
	var near: Array = []
	for b in get_tree().get_nodes_in_group("map_builder"):
		for p: Vector3 in b.leaf_points:
			if absf(p.x - focus.x) < LEAF_RADIUS and absf(p.z - focus.z) < LEAF_RADIUS:
				near.append(p)
				if near.size() > 40:
					break
	if near.is_empty():
		return
	var tree: Vector3 = near[_rng.randi() % near.size()]
	var mi := MeshInstance3D.new()
	mi.mesh = _leaf_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not _leaf_tex.is_empty():
		mat.albedo_texture = _leaf_tex[_rng.randi() % _leaf_tex.size()]
	else:
		mat.albedo_color = Color(0.5, 0.7, 0.28).lerp(Color(0.75, 0.78, 0.35), _rng.randf())
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leaves.add_child(mi)
	var py := tree.y + 2.0 + _rng.randf_range(-0.4, 0.4)
	mi.global_position = Vector3(
		tree.x + _rng.randf_range(-1.5, 1.5), py, tree.z + _rng.randf_range(-1.5, 1.5)
	)
	_live.append(
		{
			"node": mi,
			"mat": mat,
			"age": 0.0,
			"life": _rng.randf_range(4.0, 7.0),
			"phase": _rng.randf() * TAU,
			"spin": _rng.randf_range(4.0, 9.0),
			"ground": tree.y
		}
	)


func _update_leaves(delta: float, g: float, wd: Vector2) -> void:
	var speed := 2.0 + 4.0 * g
	for i in range(_live.size() - 1, -1, -1):
		var leaf: Dictionary = _live[i]
		var node: MeshInstance3D = leaf.node
		if not is_instance_valid(node):
			_live.remove_at(i)
			continue
		leaf.age += delta
		var p := node.global_position
		p.x += (wd.x * speed + sin(leaf.age * 3.0 + leaf.phase) * 0.7) * delta
		p.z += (wd.y * speed + cos(leaf.age * 2.4 + leaf.phase) * 0.7) * delta
		p.y -= (1.1 + 0.4 * sin(leaf.age * 4.0 + leaf.phase)) * delta
		node.global_position = p
		node.scale = Vector3(absf(sin(leaf.age * leaf.spin + leaf.phase)) * 0.85 + 0.15, 1.0, 1.0)
		var fade := 1.0
		if p.y <= leaf.ground + 0.15:
			fade = clampf((p.y - leaf.ground) / 0.15, 0.0, 1.0)
		if leaf.age > leaf.life - 1.0:
			fade = minf(fade, clampf(leaf.life - leaf.age, 0.0, 1.0))
		var c: Color = leaf.mat.albedo_color
		c.a = fade
		leaf.mat.albedo_color = c
		if leaf.age >= leaf.life or p.y <= leaf.ground - 0.05:
			node.queue_free()
			_live.remove_at(i)


func _make_fireflies() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Fireflies"
	var box := Vector3(20.0, 4.0, 20.0)
	p.amount = 140
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-box, box * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box * 0.5
	pm.gravity = Vector3(0, 0.02, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.15)
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RF)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := clampf(Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			img.set_pixel(x, y, Color(pow(1.0 - d, 1.2), 0.0, 0.0))
	q.material = WorldFx.shader_mat("firefly", {"glow_tex": ImageTexture.create_from_image(img)})
	p.draw_pass_1 = q
	return p


func _make_pollen() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Pollen"
	var box := Vector3(16.0, 3.0, 16.0)
	p.amount = 180
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-box, box * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box * 0.5
	pm.gravity = Vector3(0, -0.02, 0)
	pm.direction = Vector3(1, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.2, 1.0))
	fade.add_point(Vector2(0.8, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.alpha_curve = ct
	_pollen_pm = pm
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.9, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 1.8
	q.material = m
	p.draw_pass_1 = q
	return p
