class_name WorldNpc
extends StaticBody3D
## Placeholder NPC (capsule + name tag) that talks through the HUD dialogue box. Faces its local -Z.

const GROUP := "ow_interact"
const LAYER := 8

@export var npc_name := "Villager"
@export var lines: PackedStringArray = ["Olá!"]
@export var color := Color(0.3, 0.45, 0.85)
@export var body_height := 1.6

var _tag: Label3D


static func make_alert(height: float) -> Label3D:
	var a := Label3D.new()
	a.text = "!"
	a.font_size = 96
	a.outline_size = 18
	a.modulate = Color(1.0, 0.85, 0.2)
	a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a.no_depth_test = true
	a.position.y = height
	a.visible = false
	return a


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = body_height
	col.shape = cap
	col.position.y = body_height * 0.5
	add_child(col)
	_build_body()
	_tag = Label3D.new()
	_tag.text = npc_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font_size = 72
	_tag.outline_size = 14
	_tag.position.y = body_height + 0.35
	add_child(_tag)


func _build_body() -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = body_height
	cm.material = Overworld._mat(color)
	mi.mesh = cm
	mi.position.y = body_height * 0.5
	add_child(mi)
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.18, 0.3)
	bm.material = Overworld._mat(Color(0.1, 0.1, 0.1))
	nose.mesh = bm
	nose.position = Vector3(0, body_height - 0.15, -0.3)
	add_child(nose)


func prompt() -> String:
	return "E: Talk"


func face(pos: Vector3) -> void:
	var to := pos - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)


## Called by the player on interact; the player stays locked until this returns.
func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	await say(lines)


func say(text: PackedStringArray) -> void:
	var hud := Overworld.hud_of(self)
	if hud:
		await hud.say(npc_name, text)
