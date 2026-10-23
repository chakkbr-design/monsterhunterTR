extends CanvasLayer
## Tela de evolução (autoload Evolution). Resolve Game.pending_evolutions inteira, um Pokémon por vez:
## "O quê? X está evoluindo!" → animação (silhueta antiga alternando com a nova, cada vez mais rápido,
## clarão e partículas) → "Parabéns! X evoluiu para Y!" → Game.resolve_evolution(mon, true).
## Esc/Q (apertar ou segurar) durante a animação cancela → Game.resolve_evolution(mon, false).
## A LearnMove espera esta tela terminar a fila (golpes que não couberam na evolução vêm depois).

const Kit := preload("res://ui/ui_kit.gd")
const INTRO := 1.4  # segundos mostrando "O quê?..." antes da animação (E/Enter pula)
const DURATION := 5.0  # animação inteira, como no original
const BURST := 1.2  # duração do clarão final
const MSG_MIN := 0.4  # tempo mínimo na mensagem final antes de aceitar a tecla

## Instâncias injetáveis (testes). Vazias = autoloads /root/Game e /root/LearnMove.
var game: Node = null
var learn: Node = null
## "" fechado | "intro" | "anim" | "done" (evoluiu) | "cancelled" (parou)
var state := ""
var message := ""
var mon: Mon = null
var from_species := ""
var into := ""
## Tempo no estado atual (segundos).
var t := 0.0

var _root: Control
var _stage: Control
var _label: Label
var _hint: Control
var _closed_at := -1
var _parts: Array = []  # partículas: {p: Vector2 (polar a, r) ou pos, v, life, max, size, out}
var _rng := RandomNumberGenerator.new()
var _spawn_acc := 0.0


## Desenha a cena no próprio Control (o CanvasLayer não tem _draw).
class Stage:
	extends Control
	var ui: Node

	func _draw() -> void:
		ui._draw_stage(self)


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	if game == null:
		game = get_node_or_null("/root/Game")
	if game:
		game.evolution_requested.connect(_on_evolution_requested)
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.theme = Kit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_stage = Stage.new()
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.ui = self
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -150
	panel.offset_bottom = -40
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_label = Kit.label("", Kit.TEXT, 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_label)
	_hint = Kit.hint("")
	col.add_child(_hint)


## Verdadeiro também no frame em que fechou, para a tecla de confirmar não vazar para o overworld.
func is_open() -> bool:
	return state != "" or Engine.get_process_frames() == _closed_at


func _on_evolution_requested() -> void:
	_try_open()


func _learn_open() -> bool:
	if learn == null:
		learn = get_node_or_null("/root/LearnMove")
	return learn != null and learn.state != ""


func _try_open() -> void:
	if state != "" or game == null or game.is_busy() or _learn_open():
		return
	while not game.pending_evolutions.is_empty():
		var m: Mon = game.pending_evolutions[0]
		if m.evolution_target() != "" and not m.is_fainted():
			_begin(m)
			return
		game.pending_evolutions.erase(m)  # não pode mais evoluir: só sai da fila


func _begin(m: Mon) -> void:
	mon = m
	from_species = m.species
	into = m.evolution_target()
	_parts.clear()
	_spawn_acc = 0.0
	_set_state("intro", "O quê? %s está evoluindo!" % m.display_name)
	_root.visible = true


func _set_state(s: String, msg: String) -> void:
	state = s
	t = 0.0
	message = msg
	_label.text = msg
	match s:
		"intro":
			_hint.text = "E/Enter: continuar · Esc/Q: parar a evolução"
		"anim":
			_hint.text = "Esc/Q: parar a evolução"
			preload("res://audio/cue.gd").sfx("evolution")
		_:
			_hint.text = "E/Enter: continuar"
	_stage.queue_redraw()


func _process(dt: float) -> void:
	if state == "":
		if game and not game.pending_evolutions.is_empty():
			_try_open()
		return
	if state == "anim" and _cancel_held():
		_cancel()
	advance(dt)


## Segurar Esc/Q também cancela (o _input só vê o aperto).
func _cancel_held() -> bool:
	return Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_Q)


## Avança o tempo da tela (o _process chama; os testes chamam direto para pular a animação).
func advance(dt: float) -> void:
	if state == "":
		return
	t += dt
	match state:
		"intro":
			if t >= INTRO:
				_set_state("anim", message)
		"anim":
			var k := clampf(t / DURATION, 0.0, 1.0)
			_spawn_acc += dt * lerpf(10.0, 60.0, k)
			while _spawn_acc >= 1.0:
				_spawn_acc -= 1.0
				_spawn_inward()
			if t >= DURATION:
				_complete()
	_update_parts(dt)
	_stage.queue_redraw()


func _input(ev: InputEvent) -> void:
	if state == "":
		return
	var a := Kit.nav(ev)
	if a == "":
		return
	get_viewport().set_input_as_handled()
	press(a)


## Aplica uma ação ("ok" "back"; setas são ignoradas). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	preload("res://audio/cue.gd").ui(a)
	match state:
		"intro":
			if a == "back":
				_cancel()
			elif a == "ok":
				_set_state("anim", message)
		"anim":
			if a == "back":
				_cancel()
		"done", "cancelled":
			if a in ["ok", "back"] and t >= MSG_MIN:
				_next()


func _complete() -> void:
	var old_name := mon.display_name
	game.resolve_evolution(mon, true)
	into = mon.species
	_set_state("done", "Parabéns! %s evoluiu para %s!" % [old_name, into])
	preload("res://audio/cue.gd").sfx("item_get")
	for i in 70:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(120.0, 420.0)
		_parts.append(
			{
				"pos": Vector2.ZERO,
				"v": Vector2.from_angle(a) * sp,
				"life": 0.0,
				"max": _rng.randf_range(0.7, 1.4),
				"size": _rng.randf_range(2.0, 5.0),
				"out": true
			}
		)


func _cancel() -> void:
	game.resolve_evolution(mon, false)
	_set_state("cancelled", "%s parou de evoluir." % mon.display_name)
	_parts.clear()


func _next() -> void:
	state = ""
	_try_open()
	if state == "":
		_close()


func _close() -> void:
	state = ""
	_closed_at = Engine.get_process_frames()
	message = ""
	mon = null
	_parts.clear()
	_root.visible = false


# --- Partículas ---------------------------------------------------------------


## Brilhos que nascem num anel e espiralam para o Pokémon.
func _spawn_inward() -> void:
	_parts.append(
		{
			"a": _rng.randf() * TAU,
			"r": _rng.randf_range(220.0, 320.0),
			"life": 0.0,
			"max": _rng.randf_range(0.8, 1.4),
			"size": _rng.randf_range(1.5, 4.0),
			"out": false,
			"spin": _rng.randf_range(1.0, 2.5)
		}
	)


func _update_parts(dt: float) -> void:
	var keep: Array = []
	for p in _parts:
		p.life += dt
		if p.out:
			p.pos += p.v * dt
			p.v *= 0.97
		else:
			p.a += p.spin * dt
			p.r -= 200.0 * dt
		if p.life < p.max and (p.out or p.r > 12.0):
			keep.append(p)
	_parts = keep


# --- Desenho ------------------------------------------------------------------


func _draw_stage(c: Control) -> void:
	if state == "" or mon == null:
		return
	var center := c.size * Vector2(0.5, 0.42)
	var base := minf(c.size.x, c.size.y) * 0.17
	var old_col := _type_color(from_species)
	var new_col := _type_color(into)
	var glow := 0.0  # quanto a silhueta já está "acesa" (0..1)
	var show_new := false
	var light := 0.0  # brilho do halo atrás

	match state:
		"intro":
			glow = clampf(t / INTRO, 0.0, 1.0) * 0.3
			light = glow
		"anim":
			glow = clampf(t / 0.8, 0.0, 1.0)
			var k := clampf((t - 1.0) / (DURATION - 1.0), 0.0, 1.0)
			if t > 1.0:
				var freq := lerpf(1.5, 12.0, k * k)
				show_new = fmod((t - 1.0) * freq, 1.0) > 0.5
			light = 0.35 + 0.65 * k
		"done":
			show_new = true
			glow = clampf(1.0 - t / BURST, 0.0, 1.0)
			light = glow
		"cancelled":
			glow = 0.0

	# Halo atrás da silhueta.
	if light > 0.0:
		var pulse := 1.0 + 0.06 * sin(t * 9.0)
		for i in 14:
			var rr := base * (1.5 + i * 0.15) * pulse
			c.draw_circle(center, rr, Color(1.0, 0.95, 0.75, 0.035 * light))

	var sp := into if show_new else from_species
	var col := new_col if show_new else old_col
	var sz := base * (1.18 if show_new else 1.0)
	col = col.lerp(Color(1, 1, 0.95), glow * 0.45)
	var tex: Texture2D = Kit.mon_front(sp)
	if tex:
		# Sprite do original; o brilho (modulate acima de 1) o deixa branco como na evolução clássica.
		var px := floorf(base * 2.6 / tex.get_height()) * tex.get_height()
		var ts := (
			Vector2(tex.get_width(), tex.get_height())
			* (px / tex.get_height())
			* (1.0 if show_new else 0.9)
		)
		var w := 1.0 + glow * 6.0
		c.draw_texture_rect(tex, Rect2(center - ts * 0.5, ts), false, Color(w, w, w))
	else:
		var pts := _shape(sp, center, sz)
		c.draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		c.draw_polyline(outline, col.lightened(0.5), 3.0, true)

	# Partículas.
	for p in _parts:
		var f: float = 1.0 - p.life / p.max
		var pos: Vector2 = center + (p.pos if p.out else Vector2.from_angle(p.a) * p.r)
		var pc := Color(1.0, 0.97, 0.7, f) if p.out else Color(0.8, 0.95, 1.0, f).lerp(col, 0.3)
		c.draw_circle(pos, p.size * (0.5 + f), pc)

	# Clarão final: tela branca que some, anel que cresce e raios.
	if state == "done" and t < BURST:
		var b := 1.0 - t / BURST
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.85 * b * b))
		var ring := base * (1.2 + t * 6.0)
		c.draw_arc(center, ring, 0.0, TAU, 64, Color(1, 0.95, 0.7, b), 6.0 * b + 1.0, true)
		for i in 12:
			var dir := Vector2.from_angle(i * TAU / 12.0 + t)
			c.draw_line(
				center + dir * base * 1.3,
				center + dir * ring * 1.4,
				Color(1, 1, 0.85, 0.6 * b),
				3.0,
				true
			)


func _main_type(species: String) -> String:
	var ts: Array = Dex.species(species).get("types", ["normal"])
	return String(ts[0]) if not ts.is_empty() else "normal"


func _type_color(species: String) -> Color:
	return Dex.type_color(_main_type(species))


## Silhueta própria por tipo, em coordenadas polares (θ = -π/2 é para cima). Desenhada em código, sem arte.
## Cada espécie ganha um detalhe próprio (espinhos, ondulação), para a forma nova não repetir a antiga
## quando as duas têm o mesmo tipo (Charmander → Charmeleon).
func _shape(species: String, center: Vector2, s: float) -> PackedVector2Array:
	var type := _main_type(species)
	var h := absi(hash(species))
	var spikes := 3 + h % 5
	var spike_at := float(h % 360) / 360.0 * TAU
	var stage := 0.0
	var evo: Dictionary = Dex.species(species).get("evolution", {})
	if evo.is_empty():
		stage = 1.0  # forma final: mais detalhes
	var out := PackedVector2Array()
	var n := 120
	for i in n:
		var th := -PI + TAU * i / n
		var r := _radius(type, th)
		r += (0.05 + 0.05 * stage) * maxf(0.0, sin(th * spikes + spike_at))
		r += 0.18 * _bump(th, spike_at, 0.12) * (1.0 + stage)
		out.append(center + Vector2.from_angle(th) * r * s)
	return out


func _bump(th: float, at: float, width: float) -> float:
	var d := wrapf(th - at, -PI, PI)
	return exp(-pow(d / width, 2.0))


func _radius(type: String, th: float) -> float:
	var up := -PI / 2.0
	match type:
		"fire":  # chama: ponta alta e duas línguas laterais
			return (
				0.7
				+ 0.75 * _bump(th, up, 0.3)
				+ 0.35 * _bump(th, up - 0.85, 0.18)
				+ 0.35 * _bump(th, up + 0.85, 0.18)
			)
		"water":  # gota
			return 0.75 + 0.7 * _bump(th, up, 0.22)
		"grass", "bug":  # folha inclinada
			var phi := th + PI / 4.0
			return (
				1.15
				/ sqrt(pow(cos(phi) / 1.0, 2.0) + pow(sin(phi) / 0.5, 2.0))
				* (1.0 + 0.25 * _bump(th, -PI / 4.0, 0.2))
			)
		"electric":  # estrela serrilhada
			var tri := absf(fmod((th + PI) * 7.0 / TAU, 1.0) - 0.5) * 2.0
			return 0.6 + 0.55 * tri
		"rock", "ground", "steel":  # hexágono
			var seg := PI / 3.0
			return 0.95 * cos(seg / 2.0) / cos(fposmod(th, seg) - seg / 2.0)
		"ice":  # floco de seis pontas
			return 0.65 + 0.45 * pow(absf(cos(3.0 * th)), 4.0)
		"poison", "ghost", "dark", "psychic":  # fantasma: topo redondo, barra ondulada
			return 1.0 if sin(th) < 0.0 else 0.9 + 0.18 * sin(6.0 * th)
		"flying", "dragon":  # corpo com asas abertas
			return (
				0.6
				+ 0.75 * _bump(th, -0.35, 0.28)
				+ 0.75 * _bump(th, PI + 0.35, 0.28)
				+ 0.2 * _bump(th, up, 0.3)
			)
		"fairy":  # estrela suave de cinco pontas
			return 0.7 + 0.35 * pow(absf(cos(2.5 * (th - up))), 2.0)
	# normal, fighting e o resto: bolinha com duas orelhas
	return 0.85 + 0.5 * _bump(th, up - 0.6, 0.13) + 0.5 * _bump(th, up + 0.6, 0.13)
