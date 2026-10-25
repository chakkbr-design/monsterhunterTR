extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_kanto_abilities.gd
## Habilidades dos 151 de Kanto (modo de energia). As espécies novas ainda não existem: o teste empresta
## a habilidade a um lutador com set_meta("ability_override", id).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const NEW := [
	"analytic",
	"anger_point",
	"anticipation",
	"cursed_body",
	"download",
	"early_bird",
	"forewarn",
	"gluttony",
	"harvest",
	"healer",
	"liquid_ooze",
	"mold_breaker",
	"neutralizing_gas",
	"overcoat",
	"poison_touch",
	"pressure",
	"rattled",
	"scrappy",
	"synchronize",
	"trace",
	"weak_armor",
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	_data()
	_analytic()
	_anger_point()
	_anticipation()
	_cursed_body()
	_download()
	_early_bird()
	_forewarn()
	_gluttony()
	_harvest()
	_healer()
	_liquid_ooze()
	_mold_breaker()
	_neutralizing_gas()
	_overcoat()
	_poison_touch()
	_pressure()
	_rattled()
	_scrappy()
	_synchronize()
	_trace()
	_imposter()
	_weak_armor()
	_smoke()
	print("kanto abilities: %d checks, %d falhas" % [_count, _fails])
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
	if not opts.has("speed"):
		opts["speed"] = 1.0
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false
	if not opts.has("battle_mode"):
		opts["battle_mode"] = "energy"
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Arena parada em modo de energia: ninguém age sozinho.
func _still(mine := "pidgey", foe := "rattata", opts := {}) -> Node:
	opts["seed"] = 11
	var a := _arena([Mon.create(mine, 30)], [Mon.create(foe, 30)], opts)
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	_run(a, 1.5)
	a.player.heal(a.player.max_hp)
	a.enemy.heal(a.enemy.max_hp)
	return a


func _give(f: BattleFighter, ab: String) -> void:
	f.set_meta("ability_override", ab)


func _data() -> void:
	var bad := 0
	for id in NEW:
		var d := Dex.ability(id)
		if (
			d.is_empty()
			or String(d.get("name", "")) != String(d.get("name", "")).to_upper()
			or String(d.get("desc", "")) == ""
			or String(d.get("desc_pt", "")) == ""
		):
			bad += 1
		check(
			BattleAbilities.PROFILES.has(id) or id in ["gluttony"],
			"%s tem perfil de movimento sugerido" % id
		)
	check(
		bad == 0, "as %d habilidades de Kanto têm name em maiúsculas, desc e desc_pt" % NEW.size()
	)


func _analytic() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.player, "analytic")
	var tackle := Dex.move("tackle")
	check(ab.damage_mult(a.player, a.enemy, tackle) == 1.0, "Analytic: alvo parado, dano normal")
	ab.on_move_used(a.enemy, tackle)
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, tackle), 1.3),
		"Analytic: x1,3 em quem acabou de usar um golpe"
	)
	check(
		ab.damage_mult(a.enemy, a.player, tackle) == 1.0,
		"Analytic: só vale para quem tem a habilidade"
	)
	_run(a, BattleAbilities.ANALYTIC_WINDOW + 0.3)
	check(ab.damage_mult(a.player, a.enemy, tackle) == 1.0, "Analytic: a janela de 3 s fecha")
	a.free()


func _anger_point() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "anger_point")
	var tackle := Dex.move("tackle")
	ab.on_hit(a.player, a.enemy, tackle, 5, false)
	check(int(a.enemy.stages.get("atk", 0)) == 0, "Anger Point: golpe sem crítico não faz nada")
	ab.on_hit(a.player, a.enemy, tackle, 5, true)
	check(int(a.enemy.stages.get("atk", 0)) == 6, "Anger Point: crítico leva o Ataque a +6")
	check(a.enemy.mood_state == "fury", "Anger Point: entra em fúria (a IA para de recuar)")
	a.free()


func _anticipation() -> void:
	var a := _still("pidgey", "pikachu")
	var ab: BattleAbilities = a.abilities
	a.enemy.moves = ["thunder_shock", "tackle"]
	_give(a.player, "anticipation")
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(ab._state(a.player).shudder, "Anticipation: arrepio com golpe superefetivo no inimigo")
	check(ab.last_banner == "ANTICIPATION", "Anticipation: mostra a faixa")
	var shock := Dex.move("thunder_shock")
	var dodged := 0
	var dodged_tackle := 0
	for i in 300:
		if ab.immune(a.enemy, a.player, shock):
			dodged += 1
		if ab.immune(a.enemy, a.player, Dex.move("tackle")):
			dodged_tackle += 1
	check(
		dodged > 30 and dodged < 130,
		"Anticipation: ~25%% de esquiva no superefetivo (%d/300)" % dodged
	)
	check(dodged_tackle == 0, "Anticipation: golpe comum nunca é esquivado")
	check(
		not ab.immune(a.player, a.enemy, shock), "Anticipation: não esquiva golpe do próprio lado"
	)
	a.free()
	# sem golpe perigoso: sem arrepio
	var b := _still("pidgey", "rattata")
	b.enemy.moves = ["tackle"]
	_give(b.player, "anticipation")
	b.abilities.on_enter(b.player)
	_run(b, 0.3)
	check(not b.abilities._state(b.player).shudder, "Anticipation: sem ameaça, sem arrepio")
	b.free()


func _cursed_body() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "cursed_body")
	var tackle := Dex.move("tackle")
	var locked := 0
	for i in 200:
		a.player.move_cd["tackle"] = 0.0
		ab.on_hit(a.player, a.enemy, tackle, 5)
		if float(a.player.move_cd["tackle"]) >= BattleAbilities.CURSED_LOCK - 0.1:
			locked += 1
	check(locked > 30 and locked < 100, "Cursed Body: ~30%% trava o golpe (%d/200)" % locked)
	a.free()


func _download() -> void:
	var a := _still("pidgey", "rattata")
	var ab: BattleAbilities = a.abilities
	a.enemy.stages["def"] = 6  # Defesa muito maior que a Def. Esp.: sobe o Atq. Esp.
	_give(a.player, "download")
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(
		int(a.player.stages.get("spa", 0)) == 1, "Download: Defesa alta no inimigo -> Atq. Esp. +1"
	)
	check(int(a.player.stages.get("atk", 0)) == 0, "Download: o Ataque não sobe")
	a.free()
	var b := _still("pidgey", "rattata")
	b.enemy.stages["spd"] = 6
	_give(b.player, "download")
	b.abilities.on_enter(b.player)
	_run(b, 0.3)
	check(
		int(b.player.stages.get("atk", 0)) == 1, "Download: Def. Esp. alta no inimigo -> Ataque +1"
	)
	b.free()


func _early_bird() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.player, "early_bird")
	for f in [a.player, a.enemy]:
		f.apply_status("sleep", null)
		f.sleep_turns = 4
		f.status_round = -5
	var wake_eb := 0
	var wake_n := 0
	for r in range(1, 6):
		ab.late_residual(a.player)
		ab.late_residual(a.enemy)
		a.player.round_count()
		a.enemy.round_count()
		if wake_eb == 0 and a.player.status != "sleep":
			wake_eb = r
		if wake_n == 0 and a.enemy.status != "sleep":
			wake_n = r
	check(wake_n == 3, "sono comum de contador 4 acorda na 3ª rodada (%d)" % wake_n)
	check(wake_eb == 2, "Early Bird acorda na 2ª rodada, uma antes (%d)" % wake_eb)
	a.free()


func _forewarn() -> void:
	var a := _still("pidgey", "charmander")
	var ab: BattleAbilities = a.abilities
	a.enemy.moves = ["ember", "flamethrower", "tackle"]
	_give(a.player, "forewarn")
	ab.on_enter(a.player)
	_run(a, 0.3)
	var warn: Dictionary = ab._state(a.player).warn
	check(
		String(warn.get(a.enemy.get_instance_id(), "")) == "flamethrower",
		"Forewarn: revela o golpe mais forte (%s)" % str(warn)
	)
	check(ab.last_banner == "FOREWARN", "Forewarn: mostra a faixa")
	var fd := 0
	var other := 0
	for i in 300:
		if ab.immune(a.enemy, a.player, Dex.move("flamethrower")):
			fd += 1
		if ab.immune(a.enemy, a.player, Dex.move("ember")):
			other += 1
	check(fd > 40 and fd < 150, "Forewarn: ~30%% de esquiva do golpe revelado (%d/300)" % fd)
	check(other == 0, "Forewarn: só esquiva o golpe revelado")
	a.free()


func _gluttony() -> void:
	var a := _still("pidgey", "rattata")
	var et: BattleEndTurn = a.end_turn
	for f in [a.player, a.enemy]:
		f.trainer_item = "oran_berry"
		f.item_used = false
		f.hp = int(f.max_hp * 0.6)
	_give(a.player, "gluttony")
	var p0: int = a.player.hp
	var e0: int = a.enemy.hp
	et.held_check(a.player)
	et.held_check(a.enemy)
	check(a.player.item_used, "Gluttony: come a Oran com 60% do HP")
	check(not a.enemy.item_used, "sem Gluttony a Oran espera os 50%")
	var want: int = a.player.paced(15)  # modo de energia: cura x0,6 (fighter.paced)
	check(
		a.player.hp - p0 == want,
		"Gluttony: a Oran cura x1,5 (%d, deu %d)" % [want, a.player.hp - p0]
	)
	check(a.enemy.hp == e0, "sem Gluttony não curou ainda")
	a.free()


func _harvest() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.player, "harvest")
	a.player.trainer_item = "oran_berry"
	a.player.item_used = true
	var back := 0
	for i in 40:
		ab.late_residual(a.player)
		if not a.player.item_used:
			back = i + 1
			break
	check(back > 0, "Harvest: a frutinha volta em algumas rodadas (%d)" % back)
	a.player.item_used = true
	ab.set_weather("sun", 30.0)
	ab.late_residual(a.player)
	check(not a.player.item_used, "Harvest: no sol volta na hora")
	a.player.trainer_item = "leftovers"
	a.player.item_used = true
	ab.late_residual(a.player)
	check(a.player.item_used, "Harvest: item que não é frutinha não volta")
	a.free()


func _healer() -> void:
	var party := [Mon.create("pidgey", 30), Mon.create("rattata", 30)]
	var a := _arena(party, [Mon.create("geodude", 30)], {"seed": 5, "battle_size": 2})
	_run(a, 1.3)
	a.enemy.controller = "none"
	var ab: BattleAbilities = a.abilities
	if not (is_instance_valid(a.player) and is_instance_valid(a.ally)):
		check(false, "dupla em campo")
		a.free()
		return
	_give(a.player, "healer")
	var cured := 0
	for i in 200:
		a.ally.apply_status("burn", null)
		ab.late_residual(a.player)
		if a.ally.status == "":
			cured += 1
	check(cured > 30 and cured < 100, "Healer: ~30%% cura o status do aliado (%d/200)" % cured)
	a.free()
	# sozinho em campo: chance menor, no próprio status
	var b := _still()
	_give(b.player, "healer")
	var own := 0
	for i in 300:
		b.player.apply_status("burn", null)
		b.abilities.late_residual(b.player)
		if b.player.status == "":
			own += 1
	check(own > 5 and own < 70, "Healer sozinho: ~10%% cura o próprio status (%d/300)" % own)
	b.free()


func _liquid_ooze() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "liquid_ooze")
	var drain := Dex.move("mega_drain")
	a.player.hp = int(a.player.max_hp / 2.0)
	var h0: int = a.player.hp
	a.moves.hit(a.player, a.enemy, drain, Vector3.FORWARD)
	check(
		a.player.hp < h0, "Liquid Ooze: dreno tira HP de quem drena (%d -> %d)" % [h0, a.player.hp]
	)
	a.enemy.remove_meta("ability_override")
	a.enemy.heal(a.enemy.max_hp)
	a.player.hp = int(a.player.max_hp / 2.0)
	h0 = a.player.hp
	a.moves.hit(a.player, a.enemy, drain, Vector3.FORWARD)
	check(a.player.hp > h0, "sem Liquid Ooze o dreno cura (%d -> %d)" % [h0, a.player.hp])
	_give(a.enemy, "liquid_ooze")
	check(ab.ai_mult(a.player, a.enemy, drain) < 1.0, "Liquid Ooze: a IA desvaloriza o dreno")
	check(
		ab.ai_mult(a.player, a.enemy, Dex.move("tackle")) == 1.0, "Liquid Ooze: golpe comum igual"
	)
	var plain: float = a.moves.expected_damage(a.player, a.enemy, drain)
	a.enemy.remove_meta("ability_override")
	var normal: float = a.moves.expected_damage(a.player, a.enemy, drain)
	check(plain < normal, "Liquid Ooze: dano esperado do dreno cai para a IA")
	# Leech Seed no fim da rodada
	_give(a.enemy, "liquid_ooze")
	a.enemy.seeded = true
	a.enemy.leech_source = a.player
	a.player.heal(a.player.max_hp)
	var h1: int = a.player.hp
	a.end_turn.run()
	check(
		a.player.hp < h1,
		"Liquid Ooze: Leech Seed faz mal a quem plantou (%d -> %d)" % [h1, a.player.hp]
	)
	a.free()


func _mold_breaker() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "levitate")
	var eq := Dex.move("earthquake")
	check(ab.immune(a.player, a.enemy, eq), "sem Mold Breaker, Levitate segura o Terremoto")
	_give(a.player, "mold_breaker")
	check(not ab.immune(a.player, a.enemy, eq), "Mold Breaker: passa por cima do Levitate")
	_give(a.enemy, "thick_fat")
	check(
		ab.damage_mult(a.player, a.enemy, Dex.move("ember")) == 1.0,
		"Mold Breaker: ignora o Thick Fat"
	)
	_give(a.player, "")
	check(
		ab.damage_mult(a.player, a.enemy, Dex.move("ember")) == 0.5,
		"sem Mold Breaker o Thick Fat vale"
	)
	_give(a.enemy, "sturdy")
	var big: int = a.enemy.hp + 50
	check(
		ab.adjust_damage(a.player, a.enemy, Dex.move("tackle"), big) == a.enemy.hp - 1,
		"Sturdy segura"
	)
	_give(a.player, "mold_breaker")
	check(
		ab.adjust_damage(a.player, a.enemy, Dex.move("tackle"), big) == big,
		"Mold Breaker: ignora o Sturdy"
	)
	_give(a.enemy, "shell_armor")
	check(ab.no_crit(a.enemy), "Shell Armor sozinho bloqueia crítico")
	check(not ab.no_crit(a.enemy, a.player), "Mold Breaker: Shell Armor não bloqueia crítico")
	_give(a.enemy, "insomnia")
	check(ab.blocks_status(a.enemy, "sleep"), "Insomnia bloqueia sono")
	check(not ab.blocks_status(a.enemy, "sleep", a.player), "Mold Breaker: Insomnia não bloqueia")
	_give(a.enemy, "static")
	check(
		not ab.blocks_stage_drop(a.enemy, "atk", a.player),
		"habilidade de gatilho segue como estava"
	)
	a.free()


func _neutralizing_gas() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "intimidate")
	check(ab.ability_of(a.enemy) == "intimidate", "sem gás, a habilidade vale")
	_give(a.player, "neutralizing_gas")
	_run(a, 0.2)
	check(ab.ability_of(a.enemy) == "", "Neutralizing Gas: anula a habilidade dos outros")
	check(ab.ability_of(a.player) == "neutralizing_gas", "Neutralizing Gas: a dele continua")
	check(
		ab.damage_mult(a.player, a.enemy, Dex.move("tackle")) == 1.0,
		"habilidade anulada não mexe no dano"
	)
	a.player.set_meta("ability_override", "")  # o gás sai
	_run(a, 0.3)
	check(ab.ability_of(a.enemy) == "intimidate", "ao sair o gás, as habilidades voltam")
	check(
		int(a.player.stages.get("atk", 0)) == -1,
		"ao sair o gás, a Intimidate age de novo (atk %d)" % int(a.player.stages.get("atk", 0))
	)
	a.free()


func _overcoat() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "overcoat")
	var spore := Dex.move("spore")
	check(a.moves.effects.blocks_hit(a.player, a.enemy, spore), "Overcoat: imune a golpe de pó")
	_give(a.enemy, "")
	check(not a.moves.effects.blocks_hit(a.player, a.enemy, spore), "sem Overcoat o pó pega")
	_give(a.player, "overcoat")
	ab.set_weather("sand", 30.0)
	var h: int = a.player.hp
	ab.weather_residual(a.player)
	check(a.player.hp == h, "Overcoat: a areia não machuca")
	_give(a.player, "")
	ab.weather_residual(a.player)
	check(a.player.hp < h, "sem Overcoat a areia machuca")
	a.free()


func _poison_touch() -> void:
	var a := _still("pidgey", "rattata")
	var ab: BattleAbilities = a.abilities
	_give(a.player, "poison_touch")
	var tackle := Dex.move("tackle")
	var hits := 0
	for i in 200:
		a.enemy.clear_status()
		ab.on_hit(a.player, a.enemy, tackle, 5)
		if a.enemy.status == "poison":
			hits += 1
	check(hits > 30 and hits < 100, "Poison Touch: ~30%% envenena no contato (%d/200)" % hits)
	# golpe sem contato não envenena
	var none := 0
	for i in 100:
		a.enemy.clear_status()
		ab.on_hit(a.player, a.enemy, Dex.move("thunder_shock"), 5)
		if a.enemy.status == "poison":
			none += 1
	check(none == 0, "Poison Touch: golpe sem contato nunca envenena")
	a.free()


func _pressure() -> void:
	var a := _still()
	check(a.enemy.energy_mode, "arena em modo de energia")
	var tackle := Dex.move("tackle")
	a.enemy.position = a.player.position + Vector3(10, 0, 0)
	var base: float = a.enemy.pp_cost_of(tackle)
	_give(a.player, "pressure")
	check(a.enemy.pp_cost_of(tackle) == base, "Pressure: inimigo longe paga o custo normal")
	a.enemy.position = a.player.position + Vector3(2, 0, 0)
	check(
		a.enemy.pp_cost_of(tackle) == roundf(base * BattleAbilities.PRESSURE_COST),
		"Pressure: inimigo perto paga 25%% a mais (%f -> %f)" % [base, a.enemy.pp_cost_of(tackle)]
	)
	check(a.player.pp_cost_of(tackle) == base, "Pressure: ele mesmo paga o normal")
	var e0: float = a.enemy.pp_max
	a.enemy.pp_max = 100.0
	a.moves.use(a.enemy, "tackle")
	check(
		is_equal_approx(a.enemy.pp_max, 100.0 - roundf(base * BattleAbilities.PRESSURE_COST)),
		"Pressure: o golpe gasta o custo maior de verdade (%f)" % a.enemy.pp_max
	)
	check(e0 >= 0.0, "energia inicial lida")
	a.free()


func _rattled() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "rattled")
	ab.on_hit(a.player, a.enemy, Dex.move("tackle"), 5)
	check(int(a.enemy.stages.get("spe", 0)) == 0, "Rattled: golpe Normal não assusta")
	ab.on_hit(a.player, a.enemy, Dex.move("bite"), 5)
	check(int(a.enemy.stages.get("spe", 0)) == 1, "Rattled: golpe Sombrio dá Speed +1")
	ab.on_hit(a.player, a.enemy, Dex.move("bug_bite"), 5)
	check(int(a.enemy.stages.get("spe", 0)) == 2, "Rattled: golpe de Inseto dá Speed +1")
	_give(a.player, "intimidate")
	a.enemy.stages["spe"] = 0
	ab._do_intimidate(a.player)
	check(int(a.enemy.stages.get("spe", 0)) == 1, "Rattled: ser intimidado dá Speed +1")
	a.free()


func _scrappy() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	a.enemy.types = ["ghost"]
	var tackle := Dex.move("tackle")
	check(a.moves.expected_damage(a.player, a.enemy, tackle) == 0.0, "Fantasma é imune ao Normal")
	_give(a.player, "scrappy")
	check(
		a.moves.expected_damage(a.player, a.enemy, tackle) > 0.0, "Scrappy: Normal acerta Fantasma"
	)
	check(
		a.moves.expected_damage(a.player, a.enemy, Dex.move("karate_chop")) > 0.0,
		"Scrappy: Lutador acerta Fantasma"
	)
	check(
		a.moves.expected_damage(a.player, a.enemy, Dex.move("thunder_shock")) > 0.0,
		"outros tipos seguem normais"
	)
	check(
		not "ghost" in a.moves.effects.defender_profile(a.player, a.enemy, tackle).types,
		"Scrappy: o perfil do defensor perde o Fantasma"
	)
	var h: int = a.enemy.hp
	a.moves.hit(a.player, a.enemy, tackle, Vector3.FORWARD)
	check(a.enemy.hp < h, "Scrappy: o golpe causa dano de verdade")
	check(BattleAbilities.INTIMIDATE_PROOF.has("scrappy"), "Scrappy: imune à Intimidate")
	a.free()


func _synchronize() -> void:
	var a := _still("pidgey", "rattata")
	_give(a.enemy, "synchronize")
	check(a.enemy.apply_status("burn", a.player), "queimadura pega no Synchronize")
	check(a.player.status == "burn", "Synchronize: a queimadura volta para quem causou")
	a.player.clear_status()
	a.enemy.clear_status()
	a.enemy.apply_status("sleep", a.player)
	check(a.player.status == "", "Synchronize: sono não volta")
	a.enemy.clear_status()
	a.enemy.apply_status("paralysis", a.player)
	check(a.player.status == "paralysis", "Synchronize: paralisia volta")
	a.player.clear_status()
	a.enemy.clear_status()
	a.enemy.apply_status("poison", null)
	check(a.player.status == "", "Synchronize: status sem autor não volta")
	a.free()


func _trace() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "intimidate")
	_give(a.player, "trace")
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(ab.ability_of(a.player) == "intimidate", "Trace: copia a habilidade do inimigo")
	check(
		int(a.enemy.stages.get("atk", 0)) == -1,
		"Trace: a habilidade copiada age na hora (Intimidate no inimigo)"
	)
	a.free()
	var b := _still()
	_give(b.enemy, "trace")
	_give(b.player, "trace")
	b.abilities.on_enter(b.player)
	_run(b, 0.3)
	check(b.abilities.ability_of(b.player) == "trace", "Trace não copia Trace")
	b.free()


func _imposter() -> void:
	var a := _still("ditto", "charizard")
	var ab: BattleAbilities = a.abilities
	_give(a.player, "imposter")
	ab.on_enter(a.player)
	_run(a, 0.3)
	check(BattleTransform.is_transformed(a.player), "Imposter: Ditto vira cópia ao entrar")
	check(a.player.types == a.enemy.types, "Imposter: fica com os tipos do inimigo")
	a.free()


func _weak_armor() -> void:
	var a := _still()
	var ab: BattleAbilities = a.abilities
	_give(a.enemy, "weak_armor")
	ab.on_hit(a.player, a.enemy, Dex.move("thunder_shock"), 5)
	check(int(a.enemy.stages.get("def", 0)) == 0, "Weak Armor: golpe especial não conta")
	ab.on_hit(a.player, a.enemy, Dex.move("tackle"), 5)
	check(int(a.enemy.stages.get("def", 0)) == -1, "Weak Armor: físico baixa a Defesa")
	check(int(a.enemy.stages.get("spe", 0)) == 2, "Weak Armor: físico sobe a Speed +2")
	ab.on_hit(a.player, a.enemy, Dex.move("tackle"), 5)
	check(int(a.enemy.stages.get("spe", 0)) == 2, "Weak Armor: no máximo um gatilho por segundo")
	_run(a, BattleAbilities.ARMOR_GAP + 0.2)
	ab.on_hit(a.player, a.enemy, Dex.move("tackle"), 5)
	check(
		int(a.enemy.stages.get("spe", 0)) == 4, "Weak Armor: passado o intervalo, gatilha de novo"
	)
	a.free()


## Cada habilidade nova numa luta de IA contra IA curta: nada trava nem dá erro de script.
func _smoke() -> void:
	var done := 0
	for id in NEW:
		var m1 := Mon.create("pidgey", 22)
		var m2 := Mon.create("rattata", 22)
		var a := _arena([m1], [m2], {"seed": 91, "autoplay": true})
		_give(a.player, id)
		a.abilities.on_enter(a.player)
		_run(a, 6.0)
		check(is_instance_valid(a.player), "luta com %s roda sem travar" % id)
		done += 1
		a.free()
	check(done == NEW.size(), "luta curta com as %d habilidades" % NEW.size())
