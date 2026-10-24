extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_front/test_front.gd
## Fluxo do título com teclas simuladas (root.push_input), Game injetado com save de teste
## e troca de cena interceptada. Nunca toca no user://save.json de verdade.

const Kit := preload("res://ui/ui_kit.gd")
const Settings := preload("res://ui/front/settings.gd")
const SAVE := "user://test_save_front.json"
const CFG := "user://test_settings_front.cfg"

var fails := 0
var scene_to := ""


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func key(k: int, ch := "") -> void:
	var ev := Kit.key(k)
	if ch != "":
		ev.unicode = ch.unicode_at(0)
	root.push_input(ev)
	await process_frame


func type_text(s: String) -> void:
	for i in s.length():
		var ch := s[i]
		await key(OS.find_keycode_from_string(ch.to_upper()), ch)


## Aperta Enter até o título chegar no estado (ou desistir).
func enter_until(t: Node, st: String, limit := 40) -> bool:
	for i in limit:
		if t.state == st:
			return true
		await key(KEY_ENTER)
	return t.state == st


func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func make_title(game: Node) -> Node:
	scene_to = ""
	var t: Node = load("res://ui/front/title.tscn").instantiate()
	t.game = game
	t.settings_path = CFG
	t.fade_time = 0.02
	t.text_speed = 100000.0
	t.change_scene = func(p: String): scene_to = p
	root.add_child(t)
	return t


func wait_scene(limit := 120) -> void:
	for i in limit:
		if scene_to != "":
			return
		await process_frame


func _run() -> void:
	_rm(SAVE)
	_rm(CFG)
	var game = load("res://core/game.gd").new()
	game.save_path = SAVE
	root.add_child(game)

	# --- 1. Sem save: não há Continuar. Novo jogo completo pelo teclado. ---
	var t := make_title(game)
	await frames(2)
	check(t.state == "splash", "começa na abertura")
	await key(KEY_ENTER)
	check(t.state == "press", "Enter pula a abertura")
	await key(KEY_E)
	check(t.state == "menu", "E abre o menu")
	check(not t.menu_items.has("continue"), "sem save: Continuar escondido")
	check(t.menu_items[t.cursor] == "new", "cursor começa em Novo jogo")
	await key(KEY_ENTER)
	check(t.state == "talk", "Novo jogo abre a fala do professor")
	check(await enter_until(t, "gender"), "falas do professor levam à escolha de gênero")
	await key(KEY_D)
	check(t.gender == "female", "D/direita escolhe Menina")
	await key(KEY_ENTER)
	check(t.state == "name", "entrada do nome do jogador")
	# Digitação física (W e E aqui digitam letras, não navegam).
	await type_text("Wes")
	check(t._entry.value == "Wes", "digitou Wes pelo teclado (valor: %s)" % t._entry.value)
	await key(KEY_BACKSPACE)
	await key(KEY_BACKSPACE)
	await type_text("Ana")
	check(
		t._entry.value == "WAna",
		"Backspace apaga e continua digitando (valor: %s)" % t._entry.value
	)
	await type_text("1234567890")
	check(t._entry.value.length() == 10, "máximo de 10 letras")
	for i in 10:
		await key(KEY_BACKSPACE)
	check(t._entry.value == "", "apagou tudo")
	await key(KEY_ESCAPE)
	check(t.state == "gender", "Esc no nome volta para o gênero")
	await key(KEY_ENTER)
	check(t.state == "name" and t._entry.value == "", "nome de novo, vazio")
	await type_text("Ana")
	await key(KEY_ENTER)
	check(t.player_name == "Ana", "Enter depois de digitar confirma (cursor pula para OK)")
	check(t.state == "talk", "fala sobre o rival")
	check(await enter_until(t, "rival"), "chega no nome do rival")
	# Teclado na tela: A, direita, b (minúscula automática), direita x3 até OK.
	await key(KEY_ENTER)
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(t._entry.value == "Ab", "teclado na tela digita Ab (valor: %s)" % t._entry.value)
	for i in 4:
		await key(KEY_DOWN)
	check(
		t._entry.current_key() == "Espaço", "linha de baixo: Espaço (%s)" % t._entry.current_key()
	)
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(
		t._entry.value == "Gael", "Sugerir preenche o primeiro nome sugerido (%s)" % t._entry.value
	)
	await key(KEY_RIGHT)
	await key(KEY_RIGHT)
	check(t._entry.current_key() == "OK", "cursor em OK")
	await key(KEY_ENTER)
	check(t.state == "confirm", "tela de confirmação")
	check(t.rival_name == "Gael", "rival = Gael")
	await key(KEY_ENTER)
	check(t.state == "talk", "fala final")
	check(await enter_until(t, "leaving"), "fala final termina e sai")
	await wait_scene()
	check(scene_to == "res://world/route_world.tscn", "trocou para a RouteWorld (%s)" % scene_to)
	check(
		game.player_name == "Ana" and game.rival_name == "Gael" and game.player_gender == "female",
		(
			"Game com nomes e gênero (%s, %s, %s)"
			% [game.player_name, game.rival_name, game.player_gender]
		)
	)
	check(
		game.spawn_request == {"interior": "player_room", "spawn": "bed"}, "spawn_request no quarto"
	)
	check(
		game.party.is_empty() and game.flags.keys() == ["started_at"],
		"jogo novo zerado, com a data de início (%s)" % game.flags
	)
	t.queue_free()
	await frames(2)

	# --- 2. Opções gravadas em settings.cfg ---
	t = make_title(game)
	await frames(1)
	t.press("ok")
	t.press("ok")
	check(t.state == "menu", "menu de novo")
	var opt: int = t.menu_items.find("options")
	for i in opt:
		await key(KEY_S)
	await key(KEY_ENTER)
	check(t.state == "options", "abre Opções")
	await key(KEY_A)  # velocidade do texto: Médio -> Lento
	for i in 3:
		await key(KEY_DOWN)
	await key(KEY_LEFT)  # som 100 -> 90
	await key(KEY_DOWN)
	await key(KEY_ENTER)  # janela -> tela cheia
	var cfg := Settings.load_cfg(CFG)
	check(
		cfg.text_speed == 0 and cfg.sfx == 90 and cfg.fullscreen == true,
		"settings.cfg: texto Lento, som 90, tela cheia (%s)" % cfg
	)
	check(Settings.text_cps(cfg) == 25.0, "texto Lento = 25 letras/s")
	check(Settings.battle_speed_value(cfg) == 0.6, "batalha Lento = 0,6x")
	for i in 3:
		await key(KEY_DOWN)
	check(Settings.ROWS[t.cursor][0] == "controls", "linha CONTROLES")
	await key(KEY_ENTER)
	check(t.state == "controls" and t._controls.visible, "abre os controles")
	await key(KEY_ESCAPE)
	check(t.state == "options", "Esc volta às opções")
	await key(KEY_ESCAPE)
	check(t.state == "menu", "Esc volta ao menu")
	# Créditos.
	check(t.menu_items[-2] == "credits", "CRÉDITOS antes de SAIR")
	t.cursor = t.menu_items.find("credits")
	await key(KEY_ENTER)
	check(t.state == "credits" and t._credits.visible, "abre os créditos")
	t._process(5.0)
	t._process(1.0)
	await frames(1)
	check(t._credits_acc >= 0.0, "créditos rolam sozinhos")
	await key(KEY_ESCAPE)
	check(t.state == "menu" and not t._credits.visible, "Esc fecha os créditos")
	# Parado 60 s no "Pressione Enter" volta à abertura.
	await key(KEY_ESCAPE)
	check(t.state == "press", "Esc volta ao Pressione Enter")
	t._process(61.0)
	check(t.state == "splash", "60 s parado volta à abertura")
	t.queue_free()
	await frames(2)
	Settings.save_cfg({"volume": 25, "fullscreen": false}, CFG)
	var back := Settings.load_cfg(CFG)
	check(back.volume == 25 and back.fullscreen == false, "save/load de settings")
	check(Settings.load_cfg("user://nao_existe.cfg") == Settings.DEFAULTS, "sem arquivo = padrão")
	t = make_title(game)
	await frames(1)
	check(t.settings.volume == 25, "título carrega as opções ao abrir")
	t.queue_free()
	await frames(2)

	# --- 3. Com save: Continuar aparece com o resumo e carrega ---
	game.choose_starter("Charmander")
	game.money = 1234
	game.play_time = 125.0
	check(
		game.save_game({"pos": [1.0, 2.0, 3.0], "interior": "player_room"}), "save de teste gravado"
	)
	game.new_game("X", "Y", "male")
	t = make_title(game)
	await frames(1)
	t.press("ok")
	t.press("ok")
	check(t.menu_items[0] == "continue" and t.cursor == 0, "com save: Continuar primeiro")
	var s: Dictionary = t.save_summary()
	check(
		s.get("name") == "Ana" and s.get("money") == 1234 and String(s.get("lead")).contains("5"),
		"resumo do save: %s" % s
	)
	check(
		s.get("time") == "0:02" and s.get("count") == 1 and s.get("location") == "CIDADE DE PALLET",
		"cartão com TEMPO, POKéMON e LOCAL: %s" % s
	)
	check(t._card.visible, "cartão do save visível")
	# Novo jogo com save pede confirmação; Não volta ao menu.
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(t.state == "overwrite", "Novo jogo com save pede confirmação")
	await key(KEY_ENTER)
	check(t.state == "menu", "Não volta ao menu")
	await key(KEY_UP)
	await key(KEY_ENTER)
	await wait_scene()
	check(scene_to == "res://world/route_world.tscn", "Continuar troca para a RouteWorld")
	check(
		game.player_name == "Ana" and game.money == 1234 and game.party.size() == 1,
		"Game carregado do save"
	)
	check(game.last_save.get("pos", []) == [1.0, 2.0, 3.0], "last_save com a posição")
	check(game.spawn_request.is_empty(), "Continuar não pede spawn")
	t.queue_free()
	await frames(2)

	# --- 4. Esc na fala do professor pula a introdução (nomes padrão); boot_to_menu ---
	_rm(SAVE)
	t = make_title(game)
	await frames(1)
	t.press("ok")
	t.press("ok")
	check(t.menu_items[t.cursor] == "new", "sem save: Novo jogo")
	await key(KEY_ENTER)
	check(t.state == "talk", "fala do professor")
	await key(KEY_ESCAPE)
	await wait_scene()
	check(
		scene_to == "res://world/route_world.tscn" and game.player_name == "RED",
		"Esc pula a introdução com os nomes padrão (%s)" % game.player_name
	)
	check(int(game.flags.get("started_at", 0)) > 0, "data de início gravada")
	t.queue_free()
	await frames(2)
	preload("res://ui/front/title.gd").boot_to_menu = true
	t = make_title(game)
	await frames(1)
	check(t.state == "menu", "boot_to_menu abre direto no menu")
	t.queue_free()
	await frames(2)

	_rm(SAVE)
	_rm(CFG)
	print("FRONT: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	quit(1 if fails > 0 else 0)
