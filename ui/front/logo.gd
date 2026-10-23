extends Control
## Logo da tela de título no estilo do original: "POKéMON" em Pixelify Sans dourado com contorno azul
## e o subtítulo em papel com contorno de tinta.

const LINE1 := "POKéMON"
const LINE2 := "BATTLE ADVANCED"
const GOLD := Color("ffd84a")
const BLUE := Color("2a3a8a")

var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 170)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var K = preload("res://ui/ui_kit.gd")
	var f: Font = K.title_font()
	_text(f, LINE1, 96, Vector2(0, 92), GOLD, BLUE)
	_text(f, LINE2, 44, Vector2(6, 150), K.PAPER, K.INK)


func _text(f: Font, s: String, fs: int, p: Vector2, col: Color, outline: Color) -> void:
	draw_string_outline(f, p + Vector2(4, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0, 0, 0, 0.35))
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, outline)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
