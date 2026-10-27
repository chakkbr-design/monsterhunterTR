extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_kanto_moves.gd
## Os 57 golpes Kanto que faltavam (axe_kick ... wood_hammer): dados, uso em luta de energia e as
## mecânicas novas (BattleTransform, Dream Eater, Perish Song, Bonemerang, OHKO, Detect...).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const MOVES := [
	"axe_kick",
	"blaze_kick",
	"bone_rush",
	"bonemerang",
	"bullet_punch",
	"conversion",
	"conversion_2",
	"crabhammer",
	"darkest_lariat",
	"detect",
	"dream_eater",
	"dual_chop",
	"entrainment",
	"extreme_speed",
	"first_impression",
	"freeze_dry",
	"guard_split",
	"guard_swap",
	"guillotine",
	"hail",
	"heal_bell",
	"high_jump_kick",
	"kinesis",
	"lava_plume",
	"lick",
	"lovely_kiss",
	"mach_punch",
	"magic_coat",
	"magic_room",
	"metal_burst",
	"mystical_fire",
	"nature_power",
	"perish_song",
	"phantom_force",
	"poltergeist",
	"powder_snow",
	"power_split",
	"power_swap",
	"psystrike",
	"raging_bull",
	"raging_fury",
	"reflect_type",
	"retaliate",
	"role_play",
	"sheer_cold",
	"soft_boiled",
	"sparkling_aria",
	"speed_swap",
	"steel_roller",
	"storm_throw",
	"teleport",
	"terrain_pulse",
	"transform",
	"triple_axel",
	"vice_grip",
	"vital_throw",
	"wood_hammer"
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
	_transform()
	_dream_eater()
	_perish()
	_bonemerang()
	_ohko()
	_detect()
	_misc()
	print("kanto_moves: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(party, enemies, {"speed": 1.0, "no_rewards": true, "field_objects": false, "seed": 11})
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _ready_all(f: BattleFighter) -> void:
	f.pp_max = f.pp_base  # energia cheia
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
		f.pp_max = f.pp_base
		f.clear_status()
		f.trap_t = 0.0
		f.knock = Vector3.ZERO
		_ready_all(f)
	return a


func _data() -> void:
	check(MOVES.size() == 57, "lista com 57 golpes (%d)" % MOVES.size())
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
		elif mv.has("bp") and float(mv.power) != float(mv.bp) and not mv.has("hits_range"):
			ok = false
			print("  poder diferente do oficial: ", id)
		elif String(mv.get("category", "")) == "status" and float(mv.get("power", 0)) != 0.0:
			ok = false
			print("  status com poder: ", id)
		if not fxs.has(id):
			look_ok = false
			print("  sem look em move_fx: ", id)
	check(ok, "57 golpes com kind válido e poder oficial")
	check(look_ok, "57 golpes com look em move_fx.json")


func _cast_all() -> void:
	var a := _still("clefable", "slowbro", 40, 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var used := 0
	for id in MOVES:
		if id == "transform":
			continue  # testado à parte (muda o lutador)
		_ready_all(p)
		_ready_all(e)
		p.hp = p.max_hp
		e.hp = e.max_hp
		p.trap_t = 0.0
		p.position = Vector3(-3, 0, 0)
		e.position = Vector3(2, 0, 0)
		if a.moves.use(p, id):
			used += 1
		_run(a, 1.6)
		for f in [p, e]:
			f.knock = Vector3.ZERO
			f.hidden = ""
			if f.look:
				f.look.visible = true
	check(used >= 40, "a maioria dos golpes sai numa luta de energia (%d/56)" % used)
	a.free()
	# luta curta de verdade, com a IA nos dois lados e golpes novos no moveset
	var pm := Mon.create("primeape", 40)
	pm.moves = ["high_jump_kick", "mach_punch", "axe_kick", "detect"]
	var em := Mon.create("mankey", 40)
	em.moves = ["bullet_punch", "vital_throw", "extreme_speed", "magic_coat"]
	var b := _arena([pm], [em])
	_run(b, 20.0)
	check(
		b.player.hp < b.player.max_hp or b.enemy.hp < b.enemy.max_hp,
		"luta de IA com golpes novos troca dano"
	)
	b.free()


func _transform() -> void:
	var a := _still("clefable", "slowbro", 30, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var own_moves: Array = p.moves.duplicate()
	var own_hp := p.hp
	check(a.moves.use(p, "transform"), "usa Transform")
	_run(a, 1.2)
	check(BattleTransform.is_transformed(p), "Transform marca o usuário")
	check(p.types == e.types, "Transform copia os tipos")
	check(p.moves == e.moves.slice(0, 4), "Transform copia os golpes")
	check(is_equal_approx(p.stat("atk"), e.stat("atk")), "Transform copia o Ataque")
	check(p.hp == own_hp, "Transform mantém o HP")
	check(not BattleTransform.apply(a, p, e), "não transforma duas vezes")
	BattleTransform.revert(p)
	check(
		not BattleTransform.is_transformed(p) and p.moves == own_moves, "revert devolve o que era"
	)
	check(BattleTransform.apply(a, p, e), "apply direto (Imposter) funciona depois do revert")
	a.free()


func _dream_eater() -> void:
	var a := _still("koffing", "slowbro", 30, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.hp = 5
	check(not a.moves.use(p, "dream_eater"), "Dream Eater não sai com o alvo acordado")
	e.status = "sleep"
	e.status_t = 30.0
	check(a.moves.use(p, "dream_eater"), "Dream Eater sai com o alvo dormindo")
	_run(a, 1.5)
	check(p.hp > 5 or e.hp < e.max_hp, "Dream Eater acerta e cura (%d)" % p.hp)
	a.free()


func _perish() -> void:
	var a := _still("koffing", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(2, 0, 0)
	check(a.moves.use(p, "perish_song"), "usa Perish Song")
	_run(a, 1.0)
	check(fx.active(fx.st(e), "perish") and fx.active(fx.st(p), "perish"), "a canção pega os dois")
	a.end_turn.run()
	a.end_turn.run()
	check(p.alive() and e.alive(), "vivos depois de 2 rodadas")
	a.end_turn.run()
	check(not p.alive() and not e.alive(), "desmaiam na terceira rodada")
	a.free()


func _bonemerang() -> void:
	var a := _still("sandshrew", "slowbro", 30, 30)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var mv := Dex.move("bonemerang")
	var rolled: Dictionary = a.moves.effects.roll_hits(mv, p)
	check(
		int(rolled.get("hits", 0)) == 2 and not rolled.has("count"), "Bonemerang: 2 acertos, 1 osso"
	)
	check(BattleMoves.hits_of(rolled) == 2, "Bonemerang vale 2 acertos")
	p.position = Vector3(-3, 0, 0)
	e.position = Vector3(1, 0, 0)
	var hp0 := e.hp
	check(a.moves.use(p, "bonemerang"), "usa Bonemerang")
	_run(a, 2.5)
	check(e.hp < hp0, "Bonemerang machuca (%d)" % (hp0 - e.hp))
	a.free()


func _ohko() -> void:
	var a := _still("charmander", "slowbro", 45, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var g := Dex.move("guillotine")
	check(String(g.get("special", "")) == "ohko", "Guillotine é OHKO")
	check(fx.exact_hit(p, e, g, Vector3.RIGHT), "Guillotine resolve pelo caminho exato")
	_run(a, 0.5)
	check(not e.alive() or e.hp == 0, "Guillotine derruba")
	var b := _still("charmander", "slowbro", 45, 30)
	var bf: BattleMoveEffects = b.moves.effects
	var sc := Dex.move("sheer_cold")
	b.player.types = ["fire"]
	var acc_other := bf.accuracy_of(b.player, sc)
	b.player.types = ["ice"]
	var acc_ice := bf.accuracy_of(b.player, sc)
	check(
		acc_ice > acc_other,
		"Sheer Cold: mais difícil para quem não é Gelo (%d < %d)" % [acc_other, acc_ice]
	)
	b.enemy.types = ["ice"]
	b.player.types = ["fire"]
	check(bf.exact_hit(b.player, b.enemy, sc, Vector3.RIGHT), "Sheer Cold resolve")
	check(b.enemy.alive(), "Sheer Cold não afeta tipo Gelo")
	a.free()
	b.free()


func _detect() -> void:
	var a := _still("primeape", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(a.moves.use(p, "detect"), "usa Detect")
	_run(a, 0.3)
	check(fx.active(fx.st(p), "protect"), "Detect protege")
	check(fx.blocks_hit(e, p, Dex.move("tackle")), "Detect segura o golpe")
	check(bool(Dex.move("detect").get("insight", false)), "Detect tem insight")
	a.free()


func _misc() -> void:
	var a := _still("charmander", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(
		BattleKanto.freeze_types(["water", "ground"]) == ["grass", "ground"],
		"Freeze-Dry: Água vira fraqueza"
	)
	check(
		a.moves.expected_damage(p, e, Dex.move("freeze_dry")) > 0.0, "expected_damage de Freeze-Dry"
	)
	check(a.moves.use(p, "magic_room"), "usa Magic Room")
	_run(a, 0.4)
	check(fx.active(fx.field, "magic"), "Magic Room liga o campo")
	a.free()
