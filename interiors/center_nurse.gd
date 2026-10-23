class_name CenterNurse
extends HealSpot
## Pokémon Center nurse (or Mom at home): heals the party via Game.heal_party, with a short dialogue.
## Records Game.flags["last_heal"] = interior id (RouteWorld sends the player there after a white-out).
## A story hook registered on RouteWorld (set_interact_hook) runs first and can replace the default.

var is_mom := false


func prompt() -> String:
	return "E: Falar"


func interact(p: OverworldPlayer) -> void:
	face(p.global_position)
	if await InteriorHooks.run(self):
		return
	var lines_now := lines
	var n := lines_now.size()
	# Nurse: greeting first, heal while "um momento...", then the rest. Mom: heal, then talk.
	var split := 2 if not is_mom and n >= 3 else 0
	if split > 0:
		await say(lines_now.slice(0, split))
	Game.heal_party()
	Game.flags["last_heal"] = String(get_meta("interior", ""))
	await say(lines_now.slice(split))
