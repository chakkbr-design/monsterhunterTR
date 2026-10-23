extends Control
## Personagens simples desenhados em código para a introdução: "prof", "boy" ou "girl".

var kind := "prof":
	set(v):
		kind = v
		queue_redraw()
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 240)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var bob := sin(t * 2.0) * 2.0
	var skin := Color(0.98, 0.82, 0.68)
	var shoe := Color(0.2, 0.16, 0.14)
	var coat: Color
	var legs: Color
	var hair: Color
	match kind:
		"prof":
			coat = Color(0.95, 0.95, 0.97)
			legs = Color(0.45, 0.35, 0.28)
			hair = Color(0.82, 0.82, 0.86)
		"boy":
			coat = Color(0.25, 0.5, 0.9)
			legs = Color(0.2, 0.25, 0.4)
			hair = Color(0.25, 0.17, 0.12)
		_:
			coat = Color(0.95, 0.45, 0.55)
			legs = Color(0.95, 0.85, 0.4)
			hair = Color(0.55, 0.28, 0.15)
	var base := size.y - 6.0
	# Pernas e sapatos.
	draw_rect(Rect2(cx - 22, base - 70, 18, 62), legs)
	draw_rect(Rect2(cx + 4, base - 70, 18, 62), legs)
	draw_rect(Rect2(cx - 26, base - 10, 24, 10), shoe)
	draw_rect(Rect2(cx + 2, base - 10, 24, 10), shoe)
	# Tronco (jaleco do professor é mais comprido; a menina usa saia).
	var top := base - 150 + bob
	var bottom := base - 40.0 if kind == "prof" else base - 64.0
	var flare := 40.0 if kind == "girl" else 30.0
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 26, top), Vector2(cx + 26, top),
		Vector2(cx + flare, bottom), Vector2(cx - flare, bottom)]), coat)
	if kind == "prof":
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, top), Vector2(cx + 8, top), Vector2(cx, top + 34)]),
			Color(0.35, 0.55, 0.45))
		draw_line(Vector2(cx, top + 34), Vector2(cx, bottom), Color(0.8, 0.8, 0.85), 2.0)
	# Braços.
	var wave := sin(t * 3.0) * 6.0 if kind == "prof" else 0.0
	draw_line(Vector2(cx - 26, top + 8), Vector2(cx - 38, top + 70), coat.darkened(0.12), 12.0)
	draw_line(Vector2(cx + 26, top + 8), Vector2(cx + 42, top + 64 - wave), coat.darkened(0.12), 12.0)
	draw_circle(Vector2(cx - 38, top + 72), 7, skin)
	draw_circle(Vector2(cx + 42, top + 66 - wave), 7, skin)
	# Cabeça e cabelo.
	var head := Vector2(cx, top - 30)
	if kind == "girl":
		draw_rect(Rect2(head.x - 30, head.y - 10, 60, 52), hair)
	draw_circle(head, 30, skin)
	match kind:
		"prof":
			draw_arc(head, 30, PI * 1.05, PI * 1.95, 16, hair, 12.0)
			draw_line(head + Vector2(-14, 12), head + Vector2(14, 12), Color(0.6, 0.6, 0.65), 3.0)
		"boy":
			draw_arc(head, 30, PI * 1.0, PI * 2.0, 16, hair, 16.0)
			draw_rect(Rect2(head.x - 34, head.y - 34, 68, 14), Color(0.9, 0.25, 0.25))
			draw_rect(Rect2(head.x, head.y - 24, 40, 6), Color(0.9, 0.25, 0.25))
		_:
			draw_arc(head, 30, PI * 1.0, PI * 2.0, 16, hair, 18.0)
			draw_circle(head + Vector2(26, -18), 8, Color(0.95, 0.85, 0.3))
	for ex in [-10, 10]:
		draw_circle(head + Vector2(ex, -2), 3.5, Color(0.15, 0.12, 0.2))
	draw_arc(head + Vector2(0, 8), 8, 0.3, PI - 0.3, 8, Color(0.6, 0.3, 0.3), 2.0)
