class_name WorldDoor
extends WorldNpc
## Building door marker. Interiors don't exist yet, so it only shows its lines ("Fechado." by default).
## target_scene / target_spawn keep the map's link for when interiors are added.

var target_scene := ""
var target_spawn := ""


func _build_body() -> void:
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 2.0, 0.12)
	bm.material = MapBuilder.mat(color)
	slab.mesh = bm
	slab.position = Vector3(0, 1.0, 0.02)
	add_child(slab)
	var mat := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.5, 0.04, 0.8)
	mm.material = MapBuilder.mat(Color(0.75, 0.3, 0.25))
	mat.mesh = mm
	mat.position = Vector3(0, 0.02, -0.45)
	add_child(mat)


func prompt() -> String:
	return "E: Entrar"


func interact(_p: OverworldPlayer) -> void:
	await say(lines)
