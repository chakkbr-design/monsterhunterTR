extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_gen9_ai.gd
## IA de status com bom senso (battle/battle_ai.gd): golpe de parceiro só com parceiro, buff até +2,
## debuff até -2, campo já ativo, status em alvo sem condição e não imune, Focus Energy uma vez, cura
## com HP baixo, trava de 4-6 s depois de um status (o urgente passa) e Desespero sem PP.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_partner_moves()
	_stat_caps()
	_field_moves()
	_status_targets()
	_once_and_heal()
	_lock()
	_pick_weights()
	_struggle_deadlock()
	print("gen9_ai: %d checks, %d falhas" % [_count, _fails])
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
	opts["field_objects"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada com o jogador pronto para a IA decidir (sem trava, estágios zerados, HP cheio).
func _still(me := "charmander", foe := "rattata", moves: Array = []) -> Node:
	var a := _arena([Mon.create(me, 30)], [Mon.create(foe, 30)], {"seed": 21})
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.clear_status()
		f.confusion_t = 0.0
		f.evasion_t = 0.0
		f.crit_stage = 0
		for k in f.stages:
			f.stages[k] = 0
		f.move_cd.clear()
		f.gcd_t = 0.0
		f.prepare_t = 0.0
	if not moves.is_empty():
		a.player.moves = moves.duplicate()
	a.player.ai.status_lock_t = 0.0
	a.player.ai.think_scale = 0.5
	return a


func _partner_moves() -> void:
	var a := _still("charmander", "rattata", ["ember", "helping_hand", "follow_me", "after_you"])
	var ai: BattleAI = a.player.ai
	for id in ["helping_hand", "follow_me", "rage_powder", "after_you", "quick_guard"]:
		check(not ai.status_ok(id), "1x1: %s fica de fora sem parceiro" % id)
	a.free()
	var d := _arena(
		[Mon.create("charmander", 30), Mon.create("squirtle", 30)],
		[Mon.create("rattata", 30), Mon.create("pidgey", 30)],
		{"kind": "trainer", "battle_size": 2, "seed": 5, "no_rewards": true}
	)
	_run(d, 3.0)
	if d.doubles and is_instance_valid(d.ally):
		var ai2: BattleAI = d.player.ai
		d.player.hp = d.player.max_hp
		ai2.status_lock_t = 0.0
		check(ai2.status_ok("helping_hand"), "2x2: Helping Hand com parceiro vivo")
	else:
		check(false, "2x2 montado")
	d.free()


func _stat_caps() -> void:
	var a := _still("charmander", "rattata", ["ember", "agility", "swords_dance", "shell_smash"])
	var p: BattleFighter = a.player
	var ai: BattleAI = p.ai
	check(ai.status_ok("agility"), "Agility com Speed 0")
	p.stages.spe = 2
	check(not ai.status_ok("agility"), "Agility não repete com Speed +2")
	p.stages.spe = 6
	check(not ai.status_ok("agility"), "nunca no +6")
	p.stages.spe = 0
	check(ai.status_ok("swords_dance"), "Swords Dance no 0")
	check(
		near(ai.status_weight("swords_dance"), BattleAI.STATUS_W_SETUP),
		"Swords Dance no 0 tem peso de preparo"
	)
	p.stages.atk = 2
	check(not ai.status_ok("swords_dance"), "Swords Dance não repete no +2")
	check(not ai.status_ok("shell_smash"), "Shell Smash com Ataque +2 fica de fora")
	p.stages.atk = 0
	check(ai.status_ok("shell_smash"), "Shell Smash no 0")
	a.free()
	var b := _still("charmander", "rattata", ["ember", "scary_face", "growl", "string_shot"])
	var e: BattleFighter = b.enemy
	var ai2: BattleAI = b.player.ai
	check(ai2.status_ok("scary_face"), "Scary Face na Speed 0 do alvo")
	e.stages.spe = -2
	check(not ai2.status_ok("scary_face"), "Scary Face não repete no -2")
	check(not ai2.status_ok("string_shot"), "String Shot também não")
	e.stages.atk = -1
	check(not ai2.status_ok("growl"), "debuff de novo só sem golpe de dano à mão")
	b.free()


func _field_moves() -> void:
	var a := _still("pidgey", "rattata", ["gust", "tailwind", "safeguard", "light_screen"])
	var p: BattleFighter = a.player
	var ai: BattleAI = p.ai
	check(ai.status_ok("tailwind"), "Tailwind sem vento")
	a.moves.use(p, "tailwind")
	_run(a, 0.4)
	ai.status_lock_t = 0.0
	check(not ai.status_ok("tailwind"), "Tailwind não repete com o vento ativo")
	p.move_cd.clear()
	p.gcd_t = 0.0
	a.moves.use(p, "safeguard")
	_run(a, 0.4)
	ai.status_lock_t = 0.0
	check(not ai.status_ok("safeguard"), "Safeguard não repete ativo")
	check(ai.status_ok("light_screen"), "Light Screen livre")
	a.free()


func _status_targets() -> void:
	var a := _still("charmander", "rattata", ["ember", "toxic", "will_o_wisp", "sleep_powder"])
	var e: BattleFighter = a.enemy
	var ai: BattleAI = a.player.ai
	check(ai.status_ok("toxic"), "Toxic em alvo limpo")
	e.apply_status("burn")
	check(not ai.status_ok("toxic"), "Toxic não vai em alvo já queimado")
	e.clear_status()
	e.types = ["fire"]
	check(not ai.status_ok("will_o_wisp"), "Will-O-Wisp não vai em Fogo")
	e.types = ["poison"]
	check(not ai.status_ok("toxic"), "Toxic não vai em Veneno")
	e.types = ["grass"]
	check(not ai.status_ok("sleep_powder"), "pó não vai em Planta")
	e.types = ["normal"]
	a.moves.effects.sides[e.side]["safeguard"] = a.moves.effects.now + 5.0
	check(not ai.status_ok("toxic"), "status não vai em quem tem Safeguard")
	a.free()


func _once_and_heal() -> void:
	var a := _still("pidgey", "rattata", ["gust", "focus_energy", "roost", "protect"])
	var p: BattleFighter = a.player
	var ai: BattleAI = p.ai
	check(ai.status_ok("focus_energy"), "Focus Energy a primeira vez")
	ai.note_used("focus_energy")
	ai.status_lock_t = 0.0
	p.crit_stage = 0
	check(not ai.status_ok("focus_energy"), "Focus Energy uma vez por luta")
	check(not ai.status_ok("roost"), "Roost com HP cheio fica de fora")
	p.hp = int(p.max_hp * 0.3)
	check(ai.status_ok("roost") and ai.status_urgent("roost"), "Roost com HP baixo é urgente")
	a.free()


func _lock() -> void:
	var a := _still("charmander", "rattata", ["ember", "swords_dance", "protect", "agility"])
	var p: BattleFighter = a.player
	var ai: BattleAI = p.ai
	ai.note_used("agility")
	check(
		ai.status_lock_t >= BattleAI.STATUS_LOCK.x and ai.status_lock_t <= BattleAI.STATUS_LOCK.y,
		"status liga a trava de 4-6 s (%.1f)" % ai.status_lock_t
	)
	check(not ai.status_ok("swords_dance"), "na trava o buff espera")
	a.enemy.prepare_t = 0.5
	check(ai.status_ok("protect"), "na trava o Protect diante de ameaça passa")
	a.enemy.prepare_t = 0.0
	var any_status := false
	for i in 60:
		var id := ai.pick(["ember", "swords_dance", "agility"])
		if id != "ember":
			any_status = true
	check(not any_status, "na trava a IA ataca")
	check(ai.pick(["swords_dance", "agility"]) == "", "na trava sem golpe de dano pronto espera")
	ai.note_used("ember")
	check(ai.status_lock_t > 0.0, "golpe de dano não mexe na trava")
	p.moves = ["ember"]
	for i in int((BattleAI.STATUS_LOCK.y + 0.2) / DT):
		ai.step(DT)
	check(ai.status_lock_t <= 0.0, "a trava acaba")
	a.free()


func _pick_weights() -> void:
	var a := _still("charmander", "rattata", ["ember", "swords_dance", "agility", "sweet_scent"])
	var ai: BattleAI = a.player.ai
	var n := {}
	for i in 600:
		ai.status_lock_t = 0.0
		var id := ai.pick(["ember", "swords_dance", "agility", "sweet_scent"])
		n[id] = int(n.get(id, 0)) + 1
	var st := 600 - int(n.get("ember", 0))
	check(st > 60 and st < 450, "status às vezes, dano na maioria %s" % str(n))
	check(int(n.get("sweet_scent", 0)) < int(n.get("swords_dance", 0)), "Sweet Scent pesa pouco")
	ai.status_lock_t = 0.0
	var waited := 0
	for i in 200:
		if ai.status_lock_t <= 0.0:
			if ai.pick(["sweet_scent"]) == "":
				waited += 1
		ai.status_lock_t = 0.0
	check(waited > 100, "dano em cooldown: o status fraco quase sempre espera (%d/200)" % waited)
	ai.status_lock_t = 0.0
	if ai.pick(["sweet_scent"]) == "":
		check(ai.status_lock_t >= BattleAI.DECLINE_LOCK, "recusou: não rola de novo por 1,5 s")
	a.free()


## Os dois sem PP perto um do outro: o Desespero sai (antes ninguém batia e a luta ia até o tempo).
func _struggle_deadlock() -> void:
	var a := _still("clefairy", "oddish", [])
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.controller = "ai"
	e.controller = "ai"
	for f in [p, e]:
		f.pp_max = 0.0
	check(p.out_of_pp() and e.out_of_pp(), "os dois sem PP")
	var hp0 := p.hp + e.hp
	_run(a, 12.0)
	check(p.hp + e.hp < hp0, "sem PP eles se batem no Desespero (%d -> %d)" % [hp0, p.hp + e.hp])
	a.free()


func near(x: float, y: float) -> bool:
	return absf(x - y) < 0.001
