extends Control
## Fundo animado da tela de título, todo desenhado em código: céu de entardecer, sol,
## estrelas, nuvens, morros em paralaxe e uma criaturinha que espia do morro da frente.

var t := 0.0
## Multiplicador da animação (0 congela, útil em capturas).
var speed := 1.0

var _stars: Array = []
var _motes: Array = []
var _clouds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.45), rng.randf_range(0.8, 2.0), rng.randf() * TAU])
	for i in 26:
		_motes.append([rng.randf(), rng.randf(), rng.randf_range(0.01, 0.03), rng.randf() * TAU])
	for i in 6:
		_clouds.append([rng.randf(), rng.randf_range(0.08, 0.3), rng.randf_range(0.6, 1.3), rng.randf_range(0.004, 0.012)])


func _process(dt: float) -> void:
	t += dt * speed
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var horizon := h * 0.62
	# Céu: três faixas de gradiente.
	var top := Color(0.07, 0.09, 0.22)
	var mid := Color(0.32, 0.27, 0.52)
	var low := Color(0.98, 0.62, 0.42)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.38), Vector2(0, h * 0.38)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.38), Vector2(w, h * 0.38), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid, mid, low, low]))
	# Estrelas piscando.
	for s in _stars:
		var a := 0.35 + 0.35 * sin(t * 1.7 + s[2])
		draw_circle(Vector2(s[0].x * w, s[0].y * h), s[1], Color(1, 1, 0.95, a))
	# Sol com halo.
	var sun := Vector2(w * 0.3, horizon - h * 0.06 + sin(t * 0.2) * 4.0)
	for i in 5:
		draw_circle(sun, h * (0.09 + 0.045 * i), Color(1.0, 0.8, 0.5, 0.07))
	draw_circle(sun, h * 0.085, Color(1.0, 0.86, 0.58))
	# Nuvens à deriva.
	for c in _clouds:
		var cx := fposmod(c[0] + t * c[3], 1.3) * w - w * 0.15
		var cy: float = c[1] * h
		var k: float = c[2] * h * 0.05
		var col := Color(1.0, 0.85, 0.8, 0.35)
		draw_circle(Vector2(cx, cy), k, col)
		draw_circle(Vector2(cx + k * 1.1, cy + k * 0.2), k * 0.8, col)
		draw_circle(Vector2(cx - k * 1.1, cy + k * 0.25), k * 0.7, col)
	# Morros em três camadas (o de trás anda mais devagar).
	_hill(horizon - h * 0.04, h * 0.05, 0.004, 3.0, t * 6.0, Color(0.36, 0.3, 0.5))
	_hill(horizon + h * 0.06, h * 0.06, 0.006, 1.0, t * 14.0, Color(0.2, 0.32, 0.42))
	var front_y := horizon + h * 0.2
	_hill(front_y, h * 0.04, 0.009, 5.0, t * 28.0, Color(0.11, 0.2, 0.24))
	_critter(Vector2(w * 0.78, front_y + _hill_y(w * 0.78, h * 0.04, 0.009, 5.0, t * 28.0) + 4.0), h * 0.055)
	# Vaga-lumes subindo.
	for m in _motes:
		var y := fposmod(m[1] - t * m[2], 1.0)
		var x: float = m[0] + sin(t * 0.8 + m[3]) * 0.01
		var a := 0.6 * sin(y * PI)
		draw_circle(Vector2(x * w, h * (0.55 + y * 0.45)), 2.2, Color(1.0, 0.95, 0.55, a))


func _hill_y(x: float, amp: float, freq: float, phase: float, scroll: float) -> float:
	var u := x + scroll
	return -amp * (sin(u * freq + phase) + 0.5 * sin(u * freq * 2.3 + phase * 1.7))


func _hill(base: float, amp: float, freq: float, phase: float, scroll: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var step := 16.0
	var x := 0.0
	while x <= size.x + step:
		pts.append(Vector2(x, base + _hill_y(x, amp, freq, phase, scroll)))
		x += step
	pts.append(Vector2(size.x + step, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, col)


## Silhueta original: bolinha de orelhas compridas que balança e pisca.
func _critter(feet: Vector2, r: float) -> void:
	var bob := sin(t * 2.2) * r * 0.06
	var c := feet + Vector2(0, -r + bob)
	var body := Color(0.08, 0.13, 0.16)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.6), c + Vector2(-r * 0.95, -r * 1.9 + sin(t * 1.3) * r * 0.1), c + Vector2(-r * 0.1, -r * 0.85)]), body)
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r * 0.85), c + Vector2(r * 0.85, -r * 1.85), c + Vector2(r * 0.6, -r * 0.55)]), body)
	draw_circle(c, r, body)
	draw_circle(c + Vector2(r * 0.9, r * 0.5), r * 0.25, body)
	var blink := fposmod(t, 4.0) > 3.85
	var eye := Color(1.0, 0.9, 0.6)
	for ex in [-0.35, 0.3]:
		var p := c + Vector2(r * ex, -r * 0.15)
		if blink:
			draw_line(p - Vector2(r * 0.12, 0), p + Vector2(r * 0.12, 0), eye, 2.0)
		else:
			draw_circle(p, r * 0.13, eye)
