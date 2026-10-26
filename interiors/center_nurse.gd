class_name CenterNurse
extends HealSpot
## Pokémon Center nurse (or Mom at home), like the original npc.gd Action.HEAL: says `lines`, then
## (with a party) heals with a fade through RouteWorld.heal_with_fade (Game.heal_with_fade there) and
## says `after_heal_lines`. Records Game.flags["last_heal"] = interior id (white-out return point).
## A story hook registered on RouteWorld (set_interact_hook) runs first and can replace the default.

var is_mom := false
var after_heal_lines := PackedStringArray()


func prompt() -> String:
	return "E: Talk"


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	if await InteriorHooks.run(self):
		return
	await say(lines)
	if Game.party.is_empty():
		return
	Game.flags["last_heal"] = String(get_meta("interior", ""))
	await _heal()
	if not after_heal_lines.is_empty():
		await say(after_heal_lines)


func _heal() -> void:
	var w := Overworld.of(self)
	if w and w.has_method("heal_with_fade"):
		await w.heal_with_fade()
		return
	Game.heal_party()
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx("heal"):
		au.sfx("heal")
