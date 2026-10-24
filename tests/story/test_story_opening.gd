extends SceneTree
## Integração: abertura inteira na RouteWorld real (precisa da API dos Interiores).
## godot --headless --path . --script res://tests/story/test_story_opening.gd
## quarto -> sai de casa -> Oak barra no norte de Pallet -> laboratório -> Charmander ->
## rival com Squirtle -> batalha (autoplay) -> cura no lab -> loja de Viridian (encomenda) -> lab -> Pokédex.
## Também: autosave (porta e fim de cena), prêmio do rival 35 x 5, Pokédex vista ao abrir o cartão.

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
	story = root.get_node_or_null("Story")
	if story == null:
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
	check(
		world.has_method("go_to_interior") and world.has_signal("location_changed"),
		"API dos Interiores presente"
	)
	check(story.world == world, "Story ligado à RouteWorld")
	check(
		world.location_id == "player_room" and story.location_id == "player_room",
		"começa no quarto (%s)" % world.location_id
	)
	check(game.party.is_empty(), "jogo novo sem Pokémon (%d)" % game.party.size())
	if FileAccess.file_exists(game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	var saves := [0]
	game.saved.connect(func(): saves[0] += 1)
	check(story.triggers().size() >= 1, "gatilho oak_stop criado a partir do pallet_town.json")

	# Desce a escada e sai de casa.
	await world.go_to_interior("player_house", "stairs")
	await frames(5)
	check(
		story.location_id == "player_house" and not story.is_running(),
		"casa sem cena antes do inicial"
	)
	await world.go_to_zone("pallet_town", "player_house_door")
	await frames(10)
	check(world.location_kind == "zone" and world.location_id == "pallet_town", "em Pallet")

	# Anda para o norte até o mato alto.
	var cutscenes: Array = []
	story.cutscene_started.connect(func(id): cutscenes.append(id))
	p.global_position = Vector3(0, p.global_position.y + 0.3, -12.0)
	var locked_seen := [false]
	Input.action_press("move_forward")
	var ok := await until(
		func():
			if story.is_running() and p.locked:
				locked_seen[0] = true
			return cutscenes.has("oak_stop"),
		6.0
	)
	Input.action_release("move_forward")
	print("     oak_stop por caminhada: ", ok)
	if not ok:
		# Sem câmera alinhada ao norte: empurra o jogador para dentro do gatilho.
		p.global_position = Vector3(0, p.global_position.y, -16.5)
		ok = await until(func(): return cutscenes.has("oak_stop"), 3.0)
	check(ok, "Oak barra no norte de Pallet")
	await until(
		func():
			if story.is_running() and p.locked:
				locked_seen[0] = true
			return not story.is_running(),
		30.0
	)
	check(locked_seen[0], "jogador travado durante a cena")
	check(not p.locked, "jogador solto depois")
	check(world.location_id == "oak_lab", "levado ao laboratório (%s)" % world.location_id)
	check(game.flags.get("oak_stopped", false), "flag oak_stopped")
	check(story.actor("oak") != null and story.actor("rival") != null, "Oak e rival no lab")
	var b: Node3D = story.ball("Charmander")
	check(
		b != null and story.ball("Bulbasaur") != null and story.ball("Squirtle") != null,
		"três Poké Balls na mesa"
	)
	check(saves[0] >= 1 and game.has_save(), "autosave depois da cena do Oak (%d)" % saves[0])
	var lab_room: Node = world.interior("oak_lab")
	check(lab_room.get_node_or_null("PokedexA") != null, "Pokédex na mesa do lab")
	if b:
		var m: Node3D = world.marker("oak_lab", "ball_2")
		check(
			m != null and b.global_position.distance_to(m.global_position) < 0.01,
			"Charmander no ball_2"
		)

	# Escolhe Charmander (como o E do jogador faria) -> rival pega Squirtle. A luta é na saída do lab.
	var battles: Array = []
	game.battle_finished.connect(func(r): battles.append(r))
	# Cartão aberto e NÃO: a espécie já fica vista (story.gd:374 do original).
	if story.ball("Bulbasaur"):
		story.auto_answer = false
		story.pick_starter(story.ball("Bulbasaur"))
		await until(func(): return not story.is_running(), 10.0)
		story.auto_answer = true
	check(game.seen.has("Bulbasaur") and game.party.is_empty(), "NÃO no cartão: Bulbasaur visto")
	var money0: int = game.money
	if b:
		p.global_position = b.global_position + Vector3(0, -0.8, 1.2)
		p.locked = true
		story.pick_starter(b)
	ok = await until(
		func(): return not story.is_running() and game.flags.get("got_starter", false), 30.0
	)
	p.locked = false
	check(ok, "inicial escolhido")
	check(
		battles.is_empty() and not game.flags.get("rival_battle_done", false),
		"escolher não começa a luta (ela é na saída do lab, como no original)"
	)
	await _lab_exit_battle(p)
	ok = await until(
		func(): return not story.is_running() and game.flags.get("rival_battle_done", false),
		MAX_WAIT_S
	)
	check(ok, "batalha do rival terminou")
	check(game.party.size() == 1 and game.party[0].species == "Charmander", "Charmander na equipe")
	check(game.flags.get("rival_starter") == "Squirtle", "rival ficou com Squirtle")
	check(
		(
			story.ball("Squirtle") == null
			and story.ball("Charmander") == null
			and story.ball("Bulbasaur") != null
		),
		"só Bulbasaur na mesa"
	)
	check(battles.size() == 1, "uma batalha (%d)" % battles.size())
	var outcome := String(story.last_battle.get("outcome", "?"))
	print("     batalha: ", outcome)
	check(outcome == "win" or outcome == "lose", "batalha resolvida (%s)" % outcome)
	check(
		not game.flags.has("trainer_rival_blue_route22"),
		"rival da Rota 22 não marcado como vencido"
	)
	check(
		world.location_id == "oak_lab" and world.interior("oak_lab").contains(p.global_position),
		"continua no lab (sem white-out)"
	)
	check(story.actor("rival") == null, "rival saiu")
	check(game.party[0].hp == game.party[0].max_hp, "time curado no lab depois da luta")
	if outcome == "win":
		check(game.money == money0 + 35 * 5, "prêmio 35 x 5 (%d -> %d)" % [money0, game.money])

	# Casa: sem cena automática da Mamãe.
	await world.go_to_interior("player_house", "door")
	await frames(3)
	check(not story.is_running(), "casa sem cena depois da luta")

	# Loja de Viridian -> encomenda.
	await world.go_to_interior("mart_viridian", "door")
	await frames(3)
	await until(func(): return not story.is_running() and game.flags.get("has_parcel", false), 20.0)
	check(int(game.bag.get("oaks_parcel", 0)) == 1, "recebeu oaks_parcel")

	# De volta ao laboratório -> Pokédex.
	var balls := int(game.bag.get("poke_ball", 0))
	await world.go_to_interior("oak_lab", "door")
	await frames(3)
	await until(
		func(): return not story.is_running() and game.flags.get("has_pokedex", false), 30.0
	)
	check(game.flags.get("has_pokedex", false), "flags.has_pokedex")
	check(
		int(game.bag.get("oaks_parcel", 0)) == 0 and int(game.bag.get("pokedex", 0)) == 1,
		"encomenda trocada pela Pokédex"
	)
	check(int(game.bag.get("poke_ball", 0)) == balls + 5, "5 Poké Balls")
	await frames(2)
	check(lab_room.get_node_or_null("PokedexA") == null, "Pokédex sumiram da mesa")
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


## Anda para a saída do lab: o rival desafia e a luta acontece na quadra do RivalBattleSpot
## (original: centro (0, 0.6), 10 x 6.4, jogador em x -5.3, rival em +5.3, mons em -3.8 e +2.12).
func _lab_exit_battle(p: CharacterBody3D) -> void:
	var lab: Node3D = world.interior("oak_lab")
	check(lab.get_node_or_null("LabExitTrigger") != null, "gatilho da saída do lab")
	p.global_position = lab.to_global(Vector3(-2.5, 0.05, 5.6))
	await frames(3)
	Input.action_press("move_back")
	var started := await until(func(): return game.is_busy(), 6.0)
	Input.action_release("move_back")
	if not started:
		# Câmera não alinhada ao sul: põe o jogador direto no gatilho.
		p.global_position = lab.to_global(Vector3(-2.5, 0.05, 6.8))
		started = await until(func(): return game.is_busy(), 6.0)
	check(started, "o rival desafia na saída do lab")
	if not started:
		return
	await frames(2)
	var arena: Node3D = game.get("_arena")
	var spot: Node3D = world.marker("oak_lab", "rival_battle")
	check(
		(
			arena != null
			and spot != null
			and arena.global_position.distance_to(spot.global_position) < 0.01
		),
		"quadra no centro do lab (marcador rival_battle)"
	)
	if arena == null:
		return
	check(arena.fixed and arena.rect.size.is_equal_approx(Vector2(10, 6.4)), "quadra 10 x 6,4")
	var lp: Vector3 = lab.to_local(p.global_position)
	check(
		Vector2(lp.x, lp.z).distance_to(Vector2(-5.3, 0.6)) < 0.05,
		"jogador na ponta oeste (%s)" % lp
	)
	var rv: Node3D = story.actor("rival")
	var lr: Vector3 = lab.to_local(rv.global_position) if rv else Vector3.INF
	check(
		Vector2(lr.x, lr.z).distance_to(Vector2(5.3, 0.6)) < 0.05, "rival na ponta leste (%s)" % lr
	)
	check(
		arena.player.position.distance_to(Vector3(-3.8, 0, 0)) < 0.05,
		"Charmander 1,5 m à frente do jogador (%s)" % arena.player.position
	)
	check(
		arena.enemy.position.distance_to(Vector3(2.12, 0, 0)) < 0.05,
		"Squirtle a 40%% do caminho até o rival (%s)" % arena.enemy.position
	)
	var free := true
	for x in range(-4, 5):
		for z in [-2.6, 0.0, 2.6]:  # local da arena
			if arena._solid_at(Vector3(x, 0, z)):
				free = false
	check(free, "nenhum móvel dentro da quadra")
