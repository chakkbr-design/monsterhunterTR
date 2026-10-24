extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_map_builder.gd
## Builds each zone of route_world with MapBuilder and checks it; then runs route_world.tscn
## (streaming, zone walk, LearnMove freeze).

const ZONES := [
	"pallet_town",
	"route_1",
	"viridian_city",
	"route_22",
	"route_2",
	"viridian_forest",
	"route_2_north",
	"pewter_city"
]

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


func _ground_y(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 5.0, 1)
	)
	return hit.position.y if not hit.is_empty() else -INF


func _run() -> void:
	for id in ZONES:
		await _zone(id)
	await _world()
	print("[map builder] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _zone(id: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var b = load("res://world/map_builder.gd").new()
	b.zone_id = id
	b.items_per_frame = 40  # exercise the frame-sliced path
	holder.add_child(b)
	var t0 := Time.get_ticks_msec()
	b.build()
	if not b.is_built:
		await b.built
	await frames(3)
	var c: Dictionary = b.counts
	print("  %s built in %d ms: %s" % [id, Time.get_ticks_msec() - t0, c])
	check(b.is_built and not b.data.is_empty(), "%s: built from JSON" % id)
	check(int(c.get("ground", 0)) == 1, "%s: has ground" % id)
	check(
		int(c.get("walls", 0)) > 0 and int(c.get("bounds", 0)) > 0,
		"%s: has walls and boundary" % id
	)
	check(
		int(c.get("buildings", 0)) == b.data.get("buildings", []).size(), "%s: all buildings" % id
	)
	check(int(c.get("plateaus", 0)) == b.data.get("plateaus", []).size(), "%s: all plateaus" % id)
	check(
		int(c.get("tall_grass", 0)) == b.data.get("tall_grass", []).size(),
		"%s: all tall grass (%d)" % [id, int(c.get("tall_grass", 0))]
	)
	check(
		int(c.get("spawn_zones", 0)) == b.data.get("spawn_zones", []).size(),
		"%s: all spawn zones" % id
	)
	check(int(c.get("trees", 0)) > 20 and int(c.get("npcs", 0)) > 0, "%s: trees and npcs" % id)
	for g in b.get_children():
		if g.has_method("table") and g.table().is_empty():
			check(false, "%s: %s table '%s' exists" % [id, g.name, g.table_id])
	var space: PhysicsDirectSpaceState3D = b.get_world_3d().direct_space_state
	check(not b.arrivals.is_empty(), "%s: has arrivals" % id)
	for name in b.arrivals:
		var at: Vector3 = b.arrivals[name]
		var gy := _ground_y(space, at)
		check(
			absf(gy - at.y) < 0.35,
			"%s: spawn '%s' on ground (y %.2f, ground %.2f)" % [id, name, at.y, gy]
		)
	if id == "route_1":
		check(
			int(c.get("ramps", 0)) == 6 and int(c.get("ledges", 0)) == 6,
			"route_1: 6 ramps, 6 ledges"
		)
		# Plateau tops are solid at their height.
		check(
			absf(_ground_y(space, Vector3(-20, 1.5, -55)) - 0.9) < 0.05,
			"route_1: band_1 top at 0.9"
		)
		var hy := _ground_y(space, Vector3(-20, 7, -86))
		check(absf(hy - 6.0) < 0.05, "route_1: west hill top at 6 (%.2f)" % hy)
	holder.queue_free()
	await frames(2)


func _world() -> void:
	var game := root.get_node("Game")
	var w: Node3D = load("res://world/route_world.tscn").instantiate()
	root.add_child(w)
	await frames(10)
	var p: CharacterBody3D = get_first_node_in_group("ow_player")
	check(
		w.builders.has("pallet_town") and w.builders.pallet_town.is_built,
		"world: pallet built at start"
	)
	check(
		p.global_position.distance_to(Vector3(-8.3, 0.2, -4.2)) < 0.5,
		"world: player at Pallet start (%s)" % p.global_position
	)
	check(p.is_on_floor(), "world: player standing on ground")
	check(game.party.size() > 0, "world: party seeded")
	game.party.clear()  # no battles (wild charges, grass ambushes) while walking around below
	for i in 600:
		if w.builders.has("route_1") and w.builders.route_1.is_built:
			break
		await physics_frame
	check(w.builders.has("route_1") and w.builders.route_1.is_built, "world: route_1 streamed in")
	check(not w.builders.has("viridian_city"), "world: viridian not loaded yet")

	# LearnMove open -> player frozen (real autoload when registered, else a stand-in).
	var lm: Node = root.get_node_or_null("LearnMove")
	var fake: Node = null
	if lm:
		lm.state = "msg"
	else:
		var src := GDScript.new()
		src.source_code = "extends Node\nfunc is_open() -> bool:\n\treturn true\n"
		src.reload()
		fake = Node.new()
		fake.set_script(src)
		fake.name = "LearnMove"  # after set_script, which resets the name
		root.add_child(fake)
	var before := p.global_position
	# Away from the house: walking into its door now enters it (original door.gd body_entered).
	Input.action_press("move_back")
	await frames(30)
	check(
		p.global_position.distance_to(before) < 0.05,
		(
			"world: frozen while LearnMove.is_open() (moved %.2f)"
			% p.global_position.distance_to(before)
		)
	)
	if lm:
		lm.state = ""
	else:
		fake.free()
	await frames(30)
	Input.action_release("move_back")
	check(p.global_position.distance_to(before) > 1.0, "world: walks again after LearnMove closes")

	# Walk up Route 1's road from the Pallet gate: zone switches and grass/plateaus hold the player.
	p.global_position = Vector3(0, 0.2, -21)
	await frames(30)
	check(w.active_zone == "route_1", "world: active zone route_1 (%s)" % w.active_zone)
	# Ramp: band_1 ramp at x -8.5 on its south edge (z -44) climbs to 0.9.
	p.global_position = Vector3(-8.5, 0.2, -42.3)
	await frames(5)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(
		absf(p.global_position.y - 0.9) < 0.15 and p.global_position.z < -45.0,
		"world: ramp climbs onto band_1 (%s)" % p.global_position
	)
	# Ledge (band_1 south, x -29..-11): walk off the top...
	p.global_position = Vector3(-17.5, 1.1, -46.5)  # gap in the hedge that lines the ledge
	await frames(10)
	Input.action_press("move_back")
	await frames(60)
	Input.action_release("move_back")
	check(
		p.global_position.y < 0.3 and p.global_position.z > -44.0,
		"world: drops off the ledge (%s)" % p.global_position
	)
	# ...but can't walk back up.
	Input.action_press("move_forward")
	await frames(170)
	Input.action_release("move_forward")
	await frames(30)
	check(
		p.global_position.y < 0.3 and p.global_position.z > -44.0,
		"world: ledge is one-way (%s)" % p.global_position
	)
	# Teleport to the north of Route 1: Viridian streams in, Pallet streams out.
	p.global_position = Vector3(0, 2.9, -100)
	for i in 900:
		if (
			w.builders.has("viridian_city")
			and w.builders.viridian_city.is_built
			and not w.builders.has("pallet_town")
		):
			break
		await physics_frame
	check(
		w.builders.has("viridian_city") and w.builders.viridian_city.is_built,
		"world: viridian streamed in"
	)
	check(not w.builders.has("pallet_town"), "world: pallet streamed out")
	check(
		p.global_position.y > 2.0 and p.is_on_floor(),
		"world: standing on route_1 band_3 (y %.2f)" % p.global_position.y
	)
	p.global_position = Vector3(0, 0.2, -150)
	await frames(30)
	check(w.active_zone == "viridian_city" and p.is_on_floor(), "world: in Viridian on the ground")
	var wild := get_nodes_in_group("ow_wild").size()
	check(wild > 0, "world: visible wild mons spawned (%d)" % wild)
	check(
		get_nodes_in_group("ow_interact").size() > 10,
		"world: npcs/signs/doors placed (%d)" % get_nodes_in_group("ow_interact").size()
	)
	w.queue_free()
	await frames(2)
	game.party.clear()
