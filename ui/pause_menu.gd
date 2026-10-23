extends CanvasLayer
## Menu de pausa do overworld (autoload PauseMenu): Pokémon, Bolsa, Salvar, Fechar.
## Abre com a ação "pause" (Esc) quando o Game não está ocupado. Não pausa a árvore:
## o jogador do overworld consulta PauseMenu.is_open() para não andar.

const Kit := preload("res://ui/ui_kit.gd")
const ENTRIES := ["Pokémon", "Bolsa", "Salvar", "Fechar"]
const CATS := [["medicine", "Remédios"], ["berries", "Frutas"], ["tm", "MTs"], ["balls", "Pokébolas"], ["key", "Itens-chave"]]
const PARTY_W := [170, 70, 120, 50]

## Instâncias injetáveis (testes). Vazias = autoloads /root/Game e /root/LearnMove.
var game: Node = null
var learn: Node = null
## "" fechado | "main" | "party" | "summary" | "bag" | "target" | "msg"
var screen := ""
var cursor := 0
var message := ""

var _root: Control
var _box: VBoxContainer
var _main_cur := 0
var _party_cur := 0
var _cat := ""
var _bag_cur := 0
var _item := ""
var _back_to := "main"
var _closed_at := -1


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game == null:
		game = get_node_or_null("/root/Game")
	var w := Kit.window(self, Vector2(760, 0))
	_root = w[0]
	_box = w[1]
	_root.visible = false


## Verdadeiro também no frame em que fechou, para a tecla de confirmar não vazar para o overworld.
func is_open() -> bool:
	return screen != "" or Engine.get_process_frames() == _closed_at


func _learn_open() -> bool:
	if learn == null:
		learn = get_node_or_null("/root/LearnMove")
	return learn != null and learn.state != ""


func open() -> bool:
	if screen != "" or game == null or game.is_busy() or _learn_open() or _story_running():
		return false
	_root.visible = true
	_main_cur = 0
	_go("main")
	return true


func close() -> void:
	screen = ""
	_closed_at = Engine.get_process_frames()
	_root.visible = false
	Kit.clear(_box)


func _story_running() -> bool:
	var st := get_node_or_null("/root/Story")
	return st != null and st.is_running()


func _unhandled_input(ev: InputEvent) -> void:
	if screen != "":
		return
	var esc: bool = ev is InputEventKey and ev.pressed and not ev.echo and (ev.physical_keycode == KEY_ESCAPE or ev.keycode == KEY_ESCAPE)
	if esc or (InputMap.has_action("pause") and ev.is_action_pressed("pause")):
		if open():
			get_viewport().set_input_as_handled()


func _input(ev: InputEvent) -> void:
	if screen == "" or _learn_open():
		return
	var a := Kit.nav(ev)
	if a == "":
		return
	get_viewport().set_input_as_handled()
	press(a)


## Aplica uma ação de navegação ("up" "down" "left" "right" "ok" "back"). Usado pelo _input e pelos testes.
func press(a: String) -> void:
	if screen == "" or _learn_open():
		return
	preload("res://audio/cue.gd").ui(a)
	match screen:
		"main":
			_main_cur = _step(_main_cur, a, ENTRIES.size())
			if a == "back":
				close()
				return
			if a == "ok":
				match _main_cur:
					0:
						_party_cur = 0
						_go("party")
					1:
						_cat = _first_cat()
						_bag_cur = 0
						_go("bag")
					2:
						_save()
					3:
						close()
						return
		"party":
			_party_cur = _step(_party_cur, a, game.party.size())
			if a == "back":
				_go("main")
			elif a == "ok" and not game.party.is_empty():
				_go("summary")
		"summary":
			if a in ["left", "up"]:
				_party_cur = posmod(_party_cur - 1, game.party.size())
			elif a in ["right", "down"]:
				_party_cur = posmod(_party_cur + 1, game.party.size())
			elif a in ["back", "ok"]:
				_go("party")
		"bag":
			var cats := _cats()
			if a == "left" and not cats.is_empty():
				_cat = cats[posmod(cats.find(_cat) - 1, cats.size())]
				_bag_cur = 0
			elif a == "right" and not cats.is_empty():
				_cat = cats[posmod(cats.find(_cat) + 1, cats.size())]
				_bag_cur = 0
			var items := _items()
			_bag_cur = _step(_bag_cur, a, items.size())
			if a == "back":
				_go("main")
			elif a == "ok" and not items.is_empty():
				_item = items[_bag_cur]
				if not _usable_outside(_item):
					_msg("Não dá para usar isso agora.", "bag")
				elif game.party.is_empty():
					_msg("Você não tem Pokémon.", "bag")
				else:
					_party_cur = 0
					_go("target")
		"target":
			_party_cur = _step(_party_cur, a, game.party.size())
			if a == "back":
				_go("bag")
			elif a == "ok":
				_use(game.party[_party_cur])
		"msg":
			if a in ["ok", "back"]:
				_go(_back_to)
	cursor = _cursor()
	_render()


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
	cursor = _cursor()
	_render()


func _msg(text: String, back: String) -> void:
	message = text
	_back_to = back
	_go("msg")


func _cursor() -> int:
	match screen:
		"main": return _main_cur
		"party", "summary", "target": return _party_cur
		"bag": return _bag_cur
	return 0


func _save() -> void:
	var extra := {}
	var p: Node3D = null
	var world: Node = null
	if is_inside_tree():
		p = get_tree().get_first_node_in_group("ow_player") as Node3D
		world = get_tree().get_first_node_in_group("ow_root")
	if world and world.has_method("save_extra"):
		extra = world.save_extra()  # {"pos": [x, y, z], "zone" | "interior": id}
	elif p:
		var v := p.global_position
		extra = {"pos": [v.x, v.y, v.z]}
	_msg("Jogo salvo." if game.save_game(extra) else "Não foi possível salvar.", "main")


func _use(m: Mon) -> void:
	var iname := Kit.item_name(_item)
	var text: String = game.use_item(_item, m)
	if text == "":
		text = "%s não teria efeito em %s." % [iname, m.display_name]
	if not game.bag.has(_item):
		_bag_cur = 0
		if _items().is_empty():
			var cats := _cats()
			_cat = cats[0] if not cats.is_empty() else _cat
	_msg(text, "bag")


func _usable_outside(id: String) -> bool:
	var fx: Dictionary = Dex.item(id).get("effect", {})
	for k in ["hp", "revive", "cure", "level", "teach", "evolve"]:
		if fx.has(k):
			return true
	return false


func _cat_of(id: String) -> String:
	var c := String(Dex.item(id).get("category", ""))
	for e in CATS:
		if e[0] == c:
			return c
	return "key"


## Categorias com pelo menos um item na bolsa, na ordem de CATS.
func _cats() -> Array:
	var out: Array = []
	for e in CATS:
		for id in game.bag:
			if int(game.bag[id]) > 0 and _cat_of(id) == e[0]:
				out.append(e[0])
				break
	return out


func _first_cat() -> String:
	var c := _cats()
	return c[0] if not c.is_empty() else "medicine"


func _items() -> Array:
	var out: Array = []
	for id in game.bag:
		if int(game.bag[id]) > 0 and _cat_of(id) == _cat:
			out.append(id)
	out.sort_custom(func(x, y): return Kit.item_name(x) < Kit.item_name(y))
	return out


# --- Desenho (refeito a cada tecla) ---

func _render() -> void:
	Kit.clear(_box)
	match screen:
		"main": _render_main()
		"party": _render_party("Pokémon", "↑/↓ escolhe · E resumo · Esc volta")
		"target": _render_party("Usar %s em qual Pokémon?" % Kit.item_name(_item), "↑/↓ escolhe · E usa · Esc volta")
		"summary": _render_summary()
		"bag": _render_bag()
		"msg":
			var l := Kit.label(message)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_box.add_child(l)
			_box.add_child(Kit.hint("E/Enter: continuar"))


func _render_main() -> void:
	_box.add_child(Kit.label("Menu", Kit.TEXT, 24))
	_box.add_child(Kit.label("Dinheiro: $%d" % int(game.money), Kit.DIM))
	for i in ENTRIES.size():
		_box.add_child(Kit.row([ENTRIES[i]], [200], i == _main_cur))
	_box.add_child(Kit.hint("↑/↓ escolhe · E/Enter confirma · Esc fecha"))


func _render_party(title: String, hint: String) -> void:
	_box.add_child(Kit.label(title, Kit.TEXT, 22))
	if game.party.is_empty():
		_box.add_child(Kit.label("Nenhum Pokémon.", Kit.DIM))
	for i in game.party.size():
		var m: Mon = game.party[i]
		var cols := [m.display_name, "Nv %d" % m.level, ["HP %d/%d" % [m.hp, m.max_hp], Kit.hp_color(m)],
			[Kit.status_text(m), Kit.BAD]]
		if screen == "target":
			cols.append(["" if Items.can_use(_item, m) else "sem efeito", Kit.DIM])
		_box.add_child(Kit.row(cols, PARTY_W, i == _party_cur))
	_box.add_child(Kit.hint(hint))


func _render_summary() -> void:
	var m: Mon = game.party[_party_cur]
	var types := " / ".join(PackedStringArray(m.types.map(func(t): return Kit.type_name(t))))
	_box.add_child(Kit.label("%s  Nv %d" % [m.display_name, m.level], Kit.TEXT, 24))
	_box.add_child(Kit.label("%s · %s · HP %d/%d %s" % [m.species, types, m.hp, m.max_hp, Kit.status_text(m)], Kit.DIM))
	_box.add_child(Kit.label("Natureza: %s" % Kit.nature_text(m.nature)))
	var nxt := "nível máximo" if m.level >= Growth.MAX_LEVEL else "%d XP para o próximo nível" % (m.exp_next_level - m.xp)
	_box.add_child(Kit.label("XP: %d · %s" % [m.xp, nxt]))
	var w := [130, 80, 60, 60]
	_box.add_child(Kit.row(["Atributo", "Valor", "IV", "EV"], w, false, true))
	for s in StatCalc.STATS:
		var mult := StatCalc.nature_mult(m.nature, s)
		var c := Kit.GOOD if mult > 1.0 else (Kit.BAD if mult < 1.0 else Kit.TEXT)
		_box.add_child(Kit.row([[Kit.STATS[s], c], str(m.stat(s)), str(int(m.ivs.get(s, 0))), str(int(m.evs.get(s, 0)))], w))
	_box.add_child(Kit.label("Golpes", Kit.DIM))
	for id in m.moves:
		_box.add_child(Kit.row(Kit.move_cols(id), [200, 110, 100, 60, 60]))
	_box.add_child(Kit.hint("←/→ troca de Pokémon (%d/%d) · Esc volta" % [_party_cur + 1, game.party.size()]))


func _render_bag() -> void:
	_box.add_child(Kit.label("Bolsa", Kit.TEXT, 22))
	var cats := _cats()
	if cats.is_empty():
		_box.add_child(Kit.label("A bolsa está vazia.", Kit.DIM))
		_box.add_child(Kit.hint("Esc volta"))
		return
	if not cats.has(_cat):
		_cat = cats[0]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for e in CATS:
		if cats.has(e[0]):
			tabs.add_child(Kit.row([e[1]], [], e[0] == _cat))
	_box.add_child(tabs)
	var items := _items()
	for i in items.size():
		_box.add_child(Kit.row([Kit.item_name(items[i]), "x%d" % int(game.bag[items[i]])], [260, 60], i == _bag_cur))
	if not items.is_empty():
		var d := Kit.label(String(Dex.item(items[clampi(_bag_cur, 0, items.size() - 1)]).get("description", "")), Kit.DIM, 15)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(d)
	_box.add_child(Kit.hint("←/→ categoria · ↑/↓ item · E usa · Esc volta"))
