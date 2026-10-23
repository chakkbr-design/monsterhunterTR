class_name WorldSunShaft
extends Node3D
## Port of the original sun_shaft.gd (forest clearings): two crossed additive cards with the
## sun_shaft shader, tilted toward the sun, plus a dappled light pool on the ground. Strength follows
## WorldTimeOfDay's "shafts" multiplier and breathes slowly.

@export var radius := 2.2
@export var height := 9.0
@export var opacity := 0.2
@export var pool_opacity := 0.22
@export var tilt_deg := 10.0
@export var shaft_seed := 0

var _mats: Array[ShaderMaterial] = []
var _mult := 1.0
var _phase := 0.0


func _ready() -> void:
	add_to_group("sun_shafts")
	var rng := RandomNumberGenerator.new()
	rng.seed = (
		shaft_seed
		if shaft_seed != 0
		else int(absf(global_position.x * 13.0 + global_position.z * 7.0)) + 1
	)
	_phase = rng.randf() * TAU
	var beam := Node3D.new()
	beam.rotation_degrees = Vector3(0, -40.0, tilt_deg)
	add_child(beam)
	var qm := QuadMesh.new()
	qm.size = Vector2(radius * 2.0, height)
	for i in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = _mat(false, rng.randf())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = i * PI / 2.0
		mi.position = Vector3(0, height / 2.0, 0)
		beam.add_child(mi)
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.4, radius * 2.4)
	var pool := MeshInstance3D.new()
	pool.mesh = pm
	pool.material_override = _mat(true, rng.randf())
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position.y = 0.03
	add_child(pool)
	var tod := get_tree().get_first_node_in_group(WorldTimeOfDay.GROUP)
	if tod:
		_mult = tod.shafts_mult()


func _mat(pool: bool, s: float) -> ShaderMaterial:
	var m := WorldFx.shader_mat(
		"sun_shaft",
		{
			"tint": Color(1.0, 0.82, 0.48),
			"strength": pool_opacity if pool else opacity,
			"seed": s,
			"ground_pool": pool
		}
	)
	_mats.append(m)
	return m


func set_period_mult(m: float) -> void:
	_mult = m


func _process(delta: float) -> void:
	_phase += delta * 0.32
	var b := 1.0 + sin(_phase) * 0.22
	for i in _mats.size():
		var base := pool_opacity if i == _mats.size() - 1 else opacity
		_mats[i].set_shader_parameter("strength", base * b * _mult)
