extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_pc/test_pc.gd
## Testa o PCStorage com teclas simuladas (root.push_input) e Game injetado.

const Kit := preload("res://ui/ui_kit.gd")

var fails := 0
var _done := false


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FALHOU: ", what)


func send(k: int, times := 1) -> void:
	for i in times:
		root.push_input(Kit.key(k))


func _process(_dt: float) -> bool:
	if not _done:
		_done = true
		_run()
	return false


func _run() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save_pc.json"
	var pc = load("res://ui/pc/pc_storage.gd").new()
	pc.game = game
	root.add_child(pc)

	var a := Mon.create("Bulbasaur", 5)
	var b := Mon.create("Pidgey", 3)
	var c := Mon.create("Rattata", 4)
	game.party = [a, b]
	game.pc = [c]

	# 1. Abrir, Sair.
	check(not pc.is_open(), "começa fechado")
	check(pc.open(), "open() abre")
	check(pc.is_open() and pc.screen == "menu", "menu aberto")
	check(not pc.open(), "open() não reabre")
	send(KEY_Q)
	check(pc.screen == "" and pc.is_open(), "Q fecha e segura o frame")
	pc.open()

	# 2. Guardar pela equipe.
	send(KEY_E)  # Guardar Pokémon
	check(pc.screen == "party" and pc.party_mode == "deposit", "tela de guardar")
	send(KEY_S)  # pidgey
	send(KEY_E)
	check(game.party == [a] and game.pc == [c, b], "pidgey guardado no PC")
	check(pc.screen == "msg" and "Caixa 1" in pc.message, "mensagem de guardado: " + pc.message)
	send(KEY_E)
	check(pc.screen == "party", "volta para a equipe")

	# 3. Último Pokémon de pé: recusado.
	send(KEY_E)  # tenta guardar bulbasaur (único)
	check(
		game.party == [a] and pc.screen == "msg" and "último" in pc.message,
		"recusa o único: " + pc.message
	)
	send(KEY_E)
	game.party = [a, b]
	game.pc = [c]
	b.hp = 0
	pc._party_cur = 0
	send(KEY_E)
	check(
		game.party.size() == 2 and "de pé" in pc.message,
		"recusa deixar só desmaiados: " + pc.message
	)
	send(KEY_E)
	b.hp = b.max_hp

	# 4. Retirar.
	send(KEY_ESCAPE)
	check(pc.screen == "menu", "Esc volta ao menu")
	send(KEY_S)
	send(KEY_E)  # Retirar Pokémon
	check(pc.screen == "box" and pc.box == 0 and pc.slot == 0, "caixa 1, espaço 1")
	check(pc.selected_mon() == c, "rattata sob o cursor")
	send(KEY_E)
	check(pc.screen == "action", "menu de ações")
	send(KEY_E)  # Retirar
	check(game.party == [a, b, c] and game.pc.is_empty(), "rattata retirado")
	send(KEY_E)
	check(pc.screen == "box", "volta à caixa")

	# 5. Equipe cheia recusa retirar.
	var extra := Mon.create("Caterpie", 2)
	game.pc = [extra]
	for i in 3:
		game.party.append(Mon.create("Weedle", 2))
	send(KEY_E)
	send(KEY_E)
	check(
		game.party.size() == 6 and pc.screen == "msg" and "cheia" in pc.message,
		"equipe cheia: " + pc.message
	)
	send(KEY_E)

	# 6. Soltar com confirmação (Não é o padrão).
	send(KEY_E)  # ações
	send(KEY_S)  # Soltar
	send(KEY_E)
	check(pc.screen == "confirm", "pede confirmação")
	send(KEY_E)  # Não
	check(pc.screen == "action" and game.pc.size() == 1, "Não mantém")
	send(KEY_E)  # Soltar de novo (cursor ficou em Soltar)
	send(KEY_LEFT)  # Sim
	send(KEY_ENTER)
	check(game.pc.is_empty() and pc.screen == "msg", "soltou")
	send(KEY_E)

	# 7. Trocar de caixa.
	var many: Array = []
	for i in 35:
		many.append(Mon.create("Magikarp", 5 + i % 10))
	game.pc = many
	send(KEY_RIGHT, 5)  # coluna 6
	check(pc.box == 0 and pc.slot == 5, "coluna 6 da caixa 1")
	send(KEY_RIGHT)  # passa da borda
	check(pc.box == 1 and pc.slot == 0, "borda direita vai para a caixa 2")
	check(pc.pc_index() == 30 and pc.selected_mon() == many[30], "índice 30 na caixa 2")
	send(KEY_LEFT)
	check(pc.box == 0 and pc.slot == 5, "borda esquerda volta para a caixa 1")
	send(KEY_PAGEUP)
	check(pc.box == 7, "PgUp da caixa 1 vai para a 8")
	send(KEY_PAGEDOWN, 2)
	check(pc.box == 1, "PgDn avança")
	send(KEY_DOWN)  # espaço 7 da caixa 2 = índice 36, vazio
	check(pc.selected_mon() == null, "espaço vazio")
	send(KEY_E)
	check(pc.screen == "box", "espaço vazio não abre ações")

	# 8. PC cheio.
	var full: Array = []
	for i in game.BOX_SIZE * game.BOX_COUNT:
		full.append(Mon.create("Magikarp", 5))
	game.pc = full
	game.party = [a, b]
	send(KEY_ESCAPE)
	send(KEY_W)  # Guardar (cursor estava em Retirar)
	send(KEY_E)
	send(KEY_S)
	send(KEY_E)
	check(game.party.size() == 2 and "cheio" in pc.message, "PC cheio: " + pc.message)
	send(KEY_E)

	# 9. Organizar a equipe.
	game.pc = []
	send(KEY_ESCAPE)
	send(KEY_S, 2)  # Mover/organizar
	send(KEY_E)
	check(pc.screen == "party" and pc.party_mode == "organize", "tela de organizar")
	send(KEY_E)  # pega bulbasaur
	send(KEY_S)
	send(KEY_E)  # troca com pidgey
	check(game.party == [b, a], "trocou a ordem")
	send(KEY_ESCAPE)
	send(KEY_S)  # Sair
	send(KEY_E)
	check(pc.screen == "", "Sair fecha")

	pc.free()
	game.free()
	print("pc: %d falhas" % fails)
	quit(1 if fails else 0)
