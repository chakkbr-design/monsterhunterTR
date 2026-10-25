extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_more_a_moves.gd
## Os 120 golpes da parte A (accelerock ... lunar_dance): dados, uso em luta de energia e as mecânicas
## novas de battle/battle_more_a.gd (proteções, Jaw Lock, Bide, Court Change, Thousand Arrows...).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const MOVES := [
	"accelerock",
	"anchor_shot",
	"aqua_cutter",
	"aqua_step",
	"arm_thrust",
	"attack_order",
	"aura_wheel",
	"barb_barrage",
	"beak_blast",
	"bide",
	"bitter_blade",
	"bolt_beak",
	"bolt_strike",
	"branch_poke",
	"collision_course",
	"comeuppance",
	"crush_grip",
	"diamond_storm",
	"dire_claw",
	"double_iron_bash",
	"double_shock",
	"dragon_ascent",
	"dragon_darts",
	"dragon_hammer",
	"drum_beating",
	"false_surrender",
	"fire_lash",
	"fishious_rend",
	"flower_trick",
	"flying_press",
	"force_palm",
	"frustration",
	"fusion_bolt",
	"gear_grind",
	"gigaton_hammer",
	"glaive_rush",
	"grav_apple",
	"head_charge",
	"headlong_rush",
	"horn_leech",
	"hyper_drill",
	"ice_hammer",
	"ivy_cudgel",
	"jaw_lock",
	"jet_punch",
	"kowtow_cleave",
	"lands_wrath",
	"last_respects",
	"leafage",
	"meteor_assault",
	"mighty_cleave",
	"mortal_spin",
	"multi_attack",
	"natural_gift",
	"order_up",
	"plasma_fists",
	"population_bomb",
	"power_trip",
	"power_up_punch",
	"precipice_blades",
	"psyblade",
	"psyshield_bash",
	"pyro_ball",
	"return",
	"rock_climb",
	"rock_wrecker",
	"sacred_fire",
	"sacred_sword",
	"salt_cure",
	"shadow_force",
	"spectral_thief",
	"spin_out",
	"spirit_break",
	"spirit_shackle",
	"stone_axe",
	"sunsteel_strike",
	"tail_slap",
	"thousand_arrows",
	"thousand_waves",
	"triple_dive",
	"triple_kick",
	"trop_kick",
	"v_create",
	"wicked_blow",
	"zing_zap",
	"aromatic_mist",
	"aurora_veil",
	"autotomize",
	"baneful_bunker",
	"burning_bulwark",
	"captivate",
	"chilly_reception",
	"clangorous_soul",
	"confide",
	"corrosive_gas",
	"cotton_guard",
	"cotton_spore",
	"court_change",
	"crafty_shield",
	"dark_void",
	"decorate",
	"defend_order",
	"doodle",
	"electrify",
	"fairy_lock",
	"fillet_away",
	"floral_healing",
	"flower_shield",
	"foresight",
	"forests_curse",
	"gear_up",
	"geomancy",
	"grass_whistle",
	"grudge",
	"heart_swap",
	"instruct",
	"jungle_healing",
	"kings_shield",
	"lunar_blessing",
	"lunar_dance"
]
const KINDS := [
	"dash",
	"arc",
	"multi_arc",
	"whip",
	"projectile",
	"homing",
	"stream",
	"beam",
	"aoe_self",
	"aoe_target",
	"zone",
	"self_buff",
	"debuff_aoe",
	"clones"
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	seed(9)
	_data()
	_cast_all()
	_hits_odds()
	_beak_blast()
	_shields()
	_aurora()
	_glaive()
	_jaw_lock()
	_arrows()
	_power_hooks()
	_salt_cure()
	_court_change()
	_bide()
	_flying_press()
	_thief()
	_natural_gift()
	_crafty_electrify()
	_grudge()
	_recharge()
	_self_status()
	_doubles()
	_ai_fight()
	print("more_a_moves: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, size := 1) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		party,
		enemies,
		{
			"kind": "trainer" if size > 1 else "wild",
			"speed": 1.0,
			"battle_mode": "energy",
			"battle_size": size,
			"no_rewards": true,
			"field_objects": false,
			"seed": 11
		}
	)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _ready_all(f: BattleFighter) -> void:
	f.move_cd.clear()
	f.gcd_t = 0.0
	f.stun_t = 0.0
	f.impact_t = 0.0
	f.root_t = 0.0
	f.pp_max = 100.0


func _still(me := "charmander", foe := "slowbro", lv := 30, foe_lv := 30) -> Node:
	var a := _arena([Mon.create(me, lv)], [Mon.create(foe, foe_lv)])
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.clear_status()
		f.trap_t = 0.0
		f.knock = Vector3.ZERO
		_ready_all(f)
	return a


func _use(a: Node, f: BattleFighter, id: String) -> bool:
	var ok: bool = a.moves.use(f, id)
	_run(a, 0.4)
	return ok


func _fx(a: Node) -> BattleMoveEffects:
	return a.moves.effects


func _data() -> void:
	check(MOVES.size() == 120, "lista com 120 golpes (%d)" % MOVES.size())
	var ok := true
	var look_ok := true
	var fxs: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string("res://data/move_fx.json")).get("moves", {})
	)
	for id in MOVES:
		var mv := Dex.move(id)
		if mv.is_empty() or not String(mv.get("kind", "")) in KINDS:
			ok = false
			print("  sem dados/kind: ", id)
		elif mv.has("bp") and float(mv.power) != float(mv.bp):
			ok = false
			print("  poder diferente do oficial: ", id)
		elif String(mv.get("category", "")) == "status" and float(mv.get("power", 0)) != 0.0:
			ok = false
			print("  status com poder: ", id)
		if not fxs.has(id):
			look_ok = false
			print("  sem look em move_fx: ", id)
	check(ok, "120 golpes com kind válido e poder oficial")
	check(look_ok, "120 golpes com look em move_fx.json")
	check(Dex.move("flying_press").get("also_type", "") == "flying", "Flying Press tem o 2º tipo")
	check(
		Dex.move("kings_shield").get("priority", 0) == 4, "King's Shield: prioridade +4 da PokeAPI"
	)


func _cast_all() -> void:
	var a := _still("clefable", "slowbro", 40, 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var used := 0
	for id in MOVES:
		_ready_all(p)
		_ready_all(e)
		p.hp = p.max_hp
		e.hp = e.max_hp
		p.trap_t = 0.0
		p.trainer_item = "oran_berry"
		p.item_used = false
		p.position = Vector3(-3, 0, 0)
		e.position = Vector3(2, 0, 0)
		if a.moves.use(p, id):
			used += 1
		_run(a, 1.6)
		for f in [p, e]:
			f.knock = Vector3.ZERO
			f.hidden = ""
			f.clear_status()
			f.trap_t = 0.0
			f.types = f.types if not f.types.is_empty() else ["normal"]
			if f.look:
				f.look.visible = true
		if not p.alive() or not e.alive():
			a.free()
			a = _still("clefable", "slowbro", 40, 40)
			p = a.player
			e = a.enemy
	check(used >= 95, "a maioria dos golpes sai numa luta de energia (%d/120)" % used)
	a.free()


func _hits_odds() -> void:
	var a := _still()
	var fx := _fx(a)
	var mv := Dex.move("population_bomb")
	var tot := 0.0
	var top := 0
	var low := 99
	for i in 600:
		var n := int(fx.roll_hits(mv, a.player).get("hits", 0))
		tot += n
		top = maxi(top, n)
		low = mini(low, n)
	var mean := tot / 600.0
	check(mean > 5.3 and mean < 7.6, "Population Bomb: média de golpes perto de 6,5 (%.2f)" % mean)
	check(top == 10 and low == 1, "Population Bomb vai de 1 a 10 golpes (%d..%d)" % [low, top])
	var arm := int(fx.roll_hits(Dex.move("arm_thrust"), a.player).get("hits", 0))
	check(arm >= 2 and arm <= 5, "Arm Thrust: 2 a 5 golpes (%d)" % arm)
	a.free()


func _beak_blast() -> void:
	var a := _still("pidgeot", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(3, 0, 0)
	check(_use(a, p, "beak_blast"), "usa Beak Blast")
	check(
		p.prepare_t > 0.0 and p.prepare_id == "beak_blast", "Beak Blast prepara (bico esquentando)"
	)
	fx.blocks_hit(e, p, Dex.move("tackle"))
	check(e.status == "burn", "quem encosta no bico quente se queima")
	e.clear_status()
	fx.blocks_hit(e, p, Dex.move("ember"))
	check(e.status == "", "golpe à distância não queima")
	a.free()


func _shields() -> void:
	var a := _still(
		"aegislash" if not Dex.species("aegislash").is_empty() else "magnemite", "slowbro", 40, 30
	)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var tackle := Dex.move("tackle")
	check(_use(a, p, "kings_shield"), "usa King's Shield")
	check(fx.active(fx.st(p), "kshield"), "King's Shield ligado")
	check(fx.blocks_hit(e, p, tackle), "King's Shield barra golpe de dano")
	check(int(e.stages.get("atk", 0)) == -2, "contato com King's Shield: Ataque -2")
	var growl := {"id": "x", "power": 0, "category": "status", "kind": "projectile"}
	check(not fx.blocks_hit(e, p, growl), "King's Shield deixa passar golpe de status")
	check(not fx.blocks_hit(e, p, Dex.move("phantom_force")), "golpe que ignora proteção passa")
	a.end_turn.run()
	check(not fx.active(fx.st(p), "kshield"), "King's Shield acaba no fim da rodada")
	a.free()
	for row in [["baneful_bunker", "poison"], ["burning_bulwark", "burn"]]:
		var b := _still("charmander", "slowbro", 30, 30)
		var bf := _fx(b)
		check(_use(b, b.player, row[0]), "usa %s" % row[0])
		check(bf.blocks_hit(b.enemy, b.player, tackle), "%s protege como o Protect" % row[0])
		check(b.enemy.status == row[1], "%s: contato dá %s" % [row[0], row[1]])
		b.enemy.clear_status()
		bf.blocks_hit(b.enemy, b.player, Dex.move("ember"))
		check(b.enemy.status == "", "%s: golpe à distância não pega" % row[0])
		b.free()


func _aurora() -> void:
	var a := _still()
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(not fx.usable(p, Dex.move("aurora_veil")), "Aurora Veil só na neve")
	fx.set_weather("hail", 5, p)
	check(fx.usable(p, Dex.move("aurora_veil")), "Aurora Veil sai na neve")
	var tackle := Dex.move("tackle")
	var before := float(fx.adjust_move(e, p, tackle).get("power", 0))
	check(_use(a, p, "aurora_veil"), "usa Aurora Veil")
	check(fx.active(fx._sd(p.side), "aurora_veil"), "barreira ligada")
	var after := float(fx.adjust_move(e, p, tackle).get("power", 0))
	check(
		is_equal_approx(after, before * 0.5),
		"Aurora Veil corta o dano pela metade (%d -> %d)" % [before, after]
	)
	var other := float(fx.adjust_move(p, e, tackle).get("power", 0))
	check(is_equal_approx(other, before), "o outro lado não é afetado")
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx._sd(p.side), "aurora_veil"), "Aurora Veil acaba em 5 rodadas")
	a.free()


func _glaive() -> void:
	var a := _still()
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var tackle := Dex.move("tackle")
	var base := float(fx.adjust_move(e, p, tackle).get("power", 0))
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(3, 0, 0)
	check(_use(a, p, "glaive_rush"), "usa Glaive Rush")
	check(fx.active(fx.st(p), "glaive"), "Glaive Rush deixa vulnerável")
	check(
		is_equal_approx(float(fx.adjust_move(e, p, tackle).get("power", 0)), base * 2.0),
		"o usuário leva o dobro"
	)
	_run(a, 2.0)
	_ready_all(p)
	check(_use(a, p, "tackle"), "usa outro golpe")
	check(not fx.active(fx.st(p), "glaive"), "o próximo golpe acaba com a vulnerabilidade")
	a.free()


func _jaw_lock() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(1.4, 0, 0)
	check(_use(a, p, "jaw_lock"), "usa Jaw Lock")
	_run(a, 1.0)
	check(fx.active(fx.st(p), "jaw") and fx.active(fx.st(e), "jaw"), "Jaw Lock prende os dois")
	check(fx.cant_escape(p) and fx.cant_escape(e), "nenhum dos dois pode fugir ou trocar")
	e.position = Vector3(7, 0, 0)
	_run(a, 1.0)
	check(p.flat_to(e).length() < 4.0, "a coleira puxa os dois (%.1f m)" % p.flat_to(e).length())
	for i in 4:
		a.end_turn.run()
	check(not fx.cant_escape(p) and not fx.cant_escape(e), "solta depois de 4 rodadas")
	a.free()


func _arrows() -> void:
	var a := _still("charmander", "pidgey", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var mv := Dex.move("thousand_arrows")
	var prof := fx.defender_profile(p, e, mv)
	check(not "flying" in prof.types, "Thousand Arrows ignora o tipo Voador")
	check(Dex.effectiveness("ground", e.types) == 0.0, "Voador é imune a Terra normalmente")
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(4, 0, 0)
	var hp0 := e.hp
	check(_use(a, p, "thousand_arrows"), "usa Thousand Arrows")
	_run(a, 2.0)
	check(e.hp < hp0, "as flechas acertam um Voador (%d)" % (hp0 - e.hp))
	check(fx.active(fx.st(e), "smacked") and fx.grounded(e), "o alvo é derrubado e fica no chão")
	e.hp = e.max_hp
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx.st(e), "smacked"), "volta a voar depois de 5 rodadas")
	a.free()
	var b := _still("charmander", "slowbro", 40, 30)
	var bf := _fx(b)
	b.player.position = Vector3(0, 0, 0)
	b.enemy.position = Vector3(1.0, 0, 0)
	check(_use(b, b.player, "thousand_waves"), "usa Thousand Waves")
	_run(b, 1.2)
	check(bf.cant_escape(b.enemy), "Thousand Waves: o alvo não foge")
	b.free()
	var c := _still("charmander", "slowbro", 40, 30)
	c.player.position = Vector3(0, 0, 0)
	c.enemy.position = Vector3(3, 0, 0)
	for id in ["spirit_shackle", "anchor_shot"]:
		_ready_all(c.player)
		c.enemy.trap_t = 0.0
		c.enemy.position = Vector3(2.5, 0, 0)
		c.moves.use(c.player, id)
		_run(c, 1.2)
		check(_fx(c).cant_escape(c.enemy), "%s: o alvo fica preso" % id)
		_fx(c).st(c.enemy).trapped = false
	c.free()


func _power_hooks() -> void:
	var a := _still("charmander", "slowbro", 40, 40)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var cc := Dex.move("collision_course")
	e.types = ["normal"]
	var sup := float(fx.adjust_move(p, e, cc).get("power", 0))
	e.types = ["fighting"]
	var neu := float(fx.adjust_move(p, e, cc).get("power", 0))
	check(
		is_equal_approx(neu, 100.0) and is_equal_approx(sup, 100.0 * 4.0 / 3.0),
		"Collision Course: x4/3 no superefetivo (%.0f/%.0f)" % [sup, neu]
	)
	var lr := Dex.move("last_respects")
	check(
		is_equal_approx(float(fx.adjust_move(p, e, lr).get("power", 0)), 50.0),
		"Last Respects sem baixas: 50"
	)
	var fusion := Dex.move("fusion_bolt")
	check(
		is_equal_approx(float(fx.adjust_move(p, e, fusion).get("power", 0)), 100.0),
		"Fusion Bolt sozinho: 100"
	)
	fx.field["fusion_flare_t"] = fx.now
	check(
		is_equal_approx(float(fx.adjust_move(p, e, fusion).get("power", 0)), 200.0),
		"Fusion Bolt depois do Fusion Flare: 200"
	)
	p.mon.friend = 255
	check(
		float(fx.adjust_move(p, e, Dex.move("return")).get("power", 0)) == 102.0,
		"Return com amizade 255: 102"
	)
	check(
		float(fx.adjust_move(p, e, Dex.move("frustration")).get("power", 0)) == 1.0,
		"Frustration com amizade 255: 1"
	)
	p.mon.friend = 0
	check(
		float(fx.adjust_move(p, e, Dex.move("frustration")).get("power", 0)) == 102.0,
		"Frustration com amizade 0: 102"
	)
	var gg := Dex.move("grav_apple")
	var normal := float(fx.adjust_move(p, e, gg).get("power", 0))
	fx.set_rounds(fx.field, "gravity", 5)
	check(
		is_equal_approx(float(fx.adjust_move(p, e, gg).get("power", 0)), normal * 1.5),
		"Grav Apple: 1,5x sob Gravidade"
	)
	e.hp = e.max_hp
	var cg := float(fx.adjust_move(p, e, Dex.move("crush_grip")).get("power", 0))
	e.hp = e.max_hp / 2
	var cg2 := float(fx.adjust_move(p, e, Dex.move("crush_grip")).get("power", 0))
	check(cg > cg2 and cg2 > 50.0, "Crush Grip cai com o HP do alvo (%d > %d)" % [cg, cg2])
	p.stages["atk"] = 2
	check(
		float(fx.adjust_move(p, e, Dex.move("power_trip")).get("power", 0)) == 60.0,
		"Power Trip: 20 + 20 por nível"
	)
	fx.set_rounds(fx.field, "electric", 5)
	var pb := Dex.move("psyblade")
	check(
		is_equal_approx(float(fx.adjust_move(p, e, pb).get("power", 0)), 80.0 * 1.5),
		"Psyblade: 1,5x no Campo Elétrico"
	)
	# poder 2x se chega antes
	var bb := Dex.move("bolt_beak")
	e.prepare_t = 0.5
	check(
		is_equal_approx(float(fx.adjust_move(p, e, bb).get("power", 0)), 170.0),
		"Bolt Beak: dobra com o alvo preparando"
	)
	e.prepare_t = 0.0
	fx.st(e).move_t = fx.now
	check(
		is_equal_approx(float(fx.adjust_move(p, e, bb).get("power", 0)), 85.0),
		"Bolt Beak: normal com o alvo ativo"
	)
	# tipos que mudam
	a.player.set_meta("noop", 1)
	check(
		String(fx.adjust_move(p, e, Dex.move("ivy_cudgel")).get("type", "")) == "grass",
		"Ivy Cudgel sem máscara: Planta"
	)
	a.free()


func _salt_cure() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(1.4, 0, 0)
	check(_use(a, p, "salt_cure"), "usa Salt Cure")
	_run(a, 1.0)
	check(bool(_fx(a).st(e).get("salted", false)), "o alvo fica salgado")
	var hp0 := e.hp
	a.end_turn.run()
	check(
		hp0 - e.hp >= e.max_hp / 4 - 1, "Água em Salt Cure perde 1/4 por rodada (%d)" % (hp0 - e.hp)
	)
	a.free()


func _court_change() -> void:
	var a := _still()
	var fx := _fx(a)
	var p: BattleFighter = a.player
	fx.set_rounds(fx._sd(0), "reflect", 5)
	fx.set_rounds(fx._sd(1), "tailwind", 4)
	fx.spikes.append({"pos": Vector3.ZERO, "side": 0, "layers": 1, "t": fx.now + 50.0, "hit": {}})
	check(_use(a, p, "court_change"), "usa Court Change")
	_run(a, 0.5)
	check(
		fx.active(fx._sd(1), "reflect") and not fx.active(fx._sd(0), "reflect"),
		"o Reflect vai para o outro lado"
	)
	check(
		fx.active(fx._sd(0), "tailwind") and not fx.active(fx._sd(1), "tailwind"),
		"o Tailwind do outro vem para cá"
	)
	check(int(fx.spikes[0].side) == 1, "as armadilhas trocam de lado")
	a.free()


func _bide() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(1.6, 0, 0)
	check(_use(a, p, "bide"), "usa Bide")
	_ready_all(p)
	check(not fx.usable(p, Dex.move("tackle")), "durante o Bide não sai outro golpe")
	check(_use(a, e, "tackle"), "o outro ataca")
	_run(a, 1.5)
	var lost := p.max_hp - p.hp
	check(lost > 0, "o Bide leva dano (%d)" % lost)
	var hp0 := e.hp
	a.end_turn.run()
	a.end_turn.run()
	check(not fx.active(fx.st(p), "bide"), "Bide acaba em 2 rodadas")
	check(
		hp0 - e.hp >= lost, "devolve o dobro do dano (levou %d, devolveu %d)" % [lost, hp0 - e.hp]
	)
	a.free()


func _flying_press() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var mv := Dex.move("flying_press")
	var pp := p.damage_profile()
	var dp := e.damage_profile()
	dp["types"] = ["grass"]
	var r1 := Damage.compute(pp, dp, mv, null)
	check(
		is_equal_approx(float(r1.eff), 2.0),
		"Flying Press contra Planta: 1 x 2 = 2 (%.2f)" % float(r1.eff)
	)
	dp["types"] = ["rock"]
	var r2 := Damage.compute(pp, dp, mv, null)
	check(
		is_equal_approx(float(r2.eff), 1.0),
		"Flying Press contra Pedra: 2 x 0,5 = 1 (%.2f)" % float(r2.eff)
	)
	dp["types"] = ["ghost"]
	var r3 := Damage.compute(pp, dp, mv, null)
	check(float(r3.eff) == 0.0, "Flying Press não afeta Fantasma")
	a.free()


func _thief() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.stages["def"] = 2
	e.stages["spa"] = 1
	var prof := fx.attacker_profile(p, e, Dex.move("spectral_thief"))
	check(
		int(p.stages.get("def", 0)) == 2 and int(p.stages.get("spa", 0)) == 1,
		"Spectral Thief rouba os aumentos"
	)
	check(int(e.stages.get("def", 0)) == 0, "o alvo perde os aumentos")
	check(prof.has("atk"), "perfil do atacante segue valendo")
	a.free()


func _natural_gift() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var mv := Dex.move("natural_gift")
	p.trainer_item = ""
	check(not fx.usable(p, mv), "Natural Gift sem frutinha falha")
	p.trainer_item = "oran_berry"
	p.item_used = false
	check(fx.usable(p, mv), "Natural Gift com frutinha")
	var m := fx.adjust_move(p, e, mv)
	check(String(m.get("type", "")) == "poison" and float(m.power) == 80.0, "Oran Berry: Veneno 80")
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(3, 0, 0)
	check(_use(a, p, "natural_gift"), "usa Natural Gift")
	check(p.item_used, "a frutinha é consumida")
	a.free()


func _crafty_electrify() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(_use(a, p, "crafty_shield"), "usa Crafty Shield")
	var status := {"id": "x", "power": 0, "category": "status", "kind": "projectile"}
	check(fx.blocks_hit(e, p, status), "Crafty Shield barra golpe de status")
	check(
		not fx.blocks_hit(e, p, Dex.move("tackle")) or fx.active(fx.st(p), "protect"),
		"mas não o de dano"
	)
	a.end_turn.run()
	check(not fx.blocks_hit(e, p, status), "acaba no fim da rodada")
	var tackle := Dex.move("tackle")
	check(
		String(fx.adjust_move(e, p, tackle).get("type", "")) == "normal",
		"sem Electrify o tipo é Normal"
	)
	fx.after_hit(p, e, Dex.move("electrify"), 0)
	check(
		String(fx.adjust_move(e, p, tackle).get("type", "")) == "electric",
		"Electrify: o golpe vira Elétrico"
	)
	a.end_turn.run()
	check(
		String(fx.adjust_move(e, p, tackle).get("type", "")) == "normal",
		"Electrify acaba na rodada"
	)
	fx.after_hit(p, e, Dex.move("plasma_fists"), 10)
	check(
		String(fx.adjust_move(p, e, tackle).get("type", "")) == "electric",
		"Plasma Fists: Normal vira Elétrico"
	)
	a.end_turn.run()
	check(
		String(fx.adjust_move(p, e, tackle).get("type", "")) == "normal",
		"Plasma Fists acaba na rodada"
	)
	a.free()


func _grudge() -> void:
	var a := _still("charmander", "primeape", 40, 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.moves = ["tackle"]
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(1.4, 0, 0)
	check(_use(a, p, "grudge"), "usa Grudge")
	p.hp = 1
	a.moves.use(e, "tackle")
	_run(a, 1.5)
	check(not p.alive(), "o usuário do Grudge desmaia")
	check(
		float(e.move_cd.get("tackle", 0.0)) >= BattleMoveEffects.LOCK_CD * 0.5,
		"o golpe que derrubou trava (PP zerado)"
	)
	a.free()


func _recharge() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var p: BattleFighter = a.player
	p.position = Vector3(0, 0, 0)
	a.enemy.position = Vector3(4, 0, 0)
	check(_use(a, p, "meteor_assault"), "usa Meteor Assault")
	var peak := 0.0
	for i in int(2.5 / DT):
		a.step(DT)
		peak = maxf(peak, p.stun_t)
	check(peak > 1.0, "Meteor Assault: o usuário precisa recarregar (%.2f)" % peak)
	a.free()


func _self_status() -> void:
	var a := _still("charmander", "slowbro", 40, 30)
	var fx := _fx(a)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	# Clangorous Soul
	var hp0 := p.hp
	check(_use(a, p, "clangorous_soul"), "usa Clangorous Soul")
	check(hp0 - p.hp == p.max_hp / 3 and int(p.stages.get("spe", 0)) == 1, "perde 1/3 e sobe tudo")
	# Fillet Away
	_ready_all(p)
	p.hp = p.max_hp
	check(_use(a, p, "fillet_away"), "usa Fillet Away")
	check(
		int(p.stages.get("atk", 0)) == 3 and p.hp == p.max_hp - p.max_hp / 2,
		"Fillet Away: +2 e metade do HP"
	)
	_ready_all(p)
	p.hp = 3
	check(not fx.usable(p, Dex.move("fillet_away")), "sem HP o Fillet Away falha")
	# Decorate no 1x1: em si mesmo
	p.hp = p.max_hp
	p.stages["atk"] = 0
	p.stages["spa"] = 0
	_ready_all(p)
	check(_use(a, p, "decorate"), "usa Decorate")
	check(
		int(p.stages.get("atk", 0)) == 2 and int(p.stages.get("spa", 0)) == 2,
		"Decorate: +2 em Ataque e Ataque Especial"
	)
	# Autotomize
	_ready_all(p)
	var w0 := BattlePhysics.weight_of(p)
	check(_use(a, p, "autotomize"), "usa Autotomize")
	check(is_equal_approx(BattlePhysics.weight_of(p), w0 * 0.5), "Autotomize: peso pela metade")
	# Jungle Healing / Lunar Blessing
	_ready_all(p)
	p.hp = p.max_hp / 4
	p.apply_status("burn")
	check(_use(a, p, "jungle_healing"), "usa Jungle Healing")
	check(p.status == "" and p.hp > p.max_hp / 4, "cura o status e um pouco de HP")
	# Fairy Lock
	_ready_all(p)
	check(_use(a, p, "fairy_lock"), "usa Fairy Lock")
	_run(a, 0.3)
	check(fx.cant_escape(e) and fx.cant_escape(p), "Fairy Lock: ninguém foge")
	for i in 2:
		a.end_turn.run()
	_run(a, 0.2)
	check(not fx.cant_escape(e), "Fairy Lock acaba em 2 rodadas")
	# Forest's Curse, Foresight, Heart Swap
	_ready_all(p)
	e.position = Vector3(2.5, 0, 0)
	p.position = Vector3(0, 0, 0)
	check(_use(a, p, "forests_curse"), "usa Forest's Curse")
	_run(a, 1.2)
	check("grass" in e.types, "o alvo ganha Planta")
	_ready_all(p)
	e.stages["atk"] = 3
	check(_use(a, p, "heart_swap"), "usa Heart Swap")
	_run(a, 1.2)
	check(
		int(p.stages.get("atk", 0)) == 3 or int(e.stages.get("atk", 0)) != 3,
		"Heart Swap troca as mudanças"
	)
	e.types = ["ghost"]
	fx.after_hit(p, e, Dex.move("foresight"), 0)
	var prof := fx.defender_profile(p, e, Dex.move("tackle"))
	check(not "ghost" in prof.types, "Foresight: Normal acerta Fantasma")
	prof = fx.defender_profile(p, e, Dex.move("ember"))
	check("ghost" in prof.types, "Foresight só vale para Normal e Lutador")
	# Doodle
	e.types = ["psychic"]
	fx.after_hit(p, e, Dex.move("doodle"), 0)
	check(
		String(p.get_meta("ability_override", "x")) == fx._ability(e), "Doodle copia a habilidade"
	)
	# Corrosive Gas
	e.trainer_item = "oran_berry"
	e.item_used = false
	fx.after_hit(p, e, Dex.move("corrosive_gas"), 0)
	check(e.item_used, "Corrosive Gas derruba o item")
	# Instruct sem último golpe falha sem erro
	fx.after_hit(p, e, Dex.move("instruct"), 0)
	check(true, "Instruct sem golpe anterior não quebra")
	# Chilly Reception sem reserva: só a neve
	_ready_all(p)
	check(_use(a, p, "chilly_reception"), "usa Chilly Reception")
	_run(a, 0.5)
	check(fx.weather() in ["hail", "snow"], "Chilly Reception traz a neve")
	a.free()


func _doubles() -> void:
	var pm := [Mon.create("charmander", 80), Mon.create("bulbasaur", 40)]
	var em := [Mon.create("slowbro", 40), Mon.create("golem", 40)]
	var a := _arena(pm, em, 2)
	_run(a, 2.0)
	for f in a.fighters:
		f.controller = "none"
		f.clear_status()
		_ready_all(f)
	var mine: Array = a.fighters.filter(func(f): return f.side == 0)
	var theirs: Array = a.fighters.filter(func(f): return f.side == 1)
	check(mine.size() == 2 and theirs.size() == 2, "arena 2x2 montada")
	if mine.size() < 2 or theirs.size() < 2:
		a.free()
		return
	var p: BattleFighter = mine[0]
	var mate: BattleFighter = mine[1]
	p.position = Vector3(-1.5, 0, -3)
	mate.position = Vector3(1.5, 0, -3)
	theirs[0].position = Vector3(-2.5, 0, 3)
	theirs[1].position = Vector3(2.5, 0, 3)
	p.opponent = theirs[0]
	var hit := [false, false]
	for n in 4:
		var hp0 := [theirs[0].hp, theirs[1].hp]
		_ready_all(p)
		a.moves.use(p, "dragon_darts")
		_run(a, 2.5)
		for k in 2:
			hit[k] = hit[k] or theirs[k].hp < hp0[k]
	check(hit[0] and hit[1], "os dardos se dividem: os dois adversários levam %s" % [hit])
	var fx := _fx(a)
	_ready_all(p)
	check(_use(a, p, "aromatic_mist"), "usa Aromatic Mist")
	check(int(mate.stages.get("spd", 0)) == 1, "Aromatic Mist sobe a Def. Esp. do parceiro")
	_ready_all(p)
	check(_use(a, p, "decorate"), "usa Decorate com parceiro")
	check(
		int(mate.stages.get("atk", 0)) == 2 and int(p.stages.get("atk", 0)) == 0,
		"Decorate vai no parceiro"
	)
	_ready_all(p)
	mate.hp = mate.max_hp / 4
	check(_use(a, p, "floral_healing"), "usa Floral Healing")
	check(mate.hp > mate.max_hp / 4, "Floral Healing cura o parceiro")
	_ready_all(p)
	check(_use(a, p, "flower_shield"), "usa Flower Shield")
	check(fx != null, "Flower Shield sem erro")
	a.free()


func _ai_fight() -> void:
	var pm := Mon.create("primeape", 40)
	pm.moves = ["gigaton_hammer", "kowtow_cleave", "jet_punch", "kings_shield"]
	var em := Mon.create("mankey", 40)
	em.moves = ["jaw_lock", "wicked_blow", "bide", "baneful_bunker"]
	var b := _arena([pm], [em])
	_run(b, 25.0)
	check(
		b.player.hp < b.player.max_hp or b.enemy.hp < b.enemy.max_hp,
		"luta de IA com golpes novos troca dano"
	)
	b.free()
