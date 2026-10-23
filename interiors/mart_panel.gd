class_name MartPanel
extends CanvasLayer
## Poké Mart window: Comprar / Vender / Sair -> item list -> quantity -> confirm.
## Keys: W/S or arrows move, A/D change quantity (W/S ±10 in the quantity box), E/Enter confirm,
## Esc/R go back. Input is consumed while open (Esc doesn't reach the pause menu).
## `await panel.open(shop_id)` returns when the window closes.

signal closed

const LAYER := 15

var shop_id := "viridian"
var game: Object = null  ## null = Game autoload
var state := ""  ## "", "menu", "list", "qty"
var selling := false
var cursor := 0
var qty := 1
var items: Array = []

var _title: Label
var _money: Label
var _list: VBoxContainer
var _info: Label
var _root: PanelContainer


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_root.custom_minimum_size = Vector2(420, 360)
	_root.offset_left = -460
	_root.offset_right = -40
	_root.offset_top = -200
	_root.offset_bottom = 200
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.2, 0.94)
	sb.border_color = Color(0.3, 0.5, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 20)
	_money.modulate = Color(1, 0.9, 0.45)
	top.add_child(_money)
	_list = VBoxContainer.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_list)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(380, 60)
	_info.modulate = Color(0.85, 0.88, 0.95)
	v.add_child(_info)
	var help := Label.new()
	help.text = "W/S escolhe   A/D quantidade   E confirma   Esc volta"
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.55)
	v.add_child(help)
	visible = false


func _g() -> Object:
	return MartShop._game(game)


func is_open() -> bool:
	return state != ""


func open(id: String) -> void:
	shop_id = id
	state = "menu"
	cursor = 0
	visible = true
	_redraw()
	await closed


func close() -> void:
	state = ""
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if state == "" or not event.is_pressed() or event.is_echo():
		if state != "" and (event is InputEventKey or event is InputEventJoypadButton):
			get_viewport().set_input_as_handled()
		return
	var act := ""
	if event.is_action("move_forward") or event.is_action("ui_up"):
		act = "up"
	elif event.is_action("move_back") or event.is_action("ui_down"):
		act = "down"
	elif event.is_action("move_left") or event.is_action("ui_left"):
		act = "left"
	elif event.is_action("move_right") or event.is_action("ui_right"):
		act = "right"
	elif event.is_action("interact") or event.is_action("ui_accept") or event.is_action("jump"):
		act = "ok"
	elif event.is_action("pause") or event.is_action("run_away") or event.is_action("ui_cancel"):
		act = "back"
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	if act != "":
		press(act)


## One navigation step ("up", "down", "left", "right", "ok", "back"). Used by _input and tests.
func press(act: String) -> void:
	match state:
		"menu":
			match act:
				"up":
					cursor = posmod(cursor - 1, 3)
				"down":
					cursor = posmod(cursor + 1, 3)
				"back":
					close()
					return
				"ok":
					if cursor == 2:
						close()
						return
					_enter_list(cursor == 1)
		"list":
			var n := items.size() + 1  # last row = Voltar
			match act:
				"up":
					cursor = posmod(cursor - 1, n)
				"down":
					cursor = posmod(cursor + 1, n)
				"back":
					_back_to_menu()
				"ok":
					if cursor >= items.size():
						_back_to_menu()
					elif _max_for(items[cursor]) > 0:
						qty = 1
						state = "qty"
					else:
						_info.text = (
							"Dinheiro insuficiente." if not selling else "Você não tem esse item."
						)
						return
		"qty":
			var id: String = items[cursor]
			var mx := maxi(_max_for(id), 1)
			match act:
				"left":
					qty = clampi(qty - 1, 1, mx)
				"right":
					qty = clampi(qty + 1, 1, mx)
				"up":
					qty = clampi(qty + 10, 1, mx)
				"down":
					qty = clampi(qty - 10, 1, mx)
				"back":
					state = "list"
				"ok":
					var ok := (
						MartShop.sell(id, qty, game) if selling else MartShop.buy(id, qty, game)
					)
					var msg := ""
					if ok and selling:
						msg = (
							"Vendeu %d %s por P$%d."
							% [qty, MartShop.item_name(id), MartShop.sell_price(id) * qty]
						)
					elif ok:
						msg = (
							"Comprou %d %s por P$%d."
							% [qty, MartShop.item_name(id), MartShop.price(id) * qty]
						)
						if id == MartShop.BONUS_FOR and qty >= MartShop.BONUS_AT:
							msg += " Ganhou também uma Premier Ball!"
					else:
						msg = "Não deu certo."
					state = "list"
					if selling:
						items = MartShop.sellable(game)
						cursor = mini(cursor, items.size())
					_redraw()
					_info.text = msg
					return
	_redraw()


func _enter_list(sell: bool) -> void:
	selling = sell
	items = MartShop.sellable(game) if sell else MartShop.stock(shop_id)
	cursor = 0
	state = "list"


func _back_to_menu() -> void:
	state = "menu"
	cursor = 1 if selling else 0


func _max_for(id: String) -> int:
	return MartShop.max_sell(id, game) if selling else MartShop.max_buy(id, game)


func _redraw() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var g := _g()
	_money.text = "P$%d" % (int(g.money) if g else 0)
	_info.text = ""
	match state:
		"menu":
			_title.text = "POKé MART"
			for i in 3:
				_row(["Comprar", "Vender", "Sair"][i], "", i == cursor)
			_info.text = "Posso ajudar?"
		"list", "qty":
			_title.text = "VENDER" if selling else "COMPRAR"
			if items.is_empty():
				_row("(nada para vender)" if selling else "(sem estoque)", "", false)
			for i in items.size():
				var id: String = items[i]
				var unit := MartShop.sell_price(id) if selling else MartShop.price(id)
				var have := MartShop.count(id, game)
				_row("%s  x%d" % [MartShop.item_name(id), have], "P$%d" % unit, i == cursor)
			_row("Voltar", "", cursor >= items.size())
			if cursor < items.size():
				var id2: String = items[cursor]
				_info.text = String(Dex.item(id2).get("description", ""))
				if state == "qty":
					var unit2 := MartShop.sell_price(id2) if selling else MartShop.price(id2)
					_info.text = "Quantidade: ◀ %d ▶   Total: P$%d" % [qty, unit2 * qty]


func _row(text: String, right: String, sel: bool) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = ("▶ " if sel else "   ") + text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	if sel:
		l.modulate = Color(1, 0.9, 0.4)
	h.add_child(l)
	var r := Label.new()
	r.text = right
	r.add_theme_font_size_override("font_size", 18)
	h.add_child(r)
	_list.add_child(h)
