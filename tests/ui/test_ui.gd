extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui/test_ui.gd
## Testa LearnMove e PauseMenu com teclas simuladas (root.push_input), Game injetado.

const Kit := preload("res://ui/ui_kit.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FALHOU: ", what)


func send(k: int, times := 1) -> void:
	for i in times:
		root.push_input(Kit.key(k))


func unknown_moves(m: Mon, n: int) -> Array:
	var out: Array = []
	for id in Dex.all_moves():
		if not m.moves.has(id):
			out.append(id)
			if out.size() == n:
				break
	return out


var _done := false


## O root só entra na árvore depois do _initialize: o teste roda no primeiro frame.
func _process(_dt: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save.json"
	var learn = load("res://ui/learn_move_ui.gd").new()
	learn.game = game
	root.add_child(learn)
	var menu = load("res://ui/pause_menu.gd").new()
	menu.game = game
	menu.learn = learn
	root.add_child(menu)

	# 1. Fila com 2 golpes, resolvida pelo teclado.
	var m := Mon.create("bulbasaur", 20)
	var old: Array = m.moves.duplicate()
	var nw := unknown_moves(m, 3)
	game.queue_learn(m, nw[0])
	game.queue_learn(m, nw[1])
	check(game.pending_learns.size() == 2, "fila tem 2")
	game.learn_requested.emit()
	check(learn.is_open() and learn.state == "pick", "LearnMove abriu")
	send(KEY_S)                   # cursor 1
	send(KEY_E)                   # esquece o golpe 1
	check(m.moves[1] == nw[0] and learn.state == "msg", "trocou golpe 1 pelo primeiro")
	send(KEY_ENTER)               # próximo da fila
	check(learn.is_open() and learn.state == "pick" and learn.cursor == 0, "segundo da fila")
	send(KEY_DOWN, 2)
	send(KEY_UP)                  # cursor 1 de novo
	send(KEY_UP)                  # cursor 0
	send(KEY_ENTER)
	check(m.moves[0] == nw[1], "trocou golpe 0 pelo segundo")
	send(KEY_E)
	check(learn.state == "" and game.pending_learns.is_empty(), "fila vazia e tela fechada")
	check(m.moves[2] == old[2] and m.moves[3] == old[3], "outros golpes intactos")

	# 2. Desistir (com confirmação; "Não" é o padrão).
	var before: Array = m.moves.duplicate()
	game.queue_learn(m, nw[2])
	game.learn_requested.emit()
	send(KEY_ESCAPE)
	check(learn.state == "confirm", "Esc pede confirmação")
	send(KEY_E)
	check(learn.state == "pick" and game.pending_learns.size() == 1, "Não volta para a lista")
	send(KEY_S, 4)                # linha do golpe novo
	check(learn.cursor == 4, "cursor no golpe novo")
	send(KEY_E)
	send(KEY_LEFT)                # Sim
	send(KEY_E)
	check(learn.state == "msg" and game.pending_learns.is_empty() and m.moves == before, "desistiu sem mudar golpes")
	send(KEY_Q)
	check(learn.state == "", "fechou depois de desistir")

	# 3. Poção pela bolsa do menu de pausa.
	var p := Mon.create("pikachu", 10)
	p.hp = 1
	game.party = [p]
	game.bag = {"potion": 3, "poke_ball": 5}
	send(KEY_ESCAPE)
	check(menu.is_open() and menu.screen == "main", "Esc abre o menu")
	send(KEY_S)
	send(KEY_E)
	check(menu.screen == "bag" and menu._cat == "medicine", "bolsa abre em Remédios")
	send(KEY_E)
	check(menu.screen == "target", "escolher Pokémon")
	send(KEY_E)
	check(p.hp == mini(21, p.max_hp) and int(game.bag.get("potion", 0)) == 2, "poção curou e foi descontada")
	check(menu.screen == "msg" and "recuperou" in menu.message, "mensagem do item: " + menu.message)
	send(KEY_E)
	check(menu.screen == "bag", "volta para a bolsa")
	send(KEY_E, 2)                # usar de novo: HP ainda não cheio
	send(KEY_E)
	send(KEY_D)                   # Pokébolas
	send(KEY_E)
	check(menu.screen == "msg" and "Não dá" in menu.message, "bola não usa fora da batalha")
	send(KEY_E)

	# 4. MT com 4 golpes cai na LearnMove; o menu ignora teclas enquanto ela está aberta.
	var f := Mon.create("bulbasaur", 20)
	game.party = [f, p]
	game.add_item("tm09")
	send(KEY_A)                   # MTs (fica entre Remédios e Pokébolas)
	check(menu._cat == "tm", "aba MTs")
	send(KEY_E)
	send(KEY_E)                   # usa em f
	check(learn.is_open() and menu.is_open(), "MT abriu LearnMove por cima do menu")
	send(KEY_E)                   # esquece golpe 0
	check(f.moves[0] == "bullet_seed" and game.bag.has("tm09"), "MT ensinou e não foi gasta")
	check(menu.screen == "msg", "menu não andou enquanto LearnMove aberta")
	send(KEY_E)
	check(learn.state == "", "LearnMove fechou")

	# 5. Resumo e Salvar com posição do jogador.
	send(KEY_ESCAPE, 2)           # msg -> bolsa -> main
	check(menu.screen == "main", "voltou ao menu principal")
	send(KEY_W)                   # Pokémon
	send(KEY_E)
	send(KEY_E)
	check(menu.screen == "summary", "resumo aberto")
	send(KEY_RIGHT)
	check(menu.cursor == 1, "resumo troca de Pokémon")
	send(KEY_ESCAPE, 2)
	var pl := Node3D.new()
	pl.add_to_group("ow_player")
	root.add_child(pl)
	pl.global_position = Vector3(1, 2, 3)
	send(KEY_S, 2)
	send(KEY_E)
	check(menu.screen == "msg" and menu.message == "Jogo salvo.", "salvou")
	var d: Dictionary = game.load_game()
	check(d.get("pos", []) == [1.0, 2.0, 3.0], "posição no save: %s" % [d.get("pos")])
	send(KEY_E)
	send(KEY_S)                   # Fechar
	send(KEY_E)
	check(menu.screen == "", "Fechar fecha o menu")
	check(menu.is_open(), "is_open segura o frame em que fechou")
	game.free()
	print("ui: %d falhas" % fails)
	quit(1 if fails else 0)
