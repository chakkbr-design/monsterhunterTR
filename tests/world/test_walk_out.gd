extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_walk_out.gd
## Luta no mundo (BattleWalkOut): o jogador e o treinador do mundo saem andando da quadra quando a
## batalha começa e ficam fora dela, cada um no fundo do seu lado; na grade (Pallet) param no centro
## de um tile; o adversário é o próprio corpo do mundo (sem boneco); a luta que acaba no meio do
## caminho solta o corpo.

var _fails := 0
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


func _run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_walk_out_save.json"
	game.save_enabled = false
	game.new_game("ASH", "GARY")
	game.flags["got_starter"] = true
	game.add_mon(load("res://core/mon.gd").create("bulbasaur", 5))
	var story = root.get_node_or_null("Story")
	if story:
		story.auto_advance = true
		story.auto_answer = true
	game.spawn_request = {"zone": "pallet_town", "spawn": "start"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	p = get_first_node_in_group("ow_player")
	for i in 600:
		if w.builders.has("pallet_town") and w.builders.pallet_town.is_built and p.grid_active():
			break
		await physics_frame
	await frames(10)
	check(p.grid_active(), "Pallet on the grid")
	await _wild("Pallet (grid)", true)
	await _trainer()
	await _cut_short()
	await w.go_to_zone("route_1", "")
	await frames(30)
	check(not p.grid_active(), "Route 1 walks free")
	await _wild("Route 1 (free)", false)
	print("[walk out] %d failed" % _fails)
	quit(1 if _fails else 0)


## Starts a battle without awaiting it; returns the arena.
func _start(enemies: Array, opts: Dictionary) -> Node:
	var fight := func(): await w.battle(enemies, opts)
	fight.call()
	await frames(3)
	return game._arena


func _end(arena) -> void:
	if is_instance_valid(arena) and game._arena == arena:
		arena.finished.emit({"outcome": "run"})
	await frames(30)


## Off the court (local) by about BattleWalkOut.OUT, behind its own side.
func _outside(arena, n: Node3D, side: int) -> bool:
	var l: Vector3 = arena.to_local(n.global_position)
	var dir: Vector3 = -arena.axis if side == 0 else arena.axis
	var r: Rect2 = arena.rect.grow(BattleWalkOut.OUT - 0.05)
	return not r.has_point(Vector2(l.x, l.z)) and Vector3(l.x, 0, l.z).dot(dir) > 0.0


func _wild(where: String, grid: bool) -> void:
	var start := p.global_position
	var arena = await _start(
		[load("res://core/mon.gd").create("rattata", 3)], {"kind": "wild", "speed": 1.0}
	)
	check(arena != null, "%s: wild battle started" % where)
	if arena == null:
		return
	check(arena._stands.get(0) == p, "%s: the player is the trainer of side 0" % where)
	await frames(15)
	check(p.sprite == null or p.sprite.moving, "%s: the player's sheet walks" % where)
	await frames(240)
	check(
		_outside(arena, p, 0),
		"%s: player off the court (%s)" % [where, arena.to_local(p.global_position)]
	)
	check(p.global_position.distance_to(start) > 3.0, "%s: player walked away" % where)
	if grid:
		var c := Vector2(p.global_position.x, p.global_position.z)
		check(c.distance_to(c.round()) < 0.02, "%s: stops on a tile centre (%s)" % [where, c])
	check(
		arena.trainer_spot(0).distance_to(arena.to_local(p.global_position)) < 0.3,
		"%s: balls come from the player" % where
	)
	await _end(arena)


func _trainer() -> void:
	var t := WorldTrainer.new()
	t.trainer_id = "test_youngster"
	t.sight = 0.0
	w.add_child(t)
	t.global_position = p.global_position + Vector3(0, 0, -1.2)
	await frames(3)
	t.sight = 0.0
	var arena = await _start(
		WorldTrainer.build_party(Dex.trainer("test_youngster")),
		{"kind": "trainer", "trainer_id": "test_youngster", "speed": 1.0, "autoplay": true}
	)
	check(arena != null, "trainer battle started")
	if arena == null:
		t.queue_free()
		return
	check(arena._stands.get(1) == t, "the world trainer stands for side 1")
	check(arena.get_node_or_null("TrainerStand1") == null, "no puppet next to the world trainer")
	await frames(240)
	check(_outside(arena, p, 0), "player off the court (%s)" % arena.to_local(p.global_position))
	check(_outside(arena, t, 1), "trainer off the court (%s)" % arena.to_local(t.global_position))
	await _end(arena)
	t.queue_free()
	await frames(2)


## The battle ends mid-walk: the walk stops with it.
func _cut_short() -> void:
	var arena = await _start(
		[load("res://core/mon.gd").create("rattata", 3)], {"kind": "wild", "speed": 1.0}
	)
	if arena == null:
		check(false, "cut short: battle started")
		return
	await frames(10)
	await _end(arena)
	var at := p.global_position
	await frames(60)
	check(p.global_position.distance_to(at) < 0.6, "the walk stops when the battle ends")
