extends RefCounted
## Peças comuns da UI: tema, painéis, linhas de tabela, navegação por teclado e textos em português.
## Uso: const Kit := preload("res://ui/ui_kit.gd")

const BG := Color(0.09, 0.11, 0.17, 0.96)
const BG_ROW := Color(0.14, 0.17, 0.25)
const SEL := Color(0.98, 0.78, 0.25)
const SEL_BG := Color(0.26, 0.31, 0.45)
const TEXT := Color(0.93, 0.94, 0.97)
const DIM := Color(0.6, 0.64, 0.73)
const GOOD := Color(0.45, 0.85, 0.5)
const BAD := Color(0.95, 0.4, 0.35)
const ACCENT := Color(0.45, 0.75, 1.0)

const TYPES := {
	"normal": "Normal", "fire": "Fogo", "water": "Água", "grass": "Planta", "electric": "Elétrico",
	"ice": "Gelo", "fighting": "Lutador", "poison": "Venenoso", "ground": "Terrestre", "flying": "Voador",
	"psychic": "Psíquico", "bug": "Inseto", "rock": "Pedra", "ghost": "Fantasma", "dragon": "Dragão",
	"dark": "Sombrio", "steel": "Aço", "fairy": "Fada",
}
const CATEGORIES := {"physical": "Físico", "special": "Especial", "status": "Status"}
const STATS := {"hp": "HP", "atk": "Ataque", "def": "Defesa", "spa": "At. Esp.", "spd": "Def. Esp.", "spe": "Velocidade"}
const STATUS := {"burn": "QUE", "poison": "ENV", "paralysis": "PAR", "sleep": "DOR", "freeze": "CON", "toxic": "ENV"}


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	sb.border_color = Color(0.3, 0.36, 0.5)
	sb.set_border_width_all(2)
	t.set_stylebox("panel", "PanelContainer", sb)
	return t


## Raiz em tela cheia com fundo escurecido e uma janela central. Devolve [raiz, conteúdo VBox].
static func window(layer: CanvasLayer, size: Vector2) -> Array:
	var root := Control.new()
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var win := PanelContainer.new()
	win.custom_minimum_size = size
	center.add_child(win)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	win.add_child(col)
	return [root, col]


static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


static func label(text: String, color := TEXT, size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## Uma linha selecionável. cols = [texto, ...] ou [[texto, cor], ...]; widths = largura mínima de cada coluna.
static func row(cols: Array, widths: Array, selected := false, disabled := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SEL_BG if selected else BG_ROW
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.border_color = SEL
		sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for i in cols.size():
		var c = cols[i]
		var txt: String = c[0] if c is Array else str(c)
		var col: Color = c[1] if c is Array else (SEL if selected and i == 0 else TEXT)
		if disabled:
			col = DIM
		var l := label(txt, col)
		if i < widths.size():
			l.custom_minimum_size.x = widths[i]
		if i == cols.size() - 1 and i >= widths.size():
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	return p


static func hint(text: String) -> Label:
	var l := label(text, DIM, 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## Traduz um evento em "up" "down" "left" "right" "ok" "back" (ou "").
## Teclas: setas/WASD, E/Enter/Espaço confirma, Esc/Q/Backspace volta. Também aceita ui_* (controle).
static func nav(ev: InputEvent) -> String:
	if ev is InputEventKey:
		if not ev.pressed:
			return ""
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		match k:
			KEY_UP, KEY_W: return "up"
			KEY_DOWN, KEY_S: return "down"
			KEY_LEFT, KEY_A: return "left"
			KEY_RIGHT, KEY_D: return "right"
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: return "" if ev.echo else "ok"
			KEY_ESCAPE, KEY_Q, KEY_BACKSPACE: return "" if ev.echo else "back"
		return ""
	for a in [["ui_up", "up"], ["ui_down", "down"], ["ui_left", "left"], ["ui_right", "right"],
			["ui_accept", "ok"], ["ui_cancel", "back"]]:
		if ev.is_action_pressed(a[0]):
			return a[1]
	return ""


## Evento de tecla pronto (para testes e para reenviar entradas).
static func key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	return ev


static func type_name(t: String) -> String:
	return TYPES.get(t, t.capitalize())


static func move_name(id: String) -> String:
	return String(Dex.move(id).get("name", id))


static func item_name(id: String) -> String:
	return String(Dex.item(id).get("name", id))


## [nome, tipo, categoria, poder, precisão] de um golpe, já como texto.
static func move_cols(id: String) -> Array:
	var mv := Dex.move(id)
	var t := String(mv.get("type", "normal"))
	var power := int(mv.get("power", 0))
	var acc := int(mv.get("accuracy", 0))
	return [move_name(id), [type_name(t), Dex.type_color(t)], CATEGORIES.get(mv.get("category", ""), "?"),
		str(power) if power > 0 else "—", str(acc) if acc > 0 else "—"]


static func status_text(m: Mon) -> String:
	if m.is_fainted():
		return "DES"
	return STATUS.get(m.status, "")


static func nature_text(nature: String) -> String:
	var n: Array = StatCalc.NATURES.get(nature, [])
	if n.is_empty():
		return "%s (neutra)" % nature.capitalize()
	return "%s (+%s −%s)" % [nature.capitalize(), STATS[n[0]], STATS[n[1]]]


static func hp_color(m: Mon) -> Color:
	var f := float(m.hp) / maxf(1.0, m.max_hp)
	return GOOD if f > 0.5 else (SEL if f > 0.2 else BAD)
