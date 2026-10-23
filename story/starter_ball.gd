class_name StarterBall
extends Node3D
## Poké Ball de inicial na mesa do laboratório. Interagir chama Story.pick_starter(self).

@export var species := "Bulbasaur"

var _ball: Node3D


func _enter_tree() -> void:
	add_to_group(WorldNpc.GROUP)


func _ready() -> void:
	_ball = Node3D.new()
	_ball.position.y = 0.25
	add_child(_ball)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.is_hemisphere = true
	sm.material = Overworld._mat(Color(0.85, 0.15, 0.15))
	top.mesh = sm
	_ball.add_child(top)
	var bottom := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.215
	bm.height = 0.43
	bm.is_hemisphere = true
	bm.material = Overworld._mat(Color(0.95, 0.95, 0.95))
	bottom.mesh = bm
	bottom.rotation.x = PI
	_ball.add_child(bottom)


func _process(delta: float) -> void:
	if _ball:
		_ball.rotation.y += delta * 0.6


func prompt() -> String:
	return "E: Ver Poké Ball"


func interact(_p: Node) -> void:
	var s := get_node_or_null("/root/Story")
	if s:
		await s.pick_starter(self)


## Some da mesa (o inicial foi escolhido).
func take() -> void:
	remove_from_group(WorldNpc.GROUP)
	var tw := create_tween()
	tw.tween_property(_ball, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(queue_free)
