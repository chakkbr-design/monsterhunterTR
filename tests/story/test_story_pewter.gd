extends SceneTree
## Integração Rodada 4: guia de Pewter leva ao ginásio, aviso da saída leste, Campista Liam e Brock
## (batalha em autoplay) -> flags.badge_boulder + TM39 na bolsa.
## godot --headless --fixed-fps 60 --path . --script res://tests/story/test_story_pewter.gd

var _fails := 0
var game: Node
var story: Node
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
	game.save_path = "user://test_story_pewter_save.json"
	game.new_game("ASH", "GARY")
	for f in [
		"oak_stopped",
		"got_starter",
		"starter_chosen",
		"rival_battle_done",
		"mom_healed",
		"has_pokedex",
		"parcel_delivered"
	]:
		game.flags[f] = true
	game.flags["rival_starter"] = "Charmander"
	game.add_mon(load("res://core/mon.gd").create("squirtle", 28))
	story = root.get_node("Story")
	story.auto_advance = true
	story.auto_answer = true
	story.auto_battle = true
	story.battle_extra = {"seed": 11, "speed": 3.0}
	load("res://world/trainer.gd").battle_extra = {"autoplay": true, "seed": 5, "speed": 3.0}
	game.spawn_request = {"zone": "pewter_city", "spawn": "pw_south"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	await _guide()
	await _east_block()
	await _gym()
	load("res://world/trainer.gd").battle_extra = {}
	w.queue_free()
	await frames(2)
	print("PASSOU (0 falhas)" if _fails == 0 else "FALHOU (%d falhas)" % _fails)
	quit(1 if _fails > 0 else 0)


func _guide() -> void:
	var seen: Array = []
	story.cutscene_started.connect(func(id): seen.append(id))
	check(
		story.triggers().any(func(t): return t.event == "pewter_guide"),
		"gatilho do guia de Pewter criado"
	)
	check(
		story.triggers().any(func(t): return t.event == "pewter_east_block"),
		"gatilho da saída leste (pewter_city.json)"
	)
	Input.action_press("move_forward")
	var started := await until(func(): return seen.has("pewter_guide"), 10.0)
	Input.action_release("move_forward")
	check(started, "entrar em Pewter dispara o guia")
	check(await until(func(): return not story.is_running(), 60.0), "cena do guia termina")
	check(game.flags.get("pewter_guide_done", false), "flag pewter_guide_done")
	var front: Vector3 = w.builders.pewter_city.arrivals.pw_gym_front
	check(
		Vector2(p.global_position.x - front.x, p.global_position.z - front.z).length() < 2.5,
		"guia deixa o jogador na porta do ginásio (%s)" % p.global_position
	)
	await w.go_to_zone("pewter_city", "pw_south")
	await frames(30)
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(seen.count("pewter_guide") == 1, "o guia aparece uma vez só")


func _east_block() -> void:
	var seen: Array = []
	story.cutscene_started.connect(func(id): seen.append(id))
	await w.go_to_zone("pewter_city", "pw_east")
	await frames(10)
	p.global_position = Vector3(43.5, 0.3, -428.4)
	check(
		await until(func(): return seen.has("pewter_east_block"), 5.0),
		"saída leste dispara o aviso"
	)
	check(await until(func(): return not story.is_running(), 20.0), "aviso termina")
	check(p.global_position.x < 41.0, "jogador volta para oeste (x %.1f)" % p.global_position.x)


func _gym() -> void:
	await w.go_to_interior("pewter_gym", "door")
	await frames(10)
	var gym = w.interior("pewter_gym")
	var liam: Node = gym.npcs.liam
	var brock: Node = gym.npcs.brock
	var money0: int = game.money
	# Sobe pelo corredor central: o Liam vê e desafia.
	Input.action_press("move_forward")
	var spotted := await until(func(): return game.is_busy(), 10.0)
	Input.action_release("move_forward")
	check(spotted, "Campista Liam vê o jogador no corredor")
	check(
		await until(func(): return game.flags.get("trainer_camper_liam", false), 180.0),
		"vence o Liam (autoplay)"
	)
	check(
		await until(func(): return not p.locked and not game.is_busy(), 20.0),
		"jogador livre depois do Liam"
	)
	game.heal_party()
	# Brock: interagir passa pelo gancho da história.
	await w.go_to_interior("pewter_gym", "front_of_brock")
	await frames(10)
	check(p.focus == brock, "Brock ao alcance")
	var done := [false]
	var talk := func():
		await brock.interact(p)
		done[0] = true
	talk.call()
	check(await until(func(): return story.current() == "brock", 5.0), "cena do Brock começa")
	check(await until(func(): return game.is_busy(), 20.0), "batalha com o Brock começa")
	check(await until(func(): return done[0], 300.0), "batalha com o Brock termina")
	check(
		String(story.last_battle.get("outcome", "")) == "win",
		"venceu o Brock (%s)" % story.last_battle.get("outcome", "?")
	)
	check(
		game.flags.get("badge_boulder", false) and game.flags.get("boulder_badge", false),
		"flags.badge_boulder (+ boulder_badge)"
	)
	check(game.flags.get("trainer_brock", false), "flags.trainer_brock")
	check(int(game.bag.get("tm39", 0)) == 1, "TM39 (Tumba de Pedras) na bolsa")
	check(game.money >= money0 + 1400, "prêmio do Brock pago (%d -> %d)" % [money0, game.money])
	check(not story.is_running() and not p.locked, "nada travado depois do Brock")
	# Falar de novo: só a conversa, sem nova luta nem novo TM.
	done[0] = false
	talk.call()
	check(await until(func(): return done[0], 20.0), "falar de novo termina")
	check(not game.is_busy() and int(game.bag.get("tm39", 0)) == 1, "sem revanche nem TM repetido")
	# Com a insígnia o guia não volta e o aviso leste vira "em construção".
	check(
		not load("res://story/story_flags.gd").pewter_guide_due(game.flags),
		"guia não volta depois da insígnia"
	)
