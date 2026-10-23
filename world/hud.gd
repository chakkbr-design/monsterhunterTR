class_name WorldHud
extends CanvasLayer
## HUD do overworld no visual do original (hud.gd + party_orbs.gd): orbes da equipe no canto direito
## (anel de HP, anel de PP, nível), pílula com o nome do lugar, barra de dicas, aviso de interação,
## mensagens rápidas e a caixa de diálogo com letreiro.
## API usada pelo mundo/história: set_prompt, toast, say, is_dialog_open, can_interact, sinal advanced.

const Kit := preload("res://ui/ui_kit.gd")
const GROUP := "ow_hud"
const REARM_S := 0.25  ## anti-repeat after a dialogue closes
const TEXT_CPS := 55.0

signal advanced

var _orbs: PartyOrbs
var _loc: PanelContainer
var _loc_label: Label
var _loc_sub: Label
var _hint: Control
var _prompt: Control
var _prompt_text := ""
var _toast: Label
var _dlg: Kit.Dialog
var _toast_t := 0.0
var _open := false
var _clock := 0.0  ## game time, so fixed-fps runs behave like real ones
var _closed_at := -100.0
var _line_at := 0.0
var _world: Node = null
var _location := ""


## Coluna de orbes da equipe (party_orbs do original).
class PartyOrbs extends Control:
	const SLOT_GAP := 58.0
	const CX := 34.0
	const CY0 := 34.0
	const R_OUTER := 27.0
	const R_DISC := 23.0
	const R_EMPTY := 17.0
	var party: Array = []
	var _shown := {}
	var _flash := {}
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = panel_size()
		size = panel_size()

	func panel_size() -> Vector2:
		return Vector2(68, 6.0 * SLOT_GAP + 10.0)

	func refresh(p: Array, delta: float) -> void:
		party = p
		_t += delta
		for i in mini(party.size(), 6):
			var m: Mon = party[i]
			var hp := clampf(float(m.hp) / maxf(float(m.max_hp), 1.0), 0.0, 1.0)
			var shown := float(_shown.get(i, hp))
			if hp < shown - 0.001:
				_flash[i] = 0.2
			_shown[i] = move_toward(shown, hp, delta * 8.0)
			_flash[i] = maxf(float(_flash.get(i, 0.0)) - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var K = preload("res://ui/ui_kit.gd")
		draw_style_box(K.pill(Color(K.INK, 0.8), Color(K.PAPER, 0.12), 16), Rect2(Vector2.ZERO, panel_size()))
		for i in 6:
			var c := Vector2(CX, CY0 + i * SLOT_GAP)
			if i >= party.size():
				draw_arc(c, R_EMPTY, 0.0, TAU, 40, Color(K.RIM, 0.35), 2.0, true)
				continue
			var m: Mon = party[i]
			var fainted := m.hp <= 0
			draw_circle(c, R_DISC, Color(K.INK, 0.7))
			var ic: Texture2D = K.mon_disc(m.species, 64)
			if ic:
				draw_texture_rect(ic, Rect2(c - Vector2(22, 22), Vector2(44, 44)), false, Color(0.4, 0.4, 0.4) if fainted else Color.WHITE)
			var hp := float(_shown.get(i, 1.0))
			var col: Color = K.DIM if fainted else K.hp_color(hp)
			if float(_flash.get(i, 0.0)) > 0.0:
				col = K.PAPER
			K.draw_ring(self, c, R_DISC, 4.0, 0.0 if fainted else hp, col, Color(K.INK, 0.55))
			var ppr := clampf(m.pp / maxf(m.pp_base, 1.0), 0.0, 1.0)
			K.draw_ring(self, c, R_DISC - 4.0, 3.0, 0.0 if fainted else ppr, K.PP_BLUE, Color(K.INK, 0.45))
			if fainted:
				draw_line(c + Vector2(-R_DISC * 0.8, R_DISC * 0.8), c + Vector2(R_DISC * 0.8, -R_DISC * 0.8), K.RED, 3.0, true)
			elif m.status != "":
				draw_circle(c + Vector2(19, -19), 6.0, K.STATUS_TAGS.get(m.status, ["", K.AMBER])[1])
			var f: Font = K.body_font()
			var r := Rect2(c + Vector2(18, 20) - Vector2(13, 8), Vector2(26, 16))
			draw_style_box(K.pill(Color(K.INK, 0.9), Color.TRANSPARENT, 7), r)
			draw_string(f, Vector2(r.position.x, r.get_center().y + 4), "L%d" % m.level, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11,
				K.DIM if fainted else K.PAPER)


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var root := Control.new()
	root.theme = Kit.ui_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_loc = PanelContainer.new()
	_loc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.pill(Color(Kit.INK, 0.8), Color.TRANSPARENT, 18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_loc.add_theme_stylebox_override("panel", sb)
	_loc.visible = false
	root.add_child(_loc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", -2)
	_loc.add_child(lv)
	_loc_label = Label.new()
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loc_label.add_theme_font_override("font", Kit.title_font())
	_loc_label.add_theme_font_size_override("font_size", 20)
	_loc_label.add_theme_color_override("font_color", Kit.PAPER)
	_loc_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	lv.add_child(_loc_label)
	_loc_sub = Label.new()
	_loc_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loc_sub.add_theme_font_override("font", Kit.title_font())
	_loc_sub.add_theme_font_size_override("font_size", 14)
	_loc_sub.add_theme_color_override("font_color", Kit.RIM)
	_loc_sub.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	lv.add_child(_loc_sub)

	_orbs = PartyOrbs.new()
	root.add_child(_orbs)

	_hint = Kit.hint("Shift correr · Espaço pular · Esc menu")
	root.add_child(_hint)

	_prompt = Kit.hint("")
	_prompt.visible = false
	root.add_child(_prompt)

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -96
	_toast.offset_bottom = -50
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_color", Kit.PAPER)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_toast.visible = false
	root.add_child(_toast)

	_dlg = Kit.Dialog.new()
	_dlg.cps = TEXT_CPS
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dlg.offset_left = -400
	_dlg.offset_right = 400
	_dlg.offset_top = -168
	_dlg.offset_bottom = -22
	_dlg.visible = false
	root.add_child(_dlg)
	_layout()


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1152, 648)


func _layout() -> void:
	var vp := _vp()
	var top := 14.0
	if _loc.visible:
		var m := _loc.get_combined_minimum_size()
		_loc.size = m
		_loc.position = Vector2(vp.x - 14.0 - m.x, 14.0)
		top = 14.0 + m.y + 10.0
	_orbs.position = Vector2(vp.x - 14.0 - _orbs.panel_size().x, top)
	var hm := _hint.get_combined_minimum_size()
	_hint.size = hm
	_hint.position = vp - hm - Vector2(20, 20)
	if _prompt.visible:
		var pm := _prompt.get_combined_minimum_size()
		_prompt.size = pm
		_prompt.position = Vector2((vp.x - pm.x) * 0.5, vp.y - 120.0)


func _process(delta: float) -> void:
	_clock += delta
	var g := get_node_or_null("/root/Game")
	_orbs.refresh(g.party if g else [], delta)
	_find_world()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	var busy: bool = g != null and g.is_busy()
	_orbs.visible = not busy
	_loc.visible = _location != "" and not busy
	_hint.visible = not _open and not busy
	_layout()
	if _open and _clock - _line_at > 0.2 \
			and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")):
		if not _dlg.complete():
			_dlg.finish()
		else:
			advanced.emit()


## Liga ao location_changed da RouteWorld para mostrar o nome do lugar na pílula.
func _find_world() -> void:
	if _world != null and is_instance_valid(_world):
		return
	_world = get_tree().get_first_node_in_group("ow_root") if is_inside_tree() else null
	if _world == null:
		return
	if _world.has_signal("location_changed"):
		_world.location_changed.connect(_on_location_changed)
	if "location_kind" in _world and String(_world.location_id) != "":
		_on_location_changed(String(_world.location_kind), String(_world.location_id))


func _on_location_changed(kind: String, id: String) -> void:
	var name := id.capitalize()
	if kind == "zone" and "zones" in _world:
		name = String(_world.zones.get(id, {}).get("name", name))
	elif kind == "interior" and "interiors" in _world and _world.interiors.has(id) and _world.interiors[id].has_method("display_name"):
		name = String(_world.interiors[id].display_name())
	set_location(name)


## Nome do lugar na pílula do canto (vazio esconde).
func set_location(text: String, sub := "") -> void:
	_location = text
	_loc_label.text = text
	_loc_sub.text = sub
	_loc_sub.visible = sub != ""
	_loc.visible = text != ""
	_layout()


func location() -> String:
	return _location


## "E: Battle Rattata" -> tecla E + "Batalhar com Rattata".
func set_prompt(text: String) -> void:
	if text != _prompt_text:
		_prompt_text = text
		var key := ""
		var rest := text
		var i := text.find(":")
		if i > 0 and i <= 6:
			key = text.substr(0, i).strip_edges()
			rest = text.substr(i + 1).strip_edges()
		if rest.begins_with("Battle "):
			rest = "Batalhar com " + rest.substr(7)
		elif rest == "Talk":
			rest = "Falar"
		_prompt.text = ("%s %s" % [key, rest]) if key != "" else rest
	_prompt.visible = text != "" and not _open
	_layout()


func toast(text: String, secs := 2.5) -> void:
	_toast.text = text
	_toast_t = secs
	_toast.modulate.a = 1.0
	_toast.visible = true


func is_dialog_open() -> bool:
	return _open


## True when a fresh interact press should reach the world (no dialogue open or just closed).
func can_interact() -> bool:
	return not _open and _clock - _closed_at > REARM_S


## Shows the lines one by one (interact/jump advances) and returns when the box closes.
func say(who: String, lines: PackedStringArray) -> void:
	_open = true
	_prompt.visible = false
	_hint.visible = false
	for l in lines:
		_dlg.show_line(who, l)
		if l == lines[0]:
			Kit.pop_in(_dlg)
		_line_at = _clock
		await advanced
	_dlg.visible = false
	_open = false
	_closed_at = _clock
