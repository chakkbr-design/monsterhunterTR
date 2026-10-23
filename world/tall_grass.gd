class_name TallGrass
extends Area3D
## Tall-grass patch: tells the player when it enters/leaves; the player rolls encounters while inside.

@export var table_id := "route_1"
@export var size := Vector3(8.0, 1.0, 6.0)
@export var density := 6.0  ## blades per square metre
@export var color := Color(0.25, 0.62, 0.22)

var _blades: MultiMeshInstance3D
var _shake_t := 0.0


func table() -> Dictionary:
	return Dex.encounter_table(table_id)


func _ready() -> void:
	collision_layer = 0
	collision_mask = OverworldPlayer.LAYER
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	add_child(col)
	_build_blades()
	body_entered.connect(_on_body.bind("enter_grass"))
	body_exited.connect(_on_body.bind("exit_grass"))


func _on_body(b: Node3D, method: String) -> void:
	if b.has_method(method):
		b.call(method, self)


func _build_blades() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.18, 0.75, 0.06)
	mesh.material = Overworld._mat(color)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = int(size.x * size.z * density)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in mm.instance_count:
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		var o := Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0.35, rng.randf_range(-0.5, 0.5) * size.z)
		mm.set_instance_transform(i, Transform3D(b, o))
	_blades = MultiMeshInstance3D.new()
	_blades.multimesh = mm
	add_child(_blades)


## Short wobble when something jumps out.
func shake() -> void:
	_shake_t = 0.5


func _process(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t = maxf(_shake_t - delta, 0.0)
	_blades.rotation.z = sin(_shake_t * 40.0) * 0.06 * (_shake_t / 0.5)
