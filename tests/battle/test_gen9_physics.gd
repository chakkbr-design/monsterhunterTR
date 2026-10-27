extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_gen9_physics.gd
## Gen 9 física e regras de dupla: fórmula de dano Gen 5+ (spread 0,75x, queimadura, Guts), golpe de alvo
## único na dupla, mesmo dano 1x1 e 2x2, empurrão por eficácia, arremesso e batida na cerca, salto do Body Slam,
## Aerial Ace, Dig e a IA (área na dupla, investida longa).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_formula()
	_spread_doubles()
	_single_target()
	_same_damage()
	_knock_eff()
	_push_and_crash()
	_leap()
	_blink()
	_dig()
	_ai()
	print("gen9_physics: %d checks, %d falhas" % [_count, _fails])
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
	var base := {"speed": 1.0, "damage_pace": 1.0, "field_objects": false, "no_rewards": true}
	base.merge(opts, true)
	if opts.get("default_pace", false):
		base.erase("damage_pace")
	a.start(party, enemies, base)
	var t := 0.0
	while a.state != "fight" and t < 12.0:
		a.step(DT)
		t += DT
	for f in a.fighters:
		f.controller = "none"
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _mon(sp: String, lv: int) -> Mon:
	var m := Mon.create(sp, lv)
	m.ability_slot = 0
	return m


func _duo(sp_a: Array, sp_b: Array, lv := 40, seed := 7) -> Node:
	var pa: Array = sp_a.map(func(s): return _mon(s, lv))
	var pb: Array = sp_b.map(func(s): return _mon(s, lv))
	return _arena(pa, pb, {"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": seed})


## HP grande para o dano não ficar limitado pelo HP do alvo (o nocaute cortava a conta do spread).
func _heal_all(a: Node) -> void:
	for f in a.fighters:
		f.max_hp = 9999
		f.hp = f.max_hp
		f.mon.hp = f.max_hp
		f.knock = Vector3.ZERO
		f.launch_t = 0.0
		f.stun_t = 0.0
		f.impact_t = 0.0


# --- Fórmula ---


func _formula() -> void:
	var atk := {"level": 50, "types": ["fire"], "atk": 120, "spa": 120, "crit_stage": 0}
	var grass := {"types": ["grass"], "def": 80, "spd": 80}
	var mv := {"type": "fire", "category": "special", "power": 90}
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	var ok := true
	for i in 30:
		r1.seed = 100 + i
		r2.seed = 100 + i
		var full := Damage.compute(atk, grass, mv, r1)
		var spread := Damage.compute(atk, grass, mv, r2, {"spread": 0.75})
		var ratio := float(spread.damage) / float(full.damage)
		if ratio < 0.7 or ratio > 0.8:
			ok = false
	check(ok, "spread 0,75x na fórmula")
	# Ordem oficial: base inteira, com floor; nível 50, poder 90, 120/80 dá base 61 (sem crítico, roll 100).
	var base := floorf(floorf(floorf(2.0 * 50 / 5.0 + 2.0) * 90 * 120 / 80.0) / 50.0) + 2.0
	check(int(base) == 61, "base Gen 5+ (%d)" % int(base))
	check(Damage.poke_round(2.5) == 2.0 and Damage.poke_round(2.51) == 3.0, "pokeRound desce no .5")
	check(Damage.weather_mult("water", "rain") == 1.5, "chuva sobe Água")
	check(Damage.weather_mult("fire", "rain") == 0.5, "chuva corta Fogo")
	var phys := {"type": "normal", "category": "physical", "power": 80}
	var burned := atk.duplicate()
	burned["burned"] = true
	var guts := burned.duplicate()
	guts["guts"] = true
	r1.seed = 5
	var d_ok: int = Damage.compute(atk, grass, phys, r1).damage
	r1.seed = 5
	var d_burn: int = Damage.compute(burned, grass, phys, r1).damage
	r1.seed = 5
	var d_guts: int = Damage.compute(guts, grass, phys, r1).damage
	check(
		abs(d_burn * 2 - d_ok) <= 2,
		"queimadura corta o físico pela metade (%d / %d)" % [d_burn, d_ok]
	)
	check(d_guts == d_ok, "Guts ignora a queimadura")


# --- Dupla ---


func _spread_doubles() -> void:
	var a := _duo(["sandshrew", "squirtle"], ["rattata", "rattata"])
	check(a.doubles, "2x2 ligado")
	var user: BattleFighter = a.player
	var e1: BattleFighter = a.enemy
	var e2: BattleFighter = a.enemy2
	a.ally.position = Vector3(6, 0, 3)
	user.position = Vector3(0, 0, 2)
	e1.position = Vector3(0, 0, 0.5)
	e2.position = Vector3(1.2, 0, 0.3)
	user.opponent = e1
	var mv := Dex.move("earthquake")
	_heal_all(a)
	a.rng.seed = 77
	a.moves.deliver(user, mv)
	_run(a, 0.8)
	var both := e1.max_hp - e1.hp
	check(e2.hp < e2.max_hp, "Earthquake acerta os dois adversários")
	check(a.ally.hp == a.ally.max_hp, "parceiro longe não leva o Earthquake")
	_heal_all(a)
	e2.position = Vector3(8, 0, -3)
	e1.position = Vector3(0, 0, 0.5)
	user.position = Vector3(0, 0, 2)
	a.rng.seed = 77
	a.moves.deliver(user, mv)
	_run(a, 0.8)
	var alone := e1.max_hp - e1.hp
	var ratio := float(both) / maxf(float(alone), 1.0)
	print("  spread: %d com dois, %d sozinho (%.2f)" % [both, alone, ratio])
	check(ratio > 0.68 and ratio < 0.82, "spread: 0,75x com dois alvos (%.2f)" % ratio)
	# all_other_pokemon pega o parceiro perto.
	_heal_all(a)
	a.ally.position = Vector3(-1.0, 0, 2.3)
	user.position = Vector3(0, 0, 2)
	a.moves.deliver(user, mv)
	_run(a, 0.8)
	check(a.ally.hp < a.ally.max_hp, "Earthquake acerta o parceiro perto (all_other_pokemon)")
	# Razor Leaf (all_opponents, projétil): uma leva para cada.
	_heal_all(a)
	a.ally.position = Vector3(6, 0, 3)
	user.position = Vector3(0, 0, 3)
	e1.position = Vector3(-1.5, 0, -1)
	e2.position = Vector3(1.5, 0, -1)
	a.moves.deliver(user, Dex.move("swift"))
	_run(a, 1.5)
	check(e1.hp < e1.max_hp and e2.hp < e2.max_hp, "Swift acerta os dois")
	a.free()


func _single_target() -> void:
	var a := _duo(["mankey", "squirtle"], ["rattata", "rattata"])
	var user: BattleFighter = a.player
	var e1: BattleFighter = a.enemy
	var e2: BattleFighter = a.enemy2
	a.ally.position = Vector3(6, 0, 4)
	for id in ["scratch", "hyper_beam", "karate_chop"]:
		_heal_all(a)
		user.position = Vector3(0, 0, 1.2)
		e1.position = Vector3(-0.35, 0, 0)
		e2.position = Vector3(0.45, 0, 0.1)
		user.opponent = e1
		user.facing = Vector3(0, 0, -1)
		user.move_cd.clear()
		a.moves.deliver(user, Dex.move(id))
		_run(a, 1.4)
		var n := int(e1.hp < e1.max_hp) + int(e2.hp < e2.max_hp)
		check(n == 1, "%s (alvo único) acerta só um na dupla (%d)" % [id, n])
	# Multi-hit de alvo único fica no mesmo alvo.
	_heal_all(a)
	user.position = Vector3(0, 0, 1.0)
	e1.position = Vector3(-0.3, 0, 0)
	e2.position = Vector3(0.3, 0, 0)
	a.moves.deliver(user, Dex.move("double_kick"))
	_run(a, 1.0)
	var n2 := int(e1.hp < e1.max_hp) + int(e2.hp < e2.max_hp)
	check(n2 == 1, "Double Kick fica num alvo só (%d)" % n2)
	a.free()


func _same_damage() -> void:
	var dmg := []
	var p := [_mon("mankey", 30), _mon("squirtle", 30)]
	var e := [_mon("rattata", 30), _mon("rattata", 30)]
	for doubles in [false, true]:
		for m in p + e:
			m.hp = m.max_hp
		var opts := {
			"kind": "trainer", "battle_size": 2 if doubles else 1, "seed": 4, "default_pace": true
		}
		var a := _arena(p, e, opts)
		check(a.doubles == doubles, "modo %s" % ("2x2" if doubles else "1x1"))
		var user: BattleFighter = a.player
		var t: BattleFighter = a.enemy
		for f in a.fighters:
			if f != user and f != t:
				f.position = Vector3(7, 0, 5)
		user.position = Vector3(0, 0, 1.0)
		t.position = Vector3(0, 0, 0)
		user.opponent = t
		_heal_all(a)
		a.rng.seed = 999
		a.moves.deliver(user, Dex.move("karate_chop"))
		_run(a, 0.6)
		dmg.append(t.max_hp - t.hp)
		a.free()
	print("  dano 1x1 %d, 2x2 %d" % dmg)
	check(dmg[0] > 0 and dmg[0] == dmg[1], "mesmo dano no 1x1 e no 2x2 (%d / %d)" % dmg)


# --- Física ---


func _knock_eff() -> void:
	var k_super := BattlePhysics.knock_mult(2.0, false)
	var k_norm := BattlePhysics.knock_mult(1.0, false)
	var k_weak := BattlePhysics.knock_mult(0.5, false)
	check(k_super > k_norm and k_norm > k_weak, "empurrão: super > normal > pouco efetivo")
	check(BattlePhysics.knock_mult(1.0, true) > k_norm, "crítico empurra mais")
	check(BattlePhysics.knock_mult(1.0, false, 200.0) < k_norm, "pesado é empurrado menos")
	# No campo: Iron Tail (Aço, contato forte) arremessa mais o Pedra (superefetivo) que o Normal,
	# e o Água (pouco efetivo) menos.
	var moved := {}
	for sp in ["geodude", "rattata", "squirtle"]:
		var a := _arena([_mon("onix", 40)], [_mon(sp, 40)], {"seed": 3})
		var user: BattleFighter = a.player
		var t: BattleFighter = a.enemy
		var phys: BattlePhysics = a.moves.phys
		var mv := Dex.move("iron_tail")
		var eff := Dex.effectiveness("steel", t.types)
		moved[sp] = (
			phys.launch_dist(mv, eff, false, t, true)
			/ BattlePhysics.knock_mult(1.0, false, BattlePhysics.weight_of(t))
		)
		user.position = Vector3(0, 0, 1.0)
		t.position = Vector3(0, 0, 0)
		user.opponent = t
		t.hp = t.max_hp
		var z0 := t.position.z
		a.moves.hit(user, t, mv, Vector3(0, 0, -1))
		_run(a, 1.0)
		if sp == "geodude":
			check(
				z0 - t.position.z > 1.0,
				"Iron Tail superefetivo arremessa (%.2f m)" % (z0 - t.position.z)
			)
		a.free()
	check(
		moved["geodude"] > moved["rattata"] and moved["rattata"] > moved["squirtle"],
		"arremesso pela eficácia (%s)" % [moved]
	)


func _push_and_crash() -> void:
	var a := _arena([_mon("pidgey", 30)], [_mon("rattata", 30)], {"seed": 11})
	var user: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	user.position = Vector3(0, 0, 1)
	t.position = Vector3(0, 0, 0)
	user.opponent = t
	a.moves.deliver(user, Dex.move("whirlwind"))
	_run(a, 1.0)
	check(t.position.z < -2.5, "Whirlwind arremessa o alvo longe (%.2f)" % t.position.z)
	# Perto da cerca: bate e perde um pouco de HP.
	var r: Rect2 = a.rect
	t.position = Vector3(r.end.x - 1.0, 0, 0)
	t.hp = t.max_hp
	t.stun_t = 0.0
	a.moves.phys.launch(t, Vector3(1, 0, 0), 4.0, true)
	_run(a, 1.0)
	var lost := t.max_hp - t.hp
	check(
		lost > 0 and lost <= int(t.max_hp * 0.1) + 1, "bateu na cerca e perdeu um pouco (%d)" % lost
	)
	check(t.position.x <= r.end.x - 0.4, "não atravessa a cerca")
	a.free()
	# Caixa no campo.
	var b := _arena(
		[_mon("pidgey", 30)], [_mon("rattata", 30)], {"seed": 12, "field_objects": true}
	)
	var tb: BattleFighter = b.enemy
	if not b.field.objects.is_empty():
		var o: Dictionary = b.field.objects[0]
		var inward: Vector3 = (-o.pos).normalized()
		tb.position = o.pos + inward * 2.0
		tb.hp = tb.max_hp
		var hp_obj := int(o.hp)
		b.moves.phys.launch(tb, -inward, 4.0)
		_run(b, 1.0)
		check(tb.hp < tb.max_hp, "bateu na caixa/pedra e sofreu")
		check(not o in b.field.objects or int(o.hp) < hp_obj, "a caixa/pedra levou o tranco")
	b.free()


func _leap() -> void:
	var a := _arena([_mon("rattata", 30)], [_mon("rattata", 30)], {"seed": 13})
	var user: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	user.position = Vector3(0, 0, 3)
	t.position = Vector3(0, 0, 0)
	user.opponent = t
	t.hp = t.max_hp
	a.moves.deliver(user, Dex.move("body_slam"))
	var top := 0.0
	for i in 15:
		a.step(DT)
		top = maxf(top, user.position.y)
	check(user.motion == "leap" or top > 0.5, "Body Slam pula")
	check(top > 0.6, "Body Slam sobe (%.2f m)" % top)
	_run(a, 1.0)
	check(t.hp < t.max_hp, "Body Slam acerta no pouso")
	check(user.motion == "" and user.position.y < 0.05, "Body Slam volta ao chão")
	a.free()
	# Earthquake com "slam": pula no lugar.
	var b := _arena([_mon("sandshrew", 30)], [_mon("rattata", 30)], {"seed": 14})
	b.player.opponent = b.enemy
	b.moves.deliver(b.player, Dex.move("earthquake"))
	var top2 := 0.0
	for i in 20:
		b.step(DT)
		top2 = maxf(top2, b.player.position.y)
	check(top2 > 0.4, "Earthquake pula antes do tremor (%.2f m)" % top2)
	b.free()


func _blink() -> void:
	var a := _arena([_mon("pidgey", 30)], [_mon("rattata", 30)], {"seed": 15})
	var user: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	user.position = Vector3(0, 0, 5)
	t.position = Vector3(0, 0, 0)
	user.opponent = t
	t.hp = t.max_hp
	a.moves.deliver(user, Dex.move("aerial_ace"))
	a.step(DT)
	check(user.hidden == "blink", "Aerial Ace some")
	_run(a, 0.8)
	check(user.flat_to(t).length() < 2.0, "Aerial Ace reaparece junto do alvo")
	check(t.hp < t.max_hp, "Aerial Ace acerta")
	check(user.look == null or user.look.visible, "sprite volta")
	a.free()


func _dig() -> void:
	var a := _arena([_mon("sandshrew", 30)], [_mon("rattata", 30)], {"seed": 16})
	var user: BattleFighter = a.player
	var t: BattleFighter = a.enemy
	user.position = Vector3(0, 0, 4)
	t.position = Vector3(0, 0, 0)
	user.opponent = t
	t.hp = t.max_hp
	user.hp = user.max_hp
	a.moves.deliver(user, Dex.move("dig"))
	_run(a, 0.35)
	check(user.hidden == "dig", "Dig: entrou na terra")
	check(user.look == null or not user.look.visible, "Dig: sprite some")
	var hp0 := user.hp
	a.moves.hit(t, user, Dex.move("tackle"), Vector3(0, 0, 1))
	check(user.hp == hp0, "Dig: invulnerável a Tackle")
	var eq := Dex.move("earthquake")
	check(a.moves.phys.hidden_power(eq, user) == 2.0, "Dig: Earthquake alcança com 2x")
	var path_ok := true
	var z0 := user.position.z
	for i in 30:
		a.step(DT)
		if user.hidden == "dig" and user.position.z > z0 + 0.01:
			path_ok = false
	check(path_ok and user.position.z < z0, "Dig: anda por baixo até o alvo")
	_run(a, 1.5)
	check(user.hidden == "", "Dig: saiu da terra")
	check(user.look == null or user.look.visible, "Dig: sprite volta")
	check(t.hp < t.max_hp, "Dig: acerta ao sair embaixo do alvo")
	check(a.field.terrain_at(t.position) == "hole" or a.field.marks.size() > 0, "Dig: deixa buraco")
	a.free()


func _ai() -> void:
	var a := _duo(["geodude", "squirtle"], ["rattata", "rattata"], 45)
	var user: BattleFighter = a.player
	var e1: BattleFighter = a.enemy
	var e2: BattleFighter = a.enemy2
	user.moves = ["rock_slide", "rock_throw"]
	a.ally.position = Vector3(7, 0, 4)
	user.position = Vector3(0, 0, 4)
	e1.position = Vector3(-0.5, 0, 0)
	e2.position = Vector3(0.6, 0, 0)
	user.opponent = e1
	for f in [e1, e2]:
		f.max_hp = 999
		f.hp = 999
	var picks := {}
	for i in 20:
		var id: String = user.ai.pick(["rock_slide", "rock_throw"])
		picks[id] = int(picks.get(id, 0)) + 1
	check(int(picks.get("rock_slide", 0)) >= 15, "IA prefere área com os dois perto (%s)" % [picks])
	var single: float = a.moves.expected_damage(user, e1, Dex.move("rock_throw"))
	var area_one: float = a.moves.expected_damage(user, e1, Dex.move("rock_slide"))
	var area_raw: float = a.moves.expected_damage(user, e1, Dex.move("rock_slide"), false)
	check(area_one < area_raw, "IA conta o 0,75x no alvo do golpe de área")
	check(single > 0.0, "golpe de alvo único conta um alvo")
	# Investida longa para fechar distância.
	user.moves = ["quick_attack", "scratch"]
	e2.position = Vector3(8, 0, -4)
	user.position = Vector3(0, 0, 7.5)
	e1.position = Vector3(0, 0, 0)
	user.move_cd.clear()
	user.gcd_t = 0.0
	var got := false
	for i in 10:
		if user.ai._rush_move(7.5) == "quick_attack":
			got = true
	check(got, "IA usa a investida longa de longe")
	check(user.ai._rush_move(1.5) == "", "de perto não precisa")
	a.free()
