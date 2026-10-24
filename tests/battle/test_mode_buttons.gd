extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_mode_buttons.gd
## Botões de modo (OFENSIVO/DEFENSIVO/SUPORTE/LIVRE) no HUD: visibilidade, destaque, sinal e posição.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0
var _got: Array = []


func _initialize() -> void:
	# 1x1 selvagem: só os botões do player.
	var a: Node = _arena([Mon.create("charmander", 10)], [Mon.create("pidgey", 10)], {"seed": 7})
	for i in 30:
		a.step(DT)
	var hud: BattleHUD = a.hud
	check(hud.mode_buttons_visible("player"), "1x1: botões do player")
	check(not hud.mode_buttons_visible("ally"), "1x1: sem botões do ally")
	_modes(a)
	a.free()
	# 2x1 selvagem com aliado.
	a = _arena(
		[Mon.create("charmander", 10), Mon.create("squirtle", 10)],
		[Mon.create("pidgey", 10)],
		{"seed": 7, "battle_size": 2}
	)
	for i in 30:
		a.step(DT)
	check(
		a.hud.mode_buttons_visible("player") and a.hud.mode_buttons_visible("ally"), "2x1: os dois"
	)
	_modes(a)
	_layout(a.hud)
	a.free()
	# 2x2 de treinador.
	a = _arena(
		[Mon.create("charmander", 10), Mon.create("squirtle", 10)],
		[Mon.create("pidgey", 10), Mon.create("rattata", 10)],
		{"seed": 7, "kind": "trainer", "battle_size": 2}
	)
	for i in 30:
		a.step(DT)
	check(
		a.hud.mode_buttons_visible("player") and a.hud.mode_buttons_visible("ally"), "2x2: os dois"
	)
	_modes(a)
	_layout(a.hud)
	a.free()
	print("mode_buttons: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func _modes(a: Node) -> void:
	var hud: BattleHUD = a.hud
	for m in 4:
		a.player_mode = m
		a.step(DT)
		check(
			hud.highlighted_mode("player") == a.get_script().ALLY_MODE_NAMES[m],
			"destaque player %d" % m
		)
		if hud.mode_buttons_visible("ally"):
			a.ally_mode = (m + 1) % 4
			a.step(DT)
			check(
				hud.highlighted_mode("ally") == a.get_script().ALLY_MODE_NAMES[(m + 1) % 4],
				"destaque ally %d" % m
			)
	_got.clear()
	hud.mode_clicked.connect(func(s, m): _got.append([s, m]))
	hud.press_mode("player", 2)
	hud.press_mode("ally", 3)
	check(_got == [["player", 2], ["ally", 3]], "press_mode emite o sinal")
	# A arena ouve o clique como as teclas F/G (sem teclado o comando vale na hora).
	check(a.player_mode == 2, "clique muda o modo do controlado na arena (%d)" % a.player_mode)
	a.step(DT)
	check(
		hud.highlighted_mode("player") == a.get_script().ALLY_MODE_NAMES[2],
		"botão reflete o clique"
	)
	var b = hud._mode_btns["player"][1]
	check(
		b.mouse_filter == Control.MOUSE_FILTER_STOP and b.focus_mode == Control.FOCUS_NONE,
		"STOP e sem foco"
	)
	check(hud._root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "resto do HUD ignora")


func _layout(hud: BattleHUD) -> void:
	var center := Vector2(576, 324)
	for slot in ["player", "ally"]:
		for m in 4:
			var r := hud.mode_button_rect(slot, m)
			check(r.size.x > 0 and r.size.y > 0, "retângulo %s %d" % [slot, m])
			check(not r.has_point(center), "fora do centro %s %d" % [slot, m])
			for o in ["player", "ally", "foe", "foe2"]:
				check(
					not r.intersects(hud.card_rect(o)), "%s %d não cobre cartão %s" % [slot, m, o]
				)
			for n in range(m + 1, 4):
				check(not r.intersects(hud.mode_button_rect(slot, n)), "pílulas não se sobrepõem")
			for o in ["player", "ally"]:
				if o != slot:
					check(not r.intersects(hud.mode_button_rect(o, m)), "filas não se sobrepõem")


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	opts["speed"] = 1.0
	opts["auto_battle"] = false
	a.start(party, enemies, opts)
	return a
