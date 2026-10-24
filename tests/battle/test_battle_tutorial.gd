extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_battle_tutorial.gd
## Tutorial da batalha (porte do ui/battle_tutorial.gd): lição do Prof. Carvalho na 1ª luta com o
## rival e cartões de dica (start, cooldown, dodge, stat, hp), flags tut_* e "dicas de batalha".
## Arena com step(dt) manual; o _process do tutorial é chamado à mão.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const INTRO := 2.5  ## abertura do treinador (desafio + bola)

var _fails := 0
var _count := 0


func _initialize() -> void:
	_all()


## Espera um quadro: o tutorial (CanvasLayer) só liga os sinais no _ready, dentro da árvore.
func _all() -> void:
	await process_frame
	_lesson()
	_cards()
	_tips_off()
	_hold_foe()
	_story_spot()
	paused = false
	print("battle_tutorial: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _game(flags := {}) -> Node:
	var g: Node = load("res://core/game.gd").new()
	g.flags = flags
	root.add_child(g)
	return g


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	opts["speed"] = 1.0
	opts["seed"] = 7
	opts["tutorial"] = true
	opts["auto_battle"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _tick(t: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		if is_instance_valid(t):
			t._process(DT)


func _rival(g: Node, tips := true) -> Node:
	return _arena(
		[Mon.create("charmander", 5)],
		[Mon.create("squirtle", 5)],
		{
			"kind": "trainer",
			"trainer_id": "rival_blue_route22",
			"trainer_class": "rival",
			"scripted": true,
			"game": g,
			"battle_tips": tips
		}
	)


## Lição: intro, your_hp, foe_hp (fala + holofote), moves (só o Growl), stat (3,5 s), attack.
func _lesson() -> void:
	var g := _game()
	var a := _rival(g)
	var t: Node = a.tutorial
	check(t != null, "arena cria o tutorial com opts.tutorial")
	check(t.lesson_step() == "", "nada antes do fim da abertura")
	_run(a, INTRO + 0.1)
	check(a.state == "fight", "luta começou")
	check(t.lesson_step() == "intro", "lição começa no 'intro' (%s)" % t.lesson_step())
	check(g.flags.get("tut_battle_lesson", false), "flag tut_battle_lesson")
	check(g.flags.get("tut_start", false), "flag tut_start (a lição substitui o cartão)")
	check(a.tut_locked and a.tut_hold_foe and a.tut_move == -1, "intro: tudo travado")
	check(t._status_slot == 1 and t._attack_slot == 0, "Growl e Scratch escolhidos")
	check(t.waiting_for_dismiss(), "intro espera o OK")
	check(not paused, "lição não pausa a árvore")
	check(
		t._bubble.visible and t._bubble_body.text.begins_with("Aqui as batalhas"), "fala do intro"
	)
	var pos: Vector3 = a.enemy.position
	_run(a, 1.5)
	check(a.enemy.position.distance_to(pos) < 0.01, "adversário parado na lição")
	t._lesson_next()
	check(t.lesson_step() == "your_hp", "your_hp")
	check(t._spot.hole().size.x > 0.0, "holofote no seu cartão")
	t._lesson_next()
	check(t.lesson_step() == "foe_hp", "foe_hp")
	t._lesson_next()
	check(t.lesson_step() == "moves", "moves")
	check(a.tut_move == 1 and not a.tut_walk, "só o Growl liberado, sem andar")
	check(t._bubble_body.text.contains("Growl"), "fala cita o Growl: " + t._bubble_body.text)
	check(t._arrow.visible, "seta em cima do golpe")
	check(not t.waiting_for_dismiss(), "moves é ao vivo")
	# Golpe errado não avança; o Growl avança.
	a.moves.use(a.player, "scratch")
	check(t.lesson_step() == "moves", "Scratch não avança a lição")
	_run(a, 1.5)
	a.moves.use(a.player, "growl")
	check(t.lesson_step() == "stat", "Growl avança para 'stat' (%s)" % t.lesson_step())
	check(t._bubble_body.text.contains("Ataque"), "fala do ▼ cita o Ataque")
	_run(a, 0.5)
	_tick(t, 3.6)
	check(t.lesson_step() == "attack", "stat espera 3,5 s e vai para 'attack'")
	check(a.tut_move == 0 and a.tut_walk and a.tut_hold_foe, "attack: Scratch e andar liberados")
	check(t._bubble_body.text.contains("aperte 1"), "fala do attack: " + t._bubble_body.text)
	# Encosta e acerta.
	a.player.position = a.enemy.position + (a.player.position - a.enemy.position).normalized() * 0.9
	a.player.facing = (a.enemy.position - a.player.position).normalized()
	a.player.gcd_t = 0.0
	a.player.move_cd.clear()
	a.moves.use(a.player, "scratch")
	_run(a, 1.0)
	check(t.lesson_step() == "", "acertar encerra a lição")
	check(t._lesson_done, "lição feita")
	check(not a.tut_locked and not a.tut_hold_foe, "travas soltas depois da lição")
	# Depois da lição nenhum cartão aparece.
	t._trigger("dodge")
	_tick(t, 0.1)
	check(not t.is_showing() and not g.flags.has("tut_dodge"), "sem cartões depois da lição")
	a.free()
	g.free()


## Sem lição (já dada): cartões disparados pelos eventos, cada um uma vez, com a árvore pausada.
func _cards() -> void:
	var g := _game({"tut_battle_lesson": true})
	var a := _rival(g)
	var t: Node = a.tutorial
	_run(a, INTRO + 0.1)
	check(t.lesson_step() == "", "sem lição quando tut_battle_lesson")
	check(not a.tut_locked, "sem trava")
	a.enemy.controller = "none"
	_tick(t, 1.0)
	check(not t.is_showing(), "start espera 1,3 s")
	_tick(t, 0.4)
	check(t.current_card() == "start", "cartão start")
	check(paused, "cartão pausa a árvore")
	check(g.flags.get("tut_start", false), "flag tut_start")
	check(t._title.text == "Batalhas em tempo real", "título do start")
	t._close()
	check(not paused and not t.is_showing(), "fechar despausa")
	a.player.gcd_t = 0.0
	a.moves.use(a.player, "scratch")
	_tick(t, 0.9)
	check(t.current_card() == "cooldown", "cartão cooldown depois do 1º golpe")
	t._close()
	# Golpe de status do adversário: cartão stat com o nome do golpe.
	a.enemy.gcd_t = 0.0
	a.moves.use(a.enemy, "tail_whip")
	check(t.current_card() == "stat", "cartão stat (golpe de status do adversário)")
	check(t._body.text.begins_with("Squirtle usou Tail Whip!"), "texto do stat: " + t._body.text)
	t._close()
	# Golpe com poder do adversário: dodge.
	_run(a, 1.5)
	a.moves.use(a.enemy, "tackle")
	check(t.current_card() == "dodge", "cartão dodge")
	t._close()
	# HP baixo (o hp com Poção na bolsa ensina a usar).
	a.player.hp = int(a.player.max_hp * 0.4)
	_tick(t, DT)
	check(t.current_card() == "hp", "cartão hp")
	check(t._body.text.contains("Aperte E"), "hp com Poção: " + t._body.text)
	t._close()
	check(not paused, "fila vazia despausa")
	for id in ["start", "cooldown", "dodge", "stat", "hp"]:
		check(g.flags.get("tut_" + id, false), "flag tut_" + id)
	# Visto não volta.
	a.player.gcd_t = 0.0
	a.player.move_cd.clear()
	a.moves.use(a.player, "growl")
	_tick(t, 1.0)
	check(not t.is_showing(), "cartão visto não repete")
	# Fim da luta: o tutorial some e despausa.
	a._finish()
	check(t.is_queued_for_deletion(), "tutorial sai no fim da luta")
	a.free()
	g.free()


func _tips_off() -> void:
	var g := _game()
	var a := _rival(g, false)
	var t: Node = a.tutorial
	_run(a, INTRO + 0.1)
	check(t.lesson_step() == "", "dicas desligadas: sem lição")
	_tick(t, 2.0)
	check(not t.is_showing() and g.flags.is_empty(), "dicas desligadas: sem cartões nem flags")
	a.free()
	g.free()


func _hold_foe() -> void:
	var g := _game()
	var a := _arena(
		[Mon.create("charmander", 10)],
		[Mon.create("pidgey", 10)],
		{"kind": "wild", "game": g, "battle_tips": true, "battle_size": 1}
	)
	_run(a, 1.3)
	check(a.tutorial.lesson_step() == "", "selvagem: sem lição")
	a.tut_hold_foe = true
	var pos: Vector3 = a.enemy.position
	var hp: int = a.player.hp
	_run(a, 3.0)
	# No chão: o Voador pode terminar de descer para a vez dele (a altura não é a IA andando).
	var flat := Vector3(1, 0, 1)
	check(
		(a.enemy.position * flat).distance_to(pos * flat) < 0.01 and a.player.hp == hp,
		"tut_hold_foe segura a IA"
	)
	a.tut_hold_foe = false
	_run(a, 4.0)
	check(a.enemy.position.distance_to(pos) > 0.05, "IA volta a agir")
	a.free()
	g.free()


func _story_spot() -> void:
	var s = load("res://story/story.gd")
	var at: Vector3 = s.oak_lesson_spot(Vector3(0, 0, 0.6))
	check(
		at.distance_to(Vector3(5.7, 0, -3.6)) < 0.001, "lugar do Oak na borda da quadra (%s)" % at
	)
