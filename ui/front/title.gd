extends Control
## Cena principal: abertura, título, menu (Continuar / Novo jogo / Opções / Créditos / Sair) e a introdução
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
## Modo de treinamento: monta dois times e eles lutam sozinhos (ui/training/).
const TRAINING_SCENE := "res://ui/training/training_setup.tscn"
const START_SPAWN := {"interior": "player_room", "spawn": "bed"}
const PROF_NAME := "PROF. CARVALHO"
const SPLASH_TIME := 2.6
## Segundos parado na tela "Pressione Enter" até voltar à abertura (front_end.IDLE_TO_SPLASH).
const IDLE_TO_SPLASH := 60.0
const CREDITS_IDLE := 1.5
const CREDITS_PAUSE := 3.0
const CREDITS_SPEED := 30.0
## Créditos do original (data/credits.json), traduzidos; a arte e o som usados aqui são os dele.
## [título, linhas, [[nome, detalhe], ...]]
const CREDITS := [
	[
		"JOGO ORIGINAL",
		[
			"Port pessoal do Pokemon Battle Arena 0.2.0 demo, sem fins comerciais. A arte, os sons e o desenho do jogo são do projeto original."
		],
		[]
	],
	[
		"SPRITES DOS POKÉMON",
		[
			"Sprites de Pokémon Mystery Dungeon do PMD SpriteCollab — sprites.pmdcollab.org",
			"Licença CC BY-NC 4.0"
		],
		[
			[
				"Spike Chunsoft",
				"Beedrill, Caterpie, Diglett, Dugtrio, Fearow, Kakuna, Magikarp, Metapod, Nidoqueen, Nidoran F, Pidgeot, Pidgeotto, Pidgey, Pikachu, Poliwag, Poliwhirl, Poliwrath, Psyduck, Raichu, Sandshrew, Sandslash, Slowbro, Spearow, Squirtle, Venusaur"
			],
			["3P1C", "Sandshrew"],
			["Deeshura", "Nidorina"],
			["Emboarger", "Sandshrew"],
			[
				"Emmuffin",
				"Blastoise, Butterfree, Charmander, Charmeleon, Geodude, Goldeen, Golem, Graveler, Gyarados, Mankey, Raticate, Sandslash, Seaking, Slowpoke, Wartortle, Weedle"
			],
			["Grimlin", "Raichu"],
			["Gust", "Bulbasaur, Golduck, Ivysaur"],
			["G〜", "Charizard, Nidoking, Onix"],
			["JFain", "Pidgey"],
			["Morei", "Golem"],
			["NeonCityRain", "Primeape"],
			["Prismatic", "Nidoran M, Nidorino"],
			["ShyStarryRain", "Rattata"],
			["Top_Kec", "Raichu"],
		]
	],
	[
		"EFEITOS DOS GOLPES",
		[
			"Coleção de recursos Pokémon Mystery Dungeon Origins (PMDCollab)",
			"Efeitos de Pokémon Mystery Dungeon, Pokémon Ruby, Sapphire e Emerald e Pokémon Ranger"
		],
		[]
	],
	[
		"MÚSICA E SOM",
		[],
		[
			["Kenney", "Interface, UI, Impact, RPG, Digital e Sci-Fi Sounds, Music Jingles — CC0"],
			["Aureolus_Omicron", "15 Melodic RPG Chiptunes — CC0"],
			["AkitsukiShintai", "Sons dos golpes (pacote Pokémon HD-2D)"],
			["Sons originais", "Gritos e efeitos sintetizados feitos para o jogo"],
		]
	],
	[
		"MODELOS 3D",
		[],
		[
			["Kenney", "City Kit Suburban, Nature Kit, Fantasy Town Kit — CC0"],
			[
				"Pokémon HeartGold e SoulSilver",
				"Modelos do mundo © Nintendo / Creatures Inc. / GAME FREAK inc."
			],
		]
	],
	[
		"FONTES",
		[],
		[
			["Nunito", "The Nunito Project Authors — SIL Open Font License 1.1"],
			["Pixelify Sans", "The Pixelify Sans Project Authors — SIL Open Font License 1.1"],
		]
	],
	[
		"POKÉMON",
		[
			"Pokémon © Nintendo / Creatures Inc. / GAME FREAK inc. Pokémon Mystery Dungeon © Spike Chunsoft. Este é um projeto de fã, gratuito e sem fins comerciais, sem ligação com eles e sem o apoio deles."
		],
		[]
	],
]

## Volta direto ao menu (sem abertura), como o FrontEnd.boot_to_menu do original (menu de pausa > Título).
static var boot_to_menu := false

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
## Letras por segundo das falas; negativo = a velocidade do texto das Opções (0 = instantâneo).
var text_speed := -1.0

## "splash" "press" "menu" "options" "controls" "credits" "overwrite" "talk" "gender" "name" "rival"
## "confirm" "leaving"
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
var _idle := 0.0
var _credits_wait := 0.0
var _credits_acc := 0.0
var _loc_names := {}

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
var _more: Control
var _ask: PanelContainer
var _ask_box: VBoxContainer
var _fade: ColorRect
var _credits: Control
var _credits_scroll: ScrollContainer
var _controls: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	if game == null:
		game = get_node_or_null("/root/Game")
	if not change_scene.is_valid():
		change_scene = func(path: String): get_tree().change_scene_to_file(path)
	settings = Settings.load_cfg(settings_path)
	Settings.apply(settings)
	if text_speed < 0.0:
		text_speed = Settings.text_cps(settings)
	_build()
	if boot_to_menu:
		boot_to_menu = false
		_go_menu()
	else:
		_go_splash()


# --- Montagem ---


func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build() -> void:
	_backdrop = Backdrop.new()
	add_child(_backdrop)

	var center := _full(MarginContainer.new())
	center.add_theme_constant_override("margin_left", 80)
	center.add_theme_constant_override("margin_top", 70)
	add_child(center)
	_title_box = VBoxContainer.new()
	_title_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_title_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title_box.add_theme_constant_override("separation", 18)
	center.add_child(_title_box)
	_logo = Logo.new()
	_title_box.add_child(_logo)
	_press = Kit.header("PRESSIONE ENTER", Kit.PAPER, 30)
	_press.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_press.add_theme_constant_override("shadow_offset_y", 3)
	_title_box.add_child(_press)
	_menu_row = HBoxContainer.new()
	_menu_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_menu_row.add_theme_constant_override("separation", 16)
	_title_box.add_child(_menu_row)
	var menu_panel := Kit.Win.new()
	menu_panel.custom_minimum_size = Vector2(320, 0)
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_menu_row.add_child(menu_panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	menu_panel.add_child(_menu_box)
	_card = Kit.Win.new("CONTINUAR")
	_card.custom_minimum_size = Vector2(360, 0)
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
	_shade.color = Color("10162a")
	_intro.add_child(_shade)
	var rg := Gradient.new()
	rg.colors = PackedColorArray([Color("33447a"), Color(0.06, 0.08, 0.16, 0)])
	var rgt := GradientTexture2D.new()
	rgt.gradient = rg
	rgt.fill = GradientTexture2D.FILL_RADIAL
	rgt.fill_from = Vector2(0.5, 0.42)
	rgt.fill_to = Vector2(0.5, 1.05)
	var glow := TextureRect.new()
	glow.texture = rgt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	_intro.add_child(_full(glow))
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
	_rival_fig.kind = "rival"
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
	_ask = Kit.Win.new()
	_ask.custom_minimum_size = Vector2(420, 0)
	ac.add_child(_ask)
	_ask_box = VBoxContainer.new()
	_ask_box.add_theme_constant_override("separation", 6)
	_ask.add_child(_ask_box)

	_dialog = Kit.Win.new(PROF_NAME)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 80
	_dialog.offset_right = -80
	_dialog.offset_top = -160
	_dialog.offset_bottom = -20
	_intro.add_child(_dialog)
	var dv := VBoxContainer.new()
	_dialog.add_child(dv)
	_speaker = Kit.label(PROF_NAME, Kit.ACCENT, 16)
	_speaker.visible = false
	dv.add_child(_speaker)
	_text = Kit.label("", Kit.TEXT, 22)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_text)
	_more = Kit.hint("Enter continuar")
	dv.add_child(_more)

	# Créditos (credits_panel do original): janela no meio que rola sozinha.
	_credits = _full(Control.new())
	_credits.visible = false
	add_child(_credits)
	var cdim := _full(ColorRect.new())
	cdim.color = Color(0, 0, 0, 0.45)
	_credits.add_child(cdim)
	var ccc := _full(CenterContainer.new())
	_credits.add_child(ccc)
	var cwin := Kit.Win.new("CRÉDITOS")
	cwin.custom_minimum_size = Vector2(620, 534)
	ccc.add_child(cwin)
	var ccol := VBoxContainer.new()
	ccol.add_theme_constant_override("separation", 14)
	cwin.add_child(ccol)
	_credits_scroll = ScrollContainer.new()
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_credits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ccol.add_child(_credits_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_scroll.add_child(body)
	for sec in CREDITS:
		body.add_child(Kit.header(sec[0], Kit.BLUE))
		for line in sec[1]:
			var l := Kit.label(line, Kit.INK, Kit.SIZE_SMALL)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(l)
		for e in sec[2]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 24)
			var n := Kit.label(e[0], Kit.INK)
			n.custom_minimum_size.x = 220
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(n)
			var dl := Kit.label(e[1], Kit.DIM, Kit.SIZE_SMALL)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(dl)
			body.add_child(row)
	var ch := Kit.hint("↑/↓ rola · Esc volta")
	ch.size_flags_horizontal = Control.SIZE_SHRINK_END
	ccol.add_child(ch)

	# Controles (a mesma tabela do menu de pausa).
	_controls = _full(CenterContainer.new())
	_controls.visible = false
	add_child(_controls)

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
	_idle = 0.0
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
	menu_items.append_array(["new", "training", "options", "credits", "quit"])
	cursor = maxi(0, menu_items.find(at))
	_render()


func _go_options() -> void:
	state = "options"
	cursor = 0
	_render()


const MENU_TEXT := {
	"continue": "CONTINUAR",
	"new": "NOVO JOGO",
	"training": "MODO DE TREINAMENTO",
	"options": "OPÇÕES",
	"credits": "CRÉDITOS",
	"quit": "SAIR"
}


func _go_credits() -> void:
	state = "credits"
	_credits_wait = CREDITS_IDLE
	_credits_acc = 0.0
	_credits_scroll.scroll_vertical = 0
	_credits.visible = true


func _go_controls() -> void:
	state = "controls"
	Kit.clear(_controls)
	var w: Array = Kit.panel("CONTROLES", Vector2(minf(900.0, size.x - 40.0), 0), 10)
	_controls.add_child(w[0])
	preload("res://ui/pause_menu.gd").controls_into(w[1])
	_controls.visible = true


func _render() -> void:
	Kit.clear(_menu_box)
	Kit.clear(_card_box)
	_card.visible = false
	match state:
		"menu":
			for i in menu_items.size():
				_menu_box.add_child(Kit.row([MENU_TEXT[menu_items[i]]], [240], i == cursor))
			_menu_box.add_child(Kit.hint("Setas escolhem · Enter confirma"))
			_card.title = "CONTINUAR"
			if menu_items[cursor] == "continue":
				_fill_card()
		"options":
			_menu_box.add_child(Kit.header("OPÇÕES", Kit.BLUE, 20))
			Kit.option_rows(_menu_box, settings, cursor)
			_menu_box.add_child(Kit.hint("↑/↓ escolhe · ←/→ muda · E abre · Esc volta"))


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
	var party: Array = d.get("party", []) if d.get("party", []) is Array else []
	var out := {
		"name": String(d.get("player_name", "?")),
		"money": int(d.get("money", 0)),
		"time": Kit.format_time(float(d.get("play_time", 0.0))),
		"count": party.size(),
		"location": _save_location(d),
		"lead": "",
		"when": ""
	}
	if not party.is_empty() and party[0] is Dictionary:
		var m: Dictionary = party[0]
		var sp := String(m.get("species", ""))
		var nm := String(m.get("nickname", ""))
		if nm == "":
			nm = String(Dex.species(sp).get("name", sp.capitalize())) if sp != "" else "?"
		out.lead = "%s  Nv. %d" % [nm, int(m.get("level", 1))]
	var mt := FileAccess.get_modified_time(game.save_path)
	if mt > 0:
		var dt := Time.get_datetime_dict_from_unix_time(
			mt + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		)
		out.when = "%02d/%02d/%d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
	return out


## Nome do lugar do save (SaveGame.location_name do original): a zona, ou a zona em volta da sala.
func _save_location(d: Dictionary) -> String:
	var zone := String(d.get("zone", ""))
	if zone == "" and d.has("interior"):
		var room: Dictionary = InteriorDefs.ROOMS.get(String(d.interior), {})
		zone = String(room.get("zone", ""))
		if zone == "":
			return String(room.get("name", "?"))
	if zone == "":
		return "?"
	if not _loc_names.has(zone):
		var nm := zone.capitalize()
		var path := "res://data/maps/%s.json" % zone
		if FileAccess.file_exists(path):
			var m = JSON.parse_string(FileAccess.get_file_as_string(path))
			if m is Dictionary:
				nm = String(m.get("name", nm))
		_loc_names[zone] = nm
	return String(_loc_names[zone])


## Cartão do Continuar com as linhas do original (SaveGame.summary_rows): JOGADOR, TEMPO, POKéMON, LOCAL.
func _fill_card() -> void:
	var s := save_summary()
	if s.is_empty():
		return
	_card.visible = true
	var rows := [
		["JOGADOR", s.name],
		["TEMPO", s.time],
		["POKéMON", str(s.count)],
		["LOCAL", s.location],
	]
	_card_box.add_child(Kit.info_grid(rows, 24))


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
	_text.visible_characters = 0 if text_speed > 0.0 else -1
	_more.visible = text_speed <= 0.0


func _talk_ok() -> void:
	if (
		_text.visible_characters >= 0
		and _text.visible_characters < _text.get_total_character_count()
	):
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
		_render_ask(
			"Já existe um jogo salvo. Começar um novo?\n(O save antigo só é substituído quando você salvar.)",
			["Sim", "Não"]
		)
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
		sb.bg_color = Kit.RED_SOFT if i == cursor else Color(Kit.PAPER, 0.85)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		sb.border_color = Kit.RED if i == cursor else Kit.INK
		sb.set_border_width_all(4 if i == cursor else 3)
		sb.anti_aliasing = true
		p.add_theme_stylebox_override("panel", sb)
		var f := Figure.new()
		f.kind = "boy" if i == 0 else "girl"
		p.add_child(f)
		v.add_child(p)
		var l := Kit.header(
			"MENINO" if i == 0 else "MENINA", Kit.RED if i == cursor else Kit.PAPER, 24
		)
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
	_render_ask(
		(
			"Você: %s (%s)\nRival: %s\n\nEstá tudo certo?"
			% [player_name, "menino" if gender == "male" else "menina", rival_name]
		),
		["Sim, vamos lá!", "Não, mudar os nomes"]
	)


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
		game.flags["started_at"] = int(Time.get_unix_time_from_system())
		game.spawn_request = START_SPAWN.duplicate()
	_leave()


## Esc numa fala da introdução pula o resto (front_end._skip_intro): nomes e gênero que faltam
## ficam no padrão e o jogo começa.
func _skip_intro() -> void:
	_finish_new_game()


func _continue() -> void:
	if game != null:
		game.spawn_request = {}
		game.last_save = game.load_game()
	_leave()


func _leave(scene := WORLD_SCENE) -> void:
	state = "leaving"
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(func(): change_scene.call(scene))


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
			_idle += dt
			if _idle > IDLE_TO_SPLASH:
				_go_splash()
		"credits":
			if _credits_wait > 0.0:
				_credits_wait -= dt
			else:
				_credits_acc += CREDITS_SPEED * dt
				var step := int(_credits_acc)
				if step > 0:
					_credits_scroll.scroll_vertical += step
					_credits_acc -= step
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
	if ev is InputEventKey and ev.pressed:
		_idle = 0.0
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
	preload("res://audio/cue.gd").ui(a)
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
					"continue":
						_continue()
					"new":
						_start_new()
					"training":
						_leave(TRAINING_SCENE)
					"options":
						_go_options()
					"credits":
						_go_credits()
					"quit":
						get_tree().quit()
			elif a == "back":
				_go_press()
		"options":
			var key: String = Settings.ROWS[cursor][0]
			if a == "up" or a == "down":
				cursor = posmod(cursor + (1 if a == "down" else -1), Settings.ROWS.size())
			elif a == "back" or (a == "ok" and key == "back"):
				_go_menu("options")
				return
			elif key == "controls":
				if a in ["ok", "right"]:
					_go_controls()
					return
			elif a in ["left", "right", "ok"]:
				var dir := 0 if a == "ok" else (1 if a == "right" else -1)
				if Settings.change(settings, key, dir):
					_apply_settings()
			_render()
		"controls":
			if a in ["ok", "back"]:
				_controls.visible = false
				state = "options"
				_render()
		"credits":
			if a == "back":
				_credits.visible = false
				_go_menu("credits")
			elif a == "up" or a == "down":
				_credits_scroll.scroll_vertical += -60 if a == "up" else 60
				_credits_acc = 0.0
				_credits_wait = CREDITS_PAUSE
		"overwrite":
			if a == "up" or a == "down" or a == "left" or a == "right":
				cursor = 1 - cursor
				_render_ask(
					"Já existe um jogo salvo. Começar um novo?\n(O save antigo só é substituído quando você salvar.)",
					["Sim", "Não"]
				)
			elif a == "back" or (a == "ok" and cursor == 1):
				_ask.visible = false
				_go_menu("new")
			elif a == "ok":
				_ask.visible = false
				_begin_intro()
		"talk":
			if a == "ok":
				_talk_ok()
			elif a == "back":
				_skip_intro()
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
				_render_ask(
					(
						"Você: %s (%s)\nRival: %s\n\nEstá tudo certo?"
						% [player_name, "menino" if gender == "male" else "menina", rival_name]
					),
					["Sim, vamos lá!", "Não, mudar os nomes"]
				)
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
