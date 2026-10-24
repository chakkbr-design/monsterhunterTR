class_name RoomHiddenItem
extends ItemBall
## Hidden item in a room (original item_pickup.gd with hidden = true): nothing is drawn and no prompt
## shows, but interacting finds it once (flag item_<uid>), e.g. the Potion at the bedroom desk.


func _init() -> void:
	show_tag = false


func _build_body() -> void:
	pass


func prompt() -> String:
	return ""


func interact(p: OverworldPlayer) -> void:
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx("item_get"):
		au.sfx("item_get")
	await super.interact(p)
