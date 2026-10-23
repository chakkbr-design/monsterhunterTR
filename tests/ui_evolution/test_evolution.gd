extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_evolution/test_evolution.gd
## Testa a tela de evolução com Game injetado: aceitar, cancelar, fila de dois e a LearnMove esperando.
## A tela entra como /root/Evolution (nome), então a LearnMove a enxerga como o autoload de verdade.
## O Game não entra na árvore: a fila pending_evolutions é preenchida à mão e o sinal emitido.

const Kit := preload("res://ui/ui_kit.gd")

var fails := 0
var evo: Node
var game: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FALHOU: ", what)


func send(k: int) -> void:
	root.push_input(Kit.key(k))


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


## Fila e abre a tela para os Pokémon dados.
func request(mons: Array) -> void:
	game.pending_evolutions = mons.duplicate()
	game.evolution_requested.emit()


## Da animação até a mensagem final, sem esperar o tempo real.
func finish_anim() -> void:
	evo.advance(evo.DURATION + 0.1)
	evo.advance(evo.MSG_MIN + 0.05)


func _run() -> void:
	game = load("res://core/game.gd").new()
	game.save_path = "user://test_save_evo.json"
	# O autoload Evolution usa o Game de verdade; o teste troca por uma instância com Game injetado.
	var auto := root.get_node_or_null("Evolution")
	if auto:
		root.remove_child(auto)
		auto.free()
	evo = load("res://ui/evolution/evolution_ui.gd").new()
	evo.game = game
	evo.name = "Evolution"
	root.add_child(evo)
	var learn = load("res://ui/learn_move_ui.gd").new()
	learn.game = game
	root.add_child(learn)
	evo.learn = learn

	# 1. Aceitar: intro → animação → Parabéns → fecha.
	var b := Mon.create("Bulbasaur", 16)
	game.party = [b]
	check(b.evolution_target() == "Ivysaur", "Bulbasaur 16 pode evoluir")
	request([b])
	check(evo.is_open() and evo.state == "intro", "abriu na intro")
	check(evo.message == "O quê? Bulbasaur está evoluindo!", "texto da intro: " + evo.message)
	evo.advance(evo.INTRO + 0.05)
	check(evo.state == "anim", "intro passa sozinha para a animação")
	evo.advance(2.0)
	check(evo.state == "anim" and b.species == "Bulbasaur", "ainda não evoluiu no meio da animação")
	finish_anim()
	check(evo.state == "done" and b.species == "Ivysaur", "evoluiu ao fim da animação")
	check(evo.message == "Parabéns! Bulbasaur evoluiu para Ivysaur!", "texto final: " + evo.message)
	check(game.pending_evolutions.is_empty(), "fila vazia depois de aceitar")
	check(bool(game.caught.get("Ivysaur", false)), "Ivysaur marcado como capturado")
	send(KEY_E)
	check(evo.state == "" and evo.is_open(), "fechou e segura o frame do fechamento")
	await frames(2)
	check(not evo.is_open(), "is_open falso depois do frame")

	# 2. Cancelar com Esc no meio da animação.
	var c := Mon.create("Charmander", 16)
	game.party = [c]
	request([c])
	send(KEY_ENTER)  # pula a intro
	check(evo.state == "anim", "Enter pula a intro")
	evo.advance(2.5)
	send(KEY_ESCAPE)
	check(evo.state == "cancelled" and c.species == "Charmander", "Esc cancelou")
	check(evo.message == "Charmander parou de evoluir.", "texto do cancelamento: " + evo.message)
	check(
		c.evolution_target() == "" and game.pending_evolutions.is_empty(),
		"cancelado até o próximo nível"
	)
	send(KEY_E)
	check(evo.state == "cancelled", "mensagem segura a tecla por um instante")
	evo.advance(evo.MSG_MIN + 0.05)
	send(KEY_E)
	check(evo.state == "", "fechou depois de cancelar")
	await frames(2)

	# 3. Fila de dois: aceita o primeiro, Q cancela o segundo já na intro.
	var s := Mon.create("Squirtle", 16)
	var b2 := Mon.create("Bulbasaur", 16)
	game.party = [s, b2]
	request([s, b2])
	check(evo.mon == s, "primeiro da fila é o Squirtle")
	evo.press("ok")
	finish_anim()
	check(s.species == "Wartortle", "Squirtle evoluiu")
	evo.press("ok")
	check(evo.state == "intro" and evo.mon == b2, "segundo da fila sem fechar a tela")
	check(evo.message == "O quê? Bulbasaur está evoluindo!", "intro do segundo")
	send(KEY_Q)
	check(evo.state == "cancelled" and b2.species == "Bulbasaur", "Q cancela na intro")
	evo.advance(1.0)
	evo.press("back")
	check(evo.state == "" and game.pending_evolutions.is_empty(), "fila de dois resolvida")
	await frames(2)

	# 4. A LearnMove espera a evolução terminar.
	var m := Mon.create("Bulbasaur", 16)
	game.party = [m]
	var wanted := ""
	for id in Dex.all_moves():
		if not m.moves.has(id):
			wanted = id
			break
	while m.moves.size() < Mon.MAX_MOVES:  # garante a tela de esquecer
		for id in Dex.all_moves():
			if not m.moves.has(id) and id != wanted:
				m.moves.append(id)
				break
	game.pending_evolutions = [m]
	game.queue_learn(m, wanted)
	check(game.pending_learns.size() == 1, "golpe na fila")
	game.learn_requested.emit()  # o Game emite os dois depois da batalha, nessa ordem não importa
	check(learn.state == "", "LearnMove não abre com evolução pendente")
	game.evolution_requested.emit()
	check(evo.state == "intro", "Evolution abriu")
	await frames(3)
	check(learn.state == "" and evo.is_open(), "LearnMove segue esperando com a Evolution aberta")
	evo.press("ok")
	finish_anim()
	check(m.species == "Ivysaur", "evoluiu antes de aprender")
	check(learn.state == "", "LearnMove espera a mensagem final")
	evo.press("ok")
	learn._process(0.0)
	check(learn.state == "", "LearnMove não abre no frame em que a Evolution fecha")
	await frames(3)
	check(learn.state == "pick" and learn._current().mon == m, "LearnMove abriu depois da evolução")
	learn.press("back")
	learn.press("left")
	learn.press("ok")
	learn.press("ok")
	check(learn.state == "" and game.pending_learns.is_empty(), "LearnMove resolvida")

	# 5. Evolution espera a LearnMove aberta e não abre durante batalha.
	var q := Mon.create("Charmander", 16)
	game.party = [q]
	game.queue_learn(m, wanted)
	learn._try_open()
	check(learn.state == "pick", "LearnMove aberta (sem evolução pendente)")
	request([q])
	check(evo.state == "", "Evolution espera a LearnMove")
	learn.press("back")
	learn.press("left")
	learn.press("ok")
	learn.press("ok")
	await frames(2)
	check(evo.state == "intro" and evo.mon == q, "Evolution abriu depois da LearnMove")
	evo.press("back")
	evo.advance(1.0)
	evo.press("ok")

	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_evo.json"))
	print("ui_evolution: %d falhas" % fails)
	quit(1 if fails else 0)
