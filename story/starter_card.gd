class_name StarterCard
extends CanvasLayer
## Cartão de escolha da história: mostra (opcional) uma espécie — nome, tipos, categoria e descrição de
## species.json — e uma pergunta Sim/Não. ←/→ (ou A/D) muda, E/Espaço confirma.
## Uso: var ok: bool = await StarterCard.open(parent, "Escolher?", "Charmander")

signal answered(yes: bool)

const TYPE_COLORS := {
	"grass": Color(0.35, 0.7, 0.3), "fire": Color(0.92, 0.45, 0.2), "water": Color(0.3, 0.55, 0.92),
	"poison": Color(0.6, 0.35, 0.7), "normal": Color(0.62, 0.62, 0.5), "flying": Color(0.55, 0.6, 0.9),
}
const ARM_S := 0.2  ## ignora o aperto de E que abriu o cartão

var species := ""
var question := ""
var choice := true
var _age := 0.0
var _yes: Button
var _no: Button
var _done := false


static func open(parent: Node, q: String, sp := "") -> bool:
	var c := StarterCard.new()
	c.species = sp
	c.question = q
	parent.add_child(c)
	var yes: bool = await c.answered
	c.queue_free()
	return yes


func _ready() -> void:
	layer = 20
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.96, 0.92, 0.97)
	sb.border_color = Color(0.22, 0.28, 0.4)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	if species != "":
		_species_block(v)
	var q := _label(Game.fill_names(question), 20, Color(0.1, 0.1, 0.15))
	v.add_child(q)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	v.add_child(h)
	_yes = Button.new()
	_yes.text = "Sim"
	_yes.custom_minimum_size = Vector2(120, 36)
	_yes.pressed.connect(_answer.bind(true))
	h.add_child(_yes)
	_no = Button.new()
	_no.text = "Não"
	_no.custom_minimum_size = Vector2(120, 36)
	_no.pressed.connect(_answer.bind(false))
	h.add_child(_no)
	_refresh()


func _species_block(v: VBoxContainer) -> void:
	var d := Dex.species(species)
	var name_l := _label(String(d.get("name", species)), 30, Color(0.1, 0.1, 0.15))
	v.add_child(name_l)
	v.add_child(_label(String(d.get("category", "Pokémon")), 15, Color(0.35, 0.36, 0.42)))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	v.add_child(th)
	for t in d.get("types", []):
		var pill := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = TYPE_COLORS.get(String(t), Color(0.5, 0.5, 0.5))
		ps.set_corner_radius_all(8)
		ps.set_content_margin_all(4)
		ps.content_margin_left = 10
		ps.content_margin_right = 10
		pill.add_theme_stylebox_override("panel", ps)
		pill.add_child(_label(String(t).to_upper(), 13, Color.WHITE))
		th.add_child(pill)
	var fl := _label(String(d.get("flavor", "")), 15, Color(0.16, 0.16, 0.2))
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(520, 0)
	v.add_child(fl)


func _label(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _refresh() -> void:
	_yes.text = ("> Sim" if choice else "Sim")
	_no.text = ("Não" if choice else "> Não")


func _process(delta: float) -> void:
	_age += delta
	if _done or _age < ARM_S:
		return
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		choice = true
		_refresh()
	elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		choice = false
		_refresh()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		_answer(choice)


func _answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit.call_deferred(yes)
