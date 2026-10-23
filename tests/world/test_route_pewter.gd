extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_route_pewter.gd
## Rodada 4: Route 22, Route 2, Viridian Forest, Route 2 north and Pewter in RouteWorld streaming —
## every arrival on the ground, Viridian's north wall follows has_pokedex, forest density, visible
## spawns, forest trainers, the Route 22 rival (once, after the Pokédex, autoplay) and Pewter's east exit closed.

const NEW_ZONES := ["route_22", "route_2", "viridian_forest", "route_2_north", "pewter_city"]
const FOREST_TRAINERS := ["bug_catcher_rick", "bug_catcher_doug", "bug_catcher_anthony", "bug_catcher_charlie", "bug_catcher_sammy"]

var _fails := 0
var Trainer
var Builder
var MonS
var DexS
var game: Node
var w: Node3D
var p: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func until(cond: Callable, secs := 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			return false
		await physics_frame
	return true


func _run() -> void:
	game = root.get_node("Game")
	Trainer = load("res://world/trainer.gd")
	Builder = load("res://world/map_builder.gd")
	MonS = load("res://core/mon.gd")
	DexS = load("res://core/dex.gd")
	game.save_path = "user://test_route_pewter_save.json"
	game.new_game("ASH", "GARY")
	game.flags["got_starter"] = true
	game.flags["rival_starter"] = "Squirtle"
	game.spawn_request = {"zone": "viridian_city", "spawn": "vc_north"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	await _zones_listed()
	await _flag_wall()
	await _arrivals()
	await _streaming_north()
	await _forest()
	await _pewter_east()
	await _rival_route22()
	w.queue_free()
	await frames(2)
	print("[route pewter] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _zones_listed() -> void:
	for z in NEW_ZONES:
		check(w.zones.has(z), "world.json zone %s streamed by RouteWorld" % z)
	check(w.location_id == "viridian_city", "starts in Viridian (%s)" % w.location_id)


func _flag_wall() -> void:
	var b = w.builders.viridian_city
	check(not b.flag_wall_open(0), "Viridian north wall closed without the Pokédex")
	game.flags["has_pokedex"] = true
	await frames(30)
	check(b.flag_wall_open(0), "Viridian north wall opens with flags.has_pokedex (live)")
	game.flags["has_pokedex"] = false
	await frames(30)
	check(not b.flag_wall_open(0), "and closes again when the flag is cleared")
	game.flags["has_pokedex"] = true
	await frames(30)


func _arrivals() -> void:
	game.party.clear()  # no wild charges while hopping around
	for z in NEW_ZONES:
		var t0 := Time.get_ticks_msec()
		await w.go_to_zone(z, "")
		var ms := Time.get_ticks_msec() - t0
		var b = w.builders[z]
		check(b.is_built, "%s built (%d ms sync)" % [z, ms])
		for sp in b.arrivals:
			await w.go_to_zone(z, sp)
			await frames(8)
			var at: Vector3 = b.arrivals[sp]
			check(p.is_on_floor() and absf(p.global_position.y - at.y) < 0.4, "%s/%s: lands on the ground (%s)" % [z, sp, p.global_position])


func _streaming_north() -> void:
	# Walk-free hop: teleport onto Route 2 from Viridian's north gap; the zone switch follows the player.
	await w.go_to_zone("viridian_city", "vc_north")
	await frames(10)
	p.global_position = Vector3(0, 0.3, -200)
	check(await until(func(): return w.active_zone == "route_2", 10.0), "walks into Route 2 (%s)" % w.active_zone)
	p.global_position = Vector3(5, 0.3, -232)
	check(await until(func(): return w.builders.has("viridian_forest") and w.builders.viridian_forest.is_built, 30.0),
			"Viridian Forest streams in near the gate")
	var b = w.builders.route_2
	check(b.get_node_or_null("Door_forest_gate") != null and b.get_node_or_null("BackDoor_forest_gate") != null,
			"Route 2 gatehouse has front and back doors")


func _forest() -> void:
	game.party.clear()
	game.add_mon(MonS.create("pidgey", 5))
	await w.go_to_zone("viridian_forest", "vf_mid")
	await frames(20)
	var b = w.builders.viridian_forest
	var c: Dictionary = b.counts
	check(int(c.get("trees", 0)) > 1000 and int(c.get("tall_grass", 0)) >= 30, "forest is dense (%d trees, %d grass)" % [c.get("trees", 0), c.get("tall_grass", 0)])
	var mm := 0
	for n in b.get_children():
		if n is MultiMeshInstance3D:
			mm += 1
	check(mm >= 3, "trees/props batched into MultiMeshes (%d)" % mm)
	var found: Array = []
	for n in b.get_children():
		if n.get_script() == Trainer:
			found.append(n.trainer_id)
	for id in FOREST_TRAINERS:
		check(found.has(id), "forest trainer %s placed" % id)
	check(not w.builders.has("route_1") or not w.builders.route_1.find_children("Trainer_Rick", "", true, false).size() > 0, "Rick moved off Route 1")
	var tables := {}
	for g in b.get_children():
		if g.has_method("table"):
			tables[g.table_id] = true
			if g.table().is_empty():
				check(false, "forest grass table '%s' exists" % g.table_id)
	check(tables.has("viridian_forest"), "forest uses its own encounter table")
	var wild := 0
	for n in get_nodes_in_group("ow_wild"):
		if w.zone_at(n.global_position) == "viridian_forest":
			wild += 1
	check(wild > 0, "visible wild mons in the forest (%d)" % wild)
	for z in ["route_22", "route_2", "route_2_north", "pewter_city"]:
		var tb := {}
		for f in Builder.load_map(z).get("spawn_zones", []) + Builder.load_map(z).get("tall_grass", []):
			tb[String(f.get("table", z))] = true
		for t in tb:
			check(not DexS.encounter_table(t).is_empty(), "%s: encounter table '%s' exists" % [z, t])


func _pewter_east() -> void:
	game.party.clear()
	var st := root.get_node_or_null("Story")
	if st:
		st.auto_advance = true
	await w.go_to_zone("pewter_city", "pw_east")
	await frames(10)
	check(not w.zones.has("route_3"), "Route 3 not built (blocked)")
	Input.action_press("move_right")
	await frames(240)
	Input.action_release("move_right")
	await until(func(): return st == null or not st.is_running(), 10.0)
	check(p.global_position.x < 47.0 and w.zone_at(p.global_position) == "pewter_city", "east exit stays closed (x %.1f)" % p.global_position.x)
	var sign: Node = w.builders.pewter_city.get_node_or_null("Route3Closed")
	check(sign != null and String(sign.lines[0]).contains("CONSTRUÇÃO"), "'Em construção' sign at the east exit")
	if st:
		st.auto_advance = false


func _rival_route22() -> void:
	game.party.clear()
	game.add_mon(MonS.create("charmander", 40))
	Trainer.battle_extra = {"autoplay": true, "seed": 3, "speed": 3.0}
	var st := root.get_node_or_null("Story")
	if st:
		st.auto_advance = true
	game.flags["has_pokedex"] = false
	await w.go_to_zone("route_22", "r22_east")
	await frames(10)
	var rival: Node = w.builders.route_22.get_node_or_null("Trainer_Blue")
	check(rival != null and not rival.visible, "Route 22 rival hidden before the Pokédex")
	game.flags["has_pokedex"] = true
	await frames(5)
	check(rival.visible and rival.npc_name == "GARY", "rival appears after the Pokédex, named {RIVAL} (%s)" % rival.npc_name)
	p.global_position = rival.global_position + Vector3(0, 0.3, 3.0)
	check(await until(func(): return game.is_busy(), 10.0), "rival spots the player and starts the battle")
	check(await until(func(): return game.flags.get("rival2_done", false), 180.0), "rival battle finishes (rival2_done)")
	check(game.flags.get("rival2_won", false) and game.flags.get("trainer_rival_blue_route22", false), "won against the rival")
	var wr: WeakRef = weakref(rival)
	check(await until(func(): return wr.get_ref() == null, 20.0), "rival walks off and is removed")
	await frames(5)
	check(not p.locked, "player free after the encounter")
	# Only once: a fresh build of Route 22 keeps him away.
	await w.go_to_zone("route_22", "r22_east")
	var again: Node = w.builders.route_22.get_node_or_null("Trainer_Blue")
	check(again == null or not again.visible, "rival does not come back")
	Trainer.battle_extra = {}
	if st:
		st.auto_advance = false
