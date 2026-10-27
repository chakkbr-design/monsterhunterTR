extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_gen9_abilities.gd
## Habilidades dos Pokémon 1-51 (geração atual) e o clima da arena.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_data()
	_weather_basics()
	_drought_and_speed()
	_sand()
	_rain_sun()
	_rivalry()
	_unaware()
	_wonder_skin()
	_magic_guard()
	_frisk_unnerve()
	_tangled_feet()
	_infiltrator()
	print("gen9 abilities: %d checks, %d falhas" % [_count, _fails])
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
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _mon(species: String, ab: String, lv := 20) -> Mon:
	var m := Mon.create(species, lv)
	var list: Array = Dex.species(m.species).get("abilities", [])
	check(ab in list, "%s tem %s" % [species, ab])
	m.ability_slot = maxi(list.find(ab), 0)
	return m


## Como _mon, mas empresta a habilidade à espécie se os dados oficiais não a dão a ela (Grimer e
## Poison Heal eram do jogo antes dos dados da Gen 9): só testa o efeito.
func _lent(species: String, ab: String, lv := 10) -> Mon:
	var list: Array = Dex.species(species).get("abilities", [])
	if not ab in list:
		list.append(ab)
	return _mon(species, ab, lv)


## Arena parada: o inimigo não age.
func _still(mine: Mon, foe: Mon, opts := {}) -> Node:
	opts["seed"] = 7
	var a := _arena([mine], [foe], opts)
	_run(a, 1.3)
	a.enemy.controller = "none"
	a.player.controller = "none"
	# investida longa já lançada termina antes de medir
	_run(a, 1.5)
	a.player.heal(a.player.max_hp)
	a.enemy.heal(a.enemy.max_hp)
	return a


func _data() -> void:
	var ids := {}
	for sp in Dex.all_species():
		var d := Dex.species(sp)
		if int(d.get("dex_no", 999)) <= 51:
			for id in d.get("abilities", []):
				ids[String(id)] = true
	check(ids.size() == 44, "44 habilidades nos Pokémon 1-51 (%d)" % ids.size())
	var bad := 0
	for id in ids:
		var d := Dex.ability(id)
		if (
			d.is_empty()
			or String(d.get("name", "")) != String(d.get("name", "")).to_upper()
			or String(d.get("desc", "")) == ""
			or String(d.get("desc_pt", "")) == ""
		):
			bad += 1
	check(bad == 0, "as 44 têm name em maiúsculas, desc e desc_pt (%d ruins)" % bad)


func _weather_basics() -> void:
	var a := _still(Mon.create("bulbasaur", 20), Mon.create("pidgey", 20))
	var ab: BattleAbilities = a.abilities
	check(ab.weather_now() == "", "sem clima por padrão")
	var ember := Dex.move("ember")
	check(ab.damage_mult(a.player, a.enemy, ember) == 1.0, "Fogo normal sem clima")
	ab.set_weather("sun", 2.0)
	check(ab.weather_now() == "sun", "set_weather sun")
	check(ab.damage_mult(a.player, a.enemy, ember) == 1.5, "sol: Fogo x1,5")
	check(ab.damage_mult(a.player, a.enemy, Dex.move("water_gun")) == 0.5, "sol: Água x0,5")
	_run(a, 2.2)
	check(ab.weather_now() == "", "o clima criado expira")
	ab.set_weather("sandstorm")
	check(ab.weather_now() == "sand", "apelido sandstorm = sand")
	a.free()
	var b := _still(Mon.create("bulbasaur", 20), Mon.create("pidgey", 20), {"weather": "rain"})
	check(b.abilities.weather_now() == "rain", "opts.weather da arena")
	check(
		b.abilities.damage_mult(b.player, b.enemy, Dex.move("water_gun")) == 1.5, "chuva: Água x1,5"
	)
	b.free()


func _drought_and_speed() -> void:
	var a := _still(_mon("ninetales", "drought"), _mon("oddish", "chlorophyll"))
	_run(a, 0.5)
	var ab: BattleAbilities = a.abilities
	check(ab.weather_now() == "sun", "Drought abre o sol ao entrar")
	check(ab.banners_shown >= 1 and ab.last_banner == "DROUGHT", "Drought mostra a faixa")
	check(ab.walk_mult(a.enemy) == 1.5, "Chlorophyll: x1,5 no sol (%f)" % ab.walk_mult(a.enemy))
	check(ab.cast_speed_mult(a.enemy, Dex.move("tackle")) == 1.5, "Chlorophyll: preparo x1,5")
	check(ab.order_speed_mult(a.enemy) == 2.0, "Chlorophyll: Speed 2x na ordem da rodada no sol")
	check(
		is_equal_approx(BattleTurns.order_speed(a.enemy), a.enemy.eff_spe() * 2.0),
		"BattleTurns.order_speed usa o Chlorophyll"
	)
	check(ab.order_speed_mult(a.player) == 1.0, "sem Chlorophyll, ordem normal")
	# Drought: 5 rodadas de sol
	for i in 4:
		ab.on_round_end()
	check(ab.weather_now() == "sun", "Drought: sol ainda na 4ª rodada")
	ab.on_round_end()
	check(ab.weather_now() == "", "Drought: o sol acaba depois de 5 rodadas")
	check(ab.walk_mult(a.enemy) == 1.0, "Chlorophyll: nada sem sol")
	check(ab.order_speed_mult(a.enemy) == 1.0, "Chlorophyll: ordem normal sem sol")
	a.free()
	var c := _still(Mon.create("pidgey", 20), _mon("psyduck", "cloud_nine"))
	c.abilities.set_weather("sun", 30.0)
	check(c.abilities.weather_now() == "", "Cloud Nine suprime o clima")
	check(
		c.abilities.damage_mult(c.player, c.enemy, Dex.move("ember")) == 1.0,
		"Cloud Nine: Fogo sem bônus de sol"
	)
	c.free()


func _sand() -> void:
	var a := _still(_mon("sandshrew", "sand_rush"), _mon("diglett", "sand_force"))
	var ab: BattleAbilities = a.abilities
	check(ab.walk_mult(a.player) == 1.0, "Sand Rush: sem areia, normal")
	ab.set_weather("sand", 30.0)
	check(ab.walk_mult(a.player) == 1.5, "Sand Rush: x1,5 na areia")
	check(ab.cast_speed_mult(a.player, Dex.move("tackle")) == 1.5, "Sand Rush: preparo x1,5")
	var mud := Dex.move("earthquake")
	check(ab.damage_mult(a.enemy, a.player, mud) == 1.3, "Sand Force: Terra x1,3 na areia")
	check(
		ab.damage_mult(a.enemy, a.player, Dex.move("tackle")) == 1.0,
		"Sand Force: só Pedra/Terra/Aço"
	)
	var h: int = a.player.hp
	check(ab.order_speed_mult(a.player) == 2.0, "Sand Rush: Speed 2x na ordem na areia")
	ab.on_round_end()
	_run(a, BattleTurns.ROUND_SECS + 0.5)
	check(
		a.player.hp == h and a.enemy.hp == a.enemy.max_hp,
		"Sand Rush/Force e tipo Terra não sofrem a areia"
	)
	a.free()
	var b := _still(_mon("sandshrew", "sand_veil"), Mon.create("pidgey", 20), {"damage_pace": 1.0})
	b.abilities.set_weather("sand", 30.0)
	_run(b, 1.0)
	check(b.player.evasion_t > 0.0 and b.player.evasion >= 0.2, "Sand Veil: esquiva na areia")
	b.free()
	# areia machuca quem não é imune
	var c := _still(Mon.create("pidgey", 20), _mon("paras", "dry_skin"), {"damage_pace": 1.0})
	c.abilities.set_weather("sand", 30.0)
	var pid: BattleFighter = c.player
	var h2 := pid.hp
	c.abilities.on_round_end()
	check(
		pid.hp == h2 - maxi(1, int(pid.max_hp / 16.0)),
		"areia tira 1/16 no fim da rodada de quem não é imune (%d -> %d)" % [h2, pid.hp]
	)
	# rodando a luta: tira de novo no fim da rodada, não a cada 2 s
	var h3 := pid.hp
	_run(c, 1.0)
	var mid := pid.hp
	_run(c, BattleTurns.ROUND_SECS + 0.5)
	check(pid.hp < h3, "areia: a luta chega ao fim da rodada (%d -> %d)" % [h3, pid.hp])
	check(mid >= h3 - maxi(1, int(pid.max_hp / 16.0)), "areia: no máx. um corte por rodada")
	c.free()
	# neve (Gen 9) não tira HP
	var d := _still(Mon.create("pidgey", 20), Mon.create("rattata", 20), {"damage_pace": 1.0})
	d.abilities.set_weather("snow", 30.0)
	var h4: int = d.player.hp
	d.abilities.on_round_end()
	check(d.player.hp == h4, "neve (hail) não tira HP na Gen 9")
	d.free()


func _rain_sun() -> void:
	var a := _still(_mon("squirtle", "rain_dish"), _mon("paras", "dry_skin"), {"damage_pace": 1.0})
	var ab: BattleAbilities = a.abilities
	a.player.hp = int(a.player.max_hp / 2.0)
	a.enemy.hp = int(a.enemy.max_hp / 2.0)
	var p0: int = a.player.hp
	var e0: int = a.enemy.hp
	ab.set_weather("rain", 30.0)
	ab.on_round_end()
	check(
		a.player.hp == p0 + maxi(1, int(a.player.max_hp / 16.0)),
		"Rain Dish cura 1/16 na chuva no fim da rodada"
	)
	check(
		a.enemy.hp == e0 + maxi(1, int(a.enemy.max_hp / 8.0)),
		"Dry Skin cura 1/8 na chuva no fim da rodada"
	)
	e0 = a.enemy.hp
	check(
		ab.immune(a.player, a.enemy, Dex.move("water_gun")) and a.enemy.hp > e0,
		"Dry Skin absorve Água"
	)
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, Dex.move("ember")), 0.625),
		"Dry Skin: Fogo causa mais (x1,25, chuva x0,5)"
	)
	ab.set_weather("sun", 30.0)
	e0 = a.enemy.hp
	ab.on_round_end()
	check(a.enemy.hp < e0, "Dry Skin perde HP no sol no fim da rodada")
	a.free()
	var b := _still(_mon("charmander", "solar_power"), Mon.create("pidgey", 20), {"damage_pace": 1.0})
	var ab2: BattleAbilities = b.abilities
	var ember := Dex.move("ember")
	var tackle := Dex.move("tackle")
	var no_sun: float = ab2.damage_mult(b.player, b.enemy, tackle)
	ab2.set_weather("sun", 30.0)
	check(
		ab2.damage_mult(b.player, b.enemy, ember) == 1.5 * 1.5,
		"Solar Power: especial x1,5 + sol x1,5"
	)
	check(ab2.damage_mult(b.player, b.enemy, tackle) == no_sun, "Solar Power só no especial")
	var h := int(b.player.hp)
	b.abilities.on_round_end()
	check(
		b.player.hp == h - maxi(1, int(b.player.max_hp / 8.0)),
		"Solar Power custa 1/8 no sol no fim da rodada"
	)
	b.free()
	_round_status()


## Fim de rodada: Poison Heal, Natural Cure, Shed Skin; Damp na explosão.
func _round_status() -> void:
	var a := _still(_lent("grimer", "poison_heal"), Mon.create("pidgey", 20), {"damage_pace": 1.0})
	var g: BattleFighter = a.player
	g.hp = int(g.max_hp / 2.0)
	g.status = ""
	g.apply_status("poison", a.enemy)
	var h := g.hp
	_run(a, 1.5)
	check(g.hp >= h, "Poison Heal: o veneno não tira HP (%d -> %d)" % [h, g.hp])
	h = g.hp
	a.abilities.on_round_end()
	check(g.hp == h + maxi(1, int(g.max_hp / 8.0)), "Poison Heal: +1/8 no fim da rodada")
	a.free()
	var b := _still(_mon("staryu", "natural_cure"), Mon.create("pidgey", 20), {"damage_pace": 1.0})
	b.player.apply_status("burn", b.enemy)
	check(b.player.status == "burn", "queimou")
	b.abilities.on_round_end()
	check(b.player.status == "", "Natural Cure: cura o status no fim da rodada")
	b.free()
	var c := _still(_mon("metapod", "shed_skin"), Mon.create("pidgey", 20))
	var n := 0
	for i in 60:
		c.player.clear_status()
		c.player.apply_status("paralysis", c.enemy)
		c.abilities.on_round_end()
		if c.player.status == "":
			n += 1
	check(n > 8 and n < 35, "Shed Skin: ~1/3 por rodada (%d/60)" % n)
	c.free()
	var d := _still(Mon.create("pidgey", 20), _mon("psyduck", "damp"))
	check(
		d.abilities.immune(d.enemy, d.player, Dex.move("self_destruct")),
		"Damp: ninguém explode em campo"
	)
	d.free()


func _rivalry() -> void:
	var a := _still(_mon("nidoking", "rivalry"), Mon.create("pidgey", 20))
	var tackle := Dex.move("tackle")
	a.player.mon.gender = "male"
	a.enemy.mon.gender = "male"
	check(a.abilities.damage_mult(a.player, a.enemy, tackle) == 1.25, "Rivalry: mesmo sexo x1,25")
	a.enemy.mon.gender = "female"
	check(a.abilities.damage_mult(a.player, a.enemy, tackle) == 0.75, "Rivalry: sexo oposto x0,75")
	a.enemy.mon.gender = ""
	check(a.abilities.damage_mult(a.player, a.enemy, tackle) == 1.0, "Rivalry: sem sexo x1")
	a.free()


func _unaware() -> void:
	var a := _still(_mon("clefable", "unaware"), Mon.create("pidgey", 20))
	var ab: BattleAbilities = a.abilities
	a.enemy.stages["def"] = 2
	var tackle := Dex.move("tackle")
	check(
		is_equal_approx(ab.damage_mult(a.player, a.enemy, tackle), 2.0),
		"Unaware: ignora Defesa +2 do alvo"
	)
	a.enemy.stages["def"] = 0
	a.enemy.stages["atk"] = 2
	check(
		is_equal_approx(ab.damage_mult(a.enemy, a.player, tackle), 0.5),
		"Unaware: ignora Ataque +2 de quem bate"
	)
	a.free()


func _wonder_skin() -> void:
	var a := _still(Mon.create("pidgey", 20), _mon("venomoth", "wonder_skin"))
	var st := {"id": "x", "type": "normal", "category": "status", "accuracy": 100}
	var n := 0
	for i in 200:
		if a.abilities.immune(a.player, a.enemy, st):
			n += 1
	check(n > 60 and n < 140, "Wonder Skin: ~50%% dos golpes de status falham (%d/200)" % n)
	check(not a.abilities.immune(a.player, a.enemy, Dex.move("tackle")), "Wonder Skin: dano normal")
	a.free()


func _magic_guard() -> void:
	var a := _still(_mon("clefairy", "magic_guard"), Mon.create("pidgey", 20))
	var f: BattleFighter = a.player
	f.apply_status("poison", a.enemy)
	var h := f.hp
	_run(a, 4.0)
	check(
		f.status == "poison" and f.hp == h, "Magic Guard: veneno não tira HP (%d -> %d)" % [h, f.hp]
	)
	a.free()
	var b := _still(Mon.create("rattata", 20), Mon.create("pidgey", 20))
	b.player.apply_status("poison", b.enemy)
	var h2: int = b.player.hp
	_run(b, 4.0)
	check(b.player.hp < h2, "controle: sem Magic Guard o veneno tira HP")
	b.free()


func _frisk_unnerve() -> void:
	var a := _arena([_mon("wigglytuff", "frisk")], [Mon.create("pidgey", 20)], {"seed": 3})
	_run(a, 1.5)
	check(a.abilities.last_banner == "FRISK", "Frisk mostra a faixa ao ver o inimigo")
	a.free()
	var b := _arena([_mon("ekans", "unnerve")], [Mon.create("pidgey", 20)], {"seed": 3})
	b.enemy.trainer_item = "potion"
	b.enemy.controller = "none"
	_run(b, 1.5)
	check(b.enemy.trainer_item == "", "Unnerve: o inimigo não usa o item")
	b.free()


func _tangled_feet() -> void:
	var a := _still(_mon("pidgey", "tangled_feet"), Mon.create("rattata", 20))
	a.player.confusion_t = 5.0
	_run(a, 0.3)
	check(a.player.evasion_t > 0.0 and a.player.evasion >= 0.2, "Tangled Feet: esquiva confuso")
	a.free()
	var b := _still(Mon.create("rattata", 20), Mon.create("pidgey", 20))
	b.player.confusion_t = 5.0
	_run(b, 0.3)
	check(b.player.evasion_t <= 0.0, "controle: sem Tangled Feet não esquiva")
	b.free()


func _infiltrator() -> void:
	var party := [_mon("zubat", "infiltrator"), Mon.create("pidgey", 20)]
	var foes := [Mon.create("pidgey", 20), _mon("clefairy", "friend_guard")]
	var a := _arena(party, foes, {"seed": 5, "battle_size": 2, "kind": "trainer"})
	_run(a, 1.3)
	var tgt: BattleFighter = null
	for t in a.targets_of(a.player):
		if a.abilities.ability_of(t) != "friend_guard":
			tgt = t
	check(tgt != null, "dupla inimiga em campo")
	if tgt != null:
		var tackle := Dex.move("tackle")
		check(
			a.abilities.damage_mult(a.player, tgt, tackle) == 1.0,
			"Infiltrator ignora o Friend Guard"
		)
		a.player.mon.ability_slot = 0
		check(
			a.abilities.damage_mult(a.player, tgt, tackle) == 0.75,
			"controle: sem Infiltrator o Friend Guard vale"
		)
	a.free()
