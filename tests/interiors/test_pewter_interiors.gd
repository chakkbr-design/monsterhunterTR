extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/interiors/test_pewter_interiors.gd
## Rodada 4 rooms: forest gatehouses (front + back exits), Pewter Center (heal, PC -> PCStorage),
## Mart (pewter stock), Gym (Brock + Liam), Museum, houses. Every map door round-trips.

const NEW_ROOMS := [
	"forest_gate_south",
	"forest_gate_north",
	"pokemon_center_pewter",
	"mart_pewter",
	"pewter_gym",
	"pewter_museum",
	"pewter_house1",
	"pewter_house2"
]

var _fails := 0
var game: Node
var w: Node3D
var p: CharacterBody3D
var Defs


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _walk_until(action: String, cond: Callable, max_frames := 150) -> bool:
	Input.action_press(action)
	for i in max_frames:
		if cond.call():
			break
		await physics_frame
	Input.action_release(action)
	await frames(3)
	return cond.call()


func _until(cond: Callable, max_frames := 240) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


## Runs npc.interact(p), pressing through the dialogue; `during` is called every step (e.g. to close a UI).
func _talk(npc: Node, during := Callable()) -> void:
	var done := [false]
	var run := func():
		await npc.interact(p)
		done[0] = true
	run.call()
	var hud = get_first_node_in_group("ow_hud")
	for i in 120:
		if done[0]:
			break
		await frames(15)
		if during.is_valid():
			during.call()
		hud.advanced.emit()


func _run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_pewter_interiors_save.json"
	game.new_game("ASH", "GARY")
	Defs = load("res://interiors/interior_defs.gd")
	game.spawn_request = {"interior": "pokemon_center_pewter", "spawn": "door"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(5)
	p = get_first_node_in_group("ow_player")
	check(w.location_id == "pokemon_center_pewter", "spawn_request into the Pewter Center")
	await _rooms()
	await _doors()
	await _gates()
	await _center()
	await _mart_and_gym()
	w.queue_free()
	await frames(2)
	print("[pewter interiors] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _rooms() -> void:
	var space := w.get_world_3d().direct_space_state
	for id in NEW_ROOMS:
		var r = w.interior(id)
		check(r != null and r.get_node_or_null("Floor") != null, "%s: built" % id)
		for sp in r.spawns:
			var at: Vector3 = r.spawn_point(sp)
			var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN, 1)
			)
			check(
				not hit.is_empty() and absf(hit.position.y - at.y) < 0.05,
				"%s/%s: spawn on the floor" % [id, sp]
			)
	# Rooms do not overlap each other (old slots kept).
	var xs := {}
	for id in Defs.ORDER:
		xs[w.interior(id).global_position.x] = true
	check(xs.size() == Defs.ORDER.size(), "every room has its own slot (%d)" % xs.size())
	check(
		(
			w.interior("forest_gate_south").has_spawn("back")
			and w.interior("forest_gate_north").has_spawn("back")
		),
		"gatehouses have a back exit"
	)


func _doors() -> void:
	for pair in [
		["pokemon_center_pewter", "pw_center_door"],
		["mart_pewter", "pw_mart_door"],
		["pewter_gym", "pw_gym_door"],
		["pewter_museum", "pw_museum_door"],
		["pewter_house1", "pw_house1_door"],
		["pewter_house2", "pw_house2_door"]
	]:
		await w.go_to_zone("pewter_city", pair[1])
		await frames(5)
		var door: Node = null
		for c in w.builders.pewter_city.get_children():
			if (
				c.has_method("leads_inside")
				and Defs.DOOR_TARGETS.get(c.target_spawn, [""])[0] == pair[0]
			):
				door = c
		check(door != null and door.prompt() == "E: Entrar", "pewter door leads to %s" % pair[0])
		if door == null:
			continue
		await door.interact(p)
		check(
			(
				w.location_id == pair[0]
				and p.global_position.distance_to(w.interior(pair[0]).spawn_point("door")) < 0.6
			),
			"door -> %s/door" % pair[0]
		)
		await frames(40)
		if pair[0] == "pewter_gym":
			game.party.clear()  # Liam can't spot a player without Pokémon
		await _walk_until("move_back", func(): return w.location_kind == "zone")
		var at: Vector3 = w.builders.pewter_city.arrivals[pair[1]]
		check(
			w.location_id == "pewter_city" and p.global_position.distance_to(at) < 0.6,
			(
				"%s exit -> pewter_city/%s (%.2f m off)"
				% [pair[0], pair[1], p.global_position.distance_to(at)]
			)
		)


## Gatehouse: front door from the south, walk through to the back exit (north), then back again.
func _gates() -> void:
	game.party.clear()
	for g in [
		[
			"route_2",
			"forest_gate_south",
			"r2_forest_gate_door",
			"r2_forest_gate_back",
			"forest_gate"
		],
		["route_2_north", "forest_gate_north", "r2n_gate_door", "r2n_gate_back", "r2n_gate"]
	]:
		await w.go_to_zone(g[0], g[2])
		await frames(5)
		var b = w.builders[g[0]]
		var front: Node = b.get_node_or_null("Door_%s" % g[4])
		var back: Node = b.get_node_or_null("BackDoor_%s" % g[4])
		check(
			front != null and back != null and front.leads_inside() and back.leads_inside(),
			"%s: gate doors lead inside" % g[1]
		)
		if front == null or back == null:
			continue
		await front.interact(p)
		check(w.location_id == g[1], "front door -> %s" % g[1])
		await frames(40)
		check(
			await _walk_until("move_forward", func(): return w.location_kind == "zone", 300),
			"%s: walk through to the back exit" % g[1]
		)
		b = w.builders[g[0]]  # the zone was unloaded while indoors and rebuilt on the way out
		back = b.get_node_or_null("BackDoor_%s" % g[4])
		var at: Vector3 = b.arrivals[g[3]]
		check(
			p.global_position.distance_to(at) < 0.6,
			(
				"%s back exit -> %s/%s (%.2f m off)"
				% [g[1], g[0], g[3], p.global_position.distance_to(at)]
			)
		)
		await frames(20)
		if back == null:
			check(false, "%s: back door rebuilt" % g[1])
			continue
		await back.interact(p)
		check(
			(
				w.location_id == g[1]
				and p.global_position.distance_to(w.interior(g[1]).spawn_point("back")) < 0.6
			),
			"back door -> %s/back" % g[1]
		)
		await frames(40)
		check(
			await _walk_until("move_back", func(): return w.location_kind == "zone", 300),
			"%s: walk back to the front exit" % g[1]
		)
		at = w.builders[g[0]].arrivals[g[2]]
		check(
			p.global_position.distance_to(at) < 0.6, "%s front exit -> %s/%s" % [g[1], g[0], g[2]]
		)


func _center() -> void:
	game.party.clear()
	game.add_mon(load("res://core/mon.gd").create("bulbasaur", 8))
	var m = game.party[0]
	m.hp = 1
	await w.go_to_interior("pokemon_center_pewter", "counter")
	var r = w.interior("pokemon_center_pewter")
	await frames(5)
	check(p.focus == r.npcs.nurse, "nurse in reach from the counter")
	await _talk(r.npcs.nurse)
	check(
		m.hp == m.max_hp and game.flags.get("last_heal") == "pokemon_center_pewter",
		"Pewter Center heals and sets last_heal"
	)
	# PC terminals open PCStorage when the autoload exists.
	var pcs: Node = root.get_node_or_null("PCStorage")
	check(pcs != null, "PCStorage autoload present")
	for room in ["pokemon_center_pewter", "pokemon_center_viridian", "player_room"]:
		var pc: Node = w.interior(room).npcs.get("pc")
		if pc == null or pcs == null:
			check(false, "%s has a PC" % room)
			continue
		var opened := [false]
		await _talk(
			pc,
			func():
				if pcs.is_open() and pcs.screen != "":
					opened[0] = true
					pcs.close()
		)
		check(opened[0] and not pcs.is_open(), "%s: PC opens PCStorage" % room)


func _mart_and_gym() -> void:
	check(
		w.interior("mart_pewter").npcs.clerk.shop_id == "pewter",
		"Pewter clerk sells the pewter stock"
	)
	var gym = w.interior("pewter_gym")
	var brock: Node = gym.npcs.get("brock")
	var liam: Node = gym.npcs.get("liam")
	check(
		brock != null and brock.trainer_id == "brock" and brock.npc_name == "Líder Brock",
		"Brock in the gym (%s)" % (brock.npc_name if brock else "-")
	)
	check(
		liam != null and liam.trainer_id == "camper_liam" and liam.sight > 0.0,
		"Camper Liam guards the aisle"
	)
	check(
		brock.get_meta("role") == "brock" and brock.get_meta("interior") == "pewter_gym",
		"Brock carries the hook role"
	)
