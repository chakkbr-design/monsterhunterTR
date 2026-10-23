extends PanelContainer
## Entrada de nome com teclado na tela (setas/controle) e digitação pelo teclado físico.
## ask(título, sugestões) mostra; emite done(nome) ou cancelled.
## A tela dona repassa os eventos com handle(ev) (as letras WASD/E/Q aqui digitam, não navegam).

signal done(text: String)
signal cancelled

const Kit := preload("res://ui/ui_kit.gd")
const MAX_LEN := 10
const ROWS := [
	["A", "B", "C", "D", "E", "F", "G", "H", "I"],
	["J", "K", "L", "M", "N", "O", "P", "Q", "R"],
	["S", "T", "U", "V", "W", "X", "Y", "Z", "-"],
	["Á", "É", "Í", "Ó", "Ú", "Ã", "Õ", "Ç", "Ê"],
	["Aa", "Espaço", "Sugerir", "Apagar", "OK"],
]
const SPECIAL := ["Aa", "Espaço", "Sugerir", "Apagar", "OK"]

var value := ""
var row := 0
var col := 0
var caps := true
var suggestions: Array = []
var _sug := -1

var _title: Label
var _value_label: Label
var _count: Label
var _grid: VBoxContainer


func _ready() -> void:
	theme = Kit.theme()
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = Kit.label("", Kit.ACCENT, 20)
	v.add_child(_title)
	var line := HBoxContainer.new()
	v.add_child(line)
	_value_label = Kit.label("", Kit.SEL, 34)
	_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_value_label)
	_count = Kit.label("", Kit.DIM, 16)
	line.add_child(_count)
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 4)
	v.add_child(_grid)
	var h := Kit.hint("Digite ou use as setas · Enter escolhe · Backspace apaga · Esc volta")
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	visible = false


func ask(title_text: String, sugg: Array) -> void:
	_title.text = title_text
	suggestions = sugg
	_sug = -1
	value = ""
	row = 0
	col = 0
	caps = true
	visible = true
	_refresh()


## Recebe um evento da tela dona. Devolve true se usou.
func handle(ev: InputEvent) -> bool:
	if not visible:
		return false
	if ev is InputEventKey:
		if not ev.pressed:
			return false
		var k: int = ev.keycode if ev.keycode != 0 else ev.physical_keycode
		match k:
			KEY_ENTER, KEY_KP_ENTER:
				if not ev.echo:
					activate()
				return true
			KEY_BACKSPACE:
				erase()
				return true
			KEY_ESCAPE:
				if not ev.echo:
					cancelled.emit()
				return true
			KEY_UP: move(0, -1); return true
			KEY_DOWN: move(0, 1); return true
			KEY_LEFT: move(-1, 0); return true
			KEY_RIGHT: move(1, 0); return true
		if ev.unicode >= 32:
			if type_char(String.chr(ev.unicode)):
				_jump_to_ok()
			return true
		return false
	match Kit.nav(ev):
		"up": move(0, -1)
		"down": move(0, 1)
		"left": move(-1, 0)
		"right": move(1, 0)
		"ok": activate()
		"back":
			if value == "":
				cancelled.emit()
			else:
				erase()
		_: return false
	return true


func move(dx: int, dy: int) -> void:
	preload("res://audio/cue.gd").sfx("ui_move")
	if dy != 0:
		var old: int = ROWS[row].size()
		row = posmod(row + dy, ROWS.size())
		var n: int = ROWS[row].size()
		col = clampi(roundi(float(col) * (n - 1) / maxf(1.0, old - 1)), 0, n - 1)
	else:
		col = posmod(col + dx, ROWS[row].size())
	_refresh()


func current_key() -> String:
	return ROWS[row][col]


func activate() -> void:
	preload("res://audio/cue.gd").sfx("ui_confirm")
	var k := current_key()
	match k:
		"Aa":
			caps = not caps
			_refresh()
		"Espaço":
			type_char(" ")
		"Sugerir":
			if not suggestions.is_empty():
				_sug = (_sug + 1) % suggestions.size()
				value = String(suggestions[_sug]).left(MAX_LEN)
				_auto_caps()
				_refresh()
		"Apagar":
			erase()
		"OK":
			confirm()
		_:
			type_char(k if caps else k.to_lower())


static func allowed(ch: String) -> bool:
	return ch.length() == 1 and (ch.to_upper() != ch.to_lower() or "0123456789 -.'".contains(ch))


## Acrescenta um caractere. Falso se não coube ou não é permitido.
func type_char(ch: String) -> bool:
	if not allowed(ch) or value.length() >= MAX_LEN or (ch == " " and (value == "" or value.ends_with(" "))):
		return false
	value += ch
	_auto_caps()
	_refresh()
	return true


func erase() -> void:
	preload("res://audio/cue.gd").sfx("ui_back")
	if value != "":
		value = value.left(value.length() - 1)
		_auto_caps()
		_refresh()


func confirm() -> void:
	var v := value.strip_edges()
	if v == "" and not suggestions.is_empty():
		v = String(suggestions[0])
	if v == "":
		return
	visible = false
	done.emit(v)


func _auto_caps() -> void:
	caps = value == "" or value.ends_with(" ")


func _jump_to_ok() -> void:
	row = ROWS.size() - 1
	col = ROWS[row].size() - 1
	_refresh()


func _refresh() -> void:
	if _grid == null:
		return
	_value_label.text = value + ("_" if value.length() < MAX_LEN else "")
	_count.text = "%d/%d" % [value.length(), MAX_LEN]
	if value == "" and not suggestions.is_empty():
		_count.text = "vazio = %s   0/%d" % [suggestions[0], MAX_LEN]
	Kit.clear(_grid)
	for r in ROWS.size():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		_grid.add_child(hb)
		for c in ROWS[r].size():
			var k: String = ROWS[r][c]
			var txt := k if (caps or SPECIAL.has(k)) else k.to_lower()
			hb.add_child(_cell(txt, r == row and c == col, SPECIAL.has(k)))


func _cell(txt: String, selected: bool, wide: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Kit.SEL_BG if selected else Kit.BG_ROW
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	if selected:
		sb.border_color = Kit.SEL
		sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(98 if wide else 50, 40)
	var l := Kit.label(txt, Kit.SEL if selected else Kit.TEXT, 18 if wide else 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p
