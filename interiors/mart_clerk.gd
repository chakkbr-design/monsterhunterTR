class_name MartClerk
extends WorldNpc
## Poké Mart clerk: greets, opens the MartPanel for `shop_id` and says goodbye.
## A story hook (RouteWorld.set_interact_hook(interior, "clerk", cb)) runs first, e.g. to hand over
## Oak's Parcel; returning true skips the shop.

var shop_id := "viridian"
var panel: MartPanel


func prompt() -> String:
	return "E: Falar"


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	if await InteriorHooks.run(self):
		return
	await say(PackedStringArray(["Olá! Bem-vindo ao Poké Mart!"]))
	await open_shop()
	await say(PackedStringArray(["Volte sempre!"]))


func open_shop() -> void:
	if panel == null or not is_instance_valid(panel):
		panel = MartPanel.new()
		panel.name = "MartPanel"
		get_tree().root.add_child(panel)
	await panel.open(shop_id)


func _exit_tree() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
