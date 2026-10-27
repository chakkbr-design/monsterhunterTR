extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_ai_plans.gd
## IA do modo de energia: passivas de movimento (pulo de desespero encurralado, dentro da quadra e com
## recarga; fôlego), planos escolhidos e trocados, escolha suave
## que nunca pega golpe sem efeito e às vezes troca de golpe, e lutas que acabam: Squirtle só com
## Water Pledge contra Nidoran F em pânico com 3% de HP e a semente 2 da bateria (1x1).

const ARENA := "res://battle/battle_arena.tscn"
const SCENE := "res://ui/training/training_battle.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
## Sementes do duelo Squirtle x Nidoran F em pânico (cada uma tem que acabar em PANIC_LIMIT s).
const PANIC_SEEDS := [2, 3, 4, 5, 6, 7, 8, 9]
## Em tempo de luta: com o andar mais lento do modo de energia (BattleEnergy.WALK_PACE) a perseguição
## demora na mesma proporção.
const PANIC_LIMIT := 120.0 / BattleEnergy.WALK_PACE

var _fails := 0
var _count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_leap()
	_plans()
	_soft_pick()
	for sd in PANIC_SEEDS:
		_panic_duel(sd)
	await _seed2()
	print("ai_plans: %d checks, %d falhas" % [_count, _fails])
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
	opts.merge(
		{"speed": 1.0, "no_rewards": true, "kind": "trainer"}, false
	)
	a.start(party, enemies, opts)
	return a


func _to_fight(a: Node) -> void:
	var t := 0.0
	while a.state == "intro" and t < 10.0:
		a.step(DT)
		t += DT


func _wall(a: Node, p: Vector3) -> float:
	var r: Rect2 = a.rect
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.z - r.position.y, r.end.y - p.z))


## Encurralado no canto com o inimigo colado: pula para o aberto, dentro da quadra, ganha fôlego, e
## não pula de novo antes da recarga.
func _leap() -> void:
	var a := _arena(
		[Mon.create("pikachu", 30)],
		[Mon.create("geodude", 30)],
		{"battle_size": 1, "autoplay": true, "seed": 5, "terrain": false, "field_objects": false}
	)
	_to_fight(a)
	a.tut_hold_foe = true
	var f: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	var r: Rect2 = a.rect
	var corner := Vector3(r.position.x + 0.8, 0.0, r.position.y + 0.8)
	f.position = corner
	foe.position = corner + Vector3(1.6, 0.0, 1.2)
	f.pp_max = 20.0
	var pas: BattlePassives = f.ai.passives
	check(pas.cornered(0.5) == false, "encurralado só depois de CORNER_SECS")
	check(pas.tick(0.6), "pulo de desespero sai encurralado no canto")
	check(f.motion == "leap", "o pulo é um salto (motion leap)")
	check(pas.leap_cd >= BattlePassives.LEAP_CD - 0.01, "recarga do pulo começou")
	# É o salto de obstáculo (BattleClimb): custa a energia dele e divide a recarga.
	check(f.jump_cd >= BattleClimb.JUMP_CD - 0.01, "pulo de desespero usa a recarga do salto")
	check(
		absf(f.pp_max - (20.0 - BattleClimb.JUMP_COST)) < 0.01,
		"pulo de desespero custa JUMP_COST (%.1f)" % f.pp_max
	)
	var top := 0.0
	var t := 0.0
	while f.motion != "" and t < 2.0:
		a.step(DT)
		t += DT
		top = maxf(top, f.height())
		var inside := r.has_point(Vector2(f.position.x, f.position.z))
		if not inside:
			check(false, "o pulo sai da quadra (%s)" % f.position)
			break
	check(f.motion == "", "pousou")
	check(top > 1.0, "alto o bastante para a investida passar por baixo (%.2f m)" % top)
	var moved := (f.pos2(f.position) - corner).length()
	check(moved > 2.5, "saiu do canto (%.1f m)" % moved)
	check(_wall(a, f.position) > _wall(a, corner) + 1.0, "longe da parede depois do pulo")
	check(
		f.flat_to(foe).length() > 2.0, "pousa longe do inimigo (%.1f m)" % f.flat_to(foe).length()
	)
	check(
		f.pp_max >= 20.0 - BattleClimb.JUMP_COST + BattlePassives.BREATH_ENERGY - 0.5,
		"fôlego: energia extra (%.1f)" % f.pp_max
	)
	check(f.breath_t > 0.0, "fôlego: recarga mais rápida por uns segundos")
	f.breath_t = 0.0
	var plain := BattleEnergy.regen(f)
	f.breath_t = 1.0
	check(BattleEnergy.regen(f) > plain * 1.2, "fôlego acelera a energia")
	# De volta ao canto: a recarga segura o próximo pulo.
	f.position = corner
	foe.position = corner + Vector3(1.6, 0.0, 1.2)
	check(not pas.tick(1.5), "não pula de novo durante a recarga")
	pas.leap_cd = 0.0
	check(not pas.tick(1.5), "a recarga do salto (jump_cd) também segura")
	f.jump_cd = 0.0
	var en := f.pp_max
	f.pp_max = BattleClimb.JUMP_COST - 1.0
	check(not pas.tick(1.5), "sem energia para o salto não pula")
	f.pp_max = en
	check(pas.tick(1.5), "pula de novo depois da recarga")
	# Longe da parede ninguém pula.
	var f2: BattleFighter = f
	var t2 := 0.0
	while f2.motion != "" and t2 < 2.0:
		a.step(DT)
		t2 += DT
	f2.position = Vector3(r.get_center().x, 0.0, r.get_center().y)
	foe.position = f2.position + Vector3(1.0, 0.0, 0.0)
	pas.leap_cd = 0.0
	f2.jump_cd = 0.0
	check(not pas.tick(2.0), "no meio da quadra não pula")
	a.queue_free()


## Plano escolhido na entrada, reavaliado e trocado ao longo da luta (pesos com sorteio).
func _plans() -> void:
	var seen := {}
	var changes := 0
	var reevals := 0
	var first_ok := true
	for sd in 3:
		var mrng := RandomNumberGenerator.new()
		mrng.seed = 60 + sd
		var a := _arena(
			[Mon.create("pikachu", 30, mrng), Mon.create("geodude", 30, mrng)],
			[Mon.create("charmander", 30, mrng), Mon.create("squirtle", 30, mrng)],
			{"battle_size": 2, "autoplay": true, "seed": 60 + sd, "arena": Cfg.SMALL_ARENA}
		)
		var last := {}
		var last_t := {}
		var t := 0.0
		while t < 60.0 and a.state in ["intro", "fight"]:
			a.step(DT)
			t += DT
			if a.state != "fight":
				continue
			for f in a.fighters:
				if not is_instance_valid(f) or not f.active() or f.ai == null:
					continue
				var p := String(f.ai.plan)
				var k: int = f.get_instance_id()
				if p == "":
					first_ok = first_ok and f.ai.last_move == ""  # quem já bateu tem plano
					continue
				seen[p] = true
				if last.has(k) and last[k] != p:
					changes += 1
				if last_t.has(k) and f.ai.plan_t > float(last_t[k]) + 1.0:
					reevals += 1
				last[k] = p
				last_t[k] = f.ai.plan_t
		a.queue_free()
	print("  planos vistos: %s, reavaliações: %d, trocas: %d" % [seen.keys(), reevals, changes])
	check(first_ok, "plano escolhido na entrada")
	check(seen.size() >= 3, "vários planos aparecem (%d)" % seen.size())
	check(reevals >= 3, "o plano é reavaliado de tempos em tempos (%d)" % reevals)
	check(changes >= 1, "o plano muda na luta (%d trocas)" % changes)
	# O sorteio pelos pesos não sai sempre igual para o mesmo lutador na mesma situação.
	var a2 := _arena(
		[Mon.create("pikachu", 30)],
		[Mon.create("geodude", 30)],
		{"battle_size": 1, "autoplay": true, "seed": 9, "terrain": false}
	)
	_to_fight(a2)
	var picks := {}
	for i in 60:
		a2.player.ai.plan = ""
		a2.player.ai.choose_plan()
		picks[a2.player.ai.plan] = true
	check(picks.size() >= 2, "plano sorteado pelos pesos, não fixo (%s)" % picks.keys())
	check(not picks.has(BattlePlan.PROTECT), "1x1: sem plano de proteger o parceiro")
	a2.queue_free()
	for p in seen:
		check(p in BattlePlan.ALL, "plano conhecido: %s" % p)


## Escolha suave: golpe sem efeito nunca; o melhor na maioria; outro razoável às vezes.
func _soft_pick() -> void:
	var a := _arena(
		[Mon.create("pikachu", 30)],
		[Mon.create("geodude", 30)],
		{"battle_size": 1, "autoplay": true, "seed": 7, "terrain": false}
	)
	_to_fight(a)
	var f: BattleFighter = a.player
	f.moves = ["thunderbolt", "quick_attack", "iron_tail", "thunder_shock"]
	f.pp_max = 100.0
	f.move_cd.clear()
	var count := {}
	for i in 400:
		f.ai.last_move = ""
		f.ai.plan = ""
		var id: String = f.ai.pick(f.moves.duplicate())
		count[id] = int(count.get(id, 0)) + 1
	print("  escolha suave contra Geodude: %s" % count)
	check(
		not count.has("thunderbolt") and not count.has("thunder_shock"),
		"nunca escolhe golpe Elétrico contra Terra"
	)
	var best := ""
	for id in count:
		if best == "" or int(count[id]) > int(count[best]):
			best = id
	check(int(count.get(best, 0)) >= 240, "o melhor golpe sai na maioria (%s)" % count)
	check(count.size() >= 2, "às vezes sai outro golpe razoável (%s)" % count)
	a.queue_free()


## Squirtle só com Water Pledge (golpe de dupla funciona sozinho) contra Nidoran F em pânico com 3% de
## HP e a barra cheia: a luta tem que acabar (antes os dois ficavam rodando até o tempo acabar).
func _panic_duel(sd: int) -> void:
	var mrng := RandomNumberGenerator.new()
	mrng.seed = sd
	var sq := Mon.create("squirtle", 30, mrng)
	sq.moves = ["water_pledge", "sleep_talk", "haze", "helping_hand"]
	var ni := Mon.create("Nidoran F", 30, mrng)
	ni.moves = ["poison_jab", "sunny_day", "protect", "rain_dance"]
	ni.nature = "timid"
	ni.hp = maxi(1, int(ni.max_hp * 0.03))
	var a := _arena(
		[sq], [ni], {"battle_size": 1, "autoplay": true, "seed": sd, "arena": Cfg.SMALL_ARENA}
	)
	_to_fight(a)
	if is_instance_valid(a.enemy):
		a.enemy.pp_max = BattleEnergy.MAX
	var t := 0.0
	var pledges := 0
	var prev := 0.0
	while t < PANIC_LIMIT and a.state in ["intro", "fight"]:
		a.step(DT)
		t += DT
		var p: BattleFighter = a.player
		if is_instance_valid(p) and p.active():
			var cd := float(p.move_cd.get("water_pledge", 0.0))
			if cd > prev + 0.01:
				pledges += 1
			prev = cd
	print("  Squirtle x Nidoran F em pânico (%d): %.1f s, %d Water Pledge" % [sd, t, pledges])
	check(pledges >= 1, "Water Pledge sai sozinho, sem parceiro (%d)" % sd)
	check(a.state not in ["intro", "fight"], "a luta acaba (%d: %.0f s)" % [sd, t])
	a.queue_free()


## A semente 2 da bateria (1x1, mesma configuração de tests/balance/battery.gd) termina sem empate.
func _seed2() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var c := Cfg.default_config()
	Cfg.randomize_sides(c, rng)
	for s in 2:
		c.sides[s].think_scale = [0.8, 1.0, 1.0, 1.2][rng.randi() % 4]
	var w: String = ["", "", "", "sun", "rain", "sand", "hail"][rng.randi() % 7]  # clima da bateria
	if w != "":
		c.weather = w
	c.battle_size = 1
	c.seed = 2
	c.turbo = true
	c.time_limit = 420
	c.extra_opts = {"fast_sim": true}
	Cfg.path = "user://test_ai_plans_cfg.json"
	Cfg.current = c
	var tb: Node = load(SCENE).instantiate()
	root.add_child(tb)
	await process_frame
	for i in 60 * 60 * 30:
		await process_frame
		if tb._result_box.visible:
			break
	var out := String(tb.result.get("outcome", "?"))
	print("  semente 2 (1x1): %s em %.1f s" % [out, float(tb.fight_time)])
	check(out in ["win", "lose"], "semente 2 termina sem empate (%s)" % out)
	tb.queue_free()
	await process_frame
