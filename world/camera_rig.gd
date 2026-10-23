class_name OverworldCamera
extends Node3D
## Fixed-angle orbit rig that follows the player; cam_left/cam_right turn it in yaw steps.

const GROUP := "ow_camera"

@export_range(15.0, 75.0) var pitch_deg := 38.0
@export var distance := 14.0
@export var follow_sharpness := 6.0
@export var yaw_step_deg := 45.0
@export var yaw_sharpness := 8.0
@export var fov := 45.0

var camera: Camera3D
var _yaw := 0.0
var _yaw_target := 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.far = 220.0
	add_child(camera)
	camera.make_current()
	_yaw = rotation.y
	_yaw_target = _yaw
	var t := Overworld.player_of(self)
	if t:
		global_position = t.global_position
	_apply()


## Current yaw in radians (the player rotates its input by this).
func yaw() -> float:
	return _yaw


func _process(delta: float) -> void:
	if not Game.is_busy():
		if Input.is_action_just_pressed("cam_left"):
			_yaw_target -= deg_to_rad(yaw_step_deg)
		if Input.is_action_just_pressed("cam_right"):
			_yaw_target += deg_to_rad(yaw_step_deg)
	_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-yaw_sharpness * delta))
	var t := Overworld.player_of(self)
	if t:
		global_position = global_position.lerp(t.global_position, 1.0 - exp(-follow_sharpness * delta))
	_apply()


func _apply() -> void:
	var p := deg_to_rad(pitch_deg)
	rotation.y = _yaw
	camera.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	camera.rotation = Vector3(-p, 0.0, 0.0)
