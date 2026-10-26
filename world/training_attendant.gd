class_name TrainingAttendant
extends WorldNpc
## Coordenador do acampamento de treino (world/training_attendant.gd do original). Depois da fala pergunta
## qual boneco enfrentar (espécie e o EV que ela dá), esconde a placa daquele boneco e começa a luta de
## treino (Battle.start_training_battle): um selvagem com a cara da placa, no centro da quadra do campo
## "attendant" do mapa, parado e imortal no nível do seu Pokémon; cada KO dá os EVs dele, e só acaba
## com FUGIR. Entrada do mapa: "attendant": {options: ["Espécie|nível|placa"], center: [x, y, z], size: [w, d]}.

const Kit := preload("res://ui/ui_kit.gd")
const QUESTION := "Which dummy do you want to face?"

## Testes: >= 0 responde a escolha sozinho com essa opção (-1 = cancela; -2 = jogador escolhe).
static var auto_pick := -2

@export var train_options: PackedStringArray
@export var arena_center := Vector3.INF  ## local ao MapBuilder (pai)
@export var arena_size := Vector2.ZERO

var picker: ChoiceBox  ## aberto enquanto pergunta


## Lista de escolhas com a pergunta numa caixa de fala (PkDialogBox.ask_choice do original).
class ChoiceBox:
	extends CanvasLayer
	signal chose(i: int)
	const ARM_S := 0.2  ## ignora o aperto de E que fechou a última fala
	var speaker := ""
	var question := ""
	var items: Array = []
	var index := 0
	var _rows: VBoxContainer
	var _age := 0.0
	var _done := false

	func _ready() -> void:
		layer = 30
		var root := Control.new()
		root.theme = Kit.ui_theme()
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root)
		var dlg := Kit.Dialog.new()
		dlg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		dlg.offset_left = -400
		dlg.offset_right = 400
		dlg.offset_top = -168
		dlg.offset_bottom = -22
		root.add_child(dlg)
		dlg.show_line(speaker, question, true)
		var pw: Array = Kit.panel("", Vector2.ZERO, 2)
		var win: Control = pw[0]
		_rows = pw[1]
		win.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		win.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		win.grow_vertical = Control.GROW_DIRECTION_BEGIN
		win.offset_left = 388
		win.offset_right = 388
		win.offset_top = -178
		win.offset_bottom = -178
		root.add_child(win)
		_refresh()
		Kit.pop_in(win)

	func _refresh() -> void:
		Kit.clear(_rows)
		for i in items.size():
			_rows.add_child(Kit.row([String(items[i])], [], i == index))

	func _process(dt: float) -> void:
		_age += dt

	func _input(ev: InputEvent) -> void:
		if _done or _age < ARM_S:
			return
		var a := Kit.nav(ev)
		if a == "" and ev.is_action_pressed("interact"):
			a = "ok"
		if a == "":
			return
		get_viewport().set_input_as_handled()
		match a:
			"up":
				index = posmod(index - 1, items.size())
				_refresh()
			"down":
				index = posmod(index + 1, items.size())
				_refresh()
			"ok":
				pick(index)
			"back":
				pick(-1)

	## i < 0 = cancelou.
	func pick(i: int) -> void:
		if _done:
			return
		_done = true
		chose.emit.call_deferred(i)


## "Rattata|5|prop_dummy_rattata" -> {species, level, card} ({} se faltar algo).
static func parse_option(entry: String) -> Dictionary:
	var parts := entry.split("|")
	if parts.size() < 3 or parts[0].strip_edges() == "":
		return {}
	return {
		"species": parts[0].strip_edges(), "level": int(parts[1]), "card": parts[2].strip_edges()
	}


## {"spe": 1} -> "Speed +1".
static func ev_label(ev_yield: Dictionary) -> String:
	var parts: Array = []
	for s in ev_yield:
		parts.append("%s +%d" % [Kit.STATS.get(s, String(s).to_upper()), int(ev_yield[s])])
	return ", ".join(parts)


## NPC a partir do bloco "attendant" do mapa (mb dá a altura do chão no centro da quadra).
static func from_entry(att: Dictionary, mb: Node) -> TrainingAttendant:
	var t := TrainingAttendant.new()
	t.train_options = PackedStringArray(att.get("options", []))
	var c: Array = att.get("center", [])
	if c.size() >= 3:
		var x := float(c[0])
		var z := float(c[2])
		var y := float(mb.height_at(x, z)) if mb and mb.has_method("height_at") else float(c[1])
		t.arena_center = Vector3(x, y, z)
	var s: Array = att.get("size", [])
	if s.size() >= 2:
		t.arena_size = Vector2(float(s[0]), float(s[1]))
	return t


func interact(p: OverworldPlayer) -> void:
	await super(p)
	talking = true
	await finish_talk()
	talking = false


func finish_talk() -> void:
	var options: Array = []
	var items: Array = []
	for entry in train_options:
		var o := parse_option(entry)
		if o.is_empty():
			continue
		options.append(o)
		var sp := Dex.species(String(o.species))
		items.append("%s — %s" % [String(o.species).to_upper(), ev_label(sp.get("ev_yield", {}))])
	if options.is_empty():
		return
	var pick := await ask_choice(QUESTION, items)
	if pick < 0 or pick >= options.size():
		return
	var chosen: Dictionary = options[pick]
	var slot := String(chosen.card)
	var card := slot if slot.begins_with("res://") else "%ssprites/%s.png" % [WorldFx.ART, slot]
	var board := _nearest_board(slot)
	if board:
		board.visible = false
	await start_training_battle(String(chosen.species), int(chosen.level), card)
	if is_instance_valid(board):
		board.visible = true


## Índice escolhido (-1 = cancelou).
func ask_choice(question: String, items: Array) -> int:
	picker = ChoiceBox.new()
	picker.speaker = npc_name
	picker.question = question
	picker.items = items
	add_child(picker)
	if auto_pick > -2:
		picker.pick.call_deferred(auto_pick)
	var i: int = await picker.chose
	picker.queue_free()
	picker = null
	return i


## Battle.start_training_battle do original, pela ponte Overworld.battle -> Game.request_battle.
func start_training_battle(species: String, level: int, card_path: String) -> Dictionary:
	var ow := Overworld.of(self)
	if ow == null or Game.is_busy():
		return {}
	if Game.party.is_empty():
		await say(["You don't have any Pokémon! Get one at the lab first."])
		return {}
	if Game.first_healthy() < 0:
		await say(["All your Pokémon have fainted!"])
		return {}
	var center := global_position
	if arena_center.is_finite():
		center = get_parent().to_global(arena_center) if get_parent() is Node3D else arena_center
	var opts := {
		"kind": "wild", "can_run": true, "training": true, "center": center, "card": card_path
	}
	if arena_size.x > 0.0:
		opts["arena"] = arena_size
	return await ow.battle([Mon.create(species, level)], opts)


## Placa do mapa com esse sprite mais perto do Coordenador.
func _nearest_board(card: String) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("sprite_prop"):
		if String(n.get_meta("sprite", "")) != card:
			continue
		var d: float = (n as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	return best
