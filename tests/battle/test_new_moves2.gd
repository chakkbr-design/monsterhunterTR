extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_new_moves2.gd
## Golpes que faltavam nos learnsets Gen 9 (waterfall ... icicle_crash) e as mecânicas de
## battle/battle_move_effects.gd.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
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
const NEW_MOVES := [
	"waterfall",
	"clear_smog",
	"explosion",
	"scald",
	"iron_head",
	"low_sweep",
	"block",
	"heavy_slam",
	"vacuum_wave",
	"soak",
	"dynamic_punch",
	"dive",
	"rock_polish",
	"magnet_rise",
	"bulk_up",
	"wonder_room",
	"power_gem",
	"trick_room",
	"brine",
	"hammer_arm",
	"slack_off",
	"psychic_terrain",
	"bounce",
	"hard_press",
	"lock_on",
	"zap_cannon",
	"steel_beam",
	"acid_armor",
	"destiny_bond",
	"recover",
	"ice_shard",
	"razor_shell",
	"rage_fist",
	"simple_beam",
	"stomp",
	"coaching",
	"circle_throw",
	"acupressure",
	"brutal_swing",
	"recycle",
	"magnetic_flux",
	"supercell_slam",
	"leaf_blade",
	"shadow_punch",
	"shadow_sneak",
	"double_hit",
	"ally_switch",
	"psycho_cut",
	"draco_meteor",
	"icicle_crash"
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	seed(9)
	_data()
	_powers()
	_stat_and_status_moves()
	_heals_and_items()
	_magnet_rise()
	_rooms_and_terrain()
	_destiny_bond()
	_lock_on_and_crash()
	_steel_beam()
	_explosion()
	print("new_moves2: %d checks, %d falhas" % [_count, _fails])
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
	opts["damage_pace"] = 1.0
	opts["field_objects"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _still(me := "charmander", foe := "slowbro", lv := 30, foe_lv := 40) -> Node:
	var a := _arena([Mon.create(me, lv)], [Mon.create(foe, foe_lv)], {"seed": 11})
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	for f in [a.player, a.enemy]:
		f.hp = f.max_hp
		f.clear_status()
		f.confusion_t = 0.0
		f.trap_t = 0.0
		f.evasion_t = 0.0
		for k in f.stages:
			f.stages[k] = 0
		f.knock = Vector3.ZERO
		_ready_all(f)
	return a


func _ready_all(f: BattleFighter) -> void:
	f.move_cd.clear()
	f.gcd_t = 0.0
	f.stun_t = 0.0
	f.impact_t = 0.0
	f.root_t = 0.0


func _data() -> void:
	var ok := true
	for id in NEW_MOVES:
		var mv := Dex.move(id)
		if mv.is_empty() or not String(mv.get("kind", "")) in KINDS:
			ok = false
			print("  golpe sem dados/kind: ", id)
		elif String(mv.get("category", "")) == "status" and float(mv.get("power", 0)) != 0.0:
			ok = false
			print("  status com poder: ", id)
		elif mv.has("bp") and float(mv.power) != float(mv.bp):
			ok = false
			print("  poder diferente do oficial: ", id)
	check(ok, "50 golpes com kind válido e poder oficial")
	check(NEW_MOVES.size() == 50, "lista com 50 golpes")
	var missing := []
	for sp in Dex.all_species():
		for e in Dex.species(sp).get("learnset", []):
			if Dex.move(String(e[1])).is_empty():
				missing.append(String(e[1]))
	check(missing.is_empty(), "learnsets só com golpes do jogo %s" % str(missing))
	var sb := Dex.species("Slowbro")
	check(
		"slack_off" in sb.tm or sb.learnset.any(func(e): return e[1] == "slack_off"),
		"Slowbro aprende Slack Off"
	)
	check(
		(
			int(Dex.move("double_hit").hits_range[0]) == 2
			and int(Dex.move("double_hit").hits_range[1]) == 2
			and Dex.move("double_hit").hits == 2
		),
		"Double Hit é multi-hit oficial 2"
	)
	check(not Dex.move("steel_beam").has("hits_range"), "Steel Beam sem multi-hit")
	check(int(Dex.move("ice_shard").priority) == 1, "Ice Shard prioridade +1")
	check(int(Dex.move("trick_room").priority) == -7, "Trick Room prioridade -7")
	check(int(Dex.move("circle_throw").priority) == -6, "Circle Throw prioridade -6")
	check(
		Dex.move("explosion").get("multi_target") == "all_other_pokemon", "Explosion acerta todos"
	)


func _powers() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var brine := Dex.move("brine")
	check(float(fx.adjust_move(p, e, brine).power) == 65.0, "Brine: 65 com o alvo inteiro")
	e.hp = e.max_hp / 2 - 1
	check(float(fx.adjust_move(p, e, brine).power) == 130.0, "Brine: dobra abaixo de metade do HP")
	e.hp = e.max_hp
	check(
		float(fx.adjust_move(p, e, Dex.move("hard_press")).power) == 100.0,
		"Hard Press: 100 com HP cheio"
	)
	e.hp = e.max_hp / 4
	var hp_pw := float(fx.adjust_move(p, e, Dex.move("hard_press")).power)
	check(hp_pw >= 24.0 and hp_pw <= 26.0, "Hard Press: ~25 com 1/4 do HP (%d)" % hp_pw)
	e.hp = e.max_hp
	var rf := Dex.move("rage_fist")
	check(float(fx.adjust_move(p, e, rf).power) == 50.0, "Rage Fist: 50 sem ter levado golpe")
	for i in 3:
		fx.after_hit(e, p, Dex.move("tackle"), 5)
	check(float(fx.adjust_move(p, e, rf).power) == 200.0, "Rage Fist: +50 por golpe levado (3)")
	for i in 12:
		fx.after_hit(e, p, Dex.move("tackle"), 5)
	check(float(fx.adjust_move(p, e, rf).power) == 350.0, "Rage Fist: teto 350")
	var hs := float(fx.adjust_move(e, p, Dex.move("heavy_slam")).power)
	check(hs >= 60.0, "Heavy Slam: o pesado (Slowbro) bate forte no leve (%d)" % hs)
	check(
		float(fx.adjust_move(p, e, Dex.move("heavy_slam")).power) == 40.0,
		"Heavy Slam: o leve bate fraco"
	)
	a.free()


func _stat_and_status_moves() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.stages["atk"] = 3
	e.stages["spe"] = -2
	check(a.moves.use(p, "clear_smog"), "usa Clear Smog")
	_run(a, 1.2)
	var zero := true
	for k in e.stages:
		zero = zero and int(e.stages[k]) == 0
	check(zero, "Clear Smog zera os estágios do alvo")
	_ready_all(p)
	check(a.moves.use(p, "soak"), "usa Soak")
	_run(a, 1.2)
	check(e.types == ["water"], "Soak deixa o alvo só Water %s" % str(e.types))
	_ready_all(p)
	check(a.moves.use(p, "simple_beam"), "usa Simple Beam")
	_run(a, 1.2)
	check(a.moves.effects._ability(e) == "simple", "Simple Beam: habilidade Simple")
	a.moves.change_stage(e, "atk", -1)
	check(int(e.stages.atk) == -2, "Simple dobra a mudança de estágio (-1 vira -2)")
	_ready_all(p)
	check(a.moves.use(p, "bulk_up"), "usa Bulk Up")
	_run(a, 0.3)
	check(int(p.stages.atk) == 1 and int(p.stages.def) == 1, "Bulk Up: Ataque e Defesa +1")
	_ready_all(p)
	check(a.moves.use(p, "rock_polish"), "Rock Polish")
	_run(a, 0.3)
	check(int(p.stages.spe) == 2, "Rock Polish: Speed +2")
	_ready_all(p)
	check(a.moves.use(p, "acid_armor"), "Acid Armor")
	_run(a, 0.3)
	check(int(p.stages.def) == 3, "Acid Armor: Defesa +2")
	_ready_all(p)
	var before := 0
	for k in p.stages:
		before += int(p.stages[k])
	check(a.moves.use(p, "acupressure"), "Acupressure")
	_run(a, 0.3)
	var up := 0
	for k in p.stages:
		up += int(p.stages[k])
	check(up == before + 2, "Acupressure sobe um atributo em 2 (%d -> %d)" % [before, up])
	# Coaching e Ally Switch precisam do parceiro: sem ele falham sem estragar nada
	_ready_all(p)
	var pos := p.position
	check(a.moves.use(p, "ally_switch"), "Ally Switch sai")
	_run(a, 0.3)
	check(p.position.distance_to(pos) < 1.0, "Ally Switch sem parceiro não move")
	_ready_all(p)
	check(a.moves.use(p, "coaching"), "Coaching sai")
	_run(a, 0.3)
	_ready_all(p)
	check(a.moves.use(p, "magnetic_flux"), "Magnetic Flux sai")
	_run(a, 0.3)
	check(int(p.stages.spd) == 0, "Magnetic Flux sem Plus/Minus falha")
	a.free()


func _heals_and_items() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	p.hp = 10
	check(a.moves.use(p, "recover"), "Recover")
	_run(a, 0.3)
	check(
		p.hp >= 10 + p.max_hp / 2 - 1, "Recover cura metade do HP máx. (%d/%d)" % [p.hp, p.max_hp]
	)
	p.hp = 10
	_ready_all(p)
	check(a.moves.use(p, "slack_off"), "Slack Off")
	_run(a, 0.3)
	check(p.hp >= 10 + p.max_hp / 2 - 1, "Slack Off cura metade do HP máx.")
	p.trainer_item = "oran_berry"
	p.item_used = true
	_ready_all(p)
	check(a.moves.use(p, "recycle"), "Recycle")
	_run(a, 0.3)
	check(not p.item_used, "Recycle devolve o item usado")
	a.free()


func _magnet_rise() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(a.moves.use(p, "magnet_rise"), "Magnet Rise")
	_run(a, 0.3)
	check(fx.active(fx.st(p), "magnet"), "Magnet Rise liga")
	check(not fx.grounded(p), "levitando não pisa no chão")
	check(fx.blocks_hit(e, p, Dex.move("earthquake")), "golpe de Terra não pega quem levita")
	check(not fx.blocks_hit(e, p, Dex.move("tackle")), "outros golpes pegam")
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx.st(p), "magnet"), "Magnet Rise acaba em 5 turnos")
	a.free()


func _rooms_and_terrain() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var tackle := Dex.move("tackle")
	var def0: float = fx.defender_profile(p, e, tackle).def
	var spd0: float = fx.defender_profile(p, e, tackle).spd
	check(a.moves.use(p, "wonder_room"), "Wonder Room")
	_run(a, 0.3)
	check(fx.active(fx.field, "wonder"), "Wonder Room liga")
	var pr := fx.defender_profile(p, e, tackle)
	check(
		is_equal_approx(pr.def, spd0) and is_equal_approx(pr.spd, def0),
		"Wonder Room troca Def e Def. Esp."
	)
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx.field, "wonder"), "Wonder Room acaba em 5 turnos")
	_ready_all(p)
	check(a.moves.use(p, "psychic_terrain"), "Psychic Terrain")
	_run(a, 0.3)
	check(fx.active(fx.field, "psychic"), "Psychic Terrain liga")
	check(
		fx.blocks_hit(p, e, Dex.move("quick_attack")),
		"Psychic Terrain barra golpe de prioridade em quem pisa no chão"
	)
	check(not fx.blocks_hit(p, e, tackle), "golpe comum passa")
	var base := fx.damage_mult(p, e, Dex.move("psychic"))
	check(is_equal_approx(base, 1.3), "Psychic Terrain: Psychic 1,3x (%f)" % base)
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx.field, "psychic"), "Psychic Terrain acaba em 5 turnos")
	_ready_all(p)
	check(a.moves.use(p, "trick_room"), "Trick Room sai")
	_run(a, 1.5)
	check(a.turns.trick_room(), "Trick Room liga")
	a.free()


func _destiny_bond() -> void:
	var a := _still("rattata", "slowbro", 20, 50)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(a.moves.use(p, "destiny_bond"), "Destiny Bond")
	_run(a, 0.3)
	p.hp = 1
	_ready_all(e)
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.RIGHT)
	check(not p.alive() and not e.alive(), "Destiny Bond leva quem derrubou")
	a.free()


func _lock_on_and_crash() -> void:
	var a := _still()
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var zc := Dex.move("zap_cannon")
	check(fx.accuracy_of(p, zc) == 50.0, "Zap Cannon 50%% de precisão")
	check(a.moves.use(p, "lock_on"), "Lock-On")
	_run(a, 1.2)
	check(fx.accuracy_of(p, zc) == 0.0, "Lock-On: o próximo golpe não erra")
	var hp0 := p.hp
	fx.crash_damage(p, Dex.move("supercell_slam"))
	check(hp0 - p.hp == int(ceil(p.max_hp / 2.0)), "Supercell Slam: errar custa metade do HP máx.")
	hp0 = p.hp
	fx.crash_damage(p, Dex.move("tackle"))
	check(p.hp == hp0, "só o golpe com crash machuca")
	check(e.alive(), "alvo intacto")
	a.free()


func _steel_beam() -> void:
	var a := _still()
	var p: BattleFighter = a.player
	var hp0 := p.hp
	check(a.moves.use(p, "steel_beam"), "Steel Beam")
	_run(a, 1.5)
	check(
		hp0 - p.hp >= int(ceil(p.max_hp / 2.0)),
		"Steel Beam custa metade do HP máx. (%d -> %d)" % [hp0, p.hp]
	)
	a.free()


func _explosion() -> void:
	var a := _still("rattata", "slowbro", 20, 50)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = e.position + Vector3(1.5, 0, 0)
	var hp0 := e.hp
	check(a.moves.use(p, "explosion"), "Explosion")
	_run(a, 1.5)
	check(e.hp < hp0, "Explosion machuca o alvo")
	check(not p.alive(), "Explosion derruba quem usou")
	a.free()
