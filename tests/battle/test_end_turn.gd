extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_end_turn.gd
## Fim de turno oficial (BattleEndTurn): uma vez por rodada, valores da Gen 9 (veneno 1/8, queimadura
## 1/16, Toxic n/16, Leftovers, Black Sludge, Leech Seed, areia...), a ordem oficial dos passos, a Speed
## dentro do passo, sono/confusão/congelado contados em turnos, clima/Tailwind/Trick Room/Protect em
## rodadas, frutinhas e o popup/clarão. As lutas daqui usam damage_pace 1 (os valores oficiais); o
## ritmo do modo de energia (0,6) entra pelo fighter.paced (_pace).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	seed(4)
	_once_per_round()
	_clock()
	_values()
	_toxic()
	_items()
	_leech_and_sand()
	_more_values()
	_order()
	_speed_order()
	_sleep_and_confusion()
	_freeze()
	_durations()
	_protect()
	_protect_stall()
	_follow_me()
	_yawn_wish_future()
	_pace()
	print("end_turn: %d checks, %d falhas" % [_count, _fails])
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
	if not opts.has("damage_pace"):
		opts["damage_pace"] = 1.0
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false
	opts["field_objects"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada (os dois sem controle e sem habilidade), intro passada, tudo zerado.
func _still(me := "charmander", foe := "rattata", lv := 40, opts := {}) -> Node:
	if not opts.has("seed"):
		opts["seed"] = 11
	var a := _arena([Mon.create(me, lv)], [Mon.create(foe, lv)], opts)
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		_reset(f)
	return a


func _reset(f: BattleFighter) -> void:
	f.set_meta("ability_override", "")
	f.hp = f.max_hp
	f.mon.hp = BattleFighter.hp_to_mon(f.hp)
	f.clear_status()
	f.clear_seed()
	f.confusion_t = 0.0
	f.trap_t = 0.0
	f.trainer_item = ""
	f.item_used = false
	for k in f.stages:
		f.stages[k] = 0
	f.knock = Vector3.ZERO
	f.move_cd.clear()
	f.gcd_t = 0.0
	f.stun_t = 0.0
	f.impact_t = 0.0


func _sixteenth(f: BattleFighter) -> int:
	return maxi(1, int(f.max_hp / 16.0))


func _eighth(f: BattleFighter) -> int:
	return maxi(1, int(f.max_hp / 8.0))


## Passos do último fim de turno (na ordem) para um lutador; com f null, todos.
func _steps(a: Node, f: BattleFighter = null) -> Array:
	var out := []
	for e in a.end_turn.last_log:
		if f == null or e.who == f:
			out.append(String(e.step))
	return out


# --- Uma vez por rodada ---


func _once_per_round() -> void:
	var a := _still()
	var e: BattleFighter = a.enemy
	var r0: int = a.end_turn.rounds
	# alinha no começo de uma rodada
	var guard := 0
	while a.end_turn.rounds == r0 and guard < 600:
		a.step(DT)
		guard += 1
	_reset(e)
	e.apply_status("poison", a.player)
	e.status_t = 999.0  # o veneno passaria sozinho em BattleEnergy.STATUS_SECS
	var hp0 := e.hp
	var r1: int = a.end_turn.rounds
	_run(a, 0.5)
	check(e.hp == hp0, "veneno não tira HP no meio da rodada (%d -> %d)" % [hp0, e.hp])
	_run(a, BattleTurns.ROUND_SECS * 3.0 - 0.4)
	var ticks: int = a.end_turn.rounds - r1
	check(ticks == 3, "3 rodadas = 3 fins de turno (%d)" % ticks)
	check(
		e.hp == hp0 - 3 * _eighth(e),
		"veneno 1/8 uma vez por rodada: 3 ticks (%d -> %d, 1/8 = %d)" % [hp0, e.hp, _eighth(e)]
	)
	# popup e clarão na hora do fim da rodada
	_reset(e)
	e.apply_status("burn", a.player)
	a.end_turn.run()
	check(e._flash_t > 0.0 and e._flash_col != BattleFighter.FLASH_COL, "clarão de cor no sprite")
	if a.hud and a.hud.has_method("warn_text"):
		# HUD quieto (BattleHUD.quiet): a linha de fim de rodada não aparece.
		check(not a.hud.warn_text().contains("End of round"), 'sem "End of round" no HUD')
	a.free()


## O fim de turno é um relógio de ROUND_SECS.
func _clock() -> void:
	var a := _still("charmander", "rattata", 40)
	var e: BattleFighter = a.enemy
	e.apply_status("burn", a.player)
	var hp0 := e.hp
	var r0: int = a.end_turn.rounds
	_run(a, BattleTurns.ROUND_SECS * 2.0 + 0.1)
	var n: int = a.end_turn.rounds - r0
	check(n == 2, "fim de turno a cada ROUND_SECS (%d)" % n)
	check(e.hp == hp0 - n * _sixteenth(e), "queimadura 1/16 por rodada")
	a.free()


# --- Valores oficiais ---


func _values() -> void:
	var a := _still("charmander", "slowbro", 50)
	var e: BattleFighter = a.enemy
	e.apply_status("poison", a.player)
	var hp0 := e.hp
	a.end_turn.run()
	check(e.hp == hp0 - _eighth(e), "veneno 1/8 (%d)" % (hp0 - e.hp))
	_reset(e)
	e.apply_status("burn", a.player)
	hp0 = e.hp
	a.end_turn.run()
	check(e.hp == hp0 - _sixteenth(e), "queimadura 1/16 (%d)" % (hp0 - e.hp))
	check(e.status == "burn", "queimadura não acaba sozinha")
	_reset(e)
	e.apply_status("paralysis", a.player)
	for i in 6:
		a.end_turn.run()
	check(e.status == "paralysis" and e.hp == e.max_hp, "paralisia fica e não tira HP")
	a.free()


func _toxic() -> void:
	var a := _still("charmander", "slowbro", 50)
	var e: BattleFighter = a.enemy
	e.apply_status("toxic", a.player)
	var got := []
	for i in 3:
		var h := e.hp
		a.end_turn.run()
		got.append(h - e.hp)
	var u := _sixteenth(e)
	check(got == [u, 2 * u, 3 * u], "Toxic 1/16 -> 2/16 -> 3/16 %s (1/16 = %d)" % [str(got), u])
	check(e.toxic_n == 3, "contador do Toxic em 3")
	a.free()


func _items() -> void:
	var a := _still("charmander", "rattata", 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.trainer_item = "leftovers"
	p.hp = p.max_hp / 2
	var h := p.hp
	a.end_turn.run()
	check(p.hp == h + _sixteenth(p), "Leftovers +1/16 (%d)" % (p.hp - h))
	check(not p.item_used, "Leftovers não acaba")
	p.hp = p.max_hp
	a.end_turn.run()
	check(p.hp == p.max_hp, "Leftovers com HP cheio não faz nada")
	e.trainer_item = "black_sludge"
	h = e.hp
	a.end_turn.run()
	check(e.hp == h - _eighth(e), "Black Sludge -1/8 em quem não é Veneno")
	a.free()
	var b := _still("charmander", "ekans", 40)
	var k: BattleFighter = b.enemy
	k.trainer_item = "black_sludge"
	k.hp = k.max_hp / 2
	h = k.hp
	b.end_turn.run()
	check(k.hp == h + _sixteenth(k), "Black Sludge +1/16 no Veneno")
	# frutinhas na hora, como o oficial
	k.trainer_item = "sitrus_berry"
	k.item_used = false
	k.hp = k.max_hp
	k.take_damage(k.max_hp / 2 + 1, Vector3.ZERO, 0.0)
	var low := k.max_hp - (k.max_hp / 2 + 1)
	check(
		k.hp == low + maxi(1, int(k.max_hp / 4.0)) and k.item_used,
		"Sitrus Berry cura 1/4 ao cair para metade (%d)" % k.hp
	)
	k.trainer_item = "oran_berry"
	k.item_used = false
	k.hp = k.max_hp
	k.take_damage(1, Vector3.ZERO, 0.0)
	check(not k.item_used, "Oran Berry não age com HP alto")
	k.take_damage(k.hp - k.max_hp / 2, Vector3.ZERO, 0.0)
	check(
		k.item_used and k.hp == k.max_hp / 2 + BattleFighter.hp_from_mon(10),
		"Oran Berry +10 (HP do Mon) na metade (%d)" % k.hp
	)
	k.trainer_item = "pecha_berry"
	k.item_used = false
	k.clear_status()
	k.status = ""
	k.apply_status("burn", b.player)
	check(k.status == "burn" and not k.item_used, "Pecha não cura queimadura")
	k.clear_status()
	var pa: BattleFighter = b.player
	pa.trainer_item = "pecha_berry"
	pa.apply_status("poison", k)
	check(pa.status == "" and pa.item_used, "Pecha Berry cura o veneno na hora")
	b.free()


func _leech_and_sand() -> void:
	var a := _still("bulbasaur", "rattata", 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(e.apply_status("leech", p) and e.seeded, "Leech Seed pega")
	check(e.apply_status("poison", p) and e.status == "poison", "semente convive com veneno")
	p.hp = p.max_hp / 2
	var hp_p := p.hp
	var hp_e := e.hp
	a.end_turn.run()
	var seed_d := _eighth(e)
	check(hp_e - e.hp == seed_d + _eighth(e), "semente 1/8 + veneno 1/8 (%d)" % (hp_e - e.hp))
	check(p.hp == hp_p + seed_d, "a semente cura quem plantou (%d)" % (p.hp - hp_p))
	a.free()
	var b := _still("pidgey", "geodude", 40)
	var fx: BattleMoveEffects = b.moves.effects
	fx.set_weather("sand", 5)
	check(b.abilities.weather_now() == "sand", "areia ligada")
	var hp_pg: int = b.player.hp
	var hp_g: int = b.enemy.hp
	b.end_turn.run()
	check(b.player.hp == hp_pg - _sixteenth(b.player), "areia 1/16 em Normal/Voador")
	check(b.enemy.hp == hp_g, "Pedra/Terra imune à areia")
	b.free()
	var c := _still("pidgey", "magnemite", 40)
	c.moves.effects.set_weather("sand", 5)
	var hp_m: int = c.enemy.hp
	c.end_turn.run()
	check(c.enemy.hp == hp_m, "Aço imune à areia")
	c.free()


func _more_values() -> void:
	var a := _still("charmander", "slowbro", 50)
	var fx: BattleMoveEffects = a.moves.effects
	var e: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	fx.st(e).cursed = true
	var h := e.hp
	a.end_turn.run()
	check(e.hp == h - maxi(1, int(e.max_hp / 4.0)), "Curse 1/4")
	fx.st(e).cursed = false
	e.hp = e.max_hp
	fx.after_hit(p, e, Dex.move("wrap"), 5)
	var n := fx.rounds_left(fx.st(e), "bound")
	check(n == 5 or n == 6, "Wrap: 5-6 contando o turno do uso (%d)" % n)
	check(fx.cant_escape(e), "preso pelo Wrap não foge")
	var hits := 0
	for i in 8:
		h = e.hp
		a.end_turn.run()
		if e.hp == h - _eighth(e):
			hits += 1
	check(hits == n - 1, "Wrap 1/8 por turno, %d vezes (%d)" % [n - 1, hits])
	check(not fx.active(fx.st(e), "bound") and not fx.cant_escape(e), "Wrap acaba")
	e.hp = e.max_hp / 2
	fx.st(e).aqua_ring = true
	h = e.hp
	a.end_turn.run()
	check(e.hp == h + _sixteenth(e), "Aqua Ring 1/16")
	fx.st(e).aqua_ring = false
	fx.set_rounds(fx.field, "grassy", 5)
	h = e.hp
	a.end_turn.run()
	check(e.hp == h + _sixteenth(e), "Grassy Terrain 1/16 em quem está no chão")
	a.free()


# --- Ordem ---


func _order() -> void:
	var a := _still("charmander", "slowbro", 50)
	var fx: BattleMoveEffects = a.moves.effects
	var e: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	e.hp = e.max_hp / 2
	e.trainer_item = "leftovers"
	e.apply_status("poison", p)
	e.apply_status("leech", p)
	fx.st(e).cursed = true
	fx.set_rounds(fx.field, "grassy", 5)
	fx.set_weather("sand", 5)
	a.end_turn.run()
	var s := _steps(a, e)
	var want := ["weather", "grassy", "leftovers", "leech_seed", "poison", "curse"]
	var pos := want.map(func(k): return s.find(k))
	var sorted := pos.duplicate()
	sorted.sort()
	check(
		not -1 in pos and pos == sorted,
		"ordem oficial: clima, Grassy, Leftovers, Leech Seed, veneno, Curse %s" % str(s)
	)
	check(s.find("leftovers") < s.find("poison"), "Leftovers antes do veneno (oficial Gen 9)")
	check(s.find("weather") < s.find("poison"), "dano de clima antes do veneno")
	a.free()
	# veneno antes da queimadura (passos diferentes, lutadores diferentes)
	var b := _still("charmander", "rattata", 40)
	b.player.stats.spe = 999
	b.enemy.stats.spe = 1
	b.enemy.apply_status("poison", b.player)
	b.player.apply_status("burn", b.enemy)
	b.end_turn.run()
	var all := _steps(b)
	check(
		all.find("poison") < all.find("burn"),
		"veneno (passo 8) antes da queimadura (9) %s" % str(all)
	)
	b.free()


func _speed_order() -> void:
	var a := _still("charmander", "rattata", 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.stats.spe = 50
	e.stats.spe = 200
	p.apply_status("poison", e)
	e.apply_status("poison", p)
	a.end_turn.run()
	var who := []
	for x in a.end_turn.last_log:
		if x.step == "poison":
			who.append(x.who)
	check(who == [e, p], "dentro do passo, o mais rápido primeiro")
	a.turns.toggle_trick_room()
	a.end_turn.run()
	who = []
	for x in a.end_turn.last_log:
		if x.step == "poison":
			who.append(x.who)
	check(who == [p, e], "Trick Room inverte a ordem dentro do passo")
	a.free()


# --- Sono, confusão, congelado ---


func _sleep_and_confusion() -> void:
	var a := _still("charmander", "rattata", 40)
	var e: BattleFighter = a.enemy
	var seen := {}
	for i in 200:
		e.clear_status()
		e.apply_status("sleep")
		seen[e.sleep_turns] = true
	check(
		seen.keys().all(func(k): return k >= 2 and k <= 4) and seen.size() == 3,
		"sono: contador 2-4 (1-3 turnos)"
	)
	seen = {}
	for i in 200:
		e.confusion_t = 0.0
		e.apply_status("confusion")
		seen[e.confusion_turns] = true
	check(
		seen.keys().all(func(k): return k >= 2 and k <= 5) and seen.size() == 4,
		"confusão: contador 2-5"
	)
	# tentativa de agir: contador 2 = dorme 1 turno
	e.confusion_t = 0.0
	e.clear_status()
	e.apply_status("sleep")
	e.sleep_turns = 2
	e.try_act()
	check(e.status == "sleep", "1ª tentativa: ainda dormindo")
	e.try_act()
	check(e.status == "" and e.can_act(), "2ª tentativa: acorda e age")
	e.apply_status("confusion")
	e.confusion_turns = 3
	e.try_act()
	e.try_act()
	check(e.confusion_t > 0.0, "confusão segue nas 2 primeiras tentativas")
	e.try_act()
	check(e.confusion_t == 0.0, "confusão acaba na 3ª tentativa")
	# conta no fim da rodada (não na rodada em que dormiu)
	e.apply_status("sleep")
	e.sleep_turns = 3
	var r0: int = a.end_turn.rounds
	var guard := 0
	while e.status == "sleep" and guard < 60 * 20:
		a.step(DT)
		guard += 1
	var n: int = a.end_turn.rounds - r0
	check(n == 3, "Rest/contador 3 dorme a rodada do uso + 2 (%d fins de turno)" % n)
	# golpe não acorda (oficial)
	e.apply_status("sleep")
	e.take_damage(1, Vector3.FORWARD, 4.0)
	check(e.status == "sleep", "golpe com empurrão não acorda")
	a.free()


func _freeze() -> void:
	var a := _still("charmander", "rattata", 40)
	var e: BattleFighter = a.enemy
	var thaw := 0
	for i in 1000:
		e.clear_status()
		e.apply_status("freeze")
		e.try_act()
		if e.status == "":
			thaw += 1
	check(thaw > 150 and thaw < 250, "congelado: 20%% por tentativa (%d/1000)" % thaw)
	e.clear_status()
	e.apply_status("freeze")
	_run(a, 2.6)
	check(e.status == "freeze", "congelado não acaba por tempo")
	a.free()


# --- Durações em rodadas ---


func _durations() -> void:
	var a := _still("pidgey", "rattata", 40)
	var fx: BattleMoveEffects = a.moves.effects
	var ab: BattleAbilities = a.abilities
	var p: BattleFighter = a.player
	fx.set_weather("sand", BattleMoveEffects.FIELD_TURNS)
	var chips := 0
	for i in 4:
		var h := p.hp
		a.end_turn.run()
		chips += 1 if p.hp < h else 0
	check(ab.weather_now() == "sand", "clima de golpe ainda na 4ª rodada")
	var h5 := p.hp
	a.end_turn.run()
	check(ab.weather_now() == "", "clima de golpe acaba na 5ª rodada")
	check(chips == 4 and p.hp == h5, "areia tira HP 4 vezes (no fim do 5º turno já acabou)")
	var spe0 := p.stat("spe")
	fx.self_move(p, Dex.move("tailwind"))
	check(is_equal_approx(p.stat("spe"), spe0 * 2.0), "Tailwind dobra a Speed")
	for i in 3:
		a.end_turn.run()
	check(is_equal_approx(p.stat("spe"), spe0 * 2.0), "Tailwind segue na 3ª rodada")
	a.end_turn.run()
	check(is_equal_approx(p.stat("spe"), spe0), "Tailwind acaba depois de 4 rodadas")
	fx.self_move(p, Dex.move("light_screen"))
	for i in 4:
		a.end_turn.run()
	check(fx.side_active(0, "light_screen"), "Light Screen na 4ª rodada")
	a.end_turn.run()
	check(not fx.side_active(0, "light_screen"), "Light Screen: 5 rodadas")
	check(a.turns.toggle_trick_room(), "Trick Room liga")
	for i in 4:
		a.end_turn.run()
	check(a.turns.trick_room() and a.turns.trick_room_rounds == 1, "Trick Room na 4ª rodada")
	a.end_turn.run()
	check(not a.turns.trick_room(), "Trick Room: 5 rodadas")
	fx.self_move(p, Dex.move("gravity"))
	for i in 5:
		a.end_turn.run()
	check(not fx.no_jump(), "Gravity: 5 rodadas")
	# Taunt 3, Disable 4 (o golpe volta), Encore 3
	var e: BattleFighter = a.enemy
	fx.after_hit(p, e, Dex.move("taunt"), 0)
	for i in 2:
		a.end_turn.run()
	check(not fx.usable(e, Dex.move("growl")), "Taunt na 2ª rodada")
	a.end_turn.run()
	check(fx.usable(e, Dex.move("growl")), "Taunt: 3 rodadas")
	fx.st(e).last = "tackle"
	fx.after_hit(p, e, Dex.move("disable"), 0)
	for i in 3:
		a.end_turn.run()
	check(float(e.move_cd.get("tackle", 0.0)) > 100.0, "Disable trava o golpe")
	a.end_turn.run()
	check(float(e.move_cd.get("tackle", 0.0)) == 0.0, "Disable: 4 rodadas")
	a.free()


func _protect() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var e: BattleFighter = a.enemy
	var r0: int = a.end_turn.rounds
	var guard := 0
	while a.end_turn.rounds == r0 and guard < 600:
		a.step(DT)
		guard += 1
	fx.self_move(e, Dex.move("protect"))
	_run(a, 2.0)
	check(fx.active(fx.st(e), "protect"), "Protect segue até o fim da rodada (2 s depois)")
	var hp0 := e.hp
	a.moves.hit(a.player, e, Dex.move("ember"), Vector3.FORWARD)
	check(e.hp == hp0, "Protect segura o golpe na rodada")
	_run(a, BattleTurns.ROUND_SECS - 2.0 + 0.1)
	check(not fx.active(fx.st(e), "protect"), "Protect acaba no fim da rodada")
	a.free()


## Protect em rodadas seguidas: 1, 1/3, 1/9...; zera quando uma rodada passa sem usar.
func _protect_stall() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var e: BattleFighter = a.enemy
	var pr := Dex.move("protect")
	fx.rng.seed = 77
	var ok2 := 0
	var ok3 := 0
	var fresh := 0
	var n := 600
	for i in n:
		fx.st(e).erase("stall_n")
		fx.st(e).erase("stall_round")
		fx.self_move(e, pr)
		a.turns.round_n += 1
		fx.st(e).erase("protect")
		fx.self_move(e, pr)
		var got2 := fx.active(fx.st(e), "protect")
		if got2:
			ok2 += 1
			a.turns.round_n += 1
			fx.st(e).erase("protect")
			fx.self_move(e, pr)
			if fx.active(fx.st(e), "protect"):
				ok3 += 1
		a.turns.round_n += 2  # uma rodada sem usar: zera
		fx.st(e).erase("protect")
		fx.self_move(e, pr)
		if fx.active(fx.st(e), "protect"):
			fresh += 1
		a.turns.round_n += 2
	check(absf(ok2 / float(n) - 1.0 / 3.0) < 0.06, "2º Protect seguido: 1/3 (%d/%d)" % [ok2, n])
	check(
		ok2 > 0 and absf(ok3 / float(ok2) - 1.0 / 9.0) < 0.07,
		"3º Protect seguido: 1/9 (%d/%d)" % [ok3, ok2]
	)
	check(fresh == n, "depois de uma rodada sem usar, o Protect volta a 100%% (%d/%d)" % [fresh, n])
	a.free()


## Follow Me / Rage Powder: puxam os golpes até o fim da rodada em que saíram.
func _follow_me() -> void:
	var a := _arena(
		[Mon.create("clefairy", 30), Mon.create("pidgey", 30)],
		[Mon.create("rattata", 30), Mon.create("rattata", 30)],
		{"seed": 11, "battle_size": 2, "kind": "trainer", "no_rewards": true}
	)
	_run(a, 1.3)
	for f in a.fighters:
		f.controller = "none"
	var mine: Array = a.fighters.filter(func(f): return f.side == 0 and f.active())
	var foes: Array = a.fighters.filter(func(f): return f.side == 1 and f.active())
	check(mine.size() == 2 and foes.size() == 2, "dupla 2x2")
	if mine.size() < 2 or foes.size() < 2:
		a.free()
		return
	var fx: BattleMoveEffects = a.moves.effects
	var r0: int = a.end_turn.rounds
	var guard := 0
	while a.end_turn.rounds == r0 and guard < 600:
		a.step(DT)
		guard += 1
	var lure: BattleFighter = mine[0]
	for g in foes:
		g.opponent = mine[1]
	fx.self_move(lure, Dex.move("follow_me"))
	_run(a, 2.0)
	check(foes.all(func(g): return g.opponent == lure), "Follow Me puxa os dois adversários")
	_run(a, BattleTurns.ROUND_SECS - 2.0 + 0.1)
	check(not fx.active(fx.st(lure), "follow"), "Follow Me acaba no fim da rodada")
	a.free()


func _yawn_wish_future() -> void:
	var a := _still("charmander", "slowbro", 50)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	fx.after_hit(p, e, Dex.move("yawn"), 0)
	a.end_turn.run()
	check(e.status == "", "Yawn: acordado no fim do turno do uso")
	a.end_turn.run()
	check(e.status == "sleep", "Yawn: dorme no fim do turno seguinte")
	e.clear_status()
	p.hp = 10
	fx.self_move(p, Dex.move("wish"))
	a.end_turn.run()
	check(p.hp == 10, "Wish ainda não cura no turno do uso")
	a.end_turn.run()
	check(
		p.hp == mini(10 + int(ceil(p.max_hp / 2.0)), p.max_hp),
		"Wish cura metade no fim do turno seguinte"
	)
	fx.add_future(p, Dex.move("future_sight"), null)
	a.end_turn.run()
	a.end_turn.run()
	check(fx.futures.size() == 1, "Future Sight no ar por 2 turnos")
	a.end_turn.run()
	check(fx.futures.is_empty(), "Future Sight cai no fim do 2º turno depois do uso")
	a.free()


## O dano residual segue o ritmo do dano dos golpes (damage_pace, fighter.paced).
func _pace() -> void:
	var a := _still("charmander", "rattata", 40, {"damage_pace": 0.375})
	var e: BattleFighter = a.enemy
	check(e.dot_scale() < 1.0, "ritmo baixo nesta arena")
	e.apply_status("poison", a.player)
	var h := e.hp
	a.end_turn.run()
	check(e.hp == h - e.paced(_eighth(e)), "veneno 1/8 x damage_pace")
	a.free()
