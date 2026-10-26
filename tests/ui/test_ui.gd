extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui/test_ui.gd
## Testa LearnMove e PauseMenu com teclas simuladas (root.push_input), Game injetado.

const Kit := preload("res://ui/ui_kit.gd")
const Settings := preload("res://ui/front/settings.gd")

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


## Da primeira fala da LearnMove até a lista de golpes: 2 falas e SIM em "Apagar um golpe?".
func learn_to_pick() -> void:
	send(KEY_E, 3)


func _run() -> void:
	var game = load("res://core/game.gd").new()
	game.save_path = "user://test_save.json"
	var learn = load("res://ui/learn_move_ui.gd").new()
	learn.game = game
	root.add_child(learn)
	var menu = load("res://ui/pause_menu.gd").new()
	menu.game = game
	menu.learn = learn
	var went_to := [""]
	menu.change_scene = func(p: String): went_to[0] = p
	root.add_child(menu)

	# 1. Fila com 2 golpes, resolvida pelo teclado, com as falas do original.
	var m := Mon.create("bulbasaur", 20)
	var old: Array = m.moves.duplicate()
	var nw := unknown_moves(m, 3)
	game.queue_learn(m, nw[0])
	game.queue_learn(m, nw[1])
	check(game.pending_learns.size() == 2, "fila tem 2")
	game.learn_requested.emit()
	check(learn.is_open() and learn.state == "talk", "LearnMove abriu nas falas")
	check("tentando aprender" in learn.message, "fala 1: " + learn.message)
	send(KEY_E)
	check("mais de quatro golpes" in learn.message, "fala 2: " + learn.message)
	send(KEY_E)
	check(learn.state == "ask" and learn.question == "delete", "pergunta apagar um golpe")
	send(KEY_E)  # SIM
	check(learn.state == "pick", "SIM abre a lista")
	send(KEY_S)  # cursor 1
	send(KEY_E)  # esquece o golpe 1
	check(m.moves[1] == nw[0] and learn.state == "talk", "trocou golpe 1 pelo primeiro")
	check("Puf" in learn.message, "1, 2 e... Puf!: " + learn.message)
	send(KEY_E)
	check("esqueceu" in learn.message, "esqueceu: " + learn.message)
	send(KEY_E)
	check(learn.message == "E…", "E…")
	send(KEY_E)
	check("aprendeu" in learn.message, "aprendeu: " + learn.message)
	send(KEY_ENTER)  # próximo da fila
	check(learn.is_open() and learn.state == "talk", "segundo da fila")
	learn_to_pick()
	check(learn.state == "pick" and learn.cursor == 0, "lista do segundo")
	send(KEY_DOWN, 2)
	send(KEY_UP, 2)  # cursor 0
	send(KEY_ENTER)
	check(m.moves[0] == nw[1], "trocou golpe 0 pelo segundo")
	send(KEY_E, 4)
	check(learn.state == "" and game.pending_learns.is_empty(), "fila vazia e tela fechada")
	check(m.moves[2] == old[2] and m.moves[3] == old[3], "outros golpes intactos")

	# 2. Desistir: NÃO em apagar -> "Parar de aprender?" -> NÃO volta, SIM desiste.
	var before: Array = m.moves.duplicate()
	game.queue_learn(m, nw[2])
	game.learn_requested.emit()
	send(KEY_E, 2)
	send(KEY_D)  # NÃO
	send(KEY_E)
	check(learn.state == "ask" and learn.question == "stop", "NÃO pergunta parar de aprender")
	send(KEY_D)  # NÃO
	send(KEY_E)
	check(learn.state == "ask" and learn.question == "delete", "NÃO volta a apagar um golpe")
	send(KEY_E)  # SIM -> lista
	send(KEY_ESCAPE)
	check(learn.state == "ask" and learn.question == "stop", "Esc na lista pergunta parar")
	send(KEY_E)  # SIM
	check(
		learn.state == "talk" and "did not learn" in learn.message and m.moves == before,
		"desistiu sem mudar golpes"
	)
	check(game.pending_learns.is_empty(), "fila vazia depois de desistir")
	send(KEY_Q)
	check(learn.state == "", "fechou depois de desistir")

	# 3. Poção pela bolsa do menu de pausa.
	var p := Mon.create("pikachu", 10)
	p.hp = 1
	game.party = [p]
	game.bag = {"potion": 3, "poke_ball": 5, "great_ball": 2}
	send(KEY_ESCAPE)
	check(menu.is_open() and menu.screen == "main", "Esc abre o menu")
	send(KEY_S)
	send(KEY_E)
	check(menu.screen == "bag" and menu._cat == "medicine", "bolsa abre em Remédios")
	send(KEY_E)
	check(menu.screen == "target", "escolher Pokémon")
	send(KEY_E)
	check(
		p.hp == mini(21, p.max_hp) and int(game.bag.get("potion", 0)) == 2,
		"poção curou e foi descontada"
	)
	check(menu.screen == "msg" and "recovered" in menu.message, "mensagem do item: " + menu.message)
	send(KEY_E)
	check(menu.screen == "bag", "volta para a bolsa")
	send(KEY_D)  # Pokébolas
	check(menu._cat == "balls", "aba Pokébolas")
	var balls: Array = menu._items()
	var gi := balls.find("great_ball")
	send(KEY_S, gi)
	send(KEY_E)
	check(
		menu.screen == "bag" and game.flags.get("selected_ball", "") == "great_ball",
		"E numa bola escolhe a bola do Q (%s)" % game.flags.get("selected_ball", "")
	)
	check("Great Ball" in menu._bag_note, "nota da bola: " + menu._bag_note)
	# Jogar fora (Z): bola sai da bolsa com quantidade e confirmação.
	send(KEY_Z)
	check(menu.screen == "toss" and menu._toss_qty == 1, "Z abre jogar fora")
	send(KEY_UP, 3)
	check(menu._toss_qty == 2, "quantidade limitada ao que tem (%d)" % menu._toss_qty)
	send(KEY_E)
	check(menu.screen == "ask" and "Jogar fora 2" in menu._ask_text, "pergunta: " + menu._ask_text)
	send(KEY_E)  # SIM
	check(not game.bag.has("great_ball") and menu.screen == "bag", "jogou fora 2 Great Ball")
	check("Jogou fora 2" in menu._bag_note, "nota do descarte: " + menu._bag_note)
	send(KEY_A)  # Remédios

	# 4. MT com 4 golpes cai na LearnMove; o menu ignora teclas enquanto ela está aberta.
	var f := Mon.create("bulbasaur", 20)
	game.party = [f, p]
	game.add_item("tm09")
	send(KEY_D)  # MTs (fica entre Remédios e Pokébolas)
	check(menu._cat == "tm", "aba MTs")
	send(KEY_Z)
	check(menu.screen == "bag" and "important" in menu._bag_note, "MT não se joga fora")
	send(KEY_E)
	send(KEY_E)  # usa em f
	check(learn.is_open() and menu.is_open(), "MT abriu LearnMove por cima do menu")
	learn_to_pick()
	send(KEY_E)  # esquece golpe 0
	check(f.moves[0] == "bullet_seed" and game.bag.has("tm09"), "MT ensinou e não foi gasta")
	check(menu.screen == "msg", "menu não andou enquanto LearnMove aberta")
	send(KEY_E, 4)
	check(learn.state == "", "LearnMove fechou")

	# 5. Equipe: RESUMO / TROCAR / ITEM; resumo com páginas e troca de golpes.
	send(KEY_ESCAPE, 2)  # msg -> bolsa -> main
	check(menu.screen == "main", "voltou ao menu principal")
	send(KEY_W)  # Pokémon
	send(KEY_E)
	check(menu.screen == "party", "equipe")
	send(KEY_E)
	check(menu.screen == "party_act" and menu._act_cur == 0, "ações do Pokémon")
	send(KEY_E)
	check(menu.screen == "summary" and menu.summary_page == 0, "resumo aberto")
	send(KEY_DOWN)
	check(menu.cursor == 1, "resumo troca de Pokémon com ↓")
	send(KEY_UP)
	send(KEY_RIGHT, 2)
	check(menu.summary_page == 2, "→ vai para GOLPES")
	var mv0: String = f.moves[0]
	var mv1: String = f.moves[1]
	send(KEY_E)  # segura o golpe 0
	send(KEY_DOWN)  # troca com o 1
	check(f.moves[0] == mv1 and f.moves[1] == mv0, "golpes trocados de posição")
	send(KEY_E)  # solta
	check(menu._move_held == -1 and menu._move_cur == 1, "solta o golpe")
	send(KEY_ESCAPE)
	check(menu.screen == "party", "Esc volta para a equipe")
	send(KEY_E)
	send(KEY_S)  # TROCAR
	send(KEY_E)
	check(menu.screen == "party_switch", "trocar: escolher o lugar")
	send(KEY_S)
	send(KEY_E)
	check(game.party[0] == p and game.party[1] == f, "TROCAR muda a ordem da equipe")
	check(menu.screen == "party", "volta para a equipe")
	p.hp = 1
	send(KEY_E)  # p (lugar 0)
	send(KEY_S, 2)  # ITEM
	send(KEY_E)
	check(menu.screen == "party_item", "lista de itens para o Pokémon")
	send(KEY_E)  # Potion
	check(p.hp > 1 and menu.screen == "party_item", "ITEM usou a poção e ficou na lista")
	check(menu._pitem_note != "", "nota do item: " + menu._pitem_note)
	send(KEY_ESCAPE, 3)
	check(menu.screen == "main", "volta ao menu")

	# 6. Salvar com posição do jogador.
	var pl := Node3D.new()
	pl.add_to_group("ow_player")
	root.add_child(pl)
	pl.global_position = Vector3(1, 2, 3)
	send(KEY_S, 4)  # Salvar (Pokémon, Bolsa, Piquenique, Cartão, Salvar...)
	send(KEY_E)
	check(menu.screen == "msg" and menu.message == "Jogo salvo.", "salvou")
	var d: Dictionary = game.load_game()
	check(d.get("pos", []) == [1.0, 2.0, 3.0], "posição no save: %s" % [d.get("pos")])
	send(KEY_E)
	# 7. Título: pergunta (NÃO é o padrão), SIM troca para o título.
	send(KEY_S, 2)  # Título (depois de Opções)
	send(KEY_E)
	check(menu.screen == "ask" and not menu._ask_yes, "Título pergunta, NÃO marcado")
	send(KEY_E)
	check(menu.screen == "main" and went_to[0] == "", "NÃO volta ao menu")
	send(KEY_E)
	send(KEY_A)
	send(KEY_E)
	check(went_to[0] == "res://ui/front/title.tscn" and menu.screen == "", "SIM volta ao título")
	check(preload("res://ui/front/title.gd").boot_to_menu, "título abre direto no menu")
	preload("res://ui/front/title.gd").boot_to_menu = false
	check(menu.is_open(), "is_open segura o frame em que fechou")

	# 8. Pokédex, Cartão de Treinador, Opções e Controles.
	menu.settings_path = "user://test_settings_ui.cfg"
	game.flags["has_pokedex"] = true
	game.flags["badge_boulder"] = true
	game.flags["started_at"] = 1792800000  # 23/10/2026
	game.trainer_id = 36969
	game.money = 3000
	game.seen = {"Pidgey": true, "bulbasaur": true}
	game.caught = {"bulbasaur": true}
	check(menu.open() and menu.entries()[0] == "pokedex", "Pokédex no menu com has_pokedex")
	check(menu.entries()[-1] == "title", "último item é TÍTULO")
	check(menu.cursor == 1, "cursor começa em POKéMON")
	menu.press("up")
	menu.press("ok")
	check(
		menu.screen == "dex" and menu._dex.size() == 16 and menu.cursor == 0,
		"Pokédex lista 1..16 (%d)" % menu._dex.size()
	)
	check(menu.dex_counts() == Vector2i(2, 1), "vistos 2, capturados 1")
	menu.press("down")
	check(menu.cursor == 15, "pula as linhas vazias até Pidgey")
	menu.press("ok")
	check(menu.screen == "dex_entry", "abre o verbete")
	menu.press("back")
	menu.press("back")
	check(menu.screen == "main", "Pokédex volta ao menu")
	menu.press("down")
	menu.press("down")
	menu.press("down")
	check(
		menu.entries()[3] == "picnic" and not menu.can_picnic(),
		"PIQUENIQUE desativado sem ninguém fora"
	)
	menu.press("ok")
	check(menu.screen == "main", "piquenique desativado não abre")
	menu.press("down")
	menu.press("ok")
	check(menu.screen == "card" and menu.card_front, "cartão de treinador (frente)")
	check(menu.trainer_id_text() == "36969", "Nº ID = Game.trainer_id")
	check(menu.format_started(1792800000).ends_with("OCT 2026"), "linha INÍCIO")
	check(Kit.money_text(3000) == "₽3000" and Kit.format_money(72) == "₽72", "dinheiro ₽3000")
	menu.press("right")
	check(
		not menu.card_front and menu.has_badge("boulder") and not menu.has_badge("cascade"),
		"verso com insígnias"
	)
	menu.press("back")
	menu.press("down")
	menu.press("down")
	menu.press("ok")
	check(menu.screen == "options", "opções")
	check(Settings.ROWS[0][0] == "text_speed", "primeira opção: velocidade do texto")
	menu.press("right")
	check(int(menu._settings.text_speed) == 2, "velocidade do texto muda com →")
	menu.press("down")
	menu.press("right")
	check(int(menu._settings.battle_speed) == 1, "velocidade da batalha: Rápido")
	menu.press("down")
	var mus := int(menu._settings.music)
	menu.press("left")
	check(int(menu._settings.music) == maxi(mus - 10, 0), "música muda com ←")
	var cfg := Settings.load_cfg("user://test_settings_ui.cfg")
	check(
		cfg.text_speed == 2 and cfg.battle_speed == 1 and cfg.music == mus - 10,
		"opções gravadas: %s" % cfg
	)
	for i in 5:  # som, janela, gráficos, névoa do clima, dicas
		menu.press("down")
	check(Settings.ROWS[menu.cursor][0] == "battle_tips", "dicas de batalha")
	menu.press("ok")
	check(menu._settings.battle_tips == false, "dicas de batalha desligam")
	menu.press("down")
	menu.press("ok")
	check(menu.screen == "controls", "tela de controles")
	menu.press("back")
	menu.press("back")
	check(menu.screen == "main", "volta ao menu")
	menu.press("back")
	check(menu.screen == "", "Esc fecha")

	# 9. Resumo: linhas do original e mood.
	check(menu.mood_text(70) == "Contente" and menu.mood_text(10) == "Desconfiado", "humor")
	check(menu.met_text(f) == "—" or "em" in menu.met_text(f), "encontro")
	# 9b. Repel e Escape Rope pela Bolsa (contrato: Game.use_field_item, RouteWorld.escape_rope).
	game.bag = {"repel": 1, "escape_rope": 1}
	menu.open()
	menu.press("down")  # Bolsa
	menu.press("ok")
	var med: Array = menu._items()
	if game.has_method("use_field_item"):
		for i in med.find("repel"):
			menu.press("down")
		menu.press("ok")
		check(
			int(game.get("repel_steps")) == 100 and not game.bag.has("repel"),
			"Repel usado: 100 passos"
		)
		check(
			menu.screen == "bag" and "Repel" in menu._bag_note, "nota do Repel: " + menu._bag_note
		)
	menu._bag_cur = menu._items().find("escape_rope")
	menu.press("ok")
	check(
		menu.screen == "msg" and game.bag.has("escape_rope"),
		"Escape Rope sem mundo: não usa e não gasta"
	)
	menu.close()

	# 10. HUD: selo de PP nas orbes, relógio, "Salvando…" e a fonte com ₽.
	var Hud := load("res://world/hud.gd")
	check(Hud.PartyOrbs.pp_state(95.0, 95.0, [10.0]) == 0, "PP cheio: sem selo")
	check(Hud.PartyOrbs.pp_state(30.0, 95.0, [10.0]) == 1, "PP <= 40%: '!'")
	check(
		Hud.PartyOrbs.pp_state(5.0, 95.0, [10.0, 20.0]) == 2, "PP abaixo do golpe mais barato: 'zZ'"
	)
	check(Hud.PartyOrbs.pp_state(0.0, 95.0, []) == 2, "PP zero: 'zZ'")
	check(Hud.clock_format(0, 540.0) == "SEG 9:00", "relógio SEG 9:00")
	check(Hud.clock_format(8, 1439.0) == "TER 23:59", "relógio TER 23:59")
	var hud = Hud.new()
	root.add_child(hud)
	hud.show_saving()
	check(hud._saving.modulate.a == 1.0 and "Saving" in hud._saving.text, "Salvando… aparece")
	hud.queue_free()
	check(Kit.body_font().has_char(0x20BD), "fonte tem o ₽")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings_ui.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	game.free()
	print("ui: %d falhas" % fails)
	quit(1 if fails else 0)
