extends SceneTree
## Rodada 5 (Conteúdo do mundo): Rota 3 só com a insígnia, Monte da Lua (andares, escadas de ida e volta),
## Equipe Rocket, escolha do fóssil, estáticos que lutam uma vez.
## godot --headless --fixed-fps 60 --path . --script res://tests/content/test_mt_moon.gd

var _fails := 0
var game: Node
var story: Node
var w: Node3D
var p: CharacterBody3D
var Cave: GDScript  ## load() em vez do class_name: compilar cedo, sem autoloads, quebra


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


## Selvagens fora do caminho: a luta selvagem não tem autoplay e travaria o teste.
func _no_wilds() -> void:
	# Telas de aprender golpe / evoluir esperariam o jogador: o teste recusa tudo.
	if not game.is_busy():
		game.pending_learns.clear()
		game.pending_evolutions.clear()
		var lm := root.get_node_or_null("LearnMove")
		if lm and lm.get("state") != "":
			lm.set("state", "")
			if lm.get("_root"):
				lm.get("_root").visible = false
	for n in get_nodes_in_group("ow_wild"):
		if not game.is_busy() and n.process_mode != Node.PROCESS_MODE_DISABLED:
			n.process_mode = Node.PROCESS_MODE_DISABLED  # sem queue_free: a SpawnZone guarda a referência
			n.visible = false
			n.collision_layer = 0
			n.global_position += Vector3(0, -50, 0)


func frames(n: int) -> void:
	for i in n:
		_no_wilds()
		await physics_frame


func until(cond: Callable, secs := 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			return false
		_no_wilds()
		await physics_frame
	return true


func _run() -> void:
	game = root.get_node("Game")
	Cave = load("res://world/cave_builder.gd")
	game.save_path = "user://test_content_mt_moon_save.json"
	game.new_game("ASH", "GARY")
	for f in [
		"oak_stopped",
		"got_starter",
		"starter_chosen",
		"rival_battle_done",
		"mom_healed",
		"has_pokedex",
		"parcel_delivered",
		"pewter_guide_done",
		"rival2_done"
	]:
		game.flags[f] = true
	game.flags["rival_starter"] = "Charmander"
	# Treinadores da Rota 3 e do 1F já vencidos: o teste cuida da Equipe Rocket e do Miguel.
	for id in [
		"bug_catcher_james",
		"bug_catcher_colton",
		"youngster_ben",
		"bug_catcher_greg",
		"lass_sally",
		"youngster_calvin",
		"lass_robin",
		"lass_janice",
		"lass_iris",
		"bug_catcher_robby",
		"super_nerd_jovan",
		"lass_miriam",
		"bug_catcher_kent",
		"youngster_josh",
		"hiker_marcos"
	]:
		game.flags["trainer_" + id] = true
	game.add_mon(load("res://core/mon.gd").create("blastoise", 50))  # já evoluído: a tela de evolução esperaria o jogador
	story = root.get_node("Story")
	story.auto_advance = true
	story.auto_answer = true
	story.auto_battle = true
	story.battle_extra = {"seed": 11, "speed": 3.0}
	load("res://world/trainer.gd").battle_extra = {"autoplay": true, "seed": 5, "speed": 3.0}
	load("res://story/static_mon.gd").battle_extra = {"autoplay": true, "seed": 7, "speed": 3.0}
	game.spawn_request = {"zone": "pewter_city", "spawn": "pw_east"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	var quick := OS.get_environment("MT_MOON_QUICK") != ""  # só o fim (depuração)
	if not quick:
		await _route3_gate()
		await _mouth()
		await _floors()
		await _ladders()
		await _rockets()
		await _fossils()
	await _exit()
	await _center()
	await _statics()
	load("res://world/trainer.gd").battle_extra = {}
	load("res://story/static_mon.gd").battle_extra = {}
	w.queue_free()
	await frames(2)
	print("PASSOU (0 falhas)" if _fails == 0 else "FALHOU (%d falhas)" % _fails)
	quit(1 if _fails > 0 else 0)


func _free() -> bool:
	return not story.is_running() and not game.is_busy() and not p.locked and not p.ui_blocking()


func _walk(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func _route3_gate() -> void:
	check(w.zones.has("route_3"), "Rota 3 é uma zona da RouteWorld")
	var pw = w.builders.pewter_city
	check(not pw.flag_wall_open(0), "sem insígnia: parede da saída leste fechada")
	p.global_position = Vector3(44.5, 0.3, -430.0)
	await _walk("move_right", 120)
	await until(_free, 20.0)
	check(
		w.zone_at(p.global_position) == "pewter_city",
		"sem insígnia não passa para a Rota 3 (x %.1f)" % p.global_position.x
	)
	game.flags["badge_boulder"] = true
	game.flags["boulder_badge"] = true
	await frames(20)
	check(pw.flag_wall_open(0), "com insígnia a parede abre")
	p.global_position = Vector3(45.0, 0.3, -430.0)
	await _walk("move_right", 150)
	check(
		await until(func(): return w.location_id == "route_3", 10.0),
		"com insígnia chega à Rota 3 (%s, x %.1f)" % [w.location_id, p.global_position.x]
	)
	check(not story.is_running(), "aviso do garoto não dispara com a insígnia")


func _mouth() -> void:
	await w.go_to_zone("route_3", "r4_west_mouth")
	await frames(10)
	var b = w.builders.route_3
	var door: Node = b.get_node_or_null("Door_mtmoon_west")
	check(door != null and door.leads_inside(), "boca do Monte da Lua na Rota 3")
	check(b.arrivals.has("r4_west_mouth"), "chegada r4_west_mouth")
	var center: Node = null
	for c in b.get_children():
		if c.has_method("leads_inside") and c.target_spawn == "mm_center_in":
			center = c
	check(center != null and center.leads_inside(), "porta do Centro Pokémon do Monte da Lua")
	if door:
		await door.interact(p)
	await frames(5)
	check(w.location_id == "mt_moon_1f", "porta leva ao Monte da Lua 1F (%s)" % w.location_id)


func _floors() -> void:
	var space := w.get_world_3d().direct_space_state
	for fl in ["1f", "b1f", "b2f"]:
		var r = w.interior("mt_moon_" + fl)
		check(r != null and r.has_meta("cave_built"), "%s: caverna montada" % fl)
		if r == null:
			continue
		var rocks: Node = r.get_node_or_null("CaveRocks")
		check(
			rocks != null and rocks.get_child_count() > 20,
			"%s: paredes de rocha (%d)" % [fl, rocks.get_child_count() if rocks else 0]
		)
		check(
			r.has_spawn("door") and r.triggers.size() > 0,
			"%s: spawn door + gatilhos (%d)" % [fl, r.triggers.size()]
		)
		var warps: Array = Cave.events(fl).get("warps", [])
		for i in warps.size():
			var at: Vector3 = r.spawn_point("warp_%d" % i)
			var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN, 1)
			)
			check(
				not hit.is_empty() and absf(hit.position.y - at.y) < 0.05,
				"%s/warp_%d: chegada no chão livre" % [fl, i]
			)
		check(
			r.find_children("CaveSpawn*", "", false, false).size() > 0, "%s: zonas de encontro" % fl
		)
		check(
			not r.get_tree().get_nodes_in_group(Cave.LIGHT_GROUP).is_empty(),
			"%s: luzes da caverna" % fl
		)
	for t in ["mt_moon_1f", "mt_moon_b1f", "mt_moon_b2f"]:
		check(not load("res://core/dex.gd").encounter_table(t).is_empty(), "tabela %s" % t)
	var items: Array = w.interior("mt_moon_1f").find_children("Item_*", "", false, false)
	check(items.size() >= 5, "itens no 1F (%d)" % items.size())


## Toda escada leva a uma escada que volta para ela; e de verdade: pisar na escada troca de andar e volta.
func _ladders() -> void:
	var pairs := 0
	var ok := true
	for fl in ["1f", "b1f", "b2f"]:
		var warps: Array = Cave.events(fl).get("warps", [])
		for i in warps.size():
			var t: Dictionary = Cave.warp_target(fl, i)
			if not t.has("interior"):
				continue
			var dest := String(t.interior).trim_prefix("mt_moon_")
			var j := int(String(t.spawn).trim_prefix("warp_"))
			var back: Dictionary = Cave.warp_target(dest, j)
			if (
				back.get("interior", "") != "mt_moon_" + fl
				or back.get("spawn", "") != "warp_%d" % i
			):
				ok = false
				print("  escada sem volta: %s/%d -> %s/%d" % [fl, i, dest, j])
			pairs += 1
	check(ok and pairs >= 12, "escadas de ida e volta nos dados (%d)" % pairs)
	await w.go_to_interior("mt_moon_1f", "warp_0")
	await frames(45)
	var r1 = w.interior("mt_moon_1f")
	var ladder: Node3D = r1.get_node("Ladder0")
	p.global_position = ladder.global_position + Vector3(0, -0.3, 0)
	check(
		await until(func(): return w.location_id == "mt_moon_b1f", 5.0),
		"escada 1F -> B1F (%s)" % w.location_id
	)
	await frames(45)
	var rb = w.interior("mt_moon_b1f")
	check(
		p.global_position.distance_to(rb.spawn_point("warp_0")) < 0.8,
		"chega ao lado da escada certa no B1F"
	)
	p.global_position = rb.get_node("Ladder0").global_position + Vector3(0, -0.3, 0)
	check(
		await until(func(): return w.location_id == "mt_moon_1f", 5.0),
		"escada B1F -> 1F (%s)" % w.location_id
	)
	check(
		p.global_position.distance_to(r1.spawn_point("warp_0")) < 0.8,
		"volta ao lado da escada de partida"
	)


func _rockets() -> void:
	await w.go_to_interior("mt_moon_b2f", "warp_0")
	await frames(10)
	var r = w.interior("mt_moon_b2f")
	for i in range(1, 5):
		var id := "rocket_%d" % i
		var tr: Node = r.npcs.get(id)
		check(tr != null and tr.trainer_id == id, "%s no B2F" % id)
		if tr == null:
			continue
		check(
			String(tr.npc_name) == "Recruta da Equipe Rocket",
			"%s: nome em português (%s)" % [id, tr.npc_name]
		)
		game.heal_party()
		if not game.flags.get("trainer_" + id, false):
			await until(_free, 30.0)
			await tr.interact(p)
		check(
			await until(func(): return game.flags.get("trainer_" + id, false), 240.0),
			"vence o %s (autoplay)" % id
		)
		await until(_free, 30.0)


func _fossils() -> void:
	game.heal_party()
	var r = w.interior("mt_moon_b2f")
	check(
		r.npcs.has("miguel") and r.npcs.has("dome_fossil") and r.npcs.has("helix_fossil"),
		"Miguel e os dois fósseis no B2F"
	)
	var trig: Node3D = r.get_node_or_null("FossilTrigger")
	check(trig != null, "gatilho da cena dos fósseis")
	var seen: Array = []
	story.cutscene_started.connect(func(id): seen.append(id))
	await until(_free, 30.0)
	p.global_position = trig.global_position + Vector3(0, 0.3, 0)
	check(
		await until(func(): return seen.has("mt_moon_fossils"), 5.0),
		"chegar perto do Miguel começa a cena"
	)
	check(
		await until(func(): return game.flags.get("FLAG_GOT_FOSSIL_FROM_MT_MOON", false), 300.0),
		"cena termina com um fóssil"
	)
	await until(_free, 30.0)
	check(game.flags.get("trainer_super_nerd_miguel", false), "venceu o Miguel")
	check(
		(
			game.flags.get("FLAG_GOT_DOME_FOSSIL", false)
			and game.flags.get("mt_moon_fossil", "") == "dome"
		),
		"escolheu o Fóssil Domo (auto_answer sim)"
	)
	check(not game.flags.get("FLAG_GOT_HELIX_FOSSIL", false), "não levou os dois")
	check(
		int(game.bag.get("dome_fossil", 0)) == 1 and int(game.bag.get("helix_fossil", 0)) == 0,
		"Fóssil Domo na bolsa"
	)
	await frames(2)
	check(
		(
			not is_instance_valid(r.npcs.get("dome_fossil"))
			and not is_instance_valid(r.npcs.get("helix_fossil"))
		),
		"fósseis somem do chão"
	)
	var n := seen.size()
	p.global_position = trig.global_position + Vector3(3, 0.3, 0)
	await frames(10)
	p.global_position = trig.global_position + Vector3(0, 0.3, 0)
	await frames(30)
	check(seen.count("mt_moon_fossils") == 1 and seen.size() == n, "a cena não repete")


func _exit() -> void:
	await w.go_to_interior("mt_moon_b1f", "warp_7")
	await frames(45)
	var r = w.interior("mt_moon_b1f")
	var trig: Node3D = r.get_node_or_null("ExitRoute4East")
	check(
		trig != null and r.get_node_or_null("Route4Sign") != null,
		"saída para a Rota 4 com placa 'Continua...'"
	)
	if trig:
		p.global_position = trig.global_position + Vector3(0, 0.3, 0)
	check(
		await until(func(): return game.flags.get("mt_moon_cleared", false), 10.0),
		"sair pelo B1F marca mt_moon_cleared"
	)
	var fin := await until(_free, 20.0)
	if not fin:
		print(
			(
				"  dbg: story=%s busy=%s locked=%s ui=%s"
				% [story.current(), game.is_busy(), p.locked, p.ui_blocking()]
			)
		)
	check(fin, "cena do fim termina")
	check(w.location_id == "mt_moon_b1f", "continua dentro da caverna")
	# 1F -> Rota 3 pela boca oeste.
	await w.go_to_interior("mt_moon_1f", "west_in")
	await frames(45)
	var ex: Node3D = w.interior("mt_moon_1f").get_node_or_null("ExitRoute4West")
	if ex:
		p.global_position = ex.global_position + Vector3(0, -0.3, 0)
	check(
		await until(func(): return w.location_id == "route_3", 5.0),
		"1F -> Rota 3 pela boca do monte (%s)" % w.location_id
	)


func _center() -> void:
	await w.go_to_interior("pokemon_center_mt_moon", "door")
	await frames(10)
	var r = w.interior("pokemon_center_mt_moon")
	var sales: Node = r.npcs.get("salesman")
	check(sales != null, "vendedor de Magikarp no Centro")
	var money0: int = game.money
	var n0: int = game.party.size() + game.pc.size()
	if sales:
		await sales.interact(p)
	await until(_free, 10.0)
	check(
		game.flags.get("bought_magikarp", false) and game.money == money0 - 500,
		"comprou o Magikarp por P500"
	)
	check(game.party.size() + game.pc.size() == n0 + 1, "Magikarp entrou no time")
	if sales:
		await sales.interact(p)
	await until(_free, 10.0)
	check(game.money == money0 - 500, "não vende outro")


func _statics() -> void:
	game.heal_party()
	await w.go_to_zone("route_2", "r2_south")
	await frames(20)
	var s: Node = w.builders.route_2.get_node_or_null("Static_r2_pidgeotto")
	check(s != null and s.visible, "Pidgeotto estático na Rota 2")
	if s:
		var r: Dictionary = await s.fight()
		check(
			["win", "caught"].has(String(r.get("outcome", ""))),
			"luta com o Pidgeotto (%s)" % r.get("outcome", "?")
		)
	await frames(2)
	check(game.flags.get("static_r2_pidgeotto", false), "flag static_r2_pidgeotto")
	check(not is_instance_valid(s), "Pidgeotto some depois da luta")
	check(load("res://story/static_mon.gd").done("r2_pidgeotto"), "não luta de novo")
	# Escondido: o Raticate da Rota 1 pula quando o jogador passa.
	game.heal_party()
	await w.go_to_zone("route_1", "r1_south")
	await frames(20)
	var rat: Node3D = w.builders.route_1.get_node_or_null("Static_r1_raticate")
	check(rat != null and not rat.visible, "Raticate escondido na Rota 1")
	if rat:
		await until(_free, 10.0)
		p.global_position = rat.global_position + Vector3(0, 0.3, 0)
		check(await until(func(): return game.is_busy(), 10.0), "Raticate pula e a batalha começa")
		check(
			await until(func(): return game.flags.get("static_r1_raticate", false), 240.0),
			"flag static_r1_raticate"
		)
	await until(_free, 30.0)
