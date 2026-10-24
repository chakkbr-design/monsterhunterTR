extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_abilities.gd
## Habilidades em luta real (arena com step(dt) manual).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_data()
	_intimidate()
	_pinch()
	_immunities()
	_sturdy()
	_contact()
	_banner_throttle()
	_blocks()
	_stage_abilities()
	_helpers()
	_doubles()
	for i in 6:
		_full_battle(i)
	print("abilities: %d checks, %d falhas" % [_count, _fails])
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
	a.set_meta("got", {})
	if not opts.has("speed"):
		opts["speed"] = 1.0
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


## Mon com a habilidade `ab` (escolhe o slot da espécie que a tem).
func _mon(species: String, ab: String, lv := 10) -> Mon:
	var m := Mon.create(species, lv)
	var list: Array = Dex.species(m.species).get("abilities", [])
	check(ab in list, "%s tem %s" % [species, ab])
	m.ability_slot = maxi(list.find(ab), 0)
	return m


func _still(mine: Mon, foe: Mon) -> Node:
	var a := _arena([mine], [foe], {"seed": 7})
	_run(a, 1.3)
	a.enemy.controller = "none"
	return a


func _data() -> void:
	var ab := Dex.ability("static")
	check(ab.has("desc_pt") and ab.has("name"), "static com desc_pt")
	var bad := 0
	var nspecies := 0
	for sp in Dex.all_species():
		nspecies += 1
		var list: Array = Dex.species(sp).get("abilities", [])
		if list.is_empty() or list.size() > 3:
			bad += 1
		for id in list:
			var d := Dex.ability(String(id))
			if d.is_empty() or not d.has("desc_pt") or String(d.get("desc", "")) == "":
				bad += 1
	check(nspecies > 50 and bad == 0, "toda espécie tem 1-3 habilidades válidas (%d ruins)" % bad)
	var n := 0
	for id in BattleAbilities.PROFILES:
		if Dex.ability(id).is_empty():
			n += 1
	check(n == 0, "perfis só citam habilidades existentes")


func _intimidate() -> void:
	var a := _still(_mon("gyarados", "intimidate"), Mon.create("pidgey", 10))
	_run(a, 0.5)
	check(int(a.enemy.stages.get("atk", 0)) == -1, "Intimidate: -1 ATK no inimigo")
	check(a.abilities.banners_shown >= 1, "Intimidate mostra a faixa")
	a.free()
	# inimigo com Inner Focus resiste
	var b := _still(_mon("gyarados", "intimidate"), _mon("zubat", "inner_focus"))
	_run(b, 0.5)
	check(int(b.enemy.stages.get("atk", 0)) == 0, "Inner Focus segura Intimidate")
	b.free()


func _pinch() -> void:
	var a := _still(_mon("charmander", "blaze"), Mon.create("pidgey", 10))
	var p: BattleFighter = a.player
	var mv := Dex.move("ember")
	check(a.abilities.damage_mult(p, a.enemy, mv) == 1.0, "Blaze: sem bônus com HP cheio")
	p.hp = int(p.max_hp / 3.0)
	check(a.abilities.damage_mult(p, a.enemy, mv) == 1.5, "Blaze: x1.5 em pinch")
	check(a.abilities.damage_mult(p, a.enemy, Dex.move("tackle")) == 1.0, "Blaze só no fogo")
	a.free()
	var b := _still(Mon.create("pidgey", 10), _mon("slowpoke", "regenerator"))
	var e: BattleFighter = b.enemy
	e.hp = int(e.max_hp / 2.0)
	var h0 := e.hp
	_run(b, 3.2)
	check(e.hp > h0, "Regenerator cura devagar")
	b.free()


func _immunities() -> void:
	var a := _still(Mon.create("pidgey", 10), _mon("koffing", "levitate"))
	var ab: BattleAbilities = a.abilities
	check(ab.immune(a.player, a.enemy, Dex.move("earthquake")), "Levitate: imune a terra")
	check(not ab.immune(a.player, a.enemy, Dex.move("tackle")), "Levitate: normal acerta")
	a.free()
	var b := _still(Mon.create("pidgey", 10), _mon("poliwag", "water_absorb"))
	b.enemy.hp = 5
	check(b.abilities.immune(b.player, b.enemy, Dex.move("water_gun")), "Water Absorb imune")
	check(b.enemy.hp > 5, "Water Absorb cura")
	b.free()
	var c := _still(Mon.create("pidgey", 10), _mon("voltorb", "soundproof"))
	check(c.abilities.immune(c.player, c.enemy, Dex.move("screech")), "Soundproof: som")
	check(not c.abilities.immune(c.player, c.enemy, Dex.move("tackle")), "Soundproof: resto passa")
	c.free()


func _sturdy() -> void:
	var a := _still(Mon.create("pidgey", 10), _mon("geodude", "sturdy"))
	var e: BattleFighter = a.enemy
	var d: int = a.abilities.adjust_damage(a.player, e, Dex.move("tackle"), 9999)
	check(d == e.hp - 1, "Sturdy: sobrevive com 1 (dano %d)" % d)
	e.hp = e.max_hp - 1
	check(
		a.abilities.adjust_damage(a.player, e, Dex.move("tackle"), 9999) == 9999,
		"Sturdy: só com HP cheio"
	)
	a.free()


func _contact() -> void:
	var a := _still(Mon.create("pidgey", 10), _mon("pikachu", "static"))
	var p: BattleFighter = a.player
	var got := 0
	for i in 60:
		p.clear_status()
		a.abilities.on_hit(p, a.enemy, Dex.move("tackle"), 5)
		if p.status == "paralysis":
			got += 1
	check(got > 5 and got < 35, "Static ~30%% ao contato (%d/60)" % got)
	p.clear_status()
	for i in 60:
		a.abilities.on_hit(p, a.enemy, Dex.move("thunder_shock"), 5)
	check(p.status == "", "Static não age em golpe à distância")
	a.free()
	# determinismo com seed
	var r: Array = []
	for k in 2:
		var b := _still(Mon.create("pidgey", 10), _mon("pikachu", "static"))
		var n := 0
		for i in 30:
			b.player.clear_status()
			b.abilities.on_hit(b.player, b.enemy, Dex.move("tackle"), 5)
			if b.player.status != "":
				n += 1
		r.append(n)
		b.free()
	check(r[0] == r[1], "mesma seed, mesmo resultado (%s)" % str(r))


func _banner_throttle() -> void:
	var a := _still(Mon.create("pidgey", 10), _mon("koffing", "levitate"))
	var ab: BattleAbilities = a.abilities
	var n0 := ab.banners_shown
	for i in 10:
		ab.immune(a.player, a.enemy, Dex.move("earthquake"))
		a.step(DT)
	check(ab.banners_shown == n0 + 1, "faixa sem spam (%d)" % (ab.banners_shown - n0))
	_run(a, 3.2)
	ab.immune(a.player, a.enemy, Dex.move("earthquake"))
	check(ab.banners_shown == n0 + 2, "faixa volta após 3 s")
	a.free()


func _blocks() -> void:
	var a := _still(Mon.create("pidgey", 10), _mon("mankey", "vital_spirit"))
	check(a.abilities.blocks_status(a.enemy, "sleep"), "Vital Spirit bloqueia sono")
	check(not a.abilities.blocks_status(a.enemy, "burn"), "Vital Spirit não bloqueia queimadura")
	a.free()
	var b := _still(Mon.create("pidgey", 10), _mon("slowpoke", "own_tempo"))
	check(b.abilities.blocks_status(b.enemy, "confusion"), "Own Tempo bloqueia confusão")
	b.free()
	var c := _still(Mon.create("pidgey", 10), _mon("zubat", "inner_focus"))
	check(c.abilities.blocks_status(c.enemy, "flinch"), "Inner Focus bloqueia flinch")
	c.free()


func _stage_abilities() -> void:
	var a := _still(_mon("pikachu", "speed_boost"), Mon.create("pidgey", 10))
	_run(a, 8.5)
	check(int(a.player.stages.get("spe", 0)) == 1, "Speed Boost: +1 VEL em 8 s")
	a.free()
	var b := _still(Mon.create("pidgey", 10), _mon("mankey", "defiant"))
	b.moves.change_stage(b.enemy, "atk", -1)
	_run(b, 0.2)
	check(
		int(b.enemy.stages.get("atk", 0)) == 1,
		"Defiant: -1 vira +2 (=%d)" % int(b.enemy.stages.get("atk", 0))
	)
	b.free()
	var c := _still(Mon.create("pidgey", 10), _mon("weezing", "clear_body"))
	c.moves.change_stage(c.enemy, "def", -2)
	_run(c, 0.2)
	check(int(c.enemy.stages.get("def", 0)) == 0, "Clear Body desfaz a queda")
	c.free()
	var d := _still(_mon("primeape", "moxie"), Mon.create("pidgey", 3))
	var foe: BattleFighter = d.enemy
	foe.hp = 1
	d.abilities.on_hit(d.player, foe, Dex.move("tackle"), 1)
	foe.hp = 0
	d.abilities.on_hit(d.player, foe, Dex.move("tackle"), 1)
	check(int(d.player.stages.get("atk", 0)) == 1, "Moxie: KO dá +1 ATK")
	d.free()
	var e := _still(_mon("shellder", "rough_skin"), Mon.create("pidgey", 10))
	var hp0: int = e.enemy.hp
	e.abilities.on_hit(e.enemy, e.player, Dex.move("tackle"), 1)
	check(e.enemy.hp <= hp0, "sem erro com Rough Skin")
	e.free()


func _helpers() -> void:
	var a := _still(_mon("butterfree", "prankster"), _mon("diglett", "arena_trap"))
	var ab: BattleAbilities = a.abilities
	check(ab.cast_speed_mult(a.player, Dex.move("sleep_powder")) > 1.0, "Prankster acelera status")
	check(ab.cast_speed_mult(a.player, Dex.move("tackle")) == 1.0, "Prankster só em status")
	check(ab.profile_bias(a.player) == "trickster", "Prankster -> trickster")
	check(ab.walk_mult(a.player) < 1.0, "Arena Trap atrapalha o inimigo")
	check(ab.profile_bias(a.enemy) == "", "Arena Trap sem perfil")
	a.free()
	var b := _still(_mon("pidgey", "gale_wings"), _mon("goldeen", "swift_swim"))
	check(b.abilities.profile_bias(b.player) == "flyer", "Gale Wings -> flyer")
	check(b.abilities.walk_mult(b.enemy) > 1.0, "Swift Swim anda mais")
	check(
		b.abilities.cast_speed_mult(b.player, Dex.move("wing_attack")) > 1.0,
		"Gale Wings acelera voador"
	)
	check(b.abilities.acc_mult(b.player) == 1.0, "acc_mult neutro")
	b.free()
	var c := _still(_mon("butterfree", "compound_eyes"), Mon.create("pidgey", 10))
	check(c.abilities.acc_mult(c.player) > 1.2, "Compound Eyes")
	c.free()


func _doubles() -> void:
	var party := [_mon("pikachu", "lightning_rod"), _mon("clefairy", "friend_guard")]
	var a := _arena(party, [Mon.create("pidgey", 10)], {"seed": 5, "battle_size": 2})
	_run(a, 1.3)
	a.enemy.controller = "none"
	if is_instance_valid(a.player) and is_instance_valid(a.ally):
		var rod: BattleFighter = (
			a.player if a.abilities.ability_of(a.player) == "lightning_rod" else a.ally
		)
		var other: BattleFighter = a.ally if rod == a.player else a.player
		check(
			a.abilities.immune(a.enemy, other, Dex.move("thunder_shock")),
			"Para-raios cobre o parceiro"
		)
		check(int(rod.stages.get("spa", 0)) == 1, "Para-raios: +1 At. Esp.")
		var m: float = a.abilities.damage_mult(a.enemy, rod, Dex.move("tackle"))
		check(m < 1.0 or a.abilities.ability_of(other) != "friend_guard", "Friend Guard reduz dano")
	else:
		check(false, "dupla em campo")
	a.free()


func _full_battle(i: int) -> void:
	var pairs := [
		["pikachu", "geodude"],
		["gyarados", "pidgey"],
		["charizard", "venusaur"],
		["primeape", "onix"],
		["butterfree", "starmie"],
		["electrode", "golem"],
	]
	var pr: Array = pairs[i]
	var m1 := Mon.create(pr[0], 22)
	var m2 := Mon.create(pr[1], 22)
	m1.ability_slot = i % 3
	m2.ability_slot = (i + 1) % 3
	var a := _arena([m1], [m2], {"seed": 300 + i, "autoplay": true})
	var t := 0.0
	while a.state != "done" and t < 400.0:
		a.step(DT)
		t += DT
	var got: Dictionary = a.get_meta("got")
	check(a.state == "done" or t >= 400.0, "luta completa roda (%s)" % pr[0])
	print(
		(
			"  %s[%s] x %s[%s] em %.1f s, %d faixas"
			% [pr[0], m1.ability, pr[1], m2.ability, t, a.abilities.banners_shown]
		)
	)
	check(t < 400.0, "luta termina (%s x %s)" % [pr[0], pr[1]])
	a.free()
