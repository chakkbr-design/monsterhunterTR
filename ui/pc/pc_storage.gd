extends CanvasLayer
## PC de armazenamento (autoload PCStorage). Os terminais de PC do mundo chamam PCStorage.open().
## Telas: menu (Guardar, Retirar, Mover/organizar, Sair), caixas (8 × 30, Game.pc é uma lista única:
## a caixa i guarda os índices [i*30, i*30+30)), equipe (guardar ou reordenar), ações, confirmação e mensagem.
## Não pausa a árvore: o jogador do overworld consulta PCStorage.is_open() para não andar.

const Kit := preload("res://ui/ui_kit.gd")
const ENTRIES := ["Guardar Pokémon", "Retirar Pokémon", "Mover/organizar", "Sair"]
const ACTIONS := ["Retirar", "Soltar", "Cancelar"]
const COLS := 6
const PARTY_W := [170, 70, 120, 50]
const SLOT_SIZE := Vector2(104, 76)

## Instância injetável (testes). Vazia = autoload /root/Game.
var game: Node = null
## "" fechado | "menu" | "box" | "action" | "confirm" | "party" | "msg"
var screen := ""
## "deposit" | "organize" (tela "party")
var party_mode := "deposit"
var box := 0
var slot := 0
var message := ""

var _root: Control
var _box: VBoxContainer
var _menu_cur := 0
var _party_cur := 0
var _act_cur := 0
var _yes := false
var _held := -1
var _back_to := "menu"
var _closed_at := -1


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game == null:
		game = get_node_or_null("/root/Game")
	var w := Kit.window(self, Vector2(1060, 0))
	_root = w[0]
	_box = w[1]
	_root.visible = false


## Verdadeiro também no frame em que fechou, para a tecla de confirmar não vazar para o overworld.
func is_open() -> bool:
	return screen != "" or Engine.get_process_frames() == _closed_at


func open() -> bool:
	if screen != "" or game == null or game.is_busy() or _other_open():
		return false
	_root.visible = true
	_menu_cur = 0
	_go("menu")
	return true


func close() -> void:
	screen = ""
	_held = -1
	_closed_at = Engine.get_process_frames()
	_root.visible = false
	Kit.clear(_box)


func _other_open() -> bool:
	for n in ["PauseMenu", "LearnMove", "Evolution"]:
		var node := get_node_or_null("/root/" + n)
		if node != null and node.has_method("is_open") and node.is_open():
			return true
	var st := get_node_or_null("/root/Story")
	return st != null and st.has_method("is_running") and st.is_running()


func _input(ev: InputEvent) -> void:
	if screen == "":
		return
	var a := Kit.nav(ev)
	if a == "" and ev is InputEventKey and ev.pressed:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		match k:
			KEY_PAGEUP, KEY_Z: a = "prev_box"
			KEY_PAGEDOWN, KEY_C: a = "next_box"
	if a == "":
		return
	get_viewport().set_input_as_handled()
	press(a)


## Aplica uma ação ("up" "down" "left" "right" "ok" "back" "prev_box" "next_box"). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	if screen == "":
		return
	preload("res://audio/cue.gd").ui(a)
	match screen:
		"menu":
			_menu_cur = _step(_menu_cur, a, ENTRIES.size())
			if a == "back" or (a == "ok" and _menu_cur == 3):
				close()
				return
			if a == "ok":
				match _menu_cur:
					0: _open_party("deposit")
					1: _go("box")
					2: _open_party("organize")
		"box":
			_press_box(a)
		"action":
			_act_cur = _step(_act_cur, a, ACTIONS.size())
			if a == "back" or (a == "ok" and _act_cur == 2):
				_go("box")
			elif a == "ok" and _act_cur == 0:
				_withdraw()
			elif a == "ok" and _act_cur == 1:
				_yes = false
				_go("confirm")
		"confirm":
			if a in ["left", "right", "up", "down"]:
				_yes = not _yes
			elif a == "back":
				_go("action")
			elif a == "ok":
				if _yes:
					_release()
				else:
					_go("action")
		"party":
			_press_party(a)
		"msg":
			if a in ["ok", "back"]:
				_go(_back_to)
	_render()


func _press_box(a: String) -> void:
	match a:
		"up": slot = posmod(slot - COLS, game.BOX_SIZE)
		"down": slot = posmod(slot + COLS, game.BOX_SIZE)
		"left":
			if slot % COLS == 0:
				_switch_box(-1)
				slot += COLS - 1
			else:
				slot -= 1
		"right":
			if slot % COLS == COLS - 1:
				_switch_box(1)
				slot -= COLS - 1
			else:
				slot += 1
		"prev_box": _switch_box(-1)
		"next_box": _switch_box(1)
		"back": _go("menu")
		"ok":
			if selected_mon() != null:
				_act_cur = 0
				_go("action")


func _switch_box(d: int) -> void:
	box = posmod(box + d, game.BOX_COUNT)


func _press_party(a: String) -> void:
	_party_cur = _step(_party_cur, a, game.party.size())
	if a == "back":
		if _held >= 0:
			_held = -1
		else:
			_go("menu")
	elif a == "ok" and not game.party.is_empty():
		if party_mode == "deposit":
			_deposit()
		elif _held < 0:
			_held = _party_cur
		elif _held == _party_cur:
			_held = -1
		else:
			game.swap_party(_held, _party_cur)
			_held = -1


func _open_party(mode: String) -> void:
	party_mode = mode
	_party_cur = 0
	_held = -1
	_go("party")


## Índice em Game.pc do espaço sob o cursor.
func pc_index() -> int:
	return box * game.BOX_SIZE + slot


## Pokémon sob o cursor da caixa (null se o espaço estiver vazio).
func selected_mon() -> Mon:
	var i := pc_index()
	return game.pc[i] if i < game.pc.size() else null


## Motivo para não poder guardar o Pokémon i da equipe ("" = pode).
func deposit_refusal(i: int) -> String:
	if i < 0 or i >= game.party.size():
		return "Não há Pokémon aí."
	if game.pc_full():
		return "O PC está cheio! Solte ou retire algum Pokémon antes de guardar outro."
	for j in game.party.size():
		if j != i and not game.party[j].is_fainted():
			return ""
	if game.party.size() == 1:
		return "Não dá para guardar o seu último Pokémon."
	return "Não dá para guardar: a equipe ficaria sem nenhum Pokémon de pé."


func _deposit() -> void:
	var m: Mon = game.party[_party_cur]
	var why := deposit_refusal(_party_cur)
	if why == "" and not game.deposit(_party_cur):
		why = "Não foi possível guardar %s." % m.display_name
	if why != "":
		_msg(why, "party")
		return
	_party_cur = clampi(_party_cur, 0, maxi(0, game.party.size() - 1))
	var b: int = (game.pc.size() - 1) / game.BOX_SIZE + 1
	_msg("%s foi guardado na Caixa %d." % [m.display_name, b], "party")


func _withdraw() -> void:
	var m := selected_mon()
	if m == null:
		_go("box")
		return
	if game.party.size() >= game.PARTY_MAX:
		_msg("Sua equipe já está cheia (%d Pokémon)." % game.PARTY_MAX, "box")
		return
	if game.withdraw(pc_index()):
		_msg("%s entrou na sua equipe." % m.display_name, "box")
	else:
		_msg("Não foi possível retirar %s." % m.display_name, "box")


func _release() -> void:
	var m := selected_mon()
	if m != null and game.release(pc_index()):
		_msg("%s foi solto. Tchau, %s!" % [m.display_name, m.display_name], "box")
	else:
		_go("box")


func _step(cur: int, a: String, n: int) -> int:
	if n <= 0:
		return 0
	if a == "up":
		return posmod(cur - 1, n)
	if a == "down":
		return posmod(cur + 1, n)
	return clampi(cur, 0, n - 1)


func _go(s: String) -> void:
	screen = s
	_render()


func _msg(text: String, back: String) -> void:
	message = text
	_back_to = back
	_go("msg")


func box_count(b: int) -> int:
	return clampi(game.pc.size() - b * game.BOX_SIZE, 0, game.BOX_SIZE)


# --- Desenho (refeito a cada tecla) ---

func _render() -> void:
	Kit.clear(_box)
	if screen == "":
		return
	_box.add_child(Kit.label("PC de armazenamento", Kit.TEXT, 24))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_box.add_child(h)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(main)
	var side_mon: Mon = null
	match screen:
		"menu":
			main.add_child(Kit.label("O que você quer fazer?", Kit.DIM))
			for i in ENTRIES.size():
				main.add_child(Kit.row([ENTRIES[i]], [240], i == _menu_cur))
			main.add_child(Kit.label("Equipe: %d/%d · PC: %d/%d" % [game.party.size(), game.PARTY_MAX,
				game.pc.size(), game.BOX_SIZE * game.BOX_COUNT], Kit.DIM, 15))
			_box.add_child(Kit.hint("↑/↓ escolhe · E/Enter confirma · Esc/Q sai"))
			return
		"box", "action", "confirm":
			_render_box(main)
			side_mon = selected_mon()
			if screen == "action":
				_render_actions(main)
			elif screen == "confirm":
				_render_confirm(main)
		"party":
			_render_party(main)
			if not game.party.is_empty():
				side_mon = game.party[clampi(_party_cur, 0, game.party.size() - 1)]
		"msg":
			var l := Kit.label(message)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 600
			main.add_child(l)
			_box.add_child(Kit.hint("E/Enter: continuar"))
			return
	h.add_child(_summary(side_mon))
	var hint := ""
	match screen:
		"box": hint = "Setas movem · ←/→ na borda ou PgUp/PgDn (Z/C) trocam de caixa · E escolhe · Esc volta"
		"action": hint = "↑/↓ escolhe · E confirma · Esc volta"
		"confirm": hint = "←/→ Sim/Não · E confirma · Esc cancela"
		"party":
			hint = "↑/↓ escolhe · E guarda no PC · Esc volta" if party_mode == "deposit" else \
				("↑/↓ escolhe o destino · E troca · Esc cancela" if _held >= 0 else "↑/↓ escolhe · E pega para mover · Esc volta")
	_box.add_child(Kit.hint(hint))


func _render_box(main: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_child(Kit.label("◀  Caixa %d  ▶" % (box + 1), Kit.SEL, 22))
	var cnt := Kit.label("%d/%d" % [box_count(box), game.BOX_SIZE], Kit.DIM)
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(cnt)
	main.add_child(head)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	main.add_child(grid)
	for s in game.BOX_SIZE:
		var i: int = box * game.BOX_SIZE + s
		grid.add_child(_slot_card(game.pc[i] if i < game.pc.size() else null, s == slot))


func _slot_card(m: Mon, selected: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = SLOT_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Kit.SEL_BG if selected else Kit.BG_ROW
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	if selected:
		sb.border_color = Kit.SEL
		sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	if m == null:
		return p
	var ic := _icon(m, 30)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var n := Kit.label(m.display_name, Kit.SEL if selected else Kit.TEXT, 13)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size.x = SLOT_SIZE.x - 8
	v.add_child(n)
	var lv := Kit.label("Nv %d" % m.level, Kit.DIM, 12)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lv)
	return p


## Ícone provisório da espécie: círculo na cor do 1º tipo, borda na cor do 2º, inicial no meio.
func _icon(m: Mon, size: int) -> PanelContainer:
	var t: Array = m.types
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Dex.type_color(String(t[0]))
	sb.set_corner_radius_all(size / 2)
	sb.border_color = Dex.type_color(String(t[1])) if t.size() > 1 else sb.bg_color.darkened(0.35)
	sb.set_border_width_all(maxi(2, size / 10))
	p.add_theme_stylebox_override("panel", sb)
	var l := Kit.label(m.display_name.left(1).to_upper(), Color.WHITE, int(size * 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	p.add_child(l)
	return p


func _render_actions(main: VBoxContainer) -> void:
	var m := selected_mon()
	main.add_child(Kit.label("%s, Nv %d:" % [m.display_name, m.level], Kit.TEXT, 18))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for i in ACTIONS.size():
		h.add_child(Kit.row([ACTIONS[i]], [], i == _act_cur))
	main.add_child(h)


func _render_confirm(main: VBoxContainer) -> void:
	var m := selected_mon()
	main.add_child(Kit.label("Soltar %s? Ele não vai voltar." % m.display_name, Kit.BAD, 18))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Kit.row(["Sim"], [60], _yes))
	h.add_child(Kit.row(["Não"], [60], not _yes))
	main.add_child(h)


func _render_party(main: VBoxContainer) -> void:
	var title := "Guardar qual Pokémon?" if party_mode == "deposit" else "Organizar a equipe"
	main.add_child(Kit.label(title, Kit.TEXT, 20))
	if game.party.is_empty():
		main.add_child(Kit.label("Nenhum Pokémon na equipe.", Kit.DIM))
	for i in game.party.size():
		var m: Mon = game.party[i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.add_child(_icon(m, 28))
		var cols := [m.display_name, "Nv %d" % m.level, ["HP %d/%d" % [m.hp, m.max_hp], Kit.hp_color(m)],
			[Kit.status_text(m), Kit.BAD], ["◆ movendo" if i == _held else "", Kit.ACCENT]]
		var row := Kit.row(cols, PARTY_W, i == _party_cur)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(row)
		main.add_child(r)
	if party_mode == "deposit":
		main.add_child(Kit.label("PC: %d/%d" % [game.pc.size(), game.BOX_SIZE * game.BOX_COUNT], Kit.DIM, 15))


## Painel lateral: nível, tipos, natureza, HP e golpes.
func _summary(m: Mon) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Kit.BG_ROW
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if m == null:
		v.add_child(Kit.label("Espaço vazio", Kit.DIM))
		return p
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_icon(m, 48))
	var nm := VBoxContainer.new()
	nm.add_child(Kit.label(m.display_name, Kit.TEXT, 20))
	nm.add_child(Kit.label("Nv %d" % m.level, Kit.DIM))
	top.add_child(nm)
	v.add_child(top)
	var types := HBoxContainer.new()
	types.add_theme_constant_override("separation", 6)
	for t in m.types:
		types.add_child(_type_tag(String(t)))
	v.add_child(types)
	v.add_child(Kit.label("Natureza: %s" % Kit.nature_text(m.nature), Kit.TEXT, 15))
	var st := Kit.status_text(m)
	v.add_child(Kit.label("HP %d/%d %s" % [m.hp, m.max_hp, st], Kit.hp_color(m)))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = maxi(1, m.max_hp)
	bar.value = m.hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = Kit.hp_color(m)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	v.add_child(bar)
	v.add_child(Kit.label("Golpes", Kit.DIM, 15))
	for id in m.moves:
		var t := String(Dex.move(id).get("type", "normal"))
		var r := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.color = Dex.type_color(t)
		dot.custom_minimum_size = Vector2(6, 18)
		r.add_child(dot)
		r.add_child(Kit.label(Kit.move_name(id), Kit.TEXT, 15))
		v.add_child(r)
	return p


func _type_tag(t: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Dex.type_color(t)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := Kit.label(Kit.type_name(t), Color.WHITE, 14)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 3)
	p.add_child(l)
	return p
