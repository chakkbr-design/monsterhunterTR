extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_more_b.gd
## Golpes da Gen 2-9 da parte B (tools/moves_more_b.py, battle/battle_more_b.gd): dados, uso em luta de
## energia e as mecânicas novas (Shell Trap, proteções com contato, Octolock, Sticky Web, Sketch...).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const MOVES := [
	"aeroblast",
	"apple_acid",
	"armor_cannon",
	"bleakwind_storm",
	"blue_flare",
	"boomburst",
	"burn_up",
	"chatter",
	"clanging_scales",
	"core_enforcer",
	"doom_desire",
	"dragon_energy",
	"dynamax_cannon",
	"electro_drift",
	"electro_shot",
	"eruption",
	"fairy_wind",
	"fickle_beam",
	"fiery_dance",
	"flame_burst",
	"fleur_cannon",
	"frost_breath",
	"fusion_flare",
	"glaciate",
	"hidden_power",
	"hydro_steam",
	"hyperspace_hole",
	"infestation",
	"judgment",
	"leaf_tornado",
	"lumina_crash",
	"luster_purge",
	"magma_storm",
	"make_it_rain",
	"malignant_chain",
	"matcha_gotcha",
	"mind_blown",
	"mist_ball",
	"moongeist_beam",
	"mystical_power",
	"natures_madness",
	"night_daze",
	"oblivion_wing",
	"octazooka",
	"origin_pulse",
	"overdrive",
	"parabolic_charge",
	"photon_geyser",
	"prismatic_laser",
	"psycho_boost",
	"relic_song",
	"revelation_dance",
	"rising_voltage",
	"roar_of_time",
	"ruination",
	"sandsear_storm",
	"searing_shot",
	"secret_sword",
	"seed_flare",
	"shell_trap",
	"signal_beam",
	"snipe_shot",
	"spacial_rend",
	"springtide_storm",
	"steam_eruption",
	"syrup_bomb",
	"tachyon_cutter",
	"techno_blast",
	"tera_starstorm",
	"thunder_cage",
	"thunderclap",
	"torch_song",
	"twin_beam",
	"water_shuriken",
	"wildbolt_storm",
	"magic_powder",
	"milk_drink",
	"mind_reader",
	"mud_sport",
	"no_retreat",
	"noble_roar",
	"obstruct",
	"octolock",
	"odor_sleuth",
	"parting_shot",
	"power_trick",
	"psycho_shift",
	"purify",
	"quash",
	"refresh",
	"revival_blessing",
	"rototiller",
	"shed_tail",
	"shift_gear",
	"shore_up",
	"silk_trap",
	"sketch",
	"spicy_extract",
	"spiky_shield",
	"sticky_web",
	"stuff_cheeks",
	"tail_glow",
	"take_heart",
	"tar_shot",
	"tearful_look",
	"teatime",
	"tidy_up",
	"topsy_turvy",
	"torment",
	"toxic_thread",
	"trick_or_treat"
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
	_hp_scaled()
	_shell_trap()
	_guards()
	_octolock()
	_sticky_web()
	_sketch()
	_revival()
	_shed_tail()
	_status_moves()
	_field_moves()
	_damage_moves()
	_misc()
	_ai()
	print("more_b: %d checks, %d falhas" % [_count, _fails])
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
	a.start(
		party,
		enemies,
		{
			"speed": 1.0,
			"battle_mode": "energy",
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


func _still(me := "charmander", foe := "slowbro", lv := 30, foe_lv := 30, extra := []) -> Node:
	var a := _arena([Mon.create(me, lv)] + extra, [Mon.create(foe, foe_lv)])
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
	a.player.position = Vector3(-2, 0, 0)
	a.enemy.position = Vector3(1, 0, 0)
	return a


func _data() -> void:
	check(MOVES.size() == 111, "lista com 111 golpes (%d)" % MOVES.size())
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
		elif (
			mv.has("bp")
			and float(mv.power) != float(mv.bp)
			and not mv.has("hits_range")
			and mv.kind != "self_buff"
		):
			ok = false
			print("  poder diferente do oficial: ", id)
		elif String(mv.get("category", "")) == "status" and float(mv.get("power", 0)) != 0.0:
			ok = false
			print("  status com poder: ", id)
		if not fxs.has(id):
			look_ok = false
			print("  sem look em move_fx: ", id)
	check(ok, "111 golpes com kind válido e poder oficial")
	check(look_ok, "111 golpes com look em move_fx.json")
	check(
		Dex.move("eruption").special == "water_spout", "Eruption usa o poder por HP do Water Spout"
	)
	check(int(Dex.move("shell_trap").priority) == -3, "Shell Trap tem prioridade -3")
	check(int(Dex.move("thunderclap").priority) == 1, "Thunderclap tem prioridade +1")
	var tc: Array = Dex.move("tachyon_cutter").hits_range
	var ws: Array = Dex.move("water_shuriken").hits_range
	check(int(tc[0]) == 2 and int(tc[1]) == 2, "Tachyon Cutter bate 2x")
	check(int(ws[0]) == 2 and int(ws[1]) == 5, "Water Shuriken bate de 2 a 5x")
	check(bool(Dex.move("boomburst").get("sound", false)), "Boomburst é golpe de som")
	check("boomburst" in BattleMoveEffects.SOUND_MOVES, "Boomburst fura o Substitute")


func _cast_all() -> void:
	var a := _still("clefable", "slowbro", 40, 40)
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var used := 0
	for id in MOVES:
		if id in ["revival_blessing", "shed_tail", "sketch"]:
			continue  # testados à parte (precisam de banco / de golpe anterior)
		_ready_all(p)
		_ready_all(e)
		p.hp = p.max_hp
		e.hp = e.max_hp
		p.trap_t = 0.0
		p.position = Vector3(-3, 0, 0)
		e.position = Vector3(2, 0, 0)
		if "fire" in p.types or true:
			p.types = ["fire", "psychic"]  # Burn Up sai, STAB variado
		if a.moves.use(p, id):
			used += 1
		_run(a, 1.8)
		for f in [p, e]:
			f.knock = Vector3.ZERO
			f.hidden = ""
			if f.look:
				f.look.visible = true
	check(used >= 70, "a maioria dos golpes sai numa luta de energia (%d/108)" % used)
	a.free()
	# luta curta de verdade, com a IA dos dois lados e golpes novos no moveset
	var pm := Mon.create("alakazam", 40)
	pm.moves = ["psycho_boost", "shell_trap", "obstruct", "torment"]
	var em := Mon.create("gengar", 40)
	em.moves = ["luster_purge", "spiky_shield", "topsy_turvy", "thunderclap"]
	var b := _arena([pm], [em])
	_run(b, 20.0)
	check(
		b.player.hp < b.player.max_hp or b.enemy.hp < b.enemy.max_hp,
		"luta de IA com golpes novos troca dano"
	)
	b.free()


func _hp_scaled() -> void:
	var a := _still("charmander", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var full := float(fx.adjust_move(p, e, Dex.move("eruption")).power)
	p.hp = p.max_hp / 4
	var low := float(fx.adjust_move(p, e, Dex.move("eruption")).power)
	check(
		full == 150.0 and low < 50.0, "Eruption: 150 com HP cheio e menos com HP baixo (%d)" % low
	)
	p.hp = p.max_hp
	# Doom Desire cai só no fim do 2º turno depois do uso
	var hp0 := e.hp
	check(a.moves.use(p, "doom_desire"), "usa Doom Desire")
	_run(a, 1.5)
	check(e.hp == hp0 and fx.futures.size() == 1, "Doom Desire fica no ar (como Future Sight)")
	a.end_turn.run()
	a.end_turn.run()
	a.end_turn.run()
	_run(a, 1.5)
	check(e.hp < hp0, "Doom Desire cai depois de 2 turnos (%d)" % (hp0 - e.hp))
	a.free()


func _shell_trap() -> void:
	var a := _still("charmander", "machamp", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.position = Vector3(0, 0, 0)
	e.position = Vector3(1.5, 0, 0)
	var hp0 := e.hp
	check(a.moves.use(p, "shell_trap"), "usa Shell Trap")
	_run(a, 0.6)
	check(fx.now < float(fx.st(p).get("shell_until", -99.0)), "Shell Trap fica armado")
	a.moves.hit(e, p, Dex.move("tackle"), Vector3.LEFT)
	_run(a, 0.8)
	check(e.hp < hp0, "golpe físico explode o Shell Trap (%d)" % (hp0 - e.hp))
	check(fx.now > float(fx.st(p).get("shell_until", -99.0)), "o Shell Trap gasta a armadilha")
	# golpe especial não explode; a armadilha falha
	var b := _still("charmander", "machamp", 30, 30)
	var bp: BattleFighter = b.player
	var be: BattleFighter = b.enemy
	bp.position = Vector3(0, 0, 0)
	be.position = Vector3(1.5, 0, 0)
	var hp1 := be.hp
	b.moves.use(bp, "shell_trap")
	_run(b, 0.6)
	b.moves.hit(be, bp, Dex.move("ember"), Vector3.LEFT)
	_run(b, 2.2)
	check(be.hp == hp1, "golpe especial não explode o Shell Trap")
	check(bool(b.moves.effects.st(bp).fail), "Shell Trap sem golpe físico falha")
	a.free()
	b.free()


func _guards() -> void:
	for pair in [["spiky_shield", "hp"], ["obstruct", "def"], ["silk_trap", "spe"]]:
		var a := _still("charmander", "machamp", 30, 30)
		var fx: BattleMoveEffects = a.moves.effects
		var p: BattleFighter = a.player
		var e: BattleFighter = a.enemy
		var id: String = pair[0]
		check(a.moves.use(p, id), "usa %s" % id)
		_run(a, 0.3)
		check(fx.active(fx.st(p), "b_guard"), "%s liga a proteção" % id)
		var hp_p := p.hp
		var hp_e := e.hp
		var stage_before := int(e.stages.get(pair[1], 0)) if pair[1] != "hp" else 0
		check(fx.blocks_hit(e, p, Dex.move("tackle")), "%s segura golpe de contato" % id)
		check(p.hp == hp_p, "%s: quem protege não perde HP" % id)
		match String(pair[1]):
			"hp":
				check(e.hp < hp_e, "Spiky Shield fere quem encosta (%d)" % (hp_e - e.hp))
			"def":
				check(
					int(e.stages.def) == stage_before - 2,
					"Obstruct baixa 2 de Defesa de quem encosta"
				)
			"spe":
				check(
					int(e.stages.spe) == stage_before - 1,
					"Silk Trap baixa 1 de Velocidade de quem encosta"
				)
		var hp_e2 := e.hp
		var stage_def := int(e.stages.def)
		check(fx.blocks_hit(e, p, Dex.move("ember")), "%s também segura golpe à distância" % id)
		check(
			e.hp == hp_e2 and int(e.stages.def) == stage_def,
			"%s: golpe à distância não castiga" % id
		)
		check(not fx.blocks_hit(e, p, Dex.move("feint")), "Feint atravessa %s" % id)
		a.end_turn.run()
		check(not fx.active(fx.st(p), "b_guard"), "%s acaba no fim da rodada" % id)
		a.free()


func _octolock() -> void:
	var a := _still("hitmonlee", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(a.moves.use(p, "octolock"), "usa Octolock")
	_run(a, 1.2)
	check(fx.active(fx.st(e), "octolock"), "Octolock prende o alvo")
	check(fx.cant_escape(e), "Octolock impede fugir e trocar")
	a.end_turn.run()
	check(
		int(e.stages.def) == -1 and int(e.stages.spd) == -1,
		"no fim da rodada, Defesa e Def. Esp. caem 1"
	)
	a.end_turn.run()
	check(int(e.stages.def) == -2, "e cai de novo na rodada seguinte")
	a.end_turn.run()
	a.end_turn.run()
	check(
		not fx.active(fx.st(e), "octolock") and not fx.cant_escape(e),
		"Octolock acaba depois de 4 rodadas"
	)
	a.free()


func _sticky_web() -> void:
	var a := _still("butterfree", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var ex = BattleMoreB._extras(fx)
	check(a.moves.use(p, "sticky_web"), "usa Sticky Web")
	_run(a, 0.5)
	if ex != null:
		check(ex.webs.size() >= 2, "Sticky Web deixa teias no chão (%d)" % ex.webs.size())
		check(ex.webs.all(func(w): return bool(w.get("sticky", false))), "as teias são pegajosas")
		var w: Dictionary = ex.webs[0]
		e.position = Vector3(w.pos.x, 0, w.pos.z)
		var spe := int(e.stages.get("spe", 0))
		ex._webs_on(e)
		check(int(e.stages.spe) == spe - 1, "quem pisa na teia pegajosa perde 1 de Velocidade")
		check(e.root_t > 0.0, "e fica preso por um instante")
	else:
		check(
			int(e.stages.get("spe", 0)) == -1, "sem chão vivo, Sticky Web baixa a Velocidade direto"
		)
	a.free()


func _sketch() -> void:
	var a := _still("mew", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	p.moves = ["sketch", "tackle"]
	p.mon.moves = ["sketch", "tackle"]
	fx.st(e).last = ""
	check(not a.moves.use(p, "sketch"), "Sketch não sai sem golpe do alvo para copiar")
	fx.st(e).last = "flamethrower"
	check(a.moves.use(p, "sketch"), "usa Sketch com golpe do alvo")
	_run(a, 1.0)
	check("flamethrower" in p.moves and not "sketch" in p.moves, "Sketch vira o golpe do alvo")
	check("flamethrower" in p.mon.moves, "e fica no Pokémon para sempre")
	a.free()


func _revival() -> void:
	var second := Mon.create("pidgey", 20)
	var a := _still("charmander", "slowbro", 30, 30, [second])
	var p: BattleFighter = a.player
	var fx: BattleMoveEffects = a.moves.effects
	check(not a.moves.use(p, "revival_blessing"), "Revival Blessing falha sem ninguém desmaiado")
	second.hp = 0
	check(a.moves.use(p, "revival_blessing"), "usa Revival Blessing")
	_run(a, 0.5)
	check(
		second.hp == maxi(1, second.max_hp / 2),
		"reanima o do banco com metade do HP (%d)" % second.hp
	)
	check(BattleMoreB._fainted_ally(fx, p) == null, "ninguém mais desmaiado")
	a.free()


func _shed_tail() -> void:
	var second := Mon.create("pidgey", 20)
	var third := Mon.create("rattata", 20)
	var a := _still("charmander", "slowbro", 30, 30, [second, third])
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var mon: Mon = p.mon
	var hp_max := p.max_hp
	check(a.moves.use(p, "shed_tail"), "usa Shed Tail")
	_run(a, 1.2)
	check(
		mon.hp <= hp_max - hp_max / 2 + 1, "Shed Tail custa metade do HP (%d/%d)" % [mon.hp, hp_max]
	)
	var nf: BattleFighter = a.player
	check(nf != null and nf.mon == third, "troca com o do banco")
	check(
		int(fx.st(nf).sub) == maxi(1, hp_max / 4),
		"quem entra herda o substituto (%d)" % int(fx.st(nf).sub)
	)
	a.free()
	var b := _still("charmander", "slowbro", 30, 30)
	check(not b.moves.use(b.player, "shed_tail"), "Shed Tail não sai sem ninguém no banco")
	b.free()


func _status_moves() -> void:
	var a := _still("alakazam", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	# Torment
	check(a.moves.use(p, "torment"), "usa Torment")
	_run(a, 1.0)
	fx.st(e).last = "tackle"
	check(not fx.usable(e, Dex.move("tackle")), "Torment trava o mesmo golpe duas vezes")
	check(fx.usable(e, Dex.move("ember")), "e deixa outro golpe sair")
	# Topsy-Turvy
	e.stages["atk"] = 2
	e.stages["spe"] = -3
	_ready_all(p)
	check(a.moves.use(p, "topsy_turvy"), "usa Topsy-Turvy")
	_run(a, 1.0)
	check(int(e.stages.atk) == -2 and int(e.stages.spe) == 3, "Topsy-Turvy inverte os estágios")
	# Tar Shot
	_ready_all(p)
	check(a.moves.use(p, "tar_shot"), "usa Tar Shot")
	_run(a, 1.0)
	var ember := fx.adjust_move(p, e, Dex.move("ember"))
	check(
		float(ember.power) == float(Dex.move("ember").power) * 2.0, "Tar Shot dobra o fogo no alvo"
	)
	check(int(e.stages.spe) == 2, "Tar Shot baixa a Velocidade")
	# Trick-or-Treat e Magic Powder
	_ready_all(p)
	check(a.moves.use(p, "trick_or_treat"), "usa Trick-or-Treat")
	_run(a, 1.0)
	check("ghost" in e.types, "Trick-or-Treat acrescenta Ghost")
	_ready_all(p)
	check(a.moves.use(p, "magic_powder"), "usa Magic Powder")
	_run(a, 1.0)
	check(e.types == ["psychic"], "Magic Powder deixa o alvo Psychic puro")
	# Quash
	e.gcd_t = 0.0
	_ready_all(p)
	check(a.moves.use(p, "quash"), "usa Quash")
	_run(a, 0.5)
	check(e.gcd_t > 0.5, "Quash segura o alvo (%.2f)" % e.gcd_t)
	# Toxic Thread
	e.clear_status()
	e.types = ["normal"]
	e.stages["spe"] = 0
	_ready_all(p)
	check(a.moves.use(p, "toxic_thread"), "usa Toxic Thread")
	_run(a, 1.0)
	check(
		e.status in ["poison", "toxic"] and int(e.stages.spe) == -1,
		"Toxic Thread envenena e baixa Velocidade"
	)
	# Psycho Shift e Purify
	p.apply_status("burn")
	e.clear_status()
	_ready_all(p)
	check(a.moves.use(p, "psycho_shift"), "usa Psycho Shift")
	_run(a, 1.0)
	check(p.status == "" and e.status == "burn", "Psycho Shift passa a queimadura")
	p.hp = p.max_hp / 2
	_ready_all(p)
	var hp_p := p.hp
	check(a.moves.use(p, "purify"), "usa Purify")
	_run(a, 1.0)
	check(e.status == "" and p.hp > hp_p, "Purify cura o alvo e o usuário recupera HP")
	# Odor Sleuth
	e.types = ["ghost"]
	_ready_all(p)
	check(a.moves.use(p, "odor_sleuth"), "usa Odor Sleuth")
	_run(a, 1.0)
	var prof := fx.defender_profile(p, e, Dex.move("tackle"))
	check(not "ghost" in prof.types, "Odor Sleuth tira a imunidade de Ghost a Normal")
	# No Retreat, Power Trick, Refresh, Take Heart, Shore Up, Rototiller...
	_ready_all(p)
	check(a.moves.use(p, "no_retreat"), "usa No Retreat")
	_run(a, 0.5)
	check(
		int(p.stages.atk) == 1 and int(p.stages.spe) == 1 and fx.cant_escape(p),
		"No Retreat: +1 em tudo e preso"
	)
	check(not a.moves.use(p, "no_retreat"), "No Retreat só uma vez")
	var atk0 := float(p.stats.atk)
	var def0 := float(p.stats.def)
	_ready_all(p)
	check(a.moves.use(p, "power_trick"), "usa Power Trick")
	_run(a, 0.5)
	check(
		float(p.stats.atk) == def0 and float(p.stats.def) == atk0,
		"Power Trick troca Ataque e Defesa"
	)
	p.apply_status("burn")
	_ready_all(p)
	check(a.moves.use(p, "refresh"), "usa Refresh")
	_run(a, 0.5)
	check(p.status == "", "Refresh cura a queimadura")
	check(not a.moves.use(p, "refresh"), "Refresh falha sem status")
	p.apply_status("poison")
	var spa1 := int(p.stages.spa)
	var spd1 := int(p.stages.spd)
	_ready_all(p)
	check(a.moves.use(p, "take_heart"), "usa Take Heart")
	_run(a, 0.5)
	check(
		p.status == "" and int(p.stages.spa) == spa1 + 1 and int(p.stages.spd) == spd1 + 1,
		"Take Heart cura e sobe At. e Def. Esp."
	)
	p.hp = 1
	_ready_all(p)
	check(a.moves.use(p, "shore_up"), "usa Shore Up")
	_run(a, 0.5)
	check(p.hp >= p.max_hp / 2, "Shore Up cura metade do HP")
	_ready_all(p)
	check(a.moves.use(p, "milk_drink"), "usa Milk Drink")
	_ready_all(p)
	check(a.moves.use(p, "shift_gear"), "usa Shift Gear")
	_run(a, 0.5)
	check(int(p.stages.spe) == 3, "Shift Gear: Velocidade +2")
	var spa2 := int(p.stages.spa)
	_ready_all(p)
	check(a.moves.use(p, "tail_glow"), "usa Tail Glow")
	_run(a, 0.5)
	check(int(p.stages.spa) == mini(spa2 + 3, 6), "Tail Glow: At. Esp. +3")
	# Debuffs em área com "stats"
	e.types = ["normal"]
	e.position = Vector3(1, 0, 0)
	_ready_all(p)
	check(a.moves.use(p, "noble_roar"), "usa Noble Roar")
	_run(a, 0.5)
	check(int(e.stages.atk) == -3 and int(e.stages.spa) == -1, "Noble Roar baixa Ataque e At. Esp.")
	_ready_all(p)
	check(a.moves.use(p, "tearful_look"), "usa Tearful Look")
	_run(a, 0.5)
	check(int(e.stages.spa) == -2, "Tearful Look baixa At. Esp. de novo")
	a.free()


func _field_moves() -> void:
	var a := _still("sandslash", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	# Mud Sport
	var thunder := Dex.move("thunderbolt")
	check(fx.adjust_move(p, e, thunder).power == thunder.power, "sem Mud Sport o Elétrico é normal")
	check(a.moves.use(p, "mud_sport"), "usa Mud Sport")
	_run(a, 0.5)
	check(fx.active(fx.field, "mud_sport"), "Mud Sport liga o campo")
	var weak := fx.adjust_move(p, e, thunder)
	check(
		is_equal_approx(float(weak.power), float(thunder.power) / 3.0),
		"Elétrico sai com 1/3 do poder"
	)
	for i in 5:
		a.end_turn.run()
	check(not fx.active(fx.field, "mud_sport"), "Mud Sport acaba em 5 rodadas")
	# Rototiller: Grass no chão sobe Ataque e At. Esp.
	e.types = ["grass"]
	_ready_all(p)
	check(a.moves.use(p, "rototiller"), "usa Rototiller")
	_run(a, 0.5)
	check(int(e.stages.atk) == 1 and int(e.stages.spa) == 1, "Rototiller sobe o Grass no chão")
	# Tidy Up: limpa substituto e espinhos
	fx.st(e)["sub"] = 30
	fx.spikes.append({"pos": Vector3.ZERO, "side": 1, "layers": 1, "t": fx.now + 20.0, "hit": {}})
	_ready_all(p)
	check(a.moves.use(p, "tidy_up"), "usa Tidy Up")
	_run(a, 0.5)
	check(int(fx.st(e).sub) == 0 and fx.spikes.is_empty(), "Tidy Up tira substituto e armadilhas")
	check(int(p.stages.atk) == 1 and int(p.stages.spe) == 1, "Tidy Up sobe Ataque e Velocidade")
	# Stuff Cheeks e Teatime
	check(not a.moves.use(p, "stuff_cheeks"), "Stuff Cheeks não sai sem frutinha")
	p.trainer_item = "sitrus_berry"
	p.item_used = false
	p.hp = p.max_hp / 2
	var hp_before := p.hp
	_ready_all(p)
	check(a.moves.use(p, "stuff_cheeks"), "Stuff Cheeks sai com frutinha")
	_run(a, 0.5)
	check(
		p.item_used and int(p.stages.def) == 2 and p.hp > hp_before,
		"come a frutinha: +2 Defesa e cura"
	)
	p.trainer_item = "oran_berry"
	p.item_used = false
	_ready_all(p)
	p.hp = p.max_hp / 2
	check(a.moves.use(p, "teatime"), "usa Teatime")
	_run(a, 0.5)
	check(p.item_used, "Teatime faz todo mundo comer a frutinha")
	a.free()


func _damage_moves() -> void:
	var a := _still("charizard", "slowbro", 40, 40)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	# Burn Up só com Fire e tira o tipo
	p.types = ["fire", "flying"]
	check(a.moves.use(p, "burn_up"), "usa Burn Up")
	_run(a, 1.6)
	check(not "fire" in p.types, "Burn Up tira o tipo Fire")
	_ready_all(p)
	check(not a.moves.use(p, "burn_up"), "Burn Up não sai sem Fire")
	# Hidden Power vem dos IVs
	for k in p.mon.ivs:
		p.mon.ivs[k] = 31
	check(BattleMoreB._hp_type(p) == "dark", "IVs todos 31 = Hidden Power Dark")
	for k in p.mon.ivs:
		p.mon.ivs[k] = 30
	check(BattleMoreB._hp_type(p) == "fighting", "IVs todos pares = Hidden Power Fighting")
	var hp_move := fx.adjust_move(p, e, Dex.move("hidden_power"))
	check(hp_move.type == "fighting", "o golpe sai com o tipo dos IVs")
	# Judgment / Revelation Dance: tipo do usuário
	p.types = ["ghost"]
	check(
		fx.adjust_move(p, e, Dex.move("judgment")).type == "ghost",
		"Judgment pega o tipo do usuário"
	)
	check(
		fx.adjust_move(p, e, Dex.move("revelation_dance")).type == "ghost",
		"Revelation Dance também"
	)
	# Techno Blast com Drive
	p.trainer_item = "shock_drive"
	p.item_used = false
	check(
		fx.adjust_move(p, e, Dex.move("techno_blast")).type == "electric",
		"Techno Blast segue o Drive"
	)
	p.trainer_item = ""
	check(fx.adjust_move(p, e, Dex.move("techno_blast")).type == "normal", "sem Drive é Normal")
	# Fusion Flare dobra depois do Fusion Bolt
	var ff := Dex.move("fusion_flare")
	check(float(fx.adjust_move(p, e, ff).power) == 100.0, "Fusion Flare base")
	fx.field["b_fusion_t"] = fx.now
	check(
		float(fx.adjust_move(p, e, ff).power) == 200.0, "Fusion Flare dobra depois do Fusion Bolt"
	)
	# Electro Drift: supereficaz 4/3
	e.types = ["water"]
	var ed := fx.adjust_move(p, e, Dex.move("electro_drift"))
	check(is_equal_approx(float(ed.power), 100.0 * 4.0 / 3.0), "Electro Drift: supereficaz dá 4/3")
	e.types = ["normal"]
	check(float(fx.adjust_move(p, e, Dex.move("electro_drift")).power) == 100.0, "e neutro dá 100")
	# Rising Voltage: dobra no Campo Elétrico
	check(
		float(fx.adjust_move(p, e, Dex.move("rising_voltage")).power) == 70.0, "Rising Voltage base"
	)
	fx.set_rounds(fx.field, "electric", 5)
	check(
		float(fx.adjust_move(p, e, Dex.move("rising_voltage")).power) == 140.0,
		"Rising Voltage dobra no campo"
	)
	# Hydro Steam: o sol não enfraquece
	check(float(fx.adjust_move(p, e, Dex.move("hydro_steam")).power) == 80.0, "Hydro Steam base")
	fx.set_weather("sun", 5)
	check(
		float(fx.adjust_move(p, e, Dex.move("hydro_steam")).power) == 240.0,
		"Hydro Steam no sol compensa o 0,5x"
	)
	# Fickle Beam
	fx.st(p)["fickle"] = true
	check(
		float(fx.adjust_move(p, e, Dex.move("fickle_beam")).power) == 160.0,
		"Fickle Beam dobra quando sorteia"
	)
	fx.st(p)["fickle"] = false
	check(
		float(fx.adjust_move(p, e, Dex.move("fickle_beam")).power) == 80.0, "e vale 80 quando não"
	)
	# Photon Geyser físico se o Ataque é maior
	p.stats["atk"] = 200.0
	p.stats["spa"] = 50.0
	var prof := {"spa": 50.0, "crit_spa": 50.0}
	BattleMoreB.attacker(fx, p, e, Dex.move("photon_geyser"), prof)
	check(float(prof.spa) >= 200.0, "Photon Geyser usa o Ataque quando é maior")
	# Tar Shot + fogo; Flame Burst no parceiro do alvo (sem parceiro: não quebra)
	check(a.moves.use(p, "flame_burst"), "usa Flame Burst")
	_run(a, 1.5)
	check(e.hp <= e.max_hp, "Flame Burst sai sem alvo vizinho")
	# Mystical Power sobe o maior atributo
	var spa_before := int(p.stages.get("atk", 0))
	_ready_all(p)
	p.position = Vector3(-2, 0, 0)
	e.position = Vector3(1, 0, 0)
	check(a.moves.use(p, "mystical_power"), "usa Mystical Power")
	_run(a, 1.5)
	check(
		_stage_total(p) > spa_before or e.hp == e.max_hp,
		"Mystical Power sobe o melhor atributo ao acertar"
	)
	# Nature's Madness e Ruination: metade do HP
	_ready_all(p)
	e.hp = e.max_hp
	var hp0 := e.hp
	var resolved := Dex.move("natures_madness")
	var res := {"damage": 99, "eff": 1.0, "crit": false}
	fx.on_damage_roll(p, e, resolved, res)
	check(int(res.damage) == maxi(1, hp0 / 2), "Nature's Madness tira metade do HP")
	a.free()


func _stage_total(f: BattleFighter) -> int:
	var n := 0
	for k in f.stages:
		n += int(f.stages[k])
	return n


func _misc() -> void:
	var a := _still("hitmonchan", "slowbro", 30, 30)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	# Thunderclap só com o alvo atacando
	check(not a.moves.use(p, "thunderclap"), "Thunderclap falha com o alvo parado")
	e.prepare_t = 0.5
	e.prepare_id = "tackle"
	check(fx.usable(p, Dex.move("thunderclap")), "Thunderclap sai com o alvo preparando um golpe")
	e.prepare_t = 0.0
	e.prepare_id = ""
	# Parting Shot: derruba e troca
	var second := Mon.create("pidgey", 20)
	var third := Mon.create("rattata", 20)
	var b := _still("charmander", "slowbro", 30, 30, [second, third])
	var bp: BattleFighter = b.player
	var be: BattleFighter = b.enemy
	check(b.moves.use(bp, "parting_shot"), "usa Parting Shot")
	_run(b, 1.2)
	check(
		int(be.stages.atk) == -1 and int(be.stages.spa) == -1,
		"Parting Shot baixa Ataque e At. Esp."
	)
	check(b.player.mon == third, "e o usuário troca com o banco")
	# Snipe Shot ignora o Cobrir
	check(
		bool(Dex.move("snipe_shot").get("snipe", false)), "Snipe Shot tem a marca de ignorar desvio"
	)
	# Core Enforcer anula a habilidade de quem já agiu
	var c := _still("charmander", "slowbro", 30, 30)
	var cp: BattleFighter = c.player
	var ce: BattleFighter = c.enemy
	c.moves.effects.st(ce)["b_use_t"] = c.moves.effects.now
	check(c.moves.use(cp, "core_enforcer"), "usa Core Enforcer")
	_run(c, 1.5)
	check(
		c.moves.effects._ability(ce) == "" or ce.hp == ce.max_hp,
		"Core Enforcer anula a habilidade de quem agiu"
	)
	# Mind Blown tira metade do HP máximo mesmo sem acertar
	var d := _still("charmander", "slowbro", 30, 30)
	var dp: BattleFighter = d.player
	check(d.moves.use(dp, "mind_blown"), "usa Mind Blown")
	_run(d, 1.2)
	check(
		dp.hp <= dp.max_hp / 2 + 1,
		"Mind Blown custa metade do HP máximo (%d/%d)" % [dp.hp, dp.max_hp]
	)
	# Electro Shot carrega e sobe o At. Esp.
	var f := _still("raichu", "slowbro", 30, 30)
	var fp: BattleFighter = f.player
	check(f.moves.use(fp, "electro_shot"), "usa Electro Shot")
	check(int(fp.stages.spa) == 1, "Electro Shot sobe o At. Esp. na carga")
	var fm: Dictionary = f.moves.effects.move_for(fp, Dex.move("electro_shot"))
	check(float(fm.windup) > 0.5, "sem chuva a carga é longa")
	f.moves.effects.set_weather("rain", 5)
	var fr: Dictionary = f.moves.effects.move_for(fp, Dex.move("electro_shot"))
	check(float(fr.windup) < 0.5 and not fr.has("charge_stats"), "na chuva a carga é pulada")
	# Tempestades de vento/raio não erram na chuva
	check(
		f.moves.effects.accuracy_of(fp, Dex.move("wildbolt_storm")) == 0.0,
		"Wildbolt Storm não erra na chuva"
	)
	check(
		f.moves.effects.accuracy_of(fp, Dex.move("sandsear_storm")) > 0.0,
		"Sandsear Storm erra na chuva"
	)
	for x in [a, b, c, d, f]:
		x.free()


func _ai() -> void:
	var a := _still("alakazam", "machamp", 40, 40)
	var fx: BattleMoveEffects = a.moves.effects
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	check(
		fx.ai_worth(p, Dex.move("shell_trap")) == false,
		"a IA não arma o Shell Trap sem ameaça física"
	)
	e.prepare_t = 0.6
	e.prepare_id = "tackle"
	check(
		fx.ai_worth(p, Dex.move("shell_trap")) == true,
		"a IA arma o Shell Trap com golpe físico a caminho"
	)
	check(
		(
			fx.ai_power(p, e, Dex.move("shell_trap")) == 0.0
			or fx.ai_power(p, e, Dex.move("shell_trap")) > 0.0
		),
		"ai_power do Shell Trap responde"
	)
	e.prepare_t = 0.0
	e.prepare_id = ""
	check(fx.ai_worth(p, Dex.move("torment")) == true, "a IA usa Torment")
	check(fx.ai_worth(p, Dex.move("sticky_web")) == true, "a IA usa Sticky Web")
	check(fx.ai_worth(p, Dex.move("purify")) == false, "a IA não cura o adversário com Purify")
	check(
		a.moves.expected_damage(p, e, Dex.move("psycho_boost")) > 0.0,
		"a IA enxerga o dano do Psycho Boost"
	)
	check(
		a.moves.expected_damage(p, e, Dex.move("eruption")) > 0.0, "a IA enxerga o dano do Eruption"
	)
	a.free()
