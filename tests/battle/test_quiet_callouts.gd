extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_quiet_callouts.gd
## Na tela da luta, só números de dano, gatilhos especiais e o balão do golpe (BattleHUD.quiet);
## opts.loud_callouts volta a mostrar tudo.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const OK_KINDS := ["damage", "special", "move"]

var _fails := 0
var _count := 0
var _ran := false


## No _process: em _initialize a arena ainda não está na árvore e o HUD descarta os popups.
func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_loud()
	_filter()
	_fight()
	print("quiet_callouts: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(extra := {}) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var opts := {
		"kind": "trainer",
		"battle_size": 2,
		"autoplay": true,
		"seed": 5,
		"speed": 1.0,
		"no_rewards": true,
		"arena": Cfg.SMALL_ARENA
	}
	opts.merge(extra, true)
	a.start(
		[Mon.create("squirtle", 30), Mon.create("pikachu", 30)],
		[Mon.create("bulbasaur", 30), Mon.create("charmander", 30)],
		opts
	)
	return a


## opts.loud_callouts: HUD mostra todos os textos.
func _loud() -> void:
	var b := _arena({"loud_callouts": true})
	check(not b.hud.quiet, "opts.loud_callouts desliga o filtro")
	b.free()


## O filtro do HUD sozinho.
func _filter() -> void:
	var a := _arena()
	var hud: BattleHUD = a.hud
	check(a.quiet_callouts() and hud.quiet, "HUD quieto")
	var p: BattleFighter = a.player
	hud.shown.clear()
	p.popup("23", Color.WHITE, 1.0, 0.35, "damage")
	p.popup("CRITICAL!", Color.WHITE, 1.0, 0.6, "crit")
	p.popup("SUPER EFFECTIVE!", Color.WHITE, 1.0, 0.85, "super")
	p.popup("Missed!", Color.WHITE)
	p.popup("+2 ATK", Color.WHITE, 1.0, 0.15, "stat_up")
	p.popup("BURNED!", Color.WHITE, 1.0, 0.15, "status")
	p.popup("-12 Fell!", Color.WHITE, 1.1, 0.7)
	p.popup("Second wind!", Color.WHITE, 1.0, 0.8, "special")
	hud.warn("CLASH!", Color.WHITE)
	hud.combo("COMBO!", Color.WHITE)
	hud.ability_banner(p, "Intimidate")
	hud.cut_in("BOOM!", Color.WHITE, 0.4)
	hud.callout(p, "Tackle", Color.WHITE)
	var texts: Array = hud.shown.map(func(e): return String(e.text))
	check(
		texts == ["23", "12", "Second wind!", "Tackle"], "só dano, especial e golpe (%s)" % [texts]
	)
	check(hud.warn_text() == "" and hud.ability_text(p.side) == "", "sem aviso nem faixa")
	check(hud.cut_in_text() == "", "sem faixa de impacto comum")
	hud.cut_in("LAST HOPE!", Color.WHITE, 0.4, true)
	check(hud.cut_in_text() == "LAST HOPE!", "faixa de gatilho especial passa")
	check("Missed!" in a.log_lines, "o texto continua no registro da arena")
	a.free()


## Luta curta de verdade no 2x2: só textos permitidos na tela.
func _fight() -> void:
	var a := _arena({"seed": 21})
	var t := 0.0
	while t < 45.0 and a.state in ["intro", "fight"]:
		a.step(DT)
		t += DT
	var bad: Array = []
	var dmg := 0
	var moves := 0
	for e in a.hud.shown:
		if not String(e.kind) in OK_KINDS:
			bad.append(e)
		elif e.kind == "damage":
			dmg += 1
			if not String(e.text).is_valid_int():
				bad.append(e)
		elif e.kind == "move":
			moves += 1
	check(bad.is_empty(), "só textos permitidos (%s)" % [bad.slice(0, 5)])
	check(dmg > 0, "números de dano aparecem (%d)" % dmg)
	check(moves > 0, "balão de golpe aparece (%d)" % moves)
	a.free()
