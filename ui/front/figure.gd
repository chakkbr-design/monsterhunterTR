extends Control
## Personagem da introdução com o sprite do original (quadro de frente da folha 3x4):
## "prof" (Carvalho), "boy"/"girl" (treinador vermelho/verde), "rival". Pula de leve.

const SHEETS := {
	"prof": "res://original/assets/sprites/npc_oak.png",
	"boy": "res://original/assets/sprites/trainer.png",
	"girl": "res://original/assets/sprites/trainer_green.png",
	"rival": "res://original/assets/sprites/npc_rival.png",
}
const FRAME := Rect2(8, 11, 16, 20)

var kind := "prof":
	set(v):
		kind = v
		queue_redraw()
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(160, 240)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var tex: Texture2D = preload("res://ui/ui_kit.gd").sheet_frame(SHEETS.get(kind, SHEETS.prof), FRAME)
	var k := floorf(minf(size.x / FRAME.size.x, (size.y - 16.0) / FRAME.size.y))
	var s := FRAME.size * k
	var bob := absf(sin(t * 2.5)) * -4.0
	var base := Vector2((size.x - s.x) * 0.5, size.y - 10.0 - s.y)
	draw_set_transform(Vector2(size.x * 0.5, size.y - 8.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, s.x * 0.45, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if tex:
		draw_texture_rect(tex, Rect2(base + Vector2(0, bob), s), false)
