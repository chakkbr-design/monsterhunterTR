class_name WorldLedge
extends StaticBody3D
## One-way ledge on a plateau edge: walk off the top to drop down; from below it is a wall you
## cannot jump over. Origin = middle of the edge at the top height; local +Z points outwards (down side).

@export var length := 6.0
@export var drop := 0.9

var _shape: CollisionShape3D
var _below := true


func _ready() -> void:
	collision_layer = Overworld.WALL_LAYER
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, drop + MapBuilder.EDGE_WALL, 0.2)
	_shape.shape = box
	# Sits just inside the edge so a player who dropped down never overlaps it.
	_shape.position = Vector3(0, (MapBuilder.EDGE_WALL - drop) * 0.5, -0.1)
	add_child(_shape)
	var lip := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.18, 0.35)
	bm.material = MapBuilder.mat(Color(0.62, 0.5, 0.36))
	lip.mesh = bm
	lip.position = Vector3(0, 0.05, -0.12)
	add_child(lip)


func _physics_process(_d: float) -> void:
	var p := Overworld.player_of(self)
	if p == null or not p.is_on_floor():
		return  # keep the last state while airborne, so a jump from below can't switch it off
	var below := p.global_position.y < global_position.y - drop * 0.5
	if below != _below:
		_below = below
		_shape.set_deferred("disabled", not below)
