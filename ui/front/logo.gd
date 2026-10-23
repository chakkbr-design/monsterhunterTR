extends Control
## Logo original desenhado em código: emblema de estrela num anel + título em duas linhas.

const LINE1 := "COLECIONADOR"
const LINE2 := "DE MONSTROS"
const GOLD := Color(1.0, 0.8, 0.3)
const INK := Color(0.1, 0.08, 0.2)

var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(620, 230)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var cx := size.x * 0.5
	# Emblema: anel com estrela de 8 pontas girando devagar.
	var e := Vector2(cx, 58)
	draw_circle(e, 52, INK)
	draw_arc(e, 46, 0, TAU, 48, GOLD, 6.0, true)
	var pts := PackedVector2Array()
	for i in 16:
		var a := t * 0.4 + i * TAU / 16.0
		var r := 38.0 if i % 2 == 0 else 15.0
		pts.append(e + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.75))
	draw_circle(e, 9, Color(0.95, 0.4, 0.35))
	# Título com contorno escuro e sombra.
	_text(font, LINE1, 40, cx, 160, Color(0.85, 0.92, 1.0))
	_text(font, LINE2, 58, cx, 218, GOLD)


func _text(font: Font, s: String, fs: int, cx: float, y: float, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(cx - w * 0.5, y)
	draw_string_outline(font, p + Vector2(4, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0, 0, 0, 0.35))
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, INK)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
