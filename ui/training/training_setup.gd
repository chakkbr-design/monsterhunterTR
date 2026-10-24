extends Control
## Modo de treinamento: monta os dois times que lutam sozinhos (IA dos dois lados) e as opções da
## luta, tudo numa tela só (sem rolagem). Cada time tem 6 slots; clicar num slot vazio abre a
## lista de espécies, clicar num golpe abre a lista dos golpes que a espécie aprende. Por Pokémon:
## espécie, natureza, habilidade, golpes (qualquer golpe que a espécie aprende) e HP/status/PP
## iniciais. Todos lutam no Nv 50 e sem IVs e EVs (ver training_config.gd). Times salvos em slots. Só mouse, com os controles padrão do Godot.
## A config (formato em training_config.gd) fica em Cfg.current enquanto o jogo está aberto.

const Kit := preload("res://ui/ui_kit.gd")
const Cfg := preload("res://ui/training/training_config.gd")

const BATTLE_SCENE := "res://ui/training/training_battle.tscn"
const TITLE_SCENE := "res://ui/front/title.tscn"
const FONT_SIZE := 14
const SMALL_SIZE := 12
const ICON_PX := 32
const SPRITE_PX := 76
const TEAM_W := 236
const THINK_MIN := 0.25
const THINK_MAX := 4.0
const STAT_BAR_W := 150
const STAT_BAR_MAX := 160.0
const THINK_TIP := (
	"Multiplica o tempo entre golpes e a chance de erro: até 0,8 = sem erro e mais rápida;"
	+ " 1 = treinador normal; 1,6 ou mais = golpe sempre aleatório (salvo o que nocauteia)"
)
const STAT_ABBR := {"atk": "Atq", "def": "Def", "spa": "At.Esp", "spd": "Def.Esp", "spe": "Vel"}

var cfg: Dictionary = {}
## Pokémon em edição: lado (0 = Time A, 1 = Time B) e posição no time (-1 = time vazio).
var side := 0
var slot := 0
## Troca de cena; o teste troca por uma função que só registra o caminho.
var change_scene: Callable

var _syncing := false
var _msg := ""
var _teams: Array = []
var _type_icons := {}
## Espécies pela ordem da Pokédex (dex_no).
var _species_order: Array = []

var _status: Label
var _start_btn: Button
var _speed: OptionButton
var _seed: SpinBox
var _turbo: CheckBox
var _battle: OptionButton
var _limit: SpinBox
var _empty_note: Label
var _editor: Control
var _where: Label
var _title: Label
var _sprite: TextureRect
var _types: HBoxContainer
var _level: Label
var _nature: OptionButton
var _ability: OptionButton
var _ability_desc: Label
var _hp: SpinBox
var _hp_info: Label
var _cond: OptionButton
var _pp: SpinBox
var _pp_info: Label
var _stat_name := {}
var _base := {}
var _bar := {}
var _final := {}
var _total: Label
var _move_rows: Array = []

## Janela de escolha aberta por cima da tela (espécie, golpe ou times salvos); "" = nenhuma.
var picker := ""
## Para quem a janela escolhe: lado, posição (-1 = Pokémon novo) e slot de golpe.
var _pick_side := 0
var _pick_slot := 0
var _pick_move := 0
## Slot de time salvo marcado na janela de times salvos (-1 = nenhum).
var _team_slot := -1
var _confirm_clear := false
var _ov: Control
var _ov_title: Label
var _ov_search: LineEdit
var _ov_list: ItemList
var _ov_hint: Label
var _ov_buttons: HBoxContainer
var _slot_btns := {}


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
	select(0, 0)


func _exit_tree() -> void:
	Cfg.block_pause_menu(get_tree(), false)


## Esc fecha a janela de escolha; sem janela (e fora de um campo de texto), volta ao título.
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if picker != "":
			close_picker()
		else:
			back_to_title()


# --- API (botões e teste) ---


func select(s: int, k: int) -> void:
	side = clampi(s, 0, Cfg.SIDES - 1)
	var n := _mons(side).size()
	slot = clampi(k, 0, n - 1) if n > 0 else -1
	_refresh_all()


func set_species(id: String) -> void:
	var e := _entry()
	var sp := Dex.canon(id)
	if e.is_empty() or sp == "":
		return
	var was_full := float(e.get("pp", 0.0)) >= _pp_base(String(e.get("species", "")))
	var abil: Array = Dex.species(sp).get("abilities", [])
	e["species"] = sp
	e["moves"] = Dex.moves_at(sp, Cfg.LEVEL)
	e["ability_slot"] = clampi(int(e.get("ability_slot", 0)), 0, maxi(abil.size() - 1, 0))
	e["gender"] = _valid_gender(sp, String(e.get("gender", "")))
	e["pp"] = _pp_base(sp) if was_full else minf(float(e.get("pp", 0.0)), _pp_base(sp))
	e["evo_pending"] = false
	e["evo_cancelled_level"] = 0
	_refresh_all()


## Põe o golpe `id` no slot k (0..3); "" tira o golpe. Golpe repetido troca de lugar.
## Só golpes que a espécie aprende (em qualquer nível).
func set_move(k: int, id: String) -> void:
	var e := _entry()
	if e.is_empty() or k < 0 or k >= Mon.MAX_MOVES:
		return
	if id != "" and not can_use_move(id):
		_note("%s não aprende %s." % [e.species, Kit.move_name(id)])
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


## A espécie em edição aprende o golpe (em qualquer nível).
func can_use_move(id: String) -> bool:
	var e := _entry()
	if e.is_empty():
		return false
	return Cfg.learn_level(String(e.get("species", "")), id) >= 0


## Golpes que a espécie sabe no Nv 50 (Dex.moves_at).
func moves_for_level() -> void:
	var e := _entry()
	if not e.is_empty():
		set_field("moves", Dex.moves_at(String(e.species), Cfg.LEVEL))


## Campo simples da entrada em edição: level, nature, ability_slot, hp_pct, status, pp, moves.
func set_field(key: String, value) -> void:
	var e := _entry()
	if e.is_empty():
		return
	e[key] = value
	_refresh_all()


## Põe um Pokémon novo (espécie `sp`, ou a 1ª da Pokédex) no fim do time s.
func add_mon(s: int, sp := "") -> void:
	var mons := _mons(s)
	if mons.size() >= Cfg.PARTY_MAX:
		return
	var id := Dex.canon(sp) if Dex.canon(sp) != "" else String(_species_order[0])
	mons.append(Cfg.mon_entry(id, Cfg.LEVEL))
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


## Batalha 1x1 (1) ou 2x2 (2): quantos Pokémon de cada time lutam ao mesmo tempo.
func set_battle_size(n: int) -> void:
	cfg["battle_size"] = 1 if n == 1 else 2
	_refresh_all()


## Limite de tempo de jogo da luta em segundos (0 = sem limite).
func set_time_limit(v: int) -> void:
	cfg["time_limit"] = clampi(v, 0, 3600)
	_refresh_all()


## Grava o time s no slot salvo k (sobrescreve).
func save_team(s: int, k: int) -> void:
	_commit_edits()
	if _mons(s).is_empty():
		_note("O %s está vazio: nada para salvar." % _side_name(s))
		return
	Cfg.save_team(k, cfg.sides[s])
	_note("%s salvo no slot %d." % [_side_name(s), k + 1])
	_refresh_picker()


## Põe o time do slot salvo k no lado s (nome, item, nível da IA e Pokémon).
func load_team(s: int, k: int) -> void:
	var t: Dictionary = Cfg.load_teams()[k] if k >= 0 and k < Cfg.TEAM_SLOTS else {}
	if t.is_empty():
		_note("O slot %d está vazio." % (k + 1))
		return
	t.erase("saved_at")
	t["mons"] = (t.mons as Array).slice(0, Cfg.PARTY_MAX)
	cfg.sides[s] = t
	select(s, 0)
	_note("Slot %d carregado no %s." % [k + 1, "Time A" if s == 0 else "Time B"])
	close_picker()


func clear_team_slot(k: int) -> void:
	Cfg.save_team(k, {})
	_note("Slot %d apagado." % (k + 1))
	_refresh_picker()


func reset_default() -> void:
	cfg = Cfg.default_config()
	Cfg.current = cfg
	select(0, 0)
	_note("Times e opções padrão restaurados.")


func start() -> void:
	_commit_edits()
	if not Cfg.can_start(cfg):
		_refresh_status()
		return
	Cfg.current = cfg
	Cfg.save_config(cfg)
	change_scene.call(BATTLE_SCENE)


## Volta ao título guardando a config (ela volta igual na próxima vez).
func back_to_title() -> void:
	_commit_edits()
	Cfg.save_config(cfg)
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


# --- Janelas de escolha ---


## Clique num slot do time: slot cheio abre o Pokémon; o 1º vazio abre a lista de espécies.
func click_slot(s: int, k: int) -> void:
	_commit_edits()
	if k < _mons(s).size():
		select(s, k)
	elif k == _mons(s).size() and k < Cfg.PARTY_MAX:
		open_species(s, -1)


## Lista de espécies para o Pokémon k do time s (-1 = Pokémon novo no fim do time).
func open_species(s: int, k: int) -> void:
	_pick_side = s
	_pick_slot = k
	_open("species")


## Lista dos golpes que a espécie aprende, para o slot de golpe k do Pokémon em edição.
func open_moves(k: int) -> void:
	if _entry().is_empty():
		return
	_pick_move = clampi(k, 0, Mon.MAX_MOVES - 1)
	_open("moves")


func open_teams(s: int) -> void:
	_pick_side = s
	_team_slot = -1
	_open("teams")


func close_picker() -> void:
	picker = ""
	_confirm_clear = false
	if _ov:
		_ov.visible = false


## Escolha na janela aberta (metadado do item: id da espécie, do golpe ou nº do slot).
func pick(value) -> void:
	match picker:
		"species":
			var sp := String(value)
			close_picker()
			if _pick_slot < 0:
				add_mon(_pick_side, sp)
				_note("%s entrou no %s." % [sp, _side_name(_pick_side)])
			else:
				select(_pick_side, _pick_slot)
				set_species(sp)
		"moves":
			close_picker()
			set_move(_pick_move, String(value))
		"teams":
			_team_slot = int(value)
			_confirm_clear = false
			_refresh_picker()


func _open(kind: String) -> void:
	_commit_edits()
	picker = kind
	_confirm_clear = false
	_ov_search.text = ""
	_ov_search.visible = kind != "teams"
	_ov.visible = true
	_refresh_picker()
	if kind != "teams" and is_inside_tree():
		_ov_search.grab_focus()


func _refresh_picker() -> void:
	if picker == "":
		return
	_ov_list.clear()
	Kit.clear(_ov_buttons)
	_slot_btns.clear()
	match picker:
		"species":
			_fill_species()
		"moves":
			_fill_moves()
		"teams":
			_fill_teams()
	var b := _btn("Fechar (Esc)", close_picker)
	_ov_buttons.add_child(b)


func _fill_species() -> void:
	var editing := _pick_slot >= 0
	var cur := ""
	if editing and _pick_slot < _mons(_pick_side).size():
		cur = Dex.canon(String(_mons(_pick_side)[_pick_slot].get("species", "")))
	_ov_title.text = (
		"Trocar a espécie (%s, %dº)" % [_side_name(_pick_side), _pick_slot + 1]
		if editing
		else "Novo Pokémon no %s" % _side_name(_pick_side)
	)
	_ov_hint.text = "Clique numa espécie. A busca acha nome, número ou tipo."
	var q := _ov_search.text.strip_edges().to_lower()
	for sp in _species_order:
		var d := Dex.species(sp)
		var names := PackedStringArray()
		var keys := String(sp).to_lower()
		for t in d.get("types", []):
			names.append(Kit.type_name(String(t)))
			keys += " %s %s" % [t, Kit.type_name(String(t)).to_lower()]
		var total := 0
		for s in StatCalc.STATS:
			total += int(d.get("base", {}).get(s, 0))
		var text := (
			"#%03d  %s   %s   ·   total %d" % [int(d.get("dex_no", 0)), sp, "/".join(names), total]
		)
		if q != "" and not (keys + " " + text.to_lower()).contains(q):
			continue
		var i := _ov_list.add_item(text, Kit.mon_fitted(sp, ICON_PX))
		_ov_list.set_item_metadata(i, String(sp))
		if sp == cur:
			_ov_list.select(i)
			_ov_list.ensure_current_is_visible()


func _fill_moves() -> void:
	var e := _entry()
	var sp := String(e.get("species", ""))
	var mv: Array = e.get("moves", [])
	var cur := String(mv[_pick_move]) if _pick_move < mv.size() else ""
	_ov_title.text = "Golpe %d de %s (Nv %d)" % [_pick_move + 1, sp, Cfg.LEVEL]
	_ov_hint.text = "Todos os golpes que %s aprende, em qualquer nível." % sp
	var q := _ov_search.text.strip_edges().to_lower()
	if cur != "" and mv.size() > 1:
		var i0 := _ov_list.add_item("(vazio): tirar %s deste slot" % Kit.move_name(cur))
		_ov_list.set_item_metadata(i0, "")
	for le in Cfg.learnable_moves(sp):
		var id := String(le.id)
		var m := Dex.move(id)
		var t := String(m.get("type", "normal"))
		var when := "qualquer nível" if int(le.level) == 0 else "Nv %d" % int(le.level)
		var text := (
			"%s   ·   %s   ·   %s   ·   %s"
			% [Kit.move_name(id), Kit.type_name(t), _move_info(id), when]
		)
		if mv.has(id):
			text += "   (já tem)"
		if q != "" and not ("%s %s %s" % [id, t, text.to_lower()]).contains(q):
			continue
		var i := _ov_list.add_item(text, _type_icon(t))
		_ov_list.set_item_metadata(i, id)
		_ov_list.set_item_tooltip(i, String(m.get("desc", "")))
		if id == cur:
			_ov_list.select(i)
			_ov_list.ensure_current_is_visible()


func _fill_teams() -> void:
	var s := _pick_side
	_ov_title.text = "Times salvos (%s)" % _side_name(s)
	_ov_hint.text = (
		"Marque um slot e escolha: salvar o %s nele ou carregar o time dele." % (_side_name(s))
	)
	var all := Cfg.load_teams()
	for k in all.size():
		var t: Dictionary = all[k]
		var text := "Slot %d   ·   (vazio)" % (k + 1)
		var icon: Texture2D = null
		if not t.is_empty():
			var names := PackedStringArray()
			for d in t.mons:
				names.append(String(d.get("species", "?")))
			var nm := String(t.get("name", "")).strip_edges()
			text = (
				"Slot %d   ·   %s   ·   %s   ·   %s"
				% [
					k + 1,
					nm if nm != "" else "(sem nome)",
					", ".join(names),
					String(t.get("saved_at", "")).replace("T", " ").left(16)
				]
			)
			if not t.mons.is_empty():
				icon = Kit.mon_fitted(String(t.mons[0].get("species", "")), ICON_PX)
		var i := _ov_list.add_item(text, icon)
		_ov_list.set_item_metadata(i, k)
	if _team_slot >= 0:
		_ov_list.select(_team_slot)
	var has := _team_slot >= 0
	var full: bool = has and not (all[_team_slot] as Dictionary).is_empty()
	var sv := _btn("Salvar o %s aqui" % _side_name(s), func(): save_team(s, _team_slot))
	sv.disabled = not has
	var ld := _btn("Carregar no %s" % _side_name(s), func(): load_team(s, _team_slot))
	ld.disabled = not full
	var cl := _btn("Confirmar: apagar?" if _confirm_clear else "Apagar slot", _on_clear_team_slot)
	cl.disabled = not full
	for b in [sv, ld, cl]:
		_ov_buttons.add_child(b)
	_slot_btns = {"save": sv, "load": ld, "clear": cl}


## Apagar pede um segundo clique.
func _on_clear_team_slot() -> void:
	if not _confirm_clear:
		_confirm_clear = true
		_refresh_picker()
		return
	_confirm_clear = false
	clear_team_slot(_team_slot)


# --- Dados ---


func _mons(s: int) -> Array:
	var sd: Dictionary = cfg.sides[s]
	if not sd.get("mons") is Array:
		sd["mons"] = []
	return sd.mons


func _entry() -> Dictionary:
	var mons := _mons(side)
	return mons[slot] if slot >= 0 and slot < mons.size() else {}


func _side_name(s: int) -> String:
	return Cfg.side_name(cfg, s)


static func _dex_no(sp: String) -> int:
	return int(Dex.species(sp).get("dex_no", 9999))


static func _pp_base(sp: String) -> float:
	return float(Dex.species(sp).get("pp", 100))


static func _valid_gender(sp: String, g: String) -> String:
	var r := float(Dex.species(sp).get("gender_ratio", 0.5))
	var ok := ["male", "female"]
	if r < 0.0:
		ok = [""]
	elif r <= 0.0:
		ok = ["male"]
	elif r >= 1.0:
		ok = ["female"]
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
	## Poder oficial em "bp" (o "power" dos golpes stream é por tique); sem bp = poder variável.
	var power := int(mv.get("bp", 0))
	var dmg := power > 0 or int(mv.get("power", 0)) > 0
	var acc := int(mv.get("accuracy", 0))
	return (
		"%s · %s · %s"
		% [
			Kit.CATEGORIES.get(cat, cat),
			("Poder %d" % power) if power > 0 else ("Poder —" if dmg else "Sem dano"),
			("%d%%" % acc) if acc > 0 else "Sempre acerta"
		]
	)


static func _mon_line(d: Dictionary) -> String:
	var t := "%s  Nv %d" % [String(d.get("species", "?")), Cfg.LEVEL]
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
		t.set_stylebox(k, "Button", _box(states[k][0], states[k][1], 6, 6, 3))
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
	t.set_stylebox("normal", "LineEdit", _box(Color.WHITE, Kit.RIM, 4, 6, 2))
	t.set_stylebox("read_only", "LineEdit", _box(Kit.BG_ROW, Kit.RIM, 4, 6, 2))
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


func _panel(margin := 10) -> Array:
	var p := PanelContainer.new()
	var sb := Kit.window_box()
	sb.set_content_margin_all(margin)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
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
	v.add_theme_constant_override("separation", 1)
	v.add_child(_small(text))
	v.add_child(c)
	return v


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return o


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
		margin.add_theme_constant_override("margin_" + k, 6)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)
	margin.add_child(main)
	main.add_child(_build_top())
	var body := _hbox(6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	body.add_child(_build_team(0))
	body.add_child(_build_editor())
	body.add_child(_build_team(1))
	_build_overlay()


func _build_top() -> Control:
	var pc := _panel(6)
	var col: VBoxContainer = pc[1]
	var r1 := _hbox(8)
	col.add_child(r1)
	r1.add_child(_btn("‹ Título", back_to_title, "Volta ao título (Esc); a config fica guardada"))
	var h := Kit.header("MODO DE TREINAMENTO", Kit.INK, 22)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r1.add_child(h)
	r1.add_child(
		_btn("Trocar lados", swap_sides, "Troca o Time A e o Time B de lado (com nome e item)")
	)
	r1.add_child(_btn("Padrão", reset_default, "Volta para os times e opções padrão"))
	_start_btn = _btn("Começar batalha", start, "As duas equipes lutam sozinhas, pela IA")
	_start_btn.add_theme_stylebox_override("normal", _box(Kit.RED, Kit.INK, 6, 14, 3))
	_start_btn.add_theme_stylebox_override(
		"hover", _box(Kit.RED.lightened(0.15), Kit.INK, 6, 14, 3)
	)
	_start_btn.add_theme_color_override("font_color", Kit.PAPER)
	_start_btn.add_theme_color_override("font_hover_color", Kit.PAPER)
	r1.add_child(_start_btn)

	var r2 := _hbox(6)
	col.add_child(r2)
	r2.add_child(_small("Formato"))
	_battle = OptionButton.new()
	_battle.add_item("1x1")
	_battle.add_item("2x2")
	_battle.tooltip_text = "Quantos Pokémon de cada time lutam ao mesmo tempo"
	_battle.item_selected.connect(_on_battle)
	r2.add_child(_battle)
	r2.add_child(_small("Velocidade"))
	_speed = OptionButton.new()
	for v in Cfg.SPEEDS:
		_speed.add_item(_speed_text(v))
	_speed.item_selected.connect(_on_speed)
	r2.add_child(_speed)
	_turbo = CheckBox.new()
	_turbo.text = "Turbo"
	_turbo.focus_mode = Control.FOCUS_NONE
	_turbo.tooltip_text = "Roda as lutas o mais rápido possível, para séries longas"
	_turbo.button_down.connect(_commit_edits)
	_turbo.toggled.connect(_on_turbo)
	r2.add_child(_turbo)
	r2.add_child(_small("Limite (s)"))
	_limit = _spin(0, 3600, 5.0, 72)
	_limit.tooltip_text = "Tempo de jogo máximo; ao passar, a luta termina sem vencedor (0 = sem)"
	_limit.value_changed.connect(_on_limit)
	r2.add_child(_limit)
	r2.add_child(_small("Semente"))
	_seed = _spin(-1, 2147483647, 1.0, 110)
	_seed.tooltip_text = "-1 = aleatória; fixa = série reproduzível (luta k da série: semente + k)"
	_seed.value_changed.connect(_on_seed)
	r2.add_child(_seed)
	_status = _clip(Kit.label("", Kit.INK, SMALL_SIZE))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(_status)
	return pc[0]


func _build_team(i: int) -> Control:
	var pc := _panel()
	var p: PanelContainer = pc[0]
	p.custom_minimum_size.x = TEAM_W
	var col: VBoxContainer = pc[1]
	var t := {}
	var head := _hbox(6)
	col.add_child(head)
	t.head = Kit.header("TIME A" if i == 0 else "TIME B", Kit.INK, 20)
	t.head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t.head)
	head.add_child(
		_btn("Times salvos", open_teams.bind(i), "Salvar este time num slot ou carregar um salvo")
	)
	t.name = LineEdit.new()
	t.name.placeholder_text = "Nome do treinador"
	t.name.text_changed.connect(_on_team_name.bind(i))
	col.add_child(t.name)
	var row := _hbox(6)
	col.add_child(row)
	t.item = _option()
	t.item.add_item("Nenhum")
	t.item.set_item_metadata(0, "")
	for id in Cfg.battle_items():
		t.item.add_item(Kit.item_name(id))
		t.item.set_item_metadata(t.item.item_count - 1, id)
	t.item.tooltip_text = "A IA usa o item uma vez por Pokémon (cura de HP ou de status)"
	t.item.item_selected.connect(_on_team_item.bind(i))
	var iv := _labeled("Item do treinador", t.item)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(iv)
	t.think = _spin(THINK_MIN, THINK_MAX, 0.05, 68)
	t.think.tooltip_text = THINK_TIP
	t.think.value_changed.connect(_on_think.bind(i))
	row.add_child(_labeled("Nível da IA", t.think))
	col.add_child(_small("Pokémon (o 1º entra primeiro)"))
	t.slots = []
	for k in Cfg.PARTY_MAX:
		var b := _btn("", click_slot.bind(i, k))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = false
		b.custom_minimum_size.y = ICON_PX + 8
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		col.add_child(b)
		t.slots.append(b)
	var r1 := _hbox(4)
	col.add_child(r1)
	t.up = _btn("▲", func(): move_mon(i, _sel(i), -1), "Sobe na ordem")
	t.down = _btn("▼", func(): move_mon(i, _sel(i), 1), "Desce na ordem")
	t.dup = _btn("Duplicar", func(): duplicate_mon(i, _sel(i)), "Cópia logo abaixo")
	t.rm = _btn("Remover", func(): remove_mon(i, _sel(i)))
	for k in ["up", "down", "dup", "rm"]:
		var b: Button = t[k]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r1.add_child(b)
	col.add_child(
		_btn(
			"Copiar para o Time %s" % ("B" if i == 0 else "A"),
			copy_side.bind(i),
			"Copia os Pokémon, o item e o nível da IA para o outro time"
		)
	)
	_teams.append(t)
	return p


## Pokémon marcado no time i (só o lado em edição tem um).
func _sel(i: int) -> int:
	return slot if i == side else -1


func _build_editor() -> Control:
	var pc := _panel(12)
	var p: PanelContainer = pc[0]
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = pc[1]
	_empty_note = _wrap(
		Kit.label("Time vazio: clique em “+ Adicionar Pokémon” num dos times.", Kit.DIM)
	)
	col.add_child(_empty_note)
	var ed := VBoxContainer.new()
	ed.add_theme_constant_override("separation", 8)
	ed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor = ed
	col.add_child(ed)
	_build_head(ed)
	var mid := _hbox(16)
	ed.add_child(mid)
	_build_stats(mid)
	_build_start_state(mid)
	_build_moves(ed)
	return p


func _build_head(box: VBoxContainer) -> void:
	var head := _hbox(10)
	box.add_child(head)
	_sprite = Kit.sprite_rect(null, Vector2(SPRITE_PX, SPRITE_PX))
	head.add_child(_sprite)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	_where = _clip(_small(""))
	info.add_child(_where)
	var name_row := _hbox(8)
	info.add_child(name_row)
	_title = _clip(Kit.header("", Kit.INK, 24))
	name_row.add_child(_title)
	name_row.add_child(
		_btn("Trocar espécie", func(): open_species(side, slot), "Abre a lista de espécies")
	)
	_types = _hbox(4)
	info.add_child(_types)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 1)
	box.add_child(g)
	_level = Kit.label("Nv %d" % Cfg.LEVEL, Kit.INK, SMALL_SIZE + 1)
	_nature = _option()
	for n in StatCalc.NATURES:
		_nature.add_item(_nature_text(n))
		_nature.set_item_metadata(_nature.item_count - 1, n)
	_nature.tooltip_text = "+10% num atributo e −10% em outro (as neutras não mudam nada)"
	_nature.item_selected.connect(_on_option.bind(_nature, "nature"))
	_ability = _option()
	_ability.item_selected.connect(_on_option.bind(_ability, "ability_slot"))
	for h in ["Nível", "Natureza", "Habilidade"]:
		g.add_child(_small(h))
	for c in [_level, _nature, _ability]:
		g.add_child(c)
	_ability_desc = _wrap(_small("", Kit.INK))
	_ability_desc.custom_minimum_size.y = 30
	box.add_child(_ability_desc)


func _build_stats(box: HBoxContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(v)
	v.add_child(_small("Atributos (base → no nível, com a natureza)"))
	for s in StatCalc.STATS:
		var r := _hbox(6)
		v.add_child(r)
		var nm := Kit.label(String(Kit.STATS[s]), Kit.INK, SMALL_SIZE + 1)
		nm.custom_minimum_size.x = 84
		_stat_name[s] = nm
		_base[s] = Kit.label("", Kit.DIM, SMALL_SIZE + 1)
		_base[s].custom_minimum_size.x = 30
		_base[s].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var track := Control.new()
		track.custom_minimum_size = Vector2(STAT_BAR_W, 10)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bar := ColorRect.new()
		bar.anchor_bottom = 1.0
		track.add_child(bar)
		_bar[s] = bar
		_final[s] = Kit.label("", Kit.INK, SMALL_SIZE + 3)
		_final[s].custom_minimum_size.x = 40
		_final[s].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for c in [nm, _base[s], track, _final[s]]:
			r.add_child(c)
	_total = _small("", Kit.DIM)
	v.add_child(_total)


func _build_start_state(box: HBoxContainer) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 4)
	g.custom_minimum_size.x = 210
	box.add_child(g)
	var head := _small("Começa a luta com")
	g.add_child(head)
	g.add_child(Control.new())
	_hp = _spin(1, 100, 1.0, 72)
	_hp.suffix = "%"
	_hp.value_changed.connect(_on_int_field.bind("hp_pct"))
	_hp_info = _small("", Kit.DIM)
	_cond = _option()
	for s in Cfg.STATUSES:
		_cond.add_item(String(Cfg.STATUS_NAMES.get(s, s)))
		_cond.set_item_metadata(_cond.item_count - 1, s)
	_cond.item_selected.connect(_on_option.bind(_cond, "status"))
	_pp = _spin(0, 100, 1.0, 72)
	_pp.value_changed.connect(_on_pp)
	_pp_info = _small("", Kit.DIM)
	var hp_row := _hbox(4)
	hp_row.add_child(_hp)
	hp_row.add_child(_hp_info)
	var pp_row := _hbox(4)
	pp_row.add_child(_pp)
	pp_row.add_child(_pp_info)
	for r in [["HP", hp_row], ["Status", _cond], ["PP", pp_row]]:
		var l := Kit.label(r[0], Kit.INK, SMALL_SIZE + 1)
		g.add_child(l)
		g.add_child(r[1])


func _build_moves(box: VBoxContainer) -> void:
	var head := _hbox(8)
	box.add_child(head)
	var l := _small("Golpes (clique num golpe para trocar)")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(
		_btn("Golpes do nível", moves_for_level, "Os 4 últimos golpes que aprende até o Nv 50")
	)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	box.add_child(g)
	for k in Mon.MAX_MOVES:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(cell)
		var row := _hbox(4)
		cell.add_child(row)
		var b := _btn("", open_moves.bind(k))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
		var x := _btn("×", set_move.bind(k, ""), "Tirar este golpe")
		row.add_child(x)
		var line := _hbox(4)
		cell.add_child(line)
		var tags := _hbox(4)
		line.add_child(tags)
		var info := _clip(_small("", Kit.INK))
		line.add_child(info)
		_move_rows.append({"btn": b, "x": x, "tags": tags, "info": info})


## Janela por cima de tudo: fundo escuro (clique fora fecha), título, busca, lista e botões.
func _build_overlay() -> void:
	_ov = Control.new()
	_ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ov.visible = false
	add_child(_ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	_ov.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov.add_child(center)
	var pc := _panel(12)
	var p: PanelContainer = pc[0]
	p.custom_minimum_size = Vector2(700, 520)
	center.add_child(p)
	var col: VBoxContainer = pc[1]
	_ov_title = Kit.header("", Kit.INK, 22)
	col.add_child(_ov_title)
	_ov_hint = _wrap(_small("", Kit.DIM))
	col.add_child(_ov_hint)
	_ov_search = LineEdit.new()
	_ov_search.placeholder_text = "Buscar..."
	_ov_search.clear_button_enabled = true
	_ov_search.text_changed.connect(func(_t: String): _refresh_picker())
	_ov_search.text_submitted.connect(_on_search_enter)
	col.add_child(_ov_search)
	_ov_list = ItemList.new()
	_ov_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ov_list.fixed_icon_size = Vector2i(ICON_PX, ICON_PX)
	_ov_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ov_list.item_clicked.connect(_on_list_click)
	col.add_child(_ov_list)
	_ov_buttons = _hbox(6)
	_ov_buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(_ov_buttons)


# --- Tela a partir da config ---


func _refresh_all() -> void:
	_msg = ""
	_syncing = true
	_speed.select(_speed_index())
	_seed.value = int(cfg.get("seed", -1))
	_limit.value = int(cfg.get("time_limit", 0))
	_turbo.set_pressed_no_signal(bool(cfg.get("turbo", false)))
	_battle.select(0 if int(cfg.get("battle_size", 2)) == 1 else 1)
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
	var cur := _sel(i)
	for k in Cfg.PARTY_MAX:
		var b: Button = t.slots[k]
		var on := i == side and k == cur
		b.disabled = k > mons.size()
		b.add_theme_stylebox_override(
			"normal", _box(Kit.RED_SOFT, Kit.RED, 6, 6, 3) if on else _box(Kit.BG_ROW, Kit.RIM)
		)
		if k < mons.size():
			var d: Dictionary = mons[k]
			var sp := Dex.canon(String(d.get("species", "")))
			b.text = "%d. %s" % [k + 1, _mon_line(d)]
			b.icon = Kit.mon_fitted(sp, ICON_PX) if sp != "" else null
			b.tooltip_text = "Clique para editar"
		elif k == mons.size():
			b.text = "+ Adicionar Pokémon"
			b.icon = null
			b.tooltip_text = "Abre a lista de espécies"
		else:
			b.text = ""
			b.icon = null
			b.tooltip_text = ""
	var has := cur >= 0 and cur < mons.size()
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
	_title.text = sp if sp != "" else "(espécie inválida)"
	_sprite.texture = Kit.mon_front(sp) if sp != "" else null
	Kit.clear(_types)
	for t in spd.get("types", []):
		_types.add_child(Kit.tag(Kit.type_name(String(t)), Kit.type_col(String(t)), 12))
	_nature.select(StatCalc.NATURES.keys().find(m.nature))
	_ability.clear()
	var abil: Array = spd.get("abilities", [])
	var hidden := String(spd.get("hidden_ability", ""))
	for k in abil.size():
		var a := Dex.ability(String(abil[k]))
		var nm := String(a.get("name", abil[k])).capitalize()
		_ability.add_item(nm + (" (oculta)" if String(abil[k]) == hidden else ""))
		_ability.set_item_metadata(k, k)
		_ability.set_item_tooltip(k, String(a.get("desc_pt", a.get("desc", ""))))
	if abil.is_empty():
		_ability.add_item("—")
		_ability.set_item_metadata(0, 0)
	var ak := clampi(m.ability_slot, 0, _ability.item_count - 1)
	_ability.select(ak)
	_ability_desc.text = (
		String(
			Dex.ability(String(abil[ak])).get(
				"desc_pt", Dex.ability(String(abil[ak])).get("desc", "")
			)
		)
		if not abil.is_empty()
		else ""
	)
	_hp.value = int(e.get("hp_pct", 100))
	_hp_info.text = "%d / %d" % [m.hp, m.max_hp]
	_cond.select(maxi(Cfg.STATUSES.find(m.status), 0))
	_pp.max_value = m.pp_base
	_pp.value = m.pp
	_pp_info.text = "de %d" % int(m.pp_base)
	var nat: Array = StatCalc.NATURES.get(m.nature, [])
	var total := 0
	for s in StatCalc.STATS:
		var col := Kit.INK
		if not nat.is_empty():
			col = Kit.RED if nat[0] == s else (Kit.BLUE if nat[1] == s else Kit.INK)
		_stat_name[s].add_theme_color_override("font_color", col)
		var base := int(spd.get("base", {}).get(s, 50))
		total += base
		_base[s].text = str(base)
		var bar: ColorRect = _bar[s]
		bar.anchor_right = clampf(base / STAT_BAR_MAX, 0.04, 1.0)
		bar.color = Kit.RED.lerp(Kit.GREEN, clampf((base - 40) / 80.0, 0.0, 1.0))
		_final[s].text = str(m.stat(s))
		_final[s].add_theme_color_override("font_color", col)
	_total.text = "Total base %d" % total
	var mv: Array = e.get("moves", [])
	for k in _move_rows.size():
		var r: Dictionary = _move_rows[k]
		var id := String(mv[k]) if k < mv.size() else ""
		var b: Button = r.btn
		b.text = "%d. %s" % [k + 1, Kit.move_name(id) if id != "" else "+ escolher golpe"]
		b.disabled = k > mv.size()
		r.x.disabled = id == "" or mv.size() <= 1
		Kit.clear(r.tags)
		var t := String(Dex.move(id).get("type", "normal"))
		if id != "":
			r.tags.add_child(Kit.tag(Kit.type_name(t), Kit.type_col(t), 11))
		var info := _move_info(id) if id != "" else ""
		var lv := Cfg.learn_level(sp, id) if id != "" else 0
		if lv < 0:
			info = "não aprende!  " + info
		r.info.text = info
		r.info.add_theme_color_override("font_color", Kit.RED if lv < 0 else Kit.INK)
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


func _on_battle(i: int) -> void:
	if not _syncing:
		set_battle_size(i + 1)


func _on_option(k: int, opt: OptionButton, key: String) -> void:
	if not _syncing:
		set_field(key, opt.get_item_metadata(k))


func _on_int_field(v: float, key: String) -> void:
	if not _syncing:
		set_field(key, int(v))


func _on_pp(v: float) -> void:
	if not _syncing:
		set_field("pp", v)


## Só o botão esquerdo escolhe (roda e botão direito também chegam aqui).
func _on_list_click(k: int, _at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		pick(_ov_list.get_item_metadata(k))


## Enter na busca escolhe o 1º da lista (se for só um, é ele).
func _on_search_enter(_t: String) -> void:
	for k in _ov_list.item_count:
		var v = _ov_list.get_item_metadata(k)
		if v is String and v != "":
			pick(v)
			return


func _on_dim_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		close_picker()
