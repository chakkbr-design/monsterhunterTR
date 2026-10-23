extends SceneTree
## Integração: abertura inteira na RouteWorld real (precisa da API dos Interiores).
## godot --headless --path . --script res://tests/story/test_story_opening.gd
## quarto -> sai de casa -> Oak barra no norte de Pallet -> laboratório -> Charmander ->
## rival com Squirtle -> batalha (autoplay) -> Mamãe -> loja de Viridian (encomenda) -> lab -> Pokédex.

const MAX_WAIT_S := 240.0

var _fails := 0
var game: Node
var story: Node
var world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## Espera até cond() ser verdadeiro (ou o tempo acabar). Devolve cond().
func until(cond: Callable, secs := 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0:
			return false
		await process_frame
	return true


func _run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_story_save.json"
	game.new_game("ASH", "GARY")
	game.spawn_request = {"interior": "player_room", "spawn": "bed"}
	story = load("res://story/story.gd").new()
	story.name = "Story"
	root.add_child(story)
	story.auto_advance = true
	story.auto_answer = true
	story.auto_battle = true
	story.battle_extra = {"seed": 7, "speed": 3.0}

	var scene: PackedScene = load("res://world/route_world.tscn")
	world = scene.instantiate()
	world.set("fade_time", 0.0)
	root.add_child(world)
	await frames(10)
	var p: CharacterBody3D = world.get_tree().get_first_node_in_group("ow_player")
	check(world.has_method("go_to_interior") and world.has_signal("location_changed"), "API dos Interiores presente")
	check(story.world == world, "Story ligado à RouteWorld")
	check(world.location_id == "player_room" and story.location_id == "player_room", "começa no quarto (%s)" % world.location_id)
	check(game.party.is_empty(), "jogo novo sem Pokémon (%d)" % game.party.size())
	check(story.triggers().size() >= 1, "gatilho oak_stop criado a partir do pallet_town.json")

	# Desce a escada e sai de casa.
	await world.go_to_interior("player_house", "stairs")
	await frames(5)
	check(story.location_id == "player_house" and not story.is_running(), "casa sem cena antes do inicial")
	await world.go_to_zone("pallet_town", "player_house_door")
	await frames(10)
	check(world.location_kind == "zone" and world.location_id == "pallet_town", "em Pallet")

	# Anda para o norte até o mato alto.
	var cutscenes: Array = []
	story.cutscene_started.connect(func(id): cutscenes.append(id))
	p.global_position = Vector3(0, p.global_position.y + 0.3, -12.0)
	var locked_seen := [false]
	Input.action_press("move_forward")
	var ok := await until(func():
		if story.is_running() and p.locked:
			locked_seen[0] = true
		return cutscenes.has("oak_stop"), 6.0)
	Input.action_release("move_forward")
	print("     oak_stop por caminhada: ", ok)
	if not ok:
		# Sem câmera alinhada ao norte: empurra o jogador para dentro do gatilho.
		p.global_position = Vector3(0, p.global_position.y, -16.5)
		ok = await until(func(): return cutscenes.has("oak_stop"), 3.0)
	check(ok, "Oak barra no norte de Pallet")
	await until(func():
		if story.is_running() and p.locked:
			locked_seen[0] = true
		return not story.is_running(), 30.0)
	check(locked_seen[0], "jogador travado durante a cena")
	check(not p.locked, "jogador solto depois")
	check(world.location_id == "oak_lab", "levado ao laboratório (%s)" % world.location_id)
	check(game.flags.get("oak_stopped", false), "flag oak_stopped")
	check(story.actor("oak") != null and story.actor("rival") != null, "Oak e rival no lab")
	var b: Node3D = story.ball("Charmander")
	check(b != null and story.ball("Bulbasaur") != null and story.ball("Squirtle") != null, "três Poké Balls na mesa")
	if b:
		var m: Node3D = world.marker("oak_lab", "ball_2")
		check(m != null and b.global_position.distance_to(m.global_position) < 0.01, "Charmander no ball_2")

	# Escolhe Charmander (como o E do jogador faria) -> rival pega Squirtle -> batalha.
	var battles: Array = []
	game.battle_finished.connect(func(r): battles.append(r))
	if b:
		p.global_position = b.global_position + Vector3(0, -0.8, 1.2)
		p.locked = true
		story.pick_starter(b)
	ok = await until(func(): return not story.is_running() and game.flags.get("rival_battle_done", false), MAX_WAIT_S)
	p.locked = false
	check(ok, "inicial + batalha do rival terminaram")
	check(game.party.size() == 1 and game.party[0].species == "Charmander", "Charmander na equipe")
	check(game.flags.get("rival_starter") == "Squirtle", "rival ficou com Squirtle")
	check(story.ball("Squirtle") == null and story.ball("Charmander") == null and story.ball("Bulbasaur") != null, "só Bulbasaur na mesa")
	check(battles.size() == 1, "uma batalha (%d)" % battles.size())
	var outcome := String(story.last_battle.get("outcome", "?"))
	print("     batalha: ", outcome)
	check(outcome == "win" or outcome == "lose", "batalha resolvida (%s)" % outcome)
	check(not game.flags.has("trainer_rival_blue_route22"), "rival da Rota 22 não marcado como vencido")
	check(world.location_id == "oak_lab" and world.interior("oak_lab").contains(p.global_position), "continua no lab (sem white-out)")
	check(story.actor("rival") == null, "rival saiu")

	# Mamãe cura.
	game.party[0].hp = 1
	await world.go_to_interior("player_house", "door")
	await frames(3)
	await until(func(): return not story.is_running() and game.flags.get("mom_healed", false), 20.0)
	check(game.flags.get("mom_healed", false) and game.party[0].hp == game.party[0].max_hp, "Mamãe curou")

	# Loja de Viridian -> encomenda.
	await world.go_to_interior("mart_viridian", "door")
	await frames(3)
	await until(func(): return not story.is_running() and game.flags.get("has_parcel", false), 20.0)
	check(int(game.bag.get("oaks_parcel", 0)) == 1, "recebeu oaks_parcel")

	# De volta ao laboratório -> Pokédex.
	var balls := int(game.bag.get("poke_ball", 0))
	await world.go_to_interior("oak_lab", "door")
	await frames(3)
	await until(func(): return not story.is_running() and game.flags.get("has_pokedex", false), 30.0)
	check(game.flags.get("has_pokedex", false), "flags.has_pokedex")
	check(int(game.bag.get("oaks_parcel", 0)) == 0 and int(game.bag.get("pokedex", 0)) == 1, "encomenda trocada pela Pokédex")
	check(int(game.bag.get("poke_ball", 0)) == balls + 5, "5 Poké Balls")
	check(not story.is_running() and not p.locked, "nada travado no fim")

	# Sair do lab e passar pelo norte de Pallet não chama mais o Oak.
	cutscenes.clear()
	await world.go_to_zone("pallet_town", "lab_door")
	await frames(5)
	p.global_position = Vector3(0, p.global_position.y, -16.5)
	await frames(20)
	check(not cutscenes.has("oak_stop"), "com inicial o Oak não barra")

	print("%s (%d falhas)" % ["PASSOU" if _fails == 0 else "FALHOU", _fails])
	quit(1 if _fails else 0)
