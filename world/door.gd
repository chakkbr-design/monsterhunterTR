class_name WorldDoor
extends WorldNpc
## Building door. If the map's target_spawn leads to a known interior (InteriorDefs.DOOR_TARGETS) and the
## map root can travel (RouteWorld), "E: Entrar" walks in; otherwise it shows its lines ("Fechado.").

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


func leads_inside() -> bool:
	var w := Overworld.of(self)
	return InteriorDefs.DOOR_TARGETS.has(target_spawn) and w != null and w.has_method("enter_door")


func prompt() -> String:
	return "E: Entrar" if leads_inside() else "E: Olhar"


func interact(_p: OverworldPlayer) -> void:
	if leads_inside():
		await Overworld.of(self).enter_door(target_spawn)
		return
	await say(lines)
