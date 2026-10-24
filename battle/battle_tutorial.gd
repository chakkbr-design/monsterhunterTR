extends CanvasLayer
## Tutorial da batalha, porte do ui/battle_tutorial.gd do original: cartões de dica (start, cooldown,
## dodge, stat, hp) disparados pelos eventos da arena, e a LIÇÃO guiada do Prof. Carvalho na
## primeira luta com o rival (holofote nos cartões e nos golpes, golpes travados, adversário parado).
## A arena cria este nó quando opts.tutorial é verdadeiro (Story.rival_battle) e ele some no fim da luta.
## Flags: tut_<id> (cartão já visto) e tut_battle_lesson (lição dada). Respeita "dicas de batalha".

signal card_shown(id: String)
signal card_closed(id: String)

const Kit := preload("res://ui/ui_kit.gd")
const SETTINGS := "res://ui/front/settings.gd"

const CARD_IDS := ["start", "cooldown", "dodge", "stat", "hp"]

const LESSON := ["intro", "your_hp", "foe_hp", "moves", "stat", "attack"]
const LESSON_LIVE := ["moves", "stat", "attack"]

const STAT_HOLD := 3.5
const GRID_HOLD := 1.6
const MIN_SHOW := 0.35
const AUTO_DISMISS := 1.0

const TITLES := {
	"start": "Batalhas em tempo real",
	"cooldown": "Recarga",
	"dodge": "Desvie!",
	"stat": "Mudanças de atributo",
	"hp": "Pouco HP",
}
## Textos do original traduzidos, com as teclas deste port (golpes 1-4, bolsa E, Shift corre).
const BODIES := {
	"start":
	"As batalhas acontecem em tempo real! Mova o seu Pokémon com WASD e mantenha distância.\nAperte 1, 2, 3 ou 4 para usar um golpe.",
	"cooldown":
	"Todo golpe gasta PP e depois recarrega: o botão fica escuro até ficar pronto. Depois de qualquer golpe, todos os seus golpes descansam um instante, então não dá para soltar dois de uma vez.",
	"dodge": "Lá vem! Segure Shift enquanto anda para correr e sair do caminho.",
	"stat":
	"Os chips ▼ no cartão mostram os atributos que caíram, e os ▲, os que subiram. Eles voltam ao normal quando a batalha acaba.",
	"hp":
	"Seu Pokémon está ferido! Mais tarde você vai poder curá-lo no meio da batalha com Poções, pela bolsa (E).",
}
const HP_POTION := "Seu Pokémon está ferido! Aperte E para abrir a bolsa e usar uma Poção. Os itens dividem uma recarga curta."
const STAT_WORDS := {
	"atk": "o Ataque",
	"def": "a Defesa",
	"spa": "o Ataque Especial",
	"spd": "a Defesa Especial",
	"spe": "a Velocidade",
}

var arena: Node
var shown: Array = []
var shown_at: Dictionary = {}

var _current := ""
var _queue: Array = []
var _delays := {}
var _elapsed := 0.0
var _released := false
var _active := false
var _t0 := 0
var _stat_name := "um golpe"
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label

var _lesson := -1
var _lesson_t := 0.0
var _status_slot := -1
var _attack_slot := -1
var _lesson_done := false
var _spot: Spotlight
var _bubble: PanelContainer
var _bubble_body: Label
var _bubble_hint: Label

var _arrow: Label
var _arrow_at := Vector2.ZERO
var _arrow_on := false


func _init(a: Node = null) -> void:
	arena = a


func _ready() -> void:
	add_to_group("battle_tutorial")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_t0 = Time.get_ticks_msec()
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_panel = Kit.Win.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -190
	_panel.offset_bottom = -40
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # texto maior que 150 px cresce para cima
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_title = Label.new()
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_color_override("font_color", Kit.BLUE)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 62)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Kit.INK)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	v.add_child(_hint_label())
	if arena:
		for s in [["fight_started", _on_battle_started], ["move_used", _on_move_used]]:
			if arena.has_signal(s[0]):
				arena.connect(s[0], s[1])
		if arena.has_signal("hit_landed"):
			arena.hit_landed.connect(_on_hit_landed)
		if arena.has_signal("finished"):
			arena.finished.connect(_on_battle_ended)
	_build_lesson_ui()


func _hint_label() -> Label:
	var hint := Label.new()
	hint.theme_type_variation = "SmallLabel"
	hint.text = _dismiss_hint()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Kit.DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint


func _build_lesson_ui() -> void:
	_spot = Spotlight.new()
	add_child(_spot)
	_bubble = Kit.Win.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_bubble.add_child(v)
	var who := Label.new()
	who.theme_type_variation = "HeaderLabel"
	who.text = "Prof. Carvalho"
	who.add_theme_color_override("font_color", Kit.BLUE)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(who)
	_bubble_body = Label.new()
	_bubble_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_body.custom_minimum_size = Vector2(400, 0)
	_bubble_body.add_theme_color_override("font_color", Kit.INK)
	_bubble_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bubble_body)
	_bubble_hint = _hint_label()
	v.add_child(_bubble_hint)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 44)
	_arrow.add_theme_color_override("font_color", Kit.AMBER)
	_arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.0, 0.9))
	_arrow.add_theme_constant_override("outline_size", 8)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)


func _exit_tree() -> void:
	var t := get_tree()
	if t and t.paused:
		t.paused = false


# --- Quem chama ---


func show_card(id: String, force := false) -> void:
	if not BODIES.has(id):
		return
	if _current == id or _queue.has(id):
		return
	if not force and _seen(id):
		return
	_delays.erase(id)
	if _current == "":
		_show(id)
	else:
		_queue.append(id)


func is_showing() -> bool:
	return _current != ""


func current_card() -> String:
	return _current


## Passo da lição em curso ("" fora dela).
func lesson_step() -> String:
	return String(LESSON[_lesson]) if _lesson >= 0 else ""


func waiting_for_dismiss() -> bool:
	if _current != "":
		return true
	if _lesson >= 0:
		return not (String(LESSON[_lesson]) in LESSON_LIVE)
	return false


# --- Eventos da arena ---


func _on_battle_started() -> void:
	_active = true
	_t0 = Time.get_ticks_msec()
	shown.clear()
	shown_at.clear()
	_queue.clear()
	_delays.clear()
	if _should_teach():
		_start_lesson()
		return
	_trigger("start", 1.3)


func _on_battle_ended(_result = null) -> void:
	_active = false
	_current = ""
	_lesson = -1
	_queue.clear()
	_delays.clear()
	_dim.visible = false
	_panel.visible = false
	if _spot:
		_spot.clear()
	if _bubble:
		_bubble.visible = false
	if _arrow:
		_arrow.visible = false
		_arrow_on = false
	if arena and arena.has_method("clear_tut_lock"):
		arena.clear_tut_lock()
	if get_tree().paused:
		get_tree().paused = false
	queue_free()


func _partner():
	var p = arena.get("player") if arena else null
	return p if is_instance_valid(p) else null


func _foe():
	var e = arena.get("enemy") if arena else null
	return e if is_instance_valid(e) else null


func _on_move_used(user: Node, move: Dictionary) -> void:
	if _lesson >= 0:
		var step := String(LESSON[_lesson])
		if step == "moves" and user == _partner() and _is_move(move, _status_slot):
			_lesson_next()
		return
	if not _active or user == null:
		return
	if user == _partner():
		_trigger("cooldown", 0.8)
	elif user == _foe():
		if float(move.get("power", 0)) > 0.0:
			_trigger("dodge")
		elif String(move.get("category", "")) == "status" and not _seen("stat"):
			_stat_name = String(move.get("name", "um golpe"))
			_trigger("stat")


func _on_hit_landed(user: Node, target: Node, _info = null) -> void:
	if _lesson >= 0:
		if String(LESSON[_lesson]) == "attack" and user != null and user == _partner():
			_lesson_next()
		return
	if _active and target != null and target == _partner():
		_trigger("dodge")


# --- Cartões ---


## Opção "dicas de batalha" (Settings.battle_tips); opts.battle_tips da arena manda (testes).
func _tips_on() -> bool:
	var o = arena.get("opts") if arena else null
	if o is Dictionary and o.has("battle_tips"):
		return bool(o.battle_tips)
	if not ResourceLoader.exists(SETTINGS):
		return true
	var st = load(SETTINGS)
	return bool(st.load_cfg().get("battle_tips", true)) if st else true


func _flags() -> Dictionary:
	var g: Node = arena._game() if arena and arena.has_method("_game") else null
	if g == null:
		g = get_node_or_null("/root/Game")
	var f = g.get("flags") if g else null
	return f if f is Dictionary else {}


func _story() -> Node:
	return get_node_or_null("/root/Story")


func _auto_dialog() -> bool:
	var s := _story()
	return s != null and bool(s.get("auto_advance"))


func _trigger(id: String, delay := 0.0) -> void:
	if not _tips_on():
		return
	if _lesson_done:
		return
	if not BODIES.has(id) or _seen(id):
		return
	if id != "start" and _delays.has("start"):
		delay = maxf(delay, float(_delays["start"]) + 0.01)
	if delay <= 0.0:
		show_card(id)
	else:
		_delays[id] = delay


func _seen(id: String) -> bool:
	return (
		bool(_flags().get("tut_" + id, false))
		or shown.has(id)
		or _current == id
		or _queue.has(id)
		or _delays.has(id)
	)


func _show(id: String) -> void:
	_current = id
	_elapsed = 0.0
	_released = false
	shown.append(id)
	shown_at[id] = maxf(0.0, (Time.get_ticks_msec() - _t0) / 1000.0)
	_flags()["tut_" + id] = true
	_title.text = String(TITLES.get(id, ""))
	_body.text = _body_for(id)
	_dim.visible = true
	_panel.visible = true
	get_tree().paused = true
	print("[tutorial] ", id)
	card_shown.emit(id)


func _close() -> void:
	var id := _current
	_current = ""
	_elapsed = 0.0
	_released = false
	_dim.visible = false
	_panel.visible = false
	card_closed.emit(id)
	if not _queue.is_empty():
		_show(_queue.pop_front())
	else:
		get_tree().paused = false


func _body_for(id: String) -> String:
	match id:
		"stat":
			var sp := "O adversário"
			var f = _foe()
			if f and f.get("mon"):
				sp = String(f.mon.display_name)
			return "%s usou %s!" % [sp, _stat_name] + "\n" + String(BODIES.get(id, ""))
		"hp":
			var g: Node = arena._game() if arena and arena.has_method("_game") else null
			if g and g.get("bag") is Dictionary and int(g.bag.get("potion", 0)) > 0:
				return HP_POTION
	return String(BODIES.get(id, ""))


func _process(delta: float) -> void:
	if _lesson >= 0:
		_process_lesson(delta)
		return
	for id in _delays.keys():
		_delays[id] = float(_delays[id]) - delta
		if float(_delays[id]) <= 0.0:
			_delays.erase(id)
			show_card(id)
	if _current != "":
		_elapsed += delta
		if _released:
			if not _dismiss_held():
				_close()
		elif (
			_elapsed >= MIN_SHOW
			and (_dismiss_pressed() or (_auto_dialog() and _elapsed >= AUTO_DISMISS))
		):
			_released = true
		return
	if get_tree().paused or not _active or String(arena.get("state")) != "fight":
		return
	var p = _partner()
	if p == null:
		return
	if int(p.max_hp) > 0 and int(p.hp) < 0.5 * float(p.max_hp):
		_trigger("hp")


func _dismiss_pressed() -> bool:
	for a in ["interact", "ui_accept"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _dismiss_held() -> bool:
	for a in ["interact", "ui_accept"]:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


func _dismiss_hint() -> String:
	return "[E] OK"


# --- Lição ---


func _should_teach() -> bool:
	if not _tips_on() or _auto_dialog():
		return false
	var story := _story()
	if story != null and bool(story.get("auto_battle")):
		return false
	var f := _flags()
	if bool(f.get("tut_battle_lesson", false)) or bool(f.get("rival_battle_done", false)):
		return false
	return String(arena.get("opts").get("trainer_class", "")) == "rival"


func _start_lesson() -> void:
	var f := _flags()
	f["tut_battle_lesson"] = true
	f["tut_start"] = true
	_pick_lesson_moves()
	print("[tutorial] lesson start (status slot %d, attack slot %d)" % [_status_slot, _attack_slot])
	_lesson = 0
	_enter_lesson()


func _pick_lesson_moves() -> void:
	_status_slot = -1
	_attack_slot = -1
	var p = _partner()
	if p == null:
		return
	var ids: Array = p.moves
	for k in mini(ids.size(), 4):
		var mv := Dex.move(String(ids[k]))
		if (
			_status_slot < 0
			and String(mv.get("category", "")) == "status"
			and int(mv.get("stages", 0)) < 0
		):
			_status_slot = k
		elif _attack_slot < 0 and float(mv.get("power", 0.0)) > 0.0:
			_attack_slot = k
	if _status_slot < 0:
		_status_slot = _attack_slot
	if _attack_slot < 0:
		_attack_slot = _status_slot


func _lock(on: bool, move := -1, walk := false) -> void:
	if arena == null or not arena.has_method("clear_tut_lock"):
		return
	arena.clear_tut_lock()
	if on:
		arena.tut_locked = true
		arena.tut_hold_foe = true
		arena.tut_move = move
		arena.tut_walk = walk


func _enter_lesson() -> void:
	var step := String(LESSON[_lesson])
	var live := step in LESSON_LIVE
	_lesson_t = 0.0
	_elapsed = 0.0
	_released = false
	get_tree().paused = false
	if step == "moves":
		_lock(true, _status_slot)
	elif step == "attack":
		_lock(true, _attack_slot, true)
	else:
		_lock(true)
	_dim.visible = false
	_panel.visible = false
	var target := _lesson_target(step)
	if step == "attack":
		_spot.clear()
	else:
		_spot.target(target)
	_set_arrow(step)
	_bubble_body.text = _lesson_line(step)
	_bubble_hint.visible = not live
	_bubble.visible = true
	_place_bubble(target)
	print("[tutorial] lesson ", step)
	card_shown.emit("lesson_" + step)


func _lesson_next() -> void:
	_lesson += 1
	if _lesson >= LESSON.size():
		_end_lesson()
	else:
		_enter_lesson()


func _end_lesson() -> void:
	_lesson = -1
	_lesson_done = true
	_spot.clear()
	_bubble.visible = false
	_arrow.visible = false
	_arrow_on = false
	if get_tree().paused:
		get_tree().paused = false
	_lock(false)
	print("[tutorial] lesson done")
	card_closed.emit("lesson")


func _process_lesson(delta: float) -> void:
	_lesson_t += delta
	_elapsed += delta
	_process_arrow()
	var step := String(LESSON[_lesson])
	if step == "attack":
		return
	if step == "moves":
		if _lesson_t >= GRID_HOLD:
			var one := _lesson_target("moves_one")
			if one.size.x > 0.0:
				_spot.target(one)
		return
	if step == "stat":
		var chips := _lesson_target("stat")
		if chips.size.x > 0.0:
			_spot.target(chips)
	var done := (
		_lesson_t >= STAT_HOLD if step == "stat" else (_elapsed >= MIN_SHOW and _dismiss_pressed())
	)
	if done or (_auto_dialog() and _lesson_t >= AUTO_DISMISS):
		_lesson_next()


func _hud():
	var h = arena.get("hud") if arena else null
	return h if is_instance_valid(h) and h.has_method("move_rect") else null


func _lesson_target(step: String) -> Rect2:
	var bh = _hud()
	if bh == null:
		return Rect2()
	match step:
		"your_hp":
			return bh.card_rect("you")
		"foe_hp":
			return bh.card_rect("foe")
		"moves":
			return bh.moves_rect()
		"moves_one":
			return bh.move_rect(_status_slot)
		"stat":
			return bh.foe_chips_rect()
		"attack":
			return bh.move_rect(_attack_slot)
	return Rect2()


func _set_arrow(step: String) -> void:
	var slot := -1
	if step == "moves":
		slot = _status_slot
	elif step == "attack":
		slot = _attack_slot
	var bh = _hud()
	var r: Rect2 = bh.move_rect(slot) if bh and slot >= 0 else Rect2()
	if r.size.x <= 0.0:
		_arrow_on = false
		_arrow.visible = false
		return
	_arrow_on = true
	_arrow.visible = true
	_arrow_at = Vector2(r.get_center().x, r.position.y - 4.0)


func _process_arrow() -> void:
	if not _arrow_on:
		return
	_arrow.reset_size()
	var m := _arrow.get_combined_minimum_size()
	var bob := sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.1) * 4.0
	_arrow.position = Vector2(_arrow_at.x - m.x * 0.5, _arrow_at.y - m.y + bob)


func _lesson_line(step: String) -> String:
	match step:
		"intro":
			return "Aqui as batalhas não esperam a vez: elas acontecem em tempo real. Você se move, e o seu Pokémon também."
		"your_hp":
			return "Aqui está a vida do seu Pokémon. Se essa barra esvaziar, ele está fora da luta."
		"foe_hp":
			return "E aqui está a vida do adversário: é ela que você precisa esvaziar."
		"moves":
			if _status_slot < 0:
				return "Estes são os seus quatro golpes, uma tecla para cada."
			return (
				"Estes são os seus quatro golpes, uma tecla para cada. Comece com %s: %s"
				% [_move_name(_status_slot), _stat_line(_status_slot)]
			)
		"stat":
			var w := _stat_word(_status_slot)
			if w == "":
				w = "o atributo"
			return (
				"Viu o ▼? %s do adversário caiu, e isso vale até o fim da batalha."
				% (w.left(1).to_upper() + w.substr(1))
			)
		"attack":
			if _attack_slot < 0:
				return "Agora ataque!"
			return (
				"Agora ataque! Chegue perto e aperte %s para usar %s."
				% [_move_key(_attack_slot), _move_name(_attack_slot)]
			)
	return ""


func _move_def(slot: int) -> Dictionary:
	var p = _partner()
	if p == null or slot < 0 or slot >= p.moves.size():
		return {}
	return Dex.move(String(p.moves[slot]))


func _move_name(slot: int) -> String:
	return String(_move_def(slot).get("name", "o seu golpe"))


func _stat_line(slot: int) -> String:
	var w := _stat_word(slot)
	return "ele diminui %s do adversário." % w if w != "" else "ele enfraquece o adversário."


func _stat_word(slot: int) -> String:
	return String(STAT_WORDS.get(String(_move_def(slot).get("stat", "")), ""))


func _move_key(slot: int) -> String:
	if slot < 0 or slot >= 4:
		return "?"
	return str(slot + 1)


func _is_move(move: Dictionary, slot: int) -> bool:
	var want := _move_def(slot)
	if want.is_empty():
		return false
	var a := String(move.get("id", move.get("name", "")))
	var b := String(want.get("id", want.get("name", "")))
	return a != "" and a == b


func _place_bubble(rect: Rect2) -> void:
	_bubble.reset_size()
	var min_size := _bubble.get_combined_minimum_size()
	_bubble.size = Vector2(maxf(min_size.x, 440.0), min_size.y)
	var vp := get_viewport().get_visible_rect().size
	var at := Vector2(vp.x * 0.5 - _bubble.size.x * 0.5, 150.0)
	if rect.size.x > 0.0:
		# 340 de 720 no original: acima disso a fala vai embaixo do alvo, abaixo vai em cima.
		var mid := vp.y * 340.0 / 720.0
		at.x = clampf(
			rect.get_center().x - _bubble.size.x * 0.5,
			16.0,
			maxf(16.0, vp.x - _bubble.size.x - 16.0)
		)
		at.y = (
			rect.end.y + 14.0 if rect.position.y < mid else rect.position.y - _bubble.size.y - 14.0
		)
		if _arrow_on and rect.position.y >= mid:
			at.y -= _arrow.get_combined_minimum_size().y
	_bubble.position = at


## Holofote (pk_spotlight.gd do original): escurece a tela toda menos um retângulo, com aro âmbar.
class Spotlight:
	extends Control
	const PAD := 8.0
	const DIM := Color(0, 0, 0, 0.62)
	const LIFT := 0.14
	const FADE := 0.18
	const AMBER := Color("e8b030")

	var _hole := Rect2()
	var _alpha := 0.0
	var _want := false

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		resized.connect(queue_redraw)

	func target(rect: Rect2) -> void:
		_hole = rect.grow(PAD) if rect.size.x > 0.0 else Rect2()
		_want = true
		visible = true
		queue_redraw()

	func clear() -> void:
		_want = false
		queue_redraw()

	func hole() -> Rect2:
		return _hole if _want else Rect2()

	func _process(delta: float) -> void:
		var was := _alpha
		_alpha = move_toward(_alpha, 1.0 if _want else 0.0, delta / FADE)
		if is_equal_approx(was, _alpha):
			if _alpha <= 0.0 and visible:
				visible = false
			return
		queue_redraw()

	func _draw() -> void:
		var a := DIM * _alpha
		if _hole.size.x <= 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), a)
			return
		var h := _hole
		draw_rect(Rect2(0.0, 0.0, size.x, h.position.y), a)
		draw_rect(Rect2(0.0, h.end.y, size.x, size.y - h.end.y), a)
		draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), a)
		draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), a)
		draw_rect(h, Color(1.0, 0.97, 0.88, LIFT * _alpha))
		var rim := Color(AMBER.r, AMBER.g, AMBER.b, _alpha)
		draw_rect(h.grow(1.0), rim.darkened(0.55), false, 3.0)
		draw_rect(h.grow(4.0), rim, false, 5.0)
		draw_rect(h.grow(11.0), Color(rim.r, rim.g, rim.b, 0.22 * _alpha), false, 8.0)
