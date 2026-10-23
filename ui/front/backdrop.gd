extends Control
## Fundo da tela de título como no original (front/title_screen.gd): céu de entardecer em três cores,
## brasas subindo e o Charizard do original (overworld.png, 4 quadros) flutuando com sombra.

const CHARIZARD := "res://original/assets/pokemon/charizard/overworld.png"
const FRAME := 32
const SKY := [Color("2a1b3d"), Color("b8453a"), Color("f2a65a")]

var t := 0.0
## Multiplicador da animação (0 congela, útil em capturas).
var speed := 1.0

var _embers: Array = []
var _tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex = load(CHARIZARD) if ResourceLoader.exists(CHARIZARD) else null
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_embers.append(
			[
				rng.randf(),
				rng.randf(),
				rng.randf_range(0.04, 0.1),
				rng.randf_range(2.0, 5.0),
				rng.randf() * TAU
			]
		)


func _process(dt: float) -> void:
	t += dt * speed
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var y1 := h * 0.62
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([SKY[0], SKY[0], SKY[1], SKY[1]])
	)
	draw_polygon(
		PackedVector2Array([Vector2(0, y1), Vector2(w, y1), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([SKY[1], SKY[1], SKY[2], SKY[2]])
	)
	# Brasas: sobem, derivam para a direita e somem no alto.
	for e in _embers:
		var life := fposmod(e[1] + t * e[2], 1.0)
		var x: float = fposmod(e[0] + life * 0.12 + sin(t + e[4]) * 0.01, 1.0) * w
		var y := h + 10.0 - life * (h + 20.0)
		var a := (1.0 - life) * 0.9
		draw_circle(
			Vector2(x, y),
			e[3] * (1.0 - life * 0.5),
			Color(1.0, 0.75 - life * 0.35, 0.35 - life * 0.15, a)
		)
	if _tex == null:
		return
	var scale := floorf(h / 92.0)
	var s := Vector2(FRAME, FRAME) * scale
	var base := Vector2(w * 0.86 - s.x * 0.5, h * 0.3 - s.y * 0.5)
	var hover := sin(t * 2.0) * 8.0
	var c := base + Vector2(s.x * 0.5, s.y + 26.0)
	var k := 1.0 - sin(t * 2.0) * 0.08
	draw_set_transform(c, 0.0, Vector2(1.0, 0.22) * k)
	draw_circle(Vector2.ZERO, s.x * 0.4, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	var fr := int(t * 6.0) % 4
	draw_texture_rect_region(
		_tex, Rect2(base + Vector2(0, hover), s), Rect2(fr * FRAME, 0, FRAME, FRAME)
	)
