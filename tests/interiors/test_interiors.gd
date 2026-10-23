extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/interiors/test_interiors.gd
## Rooms build, spawn_request, stairs, doors round-trip, nurse heals, mart buy/sell (+ panel), no
## encounters indoors, indoor camera, save position, markers.

var _fails := 0
var game: Node
var w: Node3D
var p: CharacterBody3D
var events: Array = []
var Defs = load("res://interiors/interior_defs.gd")
var Shop = load("res://interiors/mart_shop.gd")


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _open_world(req: Dictionary, save: Dictionary = {}) -> void:
	if w:
		w.queue_free()
		await frames(2)
	game.spawn_request = req
	game.last_save = save
	events.clear()
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	w.location_changed.connect(func(k, i): events.append([k, i]))
	root.add_child(w)
	await frames(5)
	p = get_first_node_in_group("ow_player")


func _walk(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(3)


## Holds `action` until cond() is true (or max frames), then releases.
func _walk_until(action: String, cond: Callable, max_frames := 120) -> bool:
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


## Runs npc.interact(p), pressing through the dialogue box until it returns.
func _talk(npc: Node) -> void:
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
		hud.advanced.emit()


func _run() -> void:
	game = root.get_node("Game")
	game.party.clear()
	await _start_in_bedroom()
	await _rooms()
	await _stairs()
	await _doors()
	await _center()
	await _mart()
	await _indoor_safety()
	await _save_position()
	w.queue_free()
	await frames(2)
	print("[interiors] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _start_in_bedroom() -> void:
	await _open_world({"interior": "player_room", "spawn": "bed"})
	var bed: Vector3 = w.interior("player_room").spawn_point("bed")
	check(game.spawn_request.is_empty(), "spawn_request consumed and cleared")
	check(
		p.global_position.distance_to(bed) < 0.5,
		"spawn_request: player on player_room/bed (%s)" % p.global_position
	)
	check(
		w.location_kind == "interior" and w.location_id == "player_room",
		"location is interior player_room"
	)
	check(
		events.size() > 0 and events[-1] == ["interior", "player_room"],
		"location_changed(interior, player_room) on start (%s)" % [events]
	)
	check(game.party.is_empty(), "new game from spawn_request: no test mon seeded")
	await frames(20)
	check(p.is_on_floor(), "standing on the bedroom floor")
	var rig = get_first_node_in_group("ow_camera")
	check(
		is_equal_approx(rig.distance, w.INDOOR_DISTANCE),
		"indoor camera distance (%.1f)" % rig.distance
	)
	check(w.builders.is_empty(), "no outdoor zone built while starting indoors")


func _rooms() -> void:
	for id in Defs.ORDER:
		var r = w.interior(id)
		check(r != null and r.get_node_or_null("Floor") != null, "%s: built (floor)" % id)
		check(
			r.global_position.x >= 9000.0,
			"%s: far from the outdoor map (x %.0f)" % [id, r.global_position.x]
		)
		if id != "player_room":
			check(r.has_spawn("door") and r.triggers.size() > 0, "%s: exit mat + door spawn" % id)
		var sp: Vector3 = r.spawn_point("door" if r.has_spawn("door") else "bed")
		var space := w.get_world_3d().direct_space_state
		var hit := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(sp + Vector3.UP, sp + Vector3.DOWN, 1)
		)
		check(
			not hit.is_empty() and absf(hit.position.y - sp.y) < 0.05, "%s: spawn on the floor" % id
		)
	for m in ["ball_1", "ball_2", "ball_3", "oak", "rival"]:
		check(w.marker("oak_lab", m) is Node3D, "marker oak_lab/%s" % m)
	check(w.marker("mart_viridian", "clerk") is Node3D, "marker mart_viridian/clerk")
	check(
		w.marker("pokemon_center_viridian", "nurse") is Node3D,
		"marker pokemon_center_viridian/nurse"
	)
	check(w.marker("player_house", "mom") is Node3D, "marker player_house/mom")
	check(w.marker("oak_lab", "ball_1").global_position.y > 0.9, "ball markers sit on the table")


func _stairs() -> void:
	var r = w.interior("player_room")
	p.global_position = r.spawn_point("stairs") + Vector3(0, 0.2, 0)
	await frames(40)  # past the re-arm delay
	check(
		await _walk_until("move_right", func(): return w.location_id == "player_house"),
		"bedroom stairs -> player_house (%s)" % w.location_id
	)
	var h = w.interior("player_house")
	check(
		p.global_position.distance_to(h.spawn_point("stairs")) < 0.6,
		"arrives at player_house/stairs"
	)
	await frames(40)
	check(
		await _walk_until("move_right", func(): return w.location_id == "player_room"),
		"house stairs -> player_room"
	)


func _doors() -> void:
	# Bedroom -> house -> out through the exit mat: lands on the player_house door of Pallet.
	await w.go_to_interior("player_house", "door")
	check(w.location_id == "player_house", "go_to_interior(player_house, door)")
	await frames(40)
	check(
		await _walk_until("move_back", func(): return w.location_kind == "zone"),
		"exit mat leads outside (%s %s)" % [w.location_kind, w.location_id]
	)
	var out_at: Vector3 = w.builders.pallet_town.arrivals.player_house_door
	check(
		w.location_id == "pallet_town" and p.global_position.distance_to(out_at) < 0.6,
		"outside at the player_house door (%s vs %s)" % [p.global_position, out_at]
	)
	var rig = get_first_node_in_group("ow_camera")
	check(
		not is_equal_approx(rig.distance, w.INDOOR_DISTANCE),
		"outdoor camera restored (%.1f)" % rig.distance
	)
	check(events.has(["zone", "pallet_town"]), "location_changed(zone, pallet_town)")
	await frames(10)
	# Door node -> room, and back to the same door.
	for pair in [
		["pallet_town", "Door_player_house", "player_house", "player_house_door"],
		["pallet_town", "Door_rival_house", "rival_house", "rival_house_door"],
		["pallet_town", "Door_lab", "oak_lab", "lab_door"],
		["viridian_city", "", "pokemon_center_viridian", "vc_center_door"],
		["viridian_city", "", "mart_viridian", "vc_mart_door"],
		["viridian_city", "", "trainer_school_viridian", "vc_school_door"],
		["viridian_city", "", "viridian_house", "vc_house_door"]
	]:
		await w.go_to_zone(pair[0], pair[3])
		await frames(5)
		var b = w.builders[pair[0]]
		var door: Node = null
		for c in b.get_children():
			if (
				c.has_method("leads_inside")
				and Defs.DOOR_TARGETS.get(c.target_spawn, [""])[0] == pair[2]
			):
				door = c
		check(
			door != null and door.prompt() == "E: Entrar",
			"%s: map door leads to %s" % [pair[0], pair[2]]
		)
		if door == null:
			continue
		await door.interact(p)
		check(
			(
				w.location_id == pair[2]
				and p.global_position.distance_to(w.interior(pair[2]).spawn_point("door")) < 0.6
			),
			"door -> %s/door" % pair[2]
		)
		await frames(40)
		await _walk_until("move_back", func(): return w.location_kind == "zone")
		var at: Vector3 = w.builders[pair[0]].arrivals[pair[3]]
		check(
			w.location_id == pair[0] and p.global_position.distance_to(at) < 0.6,
			(
				"%s exit -> %s/%s (%.2f m off)"
				% [pair[2], pair[0], pair[3], p.global_position.distance_to(at)]
			)
		)


func _center() -> void:
	if game.party.is_empty():
		game.add_mon(Mon.create("bulbasaur", 8))
	var m = game.party[0]
	m.hp = 1
	game.flags.erase("last_heal")
	await w.go_to_interior("pokemon_center_viridian", "counter")
	var nurse: Node = w.interior("pokemon_center_viridian").npcs.nurse
	await frames(5)
	check(p.focus == nurse, "nurse in reach from the counter spawn")
	check(nurse.prompt() == "E: Falar", "nurse prompt in Portuguese")
	await _talk(nurse)
	check(m.hp == m.max_hp, "Pokémon Center heals (%d/%d)" % [m.hp, m.max_hp])
	check(game.flags.get("last_heal") == "pokemon_center_viridian", "last_heal recorded")
	# Hook replaces the default behaviour.
	m.hp = 1
	var called := [false]
	w.set_interact_hook(
		"pokemon_center_viridian",
		"nurse",
		func(_n):
			called[0] = true
			return true
	)
	await nurse.interact(p)
	check(called[0] and m.hp == 1, "story hook runs first and can skip the heal")
	w.set_interact_hook("pokemon_center_viridian", "nurse", Callable())
	m.heal_full()
	var pc: Node = w.interior("pokemon_center_viridian").npcs.pc
	check(pc != null and pc.prompt() == "E: Usar", "PC terminal present")


func _mart() -> void:
	game.money = 3000
	game.bag = {"potion": 2, "oaks_parcel": 1}
	check(Shop.stock("viridian").has("poke_ball"), "viridian stock from shops.json")
	check(Shop.buy("potion", 2), "buy 2 potions")
	check(
		game.money == 3000 - 2 * Shop.price("potion") and game.bag.potion == 4,
		"buy debits money and adds to bag (%d, %s)" % [game.money, game.bag]
	)
	var before: int = game.money
	check(Shop.buy("poke_ball", 10), "buy 10 poké balls")
	check(
		(
			game.money == before - 10 * Shop.price("poke_ball")
			and int(game.bag.get("poke_ball", 0)) == 10
		),
		"10 balls bought"
	)
	check(int(game.bag.get("premier_ball", 0)) == 1, "Premier Ball bonus for 10+ Poké Balls")
	check(not Shop.buy("poke_ball", 9999), "can't buy without money")
	before = game.money
	check(Shop.sell("potion", 3), "sell 3 potions")
	check(
		game.money == before + 3 * Shop.price("potion") / 2 and game.bag.potion == 1,
		"sell pays half price (%d)" % game.money
	)
	check(not Shop.sell("potion", 5), "can't sell more than owned")
	check(
		not Shop.sell("oaks_parcel", 1) and not Shop.sellable().has("oaks_parcel"),
		"key items can't be sold"
	)
	# Panel flow through the clerk: Comprar -> Poké Ball -> qty 3 -> confirm -> back -> Sair.
	await w.go_to_interior("mart_viridian", "counter")
	var clerk = w.interior("mart_viridian").npcs.clerk
	await frames(5)
	check(p.focus == clerk, "clerk in reach from the counter spawn")
	var done := [false]
	var shop := func():
		await clerk.open_shop()
		done[0] = true
	shop.call()
	await frames(2)
	var panel = clerk.panel
	check(panel.is_open() and panel.state == "menu", "mart panel opens")
	before = game.money
	var balls := int(game.bag.get("poke_ball", 0))
	panel.press("ok")  # Comprar
	check(panel.state == "list" and panel.items[0] == "poke_ball", "buy list shows stock")
	panel.press("ok")
	panel.press("right")
	panel.press("right")
	check(panel.qty == 3, "quantity 3")
	panel.press("ok")
	check(
		game.money == before - 3 * Shop.price("poke_ball") and int(game.bag.poke_ball) == balls + 3,
		"panel purchase applied"
	)
	panel.press("back")
	panel.press("down")  # Vender
	panel.press("ok")
	check(
		panel.selling and not panel.items.has("oaks_parcel"),
		"sell list without key items (%s)" % [panel.items]
	)
	panel.press("back")
	panel.press("down")
	panel.press("ok")  # Sair
	await frames(2)
	check(done[0] and not panel.is_open(), "panel closes")


func _indoor_safety() -> void:
	await w.go_to_interior("oak_lab", "door")
	await frames(10)
	var near := 0
	for n in get_nodes_in_group("ow_wild"):
		if n.global_position.distance_to(p.global_position) < 60.0:
			near += 1
	check(near == 0, "no wild mons near an interior")
	var grass := 0
	for n in w.interior("oak_lab").find_children("*", "", true, false):
		if (
			n.has_method("table")
			or String(n.get_script().resource_path if n.get_script() else "").ends_with(
				"spawn_zone.gd"
			)
		):
			grass += 1
	check(grass == 0, "no grass / spawn zones indoors")
	for i in 4:
		await _walk(["move_forward", "move_left", "move_back", "move_right"][i], 50)
	check(
		not game.is_busy() and w.location_id == "oak_lab", "walking indoors never starts a battle"
	)
	check(p._grass.is_empty(), "player not in grass indoors")


func _save_position() -> void:
	await w.go_to_interior("mart_viridian", "door")
	await frames(3)
	var ex: Dictionary = w.save_extra()
	check(
		ex.get("interior") == "mart_viridian" and ex.pos.size() == 3, "save_extra indoors (%s)" % ex
	)
	var pos: Vector3 = p.global_position
	# Continue from that save (interior key) and from a plain {"pos"} save.
	await _open_world({}, ex)
	check(
		w.location_id == "mart_viridian" and p.global_position.distance_to(pos) < 0.5,
		"continue: back in the mart"
	)
	await _open_world({}, {"pos": ex.pos})
	check(w.location_id == "mart_viridian", "continue from a plain pos save inside a room")
	await _open_world({"zone": "viridian_city", "spawn": "vc_center_door"}, ex)
	var at: Vector3 = w.builders.viridian_city.arrivals.vc_center_door
	check(
		w.location_id == "viridian_city" and p.global_position.distance_to(at) < 0.5,
		"spawn_request {zone, spawn} wins over the save"
	)
	ex = w.save_extra()
	check(ex.get("zone") == "viridian_city", "save_extra outdoors (%s)" % ex)
