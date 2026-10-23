class_name HealSpot
extends WorldNpc
## Interact to fully heal the party (Game.heal_party). Also the white-out return point.
## Drawn as the original's nurse sheet (Mom's at home, via the interior role).


func _build_body() -> void:
	if sprite_sheet == "" and String(get_meta("role", "")) == "":
		sprite_sheet = "npc_nurse"
	if _build_sprite():
		return
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
