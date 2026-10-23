class_name HealSpot
extends WorldNpc
## Interact to fully heal the party (Game.heal_party). Also the white-out return point.


func _build_body() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1.0, 0.8)
	bm.material = Overworld._mat(color)
	mi.mesh = bm
	mi.position.y = 0.5
	add_child(mi)


func prompt() -> String:
	return "E: Falar"


func interact(_p: OverworldPlayer) -> void:
	Game.heal_party()
	await say(lines)
