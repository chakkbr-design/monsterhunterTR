extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/world/test_companions.gd
## Companheiros fora da bola como o original: teclas 1-6 mandam e recolhem (vários fora ao mesmo
## tempo), a batalha escolhe líder e aliado pelo que está fora, amizade (carinho, comida, +1 a cada
## 10 s, -20 ao desmaiar), status correndo fora da bola, busca de fruta e o Piquenique.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var game: Node
var w: Node3D
var p: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://test_companions_save.json"
	_rules()
	_game_out()
	_arena_choice()
	await _world()
	print("[companions] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)


func _rules() -> void:
	check(Mon.mood(69) == "Wary" and Mon.mood(70) == "Content", "humor: Wary < 70 <= Content")
	check(Mon.mood(150) == "Happy" and Mon.mood(220) == "Devoted", "humor: Happy 150, Devoted 220")
	check(CompanionActions.pick("Content", 3.9, 1, "", false) == "", "parado < 4 s: nada")
	check(CompanionActions.pick("Content", 4.0, 1, "", false) == "COME", "Content parado: COME")
	check(CompanionActions.pick("Happy", 5.0, 1, "", false) == "ORBIT", "Happy sozinho: ORBIT")
	check(CompanionActions.pick("Happy", 5.0, 2, "", false) == "PLAY", "Happy com outro: PLAY")
	check(CompanionActions.pick("Devoted", 12.0, 2, "", false) == "NAP", "Devoted 12 s: NAP")
	check(CompanionActions.pick("Devoted", 12.0, 2, "", true) == "", "à noite: nada")
	check(CompanionActions.tired(59, 100, 100.0, 100.0), "cansado abaixo de 60% de HP")
	check(not CompanionActions.tired(60, 100, 60.0, 100.0), "60% não é cansado")
	check(CompanionActions.fetch_cooldown("Devoted") == 75.0, "busca Devoted a cada 75 s")
	check(CompanionActions.fetch_cooldown("Wary", true) == 720.0, "caverna: 3x mais devagar")
	check(CompanionActions.fetch_item(false, 0) == "oran_berry", "fora da caverna: Oran Berry")
	check(
		(
			CompanionActions.fetch_item(true, 8) == "big_mushroom"
			and CompanionActions.fetch_item(true, 3) == "tiny_mushroom"
		),
		"caverna: cogumelo (grande 1 em 8)"
	)
	var acts := CompanionActions.picnic_assign(
		[
			{"hp": 1.0, "pp": 1.0, "mood": "Happy"},
			{"hp": 1.0, "pp": 1.0, "mood": "Happy"},
			{"hp": 0.3, "pp": 1.0, "mood": "Happy"}
		],
		0.0
	)
	check(
		acts == ["CHASE", "CHASE", "NAP"], "piquenique: dois brincam, o cansado dorme (%s)" % [acts]
	)
	var hp: Array = load("res://world/picnic.gd").hp_step(10, 32, 0.0)
	check(
		hp[0] == 10 and is_equal_approx(float(hp[1]), 32 * 0.02 * 0.25 / 3.0),
		"piquenique: HP 2% a cada 3 s"
	)
	check(
		is_equal_approx(
			load("res://world/picnic.gd").pp_step(20.0, 95.0, 0.005),
			20.0 + 95.0 * 0.005 * 4.0 * 0.25
		),
		"piquenique: PP 4x o ritmo do mundo"
	)


func _game_out() -> void:
	game.new_game("ASH", "GARY")
	var a := Mon.create("charmander", 10)
	var b := Mon.create("rattata", 8)
	var c := Mon.create("pidgey", 6)
	for m in [a, b, c]:
		game.add_mon(m)
	check(game.out.is_empty(), "jogo novo: ninguém fora da bola")
	game.party_key(0)
	game.party_key(1)
	check(game.out_indices() == [0, 1], "teclas 1 e 2: dois fora ao mesmo tempo")
	game.party_key(0)
	check(game.out_indices() == [1], "tecla 1 de novo: recolhe")
	c.hp = 0
	check(game.party_key(2) == "Pidgey desmaiou!" and not game.is_out(2), "desmaiado não sai")
	c.hp = c.max_hp
	check(game.lead_index() == 1, "líder é o primeiro fora da bola")
	game.party_key(0)
	b.friend = 71
	check(game.pet(1).ok and b.friend == 77, "carinho: +6 (71 -> 77)")
	var again: Dictionary = game.pet(1)
	check(not again.ok and String(again.text).contains("carinho"), "carinho de novo: espera")
	check(not game.feed(1).ok, "comida divide a espera do carinho")
	check(game.feed(0).ok and a.friend == 78, "comida: +8")
	check(not game.pet(2).ok, "na bola: sem carinho")
	var f0: int = a.friend
	var f2: int = c.friend
	game.friend_tick(10.0)
	check(a.friend == f0 + 1 and c.friend == f2, "+1 a cada 10 s só para quem está fora")
	game.friend_tick(60.0)
	check(game.pet(1).ok, "a espera de 60 s acaba")
	check(game.deposit(0) and not game.out.has(a), "guardar no PC recolhe")


func _arena(party: Array, enemies: Array, opts: Dictionary) -> Node:
	var ar: Node = load(ARENA).instantiate()
	ar.manual = true
	root.add_child(ar)
	var got := {}
	ar.finished.connect(func(r: Dictionary) -> void: got.merge(r), CONNECT_ONE_SHOT)
	ar.set_meta("got", got)
	opts["speed"] = 1.0
	ar.start(party, enemies, opts)
	return ar


func _step(ar: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		if ar.state == "done":
			return
		ar.step(DT)


func _arena_choice() -> void:
	var party := [Mon.create("charmander", 12), Mon.create("rattata", 10), Mon.create("pidgey", 8)]
	var ar := _arena(party, [Mon.create("pidgey", 3)], {"seed": 1, "out": []})
	check(ar.player.mon == party[0] and ar.ally == null, "selvagem, ninguém fora: sem aliado")
	ar.queue_free()
	ar = _arena(party, [Mon.create("pidgey", 3)], {"seed": 1, "out": [0]})
	check(ar.ally == null, "só o líder fora: sem aliado")
	ar.queue_free()
	ar = _arena(party, [Mon.create("pidgey", 3)], {"seed": 1, "out": [2]})
	check(ar.player.mon == party[2] and ar.ally == null, "o que está fora lidera")
	ar.queue_free()
	ar = _arena(party, [Mon.create("pidgey", 3)], {"seed": 1, "out": [0, 1]})
	check(
		ar.player.mon == party[0] and is_instance_valid(ar.ally) and ar.ally.mon == party[1],
		"dois fora: Charmander lidera e Rattata é o aliado"
	)
	# O aliado desmaia: -20 de amizade e volta para a bola; o líder vence e fica fora.
	var f1: int = party[1].friend
	_step(ar, 1.5)
	ar.ally.take_damage(ar.ally.hp, Vector3.ZERO, 0.0)
	check(
		party[1].friend == f1 - 20, "desmaiar tira 20 de amizade (%d -> %d)" % [f1, party[1].friend]
	)
	_step(ar, 1.5)
	ar.enemy.take_damage(ar.enemy.hp, Vector3.ZERO, 0.0)
	_step(ar, 30.0)
	var got: Dictionary = ar.get_meta("got")
	check(got.get("outcome") == "win", "vence a selvagem")
	check(got.get("out_mons", []) == [party[0]], "fica fora quem lutou e não desmaiou")
	ar.queue_free()
	for m in party:
		m.heal_full()
	ar = _arena(
		party,
		[Mon.create("pidgey", 3)],
		{"seed": 1, "out": [0, 1], "kind": "trainer", "trainer_id": ""}
	)
	check(ar.ally == null, "treinador: 1x1")
	_step(ar, 3.0)
	ar.enemy.take_damage(ar.enemy.hp, Vector3.ZERO, 0.0)
	_step(ar, 30.0)
	got = ar.get_meta("got")
	check(got.get("out_mons", []) == [party[0]], "treinador: os outros fora voltam para a bola")
	ar.queue_free()
	for m in party:
		m.heal_full()
	ar = _arena(party, [Mon.create("pidgey", 3)], {"seed": 1, "out": []})
	_step(ar, 3.0)
	ar.enemy.take_damage(ar.enemy.hp, Vector3.ZERO, 0.0)
	_step(ar, 30.0)
	got = ar.get_meta("got")
	check(got.get("out_mons", []) == [party[0]], "quem saiu da bola na batalha fica fora depois")
	ar.queue_free()


func _companions() -> Array:
	return get_nodes_in_group("ow_companion")


func _world() -> void:
	game.new_game("ASH", "GARY")
	game.flags["got_starter"] = true
	var a := Mon.create("charmander", 10)
	var b := Mon.create("rattata", 8)
	var c := Mon.create("pidgey", 6)
	for m in [a, b, c]:
		game.add_mon(m)
	game.spawn_request = {"zone": "viridian_city", "spawn": "vc_center_door"}
	w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.0
	root.add_child(w)
	await frames(10)
	p = get_first_node_in_group("ow_player")
	check(p != null, "mundo e jogador")
	check(_companions().is_empty(), "ninguém fora: nenhum companheiro no mundo")
	Input.action_press("party_1")
	await frames(2)
	Input.action_release("party_1")
	Input.action_press("party_2")
	await frames(2)
	Input.action_release("party_2")
	await frames(5)
	check(game.out_indices() == [0, 1], "teclas 1 e 2 no mundo: dois fora")
	check(_companions().size() == 2, "dois companheiros no mundo (%d)" % _companions().size())
	# Status fora da bola: o veneno tira HP e some; quem está na bola continua envenenado.
	a.status = "poison"
	a.hp = mini(31, a.max_hp)
	c.status = "poison"
	var hp0 := a.hp
	await frames(600)
	var tick := maxi(1, int(a.max_hp / 12.0))
	check(
		a.status == "" and a.hp == hp0 - 6 * tick,
		"veneno fora da bola: %d -> %d e some" % [hp0, a.hp]
	)
	check(c.status == "poison", "na bola o veneno fica")
	# Busca de fruta: logo no início (cooldown -inf), um deles traz uma Oran Berry.
	var drops := []
	for i in 1500:
		await physics_frame
		drops = w.find_children("Fetch_*", "", true, false)
		if not drops.is_empty():
			break
	check(not drops.is_empty() and drops[0].item_id == "oran_berry", "trouxe uma Oran Berry")
	# Carinho pelo nó do mundo.
	var comp = w.get_node("Follower").companion_of(b)
	b.friend = 100
	game._friend_cd.clear()
	comp.interact(p)
	check(b.friend == 106, "E no companheiro: carinho")
	# Piquenique: todos saem, recupera HP e PP, +10 de amizade depois de 20 s.
	var menu = root.get_node_or_null("PauseMenu")
	if menu:
		check(menu.can_picnic(), "menu: piquenique disponível com alguém fora")
	var pic: Node3D = load("res://world/picnic.gd").new()
	pic.manual = true
	p.get_parent().add_child(pic)
	pic.begin(p)
	await frames(10)
	check(game.out_indices() == [0, 1, 2], "piquenique: todos saem da bola")
	b.hp = 10
	b.pp = 20.0
	var fb: int = b.friend
	await frames(720)
	check(b.hp > 10 and b.pp > 40.0, "piquenique 12 s: HP %d PP %.1f" % [b.hp, b.pp])
	await frames(600)
	pic.end()
	check(b.friend == fb + 10, "piquenique 20 s: +10 de amizade (%d -> %d)" % [fb, b.friend])
	check(not p.locked, "fim do piquenique solta o jogador")
	w.queue_free()
	await frames(2)
