extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_training/test_training_setup.gd
## Tela de montar o modo de treinamento pela API pública: espécie, nível, golpes, EVs, times,
## e as stats mostradas contra o Mon. Usa user://test_training_setup.json (nunca o training.json
## de verdade) e troca de cena interceptada.

const Cfg := preload("res://ui/training/training_config.gd")
const Title := preload("res://ui/front/title.gd")
const TEST_PATH := "user://test_training_setup.json"

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


## Stats na tela iguais às do Mon montado da entrada (por Mon.from_dict e por Cfg.build_mon).
func stats_match(scr: Node) -> bool:
	var e := entry(scr)
	var m := Mon.from_dict(e.duplicate(true))
	var b := Cfg.build_mon(e.duplicate(true))
	var shown: Dictionary = scr.shown_stats()
	for s in StatCalc.STATS:
		if int(shown[s]) != m.stat(s) or int(shown[s]) != b.stat(s):
			print("   %s: tela %d, Mon %d, build_mon %d" % [s, shown[s], m.stat(s), b.stat(s)])
			return false
	return true


func _run() -> void:
	Cfg.path = TEST_PATH
	_rm(TEST_PATH)
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

	# --- Texto digitado num SpinBox (sem Enter) vai para o Pokémon que estava aberto ---
	var le: LineEdit = scr._level.get_line_edit()
	le.grab_focus()
	le.text = "33"
	scr._on_team_click(0, Vector2.ZERO, MOUSE_BUTTON_LEFT, 1)
	await frames(2)
	check(int(scr.cfg.sides[0].mons[0].level) == 33, "nível digitado fica no Pokémon aberto")
	check(scr.side == 1 and int(scr.cfg.sides[1].mons[0].level) == 15, "e não no que abriu depois")
	scr._on_team_click(0, Vector2.ZERO, MOUSE_BUTTON_RIGHT, 0)
	scr._on_team_click(0, Vector2.ZERO, MOUSE_BUTTON_WHEEL_DOWN, 0)
	await frames(2)
	check(scr.side == 1, "roda e botão direito não trocam o Pokémon")
	le.grab_focus()
	le.text = "21"
	scr.save()
	check(int(Cfg.load_config().sides[1].mons[0].level) == 21, "Salvar confirma o texto pendente")
	scr.set_level(15)
	scr.select(0, 0)
	scr.set_level(15)

	# --- Espécies em ordem da Pokédex; turbo e limite de tempo ---
	var last := 0
	var ordered := true
	for i in scr._sp_list.item_count:
		var no := int(Dex.species(String(scr._sp_list.get_item_metadata(i))).get("dex_no", 0))
		ordered = ordered and no >= last
		last = no
	check(
		ordered and scr._sp_list.item_count == Dex.all_species().size(),
		"espécies em ordem da Pokédex"
	)
	scr.set_turbo(true)
	scr.set_time_limit(120)
	check(
		scr.cfg.turbo == true and int(scr.cfg.time_limit) == 120 and scr._turbo.button_pressed,
		"turbo e limite de tempo na config"
	)
	scr.cfg.erase("turbo")
	scr.cfg.erase("time_limit")
	scr.select(0, 0)
	check(
		not scr._turbo.button_pressed and int(scr._limit.value) == 0, "config antiga sem as chaves"
	)

	# --- Espécie: mantém nível/IVs/EVs/natureza, golpes do nível, habilidade/gênero válidos ---
	scr.select(0, 0)
	var e := entry(scr)
	e["nature"] = "adamant"
	scr.set_ev("atk", 100)
	scr.set_species("Bulbasaur")
	e = entry(scr)
	check(e.species == "Bulbasaur", "troca de espécie (%s)" % e.species)
	check(int(e.level) == 15 and e.nature == "adamant", "nível e natureza mantidos")
	check(int(e.evs.atk) == 100 and int(e.ivs.spe) == StatCalc.IV_MAX, "EVs e IVs mantidos")
	check(e.moves == Dex.moves_at("Bulbasaur", 15), "golpes do nível da espécie nova")
	check(stats_match(scr), "stats da tela batem com o Mon (Bulbasaur Nv 15)")

	var genderless := ""
	for sp in Dex.all_species():
		if float(Dex.species(sp).get("gender_ratio", 0.5)) < 0.0:
			genderless = sp
			break
	if genderless != "":
		scr.set_species(genderless)
		e = entry(scr)
		check(e.gender == "", "espécie sem gênero fica sem gênero (%s)" % genderless)
		var n: int = Dex.species(genderless).get("abilities", []).size()
		check(int(e.ability_slot) < maxi(n, 1), "habilidade dentro dos slots da espécie")
		scr.set_species("Bulbasaur")

	# --- Nível ---
	scr.set_level(42)
	e = entry(scr)
	check(int(e.level) == 42, "nível 42")
	check(stats_match(scr), "stats da tela batem com o Mon (Nv 42)")
	scr.set_level(500)
	check(int(entry(scr).level) == Growth.MAX_LEVEL, "nível limitado a %d" % Growth.MAX_LEVEL)
	scr.set_level(42)

	# --- Golpes ---
	var other := ""
	for id in Dex.all_moves():
		if not entry(scr).moves.has(id):
			other = id
			break
	scr.set_move(0, other)
	check(entry(scr).moves[0] == other, "golpe 1 trocado para %s" % other)
	var n_before: int = entry(scr).moves.size()
	scr.set_move(0, "")
	check(entry(scr).moves.size() == n_before - 1, "golpe vazio tira o golpe")
	scr.set_move(Mon.MAX_MOVES - 1, other)
	check(entry(scr).moves.has(other), "golpe no último slot")
	scr.set_move(0, "nao_existe")
	check(not entry(scr).moves.has("nao_existe"), "golpe inexistente é ignorado")
	scr.moves_for_level()
	check(entry(scr).moves == Dex.moves_at("Bulbasaur", 42), "golpes do nível")

	# --- Tirar golpe: o slot marcado vai para o 1º vazio; o último golpe não sai ---
	check(entry(scr).moves.size() == Mon.MAX_MOVES, "4 golpes no nível 42")
	var kept: Array = entry(scr).moves.duplicate()
	scr._on_move_slot(1)
	scr.set_move(1, "")
	kept.remove_at(1)
	check(
		entry(scr).moves == kept and scr.move_slot == kept.size(),
		"tirar golpe marca o 1º slot vazio (%d)" % scr.move_slot
	)
	var k_new := -1
	for i in scr._mv_list.item_count:
		var mid := String(scr._mv_list.get_item_metadata(i))
		if mid != "" and not kept.has(mid):
			k_new = i
			break
	scr._on_move_click(k_new, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	var after: Array = entry(scr).moves
	check(
		after.size() == Mon.MAX_MOVES and after.slice(0, kept.size()) == kept,
		"clique na lista não sobrescreve golpe mantido"
	)
	scr.set_field("moves", [String(kept[0])])
	scr.set_move(0, "")
	check(
		entry(scr).moves.size() == 1 and scr._status.text.contains("pelo menos um golpe"),
		"não tira o último golpe"
	)
	scr.moves_for_level()

	# --- IVs/EVs (total 510) ---
	scr.clear_evs()
	scr.set_ev("atk", 252)
	scr.set_ev("spe", 252)
	scr.set_ev("hp", 252)
	e = entry(scr)
	check(int(e.evs.hp) == 6, "EV limitado pelo total 510 (hp = %d)" % int(e.evs.hp))
	scr.set_iv("def", 0)
	check(int(entry(scr).ivs.def) == 0, "IV de Defesa 0")
	check(stats_match(scr), "stats da tela batem com o Mon (EVs/IVs)")
	scr.set_all_ivs(StatCalc.IV_MAX)
	check(int(entry(scr).ivs.def) == StatCalc.IV_MAX, "todos os IVs 31")

	# --- Times: adicionar, duplicar (sem compartilhar), subir, remover ---
	# O padrão já tem 2 Pokémon no Time B (2x2).
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
	scr.set_think(0, 2.5)
	check(is_equal_approx(float(scr.cfg.sides[0].think_scale), 2.5), "nível da IA do Time A")
	scr.set_team_item(1, "potion")
	check(scr.cfg.sides[1].item == "potion", "item do Time B")

	# --- Time vazio não começa ---
	while scr.cfg.sides[1].mons.size() > 0:
		scr.remove_mon(1, 0)
	check(not Cfg.can_start(scr.cfg) and scr._start_btn.disabled, "time vazio desabilita Começar")
	scr.start()
	check(scene_to == "", "start() com time vazio não troca de cena")
	scr.copy_side(0)
	check(scr.cfg.sides[1].mons.size() == Cfg.PARTY_MAX, "copia o Time A para o B")
	check(scr.cfg.sides[1].mons[0] != null and scr.cfg.sides[1].name == "Time B", "nome do B fica")
	scr.select(1, 0)
	scr.set_level(5)
	check(int(scr.cfg.sides[0].mons[0].level) != 5, "cópia entre times não compartilha")
	scr.swap_sides()
	check(scr.cfg.sides[0].name == "Time B" and scr.side == 0, "troca os times de lado")

	# --- Começar (pelo botão, com um EV digitado e ainda não confirmado) ---
	check(not scr._start_btn.disabled, "Começar habilitado")
	scr.clear_evs()
	var ev_le: LineEdit = scr._ev["def"].get_line_edit()
	ev_le.grab_focus()
	ev_le.text = "40"
	scr._start_btn.button_down.emit()
	scr._start_btn.pressed.emit()
	check(scene_to == scr.BATTLE_SCENE, "start() vai para a luta")
	check(Cfg.current == scr.cfg, "Cfg.current é a config da tela")
	var saved := Cfg.load_config()
	check(
		FileAccess.file_exists(TEST_PATH) and saved.sides[0].mons.size() == Cfg.PARTY_MAX,
		"config salva em %s" % TEST_PATH
	)
	check(
		int(saved.sides[scr.side].mons[scr.slot].evs.def) == 40,
		"EV digitado confirmado antes de começar"
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
	Cfg.path = Cfg.PATH
	Cfg.current = {}
	print("TRAINING SETUP: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	quit(1 if fails > 0 else 0)
