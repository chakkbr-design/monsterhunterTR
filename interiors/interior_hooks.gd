class_name InteriorHooks
extends RefCounted
## Story hooks for interior NPCs, keyed "<interior_id>/<role>" (role = the NPC's marker name:
## "nurse", "mom", "clerk", "pc", "daisy", "aide_1"...). A hook is called with the NPC node; it may be
## a coroutine. If it returns true the NPC skips its default behaviour (heal, shop, dialogue).
## Register through RouteWorld.set_interact_hook(); hooks survive scene changes (static), invalid
## callables (freed owners) are skipped.

static var hooks: Dictionary = {}


static func key(interior_id: String, role: String) -> String:
	return "%s/%s" % [interior_id, role]


static func set_hook(interior_id: String, role: String, cb: Callable) -> void:
	if cb.is_valid():
		hooks[key(interior_id, role)] = cb
	else:
		hooks.erase(key(interior_id, role))


## Runs the hook for this NPC (if any). Returns true when the hook handled the interaction.
static func run(npc: Node) -> bool:
	var k := key(String(npc.get_meta("interior", "")), String(npc.get_meta("role", "")))
	var cb: Callable = hooks.get(k, Callable())
	if not cb.is_valid():
		return false
	var r = await cb.call(npc)
	return r == true
