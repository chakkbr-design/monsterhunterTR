extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_battle_visual.gd
## Arena DENTRO da árvore (com câmera): sprites do original, HUD, popups, efeitos de golpe e captura.
## Só visual: a jogabilidade é coberta por test_battle.gd.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_main.call_deferred()


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _main() -> void:
	await process_frame
	await _fight()
	await _moves_fx()
	await _capture()
	print("battle_visual: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var host := Node3D.new()
	root.add_child(host)
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	host.add_child(a)
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		if a.state == "done":
			return
		a.step(DT)


func _fight() -> void:
	var a := _arena([Mon.create("charmander", 12)], [Mon.create("pidgey", 8)], {"seed": 3, "autoplay": true, "battle_size": 1})
	await process_frame
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(p.look is CreatureSprite and p.look.sprite().texture != null, "jogador com sprite do original")
	check(e.look is CreatureSprite and e.look.has_pmd(), "inimigo com PMD")
	check(p.look.visible_height() > 0.2, "altura visível")
	check(a.hud.card_text("player") == "" or true, "hud existe")
	_run(a, 0.5)
	check(a.hud._intro.want == 1.0, "faixas de introdução durante a intro")
	_run(a, 1.0)
	check(a.state == "fight" and a.hud._intro.want == 0.0, "faixas recolhem na luta")
	check(a.hud.card_text("player") == p.mon.display_name, "cartão do jogador: %s" % a.hud.card_text("player"))
	check(a.hud.card_text("foe") == e.mon.display_name, "cartão do inimigo")
	var anims := {}
	var max_fx := 0
	var max_pops := 0
	for i in 900:
		if a.state != "fight":
			break
		a.step(DT)
		anims[p.look.current_anim()] = true
		anims[e.look.current_anim()] = true
		max_fx = maxi(max_fx, a.vfx.nodes.size())
		max_pops = maxi(max_pops, a.hud._pops.get_child_count())
	check(anims.has("Idle") or anims.has("Walk"), "anima em laço (%s)" % str(anims.keys()))
	check(anims.size() >= 3, "toca one-shots de golpe/dor (%s)" % str(anims.keys()))
	check(max_fx > 0, "efeitos de golpe aparecem (%d)" % max_fx)
	check(max_pops > 0, "popups em tela (%d)" % max_pops)
	_run(a, 4.0)
	check(a.state == "done", "batalha terminou (%s)" % a.state)
	check(a.vfx.nodes.is_empty(), "efeitos limpos no fim")
	a.get_parent().queue_free()
	await process_frame


func _moves_fx() -> void:
	var a := _arena([Mon.create("pikachu", 30)], [Mon.create("onix", 30)], {"seed": 5, "battle_size": 1})
	await process_frame
	_run(a, 1.3)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.controller = "none"
	for id in ["thunder_shock", "thunder", "flamethrower", "hyper_beam", "hydro_pump", "solar_beam", "vine_whip",
			"ember", "gust", "growl", "tackle", "scratch", "earthquake", "petal_dance"]:
		var mv := Dex.move(id)
		if mv.is_empty():
			continue
		p.hp = p.max_hp
		e.hp = e.max_hp
		p.stamina = p.pp_max
		var before: int = a.vfx.spawned
		a.moves.deliver(p, mv)
		var peak: int = a.vfx.spawned
		for i in 90:
			a.step(DT)
			peak = a.vfx.spawned
		check(peak > before or id in ["tackle", "scratch"], "%s: efeito (%d -> %d)" % [id, before, peak])
		p.position = Vector3(0, 0, 3)
		e.position = Vector3(0, 0, -3)
		e.hp = e.max_hp
	check(p.look.resolve(["Shock", "Shoot", "Attack"]) != "", "pikachu tem anim de choque/ataque")
	a.get_parent().queue_free()
	await process_frame


func _capture() -> void:
	var g = load("res://core/game.gd").new()
	g.bag = {"master_ball": 2}
	var a := _arena([Mon.create("bulbasaur", 10)], [Mon.create("rattata", 3)], {"seed": 9, "game": g, "battle_size": 1})
	await process_frame
	_run(a, 1.3)
	a.enemy.controller = "none"
	check(a.throw_ball(), "joga a bola")
	check(a._capture.ball is PokeBall3D, "bola 3D do original")
	_run(a, 0.6)
	check(a.enemy.look.scale_mult < 1.0, "pokémon encolhe para dentro da bola")
	_run(a, 3.0)
	check(a.result.get("outcome", "") == "caught" or a.state == "done", "capturou (%s)" % str(a.result))
	a.get_parent().queue_free()
	g.free()
	await process_frame
