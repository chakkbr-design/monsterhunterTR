extends CanvasLayer
## Tela de aprender golpe com 4 golpes (autoload LearnMove), no roteiro do progression._teach do original:
## "X está tentando aprender Y." / "Mas X não pode aprender mais de quatro golpes." / "Apagar um golpe
## para dar lugar a Y?" SIM/NÃO / lista para esquecer / "Parar de aprender Y?" e, no fim, "1, 2 e… … … Puf!",
## "X esqueceu Z.", "E…", "X aprendeu Y!". Resolve Game.pending_learns inteira, um por vez.
## Teclado: cima/baixo escolhe, E/Enter confirma, Esc/Q volta.

const Kit := preload("res://ui/ui_kit.gd")
const WIDTHS := [200, 110, 100, 60, 60]

## Instância do Game. Vazio = autoload /root/Game procurado no _ready (testes injetam antes).
var game: Node = null
## "" fechado | "talk" falas (E avança) | "ask" pergunta SIM/NÃO | "pick" escolhendo o golpe
var state := ""
var cursor := 0
## Fala mostrada agora (state "talk") ou a pergunta (state "ask").
var message := ""
## Qual pergunta está aberta: "delete" (apagar um golpe?) ou "stop" (parar de aprender?).
var question := ""

var _root: Control
var _box: VBoxContainer
var _yes := true
var _closed_at := -1
var _lines: Array = []
var _then: Callable


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
	if (
		state != ""
		or game == null
		or game.pending_learns.is_empty()
		or game.is_busy()
		or _evolving()
	):
		return
	_root.visible = true
	_begin()


## Espera a tela de evolução (autoload Evolution) terminar a fila antes de abrir.
func _evolving() -> bool:
	var evo := get_node_or_null("/root/Evolution")
	return not game.pending_evolutions.is_empty() or (evo != null and evo.is_open())


func _begin() -> void:
	cursor = 0
	var p := _current()
	var mon: String = p.mon.display_name
	_talk(
		[
			"%s está tentando aprender %s." % [mon, Kit.move_name(p.move)],
			"Mas %s não pode aprender mais de quatro golpes." % mon
		],
		_ask.bind("delete")
	)


func _current() -> Dictionary:
	return game.pending_learns[0]


func _talk(lines: Array, then: Callable) -> void:
	_lines = lines
	_then = then
	state = "talk"
	message = String(_lines.pop_front())
	_render()


func _ask(which: String) -> void:
	question = which
	var mv := Kit.move_name(_current().move)
	message = (
		("Apagar um golpe para dar lugar a %s?" % mv)
		if which == "delete"
		else ("Parar de aprender %s?" % mv)
	)
	_yes = true
	state = "ask"
	_render()


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
		"talk":
			if a in ["ok", "back"]:
				if not _lines.is_empty():
					message = String(_lines.pop_front())
				else:
					_then.call()
					return
		"ask":
			if a in ["up", "down", "left", "right"]:
				_yes = not _yes
			elif a in ["ok", "back"]:
				var yes := _yes and a == "ok"
				if question == "delete":
					if yes:
						state = "pick"
						cursor = 0
					else:
						_ask("stop")
						return
				else:
					if yes:
						_give_up()
					else:
						_ask("delete")
					return
		"pick":
			var n: int = _current().mon.moves.size() + 1
			if a == "up":
				cursor = posmod(cursor - 1, n)
			elif a == "down":
				cursor = posmod(cursor + 1, n)
			elif a == "ok" and cursor < n - 1:
				_forget(cursor)
				return
			elif a in ["ok", "back"]:
				_ask("stop")
				return
	_render()


func _next() -> void:
	if game.pending_learns.is_empty():
		_close()
	else:
		_begin()


func _forget(slot: int) -> void:
	var p := _current()
	var mon: String = p.mon.display_name
	var old: String = p.mon.moves[slot]
	var mv := Kit.move_name(p.move)
	game.resolve_learn(slot)
	var au := get_node_or_null("/root/Audio")
	if au and au.has_method("has_sfx") and au.has_sfx("level_up"):
		au.sfx("level_up")
	_talk(
		[
			"1, 2 e… … … Puf!",
			"%s esqueceu %s." % [mon, Kit.move_name(old)],
			"E…",
			"%s aprendeu %s!" % [mon, mv]
		],
		_next
	)


func _give_up() -> void:
	var p := _current()
	var text := "%s não aprendeu %s." % [p.mon.display_name, Kit.move_name(p.move)]
	game.resolve_learn(-1)
	_talk([text], _next)


func _close() -> void:
	state = ""
	_closed_at = Engine.get_process_frames()
	message = ""
	question = ""
	_root.visible = false
	Kit.clear(_box)


func _render() -> void:
	Kit.clear(_box)
	if state == "talk" or state == "ask":
		var l := Kit.label(message, Kit.TEXT, 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(0, 70)
		_box.add_child(l)
		if state == "ask":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			h.add_child(Kit.row(["SIM"], [80], _yes))
			h.add_child(Kit.row(["NÃO"], [80], not _yes))
			_box.add_child(h)
			_box.add_child(Kit.hint("←/→ escolhe · E/Enter confirma"))
		else:
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
	tc.add_child(Kit.label("Qual golpe deve ser esquecido?", Kit.TEXT, 22))
	top.add_child(tc)
	_box.add_child(top)
	_box.add_child(Kit.row(["Golpe", "Tipo", "Categoria", "Poder", "Prec."], WIDTHS, false, true))
	for i in m.moves.size():
		_box.add_child(Kit.row(Kit.move_cols(m.moves[i]), WIDTHS, cursor == i))
	var sep := HSeparator.new()
	_box.add_child(sep)
	var new_cols := Kit.move_cols(p.move)
	new_cols[0] = [new_cols[0] + "  · NOVO", Kit.ACCENT]
	_box.add_child(Kit.row(new_cols, WIDTHS, cursor == m.moves.size()))
	_box.add_child(Kit.hint("↑/↓ escolhe · E/Enter esquece o golpe marcado · Esc volta"))
