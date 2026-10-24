extends Control
## Modo de treinamento: monta os dois times que lutam sozinhos (IA dos dois lados) e as opções da
## luta. Qualquer espécie, nível, natureza, gênero, habilidade, IVs/EVs, golpes, HP/PP/status
## iniciais, amizade e o item de cada treinador. Só mouse, com os controles padrão do Godot.
## A config (formato em training_config.gd) fica em Cfg.current enquanto o jogo está aberto.

const Kit := preload("res://ui/ui_kit.gd")
const Cfg := preload("res://ui/training/training_config.gd")

const BATTLE_SCENE := "res://ui/training/training_battle.tscn"
const TITLE_SCENE := "res://ui/front/title.tscn"
const FONT_SIZE := 15
const SMALL_SIZE := 13
const ICON_PX := 34
const SPRITE_PX := 80
const TEAM_W := 208
const NEW_LEVEL := 15
const THINK_MIN := 0.25
const THINK_MAX := 4.0
const GENDERS := {"": "Sem gênero", "male": "Macho", "female": "Fêmea"}
const THINK_TIP := (
	"Multiplica o tempo entre golpes e a chance de erro: até 0,8 = sem erro e mais rápida;"
	+ " 1 = treinador normal; 1,6 ou mais = golpe sempre aleatório (salvo o que nocauteia)"
)
const NO_EFFECT_TIP := "Não muda nada na luta hoje (a batalha não usa este campo)."
const STAT_ABBR := {"atk": "Atq", "def": "Def", "spa": "At.Esp", "spd": "Def.Esp", "spe": "Vel"}

var cfg: Dictionary = {}
## Pokémon em edição: lado (0 = Time A, 1 = Time B) e posição no time (-1 = time vazio).
var side := 0
var slot := 0
## Slot de golpe (0..3) que a lista de golpes preenche.
var move_slot := 0
## Troca de cena; o teste troca por uma função que só registra o caminho.
var change_scene: Callable

var _syncing := false
var _msg := ""
## Posição marcada na lista de cada time.
var _picked := [0, 0]
var _teams: Array = []
var _type_icons := {}
## Espécies pela ordem da Pokédex (dex_no).
var _species_order: Array = []

var _status: Label
var _start_btn: Button
var _speed: OptionButton
var _seed: SpinBox
var _turbo: CheckBox
var _limit: SpinBox
var _empty_note: Label
var _editor: Control
var _title: Label
var _where: Label
var _sprite: TextureRect
var _types: HBoxContainer
var _sp_search: LineEdit
var _sp_list: ItemList
var _nick: LineEdit
var _level: SpinBox
var _nature: OptionButton
var _gender: OptionButton
var _ability: OptionButton
var _hp: SpinBox
var _hp_info: Label
var _cond: OptionButton
var _pp: SpinBox
var _pp_info: Label
var _friend: SpinBox
var _stat_name := {}
var _base := {}
var _iv := {}
var _ev := {}
var _final := {}
var _ev_total: Label
var _move_rows: Array = []
var _mv_search: LineEdit
var _mv_list: ItemList


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	if not change_scene.is_valid():
		change_scene = func(path: String): get_tree().change_scene_to_file(path)
	cfg = Cfg.current if not Cfg.current.is_empty() else Cfg.load_config()
	Cfg.current = cfg
	Cfg.block_pause_menu(get_tree(), true)
	_species_order = Dex.all_species().duplicate()
	_species_order.sort_custom(func(a, b): return _dex_no(a) < _dex_no(b))
	_build()
	_fill_species()
	_fill_moves()
	select(0, 0)


func _exit_tree() -> void:
	Cfg.block_pause_menu(get_tree(), false)


## Esc (fora de um campo de texto) volta ao título.
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_to_title()


# --- API (botões e teste) ---


func select(s: int, k: int) -> void:
	side = clampi(s, 0, Cfg.SIDES - 1)
	var n := _mons(side).size()
	slot = clampi(k, 0, n - 1) if n > 0 else -1
	_picked[side] = slot
	_refresh_all()


func set_species(id: String) -> void:
	var e := _entry()
	var sp := Dex.canon(id)
	if e.is_empty() or sp == "":
		return
	var was_full := float(e.get("pp", 0.0)) >= _pp_base(String(e.get("species", "")))
	var abil: Array = Dex.species(sp).get("abilities", [])
	e["species"] = sp
	e["moves"] = Dex.moves_at(sp, int(e.get("level", 1)))
	e["ability_slot"] = clampi(int(e.get("ability_slot", 0)), 0, maxi(abil.size() - 1, 0))
	e["gender"] = _valid_gender(sp, String(e.get("gender", "")))
	e["pp"] = _pp_base(sp) if was_full else minf(float(e.get("pp", 0.0)), _pp_base(sp))
	e["evo_pending"] = false
	e["evo_cancelled_level"] = 0
	move_slot = 0
	_refresh_all()


func set_level(n: int) -> void:
	set_field("level", clampi(n, 1, Growth.MAX_LEVEL))


## Põe o golpe `id` no slot k (0..3); "" tira o golpe. Golpe repetido troca de lugar.
func set_move(k: int, id: String) -> void:
	var e := _entry()
	if e.is_empty() or k < 0 or k >= Mon.MAX_MOVES or (id != "" and Dex.move(id).is_empty()):
		return
	var mv: Array = (e.get("moves", []) as Array).duplicate()
	var j := mv.find(id)
	if id == "":
		if k >= mv.size():
			return
		if mv.size() <= 1:
			_note("O Pokémon precisa de pelo menos um golpe.")
			return
		mv.remove_at(k)
		move_slot = mini(mv.size(), Mon.MAX_MOVES - 1)
	elif j >= 0:
		if k < mv.size():
			mv[j] = mv[k]
			mv[k] = id
	elif k < mv.size():
		mv[k] = id
	else:
		mv.append(id)
	e["moves"] = mv
	_refresh_all()


## Golpes que a espécie sabe no nível atual (Dex.moves_at).
func moves_for_level() -> void:
	var e := _entry()
	if not e.is_empty():
		set_field("moves", Dex.moves_at(String(e.species), int(e.get("level", 1))))


## Campo simples da entrada em edição: nickname, level, nature, gender, ability_slot, hp_pct,
## status, pp, friend, moves.
func set_field(key: String, value) -> void:
	var e := _entry()
	if e.is_empty():
		return
	e[key] = value
	_refresh_all()


func set_iv(s: String, v: int) -> void:
	var e := _entry()
	if e.is_empty():
		return
	var ivs: Dictionary = e.get("ivs", {})
	ivs[s] = clampi(v, 0, StatCalc.IV_MAX)
	e["ivs"] = ivs
	_refresh_all()


## Todos os IVs em v (v < 0 = aleatório).
func set_all_ivs(v: int) -> void:
	var e := _entry()
	if e.is_empty():
		return
	var ivs := {}
	for s in StatCalc.STATS:
		ivs[s] = randi_range(0, StatCalc.IV_MAX) if v < 0 else clampi(v, 0, StatCalc.IV_MAX)
	set_field("ivs", ivs)


## EV de um atributo, limitado a 252 e ao total de 510.
func set_ev(s: String, v: int) -> void:
	var e := _entry()
	if e.is_empty():
		return
	var evs: Dictionary = e.get("evs", {})
	var others := 0
	for k in StatCalc.STATS:
		if k != s:
			others += int(evs.get(k, 0))
	evs[s] = clampi(v, 0, mini(StatCalc.EV_MAX_STAT, StatCalc.EV_MAX_TOTAL - others))
	e["evs"] = evs
	_refresh_all()


func clear_evs() -> void:
	set_field("evs", StatCalc.zero_evs())


func add_mon(s: int) -> void:
	var mons := _mons(s)
	if mons.size() >= Cfg.PARTY_MAX:
		return
	var lv := NEW_LEVEL if mons.is_empty() else int(mons[-1].get("level", NEW_LEVEL))
	mons.append(Cfg.mon_entry(String(_species_order[0]), lv))
	select(s, mons.size() - 1)


func remove_mon(s: int, k: int) -> void:
	var mons := _mons(s)
	if k < 0 or k >= mons.size():
		return
	mons.remove_at(k)
	select(s, mini(k, mons.size() - 1))


func duplicate_mon(s: int, k: int) -> void:
	var mons := _mons(s)
	if k < 0 or k >= mons.size() or mons.size() >= Cfg.PARTY_MAX:
		return
	mons.insert(k + 1, (mons[k] as Dictionary).duplicate(true))
	select(s, k + 1)


## Sobe (dir = -1) ou desce (dir = 1) o Pokémon k no time.
func move_mon(s: int, k: int, dir: int) -> void:
	var mons := _mons(s)
	var j := k + dir
	if k < 0 or k >= mons.size() or j < 0 or j >= mons.size():
		return
	var tmp = mons[k]
	mons[k] = mons[j]
	mons[j] = tmp
	select(s, j)


## Copia os Pokémon, o item e o nível da IA do time `from` para o outro (o nome fica).
func copy_side(from: int) -> void:
	var src: Dictionary = cfg.sides[from]
	var dst: Dictionary = cfg.sides[1 - from]
	dst["mons"] = _mons(from).duplicate(true)
	dst["item"] = String(src.get("item", ""))
	dst["think_scale"] = float(src.get("think_scale", 1.0))
	select(side, slot)
	_note("%s copiado para o %s." % [_side_name(from), _side_name(1 - from)])


## Troca os dois times de lado (com nome, item e nível da IA).
func swap_sides() -> void:
	var a = cfg.sides[0]
	cfg.sides[0] = cfg.sides[1]
	cfg.sides[1] = a
	_picked = [_picked[1], _picked[0]]
	select(1 - side, slot)
	_note("Times trocados de lado.")


func set_team_name(s: int, text: String) -> void:
	cfg.sides[s]["name"] = text
	_refresh_all()


func set_team_item(s: int, id: String) -> void:
	cfg.sides[s]["item"] = id
	_refresh_all()


func set_think(s: int, v: float) -> void:
	cfg.sides[s]["think_scale"] = clampf(v, THINK_MIN, THINK_MAX)
	_refresh_all()


func set_speed(v: float) -> void:
	cfg["speed"] = v
	_refresh_all()


func set_seed(v: int) -> void:
	cfg["seed"] = maxi(v, -1)
	_refresh_all()


func set_turbo(on: bool) -> void:
	cfg["turbo"] = on
	_refresh_all()


## Limite de tempo de jogo da luta em segundos (0 = sem limite).
func set_time_limit(v: int) -> void:
	cfg["time_limit"] = clampi(v, 0, 3600)
	_refresh_all()


func save() -> void:
	_commit_edits()
	Cfg.save_config(cfg)
	_note("Configuração salva.")


func load_saved() -> void:
	var had := FileAccess.file_exists(Cfg.path)
	_replace(Cfg.load_config())
	_note("Configuração carregada." if had else "Nada salvo ainda: carregado o padrão.")


func reset_default() -> void:
	_replace(Cfg.default_config())
	_note("Configuração padrão restaurada (não salva).")


func start() -> void:
	_commit_edits()
	if not Cfg.can_start(cfg):
		_refresh_status()
		return
	Cfg.current = cfg
	Cfg.save_config(cfg)
	change_scene.call(BATTLE_SCENE)


func back_to_title() -> void:
	load("res://ui/front/title.gd").boot_to_menu = true
	change_scene.call(TITLE_SCENE)


## Stats finais mostradas na tela (para o teste).
func shown_stats() -> Dictionary:
	var out := {}
	for s in StatCalc.STATS:
		out[s] = int((_final[s] as Label).text)
	return out


## Confirma o texto digitado e pendente num SpinBox (os botões não pegam o foco).
func _commit_edits() -> void:
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner() if vp else null
	if f and f.get_parent() is SpinBox:
		(f.get_parent() as SpinBox).apply()
	if vp:
		vp.gui_release_focus()


# --- Dados ---


func _mons(s: int) -> Array:
	var sd: Dictionary = cfg.sides[s]
	if not sd.get("mons") is Array:
		sd["mons"] = []
	return sd.mons


func _entry() -> Dictionary:
	var mons := _mons(side)
	return mons[slot] if slot >= 0 and slot < mons.size() else {}


func _replace(c: Dictionary) -> void:
	cfg = c
	Cfg.current = cfg
	_picked = [0, 0]
	select(0, 0)


func _side_name(s: int) -> String:
	var n := String(cfg.sides[s].get("name", ""))
	return n if n != "" else ("Time A" if s == 0 else "Time B")


static func _dex_no(sp: String) -> int:
	return int(Dex.species(sp).get("dex_no", 9999))


static func _pp_base(sp: String) -> float:
	return float(Dex.species(sp).get("pp", 100))


## Gêneros possíveis pela gender_ratio (-1 = sem gênero, 0 = só macho, 1 = só fêmea).
static func _genders(sp: String) -> Array:
	var r := float(Dex.species(sp).get("gender_ratio", 0.5))
	if r < 0.0:
		return [""]
	if r <= 0.0:
		return ["male"]
	if r >= 1.0:
		return ["female"]
	return ["male", "female"]


static func _valid_gender(sp: String, g: String) -> String:
	var ok := _genders(sp)
	return g if ok.has(g) else String(ok[0])


## "Adamant (+Atq −At.Esp)": rótulo curto da natureza (as cores da tabela de atributos repetem).
static func _nature_text(n: String) -> String:
	var d: Array = StatCalc.NATURES.get(n, [])
	if d.is_empty():
		return "%s (neutra)" % n.capitalize()
	return "%s (+%s −%s)" % [n.capitalize(), STAT_ABBR[d[0]], STAT_ABBR[d[1]]]


static func _speed_text(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".").replace(".", ",") + "x"


static func _move_info(id: String) -> String:
	var mv := Dex.move(id)
	var cat := String(mv.get("category", ""))
	var power := int(mv.get("power", 0))
	var acc := int(mv.get("accuracy", 0))
	return (
		"%s · %s · %s"
		% [
			Kit.CATEGORIES.get(cat, cat),
			("Poder %d" % power) if power > 0 else "Sem dano",
			("%d%%" % acc) if acc > 0 else "Sempre acerta"
		]
	)


static func _mon_line(d: Dictionary) -> String:
	var nick := String(d.get("nickname", ""))
	var lv := int(d.get("level", 1))
	var t := "%s  Nv %d" % [nick if nick != "" else String(d.get("species", "?")), lv]
	if int(d.get("hp_pct", 100)) < 100:
		t += " · %d%%" % int(d.hp_pct)
	if String(d.get("status", "")) != "":
		t += " · " + String(Kit.STATUS.get(String(d.status), ""))
	return t


# --- Montagem ---


static func _box(bg: Color, border: Color, radius := 6, mx := 8, my := 4) -> StyleBoxFlat:
	var sb := Kit.pill(bg, border, radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## Tema do kit em letra menor, com botões, campos e listas claros (papel e tinta).
func _make_theme() -> Theme:
	var t: Theme = Kit.theme().duplicate()
	t.default_font_size = FONT_SIZE
	var states := {
		"normal": [Kit.BG_ROW, Kit.RIM],
		"hover": [Kit.RED_SOFT, Kit.RED],
		"pressed": [Kit.RED, Kit.INK],
		"hover_pressed": [Kit.RED, Kit.INK],
		"disabled": [Color(Kit.BG_ROW, 0.5), Color(Kit.RIM, 0.6)],
	}
	for k in states:
		t.set_stylebox(k, "Button", _box(states[k][0], states[k][1], 6, 6, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(k, "Button", Kit.INK)
	t.set_color("font_pressed_color", "Button", Kit.PAPER)
	t.set_color("font_hover_pressed_color", "Button", Kit.PAPER)
	t.set_color("font_disabled_color", "Button", Kit.DIM)
	t.set_constant("modulate_arrow", "OptionButton", 1)
	for k in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(k, "CheckBox", _box(Color.TRANSPARENT, Color.TRANSPARENT, 6, 4, 2))
	for k in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_hover_pressed_color",
		"font_focus_color"
	]:
		t.set_color(k, "CheckBox", Kit.INK)
	t.set_color("checkbox_checked_color", "CheckBox", Kit.RED)
	t.set_color("checkbox_unchecked_color", "CheckBox", Kit.INK)
	t.set_constant("minimum_character_width", "LineEdit", 2)
	t.set_stylebox("normal", "LineEdit", _box(Color.WHITE, Kit.RIM, 4, 6, 3))
	t.set_stylebox("read_only", "LineEdit", _box(Kit.BG_ROW, Kit.RIM, 4, 6, 3))
	var focus := _box(Color.TRANSPARENT, Kit.BLUE, 4)
	focus.draw_center = false
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", Kit.INK)
	t.set_color("font_placeholder_color", "LineEdit", Kit.DIM)
	t.set_color("font_uneditable_color", "LineEdit", Kit.DIM)
	t.set_color("caret_color", "LineEdit", Kit.INK)
	t.set_color("font_selected_color", "LineEdit", Kit.INK)
	t.set_color("selection_color", "LineEdit", Color(Kit.RED, 0.3))
	t.set_color("clear_button_color", "LineEdit", Kit.INK)
	for k in [
		"up_icon_modulate",
		"up_hover_icon_modulate",
		"up_pressed_icon_modulate",
		"down_icon_modulate",
		"down_hover_icon_modulate",
		"down_pressed_icon_modulate"
	]:
		t.set_color(k, "SpinBox", Kit.INK)
	t.set_stylebox("panel", "ItemList", _box(Color.WHITE, Kit.RIM, 6, 4, 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	for k in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		t.set_stylebox(k, "ItemList", _box(Kit.RED_SOFT, Kit.RED, 6, 4, 2))
	t.set_stylebox("hovered", "ItemList", _box(Kit.BG_ROW, Color.TRANSPARENT, 6, 4, 2))
	for k in ["cursor", "cursor_unfocused"]:
		t.set_stylebox(k, "ItemList", StyleBoxEmpty.new())
	for k in [
		"font_color", "font_hovered_color", "font_selected_color", "font_hovered_selected_color"
	]:
		t.set_color(k, "ItemList", Kit.INK)
	t.set_color("guide_color", "ItemList", Color.TRANSPARENT)
	t.set_stylebox("panel", "TooltipPanel", _box(Kit.PAPER, Kit.INK, 6, 8, 5))
	t.set_color("font_color", "TooltipLabel", Kit.INK)
	t.set_font_size("font_size", "TooltipLabel", SMALL_SIZE)
	return t


func _panel() -> Array:
	var p := PanelContainer.new()
	var sb := Kit.window_box()
	sb.set_content_margin_all(12)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	return [p, col]


func _small(text: String, col := Kit.BLUE) -> Label:
	return Kit.label(text, col, SMALL_SIZE)


func _btn(text: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(_commit_edits)
	b.pressed.connect(cb)
	return b


func _spin(lo: float, hi: float, step := 1.0, w := 64) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = w
	return s


## Texto que quebra linha em vez de alargar a coluna.
func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Texto que corta com "..." em vez de alargar a coluna (nomes longos).
func _clip(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _labeled(text: String, c: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_small(text))
	v.add_child(c)
	return v


func _type_icon(t: String) -> Texture2D:
	if not _type_icons.has(t):
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Kit.type_col(t))
		_type_icons[t] = ImageTexture.create_from_image(img)
	return _type_icons[t]


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Kit.INK.darkened(0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + k, 8)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)
	main.add_child(_build_top())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	var body := _hbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_build_team(0))
	body.add_child(_build_editor())
	body.add_child(_build_team(1))


func _build_top() -> Control:
	var pc := _panel()
	var col: VBoxContainer = pc[1]
	var r1 := _hbox(8)
	col.add_child(r1)
	r1.add_child(_btn("Voltar ao título", back_to_title))
	var h := Kit.header("MODO DE TREINAMENTO", Kit.INK, 24)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r1.add_child(h)
	r1.add_child(_btn("Salvar", save, "Grava a configuração (só do modo de treinamento)"))
	r1.add_child(_btn("Carregar", load_saved, "Volta para a última configuração salva"))
	r1.add_child(_btn("Restaurar padrão", reset_default))
	_start_btn = _btn("Começar batalha", start, "As duas equipes lutam sozinhas, pela IA")
	_start_btn.add_theme_stylebox_override("normal", _box(Kit.RED, Kit.INK, 6, 14, 4))
	_start_btn.add_theme_stylebox_override(
		"hover", _box(Kit.RED.lightened(0.15), Kit.INK, 6, 14, 4)
	)
	_start_btn.add_theme_color_override("font_color", Kit.PAPER)
	_start_btn.add_theme_color_override("font_hover_color", Kit.PAPER)
	r1.add_child(_start_btn)

	var r2 := _hbox(8)
	col.add_child(r2)
	r2.add_child(_small("Velocidade"))
	_speed = OptionButton.new()
	for v in Cfg.SPEEDS:
		_speed.add_item(_speed_text(v))
	_speed.item_selected.connect(_on_speed)
	r2.add_child(_speed)
	r2.add_child(_small("Semente"))
	_seed = _spin(-1, 2147483647, 1.0, 120)
	_seed.tooltip_text = "-1 = aleatória; fixa = série reproduzível (luta k da série: semente + k)"
	_seed.value_changed.connect(_on_seed)
	r2.add_child(_seed)
	r2.add_child(_small("(-1 = aleatória)", Kit.DIM))
	r2.add_child(_small("Limite (s)"))
	_limit = _spin(0, 3600, 5.0, 76)
	_limit.tooltip_text = "Tempo de jogo máximo; ao passar, a luta termina sem vencedor (0 = sem)"
	_limit.value_changed.connect(_on_limit)
	r2.add_child(_limit)
	_turbo = CheckBox.new()
	_turbo.text = "Turbo"
	_turbo.focus_mode = Control.FOCUS_NONE
	_turbo.tooltip_text = "Roda as lutas o mais rápido possível, para séries longas"
	_turbo.button_down.connect(_commit_edits)
	_turbo.toggled.connect(_on_turbo)
	r2.add_child(_turbo)
	r2.add_child(_btn("Trocar times", swap_sides, "Troca o Time A e o Time B de lado"))
	_status = Kit.label("", Kit.INK, SMALL_SIZE)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	r2.add_child(_status)
	return pc[0]


func _build_team(i: int) -> Control:
	var pc := _panel()
	var p: PanelContainer = pc[0]
	p.custom_minimum_size.x = TEAM_W
	var col: VBoxContainer = pc[1]
	var t := {}
	t.head = Kit.header("TIME A" if i == 0 else "TIME B", Kit.INK, 22)
	col.add_child(t.head)
	col.add_child(
		_btn(
			"Copiar time para o %s" % ("B" if i == 0 else "A"),
			copy_side.bind(i),
			"Copia os Pokémon, o item e o nível da IA para o outro time"
		)
	)
	t.name = LineEdit.new()
	t.name.placeholder_text = "Nome do treinador"
	t.name.text_changed.connect(_on_team_name.bind(i))
	col.add_child(_labeled("Nome", t.name))
	var row := _hbox(6)
	col.add_child(row)
	t.item = OptionButton.new()
	t.item.add_item("Nenhum")
	t.item.set_item_metadata(0, "")
	for id in Cfg.battle_items():
		t.item.add_item(Kit.item_name(id))
		t.item.set_item_metadata(t.item.item_count - 1, id)
	t.item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.item.fit_to_longest_item = false
	t.item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.item.tooltip_text = "A IA usa o item uma vez por Pokémon (cura de HP ou de status)"
	t.item.item_selected.connect(_on_team_item.bind(i))
	var iv := _labeled("Item do treinador", t.item)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(iv)
	t.think = _spin(THINK_MIN, THINK_MAX, 0.05, 70)
	t.think.tooltip_text = THINK_TIP
	t.think.value_changed.connect(_on_think.bind(i))
	row.add_child(_labeled("Nível da IA", t.think))
	t.count = _small("")
	col.add_child(t.count)
	var list := ItemList.new()
	list.custom_minimum_size.y = Cfg.PARTY_MAX * (ICON_PX + 6) + 8
	list.fixed_icon_size = Vector2i(ICON_PX, ICON_PX)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	list.item_clicked.connect(_on_team_click.bind(i))
	list.item_selected.connect(_on_team_pick.bind(i))
	col.add_child(list)
	t.list = list
	var r1 := _hbox(4)
	col.add_child(r1)
	t.add = _btn("Adicionar", func(): add_mon(i))
	t.rm = _btn("Remover", func(): remove_mon(i, _picked[i]))
	var r2 := _hbox(4)
	col.add_child(r2)
	t.dup = _btn("Duplicar", func(): duplicate_mon(i, _picked[i]))
	t.up = _btn("Subir", func(): move_mon(i, _picked[i], -1), "Sobe na ordem (o 1º entra primeiro)")
	list.tooltip_text = "O 1º da lista entra primeiro"
	t.down = _btn("Descer", func(): move_mon(i, _picked[i], 1))
	for k in ["add", "rm", "dup", "up", "down"]:
		var b: Button = t[k]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(r1 if k in ["add", "rm"] else r2).add_child(b)
	_teams.append(t)
	return p


func _build_editor() -> Control:
	var pc := _panel()
	var p: PanelContainer = pc[0]
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = pc[1]
	_empty_note = Kit.label("Time vazio: use Adicionar para pôr um Pokémon.", Kit.DIM)
	col.add_child(_empty_note)
	var ed := _hbox(14)
	_editor = ed
	col.add_child(ed)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 276
	ed.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.add_child(right)
	_build_species(left)
	_build_fields(left)
	_build_stats(right)
	_build_moves(right)
	return p


func _build_species(box: VBoxContainer) -> void:
	var head := _hbox(10)
	box.add_child(head)
	_sprite = Kit.sprite_rect(null, Vector2(SPRITE_PX, SPRITE_PX))
	head.add_child(_sprite)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	_where = _clip(_small(""))
	info.add_child(_where)
	_title = _clip(Kit.header("", Kit.INK, 22))
	info.add_child(_title)
	_types = _hbox(4)
	info.add_child(_types)
	_sp_search = LineEdit.new()
	_sp_search.placeholder_text = "Buscar espécie ou tipo..."
	_sp_search.clear_button_enabled = true
	_sp_search.text_changed.connect(func(_t: String): _fill_species())
	box.add_child(_labeled("Espécie (clique para trocar)", _sp_search))
	_sp_list = ItemList.new()
	_sp_list.custom_minimum_size.y = 150
	_sp_list.item_selected.connect(_on_species_pick)
	box.add_child(_sp_list)


func _build_fields(box: VBoxContainer) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 4)
	box.add_child(g)
	_nick = LineEdit.new()
	_nick.placeholder_text = "(sem apelido)"
	_nick.text_changed.connect(_on_nick)
	_level = _spin(1, Growth.MAX_LEVEL)
	_level.value_changed.connect(_on_level)
	_nature = OptionButton.new()
	for n in StatCalc.NATURES:
		_nature.add_item(_nature_text(n))
		_nature.set_item_metadata(_nature.item_count - 1, n)
	_nature.item_selected.connect(_on_option.bind(_nature, "nature"))
	_gender = OptionButton.new()
	_gender.item_selected.connect(_on_option.bind(_gender, "gender"))
	_ability = OptionButton.new()
	_ability.item_selected.connect(_on_option.bind(_ability, "ability_slot"))
	_hp = _spin(1, 100, 1.0, 76)
	_hp.suffix = "%"
	_hp.value_changed.connect(_on_int_field.bind("hp_pct"))
	_hp_info = _small("", Kit.INK)
	_cond = OptionButton.new()
	for s in Cfg.STATUSES:
		_cond.add_item(String(Cfg.STATUS_NAMES.get(s, s)))
		_cond.set_item_metadata(_cond.item_count - 1, s)
	_cond.item_selected.connect(_on_option.bind(_cond, "status"))
	_pp = _spin(0, 100, 1.0, 76)
	_pp.value_changed.connect(_on_pp)
	_pp_info = _small("", Kit.INK)
	_friend = _spin(0, 255)
	_friend.tooltip_text = "Amizade 0-255 (começa em %d). %s" % [Mon.FRIEND_START, NO_EFFECT_TIP]
	_gender.tooltip_text = NO_EFFECT_TIP
	_ability.tooltip_text = NO_EFFECT_TIP
	_friend.value_changed.connect(_on_int_field.bind("friend"))
	var hp_row := _hbox(6)
	hp_row.add_child(_hp)
	hp_row.add_child(_hp_info)
	var pp_row := _hbox(6)
	pp_row.add_child(_pp)
	pp_row.add_child(_pp_info)
	for o in [_nature, _gender, _ability, _cond]:
		o.fit_to_longest_item = false
		o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for r in [
		["Apelido", _nick],
		["Nível", _level],
		["Natureza", _nature],
		["Gênero *", _gender],
		["Habilidade *", _ability],
		["HP inicial", hp_row],
		["Status inicial", _cond],
		["PP inicial", pp_row],
		["Amizade *", _friend],
	]:
		var l := _small(r[0])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.add_child(l)
		(r[1] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(r[1])
	box.add_child(
		_wrap(_small("* Gênero (visual), habilidade e amizade: sem efeito na luta.", Kit.DIM))
	)


func _build_stats(box: VBoxContainer) -> void:
	box.add_child(_small("Atributos (finais calculados como no jogo)"))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 3)
	box.add_child(g)
	for h in ["", "Base", "IV (0-31)", "EV (0-252)", "Final"]:
		g.add_child(_small(h, Kit.DIM))
	for s in StatCalc.STATS:
		var nm := Kit.label(String(Kit.STATS[s]))
		nm.custom_minimum_size.x = 84
		var iv := _spin(0, StatCalc.IV_MAX, 1.0, 56)
		iv.value_changed.connect(_on_iv.bind(s))
		var ev := _spin(0, StatCalc.EV_MAX_STAT)
		ev.custom_arrow_step = 4
		ev.value_changed.connect(_on_ev.bind(s))
		_stat_name[s] = nm
		_base[s] = Kit.label("", Kit.DIM)
		_iv[s] = iv
		_ev[s] = ev
		_final[s] = Kit.header("", Kit.INK, 18)
		for c in [nm, _base[s], iv, ev, _final[s]]:
			g.add_child(c)
	var r1 := _hbox(4)
	box.add_child(r1)
	r1.add_child(_small("IVs:"))
	r1.add_child(_btn("Todos 31", set_all_ivs.bind(StatCalc.IV_MAX)))
	r1.add_child(_btn("Todos 0", set_all_ivs.bind(0)))
	r1.add_child(_btn("Aleatório", set_all_ivs.bind(-1)))
	var r2 := _hbox(4)
	box.add_child(r2)
	_ev_total = _small("")
	r2.add_child(_ev_total)
	r2.add_child(_btn("Zerar EVs", clear_evs))


func _build_moves(box: VBoxContainer) -> void:
	box.add_child(_wrap(_small("Golpes: marque um slot e clique num golpe da lista")))
	var group := ButtonGroup.new()
	for k in Mon.MAX_MOVES:
		var row := _hbox(6)
		box.add_child(row)
		var b := _btn("", _on_move_slot.bind(k))
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		row.add_child(_btn("×", set_move.bind(k, ""), "Tirar este golpe"))
		var line := _hbox(6)
		box.add_child(line)
		var tags := _hbox(4)
		tags.custom_minimum_size.x = 84
		line.add_child(tags)
		var info := _small("", Kit.INK)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		line.add_child(info)
		_move_rows.append({"btn": b, "tags": tags, "info": info})
	var r := _hbox(6)
	box.add_child(r)
	r.add_child(
		_btn("Golpes do nível", moves_for_level, "Os golpes que a espécie sabe neste nível")
	)
	_mv_search = LineEdit.new()
	_mv_search.placeholder_text = "Buscar golpe (nome, tipo, categoria)..."
	_mv_search.clear_button_enabled = true
	_mv_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mv_search.text_changed.connect(func(_t: String): _fill_moves())
	r.add_child(_mv_search)
	_mv_list = ItemList.new()
	_mv_list.custom_minimum_size.y = 130
	_mv_list.item_clicked.connect(_on_move_click)
	box.add_child(_mv_list)


func _fill_species() -> void:
	var q := _sp_search.text.strip_edges().to_lower()
	_sp_list.clear()
	for sp in _species_order:
		var d := Dex.species(sp)
		var names := PackedStringArray()
		var keys := String(sp).to_lower()
		for t in d.get("types", []):
			names.append(Kit.type_name(String(t)))
			keys += " " + String(t)
		var text := "#%03d %s (%s)" % [int(d.get("dex_no", 0)), sp, "/".join(names)]
		if q != "" and not (keys + " " + text.to_lower()).contains(q):
			continue
		var i := _sp_list.add_item(text)
		_sp_list.set_item_metadata(i, String(sp))
	_select_species()


func _fill_moves() -> void:
	var q := _mv_search.text.strip_edges().to_lower()
	_mv_list.clear()
	_mv_list.add_item("(vazio): tira o golpe do slot")
	_mv_list.set_item_metadata(0, "")
	for id in Dex.all_moves():
		var mv := Dex.move(id)
		var t := String(mv.get("type", "normal"))
		var text := "%s · %s · %s" % [Kit.move_name(id), Kit.type_name(t), _move_info(id)]
		if q != "" and not ("%s %s %s" % [id, t, text.to_lower()]).contains(q):
			continue
		var i := _mv_list.add_item(text, _type_icon(t))
		_mv_list.set_item_metadata(i, String(id))
		_mv_list.set_item_tooltip(i, String(mv.get("desc", "")))


func _select_species() -> void:
	var e := _entry()
	_sp_list.deselect_all()
	if e.is_empty():
		return
	var sp := Dex.canon(String(e.get("species", "")))
	for i in _sp_list.item_count:
		if _sp_list.get_item_metadata(i) == sp:
			_sp_list.select(i)
			_sp_list.ensure_current_is_visible()
			return


# --- Tela a partir da config ---


func _refresh_all() -> void:
	_msg = ""
	_syncing = true
	_speed.select(_speed_index())
	_seed.value = int(cfg.get("seed", -1))
	_limit.value = int(cfg.get("time_limit", 0))
	_turbo.set_pressed_no_signal(bool(cfg.get("turbo", false)))
	for i in Cfg.SIDES:
		_sync_team(i)
	_sync_editor()
	_syncing = false
	_refresh_status()


func _speed_index() -> int:
	var v := float(cfg.get("speed", 1.0))
	var best := 0
	for i in Cfg.SPEEDS.size():
		if absf(Cfg.SPEEDS[i] - v) < absf(Cfg.SPEEDS[best] - v):
			best = i
	return best


func _sync_team(i: int) -> void:
	var t: Dictionary = _teams[i]
	var sd: Dictionary = cfg.sides[i]
	var nm := String(sd.get("name", ""))
	if t.name.text != nm:
		t.name.text = nm
	var item: OptionButton = t.item
	item.select(0)
	for k in item.item_count:
		if item.get_item_metadata(k) == String(sd.get("item", "")):
			item.select(k)
	t.think.value = float(sd.get("think_scale", 1.0))
	t.head.add_theme_color_override("font_color", Kit.RED if i == side else Kit.INK)
	var mons := _mons(i)
	t.count.text = "Pokémon (%d/%d)" % [mons.size(), Cfg.PARTY_MAX]
	var list: ItemList = t.list
	list.clear()
	for d in mons:
		var sp := Dex.canon(String(d.get("species", "")))
		var k := list.add_item(_mon_line(d), Kit.mon_fitted(sp, ICON_PX) if sp != "" else null)
		list.set_item_tooltip(
			k, "%s · Nv %d · HP %d%%" % [sp, int(d.get("level", 1)), int(d.get("hp_pct", 100))]
		)
	var cur: int = _picked[i]
	if cur >= 0 and cur < mons.size():
		list.select(cur)
	var has := cur >= 0 and cur < mons.size()
	t.add.disabled = mons.size() >= Cfg.PARTY_MAX
	t.rm.disabled = not has
	t.dup.disabled = not has or mons.size() >= Cfg.PARTY_MAX
	t.up.disabled = not has or cur == 0
	t.down.disabled = not has or cur >= mons.size() - 1


func _sync_editor() -> void:
	var e := _entry()
	_editor.visible = not e.is_empty()
	_empty_note.visible = e.is_empty()
	if e.is_empty():
		return
	var sp := Dex.canon(String(e.get("species", "")))
	var spd := Dex.species(sp)
	var m := Cfg.build_mon(e)
	_where.text = "%s · %dº Pokémon" % [_side_name(side), slot + 1]
	_title.text = "%s · Nv %d" % [m.display_name if sp != "" else "(espécie inválida)", m.level]
	_sprite.texture = Kit.mon_front(sp) if sp != "" else null
	Kit.clear(_types)
	for t in spd.get("types", []):
		_types.add_child(Kit.tag(Kit.type_name(String(t)), Kit.type_col(String(t)), 12))
	_select_species()
	if _nick.text != String(e.get("nickname", "")):
		_nick.text = String(e.get("nickname", ""))
	_level.value = m.level
	_nature.select(StatCalc.NATURES.keys().find(m.nature))
	_gender.clear()
	for g in _genders(sp):
		_gender.add_item(String(GENDERS[g]))
		_gender.set_item_metadata(_gender.item_count - 1, g)
	_gender.select(maxi(_genders(sp).find(m.gender), 0))
	_ability.clear()
	var abil: Array = spd.get("abilities", [])
	for k in abil.size():
		var a := Dex.ability(String(abil[k]))
		_ability.add_item(String(a.get("name", abil[k])).capitalize())
		_ability.set_item_metadata(k, k)
		_ability.set_item_tooltip(k, String(a.get("desc", "")))
	if abil.is_empty():
		_ability.add_item("—")
		_ability.set_item_metadata(0, 0)
	_ability.select(clampi(m.ability_slot, 0, _ability.item_count - 1))
	_hp.value = int(e.get("hp_pct", 100))
	_hp_info.text = "= %d / %d" % [m.hp, m.max_hp]
	_cond.select(maxi(Cfg.STATUSES.find(m.status), 0))
	_pp.max_value = m.pp_base
	_pp.value = m.pp
	_pp_info.text = "de %d" % int(m.pp_base)
	_friend.value = int(e.get("friend", Mon.FRIEND_START))
	var nat: Array = StatCalc.NATURES.get(m.nature, [])
	for s in StatCalc.STATS:
		var col := Kit.INK
		if not nat.is_empty():
			col = Kit.RED if nat[0] == s else (Kit.BLUE if nat[1] == s else Kit.INK)
		_stat_name[s].add_theme_color_override("font_color", col)
		_base[s].text = str(int(spd.get("base", {}).get(s, 50)))
		_iv[s].value = int(m.ivs.get(s, 0))
		_ev[s].value = int(m.evs.get(s, 0))
		_final[s].text = str(m.stat(s))
	_ev_total.text = "EVs: %d / %d" % [m.ev_total(), StatCalc.EV_MAX_TOTAL]
	var mv: Array = e.get("moves", [])
	for k in _move_rows.size():
		var r: Dictionary = _move_rows[k]
		var id := String(mv[k]) if k < mv.size() else ""
		var b: Button = r.btn
		b.text = "%d. %s" % [k + 1, Kit.move_name(id) if id != "" else "(vazio)"]
		b.set_pressed_no_signal(k == move_slot)
		Kit.clear(r.tags)
		var t := String(Dex.move(id).get("type", "normal"))
		if id != "":
			r.tags.add_child(Kit.tag(Kit.type_name(t), Kit.type_col(t), 12))
		r.info.text = _move_info(id) if id != "" else ""
		b.tooltip_text = String(Dex.move(id).get("desc", ""))


func _refresh_status() -> void:
	var ok := Cfg.can_start(cfg)
	_start_btn.disabled = not ok
	_status.text = _msg if ok else "Cada time precisa de pelo menos um Pokémon para começar."
	_status.add_theme_color_override("font_color", Kit.INK if ok else Kit.RED)


func _note(text: String) -> void:
	_msg = text
	_refresh_status()


# --- Sinais dos controles ---


func _on_speed(i: int) -> void:
	if not _syncing:
		set_speed(Cfg.SPEEDS[i])


func _on_seed(v: float) -> void:
	if not _syncing:
		set_seed(int(v))


func _on_team_name(text: String, i: int) -> void:
	if not _syncing:
		set_team_name(i, text)


func _on_team_item(k: int, i: int) -> void:
	if not _syncing:
		set_team_item(i, String(_teams[i].item.get_item_metadata(k)))


func _on_think(v: float, i: int) -> void:
	if not _syncing:
		set_think(i, v)


func _on_limit(v: float) -> void:
	if not _syncing:
		set_time_limit(int(v))


func _on_turbo(on: bool) -> void:
	if not _syncing:
		set_turbo(on)


## Seleção pela lista de um time: confirma o texto pendente no Pokémon aberto antes de trocar.
func _on_team_pick(k: int, i: int) -> void:
	if not _syncing:
		_commit_edits()
		select.call_deferred(i, k)


## Só o botão esquerdo troca o Pokémon (roda e botão direito também chegam aqui).
func _on_team_click(k: int, _at: Vector2, button: int, i: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_commit_edits()
		select.call_deferred(i, k)


func _on_species_pick(k: int) -> void:
	if not _syncing:
		set_species(String(_sp_list.get_item_metadata(k)))


## Clique na lista de golpes: põe no slot marcado e passa ao próximo (golpe repetido é ignorado).
func _on_move_click(k: int, _at: Vector2, button: int) -> void:
	_mv_list.deselect_all()
	var id := String(_mv_list.get_item_metadata(k))
	var e := _entry()
	if button != MOUSE_BUTTON_LEFT or e.is_empty() or (e.get("moves", []) as Array).has(id):
		return
	set_move(move_slot, id)
	if id != "":
		move_slot = mini(move_slot + 1, Mon.MAX_MOVES - 1)
		_refresh_all()


func _on_move_slot(k: int) -> void:
	move_slot = k
	_refresh_all()


func _on_nick(text: String) -> void:
	if not _syncing:
		set_field("nickname", text)


func _on_level(v: float) -> void:
	if not _syncing:
		set_level(int(v))


func _on_option(k: int, opt: OptionButton, key: String) -> void:
	if not _syncing:
		set_field(key, opt.get_item_metadata(k))


func _on_int_field(v: float, key: String) -> void:
	if not _syncing:
		set_field(key, int(v))


func _on_pp(v: float) -> void:
	if not _syncing:
		set_field("pp", v)


func _on_iv(v: float, s: String) -> void:
	if not _syncing:
		set_iv(s, int(v))


func _on_ev(v: float, s: String) -> void:
	if not _syncing:
		set_ev(s, int(v))
