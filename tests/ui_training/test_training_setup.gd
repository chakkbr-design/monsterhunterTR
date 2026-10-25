extends SceneTree
## Rodar: godot --headless --path . --script res://tests/ui_training/test_training_setup.gd
## Tela de montar o modo de treinamento pela API pública: slots, listas de espécie e de golpes,
## o Nv 50 fixo (qualquer golpe da espécie vale), times salvos e as stats mostradas contra o Mon.
## Usa user://test_training_setup.json e user://test_training_teams.json (nunca os arquivos de
## verdade) e troca de cena interceptada.

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


## Stats na tela iguais às do Mon montado da entrada (Cfg.build_mon: Nv 50, IV 31, EV 0).
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
	check(int(entry(scr).level) == Cfg.LEVEL, "Pokémon do padrão nasce no Nv %d" % Cfg.LEVEL)
	check(scr._level is Label, "o nível é um rótulo fixo, sem SpinBox")
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
	check(int(entry(scr).level) == Cfg.LEVEL, "Pokémon novo nasce no Nv %d" % Cfg.LEVEL)
	scr.remove_mon(0, n_a)

	# --- Trocar espécie: mantém natureza, golpes do Nv 50 da espécie nova ---
	scr.select(0, 0)
	var e := entry(scr)
	e["nature"] = "adamant"
	scr.open_species(0, 0)
	scr.pick("Bulbasaur")
	e = entry(scr)
	check(e.species == "Bulbasaur", "troca de espécie (%s)" % e.species)
	check(int(e.level) == Cfg.LEVEL and e.nature == "adamant", "nível e natureza mantidos")
	check(e.moves == Dex.moves_at("Bulbasaur", Cfg.LEVEL), "golpes do Nv 50 da espécie nova")
	check(stats_match(scr), "stats da tela batem com o Mon (Bulbasaur Nv 50)")

	# --- Golpes: qualquer golpe que a espécie aprende, em qualquer nível ---
	var learn: Array = Cfg.learnable_moves("Bulbasaur")
	check(not learn.is_empty(), "Bulbasaur tem golpes para aprender")
	scr.open_moves(0)
	var only_learn: bool = scr.picker == "moves"
	for i in scr._ov_list.item_count:
		var mid := String(scr._ov_list.get_item_metadata(i))
		only_learn = only_learn and (mid == "" or Cfg.learn_level("Bulbasaur", mid) >= 0)
	check(only_learn, "lista de golpes só com os que aprende")
	var low := ""
	for l2 in learn:
		if not entry(scr).moves.has(l2.id) and low == "":
			low = l2.id
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
	check(entry(scr).moves == Dex.moves_at("Bulbasaur", Cfg.LEVEL), "golpes do Nv 50")
	if not Dex.move("flamethrower").is_empty():
		var bp := int(Dex.move("flamethrower").get("bp", 0))
		check(scr._move_info("flamethrower").contains("Poder %d" % bp), "poder pelo bp (stream)")
	if not Dex.move("seismic_toss").is_empty():
		check(scr._move_info("seismic_toss").contains("Poder —"), "poder variável mostra —")

	# --- Golpe de nível alto (acima do 50) entra num Pokémon novo, sem bloqueio ---
	var hi_sp := ""
	var hi_id := ""
	var hi_lv := 0
	for sp in Dex.all_species():
		for le in Cfg.learnable_moves(sp):
			if int(le.level) > Cfg.LEVEL and hi_id == "":
				hi_sp = sp
				hi_id = String(le.id)
				hi_lv = int(le.level)
	check(hi_id != "", "há golpe aprendido acima do Nv %d (%s, Nv %d)" % [Cfg.LEVEL, hi_id, hi_lv])
	scr.add_mon(1, hi_sp)
	check(
		entry(scr).species == hi_sp and not entry(scr).moves.has(hi_id), "Pokémon novo, sem o golpe"
	)
	check(Cfg.learn_level(hi_sp, hi_id) == hi_lv and scr.can_use_move(hi_id), "golpe liberado")
	scr.open_moves(0)
	scr.pick(hi_id)
	check(
		entry(scr).moves[0] == hi_id and scr.picker == "", "golpe do Nv %d entra no slot 1" % hi_lv
	)
	check(stats_match(scr), "stats batem com o Mon (Nv 50, golpe de Nv %d)" % hi_lv)
	scr.remove_mon(1, scr.slot)
	scr.select(0, 0)

	# --- Times: adicionar, duplicar (sem compartilhar), subir, remover ---
	scr.add_mon(1)
	check(scr.cfg.sides[1].mons.size() == 3 and scr.side == 1 and scr.slot == 2, "adiciona no B")
	scr.set_field("hp_pct", 30)
	scr.duplicate_mon(1, 2)
	check(scr.cfg.sides[1].mons.size() == 4 and scr.slot == 3, "duplica o Pokémon")
	scr.set_field("hp_pct", 77)
	check(int(scr.cfg.sides[1].mons[2].hp_pct) == 30, "cópia não compartilha a entrada")
	scr.move_mon(1, 3, -1)
	check(int(scr.cfg.sides[1].mons[2].hp_pct) == 77 and scr.slot == 2, "sobe na ordem")
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

	# --- Jogador 1: IA (padrão) ou Manual (teclado no Time A) ---
	check(Cfg.default_config().p1_control == "ai", "Jogador 1 começa como IA")
	scr.set_p1_control("manual")
	check(
		scr.cfg.p1_control == "manual" and scr._p1.selected == 1,
		"set_p1_control grava e mostra Manual"
	)
	check(Cfg.arena_opts(scr.cfg, Vector3.ZERO).keyboard == true, "manual: opts com teclado")
	scr.set_p1_control("ai")
	check(scr.cfg.p1_control == "ai" and scr._p1.selected == 0, "volta para IA")
	scr.set_p1_control("qualquer")
	check(scr.cfg.p1_control == "ai", "valor inválido vira IA")

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
	scr.set_field("hp_pct", 9)
	check(int(Cfg.load_teams()[2].mons[0].hp_pct) != 9, "time carregado não mexe no salvo")
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
	scr.set_field("hp_pct", 5)
	check(int(scr.cfg.sides[0].mons[0].hp_pct) != 5, "cópia entre times não compartilha")
	scr.set_team_name(1, "Time B")
	scr.swap_sides()
	check(scr.cfg.sides[0].name == "Time B" and scr.side == 0, "troca os times de lado")

	# --- Começar pelo botão: a config gravada tem o Nv 50 ---
	check(not scr._start_btn.disabled, "Começar habilitado")
	scr.select(0, 0)
	scr._start_btn.button_down.emit()
	scr._start_btn.pressed.emit()
	check(scene_to == scr.BATTLE_SCENE, "start() vai para a luta")
	check(Cfg.current == scr.cfg, "Cfg.current é a config da tela")
	var saved := Cfg.load_config()
	check(
		FileAccess.file_exists(TEST_PATH) and int(saved.sides[0].mons[0].level) == Cfg.LEVEL,
		"config gravada com o Nv %d" % Cfg.LEVEL
	)
	scene_to = ""
	scr.back_to_title()
	check(scene_to == scr.TITLE_SCENE and Title.boot_to_menu, "Voltar ao título abre o menu")
	Title.boot_to_menu = false
	scr.reset_default()
	check(scr.cfg.sides[0].mons.size() == 2, "restaurar padrão")

	# --- Config antiga (Nv 12 salvo, time salvo no slot 6): a luta usa o Nv 50 ---
	var old12 := Cfg.mon_entry("Pikachu", 12)
	var b12 := Cfg.build_mon(old12)
	check(b12.level == Cfg.LEVEL, "build_mon põe o Nv 50 mesmo de entrada no Nv 12")
	check(
		b12.stat("spe") == Cfg.build_mon(Cfg.mon_entry("Pikachu", Cfg.LEVEL)).stat("spe"),
		"stats do Nv 50 (não do Nv 12)"
	)
	Cfg.save_team(5, {"name": "Antigo", "item": "", "think_scale": 1.0, "mons": [old12]})
	scr.load_team(0, 5)
	check(scr.cfg.sides[0].name == "Antigo", "time salvo no Nv 12 carregado")
	check(Cfg.build_side(scr.cfg, 0)[0].level == Cfg.LEVEL, "e a luta o monta no Nv 50")
	scr.select(0, 0)
	check(stats_match(scr), "tela mostra as stats do Nv 50 para o Nv 12 salvo")
	check(scr._mon_line(entry(scr)).contains("Nv %d" % Cfg.LEVEL), "lista mostra Nv %d" % Cfg.LEVEL)

	# Times aleatórios: 6 por lado, da Pokédex 1-51, com dano e status quando a espécie aprende.
	scr.random_teams()
	for s in Cfg.SIDES:
		var ms: Array = scr.cfg.sides[s].mons
		check(ms.size() == Cfg.PARTY_MAX, "sorteio: lado %d com 6" % s)
		check(
			ms.all(func(d): return Cfg.random_pool().has(d.species) and not d.moves.is_empty()),
			"sorteio: lado %d da Pokédex 1-51, com golpes" % s
		)
	check(Cfg.can_start(scr.cfg), "sorteio: pronto para lutar")

	# Sorteio equilibrado por tipo: determinístico pela semente e sem espécie repetida.
	var ra := RandomNumberGenerator.new()
	ra.seed = 77
	var rb := RandomNumberGenerator.new()
	rb.seed = 77
	var ta: Array = Cfg.random_mons(ra).map(func(d): return d.species)
	var tb: Array = Cfg.random_mons(rb).map(func(d): return d.species)
	check(ta == tb, "sorteio por tipo: mesma semente, mesmo time")
	var uniq := {}
	for sp in ta:
		uniq[sp] = true
	check(uniq.size() == Cfg.PARTY_MAX, "sorteio por tipo: sem espécie repetida")

	# Cenário: padrão aleatório, escolhido vai para a config e para as opts da arena.
	check(Cfg.scenario(scr.cfg) == "" and scr._scenario.selected == 0, "cenário padrão: aleatório")
	check(not Cfg.arena_opts(scr.cfg, Vector3.ZERO).has("scenario"), "aleatório: opts sem cenário")
	scr.set_scenario("lagoa")
	check(scr.cfg.scenario == "lagoa", "cenário Lagoa na config")
	check(scr._scenario.get_item_text(scr._scenario.selected) == "Lagoa", "e no seletor")
	check(Cfg.arena_opts(scr.cfg, Vector3.ZERO).get("scenario") == "lagoa", "e nas opts da arena")
	scr.set_scenario("xyz")
	check(Cfg.scenario(scr.cfg) == "", "cenário inválido volta a aleatório")
	Cfg.save_config({"sides": scr.cfg.sides, "scenario": "misto"})
	check(String(Cfg.load_config().scenario) == "misto", "cenário salvo no arquivo")

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
