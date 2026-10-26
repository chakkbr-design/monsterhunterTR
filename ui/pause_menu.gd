extends CanvasLayer
## Menu de pausa do overworld (autoload PauseMenu), no visual do original (pause_menu, party_panel,
## summary_panel, bag_panel, pokedex_panel, trainer_card, options_screen, controls_screen):
## Pokédex (com flags.has_pokedex), Pokémon, Bolsa, Cartão de Treinador, Salvar, Opções, Título.
## Abre com a ação "pause" (Esc) quando o Game não está ocupado. Não pausa a árvore:
## o jogador do overworld consulta PauseMenu.is_open() para não andar.

const Kit := preload("res://ui/ui_kit.gd")
const Settings := preload("res://ui/front/settings.gd")
const TITLE_SCENE := "res://ui/front/title.tscn"
## Ações de um Pokémon na tela da equipe (party_panel._show_actions do original).
const PARTY_ACTS := [
	["summary", "RESUMO"], ["switch", "TROCAR"], ["item", "ITEM"], ["cancel", "CANCELAR"]
]
## Mon.mood do original (faixas da amizade).
const MOODS := [[70, "Desconfiado"], [150, "Contente"], [220, "Feliz"], [256, "Dedicado"]]
## Tipo de entrega dos golpes (campo "kind" do moves.json), como o resumo do original mostra.
const KINDS := {
	"arc": "arco",
	"projectile": "projétil",
	"beam": "raio",
	"dash": "investida",
	"aoe_self": "área em volta",
	"aoe_target": "área no alvo",
	"debuff_aoe": "enfraquece em área",
	"multi_arc": "arco múltiplo",
	"self_buff": "reforço próprio",
	"stream": "jato",
	"homing": "teleguiado",
	"clones": "clones",
	"whip": "chicote",
	"zone": "zona",
}
const MONTHS := ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"]
const CATS := [
	["medicine", "Remédios"],
	["berries", "Frutas"],
	["tm", "MTs"],
	["balls", "Pokébolas"],
	["key", "Itens-chave"]
]
const SUMMARY_PAGES := ["INFO", "HABILIDADES", "GOLPES"]
const BADGES := [
	["boulder", "ROCHA", "9aa0a8"],
	["cascade", "CASCATA", "58a0e8"],
	["thunder", "TROVÃO", "e8b030"],
	["rainbow", "ARCO-ÍRIS", "68c070"],
	["soul", "ALMA", "e078b0"],
	["marsh", "PÂNTANO", "d8b848"],
	["volcano", "VULCÃO", "e0503a"],
	["earth", "TERRA", "70a050"]
]
const PORTRAIT := "res://original/assets/sprites/trainer.png"
const PORTRAIT_GREEN := "res://original/assets/sprites/trainer_green.png"
const PORTRAIT_FRAME := Rect2(8, 11, 16, 20)
const DEX_ROWS := 11
const CONTROLS := [
	[
		"MUNDO",
		[
			["Andar", "WASD/Setas"],
			["Correr", "Shift"],
			["Interagir", "E"],
			["Dar comida", "F"],
			["Mandar/recolher", "1-6"],
			["Menu", "Esc"]
		]
	],
	[
		"BATALHA",
		[
			["Golpes", "1-4"],
			["Correr", "Shift"],
			["Pular", "Espaço"],
			["Jogar Pokébola", "Q"],
			["Trocar Pokémon", "Tab"],
			["Fugir", "R"],
			["Modo do aliado", "F"],
			["Bolsa rápida", "E"]
		]
	],
	["MENUS", [["Navegar", "Setas/WASD"], ["Confirmar", "E/Enter"], ["Voltar", "Esc/Q"]]],
]

## Instâncias injetáveis (testes). Vazias = autoloads /root/Game e /root/LearnMove.
var game: Node = null
var learn: Node = null
var settings_path := Settings.PATH
## Troca de cena (Voltar ao título); o teste troca por uma função que só registra o caminho.
var change_scene: Callable
## "" fechado | "main" | "party" | "party_act" | "party_switch" | "party_item" | "summary" | "bag"
## | "toss" | "target" | "msg" | "ask" | "dex" | "dex_entry" | "card" | "options" | "controls"
var screen := ""
var cursor := 0
var message := ""
var summary_page := 0
var card_front := true

var _root: Control
var _box: Control
var _main_cur := 0
var _party_cur := 0
var _cat := ""
var _bag_cur := 0
var _item := ""
var _back_to := "main"
var _closed_at := -1
var _dex_cur := 0
var _dex: Array = []
var _opt_cur := 0
var _settings: Dictionary = {}
var _areas := {}
var _act_cur := 0
var _act_note := ""
var _switch_from := -1
var _pitem_cur := 0
var _pitem_note := ""
var _move_cur := 0
var _move_held := -1
var _bag_note := ""
var _toss_qty := 1
var _ask_text := ""
var _ask_yes := true
var _ask_then: Callable
var _ask_back := "main"


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game == null:
		game = get_node_or_null("/root/Game")
	_root = Control.new()
	_root.theme = Kit.ui_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_box = Control.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box)
	_root.visible = false
	get_viewport().size_changed.connect(_on_viewport_resized)


## As janelas são posicionadas pelo tamanho visível; redesenha quando a janela muda (tela cheia, redimensionar).
func _on_viewport_resized() -> void:
	if screen != "":
		_render()


## Verdadeiro também no frame em que fechou, para a tecla de confirmar não vazar para o overworld.
func is_open() -> bool:
	return screen != "" or Engine.get_process_frames() == _closed_at


func _learn_open() -> bool:
	if learn == null:
		learn = get_node_or_null("/root/LearnMove")
	return learn != null and learn.state != ""


func open() -> bool:
	if (
		screen != ""
		or game == null
		or game.is_busy()
		or _learn_open()
		or _story_running()
		or _other_open()
	):
		return false
	_root.visible = true
	_main_cur = maxi(0, entries().find("pokemon"))
	_go("main")
	return true


func close() -> void:
	screen = ""
	_closed_at = Engine.get_process_frames()
	_root.visible = false
	Kit.clear(_box)


func _story_running() -> bool:
	var st := get_node_or_null("/root/Story")
	return st != null and st.is_running()


## PC, evolução ou uma fala do HUD abertos: o menu não abre por cima (a tecla vazaria para eles).
func _other_open() -> bool:
	if not is_inside_tree():
		return false
	for n in ["PCStorage", "Evolution"]:
		var node := get_node_or_null("/root/" + n)
		if node != null and node.has_method("is_open") and node.is_open():
			return true
	var hud := get_tree().get_first_node_in_group("ow_hud")
	return hud != null and hud.has_method("is_dialog_open") and hud.is_dialog_open()


## Itens do menu principal, na ordem do original.
func entries() -> Array:
	var out: Array = []
	if game != null and game.flags.get("has_pokedex", false):
		out.append("pokedex")
	out.append_array(["pokemon", "bag", "picnic", "trainer", "save", "options", "title"])
	return out


## Piquenique (pause_menu.gd:86 e _can_picnic do original): só com alguém fora da bola, no chão.
func can_picnic() -> bool:
	if not is_inside_tree() or game == null or game.get("out") == null or game.out.is_empty():
		return false
	var p := get_tree().get_first_node_in_group("ow_player") as CharacterBody3D
	return p != null and p.is_on_floor() and get_tree().get_first_node_in_group("picnic") == null


func _start_picnic() -> void:
	var p := get_tree().get_first_node_in_group("ow_player")
	close()
	if p == null or not ResourceLoader.exists("res://world/picnic.gd"):
		return
	var pic: Node3D = load("res://world/picnic.gd").new()
	p.get_parent().add_child(pic)
	pic.begin(p)


func _entry_label(id: String) -> String:
	match id:
		"pokedex":
			return "POKéDEX"
		"pokemon":
			return "POKéMON"
		"bag":
			return "BOLSA"
		"picnic":
			return "PIQUENIQUE"
		"trainer":
			return String(game.player_name).to_upper()
		"save":
			return "SALVAR"
		"options":
			return "OPÇÕES"
	return "TÍTULO"


func _unhandled_input(ev: InputEvent) -> void:
	if screen != "":
		return
	var esc: bool = (
		ev is InputEventKey
		and ev.pressed
		and not ev.echo
		and (ev.physical_keycode == KEY_ESCAPE or ev.keycode == KEY_ESCAPE)
	)
	if esc or (InputMap.has_action("pause") and ev.is_action_pressed("pause")):
		if open():
			get_viewport().set_input_as_handled()


func _input(ev: InputEvent) -> void:
	if screen == "" or _learn_open():
		return
	var a := Kit.nav(ev)
	if (
		a == ""
		and ev is InputEventKey
		and ev.pressed
		and not ev.echo
		and (ev.physical_keycode == KEY_Z or ev.keycode == KEY_Z)
	):
		a = "alt"  # pk_alt do original: jogar fora na Bolsa
	if a == "":
		return
	get_viewport().set_input_as_handled()
	press(a)


## Aplica uma ação de navegação ("up" "down" "left" "right" "ok" "back"). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	if screen == "" or _learn_open():
		return
	preload("res://audio/cue.gd").ui(a)
	match screen:
		"main":
			var ents := entries()
			_main_cur = _step(_main_cur, a, ents.size())
			if a == "back":
				close()
				return
			if a == "ok":
				match ents[_main_cur]:
					"pokedex":
						_build_dex()
						_go("dex")
					"pokemon":
						_party_cur = 0
						_go("party")
					"bag":
						_cat = _first_cat()
						_bag_cur = 0
						_bag_note = ""
						_go("bag")
					"picnic":
						if can_picnic():
							_start_picnic()
							return
					"trainer":
						card_front = true
						_go("card")
					"save":
						_save()
					"options":
						_settings = Settings.load_cfg(settings_path)
						_opt_cur = 0
						_go("options")
					"title":
						_ask(
							"Voltar à tela de título? O progresso desde o último save será perdido.",
							_to_title,
							"main",
							false
						)
						return
		"party":
			_party_cur = _step(_party_cur, a, game.party.size())
			if a == "back":
				_go("main")
			elif a == "ok" and not game.party.is_empty():
				_act_cur = 0
				_act_note = ""
				_go("party_act")
		"party_act":
			_act_cur = _step(_act_cur, a, PARTY_ACTS.size())
			if a == "back":
				_go("party")
			elif a == "ok":
				match PARTY_ACTS[_act_cur][0]:
					"summary":
						summary_page = 0
						_move_cur = 0
						_move_held = -1
						_go("summary")
					"switch":
						_switch_from = _party_cur
						_go("party_switch")
					"item":
						_open_party_items("")
					_:
						_go("party")
				return
		"party_switch":
			_party_cur = _step(_party_cur, a, game.party.size())
			if a == "back":
				_party_cur = _switch_from
				_go("party_act")
			elif a == "ok":
				game.swap_party(_switch_from, _party_cur)
				_party_cur = _switch_from
				_switch_from = -1
				_go("party")
		"party_item":
			var ids := _party_items()
			_pitem_cur = _step(_pitem_cur, a, ids.size() + 1)
			if a == "back" or (a == "ok" and _pitem_cur >= ids.size()):
				_go("party_act")
				return
			if a == "ok":
				var id: String = ids[_pitem_cur]
				var m: Mon = game.party[_party_cur]
				var text: String = game.use_item(id, m)
				if text == "":
					text = "%s não teria efeito em %s." % [Kit.item_name(id), m.display_name]
				_open_party_items(text)
				return
			if a in ["up", "down"]:
				_pitem_note = ""
		"summary":
			if a == "left" or a == "right":
				summary_page = posmod(
					summary_page + (1 if a == "right" else -1), SUMMARY_PAGES.size()
				)
				_move_held = -1
			elif summary_page == 2 and a in ["up", "down", "ok"]:
				_summary_move_key(a)
			elif a == "up":
				_party_cur = posmod(_party_cur - 1, game.party.size())
				_move_cur = 0
			elif a == "down":
				_party_cur = posmod(_party_cur + 1, game.party.size())
				_move_cur = 0
			elif a in ["back", "ok"]:
				_go("party")
		"bag":
			var cats := _cats()
			if a == "left" and not cats.is_empty():
				_cat = cats[posmod(cats.find(_cat) - 1, cats.size())]
				_bag_cur = 0
			elif a == "right" and not cats.is_empty():
				_cat = cats[posmod(cats.find(_cat) + 1, cats.size())]
				_bag_cur = 0
			var items := _items()
			_bag_cur = _step(_bag_cur, a, items.size())
			if a in ["left", "right", "up", "down"]:
				_bag_note = ""
			if a == "back":
				_go("main")
			elif a == "ok" and not items.is_empty():
				_item = items[_bag_cur]
				_bag_use(_item)
				return
			elif a == "alt" and not items.is_empty():
				_item = items[_bag_cur]
				if _cat_of(_item) in ["key", "tm"]:
					_bag_note = "Isso é importante demais para jogar fora!"
				else:
					_toss_qty = 1
					_bag_note = ""
					_go("toss")
					return
		"toss":
			var top := maxi(int(game.bag.get(_item, 0)), 1)
			if a == "up" or a == "right":
				_toss_qty = clampi(_toss_qty + 1, 1, top)
			elif a == "down" or a == "left":
				_toss_qty = clampi(_toss_qty - 1, 1, top)
			elif a == "back":
				_go("bag")
				return
			elif a == "ok":
				var n := mini(_toss_qty, int(game.bag.get(_item, 0)))
				_ask(
					"Jogar fora %d %s?" % [n, Kit.item_name(_item)],
					_toss.bind(_item, n),
					"bag",
					true
				)
				return
		"target":
			_party_cur = _step(_party_cur, a, game.party.size())
			if a == "back":
				_go("bag")
			elif a == "ok":
				_use(game.party[_party_cur])
		"msg":
			if a in ["ok", "back"]:
				_go(_back_to)
		"ask":
			if a in ["up", "down", "left", "right"]:
				_ask_yes = not _ask_yes
			elif a == "back" or (a == "ok" and not _ask_yes):
				_go(_ask_back)
				return
			elif a == "ok":
				_ask_then.call()
				return
		"dex":
			if a == "up" or a == "down":
				_dex_cur = _dex_step(_dex_cur, -1 if a == "up" else 1)
			elif a == "back":
				_go("main")
			elif a == "ok" and _dex_cur < _dex.size() and String(_dex[_dex_cur].species) != "":
				_go("dex_entry")
		"dex_entry":
			if a == "up" or a == "down":
				_dex_cur = _dex_step(_dex_cur, -1 if a == "up" else 1)
			elif a in ["back", "ok"]:
				_go("dex")
		"card":
			if a in ["left", "right", "ok"]:
				card_front = not card_front
			elif a == "back":
				_go("main")
		"options":
			_opt_cur = _step(_opt_cur, a, Settings.ROWS.size())
			var key: String = Settings.ROWS[_opt_cur][0]
			if a == "back" or (a == "ok" and key == "back"):
				_go("main")
				return
			if key == "controls":
				if a in ["ok", "right"]:
					_go("controls")
					return
			elif a in ["left", "right", "ok"]:
				var dir := 0 if a == "ok" else (1 if a == "right" else -1)
				if Settings.change(_settings, key, dir):
					_apply_settings()
		"controls":
			if a in ["back", "ok"]:
				_go("options")
				return
	cursor = _cursor()
	_render()


## Página GOLPES do resumo: ↑/↓ escolhe o golpe; E segura e ↑/↓ troca a posição (summary_panel.move_selected).
func _summary_move_key(a: String) -> void:
	var m: Mon = game.party[_party_cur]
	var n := mini(m.moves.size(), Mon.MAX_MOVES)
	if n == 0:
		return
	if a == "ok":
		_move_held = -1 if _move_held >= 0 else _move_cur
		return
	var d := -1 if a == "up" else 1
	if _move_held >= 0:
		var to := _move_held + d
		if to < 0 or to >= n:
			return
		var tmp = m.moves[_move_held]
		m.moves[_move_held] = m.moves[to]
		m.moves[to] = tmp
		_move_held = to
		_move_cur = to
	else:
		_move_cur = clampi(_move_cur + d, 0, n - 1)


## Pergunta SIM/NÃO por cima da tela `back` (o ask_yes_no do original). Sim chama `then`.
func _ask(text: String, then: Callable, back: String, yes_first := true) -> void:
	_ask_text = text
	_ask_then = then
	_ask_back = back
	_ask_yes = yes_first
	_go("ask")


func _toss(id: String, n: int) -> void:
	if n > 0 and game.take_item(id, n):
		_bag_note = "Jogou fora %d %s." % [n, Kit.item_name(id)]
	_fix_bag_cursor()
	_go("bag")


func _to_title() -> void:
	close()
	if game != null and "save_enabled" in game:
		game.save_enabled = false
	preload("res://ui/front/title.gd").boot_to_menu = true
	if change_scene.is_valid():
		change_scene.call(TITLE_SCENE)
	elif is_inside_tree():
		get_tree().change_scene_to_file(TITLE_SCENE)


## Itens da Bolsa que dá para usar num Pokémon (ITEM na tela da equipe).
func _party_items() -> Array:
	var out: Array = []
	for id in game.bag:
		if int(game.bag[id]) > 0 and _usable_outside(id):
			out.append(id)
	out.sort_custom(func(x, y): return Kit.item_name(x) < Kit.item_name(y))
	return out


func _open_party_items(note: String) -> void:
	if _party_items().is_empty():
		_act_note = note if note != "" else "Nenhum item para usar num Pokémon."
		_go("party_act")
		return
	_pitem_note = note
	_pitem_cur = clampi(_pitem_cur, 0, _party_items().size())
	_go("party_item")


## E num item da Bolsa (bag_panel._on_chosen do original).
func _bag_use(id: String) -> void:
	var fx: Dictionary = Dex.item(id).get("effect", {})
	if _cat_of(id) == "balls":
		game.flags["selected_ball"] = id
		_bag_note = "%s → bola da tecla Q na batalha." % Kit.item_name(id)
		_go("bag")
	elif fx.has("repel") and game.has_method("use_field_item"):
		var t: String = game.use_field_item(id)
		if t == "":
			_msg("Não dá para usar isso agora.", "bag")
			return
		_bag_note = t
		_fix_bag_cursor()
		_go("bag")
	elif fx.has("escape"):
		_escape_rope(id)
	elif not _usable_outside(id):
		_msg("Não dá para usar isso agora.", "bag")
	elif game.party.is_empty():
		_msg("Você não tem Pokémon.", "bag")
	else:
		_party_cur = 0
		_go("target")


## Escape Rope: RouteWorld.escape_rope() (contrato); o item só sai da Bolsa se ela foi usada.
func _escape_rope(id: String) -> void:
	var w: Node = get_tree().get_first_node_in_group("ow_root") if is_inside_tree() else null
	if w == null or not w.has_method("escape_rope"):
		_msg("Não dá para usar isso agora.", "bag")
		return
	close()
	var used: bool = await w.escape_rope()
	if used:
		game.take_item(id)
	var hud := get_tree().get_first_node_in_group("ow_hud") if is_inside_tree() else null
	if hud and hud.has_method("toast"):
		hud.toast("Usou uma %s!" % Kit.item_name(id) if used else "Não dá para usar isso aqui.")


func _fix_bag_cursor() -> void:
	if not game.bag.has(_item):
		_bag_cur = 0
		if _items().is_empty():
			var cats := _cats()
			_cat = cats[0] if not cats.is_empty() else _cat
	_bag_cur = clampi(_bag_cur, 0, maxi(_items().size() - 1, 0))


func _step(cur: int, a: String, n: int) -> int:
	if n <= 0:
		return 0
	if a == "up":
		return posmod(cur - 1, n)
	if a == "down":
		return posmod(cur + 1, n)
	return clampi(cur, 0, n - 1)


func _go(s: String) -> void:
	screen = s
	cursor = _cursor()
	_render()


func _msg(text: String, back: String) -> void:
	message = text
	_back_to = back
	_go("msg")


func _cursor() -> int:
	match screen:
		"main":
			return _main_cur
		"party", "summary", "target", "party_switch":
			return _party_cur
		"party_act":
			return _act_cur
		"party_item":
			return _pitem_cur
		"bag", "toss":
			return _bag_cur
		"dex", "dex_entry":
			return _dex_cur
		"options":
			return _opt_cur
	return 0


func _apply_settings() -> void:
	Settings.save_cfg(_settings, settings_path)
	Settings.apply(_settings)


func _save() -> void:
	var extra := {}
	var p: Node3D = null
	var world: Node = null
	if is_inside_tree():
		p = get_tree().get_first_node_in_group("ow_player") as Node3D
		world = get_tree().get_first_node_in_group("ow_root")
	if world and world.has_method("save_extra"):
		extra = world.save_extra()  # {"pos": [x, y, z], "zone" | "interior": id}
	elif p:
		var v: Vector3 = p.save_position() if p.has_method("save_position") else p.global_position
		extra = {"pos": [v.x, v.y, v.z]}
	_msg("Jogo salvo." if game.save_game(extra) else "Não foi possível salvar.", "main")


func _use(m: Mon) -> void:
	var iname := Kit.item_name(_item)
	var text: String = game.use_item(_item, m)
	if text == "":
		text = "%s não teria efeito em %s." % [iname, m.display_name]
	if not game.bag.has(_item):
		_bag_cur = 0
		if _items().is_empty():
			var cats := _cats()
			_cat = cats[0] if not cats.is_empty() else _cat
	_msg(text, "bag")


func _usable_outside(id: String) -> bool:
	var fx: Dictionary = Dex.item(id).get("effect", {})
	for k in ["hp", "revive", "cure", "level", "teach", "evolve"]:
		if fx.has(k):
			return true
	return false


func _cat_of(id: String) -> String:
	var c := String(Dex.item(id).get("category", ""))
	for e in CATS:
		if e[0] == c:
			return c
	return "key"


## Categorias com pelo menos um item na bolsa, na ordem de CATS.
func _cats() -> Array:
	var out: Array = []
	for e in CATS:
		for id in game.bag:
			if int(game.bag[id]) > 0 and _cat_of(id) == e[0]:
				out.append(e[0])
				break
	return out


func _first_cat() -> String:
	var c := _cats()
	return c[0] if not c.is_empty() else "medicine"


func _items() -> Array:
	var out: Array = []
	for id in game.bag:
		if int(game.bag[id]) > 0 and _cat_of(id) == _cat:
			out.append(id)
	out.sort_custom(func(x, y): return Kit.item_name(x) < Kit.item_name(y))
	return out


# --- Pokédex ---


## Lista do nº 1 até o maior nº visto; espécies não vistas ficam como "-----".
func _build_dex() -> void:
	var by_no := {}
	var highest := 0
	for k in game.seen.keys() + game.caught.keys():
		var name := Dex.canon(String(k))
		var sp := Dex.species(name)
		var n := int(sp.get("dex_no", 0))
		if n <= 0:
			continue
		by_no[n] = name
		highest = maxi(highest, n)
	_dex = []
	for n in range(1, highest + 1):
		var s := String(by_no.get(n, ""))
		_dex.append({"no": n, "species": s, "caught": s != "" and _caught(s)})
	_dex_cur = 0
	for i in _dex.size():
		if String(_dex[i].species) != "":
			_dex_cur = i
			break


func _caught(species: String) -> bool:
	for k in game.caught:
		if Dex.canon(String(k)) == species:
			return true
	return false


func _dex_step(cur: int, d: int) -> int:
	if _dex.is_empty():
		return 0
	var i := cur
	for _n in _dex.size():
		i = wrapi(i + d, 0, _dex.size())
		if String(_dex[i].species) != "":
			return i
	return cur


func dex_counts() -> Vector2i:
	var s := {}
	var c := {}
	for k in game.seen:
		s[Dex.canon(String(k))] = true
	for k in game.caught:
		c[Dex.canon(String(k))] = true
		s[Dex.canon(String(k))] = true
	return Vector2i(s.size(), c.size())


func _area_names(species: String) -> Array:
	if _areas.is_empty():
		_areas["_loaded"] = []
		var dir := DirAccess.open("res://data/encounters")
		if dir:
			for f in dir.get_files():
				if not f.ends_with(".json"):
					continue
				var data = JSON.parse_string(
					FileAccess.get_file_as_string("res://data/encounters/" + f)
				)
				if not data is Dictionary:
					continue
				var area := String(data.get("area", f.get_basename()))
				for e in data.get("entries", []):
					var s := Dex.canon(String(e.get("species", "")))
					if s == "":
						continue
					if not _areas.has(s):
						_areas[s] = []
					if not _areas[s].has(area):
						_areas[s].append(area)
	return _areas.get(species, [])


func has_badge(id: String) -> bool:
	return bool(game.flags.get("badge_" + id, false)) or bool(game.flags.get(id + "_badge", false))


# --- Desenho (refeito a cada tecla) ---


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1152, 648)


func _add_win(title: String, pos: Vector2, size: Vector2, sep := 8) -> VBoxContainer:
	var w: Array = Kit.panel(title, size, sep)
	w[0].position = pos
	w[0].size = size
	_box.add_child(w[0])
	return w[1]


func _centered(title: String, size: Vector2, sep := 8) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(cc)
	var w: Array = Kit.panel(title, size, sep)
	cc.add_child(w[0])
	return w[1]


func _hints(text: String, pos: Vector2, right_edge := false) -> void:
	var h := Kit.hint(text)
	_box.add_child(h)
	h.reset_size()
	h.position = pos - Vector2(h.get_combined_minimum_size().x if right_edge else 0.0, 0)


func _dim(alpha := 0.45) -> void:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, alpha)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(d)


func _render() -> void:
	Kit.clear(_box)
	var s := screen
	if screen == "msg":
		s = _back_to
	elif screen == "ask":
		s = _ask_back
	match s:
		"main":
			_render_main()
		"party":
			_render_party("Escolha um Pokémon.", "↑/↓ escolhe · E confirma · Esc volta")
		"party_act":
			var m: Mon = game.party[_party_cur]
			var acts: Array = []
			for e in PARTY_ACTS:
				acts.append(e[1])
			_render_party(
				m.display_name.to_upper() + ("   ·   segue você" if _party_cur == 0 else ""),
				"↑/↓ escolhe · E confirma · Esc volta",
				acts,
				_act_cur,
				_act_note
			)
		"party_switch":
			_render_party(
				"Mover %s para onde?" % game.party[_switch_from].display_name,
				"↑/↓ escolhe · E troca · Esc volta",
				[],
				-1,
				"Escolha outro lugar e confirme para trocar. O lugar 1 é o da frente."
			)
		"party_item":
			var rows: Array = []
			for id in _party_items():
				rows.append("%s  ×%d" % [Kit.item_name(id), int(game.bag[id])])
			rows.append("CANCELAR")
			_render_party(
				"Usar em %s:" % game.party[_party_cur].display_name,
				"↑/↓ escolhe · E usa · Esc volta",
				rows,
				_pitem_cur,
				_pitem_note
			)
		"target":
			_render_party(
				"Usar %s em qual Pokémon?" % Kit.item_name(_item), "↑/↓ escolhe · E usa · Esc volta"
			)
		"summary":
			_render_summary()
		"bag", "toss":
			_render_bag()
		"dex":
			_render_dex()
		"dex_entry":
			_render_dex_entry()
		"card":
			_render_card()
		"options":
			_render_options()
		"controls":
			_render_controls()
	if screen == "msg":
		var vp := _vp()
		var d := Kit.Dialog.new()
		d.cps = 0.0
		d.position = Vector2(100, vp.y - 160)
		d.size = Vector2(vp.x - 200, 130)
		_box.add_child(d)
		d.show_line("", message, true)
	elif screen == "ask":
		var vp := _vp()
		var d := Kit.Dialog.new()
		d.cps = 0.0
		d.position = Vector2(100, vp.y - 160)
		d.size = Vector2(vp.x - 200, 130)
		_box.add_child(d)
		d.show_line("", _ask_text, true)
		var col := _add_win("", Vector2(vp.x - 290, vp.y - 290), Vector2(170, 0), 2)
		col.add_child(Kit.row(["SIM"], [110], _ask_yes))
		col.add_child(Kit.row(["NÃO"], [110], not _ask_yes))


func _render_main() -> void:
	var vp := _vp()
	var ents := entries()
	var col := _add_win("", Vector2(vp.x - 284, 20), Vector2(264, 0), 2)
	for i in ents.size():
		var off: bool = ents[i] == "picnic" and not can_picnic()  # "disabled" do original
		col.add_child(Kit.row([_entry_label(ents[i])], [], i == _main_cur, off))
	var money := Kit.label(
		"Dinheiro  " + Kit.format_money(int(game.money)), Kit.GREEN, Kit.SIZE_SMALL
	)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(money)
	if screen == "main":
		_hints("↑/↓ escolhe · E confirma · Esc fecha", Vector2(vp.x - 24, vp.y - 48), true)


func _render_party(
	context: String, hint: String, list: Array = [], list_cur := -1, note := ""
) -> void:
	var vp := _vp()
	_dim(0.3)
	var pw := minf(640.0, vp.x - 520.0)
	var col := _add_win("POKéMON", Vector2(24, 26), Vector2(pw, vp.y - 52), 2)
	if game.party.is_empty():
		col.add_child(Kit.label("Nenhum Pokémon.", Kit.DIM))
	var rh := clampf((vp.y - 110.0) / 6.0, 60.0, 88.0)
	for i in game.party.size():
		var r := Kit.PartyRow.new(game.party[i], rh)
		r.selected = i == _party_cur
		r.source = screen == "party_switch" and i == _switch_from
		if screen == "target" or (screen == "msg" and _back_to == "target"):
			r.note = "" if Items.can_use(_item, game.party[i]) else "sem efeito"
		col.add_child(r)
	var side := _add_win("", Vector2(pw + 48, 26), Vector2(vp.x - pw - 72, 0), 10)
	var c := Kit.label(context, Kit.BLUE, Kit.SIZE_SMALL)
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(c)
	if not list.is_empty():
		var lv := VBoxContainer.new()
		lv.add_theme_constant_override("separation", 2)
		for i in list.size():
			lv.add_child(Kit.row([String(list[i])], [280], i == list_cur))
		side.add_child(lv)
	if note != "":
		var nl := Kit.label(note, Kit.INK, Kit.SIZE_SMALL)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(nl)
	if not game.party.is_empty():
		var m: Mon = game.party[clampi(_party_cur, 0, game.party.size() - 1)]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(Kit.sprite_rect(Kit.mon_front(m.species), Vector2(110, 110)))
		var info := VBoxContainer.new()
		info.add_child(Kit.header(m.display_name.to_upper(), Kit.INK, 24))
		info.add_child(
			Kit.label(
				(
					"Nv %d · %s"
					% [
						m.level,
						" / ".join(PackedStringArray(m.types.map(func(t): return Kit.type_name(t))))
					]
				),
				Kit.DIM,
				Kit.SIZE_SMALL
			)
		)
		info.add_child(Kit.label("HP %d / %d" % [m.hp, m.max_hp], Kit.hp_color(m), Kit.SIZE_SMALL))
		top.add_child(info)
		side.add_child(top)
	_hints(hint, Vector2(pw + 48, vp.y - 60))


func _render_summary() -> void:
	var vp := _vp()
	_dim()
	var size := Vector2(minf(840.0, vp.x - 40.0), minf(590.0, vp.y - 40.0))
	var root := _centered("POKéMON", size, 10)
	var m: Mon = game.party[_party_cur]
	var sp := Dex.species(m.species)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Kit.pill(Color("eef2f8"), Kit.RIM, 10))
	frame.add_child(Kit.sprite_rect(Kit.mon_front(m.species), Vector2(150, 150)))
	top.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	top.add_child(col)
	col.add_child(Kit.header("%s     Nv %d" % [m.display_name, m.level]))
	var tabs: Array = []
	for i in SUMMARY_PAGES.size():
		tabs.append(
			("▶ %s" % SUMMARY_PAGES[i]) if i == summary_page else ("   %s" % SUMMARY_PAGES[i])
		)
	col.add_child(Kit.label("      ".join(PackedStringArray(tabs)), Kit.BLUE, Kit.SIZE_SMALL))
	var types := HBoxContainer.new()
	types.add_theme_constant_override("separation", 6)
	for t in m.types:
		types.add_child(Kit.tag(Kit.type_name(t), Kit.type_col(t)))
	var st := Kit.status_text(m)
	if st != "":
		types.add_child(Kit.tag(st, Kit.STATUS_TAGS.get(Kit.status_key(m), ["", Kit.DIM])[1]))
	col.add_child(types)
	var hp_line := HBoxContainer.new()
	hp_line.add_theme_constant_override("separation", 10)
	hp_line.add_child(Kit.label("HP", Kit.BLUE))
	var hb := Kit.progress(m.hp, m.max_hp, Kit.hp_color(m))
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_line.add_child(hb)
	hp_line.add_child(Kit.label("%d / %d" % [m.hp, m.max_hp]))
	col.add_child(hp_line)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)
	match summary_page:
		0:
			_summary_info(body, m, sp)
		1:
			_summary_skills(body, m, sp)
		_:
			_summary_moves(body, m)
	var hint := "←/→ página · ↑/↓ Pokémon (%d/%d) · Esc volta" % [_party_cur + 1, game.party.size()]
	if summary_page == 2:
		hint = (
			"↑/↓ escolhe · E %s · ←/→ página · Esc volta"
			% ("solta" if _move_held >= 0 else "segura para trocar")
		)
	root.add_child(Kit.hint(hint))


func _summary_info(body: VBoxContainer, m: Mon, sp: Dictionary) -> void:
	var card: Array = Kit.panel("FICHA DO TREINADOR")
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(card[0])
	var ab := Dex.ability(m.ability)
	var types: Array = []
	for t in m.types:
		types.append(Kit.type_name(t).to_upper())
	var rows := [
		["Nº", "%03d" % int(sp.get("dex_no", 0))],
		["TIPO", " / ".join(PackedStringArray(types)) if not types.is_empty() else "—"],
		["TREINADOR", String(game.player_name)],
		["Nº ID", trainer_id_text()],
		["NATUREZA", Kit.nature_text(m.nature)],
		["Humor", mood_text(int(m.friend))],
		["HABILIDADE", String(ab.get("name", m.ability.capitalize())) if m.ability != "" else "—"],
		["ENCONTRO", met_text(m)],
		["ITEM", "Nenhum"],
	]
	card[1].add_child(Kit.info_grid(rows))


## Nº ID do treinador (Game.trainer_id); o hash do nome só para save antigo sem o número.
func trainer_id_text() -> String:
	var id := int(game.get("trainer_id")) if game.get("trainer_id") != null else 0
	if id <= 0:
		id = absi(String(game.player_name).hash()) % 100000
	return "%05d" % id


static func mood_text(friend: int) -> String:
	for b in MOODS:
		if friend < int(b[0]):
			return String(b[1])
	return String(MOODS[-1][1])


## "Nv 5 em ROTA 1" (Mon.met_level / met_zone, quando o Mon guardar; senão "—").
static func met_text(m: Mon) -> String:
	var zone = m.get("met_zone")
	if zone == null or String(zone) == "":
		return "—"
	var lv := int(m.get("met_level")) if m.get("met_level") != null else 0
	return ("Nv %d em %s" % [lv, zone]) if lv > 0 else ("Em %s" % zone)


func _summary_skills(body: VBoxContainer, m: Mon, sp: Dictionary) -> void:
	var base: Dictionary = sp.get("base", {})
	var n: Array = StatCalc.NATURES.get(m.nature, [])
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 0)
	body.add_child(grid)
	for h in ["ATRIBUTO", "BASE", "IV", "EV", "VALOR"]:
		var l := Kit.label(h, Kit.DIM, Kit.SIZE_SMALL)
		l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		grid.add_child(l)
	for s in StatCalc.STATS:
		var mark := ""
		var c := Kit.BLUE
		if not n.is_empty() and n[0] == s:
			mark = "  ↑"
			c = Kit.RED
		elif not n.is_empty() and n[1] == s:
			mark = "  ↓"
		var name := Kit.label(Kit.STATS[s] + mark, c)
		name.custom_minimum_size.x = 160
		grid.add_child(name)
		grid.add_child(Kit.label(str(int(base.get(s, 0)))))
		var iv := int(m.ivs.get(s, 0))
		grid.add_child(Kit.label(str(iv), Kit.AMBER if iv >= 31 else Kit.INK))
		grid.add_child(Kit.label(str(int(m.evs.get(s, 0))), Kit.GREEN))
		grid.add_child(Kit.label(str(m.stat(s)), Kit.INK, 22))
	var exp_head := HBoxContainer.new()
	exp_head.add_theme_constant_override("separation", 10)
	body.add_child(exp_head)
	exp_head.add_child(Kit.label("EXP", Kit.BLUE))
	var span := maxi(m.exp_next_level - m.exp_this_level, 1)
	var eb := Kit.progress(clampi(m.xp - m.exp_this_level, 0, span), span, Kit.PP_BLUE)
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_head.add_child(eb)
	exp_head.add_child(
		Kit.label(
			(
				"nível máximo"
				if m.level >= Growth.MAX_LEVEL
				else "%d XP para o Nv %d" % [maxi(m.exp_next_level - m.xp, 0), m.level + 1]
			),
			Kit.DIM,
			Kit.SIZE_SMALL
		)
	)


func _summary_moves(body: VBoxContainer, m: Mon) -> void:
	if m.moves.is_empty():
		body.add_child(Kit.label("Nenhum golpe.", Kit.DIM))
		return
	_move_cur = clampi(_move_cur, 0, m.moves.size() - 1)
	for i in m.moves.size():
		var id: String = m.moves[i]
		var mv := Dex.move(id)
		var t := String(mv.get("type", "normal"))
		var p := PanelContainer.new()
		var on := i == _move_cur
		var sb := Kit.pill(
			Kit.RED_SOFT if on else Color("f0f1ea"),
			Kit.GREEN if i == _move_held else (Kit.RED if on else Kit.RIM),
			8
		)
		sb.set_content_margin_all(6)
		sb.content_margin_left = 12
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var cur := Kit.label("▶" if on else "  ", Kit.RED)
		cur.custom_minimum_size.x = 16
		h.add_child(cur)
		var nm := Kit.label(Kit.move_name(id))
		nm.custom_minimum_size.x = 180
		h.add_child(nm)
		var tg := Kit.tag(Kit.type_name(t), Kit.type_col(t))
		tg.custom_minimum_size.x = 96
		h.add_child(tg)
		var power := int(mv.get("power", 0))
		var acc := int(mv.get("accuracy", 0))
		var kind := String(mv.get("kind", ""))
		for kv in [
			["PP", "%d" % int(round(Dex.pp_cost(mv))), Kit.PP_BLUE],
			["PODER", str(power) if power > 0 else "—", Kit.INK],
			["PREC.", ("%d%%" % acc) if mv.has("accuracy") else "—", Kit.INK],
			["RECARGA", "%.1fs" % Dex.cooldown(mv), Kit.INK],
			["", String(KINDS.get(kind, kind.replace("_", " "))), Kit.DIM]
		]:
			var l := Kit.label(("%s %s" % [kv[0], kv[1]]).strip_edges(), kv[2], Kit.SIZE_SMALL)
			l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			h.add_child(l)
		var desc := String(mv.get("desc", mv.get("description", "")))
		if desc != "":
			var d := Kit.label(desc, Kit.DIM, 14)
			d.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			d.clip_text = true
			v.add_child(d)
		body.add_child(p)


func _render_bag() -> void:
	var vp := _vp()
	_dim(0.3)
	var size := Vector2(minf(680.0, vp.x - 40.0), minf(560.0, vp.y - 90.0))
	var pos := Vector2((vp.x - size.x) * 0.5, 34).floor()
	var v := _add_win("BOLSA", pos, size, 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(Kit.label("DINHEIRO", Kit.DIM, Kit.SIZE_SMALL))
	head.add_child(Kit.label(Kit.format_money(int(game.money)), Kit.GREEN, 22))
	var cats := _cats()
	if cats.is_empty():
		var e := Kit.label("A bolsa está vazia.", Kit.DIM)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(e)
		_hints("Esc volta", Vector2(pos.x, pos.y + size.y + 10))
		return
	if not cats.has(_cat):
		_cat = cats[0]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for e in CATS:
		if cats.has(e[0]):
			var on: bool = e[0] == _cat
			var p := PanelContainer.new()
			var sb := Kit.pill(
				Kit.RED_SOFT if on else Color(Kit.INK, 0.0),
				Kit.RED if on else Color.TRANSPARENT,
				10
			)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			p.add_theme_stylebox_override("panel", sb)
			var l := Kit.label(e[1], Kit.INK if on else Kit.DIM, 16)
			l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			p.add_child(l)
			tabs.add_child(p)
	v.add_child(tabs)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	var items := _items()
	var first := clampi(_bag_cur - 6, 0, maxi(items.size() - 8, 0))
	var ball := String(game.flags.get("selected_ball", ""))
	for i in range(first, mini(items.size(), first + 8)):
		var id: String = items[i]
		var tag := "   [Q]" if id == ball else ""
		list.add_child(
			Kit.row(
				[
					Kit.ItemIcon.new(id, 30),
					Kit.item_name(id),
					["×%d%s" % [int(game.bag[id]), tag], Kit.DIM]
				],
				[30, 380],
				i == _bag_cur
			)
		)
	var desc_box := PanelContainer.new()
	var sb2 := Kit.pill(Kit.PAPER, Kit.RIM, 8)
	sb2.set_border_width_all(2)
	sb2.content_margin_left = 14
	sb2.content_margin_right = 14
	sb2.content_margin_top = 6
	sb2.content_margin_bottom = 6
	desc_box.add_theme_stylebox_override("panel", sb2)
	desc_box.custom_minimum_size = Vector2(0, 62)
	var sel_id: String = (
		items[clampi(_bag_cur, 0, items.size() - 1)] if not items.is_empty() else ""
	)
	var tossing := screen == "toss" and sel_id != ""
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 2)
	desc_box.add_child(dv)
	var d := Kit.label(
		(
			("Jogar fora %s?" % Kit.item_name(sel_id))
			if tossing
			else String(Dex.item(sel_id).get("description", "")) if sel_id != "" else ""
		),
		Kit.INK,
		Kit.SIZE_SMALL
	)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(d)
	if _bag_note != "":
		var nl := Kit.label(_bag_note, Kit.AMBER, Kit.SIZE_SMALL)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dv.add_child(nl)
	v.add_child(desc_box)
	if tossing:
		var tv := _add_win(
			"JOGAR FORA", Vector2(pos.x + size.x - 256, pos.y + size.y - 196), Vector2(236, 96), 4
		)
		tv.add_child(Kit.label("Jogar fora quantos?", Kit.INK, Kit.SIZE_SMALL))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(Kit.label("▲▼", Kit.INK, 14))
		row.add_child(Kit.ItemIcon.new(sel_id, 30))
		row.add_child(Kit.label("× %d" % _toss_qty, Kit.INK, 26))
		tv.add_child(row)
		_hints("↑/↓ quantidade · E joga fora · Esc cancela", Vector2(pos.x, pos.y + size.y + 10))
		return
	_hints(
		"←/→ categoria · ↑/↓ item · E usa · Z joga fora · Esc volta",
		Vector2(pos.x, pos.y + size.y + 10)
	)


func _render_dex() -> void:
	var vp := _vp()
	_dim()
	var size := Vector2(minf(720.0, vp.x - 40.0), minf(580.0, vp.y - 40.0))
	var v := _centered("POKéDEX", size, 8)
	var c := dex_counts()
	v.add_child(Kit.label("VISTOS %d  ·  CAPTURADOS %d" % [c.x, c.y], Kit.INK, 20))
	if _dex.is_empty():
		var e := Kit.label("Nenhum Pokémon registrado ainda.", Kit.DIM)
		e.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(e)
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(list)
		var first := clampi(_dex_cur - DEX_ROWS / 2, 0, maxi(_dex.size() - DEX_ROWS, 0))
		for i in range(first, mini(_dex.size(), first + DEX_ROWS)):
			var e: Dictionary = _dex[i]
			var sp := String(e.species)
			var mark := Control.new()
			mark.custom_minimum_size = Vector2(22, 22)
			if e.caught:
				mark = Kit.ItemIcon.new("poke_ball", 22)
			var ic := Kit.sprite_rect(
				Kit.mon_front(sp) if sp != "" else null, Vector2(30, 30), sp != "" and not e.caught
			)
			var nm := [
				sp if sp != "" else "-----",
				Kit.RED if i == _dex_cur else (Kit.INK if sp != "" else Kit.DIM)
			]
			list.add_child(
				Kit.row([["%03d" % int(e.no), Kit.DIM], mark, ic, nm], [50, 22, 30], i == _dex_cur)
			)
	v.add_child(Kit.hint("↑/↓ move · E abre · Esc fecha"))


func _render_dex_entry() -> void:
	var vp := _vp()
	_dim()
	var size := Vector2(minf(780.0, vp.x - 40.0), minf(560.0, vp.y - 40.0))
	var v := _centered("POKéDEX", size, 12)
	var e: Dictionary = _dex[_dex_cur]
	var sp_name := String(e.species)
	var sp := Dex.species(sp_name)
	var caught: bool = e.caught
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	v.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Kit.pill(Color("eef2f8"), Kit.RIM, 10))
	frame.add_child(Kit.sprite_rect(Kit.mon_front(sp_name), Vector2(210, 210), not caught))
	top.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)
	info.add_child(Kit.label("Nº %03d" % int(sp.get("dex_no", 0)), Kit.BLUE, 18))
	info.add_child(Kit.header(sp_name.to_upper(), Kit.INK, 30))
	info.add_child(
		Kit.label(String(sp.get("category", "")).replace("Pokémon", "Pokémon"), Kit.INK, 18)
	)
	if caught:
		var types := HBoxContainer.new()
		types.add_theme_constant_override("separation", 8)
		for t in sp.get("types", []):
			types.add_child(Kit.tag(Kit.type_name(String(t)), Kit.type_col(String(t))))
		info.add_child(types)
	info.add_child(
		Kit.label(
			"ALTURA   %s m" % (("%.1f" % float(sp.get("height_m", 0.0))) if caught else "??"),
			Kit.INK,
			18
		)
	)
	info.add_child(
		Kit.label(
			"PESO     %s kg" % (("%.1f" % float(sp.get("weight_kg", 0.0))) if caught else "??"),
			Kit.INK,
			18
		)
	)
	info.add_child(
		Kit.label(
			"CAPTURADO" if caught else "SÓ VISTO", Kit.GREEN if caught else Kit.DIM, Kit.SIZE_SMALL
		)
	)
	var fl := Kit.label(
		(
			String(sp.get("flavor", ""))
			if caught
			else "Capture este Pokémon para ver os dados completos."
		),
		Kit.INK if caught else Kit.DIM,
		18
	)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(0, 60)
	v.add_child(fl)
	var areas := _area_names(sp_name)
	var ar := Kit.label(
		(
			"ÁREA   %s"
			% ("  ·  ".join(PackedStringArray(areas)) if not areas.is_empty() else "Desconhecida")
		),
		Kit.INK,
		16
	)
	ar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ar)
	v.add_child(Kit.hint("↑/↓ anterior/próximo · Esc volta"))


## Insígnia: textura do original quando existir; senão o octógono desenhado (cinza se não ganha).
class BadgeSlot:
	extends Control
	var badge_id := ""
	var earned := false
	var col := Color.GRAY
	var _t := 0.0

	func _process(dt: float) -> void:
		if earned:
			_t += dt
			queue_redraw()

	func _draw() -> void:
		var K = preload("res://ui/ui_kit.gd")
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		var tex: Texture2D = K.badge_texture(badge_id)
		if tex:
			draw_texture_rect(
				tex,
				Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0),
				false,
				Color.WHITE if earned else Color(0.2, 0.22, 0.26, 0.5)
			)
		else:
			var pts := _ring(c, r)
			if earned:
				draw_colored_polygon(pts, col)
				draw_colored_polygon(_ring(c, r * 0.62), col.lightened(0.35))
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, K.INK if earned else K.DIM, 3.0, true)
		if earned:
			var s := r * (0.2 + 0.05 * sin(_t * 3.0))
			var p := c + Vector2(r * 0.42, -r * 0.42)
			draw_colored_polygon(
				PackedVector2Array(
					[
						p + Vector2(0, -s * 2),
						p + Vector2(s * 0.5, -s * 0.5),
						p + Vector2(s * 2, 0),
						p + Vector2(s * 0.5, s * 0.5),
						p + Vector2(0, s * 2),
						p + Vector2(-s * 0.5, s * 0.5),
						p + Vector2(-s * 2, 0),
						p + Vector2(-s * 0.5, -s * 0.5)
					]
				),
				Color(1, 1, 1, 0.85)
			)

	func _ring(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 8:
			var a := PI / 8.0 + TAU * float(i) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts


func _render_card() -> void:
	_dim()
	var v := _centered("CARTÃO DE TREINADOR", Vector2(560, 0), 12)
	if card_front:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 22)
		v.add_child(h)
		var frame := PanelContainer.new()
		var fsb := Kit.pill(Kit.RED_SOFT, Kit.INK, 8)
		fsb.set_content_margin_all(10)
		frame.add_theme_stylebox_override("panel", fsb)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var green := String(game.player_gender) == "female"
		frame.add_child(
			Kit.sprite_rect(
				Kit.sheet_frame(PORTRAIT_GREEN if green else PORTRAIT, PORTRAIT_FRAME),
				Vector2(96, 120)
			)
		)
		h.add_child(frame)
		var rows := [
			["NOME", String(game.player_name)],
			["RIVAL", String(game.rival_name)],
			["Nº ID", trainer_id_text()],
			["DINHEIRO", Kit.money_text(int(game.money))]
		]
		if game.flags.get("has_pokedex", false):
			rows.append(["POKéDEX", "%d capturados" % dex_counts().y])
		rows.append(["TEMPO DE JOGO", Kit.format_time(float(game.play_time))])
		var started := format_started(int(game.flags.get("started_at", 0)))
		if started != "":
			rows.append(["INÍCIO", started])
		var g := Kit.info_grid(rows)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(g)
	else:
		var head := Kit.header("INSÍGNIAS DE KANTO")
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 30)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		for b in BADGES:
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 0)
			var slot := BadgeSlot.new()
			slot.badge_id = b[0]
			slot.earned = has_badge(b[0])
			slot.col = Color(b[2])
			slot.custom_minimum_size = Vector2(80, 72)
			cv.add_child(slot)
			var l := Kit.label(b[1], Kit.INK if slot.earned else Kit.DIM, 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(l)
			grid.add_child(cv)
	v.add_child(Kit.hint("←/→ vira o cartão · Esc volta"))


## "23 OUT 2026" (GameState.format_started do original); "" sem data.
static func format_started(ts: int) -> String:
	if ts <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(ts)
	return "%d %s %d" % [d.day, MONTHS[d.month - 1], d.year]


func _render_options() -> void:
	_dim()
	var v := _centered("OPÇÕES", Vector2(620, 0), 6)
	Kit.option_rows(v, _settings, _opt_cur)
	v.add_child(Kit.hint("↑/↓ escolhe · ←/→ muda · E abre · Esc volta"))


func _render_controls() -> void:
	_dim()
	var vp := _vp()
	var v := _centered("CONTROLES", Vector2(minf(900.0, vp.x - 40.0), 0), 10)
	controls_into(v)


## Tabela de teclas (controls_screen do original); o título usa a mesma.
static func controls_into(v: VBoxContainer) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	v.add_child(cols)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for c in [left, right]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 4)
		cols.add_child(c)
	for i in CONTROLS.size():
		var sec: Array = CONTROLS[i]
		var box := left if i != 1 else right
		box.add_child(Kit.header(sec[0], Kit.BLUE, 20))
		for r in sec[1]:
			var h := HBoxContainer.new()
			var l := Kit.label(r[0])
			l.custom_minimum_size.x = 190
			h.add_child(l)
			for k in String(r[1]).split("/"):
				h.add_child(Kit.KeyCap.new(k))
			box.add_child(h)
	v.add_child(Kit.hint("Esc volta"))
