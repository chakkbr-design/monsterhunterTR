extends Control
## Cena principal: abertura, título, menu (Continuar / Novo jogo / Opções / Sair) e a introdução
## do professor com escolha de gênero e nomes. Ver docs/CONTRATO.md (Rodada 3, Início de jogo).
## Teclado: setas/WASD navegam, E/Enter/Espaço confirmam, Esc/Q/Backspace voltam (controle: ui_*).
## Na entrada de nome as letras digitam; ali só as setas navegam.

const Kit := preload("res://ui/ui_kit.gd")
const Settings := preload("res://ui/front/settings.gd")
const Backdrop := preload("res://ui/front/backdrop.gd")
const Logo := preload("res://ui/front/logo.gd")
const Figure := preload("res://ui/front/figure.gd")
const NameEntry := preload("res://ui/front/name_entry.gd")

const WORLD_SCENE := "res://world/route_world.tscn"
const START_SPAWN := {"interior": "player_room", "spawn": "bed"}
const PROF_NAME := "PROF. CARVALHO"
const SPLASH_TIME := 2.6

const INTRO := [
	"Olá, olá! Que bom ver você por aqui!\nSeja bem-vindo ao mundo dos monstros!",
	"Meu nome é Carvalho, mas por aqui todo mundo\nme chama de Professor.",
	"Este mundo é cheio de criaturas fantásticas.\nTem gente que vive com elas como amigas...",
	"...e tem gente que treina com elas para batalhar.\nEu dedico a minha vida a estudá-las.",
	"Mas chega de falar de mim!\nMe conte um pouco sobre você.",
]
const ASK_GENDER := "Você é um menino ou uma menina?"
const AFTER_NAME := [
	"{PLAYER}, não é? Que nome bacana!",
	"E este aqui é o meu neto. Vocês dois disputam\ntudo um com o outro desde pequenos.",
	"...Hã, como é mesmo o nome dele?\nA memória já não é a mesma...",
]
const FINALE := [
	"Isso mesmo! Agora eu lembro: {RIVAL}!",
	"{PLAYER}! A sua própria aventura com os monstros\nestá prestes a começar!",
	"Um mundo inteiro de sonhos e descobertas espera\npor você. Vamos lá!",
]
const SUGGEST := {
	"male": ["Léo", "Davi", "Rafa", "Tiago", "Caio"],
	"female": ["Bia", "Lara", "Nina", "Duda", "Lia"],
	"rival": ["Gael", "Bruno", "Igor", "Vítor", "Enzo"],
}

## Injetáveis (testes). game vazio = autoload /root/Game.
var game: Node = null
## Troca de cena; o teste troca por uma função que só registra o caminho.
var change_scene: Callable
var settings_path := Settings.PATH
## Segundos dos fades e letras por segundo do diálogo (testes aceleram).
var fade_time := 0.6
var text_speed := 50.0

## "splash" "press" "menu" "options" "overwrite" "talk" "gender" "name" "rival" "confirm" "leaving"
var state := ""
var settings: Dictionary = {}
var menu_items: Array = []
var cursor := 0
var gender := "male"
var player_name := ""
var rival_name := ""

var _splash_t := 0.0
var _blink_t := 0.0
var _lines: Array = []
var _line := 0
var _chars := 0.0
var _talk_then: Callable
var _talk_back: Callable

var _backdrop: Control
var _title_box: VBoxContainer
var _logo: Control
var _press: Label
var _menu_row: HBoxContainer
var _menu_box: VBoxContainer
var _card: PanelContainer
var _card_box: VBoxContainer
var _splash: Label
var _intro: Control
var _shade: ColorRect
var _stage: HBoxContainer
var _prof: Control
var _rival_fig: Control
var _pick: HBoxContainer
var _entry: PanelContainer
var _dialog: PanelContainer
var _speaker: Label
var _text: Label
var _more: Label
var _ask: PanelContainer
var _ask_box: VBoxContainer
var _fade: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	if game == null:
		game = get_node_or_null("/root/Game")
	if not change_scene.is_valid():
		change_scene = func(path: String): get_tree().change_scene_to_file(path)
	settings = Settings.load_cfg(settings_path)
	Settings.apply(settings)
	_build()
	_go_splash()


# --- Montagem ---

func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build() -> void:
	_backdrop = Backdrop.new()
	add_child(_backdrop)

	var center := _full(CenterContainer.new())
	add_child(center)
	_title_box = VBoxContainer.new()
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.add_theme_constant_override("separation", 18)
	center.add_child(_title_box)
	_logo = Logo.new()
	_title_box.add_child(_logo)
	_press = Kit.label("Pressione Enter", Kit.TEXT, 24)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_press.add_theme_constant_override("outline_size", 6)
	_title_box.add_child(_press)
	_menu_row = HBoxContainer.new()
	_menu_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_row.add_theme_constant_override("separation", 16)
	_title_box.add_child(_menu_row)
	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(300, 0)
	_menu_row.add_child(menu_panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	menu_panel.add_child(_menu_box)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(300, 0)
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_menu_row.add_child(_card)
	_card_box = VBoxContainer.new()
	_card.add_child(_card_box)

	_splash = Kit.label("Um projeto independente\nfeito com Godot", Kit.TEXT, 30)
	_splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_full(_splash)
	var splash_bg := _full(ColorRect.new())
	splash_bg.color = Color(0.03, 0.03, 0.06)
	splash_bg.name = "SplashBg"
	add_child(splash_bg)
	add_child(_splash)

	# Introdução do professor.
	_intro = _full(Control.new())
	add_child(_intro)
	_shade = _full(ColorRect.new())
	_shade.color = Color(0.05, 0.06, 0.12, 0.72)
	_intro.add_child(_shade)
	var sc := _full(CenterContainer.new())
	sc.offset_bottom = -170
	_intro.add_child(sc)
	_stage = HBoxContainer.new()
	_stage.add_theme_constant_override("separation", 60)
	sc.add_child(_stage)
	_prof = Figure.new()
	_prof.kind = "prof"
	_stage.add_child(_prof)
	_rival_fig = Figure.new()
	_rival_fig.kind = "boy"
	_rival_fig.modulate = Color(0.75, 1.0, 0.8)
	_stage.add_child(_rival_fig)
	_pick = HBoxContainer.new()
	_pick.add_theme_constant_override("separation", 40)
	_stage.add_child(_pick)
	var ec := _full(CenterContainer.new())
	_intro.add_child(ec)
	_entry = NameEntry.new()
	ec.add_child(_entry)
	_entry.done.connect(_on_name_done)
	_entry.cancelled.connect(_on_name_cancel)
	var ac := _full(CenterContainer.new())
	ac.offset_bottom = -170
	_intro.add_child(ac)
	_ask = PanelContainer.new()
	_ask.custom_minimum_size = Vector2(420, 0)
	ac.add_child(_ask)
	_ask_box = VBoxContainer.new()
	_ask_box.add_theme_constant_override("separation", 6)
	_ask.add_child(_ask_box)

	_dialog = PanelContainer.new()
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 80
	_dialog.offset_right = -80
	_dialog.offset_top = -160
	_dialog.offset_bottom = -20
	_intro.add_child(_dialog)
	var dv := VBoxContainer.new()
	_dialog.add_child(dv)
	_speaker = Kit.label(PROF_NAME, Kit.ACCENT, 16)
	dv.add_child(_speaker)
	_text = Kit.label("", Kit.TEXT, 22)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_text)
	_more = Kit.hint("Enter »")
	dv.add_child(_more)

	_fade = _full(ColorRect.new())
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)


# --- Estados ---

func _show(title_parts: bool, intro: bool) -> void:
	_title_box.visible = title_parts
	_intro.visible = intro
	for n in [_splash, get_node("SplashBg")]:
		n.visible = state == "splash"


func _go_splash() -> void:
	state = "splash"
	_splash_t = 0.0
	_show(false, false)


func _go_press() -> void:
	state = "press"
	_show(true, false)
	_press.visible = true
	_menu_row.visible = false
	_logo.modulate.a = 0.0
	create_tween().tween_property(_logo, "modulate:a", 1.0, fade_time)


func _go_menu(at := "") -> void:
	state = "menu"
	_show(true, false)
	_logo.modulate.a = 1.0
	_press.visible = false
	_menu_row.visible = true
	menu_items = []
	if game != null and game.has_save():
		menu_items.append("continue")
	menu_items.append_array(["new", "options", "quit"])
	cursor = maxi(0, menu_items.find(at))
	_render()


func _go_options() -> void:
	state = "options"
	cursor = 0
	_render()


const MENU_TEXT := {"continue": "Continuar", "new": "Novo jogo", "options": "Opções", "quit": "Sair"}


func _render() -> void:
	Kit.clear(_menu_box)
	Kit.clear(_card_box)
	_card.visible = false
	match state:
		"menu":
			for i in menu_items.size():
				_menu_box.add_child(Kit.row([MENU_TEXT[menu_items[i]]], [240], i == cursor))
			_menu_box.add_child(Kit.hint("Setas escolhem · Enter confirma"))
			if menu_items[cursor] == "continue":
				_fill_card()
		"options":
			var vol := "<  %d%%  >" % settings.volume
			var full := "<  %s  >" % ("Sim" if settings.fullscreen else "Não")
			var rows := [["Volume geral", vol], ["Tela cheia", full], ["Voltar", ""]]
			_menu_box.add_child(Kit.label("Opções", Kit.ACCENT, 20))
			for i in rows.size():
				_menu_box.add_child(Kit.row(rows[i], [150, 110], i == cursor))
			_menu_box.add_child(Kit.hint("Esquerda/direita ajustam · Esc volta"))


## Resumo do save lido direto do arquivo (não mexe no Game).
func save_summary() -> Dictionary:
	if game == null or not game.has_save():
		return {}
	var f := FileAccess.open(game.save_path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return {}
	var out := {"name": String(d.get("player_name", "?")), "money": int(d.get("money", 0)), "lead": "", "when": ""}
	var party: Array = d.get("party", [])
	if not party.is_empty() and party[0] is Dictionary:
		var m: Dictionary = party[0]
		var sp := String(m.get("species", ""))
		var nm := String(m.get("nickname", ""))
		if nm == "":
			nm = String(Dex.species(sp).get("name", sp.capitalize())) if sp != "" else "?"
		out.lead = "%s  Nv. %d" % [nm, int(m.get("level", 1))]
	var mt := FileAccess.get_modified_time(game.save_path)
	if mt > 0:
		var dt := Time.get_datetime_dict_from_unix_time(mt + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
		out.when = "%02d/%02d/%d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
	return out


func _fill_card() -> void:
	var s := save_summary()
	if s.is_empty():
		return
	_card.visible = true
	_card_box.add_child(Kit.label(s.name, Kit.SEL, 22))
	_card_box.add_child(Kit.label("Parceiro: " + (s.lead if s.lead != "" else "nenhum"), Kit.TEXT))
	_card_box.add_child(Kit.label("Dinheiro: $%d" % s.money, Kit.TEXT))
	if s.when != "":
		_card_box.add_child(Kit.label("Salvo em " + s.when, Kit.DIM, 15))


# --- Introdução ---

func _intro_view(prof: bool, rival: bool, pick: bool, dialog: bool) -> void:
	_show(false, true)
	_prof.visible = prof
	_rival_fig.visible = rival
	_pick.visible = pick
	_dialog.visible = dialog
	_ask.visible = false


func talk(lines: Array, then: Callable, back: Callable, rival := false) -> void:
	state = "talk"
	_intro_view(not rival, rival, false, true)
	_lines = lines
	_line = 0
	_talk_then = then
	_talk_back = back
	_show_line()


func _show_line() -> void:
	_text.text = game.fill_names(_lines[_line]) if game != null else _lines[_line]
	_chars = 0.0
	_text.visible_characters = 0
	_more.visible = false


func _talk_ok() -> void:
	if _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count():
		_text.visible_characters = -1
		_more.visible = true
		return
	_line += 1
	if _line >= _lines.size():
		_talk_then.call()
	else:
		_show_line()


func _start_new() -> void:
	if game != null and game.has_save():
		state = "overwrite"
		cursor = 1
		_render_ask("Já existe um jogo salvo. Começar um novo?\n(O save antigo só é substituído quando você salvar.)", ["Sim", "Não"])
		return
	_begin_intro()


func _begin_intro() -> void:
	_fade.color.a = 0.0
	talk(INTRO, _go_gender, _go_menu.bind("new"))


func _go_gender() -> void:
	state = "gender"
	_intro_view(false, false, true, true)
	_text.text = ASK_GENDER
	_text.visible_characters = -1
	_more.visible = false
	cursor = 0 if gender == "male" else 1
	_render_pick()


func _render_pick() -> void:
	Kit.clear(_pick)
	for i in 2:
		var v := VBoxContainer.new()
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Kit.SEL_BG if i == cursor else Color(0, 0, 0, 0.25)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		if i == cursor:
			sb.border_color = Kit.SEL
			sb.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", sb)
		var f := Figure.new()
		f.kind = "boy" if i == 0 else "girl"
		p.add_child(f)
		v.add_child(p)
		var l := Kit.label("Menino" if i == 0 else "Menina", Kit.SEL if i == cursor else Kit.TEXT, 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		_pick.add_child(v)


func _ask_player_name() -> void:
	state = "name"
	_intro_view(false, false, false, false)
	_entry.ask("Qual é o seu nome?", SUGGEST[gender])


func _ask_rival_name() -> void:
	state = "rival"
	_intro_view(false, false, false, false)
	_entry.ask("Qual é o nome do neto do professor?", SUGGEST.rival)


func _on_name_done(text: String) -> void:
	if state == "name":
		player_name = text
		if game != null:
			game.player_name = text
		talk(AFTER_NAME, _ask_rival_name, _ask_player_name, true)
	elif state == "rival":
		rival_name = text
		if game != null:
			game.rival_name = text
		_go_confirm()


func _on_name_cancel() -> void:
	_entry.visible = false
	if state == "name":
		_go_gender()
	elif state == "rival":
		_ask_player_name()


func _go_confirm() -> void:
	state = "confirm"
	cursor = 0
	_intro_view(true, false, false, false)
	_render_ask("Você: %s (%s)\nRival: %s\n\nEstá tudo certo?" % [player_name, "menino" if gender == "male" else "menina", rival_name],
		["Sim, vamos lá!", "Não, mudar os nomes"])


func _render_ask(question: String, options: Array) -> void:
	_ask.visible = true
	Kit.clear(_ask_box)
	var q := Kit.label(question, Kit.TEXT, 20)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_box.add_child(q)
	for i in options.size():
		_ask_box.add_child(Kit.row([options[i]], [300], i == cursor))
	if state == "overwrite":
		_show(true, true)
		_title_box.visible = true
		_prof.visible = false
		_rival_fig.visible = false
		_pick.visible = false
		_dialog.visible = false


func _finish_new_game() -> void:
	if game != null:
		game.new_game(player_name, rival_name, gender)
		game.spawn_request = START_SPAWN.duplicate()
	_leave()


func _continue() -> void:
	if game != null:
		game.spawn_request = {}
		game.last_save = game.load_game()
	_leave()


func _leave() -> void:
	state = "leaving"
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(func(): change_scene.call(WORLD_SCENE))


# --- Entrada ---

func _process(dt: float) -> void:
	match state:
		"splash":
			_splash_t += dt
			var a := clampf(minf(_splash_t / 0.6, (SPLASH_TIME - _splash_t) / 0.6), 0.0, 1.0)
			_splash.modulate.a = a
			if _splash_t >= SPLASH_TIME:
				_go_press()
		"press":
			_blink_t += dt
			_press.modulate.a = 0.45 + 0.55 * absf(cos(_blink_t * 2.5))
		"talk":
			if _text.visible_characters >= 0:
				_chars += dt * text_speed
				_text.visible_characters = int(_chars)
				if _text.visible_characters >= _text.get_total_character_count():
					_text.visible_characters = -1
					_more.visible = true


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey or ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
		return
	# A tela de título fica com todo o teclado (o PauseMenu não abre aqui).
	get_viewport().set_input_as_handled()
	if state == "leaving":
		return
	if state in ["name", "rival"]:
		_entry.handle(ev)
		return
	var a := Kit.nav(ev)
	if a != "":
		press(a)


## Aplica uma ação ("up" "down" "left" "right" "ok" "back"). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	match state:
		"splash":
			if a in ["ok", "back"]:
				_go_press()
		"press":
			if a == "ok":
				_go_menu()
		"menu":
			if a == "up" or a == "down":
				cursor = posmod(cursor + (1 if a == "down" else -1), menu_items.size())
				_render()
			elif a == "ok":
				match menu_items[cursor]:
					"continue": _continue()
					"new": _start_new()
					"options": _go_options()
					"quit": get_tree().quit()
			elif a == "back":
				_go_press()
		"options":
			if a == "up" or a == "down":
				cursor = posmod(cursor + (1 if a == "down" else -1), 3)
			elif a == "back" or (a == "ok" and cursor == 2):
				_go_menu("options")
				return
			elif cursor == 0 and (a == "left" or a == "right"):
				settings.volume = clampi(int(settings.volume) + (10 if a == "right" else -10), 0, 100)
				_apply_settings()
			elif cursor == 1 and a in ["left", "right", "ok"]:
				settings.fullscreen = not settings.fullscreen
				_apply_settings()
			_render()
		"overwrite":
			if a == "up" or a == "down" or a == "left" or a == "right":
				cursor = 1 - cursor
				_render_ask("Já existe um jogo salvo. Começar um novo?\n(O save antigo só é substituído quando você salvar.)", ["Sim", "Não"])
			elif a == "back" or (a == "ok" and cursor == 1):
				_ask.visible = false
				_go_menu("new")
			elif a == "ok":
				_ask.visible = false
				_begin_intro()
		"talk":
			if a == "ok":
				_talk_ok()
			elif a == "back" and _talk_back.is_valid():
				_talk_back.call()
		"gender":
			if a == "left" or a == "right" or a == "up" or a == "down":
				cursor = 1 - cursor
				gender = "male" if cursor == 0 else "female"
				_render_pick()
			elif a == "ok":
				gender = "male" if cursor == 0 else "female"
				_ask_player_name()
			elif a == "back":
				_go_menu("new")
		"confirm":
			if a == "up" or a == "down":
				cursor = 1 - cursor
				_render_ask("Você: %s (%s)\nRival: %s\n\nEstá tudo certo?" % [player_name, "menino" if gender == "male" else "menina", rival_name],
					["Sim, vamos lá!", "Não, mudar os nomes"])
			elif a == "ok" and cursor == 0:
				_ask.visible = false
				talk(FINALE, _finish_new_game, Callable(), true)
				_talk_back = Callable()
			elif a == "ok" or a == "back":
				_ask.visible = false
				_ask_player_name()


func _apply_settings() -> void:
	Settings.save_cfg(settings, settings_path)
	Settings.apply(settings)
