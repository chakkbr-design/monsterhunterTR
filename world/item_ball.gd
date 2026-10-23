class_name ItemBall
extends WorldNpc
## Visible item on the ground (map "items"). Picking it up adds it to the bag and sets flags["item_<uid>"].

var uid := ""
var item_id := "potion"
var count := 1


static func taken(item_uid: String) -> bool:
	return bool(Game.flags.get("item_%s" % item_uid, false))


func _build_body() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.material = MapBuilder.mat(color)
	mi.mesh = sm
	mi.position.y = 0.22
	add_child(mi)


func prompt() -> String:
	return "E: Pegar"


func interact(_p: OverworldPlayer) -> void:
	Game.add_item(item_id, count)
	Game.flags["item_%s" % uid] = true
	var nm := String(Dex.item(item_id).get("name", item_id.replace("_", " ").to_upper()))
	visible = false
	await say(PackedStringArray(["Encontrou %s%s!" % [nm, "" if count == 1 else " x%d" % count]]))
	queue_free()
