extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_hud_viva.gd
## HUD da Batalha Viva: só estado (headless não renderiza).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	var a: Node = _arena(
		[Mon.create("charmander", 10), Mon.create("squirtle", 10)],
		[Mon.create("pidgey", 10)],
		{"seed": 7, "loud_callouts": true}  # todos os textos (o filtro quieto tem teste próprio)
	)
	for i in 80:
		a.step(DT)
	var hud: BattleHUD = a.hud
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var al: BattleFighter = a.ally if a.ally else p
	e.stages["atk"] = 2
	e.stages["spe"] = -1
	check(BattleHUD.VivaTags.stage_tags(e).size() == 2, "tags de estágio")
	check(BattleHUD.VivaTags.stage_tags(e)[0].text == "+2 ATK", "texto +2 ATK")
	var extra := {
		"foe2": p,
		"commands": {"player": "FREE", "ally": "OFFENSE"},
		"obey": {"player": true, "ally": false},
		"sync": [1.0, 0.5],
		"marks": {e.get_instance_id(): [{"id": "x", "name": "Marca", "color": Color.RED, "t": 3.0}]}
	}
	hud.refresh(p, e, DT, al, extra)
	check(hud.card_text("foe2") == p.mon.display_name, "cartão do 2º inimigo")
	hud.refresh(p, e, DT, al, {})
	check(hud.card_text("foe2") == "", "sem foe2 some")
	hud.refresh(p, e, DT, al, {"foe2": null})
	check(hud.card_text("foe2") == "", "foe2 null")
	for i in 60:
		hud.refresh(p, e, DT, al, extra)
	check(hud.sync_shown(0) > 0.99 and hud.sync_shown(1) > 0.49, "sintonia")
	hud.callout(p, "Lança-chamas", Color.ORANGE)
	check(hud.callout_text(p.side) == "Lança-chamas", "callout")
	hud.callout(p, "Arranhão", Color.ORANGE)
	check(hud.callout_text(p.side) == "Arranhão", "callout substitui")
	check(hud.callout_text(1 - p.side) == "", "outro lado vazio")
	hud.cut_in("NOCAUTE!", Color.RED, 0.4)
	check(hud.cut_in_text() == "NOCAUTE!", "cut_in")
	hud.combo("COMBO!", Color.YELLOW)
	hud.ability_banner(e, "Intimidação")
	check(hud.ability_text(e.side).ends_with("Intimidação"), "ability")
	for i in 20:
		hud.refresh(p, e, DT, al, extra)
	check(hud.cut_in_text() == "NOCAUTE!", "cut_in ainda 0.33s")
	for i in 80:
		hud.refresh(p, e, DT, al, extra)
	check(hud.cut_in_text() == "", "cut_in some")
	check(hud.callout_text(p.side) == "", "callout some em 1 s")
	check(hud.ability_text(e.side) == "", "ability some")
	a.free()
	print("hud_viva: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


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
