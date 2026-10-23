extends SceneTree
## Headless smoke run of overworld.tscn (drives input; meant for the no-arena instant-win bridge).
## godot --headless --fixed-fps 60 --path . --script res://tests/world/smoke_overworld.gd

var _fails := 0
var _battles: Array = []


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
	var game := root.get_node("Game")
	game.battle_finished.connect(func(r: Dictionary) -> void: _battles.append(r))
	var scene: Node3D = load("res://world/overworld.tscn").instantiate()
	root.add_child(scene)
	await frames(10)
	var player: CharacterBody3D = get_first_node_in_group("ow_player")
	check(game.party.size() >= 1, "party seeded (%s)" % [game.party[0].display_name if game.party.size() else "-"])
	check(get_nodes_in_group("ow_wild").size() == 3, "spawn zone filled to 3 (%d)" % get_nodes_in_group("ow_wild").size())

	# Walk forward along the path: player should move.
	var start := player.global_position
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(player.global_position.z < start.z - 3.0, "moves forward (dz %.2f)" % (player.global_position.z - start.z))

	# Jump.
	await frames(10)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(10)
	check(player.global_position.y > 0.5, "jumps (y %.2f)" % player.global_position.y)
	await frames(60)

	# Pace inside the big grass patch until an ambush happens.
	_battles.clear()
	player.global_position = Vector3(-15, 0.2, -10)
	await frames(5)
	var dir := "move_right"
	for i in 40:
		Input.action_press(dir)
		await frames(60)
		Input.action_release(dir)
		dir = "move_left" if dir == "move_right" else "move_right"
		if not _battles.is_empty():
			break
	await frames(60)
	check(not _battles.is_empty(), "grass ambush started a wild battle")
	check(get_nodes_in_group("ow_wild").size() <= 3, "ambusher freed after battle")

	# Trainer: step into the sight corridor; press interact to page through dialogue.
	_battles.clear()
	player.global_position = Vector3(0, 0.2, -6)
	for i in 600:
		if i % 20 == 0:
			Input.action_press("interact")
		elif i % 20 == 2:
			Input.action_release("interact")
		await physics_frame
		if game.flags.get("trainer_test_youngster", false) and not player.locked:
			break
	check(not _battles.is_empty() and _battles[0].get("outcome") != null, "trainer spotted player and battled")
	check(game.flags.get("trainer_test_youngster", false), "trainer flagged beaten")
	check(not player.locked, "player unlocked afterwards")

	# Heal spot.
	game.party[0].hp = 1
	player.global_position = Vector3(-4, 0.2, 20.5)  # just north of the heal spot, facing it
	player.facing = Vector3.BACK
	await frames(5)
	for i in 120:
		if i % 20 == 0:
			Input.action_press("interact")
		elif i % 20 == 2:
			Input.action_release("interact")
		await physics_frame
	check(game.party[0].hp == game.party[0].max_hp, "heal spot heals party")

	print("[world smoke] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
