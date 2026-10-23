extends CanvasLayer
## Tela de esquecer golpe (autoload LearnMove). Resolve Game.pending_learns inteira, um por vez.
## Teclado: cima/baixo escolhe, E/Enter confirma, Esc/Q desiste (pede confirmação).

const Kit := preload("res://ui/ui_kit.gd")
const WIDTHS := [200, 110, 100, 60, 60]

## Instância do Game. Vazio = autoload /root/Game procurado no _ready (testes injetam antes).
var game: Node = null
## "" fechado | "pick" escolhendo | "confirm" desistir? | "msg" mensagem final
var state := ""
var cursor := 0
var message := ""

var _root: Control
var _box: VBoxContainer
var _yes := false
var _closed_at := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game == null:
		game = get_node_or_null("/root/Game")
	if game:
		game.learn_requested.connect(_on_learn_requested)
	var w := Kit.window(self, Vector2(760, 0), "NOVO GOLPE")
	_root = w[0]
	_box = w[1]
	_root.visible = false


## Verdadeiro também no frame em que fechou, para a tecla de confirmar não vazar para o overworld.
func is_open() -> bool:
	return state != "" or Engine.get_process_frames() == _closed_at


func _on_learn_requested() -> void:
	_try_open()


## Pega a fila sozinho também (ex.: algo chamou queue_learn sem emitir o sinal).
func _process(_dt: float) -> void:
	if state == "" and game and not game.pending_learns.is_empty():
		_try_open()


func _try_open() -> void:
	if state != "" or game == null or game.pending_learns.is_empty() or game.is_busy() or _evolving():
		return
	_root.visible = true
	_begin()


## Espera a tela de evolução (autoload Evolution) terminar a fila antes de abrir.
func _evolving() -> bool:
	var evo := get_node_or_null("/root/Evolution")
	return not game.pending_evolutions.is_empty() or (evo != null and evo.is_open())


func _begin() -> void:
	state = "pick"
	cursor = 0
	_render()


func _current() -> Dictionary:
	return game.pending_learns[0]


func _input(ev: InputEvent) -> void:
	if state == "":
		return
	var a := Kit.nav(ev)
	if a == "":
		return
	get_viewport().set_input_as_handled()
	press(a)


## Aplica uma ação de navegação ("up" "down" "left" "right" "ok" "back"). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	preload("res://audio/cue.gd").ui(a)
	match state:
		"pick":
			var n: int = _current().mon.moves.size() + 1
			if a == "up":
				cursor = posmod(cursor - 1, n)
			elif a == "down":
				cursor = posmod(cursor + 1, n)
			elif a == "ok":
				if cursor < n - 1:
					_forget(cursor)
				else:
					_ask_give_up()
			elif a == "back":
				_ask_give_up()
		"confirm":
			if a in ["up", "down", "left", "right"]:
				_yes = not _yes
			elif a == "back" or (a == "ok" and not _yes):
				state = "pick"
			elif a == "ok":
				var p := _current()
				message = "%s não aprendeu %s." % [p.mon.display_name, Kit.move_name(p.move)]
				game.resolve_learn(-1)
				state = "msg"
		"msg":
			if a in ["ok", "back"]:
				if game.pending_learns.is_empty():
					_close()
				else:
					_begin()
				return
	_render()


func _forget(slot: int) -> void:
	var p := _current()
	var old: String = p.mon.moves[slot]
	message = "1, 2 e... Pronto! %s esqueceu %s e aprendeu %s!" % [p.mon.display_name, Kit.move_name(old), Kit.move_name(p.move)]
	game.resolve_learn(slot)
	state = "msg"


func _ask_give_up() -> void:
	_yes = false
	state = "confirm"


func _close() -> void:
	state = ""
	_closed_at = Engine.get_process_frames()
	message = ""
	_root.visible = false
	Kit.clear(_box)


func _render() -> void:
	Kit.clear(_box)
	if state == "msg":
		var l := Kit.label(message)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(0, 70)
		_box.add_child(l)
		_box.add_child(Kit.hint("E/Enter continuar"))
		return
	var p := _current()
	var m: Mon = p.mon
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.add_child(Kit.sprite_rect(Kit.party_icon(m.species), Vector2(72, 72)))
	var tc := VBoxContainer.new()
	tc.add_theme_constant_override("separation", 0)
	tc.add_child(Kit.label("%s  Nv %d" % [m.display_name, m.level], Kit.DIM, 15))
	tc.add_child(Kit.label("%s quer aprender %s." % [m.display_name, Kit.move_name(p.move)], Kit.TEXT, 22))
	tc.add_child(Kit.label("Mas já sabe 4 golpes. Qual golpe esquecer?" if state == "pick" else "", Kit.DIM))
	top.add_child(tc)
	_box.add_child(top)
	_box.add_child(Kit.row(["Golpe", "Tipo", "Categoria", "Poder", "Prec."], WIDTHS, false, true))
	for i in m.moves.size():
		_box.add_child(Kit.row(Kit.move_cols(m.moves[i]), WIDTHS, state == "pick" and cursor == i))
	var sep := HSeparator.new()
	_box.add_child(sep)
	var new_cols := Kit.move_cols(p.move)
	new_cols[0] = [new_cols[0] + "  (novo)", Kit.ACCENT]
	_box.add_child(Kit.row(new_cols, WIDTHS, state == "pick" and cursor == m.moves.size()))
	if state == "confirm":
		_box.add_child(Kit.label("Desistir de aprender %s?" % Kit.move_name(p.move), Kit.SEL))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.add_child(Kit.row(["Sim"], [80], _yes))
		h.add_child(Kit.row(["Não"], [80], not _yes))
		_box.add_child(h)
		_box.add_child(Kit.hint("←/→ escolhe · E/Enter confirma · Esc volta"))
	else:
		_box.add_child(Kit.hint("↑/↓ escolhe · E/Enter esquece o golpe marcado · Esc desiste"))
