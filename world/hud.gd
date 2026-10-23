class_name WorldHud
extends CanvasLayer
## Minimal overworld HUD: party lead (name/level/HP), money, interact prompt, toasts and a dialogue box.

const GROUP := "ow_hud"
const REARM_S := 0.25  ## anti-repeat after a dialogue closes

signal advanced

var _lead: Label
var _hp: ProgressBar
var _money: Label
var _prompt: Label
var _toast: Label
var _box: PanelContainer
var _who: Label
var _text: Label
var _toast_t := 0.0
var _open := false
var _clock := 0.0  ## game time, so fixed-fps runs behave like real ones
var _closed_at := -100.0
var _line_at := 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var stats := PanelContainer.new()
	stats.position = Vector2(12, 12)
	stats.custom_minimum_size = Vector2(240, 0)
	add_child(stats)
	var v := VBoxContainer.new()
	stats.add_child(v)
	_lead = Label.new()
	v.add_child(_lead)
	_hp = ProgressBar.new()
	_hp.custom_minimum_size = Vector2(220, 14)
	_hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.85, 0.35)
	_hp.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15)
	_hp.add_theme_stylebox_override("background", bg)
	v.add_child(_hp)
	_money = Label.new()
	v.add_child(_money)
	var help := Label.new()
	help.text = "WASD anda  Shift corre  Espaço pula  E interage  Z/C câmera  Esc menu"
	help.modulate = Color(1, 1, 1, 0.6)
	help.add_theme_font_size_override("font_size", 12)
	v.add_child(help)

	_prompt = _centered_label(Control.PRESET_CENTER_BOTTOM, -170)
	_toast = _centered_label(Control.PRESET_CENTER_TOP, 16)

	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 40
	_box.offset_right = -40
	_box.offset_top = -140
	_box.offset_bottom = -20
	_box.visible = false
	add_child(_box)
	var bv := VBoxContainer.new()
	_box.add_child(bv)
	_who = Label.new()
	_who.modulate = Color(1, 0.85, 0.4)
	bv.add_child(_who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 20)
	bv.add_child(_text)


func _centered_label(preset: Control.LayoutPreset, y: float) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(preset)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = y
	l.offset_bottom = y + 30
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(l)
	return l


func _process(delta: float) -> void:
	_refresh_stats()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0
	_clock += delta
	if _open and _clock - _line_at > 0.2 \
			and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")):
		advanced.emit()


func _refresh_stats() -> void:
	_money.text = "P$%d" % Game.money
	if Game.party.is_empty():
		_lead.text = "(sem equipe)"
		_hp.value = 0
		return
	var m: Mon = Game.party[0]
	_lead.text = "%s  Nv%d   HP %d/%d   [%d na equipe]" % [m.display_name, m.level, m.hp, m.max_hp, Game.party.size()]
	_hp.max_value = maxi(m.max_hp, 1)
	_hp.value = m.hp


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != "" and not _open


func toast(text: String, secs := 2.5) -> void:
	_toast.text = text
	_toast_t = secs
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
	_box.visible = true
	_who.text = who
	_who.visible = who != ""
	for l in lines:
		_text.text = l
		_line_at = _clock
		await advanced
	_box.visible = false
	_open = false
	_closed_at = _clock
