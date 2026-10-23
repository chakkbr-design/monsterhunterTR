class_name BattleHUD
extends CanvasLayer
## HUD placeholder: barras de HP e PP de 3 camadas (pool base, PP restante, stamina), golpes com cooldown e banner.

const BAR_W := 260.0
const HELP := "WASD anda  Shift corre  Espaço pula  1-4 golpes  E bolsa  Tab troca  F modo do aliado  Q bola  R foge  Z/C câmera"

var _player := {}
var _enemy := {}
var _ally := {}
var _menu: Label
var _menu_bg: PanelContainer
var _moves: Array = []
var _banner: Label
var _banner_t := 0.0
var _help: Label


func _init() -> void:
	layer = 5
	_player = _panel(Vector2(16, 16), true)
	_enemy = _panel(Vector2(-16 - BAR_W - 16, 16), false)
	var box := HBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -330
	box.offset_right = 330
	box.offset_top = -92
	box.offset_bottom = -36
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	for i in 4:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(158, 52)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 14)
		p.add_child(l)
		box.add_child(p)
		_moves.append({"panel": p, "label": l, "style": sb})
	_banner = Label.new()
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 110
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_banner)
	_help = Label.new()
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.anchor_right = 1.0
	_help.offset_top = -26
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.add_theme_font_size_override("font_size", 13)
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.text = HELP
	add_child(_help)
	_ally = _panel(Vector2(16, 112), false)
	_menu_bg = PanelContainer.new()
	_menu_bg.offset_left = 16
	_menu_bg.offset_top = 190
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0, 0, 0, 0.7)
	msb.set_corner_radius_all(6)
	msb.set_content_margin_all(10)
	_menu_bg.add_theme_stylebox_override("panel", msb)
	_menu = Label.new()
	_menu.add_theme_font_size_override("font_size", 15)
	_menu_bg.add_child(_menu)
	_menu_bg.visible = false
	add_child(_menu_bg)


func _rect(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	parent.add_child(r)
	return r


func _panel(at: Vector2, with_pp: bool) -> Dictionary:
	var root := Control.new()
	if at.x < 0:
		root.anchor_left = 1.0
		root.anchor_right = 1.0
	root.offset_left = at.x
	root.offset_top = at.y
	add_child(root)
	_rect(root, Vector2(-8, -6), Vector2(BAR_W + 16, 78 if with_pp else 58), Color(0, 0, 0, 0.55))
	var nl := Label.new()
	nl.add_theme_font_size_override("font_size", 16)
	root.add_child(nl)
	var d := {"root": root, "name": nl}
	_rect(root, Vector2(0, 26), Vector2(BAR_W, 12), Color(0.2, 0.2, 0.2))
	d.hp = _rect(root, Vector2(0, 26), Vector2(BAR_W, 12), Color(0.3, 0.9, 0.4))
	var hpl := Label.new()
	hpl.position = Vector2(0, 36)
	hpl.add_theme_font_size_override("font_size", 12)
	root.add_child(hpl)
	d.hp_label = hpl
	if with_pp:
		d.pp_base = _rect(root, Vector2(0, 56), Vector2(BAR_W, 10), Color(0.55, 0.12, 0.12))
		d.pp_max = _rect(root, Vector2(0, 56), Vector2(BAR_W, 10), Color(0.1, 0.16, 0.4))
		d.stamina = _rect(root, Vector2(0, 56), Vector2(BAR_W, 10), Color(0.3, 0.6, 1.0))
	return d


func banner(text: String, secs := 1.6) -> void:
	_banner.text = text
	_banner_t = secs
	_banner.modulate.a = 1.0


## info: {ally_mode: String, item_cd: float, menu: String (texto do menu rápido, "" = fechado)}.
func refresh(player: BattleFighter, enemy: BattleFighter, dt: float, ally: BattleFighter = null, info := {}) -> void:
	if _banner_t > 0.0:
		_banner_t -= dt
		_banner.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
	_fill(_player, player)
	_fill(_enemy, enemy)
	var has_ally := is_instance_valid(ally) and ally.active()
	_fill(_ally, ally if has_ally else null)
	if has_ally:
		_ally.name.text += "  [%s]" % info.get("ally_mode", "")
	var icd := float(info.get("item_cd", 0.0))
	_help.text = HELP + ("   item %.1fs" % icd if icd > 0.0 else "")
	var mt := String(info.get("menu", ""))
	_menu_bg.visible = mt != ""
	_menu.text = mt
	for i in 4:
		var slot: Dictionary = _moves[i]
		var has := is_instance_valid(player) and i < player.moves.size()
		slot.panel.visible = has
		if not has:
			continue
		var id: String = player.moves[i]
		var mv := Dex.move(id)
		var cd := maxf(float(player.move_cd.get(id, 0.0)), player.gcd_t)
		var txt := "%d  %s\nPP %.1f" % [i + 1, mv.get("name", id), Dex.pp_cost(mv)]
		if cd > 0.0:
			txt += "   %.1fs" % cd
		slot.label.text = txt
		var col := Dex.type_color(String(mv.get("type", "normal")))
		slot.style.bg_color = col.darkened(0.35) if cd <= 0.0 and player.pp_max >= Dex.pp_cost(mv) else col.darkened(0.8)


func _fill(d: Dictionary, f: BattleFighter) -> void:
	d.root.visible = is_instance_valid(f)
	if not is_instance_valid(f):
		return
	var st := String(BattleFighter.STATUS_SHORT.get(f.status, ""))
	if f.confusion_t > 0.0:
		st += " CNF"
	if f.stagger_t > 0.0:
		st += " TIRED"
	d.name.text = "%s  Lv%d  %s" % [f.mon.display_name, f.level, st]
	var frac := float(f.hp) / maxf(f.max_hp, 1)
	d.hp.size.x = BAR_W * frac
	d.hp.color = Color(0.3, 0.9, 0.4) if frac > 0.5 else (Color(1, 0.8, 0.2) if frac > 0.2 else Color(1, 0.3, 0.25))
	d.hp_label.text = "HP %d/%d" % [f.hp, f.max_hp]
	if d.has("stamina"):
		d.pp_max.size.x = BAR_W * f.pp_max / maxf(f.pp_base, 0.001)
		d.stamina.size.x = BAR_W * clampf(f.stamina, 0.0, f.pp_max) / maxf(f.pp_base, 0.001)
		d.stamina.color = Color(0.3, 0.6, 1.0) if f.stamina >= f.pp_max - 0.01 else Color(1.0, 0.6, 0.2)
