extends SceneTree
## Progressão de flags da história, sem cena de mundo.
## godot --headless --path . --script res://tests/story/test_story_flags.gd

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _run() -> void:
	_pure()
	_trigger_entry()  # scripts do mundo só com load(): os autoloads não existem na compilação do teste
	await _story_without_world()
	print("%s (%d falhas)" % ["PASSOU" if _fails == 0 else "FALHOU", _fails])
	quit(1 if _fails else 0)


func _pure() -> void:
	var f := {}
	var S := ["Bulbasaur", "Charmander", "Squirtle"]
	check(StoryFlags.step(f) == "leave_house", "jogo novo: sair de casa")
	check(StoryFlags.oak_should_stop(f), "sem inicial o Oak barra")
	check(not StoryFlags.can_pick(f), "não pega Poké Ball antes do Oak trazer")
	check(not StoryFlags.lab_has_oak(f) and StoryFlags.lab_has_rival(f), "lab antes: só o rival")
	check(StoryFlags.interior_event(f, "mart_viridian") == "", "loja sem inicial: nada")
	check(StoryFlags.balls_left(f, S) == S, "três bolas na mesa")
	check(StoryFlags.first_rival_party(f).is_empty(), "sem rival_starter, sem party")
	f.oak_stopped = true
	check(
		StoryFlags.step(f) == "pick_starter" and StoryFlags.can_pick(f), "Oak trouxe: pode escolher"
	)
	check(StoryFlags.oak_should_stop(f), "oak_stopped sem inicial ainda barra")
	f.got_starter = true
	f.starter = "Charmander"
	f.rival_starter = "Squirtle"
	check(not StoryFlags.oak_should_stop(f), "com inicial passa pelo mato")
	check(not StoryFlags.can_pick(f), "não pega segundo inicial")
	check(StoryFlags.balls_left(f, S) == ["Bulbasaur"], "sobra só Bulbasaur")
	check(StoryFlags.first_rival_party(f) == [["Squirtle", 5]], "rival: Squirtle Nv5")
	check(StoryFlags.step(f) == "rival_battle", "passo: luta com rival")
	check(
		StoryFlags.interior_event(f, "mart_viridian") == "mart_parcel",
		"loja com inicial: encomenda"
	)
	f.rival_battle_done = true
	check(not StoryFlags.lab_has_rival(f), "rival saiu do lab")
	check(
		StoryFlags.interior_event(f, "player_house") == "",
		"casa depois da luta: sem cena (Mamãe cura como NPC, como no original)"
	)
	check(
		"batalhou" in StoryFlags.daisy_lines(f)[0] and "Oi" in StoryFlags.daisy_lines({})[0],
		"Margarida muda a fala depois da luta"
	)
	check(
		(
			"confia" in StoryFlags.lab_npc_lines(f, "aide_1")[0]
			and "saiu" in StoryFlags.lab_npc_lines({}, "aide_1")[0]
		),
		"Pesquisador-chefe muda a fala depois do inicial"
	)
	check(StoryFlags.step(f) == "get_parcel", "passo: buscar encomenda")
	check(StoryFlags.interior_event(f, "oak_lab") == "", "lab sem encomenda: nada")
	f.has_parcel = true
	check(StoryFlags.interior_event(f, "mart_viridian") == "", "loja não dá outra encomenda")
	check(StoryFlags.interior_event(f, "oak_lab") == "parcel_deliver", "lab com encomenda: entrega")
	f.has_pokedex = true
	check(StoryFlags.step(f) == "done", "Pokédex: fim do roteiro")
	check(StoryFlags.interior_event(f, "oak_lab") == "", "lab depois da Pokédex: nada")
	check(StoryFlags.interior_event(f, "mart_viridian") == "", "loja depois da Pokédex: nada")
	check(
		(
			StoryFlags.can_fire({"a": true}, ["a"], ["b"])
			and not StoryFlags.can_fire({"a": true, "b": true}, ["a"], ["b"])
			and not StoryFlags.can_fire({}, ["a"], [])
		),
		"can_fire requires/blocks"
	)


func _trigger_entry() -> void:
	var trig: Array = (
		JSON
		. parse_string(FileAccess.get_file_as_string("res://data/maps/pallet_town.json"))
		. get("triggers", [])
	)
	var e: Dictionary = {}
	for t in trig:
		if t.get("event") == "oak_stop":
			e = t
	check(not e.is_empty(), "pallet_town.json tem gatilho oak_stop")
	var st: Node = load("res://story/story_trigger.gd").from_entry(e)
	check(
		st.event == "oak_stop" and st.size.x > 40.0 and st.position.z < -15.0,
		"gatilho no norte de Pallet (%s)" % st.position
	)
	st.free()


## Cenas sem mundo (sem HUD): diálogo pula, itens e flags acontecem.
func _story_without_world() -> void:
	var game: Node = root.get_node("Game")
	game.new_game("ASH", "GARY")
	var story: Node = load("res://story/story.gd").new()
	story.name = "Story"
	root.add_child(story)
	story.auto_answer = true
	check(not story.is_running(), "parado no início")
	check(game.fill_names("{PLAYER} x {RIVAL}") == "ASH x GARY", "fill_names")

	# Escolha do inicial sem mundo (bola solta).
	game.flags.oak_stopped = true
	var b: Node = load("res://story/starter_ball.gd").new()
	b.species = "Charmander"
	story.add_child(b)
	var running_seen := [false]
	story.cutscene_started.connect(func(_id): running_seen[0] = story.is_running())
	await story.pick_starter(b)
	check(running_seen[0], "is_running() verdadeiro durante a cena")
	check(not story.is_running(), "is_running() falso depois")
	check(
		game.party.size() == 1 and game.party[0].species == "Charmander",
		"inicial Charmander na equipe"
	)
	check(
		game.flags.get("got_starter") == true and game.flags.get("rival_starter") == "Squirtle",
		"flags got_starter / rival Squirtle"
	)
	check(
		not game.flags.has("rival_battle_done"),
		"escolher não começa a luta (ela é na saída do lab)"
	)
	await story.trigger("lab_exit")
	check(
		game.flags.get("rival_battle_done") == true,
		"saída do lab: luta resolvida sem mundo (vitória padrão)"
	)
	check(not story.is_running(), "saída do lab não deixa cena presa")
	check(not game.flags.has("trainer_rival_blue_route22"), "rival da Rota 22 continua não vencido")

	# Recusar no cartão não escolhe nada.
	game.flags.erase("got_starter")
	story.auto_answer = false
	var b2: Node = load("res://story/starter_ball.gd").new()
	b2.species = "Bulbasaur"
	story.add_child(b2)
	await story.pick_starter(b2)
	check(game.party.size() == 1 and not game.flags.has("got_starter"), "dizer Não não escolhe")
	game.flags.got_starter = true
	b2.free()

	await story.mart_parcel()
	check(
		game.flags.get("has_parcel") == true and int(game.bag.get("oaks_parcel", 0)) == 1,
		"loja entrega oaks_parcel"
	)
	var balls := int(game.bag.get("poke_ball", 0))
	await story.parcel_deliver()
	check(game.flags.get("has_pokedex") == true, "has_pokedex ligado")
	check(int(game.bag.get("oaks_parcel", 0)) == 0, "encomenda entregue")
	check(int(game.bag.get("pokedex", 0)) == 1, "Pokédex na bolsa")
	check(int(game.bag.get("poke_ball", 0)) == balls + 5, "5 Poké Balls")
	check(not story.is_running(), "nenhuma cena presa")
	story.queue_free()
