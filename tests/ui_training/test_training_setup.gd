extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_training/test_training_setup.gd
## Tela de montar o modo de treinamento pela API pública: slots, listas de espécie e de golpes,
## nível, times salvos e as stats mostradas contra o Mon. Usa user://test_training_setup.json e
## user://test_training_teams.json (nunca os arquivos de verdade) e troca de cena interceptada.

const Cfg := preload("res://ui/training/training_config.gd")
const Title := preload("res://ui/front/title.gd")
const TEST_PATH := "user://test_training_setup.json"
const TEST_TEAMS := "user://test_training_teams.json"

var fails := 0
var scene_to := ""


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "FALHOU  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func entry(scr: Node) -> Dictionary:
	return scr.cfg.sides[scr.side].mons[scr.slot]


## Stats na tela iguais às do Mon montado da entrada (Cfg.build_mon: IV 31, EV 0).
func stats_match(scr: Node) -> bool:
	var b := Cfg.build_mon(entry(scr).duplicate(true))
	var shown: Dictionary = scr.shown_stats()
	for s in StatCalc.STATS:
		if int(shown[s]) != b.stat(s):
			print("   %s: tela %d, build_mon %d" % [s, shown[s], b.stat(s)])
			return false
	return true


func _run() -> void:
	Cfg.path = TEST_PATH
	Cfg.teams_path = TEST_TEAMS
	_rm(TEST_PATH)
	_rm(TEST_TEAMS)
	Cfg.current = Cfg.default_config()
	var pm := root.get_node_or_null("PauseMenu")
	var scr: Control = load("res://ui/training/training_setup.tscn").instantiate()
	scr.change_scene = func(p: String): scene_to = p
	root.add_child(scr)
	await frames(2)

	check(scr.cfg == Cfg.current, "a tela edita Cfg.current")
	check(scr.side == 0 and scr.slot == 0, "começa no 1º Pokémon do Time A")
	if pm:
		check(not pm.is_processing_unhandled_input(), "menu de pausa bloqueado na tela")

	# --- Sem IVs/EVs: o Mon luta com IV 31 e EV 0 mesmo numa config antiga ---
	var old := entry(scr)
	old["evs"] = {"hp": 0, "atk": 252, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	old["ivs"] = {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0}
	var bm := Cfg.build_mon(old)
	check(int(bm.evs.atk) == 0 and int(bm.ivs.hp) == StatCalc.IV_MAX, "IV 31 e EV 0 na luta")
	scr.select(0, 0)
	check(stats_match(scr), "stats da tela batem com o Mon")

	# --- Texto digitado num SpinBox (sem Enter) vai para o Pokémon que estava aberto ---
	var le: LineEdit = scr._level.get_line_edit()
	le.grab_focus()
	le.text = "33"
	scr._teams[1].slots[0].button_down.emit()
	scr._teams[1].slots[0].pressed.emit()
	await frames(2)
	check(int(scr.cfg.sides[0].mons[0].level) == 33, "nível digitado fica no Pokémon aberto")
	check(scr.side == 1 and int(scr.cfg.sides[1].mons[0].level) == 15, "e não no que abriu depois")
	scr.select(0, 0)
	scr.set_level(15)

	# --- Slot vazio abre a lista de espécies (ordem da Pokédex); escolher põe no time ---
	var n_a: int = scr.cfg.sides[0].mons.size()
	scr.click_slot(0, n_a + 1)
	check(scr.picker == "", "só o 1º slot vazio abre a lista")
	scr.click_slot(0, n_a)
	check(scr.picker == "species" and scr._ov.visible, "slot vazio abre a lista de espécies")
	var last := 0
	var ordered := true
	for i in scr._ov_list.item_count:
		var no := int(Dex.species(String(scr._ov_list.get_item_metadata(i))).get("dex_no", 0))
		ordered = ordered and no >= last
		last = no
	check(
		ordered and scr._ov_list.item_count == Dex.all_species().size(),
		"espécies em ordem da Pokédex"
	)
	scr._ov_search.text = "bulba"
	scr._refresh_picker()
	check(scr._ov_list.item_count >= 1, "busca acha Bulbasaur")
	scr._on_list_click(0, Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	check(scr.picker == "species", "botão direito não escolhe")
	scr._on_list_click(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	check(scr.picker == "" and not scr._ov.visible, "escolher fecha a lista")
	check(
		scr.cfg.sides[0].mons.size() == n_a + 1 and entry(scr).species == "Bulbasaur",
		"Bulbasaur entrou no Time A e abriu na edição"
	)
	scr.remove_mon(0, n_a)

	# --- Trocar espécie: mantém nível e natureza, golpes do nível ---
	scr.select(0, 0)
	var e := entry(scr)
	e["nature"] = "adamant"
	scr.open_species(0, 0)
	scr.pick("Bulbasaur")
	e = entry(scr)
	check(e.species == "Bulbasaur", "troca de espécie (%s)" % e.species)
	check(int(e.level) == 15 and e.nature == "adamant", "nível e natureza mantidos")
	check(e.moves == Dex.moves_at("Bulbasaur", 15), "golpes do nível da espécie nova")
	check(stats_match(scr), "stats da tela batem com o Mon (Bulbasaur Nv 15)")

	# --- Nível ---
	scr.set_level(42)
	check(int(entry(scr).level) == 42 and stats_match(scr), "nível 42 e stats")
	scr.set_level(500)
	check(int(entry(scr).level) == Growth.MAX_LEVEL, "nível limitado a %d" % Growth.MAX_LEVEL)
	scr.set_level(15)

	# --- Golpes: só os que a espécie aprende, até o nível ---
	var learn: Array = Cfg.learnable_moves("Bulbasaur")
	check(not learn.is_empty(), "Bulbasaur tem golpes para aprender")
	scr.open_moves(0)
	var only_learn: bool = scr.picker == "moves"
	for i in scr._ov_list.item_count:
		var mid := String(scr._ov_list.get_item_metadata(i))
		only_learn = only_learn and (mid == "" or Cfg.learn_level("Bulbasaur", mid) >= 0)
	check(only_learn, "lista de golpes só com os que aprende")
	var high := ""
	var low := ""
	for l2 in learn:
		if int(l2.level) > 15 and high == "":
			high = l2.id
		if int(l2.level) <= 15 and not entry(scr).moves.has(l2.id) and low == "":
			low = l2.id
	if high != "":
		scr.pick(high)
		check(not entry(scr).moves.has(high), "golpe acima do nível fica bloqueado")
		check(scr.picker == "moves", "e a lista continua aberta")
	var foreign := ""
	for id in Dex.all_moves():
		if Cfg.learn_level("Bulbasaur", id) < 0:
			foreign = id
			break
	scr.set_move(0, foreign)
	check(not entry(scr).moves.has(foreign), "golpe que não aprende é recusado")
	if low != "":
		scr.pick(low)
		check(entry(scr).moves[0] == low and scr.picker == "", "golpe 1 trocado pela lista")
	scr.close_picker()
	var n_before: int = entry(scr).moves.size()
	scr.set_move(0, "")
	check(entry(scr).moves.size() == n_before - 1, "golpe vazio tira o golpe")
	scr.set_field("moves", [String(entry(scr).moves[0])])
	scr.set_move(0, "")
	check(
		entry(scr).moves.size() == 1 and scr._status.text.contains("pelo menos um golpe"),
		"não tira o último golpe"
	)
	scr.moves_for_level()
	check(entry(scr).moves == Dex.moves_at("Bulbasaur", 15), "golpes do nível")
	if not Dex.move("flamethrower").is_empty():
		var bp := int(Dex.move("flamethrower").get("bp", 0))
		check(scr._move_info("flamethrower").contains("Poder %d" % bp), "poder pelo bp (stream)")
	if not Dex.move("seismic_toss").is_empty():
		check(scr._move_info("seismic_toss").contains("Poder —"), "poder variável mostra —")

	# --- Times: adicionar, duplicar (sem compartilhar), subir, remover ---
	scr.add_mon(1)
	check(scr.cfg.sides[1].mons.size() == 3 and scr.side == 1 and scr.slot == 2, "adiciona no B")
	scr.set_level(30)
	scr.duplicate_mon(1, 2)
	check(scr.cfg.sides[1].mons.size() == 4 and scr.slot == 3, "duplica o Pokémon")
	scr.set_level(77)
	check(int(scr.cfg.sides[1].mons[2].level) == 30, "cópia não compartilha a entrada")
	scr.move_mon(1, 3, -1)
	check(int(scr.cfg.sides[1].mons[2].level) == 77 and scr.slot == 2, "sobe na ordem")
	scr.remove_mon(1, 2)
	check(scr.cfg.sides[1].mons.size() == 3, "remove o Pokémon")
	for i in 10:
		scr.add_mon(0)
	check(scr.cfg.sides[0].mons.size() == Cfg.PARTY_MAX, "time no máximo de %d" % Cfg.PARTY_MAX)
	scr.click_slot(0, Cfg.PARTY_MAX - 1)
	check(scr.picker == "" and scr.slot == Cfg.PARTY_MAX - 1, "slot cheio abre o Pokémon")
	scr.set_think(0, 2.5)
	check(is_equal_approx(float(scr.cfg.sides[0].think_scale), 2.5), "nível da IA do Time A")
	scr.set_team_item(1, "potion")
	check(scr.cfg.sides[1].item == "potion", "item do Time B")
	scr.set_turbo(true)
	scr.set_time_limit(120)
	check(scr.cfg.turbo == true and int(scr.cfg.time_limit) == 120, "turbo e limite de tempo")

	# --- Times salvos em slots ---
	scr.set_team_name(1, "Rival")
	scr.open_teams(1)
	check(scr.picker == "teams" and scr._ov_list.item_count == Cfg.TEAM_SLOTS, "10 slots")
	check(scr._slot_btns.save.disabled, "sem slot marcado não salva")
	scr.pick(2)
	scr._slot_btns.save.pressed.emit()
	var teams := Cfg.load_teams()
	check(teams[2].get("name") == "Rival" and teams[2].mons.size() == 3, "Time B salvo no slot 3")
	check(not scr._slot_btns.load.disabled, "slot cheio pode carregar")
	scr.close_picker()
	scr.load_team(0, 2)
	check(
		scr.cfg.sides[0].name == "Rival" and scr.cfg.sides[0].mons.size() == 3,
		"slot 3 carregado no Time A"
	)
	scr.select(0, 0)
	scr.set_level(9)
	check(int(Cfg.load_teams()[2].mons[0].level) != 9, "time carregado não mexe no salvo")
	scr.open_teams(0)
	scr.pick(2)
	scr._slot_btns.clear.pressed.emit()
	check(not Cfg.load_teams()[2].is_empty(), "apagar pede confirmação")
	scr._slot_btns.clear.pressed.emit()
	check(Cfg.load_teams()[2].is_empty(), "apagar com confirmação")
	scr.load_team(0, 2)
	check(scr._status.text.contains("vazio"), "slot vazio não carrega")
	scr.close_picker()

	# --- Time vazio não começa ---
	while scr.cfg.sides[1].mons.size() > 0:
		scr.remove_mon(1, 0)
	check(not Cfg.can_start(scr.cfg) and scr._start_btn.disabled, "time vazio desabilita Começar")
	scr.start()
	check(scene_to == "", "start() com time vazio não troca de cena")
	scr.copy_side(0)
	check(scr.cfg.sides[1].mons.size() == 3 and scr.cfg.sides[1].name == "Rival", "copia A p/ B")
	scr.select(1, 0)
	scr.set_level(5)
	check(int(scr.cfg.sides[0].mons[0].level) != 5, "cópia entre times não compartilha")
	scr.set_team_name(1, "Time B")
	scr.swap_sides()
	check(scr.cfg.sides[0].name == "Time B" and scr.side == 0, "troca os times de lado")

	# --- Começar (pelo botão, com um nível digitado e ainda não confirmado) ---
	check(not scr._start_btn.disabled, "Começar habilitado")
	scr.select(0, 0)
	var lv_le: LineEdit = scr._level.get_line_edit()
	lv_le.grab_focus()
	lv_le.text = "40"
	scr._start_btn.button_down.emit()
	scr._start_btn.pressed.emit()
	check(scene_to == scr.BATTLE_SCENE, "start() vai para a luta")
	check(Cfg.current == scr.cfg, "Cfg.current é a config da tela")
	var saved := Cfg.load_config()
	check(
		FileAccess.file_exists(TEST_PATH) and int(saved.sides[0].mons[0].level) == 40,
		"nível digitado confirmado antes de começar"
	)
	scene_to = ""
	scr.back_to_title()
	check(scene_to == scr.TITLE_SCENE and Title.boot_to_menu, "Voltar ao título abre o menu")
	Title.boot_to_menu = false
	scr.reset_default()
	check(scr.cfg.sides[0].mons.size() == 2, "restaurar padrão")

	scr.queue_free()
	await frames(2)
	if pm:
		check(pm.is_processing_unhandled_input(), "menu de pausa liberado ao sair")

	_rm(TEST_PATH)
	_rm(TEST_TEAMS)
	Cfg.path = Cfg.PATH
	Cfg.teams_path = Cfg.TEAMS_PATH
	Cfg.current = {}
	print("TRAINING SETUP: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	quit(1 if fails > 0 else 0)
