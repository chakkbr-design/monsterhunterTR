class_name MartClerk
extends WorldNpc
## Poké Mart clerk, like the original npc.gd Action.SHOP + Story.lines_for("Clerk"): the shop (MartPanel
## for `shop_id`) opens only with the Pokédex; with Oak's Parcel and no Pokédex it only sends regards,
## and before that the shelves are still being stocked.
## A story hook (RouteWorld.set_interact_hook(interior, "clerk", cb)) runs first, e.g. to hand over
## Oak's Parcel; returning true skips the shop.

var shop_id := "viridian"
var panel: MartPanel


func prompt() -> String:
	return "E: Talk"


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	if await InteriorHooks.run(self):
		return
	var f: Dictionary = Game.flags
	if not bool(f.get("has_pokedex", false)):
		if bool(f.get("has_parcel", false)):
			await say(PackedStringArray(["Thanks! Say hi to Prof. Oak for me."]))
		else:
			await say(
				PackedStringArray(
					[
						"Hello! May I help you?",
						"...Sorry, we're still stocking the shelves. Come back soon!"
					]
				)
			)
		return
	await say(PackedStringArray(["Hello! May I help you?"]))
	await open_shop()


func open_shop() -> void:
	if panel == null or not is_instance_valid(panel):
		panel = MartPanel.new()
		panel.name = "MartPanel"
		get_tree().root.add_child(panel)
	await panel.open(shop_id)


func _exit_tree() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
