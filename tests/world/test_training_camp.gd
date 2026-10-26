extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_training_camp.gd
## Acampamentos de treino de Viridian e Pewter (world/training_attendant.gd + Battle.start_training_battle
## do original): o Coordenador pergunta o boneco, esconde a placa, luta de treino contra o boneco parado e
## imortal no nível do seu Pokémon, EV a cada KO, bola não pega, termina com FUGIR. Nunca grava save.json.

var _fails := 0
var game: Node
var w: Node
var p
var TA: GDScript  # carregado depois dos autoloads (o script usa Game)


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
		if game.is_busy():
			return
		if hud and hud.is_dialog_open():
			hud.advanced.emit()
		await process_frame


func _wait_built(zone: String) -> void:
	for i in 1200:
		if w.builders.has(zone) and w.builders[zone].is_built:
			break
		await physics_frame
	await frames(20)


func _coordinator() -> Node:
	for n in get_nodes_in_group("ow_interact"):
		if n.name == "NPC_CampCoordinator" and n.is_inside_tree():
			return n
	return null


func _run() -> void:
	game = root.get_node("/root/Game")
	TA = load("res://world/training_attendant.gd")
	game.save_path = OS.get_user_data_dir().path_join("test_training_camp_save.json")
	game.save_enabled = false
	game.last_save = {}
	game.party.clear()
	game.add_mon(Mon.create("Bulbasaur", 7))
	game.spawn_request = {"zone": "viridian_city", "spawn": "vc_camp"}
	_units()
	w = load("res://world/route_world.tscn").instantiate()
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	await _wait_built("viridian_city")
	await _camp("Viridian", 0, "Rattata", "prop_dummy_rattata", "spe")
	await w.go_to_zone("pewter_city", "pw_camp")
	await _wait_built("pewter_city")
	# Bulbasaur só de Investida demora demais no Geodude (e pode cair por Desespero): Squirtle com Water Gun
	game.party.clear()
	game.add_mon(Mon.create("Squirtle", 15))
	await _camp("Pewter", 0, "Geodude", "prop_dummy_geodude", "def")
	TA.auto_pick = -1
	await _cancel()
	print("[training camp] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _units() -> void:
	var o: Dictionary = TA.parse_option("Nidoran M|5|prop_dummy_nidoran_m")
	check(
		o == {"species": "Nidoran M", "level": 5, "card": "prop_dummy_nidoran_m"},
		"parse_option lê espécie|nível|placa"
	)
	check(TA.parse_option("|5|x").is_empty(), "parse_option recusa espécie vazia")
	check(
		TA.ev_label({"spe": 1}) == "%s +1" % load("res://ui/ui_kit.gd").STATS["spe"],
		"EV label uses the stat name"
	)


func _camp(where: String, pick: int, species: String, card: String, stat: String) -> void:
	var c := _coordinator()
	check(c != null and c.get_script() == TA, "%s: Coordenador é TrainingAttendant" % where)
	if not (c != null and c.get_script() == TA):
		return
	check(c.train_options.size() == 3, "%s: 3 bonecos" % where)
	check(c.arena_size == Vector2(10, 6), "%s: quadra 10 x 6 do campo attendant" % where)
	var board: Node3D = c._nearest_board(card)
	check(board != null and board.visible, "%s: placa %s no mapa" % [where, card])
	var mon: Mon = game.party[0]
	var ev_before := int(mon.evs.get(stat, 0))
	# jogador ao lado do Coordenador
	p.global_position = c.global_position + Vector3(0, 0.1, 1.2)
	await frames(5)
	TA.auto_pick = pick
	c.interact(p)
	await _close_dialog()
	for i in 120:
		if game.is_busy():
			break
		await physics_frame
	check(game.is_busy(), "%s: escolha abre a luta de treino" % where)
	var arena = game._arena
	if arena == null:
		return
	check(arena.training, "%s: arena em modo de treino" % where)
	check(board != null and not board.visible, "%s: a placa escolhida some na luta" % where)
	for i in 600:
		if arena.state == "fight":
			break
		await physics_frame
	var foe = arena.enemy
	check(foe.mon.species == species, "%s: boneco é %s" % [where, species])
	check(foe.controller == "dummy" and foe.immortal, "%s: boneco parado e imortal" % where)
	check(foe.mon.level == mon.level, "%s: boneco no nível do seu Pokémon" % where)
	check(
		foe.look.spec().get("texture") == load(WorldFx.ART + "sprites/%s.png" % card),
		"%s: boneco com a cara da placa" % where
	)
	var c_center: Vector3 = c.get_parent().to_global(c.arena_center)
	check(
		(
			Vector2(arena.global_position.x, arena.global_position.z).distance_to(
				Vector2(c_center.x, c_center.z)
			)
			< 0.01
		),
		"%s: quadra no centro do campo attendant" % where
	)
	var balls := int(game.bag.get("poke_ball", 0))
	game.add_item("poke_ball", 1)
	check(not arena.throw_ball(), "%s: bola não pega boneco" % where)
	check(int(game.bag.get("poke_ball", 0)) == balls + 1, "%s: bola não é gasta" % where)
	# a IA bate no boneco até ganhar o EV
	arena.player.controller = "ai"
	var foe_pos: Vector3 = foe.position
	for i in 60 * 90:
		if int(mon.evs.get(stat, 0)) > ev_before:
			break
		await physics_frame
	check(int(mon.evs.get(stat, 0)) > ev_before, "%s: KO no boneco dá EV de %s" % [where, stat])
	check(foe.alive() and foe.on_field, "%s: boneco não desmaia" % where)
	check(foe.position.distance_to(foe_pos) < 3.0, "%s: boneco não sai do lugar (só recuo)" % where)
	check(arena.state == "fight", "%s: luta segue depois do KO" % where)
	if arena.state != "fight":
		print("  estado=%s result=%s hp=%d/%d" % [arena.state, arena.result, mon.hp, mon.max_hp])
		print("  log: ", arena.log_lines.slice(-12))
	var ev_now := int(mon.evs.get(stat, 0))
	check(arena.run_away(), "%s: FUGIR encerra o treino" % where)
	for i in 300:
		if not game.is_busy():
			break
		await physics_frame
	await frames(10)
	check(not game.is_busy(), "%s: volta ao mundo" % where)
	check(int(game.party[0].evs.get(stat, 0)) == ev_now, "%s: EVs ficam no Pokémon" % where)
	check(game.party[0].level == mon.level, "%s: sem EXP (nível igual)" % where)
	check(is_instance_valid(board) and board.visible, "%s: a placa volta" % where)


func _cancel() -> void:
	var c := _coordinator()
	if c == null:
		return
	c.interact(p)
	await _close_dialog()
	await frames(30)
	check(not game.is_busy(), "Cancelar a escolha não começa luta")
	check(not c.talking, "Coordenador libera o jogador depois de cancelar")
