extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_map_pickups.gd
## Map fidelity to the original (G2a): hidden items (Pallet Potion, Mt. Moon mushrooms / B2F), the two
## pickup lines, Lily's Pidgey, walk-in doors, cut trees that block, the ledge hop and the Pewter
## Youngster without hidden_by_flag. Never writes user://save.json.

var _fails := 0
var game: Node
var w: Node
var p


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _close_dialog() -> void:
	var hud = load("res://world/overworld.gd").hud_of(p)
	for i in 600:
		if hud == null or not hud.is_dialog_open():
			return
		hud.advanced.emit()
		await process_frame


## Holds the move actions so the camera-relative input walks along world_dir (zero = release).
func _hold_dir(world_dir: Vector3) -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if world_dir == Vector3.ZERO:
		return
	var v := world_dir.rotated(Vector3.UP, -p._camera_yaw())
	if v.x > 0.01:
		Input.action_press("move_right", v.x)
	elif v.x < -0.01:
		Input.action_press("move_left", -v.x)
	if v.z > 0.01:
		Input.action_press("move_back", v.z)
	elif v.z < -0.01:
		Input.action_press("move_forward", -v.z)


func _run() -> void:
	game = root.get_node("/root/Game")
	game.save_path = OS.get_user_data_dir().path_join("test_map_pickups_save.json")
	game.save_enabled = false
	game.last_save = {}
	for k in game.flags.keys():
		if String(k).begins_with("item_"):
			game.flags.erase(k)
	game.bag = {}
	game.spawn_request = {"zone": "pallet_town", "spawn": "player_house_door"}
	w = load("res://world/route_world.tscn").instantiate()
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	for i in 600:
		if w.builders.has("pallet_town") and w.builders.pallet_town.is_built:
			break
		await physics_frame
	await frames(30)
	await _hidden_item()
	await _pet()
	await _walk_in_door()
	await _ledge_hop()
	await _cave_items()
	await _cut_trees()
	_youngster()
	print("[map pickups] %d failed" % _fails)
	quit(1 if _fails else 0)


func _hidden_item() -> void:
	var b = w.builders.pallet_town
	var it = b.get_node_or_null("Item_pt_hidden_potion")
	check(it != null, "pallet: hidden Potion built")
	if it == null:
		return
	check(it.prompt() == "" and it.collision_layer == 0, "hidden item: no prompt, no body")
	check(
		it.get_child_count() <= 2, "hidden item: no ball drawn (%d children)" % it.get_child_count()
	)
	var lines: PackedStringArray = it.pickup_lines()
	check(
		(
			lines.size() == 2
			and lines[0] == "Você encontrou Potion!"
			and lines[1] == "Você guardou Potion no bolso de Remédios."
		),
		"pickup lines: %s" % [lines]
	)
	p.global_position = it.global_position + Vector3(0, 0.1, -1.0)
	p.facing = Vector3(0, 0, 1)
	await frames(5)
	check(p.focus == it, "hidden item focusable with E (%s)" % p.focus)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(5)
	await _close_dialog()
	await frames(10)
	check(int(game.bag.get("potion", 0)) == 1, "bag got the Potion (%s)" % [game.bag])
	check(bool(game.flags.get("item_pt_hidden_potion", false)), "flag item_pt_hidden_potion")
	check(not is_instance_valid(it), "hidden item removed")


func _pet() -> void:
	var pet = w.builders.pallet_town.get_node_or_null("LilysPidgey")
	check(
		pet != null and pet.has_method("prompt") and pet.get("owner_name") == "Lily",
		"pallet: Lily's Pidgey exists"
	)
	if pet == null or pet.get("owner_name") == null:
		return
	check(pet.npc_name == "Pidgey de Lily", "pet name '%s'" % pet.npc_name)
	check(pet.is_in_group("ow_interact") and pet.prompt() == "E: Falar", "pet talks with E")
	check(pet.lines.size() == 2 and pet.lines[0] == "Pidgey: Pidge! Pidge!", "pet lines")
	check(pet.global_position.distance_to(Vector3(-3, 0, 7)) < 4.5, "pet stays near home")


func _walk_in_door() -> void:
	var b = w.builders.pallet_town
	var door = b.get_node_or_null("Door_player_house")
	check(door != null and door.leads_inside(), "player house door leads inside")
	if door == null:
		return
	var out: Vector3 = -door.global_transform.basis.z
	out.y = 0.0
	out = out.normalized()
	p.global_position = door.global_position + out * 1.8 + Vector3(0, 0.1, 0)
	await frames(40)
	# Walk straight at the door: no E pressed.
	var entered := false
	_hold_dir(-out)
	for i in 240:
		await physics_frame
		if w.location_id == "player_house":
			entered = true
			break
	_hold_dir(Vector3.ZERO)
	await frames(60)
	check(entered, "walking into the door enters the house (%s)" % w.location_id)
	check(not p.locked, "player free after walking in")
	await w.go_to_zone("pallet_town", "player_house_door")
	await frames(60)
	check(w.location_id == "pallet_town", "back out on the door spawn, not re-entered")


func _ledge_hop() -> void:
	# Route 1 band_1 south ledge (x -29..-11, top 0.9): walking off hops in an arc.
	p.global_position = Vector3(0, 0.2, -21)
	for i in 600:
		if w.builders.has("route_1") and w.builders.route_1.is_built:
			break
		await physics_frame
	p.global_position = Vector3(-17.5, 1.1, -46.5)
	await frames(15)
	var hopped := false
	var peak := -INF
	Input.action_press("move_back")
	for i in 90:
		await physics_frame
		if p.has_meta("ledge_hopping"):
			hopped = true
			peak = maxf(peak, p.global_position.y)
	Input.action_release("move_back")
	await frames(20)
	check(hopped, "ledge: hop started")
	check(peak > 1.0, "ledge: hop arcs above the top (peak %.2f)" % peak)
	check(
		p.global_position.y < 0.3 and p.global_position.z > -44.0,
		"ledge: landed below (%s)" % p.global_position
	)
	check(p.is_physics_processing() and not p.locked, "ledge: controls back after landing")


func _cave_items() -> void:
	var b1: Node = w.interiors.get("mt_moon_b1f")
	var b2: Node = w.interiors.get("mt_moon_b2f")
	check(b1 != null and b2 != null, "Mt. Moon rooms exist")
	if b1 == null or b2 == null:
		return
	if b1.get_node_or_null("Item_mmb1f_tiny1") == null:
		load("res://world/cave_builder.gd").decorate(b1)
		load("res://world/cave_builder.gd").decorate(b2)
	var n := 0
	for id in ["tiny1", "tiny2", "tiny3", "big1", "big2", "big3"]:
		var it = b1.get_node_or_null("Item_mmb1f_%s" % id)
		if it and not it.hidden and it.prompt() == "E: Pegar":
			n += 1
	check(n == 6, "B1F: 6 mushrooms with prompt, no ball (%d)" % n)
	var ms = b2.get_node_or_null("Item_mmb2f_hidden_moon_stone")
	var et = b2.get_node_or_null("Item_mmb2f_hidden_ether")
	check(
		ms != null and et != null and ms.hidden and et.hidden and ms.item_id == "moon_stone",
		"B2F: hidden Moon Stone and Ether"
	)


func _cut_trees() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for zone in ["route_2", "viridian_city"]:
		var b = load("res://world/map_builder.gd").new()
		b.zone_id = zone
		b.decorate = false
		holder.add_child(b)
		b.build()
		if not b.is_built:
			await b.built
		await frames(3)
		var space: PhysicsDirectSpaceState3D = b.get_world_3d().direct_space_state
		for c in b.data.get("cut_trees", []):
			var sp = b.get_node_or_null("Cut_%s" % c.uid)
			check(
				sp != null and sp.npc_name == "Árvore" and sp.lines.size() == 2,
				"%s: cut tree %s built" % [zone, c.uid]
			)
			var at := Vector3(float(c.pos[0]), float(c.get("y", 0.0)) + 0.9, float(c.pos[1]))
			var q := PhysicsPointQueryParameters3D.new()
			q.position = at + Vector3(0.6, 0, 0)
			q.collision_mask = load("res://world/overworld.gd").WALL_LAYER
			check(not space.intersect_point(q).is_empty(), "%s: %s is solid" % [zone, c.uid])
	holder.queue_free()
	await frames(2)


func _youngster() -> void:
	var d: Dictionary = load("res://world/map_builder.gd").load_map("pewter_city")
	for n in d.get("npcs", []):
		if String(n.get("node", "")) == "NPC_Youngster":
			check(not n.has("hidden_by_flag"), "pewter: Youngster stays after the badge (original)")
