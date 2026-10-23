extends RefCounted
## Kit visual da UI, porte do kit do jogo original (pk_window, pk_menu_list, pk_hint_bar, ui_draw):
## janelas de papel com borda de tinta, seleção em pílula vermelha com setinha, barra de dicas com
## teclas, fontes Nunito/Pixelify Sans, ícones de item e sprites de Pokémon.
## Uso: const Kit := preload("res://ui/ui_kit.gd")

# --- Paleta do original ---
const PAPER := Color("f8f8f0")
const INK := Color("283040")
const RIM := Color("c8ccd4")
const SHADOW_TXT := Color("d0d0c8")
const RED := Color("e0403a")
const RED_SOFT := Color("fbe3e1")
const GREEN := Color("48a860")
const BLUE := Color("3870c8")
const AMBER := Color("e8b030")
const PP_BLUE := Color("58a0e8")
const DIM := Color("9098a0")

# Nomes antigos (as telas usam estes), mapeados para a paleta do original.
const BG := PAPER
const BG_ROW := Color("ecede6")
const SEL := RED
const SEL_BG := RED_SOFT
const TEXT := INK
const GOOD := GREEN
const BAD := RED
const ACCENT := BLUE

const SIZE_TITLE := 58
const SIZE_HEADER := 26
const SIZE_BODY := 20
const SIZE_SMALL := 16

const TITLE_FONT_PATH := "res://original/assets/fonts/PixelifySans.ttf"
const BODY_FONT_PATH := "res://original/assets/fonts/Nunito.ttf"
const SPRITES_PATH := "res://gfx/pokemon_sprites.gd"
const BADGE_DIR := "res://original/assets/ui/badges/"

const TYPES := {
	"normal": "Normal",
	"fire": "Fogo",
	"water": "Água",
	"grass": "Planta",
	"electric": "Elétrico",
	"ice": "Gelo",
	"fighting": "Lutador",
	"poison": "Venenoso",
	"ground": "Terrestre",
	"flying": "Voador",
	"psychic": "Psíquico",
	"bug": "Inseto",
	"rock": "Pedra",
	"ghost": "Fantasma",
	"dragon": "Dragão",
	"dark": "Sombrio",
	"steel": "Aço",
	"fairy": "Fada",
}
const CATEGORIES := {"physical": "Físico", "special": "Especial", "status": "Status"}
const STATS := {
	"hp": "HP",
	"atk": "Ataque",
	"def": "Defesa",
	"spa": "At. Esp.",
	"spd": "Def. Esp.",
	"spe": "Velocidade"
}
const STATUS := {
	"burn": "QUE",
	"poison": "ENV",
	"paralysis": "PAR",
	"sleep": "DOR",
	"freeze": "CON",
	"toxic": "ENV"
}
## Pílulas de status (texto, cor), como o STATUS_TAGS do original.
const STATUS_TAGS := {
	"burn": ["QUE", Color(0.93, 0.45, 0.2)],
	"poison": ["ENV", Color(0.65, 0.3, 0.75)],
	"toxic": ["ENV", Color(0.65, 0.3, 0.75)],
	"paralysis": ["PAR", Color(0.95, 0.8, 0.2)],
	"sleep": ["DOR", Color(0.55, 0.6, 0.7)],
	"freeze": ["CON", Color(0.55, 0.85, 0.9)],
	"faint": ["DES", Color(0.45, 0.45, 0.5)]
}

static var _theme: Theme
static var _fonts := {}
static var _tex := {}
static var _sprites: GDScript
static var _sprites_tried := false

# --- Fontes e tema ---


static func title_font() -> Font:
	return _font(TITLE_FONT_PATH, 600)


static func body_font() -> Font:
	return _font(BODY_FONT_PATH, 600)


static func _font(p: String, weight: int) -> Font:
	if _fonts.has(p):
		return _fonts[p]
	var f: Font = ThemeDB.fallback_font
	var base := load(p) as FontFile if ResourceLoader.exists(p) else null
	if base:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("wght"): weight
		}
		f = fv
	_fonts[p] = f
	return f


static func window_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.set_content_margin_all(18)
	sb.anti_aliasing = true
	return sb


static func glass(alpha := 0.35, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = Color(PAPER, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func pill(bg: Color, border: Color, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	return sb


static func ui_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", INK)
	t.set_color("font_shadow_color", "Label", SHADOW_TXT)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", window_box())
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", title_font())
	t.set_font_size("font_size", "HeaderLabel", SIZE_HEADER)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title_font())
	t.set_font_size("font_size", "TitleLabel", SIZE_TITLE)
	t.set_color("font_color", "TitleLabel", PAPER)
	t.set_color("font_outline_color", "TitleLabel", INK)
	t.set_constant("outline_size", "TitleLabel", 12)
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.35))
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", SIZE_SMALL)
	t.set_color("font_shadow_color", "SmallLabel", Color.TRANSPARENT)
	_theme = t
	return t


static func theme() -> Theme:
	return ui_theme()


static func pop_in(c: Control, secs := 0.12) -> void:
	c.visible = true
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.96, 0.96)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, secs)
	tw.tween_property(c, "modulate:a", 1.0, secs)


# --- Janela (PkWindow) ---


## Janela de papel com borda de tinta, aro interno e aba de título azul (como o PkWindow).
class Win:
	extends PanelContainer
	const RIM_INSET := 6.0
	var title := "":
		set(v):
			title = v
			_apply_title()
			queue_redraw()

	func _init(t := "") -> void:
		theme = preload("res://ui/ui_kit.gd").ui_theme()
		title = t

	func _apply_title() -> void:
		if title == "":
			remove_theme_stylebox_override("panel")
			return
		var sb: StyleBoxFlat = preload("res://ui/ui_kit.gd").window_box()
		sb.content_margin_top += 12
		add_theme_stylebox_override("panel", sb)

	func _draw() -> void:
		var K = preload("res://ui/ui_kit.gd")
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = K.RIM
		rim.set_border_width_all(2)
		rim.set_corner_radius_all(6)
		rim.anti_aliasing = true
		draw_style_box(rim, Rect2(Vector2.ZERO, size).grow(-RIM_INSET))
		if title == "":
			return
		var f: Font = K.title_font()
		var fs: int = K.SIZE_SMALL + 2
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
		var tab := Rect2(Vector2(20, -fs * 0.8), Vector2(w, fs + 12))
		draw_style_box(K.pill(K.BLUE, K.INK, 8), tab)
		draw_string(
			f, tab.position + Vector2(14, fs + 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, K.PAPER
		)


## Raiz em tela cheia com fundo escurecido e uma janela central. Devolve [raiz, conteúdo VBox].
static func window(layer: Node, size: Vector2, title := "") -> Array:
	var root := Control.new()
	root.theme = ui_theme()
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
	var win := Win.new(title)
	win.custom_minimum_size = size
	center.add_child(win)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	win.add_child(col)
	return [root, col]


## Janela solta (sem fundo), já com uma VBox dentro. Devolve [janela, VBox].
static func panel(title := "", size := Vector2.ZERO, sep := 8) -> Array:
	var win := Win.new(title)
	win.custom_minimum_size = size
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", sep)
	win.add_child(col)
	return [win, col]


static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


static func label(text: String, color := TEXT, size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if color.get_luminance() > 0.6:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


static func header(text: String, color := INK, size := SIZE_HEADER) -> Label:
	var l := label(text, color, size)
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_font_override("font", title_font())
	return l


# --- Linha selecionável (PkMenuList) ---


## Linha com a pílula vermelha e a setinha do original quando selecionada.
class Row:
	extends PanelContainer
	var selected := false
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		if not selected:
			return
		var c := Vector2(14.0 + sin(_t * TAU * 1.5) * 2.0, size.y * 0.5)
		draw_colored_polygon(
			PackedVector2Array([c + Vector2(-6, -8), c + Vector2(7, 0), c + Vector2(-6, 8)]),
			preload("res://ui/ui_kit.gd").INK
		)


## Uma linha selecionável. cols = [texto, ...], [[texto, cor], ...], [texto, cor, "pill"] (pílula colorida)
## ou nós Control prontos; widths = largura mínima de cada coluna.
static func row(cols: Array, widths: Array, selected := false, disabled := false) -> PanelContainer:
	var p := Row.new()
	p.selected = selected
	p.set_process(selected)
	var sb: StyleBox = pill(RED_SOFT, RED, 15) if selected else StyleBoxEmpty.new()
	sb.content_margin_left = 34
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for i in cols.size():
		var c = cols[i]
		var node: Control
		if c is Control:
			node = c
		elif c is Array and c.size() > 2 and String(c[2]) == "pill":
			node = tag(String(c[0]), c[1])
		else:
			var txt: String = String(c[0]) if c is Array else str(c)
			var col: Color = c[1] if c is Array else INK
			if disabled:
				col = DIM
			var l := label(txt, col)
			if disabled:
				l.add_theme_font_size_override("font_size", SIZE_SMALL)
				l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			node = l
		if i < widths.size():
			node.custom_minimum_size.x = widths[i]
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i == cols.size() - 1 and i >= widths.size():
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(node)
	return p


## Pílula colorida com texto (tipo de golpe, aba de bolsa...).
static func tag(text: String, col: Color, fs := 14) -> Control:
	var c := CenterContainer.new()
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", fs)
	var dark := col.get_luminance() < 0.62
	l.add_theme_color_override("font_color", PAPER if dark else INK)
	l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	var sb := pill(col.darkened(0.12), col.lightened(0.35), 10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	c.add_child(l)
	return c


# --- Barra de dicas (PkHintBar) ---


class KeyCap:
	extends Control
	var cap := ""

	func _init(text: String) -> void:
		cap = text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w: float = (
			preload("res://ui/ui_kit.gd")
			. body_font()
			. get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			. x
		)
		custom_minimum_size = Vector2(maxf(26.0, w + 14.0), 26)

	func _draw() -> void:
		var K = preload("res://ui/ui_kit.gd")
		var r := Rect2(Vector2(0, 2), size - Vector2(0, 4))
		draw_style_box(
			K.pill(Color(0, 0, 0, 0.45), Color.TRANSPARENT, 6),
			Rect2(r.position + Vector2(0, 2), r.size)
		)
		draw_style_box(K.pill(K.PAPER, K.RIM, 6), r)
		draw_string(
			K.body_font(),
			Vector2(0, r.get_center().y + 5),
			cap,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			14,
			K.INK
		)


## Faixa escura com teclas e legendas. `text` aceita "E/Enter confirma · Esc volta".
class HintBar:
	extends HBoxContainer
	var text := "":
		set(v):
			text = v
			_rebuild()

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_END

	func _rebuild() -> void:
		var K = preload("res://ui/ui_kit.gd")
		for c in get_children():
			remove_child(c)
			c.queue_free()
		for pair in K.parse_hints(text):
			if pair[0] != "":
				add_child(KeyCap.new(pair[0]))
			var l := Label.new()
			l.text = String(pair[1]) + "  "
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", K.PAPER)
			l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(l)
		queue_redraw()

	func _draw() -> void:
		if get_child_count() > 0:
			draw_style_box(
				preload("res://ui/ui_kit.gd").pill(
					Color(preload("res://ui/ui_kit.gd").INK, 0.78),
					Color.TRANSPARENT,
					size.y * 0.5 + 6
				),
				Rect2(Vector2.ZERO, size).grow_individual(10, 4, 4, 4)
			)


## "E/Enter confirma · Esc volta" -> [["E/Enter", "confirma"], ["Esc", "volta"]].
static func parse_hints(text: String) -> Array:
	var out: Array = []
	for seg in text.split("·"):
		var s := String(seg).strip_edges()
		if s == "":
			continue
		var i := s.find(" ")
		var k := s if i < 0 else s.substr(0, i)
		var rest := "" if i < 0 else s.substr(i + 1).strip_edges()
		k = k.trim_suffix(":")
		var keyish: bool = k.length() <= 9 or k.contains("/")
		if i < 0 and not keyish:
			out.append(["", s])
		elif keyish:
			out.append([k, rest])
		else:
			out.append(["", s])
	return out


static func hint(text: String) -> HintBar:
	var h := HintBar.new()
	h.text = text
	return h


# --- Entrada ---


## Traduz um evento em "up" "down" "left" "right" "ok" "back" (ou "").
## Teclas: setas/WASD, E/Enter/Espaço confirma, Esc/Q/Backspace volta. Também aceita ui_* (controle).
static func nav(ev: InputEvent) -> String:
	if ev is InputEventKey:
		if not ev.pressed:
			return ""
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		match k:
			KEY_UP, KEY_W:
				return "up"
			KEY_DOWN, KEY_S:
				return "down"
			KEY_LEFT, KEY_A:
				return "left"
			KEY_RIGHT, KEY_D:
				return "right"
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				return "" if ev.echo else "ok"
			KEY_ESCAPE, KEY_Q, KEY_BACKSPACE:
				return "" if ev.echo else "back"
		return ""
	for a in [
		["ui_up", "up"],
		["ui_down", "down"],
		["ui_left", "left"],
		["ui_right", "right"],
		["ui_accept", "ok"],
		["ui_cancel", "back"]
	]:
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


# --- Textos ---


static func type_name(t: String) -> String:
	return TYPES.get(t, t.capitalize())


static func move_name(id: String) -> String:
	return String(Dex.move(id).get("name", id))


static func item_name(id: String) -> String:
	return String(Dex.item(id).get("name", id))


static func type_col(t: String) -> Color:
	var c := Dex.type_color(t)
	return c.darkened(0.25) if c.get_luminance() > 0.85 else c


## [nome, tipo (pílula), categoria, poder, precisão] de um golpe.
static func move_cols(id: String) -> Array:
	var mv := Dex.move(id)
	var t := String(mv.get("type", "normal"))
	var power := int(mv.get("power", 0))
	var acc := int(mv.get("accuracy", 0))
	return [
		move_name(id),
		[type_name(t), type_col(t), "pill"],
		CATEGORIES.get(mv.get("category", ""), "?"),
		str(power) if power > 0 else "—",
		str(acc) if acc > 0 else "—"
	]


static func status_text(m: Mon) -> String:
	if m.is_fainted():
		return "DES"
	return STATUS.get(m.status, "")


static func status_key(m: Mon) -> String:
	if m.is_fainted():
		return "faint"
	return m.status if STATUS_TAGS.has(m.status) else ""


static func nature_text(nature: String) -> String:
	var n: Array = StatCalc.NATURES.get(nature, [])
	if n.is_empty():
		return "%s (neutra)" % nature.capitalize()
	return "%s (+%s −%s)" % [nature.capitalize(), STATS[n[0]], STATS[n[1]]]


## Cor da vida: aceita um Mon ou a fração 0..1.
static func hp_color(m) -> Color:
	var f: float = float(m) if (m is float or m is int) else float(m.hp) / maxf(1.0, m.max_hp)
	return GREEN if f > 0.5 else (AMBER if f > 0.2 else RED)


static func format_money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + "$" + s + out


static func format_time(secs: float) -> String:
	var m := int(secs) / 60
	return "%d:%02d" % [m / 60, m % 60]


# --- Desenho (ui_draw) ---


static func rounded(
	ci: CanvasItem,
	r: Rect2,
	col: Color,
	radius := 6.0,
	border := 0.0,
	border_col := Color.TRANSPARENT
) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


## Texto com contorno escuro (HUD sobre o mundo).
static func draw_text(
	ci: CanvasItem, pos: Vector2, s: String, size: int, col := PAPER, outline := 4, f: Font = null
) -> void:
	var fnt := f if f != null else body_font()
	if outline > 0:
		ci.draw_string_outline(
			fnt, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.85 * col.a)
		)
	ci.draw_string(fnt, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func draw_ring(
	ci: CanvasItem, center: Vector2, r: float, width: float, ratio: float, col: Color, bg: Color
) -> void:
	ci.draw_arc(center, r, 0.0, TAU, 64, bg, width, true)
	var f := clampf(ratio, 0.0, 1.0)
	if f <= 0.0:
		return
	var a0 := -PI * 0.5
	var a1 := a0 + TAU * f
	ci.draw_arc(center, r, a0, a1, maxi(8, int(64 * f)), col, width, true)
	ci.draw_circle(center + Vector2(cos(a0), sin(a0)) * r, width * 0.5, col)
	ci.draw_circle(center + Vector2(cos(a1), sin(a1)) * r, width * 0.5, col)


## Barra arredondada (HP/EXP) com brilho, como a ui_draw.bar.
static func bar(
	ci: CanvasItem, r: Rect2, fill: float, col: Color, track := Color(0.16, 0.18, 0.22)
) -> void:
	var rad := r.size.y * 0.5
	rounded(ci, r.grow(1.5), Color(0, 0, 0, 0.45), rad + 1.5)
	rounded(ci, r, track, rad)
	var f := clampf(fill, 0.0, 1.0)
	if f > 0.0:
		var w := maxf(r.size.x * f, rad * 2.0)
		rounded(ci, Rect2(r.position, Vector2(w, r.size.y)), col, rad)
		rounded(ci, Rect2(r.position, Vector2(w, r.size.y * 0.42)), Color(1, 1, 1, 0.22), rad * 0.5)


static func status_pill(ci: CanvasItem, pos: Vector2, status: String, fs := 12) -> float:
	if not STATUS_TAGS.has(status):
		return 0.0
	var t: Array = STATUS_TAGS[status]
	var w := body_font().get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
	var h := fs + 6.0
	rounded(ci, Rect2(pos, Vector2(w, h)), t[1], 4)
	ci.draw_string(
		body_font(), pos + Vector2(6, h - 4.5), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER
	)
	return w


static func _hex(s: String, fallback: Color) -> Color:
	return Color.html(s) if s != "" and Color.html_is_valid(s) else fallback


## Ícone procedural do item (pokébola, spray, frasco, fruta, doce, pacote, aparelho).
static func item_icon(ci: CanvasItem, id: String, r: Rect2, dim := false) -> void:
	var it := Dex.item(id)
	var mod := Color(1, 1, 1, 0.35) if dim else Color.WHITE
	if String(it.get("category", "")) == "balls" or id.ends_with("_ball"):
		ball(
			ci,
			r,
			_hex(String(it.get("top", "")), RED) * mod,
			_hex(String(it.get("accent", "")), Color.TRANSPARENT) * mod,
			mod
		)
		return
	var ic: Dictionary = it.get("icon", {}) if it.get("icon", {}) is Dictionary else {}
	var col := _hex(String(ic.get("color", "")), Color(0.6, 0.6, 0.65)) * mod
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center() - Vector2(s, s) * 0.5
	match String(ic.get("shape", "")):
		"spray":
			var body := Rect2(o + Vector2(s * 0.24, s * 0.36), Vector2(s * 0.52, s * 0.56))
			rounded(
				ci,
				Rect2(body.position + Vector2(0, s * 0.03), body.size),
				Color(0, 0, 0, 0.35 * mod.a),
				s * 0.12
			)
			rounded(ci, body, col, s * 0.12, maxf(1.0, s * 0.03), col.darkened(0.45))
			rounded(
				ci,
				Rect2(body.position + Vector2(s * 0.06, s * 0.17), Vector2(s * 0.4, s * 0.2)),
				PAPER * mod,
				s * 0.04
			)
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.38, s * 0.24), Vector2(s * 0.24, s * 0.13)),
				Color(0.55, 0.57, 0.62) * mod,
				s * 0.03
			)
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.3, s * 0.1), Vector2(s * 0.42, s * 0.15)),
				Color(0.72, 0.74, 0.78) * mod,
				s * 0.05,
				1.0,
				Color(0.3, 0.32, 0.36) * mod
			)
		"vial":
			var body := Rect2(o + Vector2(s * 0.27, s * 0.3), Vector2(s * 0.46, s * 0.6))
			rounded(
				ci,
				body,
				Color(0.85, 0.92, 0.96, 0.9) * mod,
				s * 0.14,
				maxf(1.0, s * 0.03),
				Color(0.3, 0.35, 0.4) * mod
			)
			rounded(
				ci,
				Rect2(
					body.position + Vector2(s * 0.04, s * 0.2),
					body.size - Vector2(s * 0.08, s * 0.24)
				),
				col,
				s * 0.11
			)
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.33, s * 0.12), Vector2(s * 0.34, s * 0.2)),
				col.darkened(0.35),
				s * 0.05,
				1.0,
				col.darkened(0.6)
			)
		"berry":
			var c := r.get_center() + Vector2(0, s * 0.06)
			ci.draw_circle(c + Vector2(-s * 0.1, 0), s * 0.26, col)
			ci.draw_circle(c + Vector2(s * 0.1, 0), s * 0.26, col)
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.26, col.darkened(0.08))
			ci.draw_circle(
				c + Vector2(-s * 0.14, -s * 0.08), s * 0.07, Color(1, 1, 1, 0.55 * mod.a)
			)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[
						c + Vector2(0, -s * 0.22),
						c + Vector2(s * 0.2, -s * 0.42),
						c + Vector2(s * 0.3, -s * 0.3),
						c + Vector2(s * 0.06, -s * 0.18)
					]
				),
				Color(0.3, 0.7, 0.3) * mod
			)
		"candy":
			var c := r.get_center()
			var wrap := col.lightened(0.25)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[
						c + Vector2(-s * 0.2, 0),
						c + Vector2(-s * 0.46, -s * 0.18),
						c + Vector2(-s * 0.46, s * 0.18)
					]
				),
				wrap
			)
			ci.draw_colored_polygon(
				PackedVector2Array(
					[
						c + Vector2(s * 0.2, 0),
						c + Vector2(s * 0.46, -s * 0.18),
						c + Vector2(s * 0.46, s * 0.18)
					]
				),
				wrap
			)
			ci.draw_circle(c, s * 0.24, col)
			ci.draw_arc(c, s * 0.24, 0, TAU, 24, col.darkened(0.45), maxf(1.0, s * 0.03), true)
		"parcel":
			var box := Rect2(o + Vector2(s * 0.16, s * 0.22), Vector2(s * 0.68, s * 0.6))
			rounded(ci, box, col, s * 0.06, maxf(1.0, s * 0.03), col.darkened(0.45))
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.47, s * 0.22), Vector2(s * 0.06, s * 0.6)),
				col.lightened(0.25),
				s * 0.02
			)
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.16, s * 0.47), Vector2(s * 0.68, s * 0.06)),
				col.lightened(0.25),
				s * 0.02
			)
		"device":
			var body := Rect2(o + Vector2(s * 0.22, s * 0.12), Vector2(s * 0.56, s * 0.76))
			rounded(ci, body, col, s * 0.08, maxf(1.0, s * 0.03), col.darkened(0.4))
			rounded(
				ci,
				Rect2(o + Vector2(s * 0.29, s * 0.2), Vector2(s * 0.42, s * 0.3)),
				Color(0.55, 0.9, 0.75) * mod,
				s * 0.03,
				1.0,
				col.darkened(0.5)
			)
			ci.draw_circle(o + Vector2(s * 0.5, s * 0.66), s * 0.09, Color(0.3, 0.5, 0.9) * mod)
		_:
			if String(it.get("category", "")) == "tm":
				var disc := r.get_center()
				ci.draw_circle(
					disc,
					s * 0.36,
					(
						Dex.type_color(
							String(
								Dex.move(String(it.get("effect", {}).get("teach", ""))).get(
									"type", "normal"
								)
							)
						)
						* mod
					)
				)
				ci.draw_circle(disc, s * 0.12, PAPER * mod)
				ci.draw_arc(disc, s * 0.36, 0, TAU, 24, INK * mod, 1.5, true)
			else:
				rounded(ci, r.grow(-r.size.x * 0.2), col, 6, 1.5, col.darkened(0.45))


static func ball(
	ci: CanvasItem, r: Rect2, top: Color, accent := Color.TRANSPARENT, mod := Color.WHITE
) -> void:
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.42
	ci.draw_circle(c + Vector2(0, rad * 0.08), rad, Color(0, 0, 0, 0.35 * mod.a))
	ci.draw_circle(c, rad, PAPER * mod)
	var top_pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		top_pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(top_pts, top)
	if accent.a > 0.0:
		ci.draw_circle(c + Vector2(-rad * 0.45, -rad * 0.45), rad * 0.2, accent)
		ci.draw_circle(c + Vector2(rad * 0.45, -rad * 0.45), rad * 0.2, accent)
	ci.draw_line(c - Vector2(rad, 0), c + Vector2(rad, 0), INK * mod, rad * 0.16)
	ci.draw_circle(c, rad * 0.3, INK * mod)
	ci.draw_circle(c, rad * 0.19, PAPER * mod)
	ci.draw_arc(c, rad, 0, TAU, 32, INK * mod, maxf(1.5, rad * 0.08), true)
	ci.draw_circle(c + Vector2(-rad * 0.35, -rad * 0.55), rad * 0.12, Color(1, 1, 1, 0.7 * mod.a))


## Nó que desenha o ícone de um item (para linhas de lista).
class ItemIcon:
	extends Control
	var id := ""
	var dim := false

	func _init(item_id := "", px := 30) -> void:
		id = item_id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		preload("res://ui/ui_kit.gd").item_icon(self, id, Rect2(Vector2.ZERO, size), dim)


# --- Sprites de Pokémon (helpers do gfx/pokemon_sprites.gd) ---


static func _ps() -> GDScript:
	if not _sprites_tried:
		_sprites_tried = true
		if ResourceLoader.exists(SPRITES_PATH):
			_sprites = load(SPRITES_PATH)
	return _sprites


static func _sprite(fn: String, species: String, args := []) -> Texture2D:
	var ps := _ps()
	if ps == null or species == "":
		return null
	var key := "%s|%s|%s" % [fn, species, args]
	if _tex.has(key):
		return _tex[key]
	var t = ps.callv(fn, [species] + args)
	_tex[key] = t if t is Texture2D else null
	return _tex[key]


static func mon_icon(species: String) -> Texture2D:
	return _sprite("icon", species)


static func mon_front(species: String) -> Texture2D:
	return _sprite("front", species)


static func mon_back(species: String) -> Texture2D:
	return _sprite("back", species)


static func party_icon(species: String) -> Texture2D:
	return _sprite("party_icon", species)


static func mon_fitted(species: String, px: int) -> Texture2D:
	return _sprite("icon_fitted", species, [px])


static func mon_disc(species: String, px: int) -> Texture2D:
	return _sprite("disc_icon", species, [px])


## TextureRect pronto com o sprite (pixel art, sem filtro).
static func sprite_rect(tex: Texture2D, px: Vector2, gray := false) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = px
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gray:
		r.modulate = Color(0.42, 0.45, 0.5, 0.85)
	return r


## Recorte de uma folha de sprite (retrato de treinador/NPC do original).
static func sheet_frame(path: String, region: Rect2) -> Texture2D:
	var key := "sheet|%s|%s" % [path, region]
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var at := AtlasTexture.new()
		at.atlas = load(path)
		at.region = region
		t = at
	_tex[key] = t
	return t


static func badge_texture(id: String) -> Texture2D:
	var p := BADGE_DIR + id + ".png"
	var key := "badge|" + id
	if not _tex.has(key):
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


# --- Peças compostas ---


## Linha de Pokémon da equipe (party_row do original): ícone, nome, nível, status, barra de HP.
class PartyRow:
	extends Control
	var mon: Mon
	var selected := false
	var source := false
	var note := ""

	func _init(m: Mon = null, h := 84.0) -> void:
		mon = m
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if mon == null:
			return
		var K = preload("res://ui/ui_kit.gd")
		var m := mon
		var r := Rect2(Vector2.ZERO, size).grow_individual(-4, 0, -4, 0)
		if source:
			draw_style_box(K.pill(Color(K.RED, 0.1), K.RED, 12), r)
		elif selected:
			draw_style_box(K.pill(K.RED_SOFT, K.RED, 12), r)
		var f: Font = K.body_font()
		var ic: Texture2D = K.mon_fitted(m.species, 64)
		var isz := minf(56.0, size.y - 12.0)
		var ir := Rect2(Vector2(12, (size.y - isz) * 0.5), Vector2(isz, isz))
		if ic:
			draw_texture_rect(ic, ir, false, Color(0.4, 0.4, 0.4) if m.hp <= 0 else Color.WHITE)
		else:
			K.ball(self, ir, K.RED)
		var x0 := isz + 22.0
		var ink: Color = K.INK if m.hp > 0 else K.DIM
		var y1 := size.y * 0.5 - 4.0
		var nm := m.display_name.to_upper()
		draw_string(f, Vector2(x0, y1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, K.SIZE_BODY, ink)
		var x := x0 + f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, K.SIZE_BODY).x
		if m.gender == "male" or m.gender == "female":
			x += 8.0
			draw_string(
				f,
				Vector2(x, y1),
				"♂" if m.gender == "male" else "♀",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				K.SIZE_BODY,
				K.BLUE if m.gender == "male" else K.RED
			)
		draw_string(
			f,
			Vector2(size.x - 116, y1),
			"Nv %d" % m.level,
			HORIZONTAL_ALIGNMENT_RIGHT,
			100,
			K.SIZE_BODY,
			ink
		)
		var bar_x := x0
		var st: String = K.status_key(m)
		if st != "":
			bar_x += K.status_pill(self, Vector2(x0, y1 + 8), st, 12) + 10.0
		var hp_r := clampf(float(m.hp) / maxf(float(m.max_hp), 1.0), 0.0, 1.0)
		var bw := size.x - 150.0 - bar_x
		if note != "":
			bw -= 110.0
		K.bar(
			self,
			Rect2(Vector2(bar_x, y1 + 12), Vector2(maxf(bw, 40.0), 10)),
			hp_r,
			K.hp_color(hp_r),
			Color(K.DIM, 0.5)
		)
		draw_string(
			f,
			Vector2(size.x - 136, y1 + 23),
			"HP %d/%d" % [maxi(m.hp, 0), m.max_hp],
			HORIZONTAL_ALIGNMENT_RIGHT,
			120,
			K.SIZE_SMALL,
			ink
		)
		if note != "":
			draw_string(
				f, Vector2(size.x - 262, y1 + 23), note, HORIZONTAL_ALIGNMENT_RIGHT, 110, 14, K.DIM
			)


## Caixa de diálogo (PkDialogBox): janela com o nome na aba, texto com letreiro e setinha vermelha.
class Dialog:
	extends Win
	var label: Label
	var cps := 50.0
	var _chars := 0.0
	var _t := 0.0

	func _init() -> void:
		super()
		custom_minimum_size = Vector2(0, 130)
		label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		add_child(label)

	## Mostra uma fala. instant = sem letreiro.
	func show_line(speaker: String, text: String, instant := false) -> void:
		title = speaker
		label.text = text
		_chars = 0.0
		label.visible_characters = -1 if instant or cps <= 0.0 else 0
		visible = true

	func complete() -> bool:
		return (
			label.visible_characters < 0
			or label.visible_characters >= label.get_total_character_count()
		)

	func finish() -> void:
		label.visible_characters = -1

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		_t += dt
		if label.visible_characters >= 0:
			_chars += dt * cps
			label.visible_characters = int(_chars)
			if label.visible_characters >= label.get_total_character_count():
				label.visible_characters = -1
		queue_redraw()

	func _draw() -> void:
		super()
		if visible and complete():
			var c := Vector2(size.x - 34, size.y - 24 + sin(_t * TAU * 1.5) * 3.0)
			draw_colored_polygon(
				PackedVector2Array([c + Vector2(-8, -5), c + Vector2(8, -5), c + Vector2(0, 6)]),
				preload("res://ui/ui_kit.gd").RED
			)


## Valor de uma linha de opção (PkOptionRow.ValueView): "choice", "toggle", "volume" (0..10) ou "action".
class OptionValue:
	extends Control
	var kind := "choice"
	var value = 0
	var text := ""
	var selected := false

	func _init(k := "choice", v = 0, t := "", sel := false) -> void:
		kind = k
		value = v
		text = t
		selected = sel
		custom_minimum_size = Vector2(240, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var K = preload("res://ui/ui_kit.gd")
		var f: Font = K.body_font()
		var cy := size.y * 0.5
		var arrow: Color = K.RED if selected else K.DIM
		match kind:
			"choice":
				draw_string(
					f,
					Vector2(0, cy + 7),
					text,
					HORIZONTAL_ALIGNMENT_CENTER,
					size.x,
					K.SIZE_BODY,
					K.INK
				)
				draw_colored_polygon(
					PackedVector2Array([Vector2(8, cy), Vector2(18, cy - 8), Vector2(18, cy + 8)]),
					arrow
				)
				draw_colored_polygon(
					PackedVector2Array(
						[
							Vector2(size.x - 8, cy),
							Vector2(size.x - 18, cy - 8),
							Vector2(size.x - 18, cy + 8)
						]
					),
					arrow
				)
			"toggle":
				var on := bool(value)
				var r := Rect2(Vector2(size.x * 0.5 - 40, cy - 14), Vector2(80, 28))
				draw_style_box(K.pill(K.GREEN if on else K.DIM, K.INK, 14), r)
				draw_string(
					f,
					Vector2(r.position.x, cy + 6),
					"SIM" if on else "NÃO",
					HORIZONTAL_ALIGNMENT_CENTER,
					r.size.x,
					16,
					K.PAPER
				)
			"volume":
				var w := (size.x - 9 * 4.0) / 10.0
				for i in 10:
					var seg := Rect2(Vector2(i * (w + 4.0), cy - 10), Vector2(w, 20))
					var filled := i < int(value)
					draw_style_box(
						K.pill(K.RED if filled else K.RED_SOFT, K.INK if filled else K.RIM, 4), seg
					)
			"action":
				draw_colored_polygon(
					PackedVector2Array(
						[
							Vector2(size.x - 8, cy),
							Vector2(size.x - 18, cy - 8),
							Vector2(size.x - 18, cy + 8)
						]
					),
					arrow
				)


## Linha de opção completa: rótulo à esquerda e o valor desenhado à direita, pílula quando selecionada.
static func option_row(
	text: String, kind: String, value, choice_text := "", selected := false
) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBox = pill(RED_SOFT, RED, 20) if selected else StyleBoxEmpty.new()
	sb.content_margin_left = 16
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(OptionValue.new(kind, value, choice_text, selected))
	return p


## Linhas chave/valor (PkInfoCard): chave azul à esquerda, valor à direita.
static func info_grid(rows: Array, hsep := 40) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", 4)
	for r in rows:
		g.add_child(label(String(r[0]), BLUE))
		var v = r[1]
		if v is Control:
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(v)
		else:
			var l := label(str(v))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(l)
	return g


## Barra de progresso no estilo do resumo (trilho claro, cantos redondos).
static func progress(value: float, maxv: float, col: Color, h := 14) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(maxv, 1.0)
	b.value = clampf(value, 0.0, b.max_value)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in [["background", RIM], ["fill", col]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = k[1]
		sb.set_corner_radius_all(h / 2)
		b.add_theme_stylebox_override(k[0], sb)
	return b
