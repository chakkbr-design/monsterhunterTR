extends CanvasLayer
## Tela de carregamento (autoload Loading): fundo de tinta, Poké Ball de pixel balançando, "Loading..."
## e barra que corre, no visual do kit (ui_kit.gd). Anima sozinha a cada quadro (tempo real), então
## mesmo com o trabalho pesado fatiado em quadros nunca parece travada.
##
## Uso:
##   Loading.begin("zone")        # aparece só se o trabalho passar de `delay` (0.2 s)
##   Loading.begin_now("scene")   # aparece já (troca de cena, trabalho que bloqueia o quadro)
##   Loading.end("zone")          # some com fade (fica no mínimo MIN_SHOW na tela, sem piscar)
##   Loading.end_later("scene", 3)  # igual, depois de 3 quadros (a cena nova ainda está montando)
## Chaves diferentes se somam: a tela some quando todas terminaram.

signal shown
signal hidden

const Kit := preload("res://ui/ui_kit.gd")

const FADE_S := 0.15  ## fade in / out
const MIN_SHOW := 0.35  ## depois de aparecer, fica pelo menos isto
const MAX_HOLD := 30.0  ## segurança: uma chave esquecida solta sozinha
const CELL := 7.0  ## tamanho de um "pixel" da bola
const BALL_N := 15
const INK_DARK := Color("181c28")
const BALL_RED := Color("e0403a")
const BALL_WHITE := Color("f8f8f0")
const BALL_LINE := Color("181c28")

## Segundos que o trabalho pode durar antes da tela aparecer (os testes põem 0).
var delay := 0.2

var _holds := {}  ## key -> {"t": segundos, "delay": float, "left": quadros p/ soltar (-1: não)}
var _shown := false
var _alpha := 0.0
var _shown_for := 0.0
var _face: Control
var _cells: Array = []  ## [Color, Rect2] da bola, centrada em (0, 0)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_ball()
	_face = Face.new()
	_face.screen = self
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.visible = false
	add_child(_face)


## Começa um trabalho longo; a tela aparece se ele passar de `delay` (ou `after`, se >= 0).
func begin(key := "load", after := -1.0) -> void:
	_holds[key] = {"t": 0.0, "delay": delay if after < 0.0 else after, "left": -1}
	if _holds[key].delay <= 0.0:
		_show()


## Mostra a tela já, sem esperar o `delay`.
func begin_now(key := "load") -> void:
	begin(key, 0.0)


func end(key := "load") -> void:
	_holds.erase(key)


## Solta a chave depois de `frames` quadros.
func end_later(key := "load", frames := 2) -> void:
	if _holds.has(key):
		_holds[key].left = maxi(frames, 0)


## True enquanto a tela está (ou está sumindo ainda) na frente do jogo.
func is_showing() -> bool:
	return _shown


## True enquanto algo dela aparece na tela (inclui o fade de saída).
func is_visible_now() -> bool:
	return _face != null and _face.visible


func busy() -> bool:
	return not _holds.is_empty()


func _show() -> void:
	if _shown:
		return
	_shown = true
	_shown_for = 0.0
	if _face:
		_face.visible = true
		_face.mouse_filter = Control.MOUSE_FILTER_STOP
	shown.emit()


func _process(delta: float) -> void:
	for k in _holds.keys():
		var h: Dictionary = _holds[k]
		h.t += delta
		if h.left >= 0:
			if h.left == 0:
				_holds.erase(k)
				continue
			h.left -= 1
		elif h.t > MAX_HOLD:
			_holds.erase(k)
			continue
		if not _shown and h.t >= h.delay:
			_show()
	if _shown:
		_shown_for += delta
		if _holds.is_empty() and _shown_for >= MIN_SHOW:
			_shown = false
			if _face:
				_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hidden.emit()
	_alpha = move_toward(_alpha, 1.0 if _shown else 0.0, delta / FADE_S)
	if _face:
		_face.modulate.a = _alpha
		_face.visible = _alpha > 0.0
		if _face.visible:
			_face.queue_redraw()


func _make_ball() -> void:
	var c := (BALL_N - 1) / 2.0
	for y in BALL_N:
		for x in BALL_N:
			var d := Vector2(x - c, y - c).length()
			var col: Color
			if d > c + 0.6:
				continue
			elif d > c - 1.0 or absf(y - c) < 0.6:
				col = BALL_LINE
			elif d <= 2.6:
				col = BALL_LINE if d > 1.6 else BALL_WHITE
			elif y < c:
				col = BALL_RED
				if x - c < -2 and y - c < -3:
					col = BALL_RED.lightened(0.35)  # brilho
			else:
				col = BALL_WHITE
			_cells.append([col, Rect2((x - c - 0.5) * CELL, (y - c - 0.5) * CELL, CELL, CELL)])


## O desenho: fundo, bola balançando, texto e barra.
class Face:
	extends Control
	var screen: Node

	func _draw() -> void:
		if screen == null:
			return
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), screen.INK_DARK)
		draw_rect(Rect2(0, 0, sz.x, 6), screen.BALL_RED)
		draw_rect(Rect2(0, sz.y - 6, sz.x, 6), screen.BALL_RED)
		var t := Time.get_ticks_msec() / 1000.0
		var mid := sz * 0.5 + Vector2(0, -34)
		# Balança como uma Poké Ball de verdade: dois balanços, pausa.
		var ph := fposmod(t, 1.6)
		var ang := 0.0
		if ph < 1.0:
			ang = sin(ph * TAU * 2.0) * 0.42 * (1.0 - ph)
		draw_set_transform(mid, ang, Vector2.ONE)
		for c in screen._cells:
			draw_rect(c[1], c[0])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var txt := "Loading" + ".".repeat(int(t * 3.0) % 4)
		var f: Font = screen.Kit.title_font()
		var fs := 30
		var w := f.get_string_size("Loading...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := Vector2(mid.x - w * 0.5, mid.y + 96)
		draw_string(f, base + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		draw_string(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, screen.BALL_WHITE)
		# Barra indeterminada: um trecho corre de ponta a ponta.
		var bw := 220.0
		var bx := mid.x - bw * 0.5
		var by := mid.y + 120.0
		draw_rect(Rect2(bx - 3, by - 3, bw + 6, 18), screen.BALL_LINE)
		draw_rect(Rect2(bx, by, bw, 12), Color("3a4258"))
		var seg := 70.0
		var sx := bx + (bw + seg) * fposmod(t * 0.9, 1.0) - seg
		var x0 := maxf(sx, bx)
		var x1 := minf(sx + seg, bx + bw)
		if x1 > x0:
			draw_rect(Rect2(x0, by, x1 - x0, 12), screen.BALL_RED)
