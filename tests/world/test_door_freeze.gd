extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_door_freeze.gd
## Pallet doors with the real fade and zone streaming: the player must never stay locked after a door,
## and Pallet must stay built while the player is in one of its rooms.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var game = root.get_node("/root/Game")
	game.spawn_request = {"zone": "pallet_town", "spawn": "player_house_door"}
	game.last_save = {}
	var w = load("res://world/route_world.tscn").instantiate()
	root.add_child(w)
	await frames(10)
	var p = get_first_node_in_group("ow_player")
	for pair in [
		["Door_player_house", "player_house", "player_house_door"],
		["Door_rival_house", "rival_house", "rival_house_door"],
		["Door_lab", "oak_lab", "lab_door"]
	]:
		await w.go_to_zone("pallet_town", pair[2])
		await frames(30)
		var door: Node = null
		for c in w.builders.pallet_town.get_children():
			if c.has_method("leads_inside") and c.target_spawn == pair[1].replace("oak_", ""):
				door = c
		check(door != null, "door to %s found" % pair[1])
		if door == null:
			continue
		p._interact(door)
		await frames(120)
		check(w.location_id == pair[1], "inside %s (%s)" % [pair[1], w.location_id])
		check(not p.locked, "player not locked after entering %s" % pair[1])
		check(w.builders.has("pallet_town"), "Pallet kept built while inside %s" % pair[1])
	print("FAILS: %d" % _fails)
	quit(1 if _fails else 0)
