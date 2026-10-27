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
	_official_numbers()
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


## Roda até a luta começar (o treinador tem a apresentação mais longa) e mais um pouco.
## Fora da trava de troca (BattleArena.switch_locked: começo da luta e logo depois de outra troca).
func _open(a: Node) -> void:
	a.fight_clock = maxf(float(a.fight_clock), float(a.SWITCH_OPEN))
	a.switch_lock = 0.0


func _fight(a: Node) -> void:
	var t := 0.0
	while a.state != "fight" and t < 10.0:
		a.step(DT)
		t += DT
	_run(a, 0.3)


## Mon com a habilidade `ab` (escolhe o slot da espécie que a tem).
func _mon(species: String, ab: String, lv := 10) -> Mon:
	var m := Mon.create(species, lv)
	var list: Array = Dex.species(m.species).get("abilities", [])
	check(ab in list, "%s tem %s" % [species, ab])
	m.ability_slot = maxi(list.find(ab), 0)
	return m


## Como _mon, mas empresta a habilidade à espécie se a geração atual não a dá a ninguém
## (Speed Boost, Prankster, Gale Wings saíram dos dados): só testa o efeito.
func _lent(species: String, ab: String, lv := 10) -> Mon:
	var list: Array = Dex.species(species).get("abilities", [])
	if not ab in list:
		list.append(ab)
	return _mon(species, ab, lv)


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
	# Defiant não segura: toma o -1 e reage com +2 (oficial)
	var c := _still(_mon("gyarados", "intimidate"), _mon("mankey", "defiant"))
	_run(c, 0.5)
	check(
		int(c.enemy.stages.get("atk", 0)) == 1,
		"Defiant contra Intimidate: -1 +2 = +1 (%d)" % int(c.enemy.stages.get("atk", 0))
	)
	c.free()


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
	b.abilities.on_round_end()
	check(e.hp > h0, "Regenerator cura um pouco no fim da rodada")
	b.free()
	# troca: Regenerator cura 1/3 do HP ao sair (oficial)
	var sw := _arena(
		[_mon("slowpoke", "regenerator"), Mon.create("pidgey", 10)],
		[Mon.create("rattata", 10)],
		{"seed": 7, "battle_size": 1}
	)
	_fight(sw)
	sw.enemy.controller = "none"
	var slow: BattleFighter = sw.player
	var sm: Mon = slow.mon
	slow.hp = int(slow.max_hp / 4.0)
	var hp_out := slow.hp
	_open(sw)
	check(sw.send_in(1), "troca para o segundo da party")
	sw.step(DT)
	check(
		sm.hp >= hp_out + int(sm.max_hp / 3.0),
		"Regenerator: +1/3 do HP ao sair (%d -> %d)" % [hp_out, sm.hp]
	)
	sw.free()


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
	var a := _still(_lent("pikachu", "speed_boost"), Mon.create("pidgey", 10))
	var ab: BattleAbilities = a.abilities
	var spe0 := int(a.player.stages.get("spe", 0))
	var r0 := ab.rounds
	ab.on_round_end()
	var after1 := int(a.player.stages.get("spe", 0))
	ab.on_round_end()
	var after2 := int(a.player.stages.get("spe", 0))
	if r0 == 0:
		check(after1 == spe0, "Speed Boost: nada na rodada em que entrou")
		check(after2 == spe0 + 1, "Speed Boost: +1 VEL no fim da rodada seguinte")
	else:
		check(after1 == spe0 + 1 and after2 == spe0 + 2, "Speed Boost: +1 VEL por rodada")
	a.free()
	# rodando a luta: um +1 a cada ROUND_SECS s (fora a rodada de entrada)
	var a2 := _still(_lent("pikachu", "speed_boost"), Mon.create("pidgey", 10))
	var s0 := int(a2.player.stages.get("spe", 0))
	var rr: int = a2.abilities.rounds
	_run(a2, BattleTurns.ROUND_SECS * 2.0 + 0.5)
	var got := int(a2.player.stages.get("spe", 0)) - s0
	var rounds_run: int = a2.abilities.rounds - rr
	check(
		rounds_run >= 2 and got >= rounds_run - 1 and got <= rounds_run,
		"Speed Boost na luta: +%d em %d rodadas" % [got, rounds_run]
	)
	a2.free()
	var b := _still(Mon.create("pidgey", 10), _mon("mankey", "defiant"))
	b.moves.change_stage(b.enemy, "atk", -1)
	_run(b, 0.2)
	check(
		int(b.enemy.stages.get("atk", 0)) == 1,
		"Defiant: -1 vira +2 (=%d)" % int(b.enemy.stages.get("atk", 0))
	)
	b.free()
	var c := _still(Mon.create("pidgey", 10), _lent("weezing", "clear_body"))
	c.moves.change_stage(c.enemy, "def", -2)
	_run(c, 0.2)
	check(int(c.enemy.stages.get("def", 0)) == 0, "Clear Body desfaz a queda")
	c.free()
	var d := _still(_lent("primeape", "moxie"), Mon.create("pidgey", 3))
	var foe: BattleFighter = d.enemy
	foe.hp = 1
	d.abilities.on_hit(d.player, foe, Dex.move("tackle"), 1)
	foe.hp = 0
	d.abilities.on_hit(d.player, foe, Dex.move("tackle"), 1)
	check(int(d.player.stages.get("atk", 0)) == 1, "Moxie: KO dá +1 ATK")
	d.free()
	var e := _still(_lent("shellder", "rough_skin"), Mon.create("pidgey", 10))
	var hp0: int = e.enemy.hp
	e.abilities.on_hit(e.enemy, e.player, Dex.move("tackle"), 1)
	check(e.enemy.hp <= hp0, "sem erro com Rough Skin")
	e.free()


func _helpers() -> void:
	var a := _still(_lent("butterfree", "prankster"), _mon("diglett", "arena_trap"))
	var ab: BattleAbilities = a.abilities
	check(ab.cast_speed_mult(a.player, Dex.move("sleep_powder")) > 1.0, "Prankster acelera status")
	check(ab.cast_speed_mult(a.player, Dex.move("tackle")) == 1.0, "Prankster só em status")
	check(ab.priority_bonus(a.player, Dex.move("sleep_powder")) == 1, "Prankster: +1 em status")
	check(ab.priority_bonus(a.player, Dex.move("tackle")) == 0, "Prankster: dano sem bônus")
	check(
		BattleTurns.priority_of(a.player, "sleep_powder") == 1,
		"BattleTurns.priority_of soma o Prankster"
	)
	check(ab.priority_bonus(a.enemy, Dex.move("sleep_powder")) == 0, "sem Prankster, sem bônus")
	a.enemy.types = ["dark"]
	check(
		ab.immune(a.player, a.enemy, Dex.move("sleep_powder")),
		"Prankster: status não pega em Sombrio"
	)
	check(not ab.immune(a.player, a.enemy, Dex.move("tackle")), "Prankster: dano pega em Sombrio")
	check(ab.profile_bias(a.player) == "trickster", "Prankster -> trickster")
	check(ab.walk_mult(a.player) < 1.0, "Arena Trap atrapalha o inimigo")
	check(ab.profile_bias(a.enemy) == "", "Arena Trap sem perfil")
	a.free()
	var b := _still(_lent("pidgey", "gale_wings"), _mon("goldeen", "swift_swim"))
	check(b.abilities.profile_bias(b.player) == "flyer", "Gale Wings -> flyer")
	check(b.abilities.walk_mult(b.enemy) == 1.0, "Swift Swim: sem chuva, normal")
	b.abilities.set_weather("rain", 10.0)
	check(b.abilities.walk_mult(b.enemy) > 1.0, "Swift Swim anda mais na chuva")
	check(
		b.abilities.cast_speed_mult(b.player, Dex.move("wing_attack")) > 1.0,
		"Gale Wings acelera voador"
	)
	check(b.abilities.acc_mult(b.player) == 1.0, "acc_mult neutro")
	check(
		b.abilities.priority_bonus(b.player, Dex.move("wing_attack")) == 1,
		"Gale Wings: +1 em voador com HP cheio"
	)
	check(b.abilities.order_speed_mult(b.enemy) == 2.0, "Swift Swim: Speed 2x na ordem (chuva)")
	b.player.hp = b.player.max_hp - 1
	check(
		b.abilities.priority_bonus(b.player, Dex.move("wing_attack")) == 0,
		"Gale Wings: sem HP cheio, sem prioridade"
	)
	b.free()
	# Quick Feet: 1,5x com status e sem o corte da paralisia na ordem
	var q := _still(_lent("rattata", "quick_feet"), Mon.create("pidgey", 10))
	var qf: BattleFighter = q.player
	check(q.abilities.order_speed_mult(qf) == 1.0, "Quick Feet: sem status, normal")
	qf.apply_status("paralysis", q.enemy)
	check(
		is_equal_approx(BattleTurns.order_speed(qf), qf.stat("spe") * 1.5),
		"Quick Feet: paralisado, 1,5x da Speed cheia na ordem"
	)
	q.free()
	# Unburden: 2x na ordem depois de usar o item
	var u := _still(_lent("magikarp", "unburden"), Mon.create("pidgey", 10))
	check(u.abilities.order_speed_mult(u.player) == 1.0, "Unburden: com item, normal")
	u.player.item_used = true
	check(u.abilities.order_speed_mult(u.player) == 2.0, "Unburden: usou o item, 2x na ordem")
	check(u.abilities.walk_mult(u.player) > 1.0, "Unburden: anda mais rápido")
	u.free()
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
		var ab: BattleAbilities = a.abilities
		var shock := Dex.move("thunder_shock")
		check(ab.redirect(a.enemy, other, shock) == rod, "Para-raios puxa o golpe de alvo único")
		check(
			ab.redirect(a.enemy, other, Dex.move("discharge")) == other,
			"Para-raios não puxa golpe de vários alvos (Discharge)"
		)
		check(ab.redirect(a.enemy, other, Dex.move("tackle")) == other, "Para-raios só elétrico")
		check(ab.immune(a.enemy, rod, shock), "Para-raios: imune ao elétrico")
		check(int(rod.stages.get("spa", 0)) == 1, "Para-raios: +1 At. Esp.")
		check(
			not ab.immune(a.enemy, other, shock),
			"o parceiro sozinho não é imune (o puxão é no redirect)"
		)
		# golpe de verdade (BattleMoves.hit) mirado no parceiro: o portador leva e absorve
		other.heal(other.max_hp)
		var hp_o := other.hp
		var spa0 := int(rod.stages.get("spa", 0))
		a.moves.hit(a.enemy, other, shock, Vector3.FORWARD)
		check(other.hp == hp_o, "hit: o parceiro não leva o Thunder Shock")
		check(int(rod.stages.get("spa", 0)) == spa0 + 1, "hit: o portador absorve (+1 At. Esp.)")
		a.moves.hit(a.enemy, other, Dex.move("discharge"), Vector3.FORWARD)
		check(other.hp < hp_o, "hit: Discharge (área) acerta o parceiro")
		var m: float = ab.damage_mult(a.enemy, rod, Dex.move("tackle"))
		check(m < 1.0 or ab.ability_of(other) != "friend_guard", "Friend Guard reduz dano")
		check(
			ab.damage_mult(a.enemy, other, Dex.move("tackle")) == 1.0,
			"Friend Guard não reduz o próprio dano"
		)
		# Telepathy: não leva golpe de dano do parceiro, mas leva o do inimigo
		other.set_meta("ability_override", "telepathy")
		check(ab.immune(rod, other, Dex.move("earthquake")), "Telepathy: imune ao parceiro")
		check(not ab.immune(a.enemy, other, Dex.move("tackle")), "Telepathy: inimigo acerta")
		other.remove_meta("ability_override")
	else:
		check(false, "dupla em campo")
	a.free()
	_plus_minus()
	_intimidate_doubles()
	_entry_order()


func _plus_minus() -> void:
	var party := [_lent("magnemite", "plus"), _lent("magneton", "minus")]
	var a := _arena(party, [Mon.create("pidgey", 10)], {"seed": 5, "battle_size": 2})
	_run(a, 1.3)
	a.enemy.controller = "none"
	if is_instance_valid(a.ally):
		var sp := Dex.move("thunder_shock")
		check(a.abilities.damage_mult(a.player, a.enemy, sp) == 1.5, "Plus/Minus: especial x1,5")
		check(
			a.abilities.damage_mult(a.player, a.enemy, Dex.move("tackle")) == 1.0,
			"Plus/Minus: físico normal"
		)
	else:
		check(false, "dupla Plus/Minus em campo")
	a.free()


## Intimidate no 2x2: -1 ATK nos dois inimigos, ao entrar e na troca.
func _intimidate_doubles() -> void:
	var foes := [Mon.create("pidgey", 10), Mon.create("rattata", 10)]
	var party := [
		_mon("gyarados", "intimidate"), Mon.create("pidgey", 10), _mon("ekans", "intimidate")
	]
	var a := _arena(party, foes, {"seed": 11, "battle_size": 2, "kind": "trainer"})
	_fight(a)
	var them: Array = a.targets_of(a.player)
	check(them.size() == 2, "dois inimigos em campo (%d)" % them.size())
	var all_down := true
	for t in them:
		t.controller = "none"
		if int(t.stages.get("atk", 0)) != -1:
			all_down = false
	check(all_down, "Intimidate: -1 ATK nos DOIS inimigos")
	# troca: o pidgey sai e o Ekans (Intimidate) entra no lugar
	var sub: BattleFighter = (
		a.ally if a.abilities.ability_of(a.player) == "intimidate" else a.player
	)
	var as_ally: bool = sub == a.ally
	_open(a)
	if not as_ally:
		check(a.send_in(2), "troca do controlado pelo Ekans")
	else:
		check(a.send_in(2, true), "troca do aliado pelo Ekans")
	_next_round(a)
	all_down = true
	for t in a.targets_of(a.player):
		if int(t.stages.get("atk", 0)) != -2:
			all_down = false
	check(all_down, "Intimidate na troca: mais -1 ATK nos dois (-2)")
	a.free()


## Ativação ao entrar em ordem pela Speed (do mais rápido ao mais lento) e o fim de rodada também.
func _entry_order() -> void:
	var fast := _mon("gyarados", "intimidate", 30)
	var slow := _mon("ekans", "intimidate", 5)
	var a := _arena(
		[slow, fast],
		[Mon.create("pidgey", 10), Mon.create("rattata", 10)],
		{"seed": 3, "battle_size": 2, "kind": "trainer"}
	)
	_fight(a)
	var order: Array = a.abilities.last_entry_order
	check(order.size() == 2, "os dois Intimidate ativaram (%d)" % order.size())
	if order.size() == 2:
		check(
			BattleTurns.order_speed(order[0]) >= BattleTurns.order_speed(order[1]),
			"Intimidate: o mais rápido ativa primeiro"
		)
		check(order[0].mon == fast, "Gyarados (mais rápido) antes do Ekans")
	a.abilities.on_round_end()
	var ro: Array = a.abilities.last_round_order
	var sorted_ok := true
	for i in range(1, ro.size()):
		if BattleTurns.order_speed(ro[i - 1]) < BattleTurns.order_speed(ro[i]):
			sorted_ok = false
	check(ro.size() == 4 and sorted_ok, "fim de rodada em ordem pela Speed")
	a.turns.toggle_trick_room()
	a.abilities.on_round_end()
	ro = a.abilities.last_round_order
	sorted_ok = true
	for i in range(1, ro.size()):
		if BattleTurns.order_speed(ro[i - 1]) > BattleTurns.order_speed(ro[i]):
			sorted_ok = false
	check(ro.size() == 4 and sorted_ok, "Trick Room inverte a ordem do fim de rodada")
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


## Números oficiais (o Caio pediu: só o dano final é escalado): Shell Armor/Battle Armor sem crítico,
## Sniper com crítico 2,25x, Skill Link sempre no máximo de acertos, Illuminate sem bônus de precisão.
func _official_numbers() -> void:
	var a := _still(_lent("squirtle", "shell_armor"), _lent("charmander", "sniper"))
	var me: BattleFighter = a.player
	var foe: BattleFighter = a.enemy
	check(a.abilities.no_crit(me), "Shell Armor bloqueia crítico")
	var crits := 0
	var mv := Dex.move("tackle")
	for i in 200:
		var res := Damage.compute(
			a.moves.effects.attacker_profile(foe, me, mv),
			a.moves.effects.defender_profile(foe, me, mv),
			mv.merged({"crit": 3}),
			a.rng
		)
		crits += 1 if res.crit else 0
	check(crits == 0, "Shell Armor: nenhum crítico mesmo com estágio +3 (%d)" % crits)
	check(is_equal_approx(a.abilities.crit_bonus(foe), 1.5), "Sniper: crítico 2,25x (1,5 x 1,5)")
	check(a.abilities.crit_bonus(me) == 1.0, "sem Sniper: crítico normal")
	check(
		is_equal_approx(a.abilities.damage_mult(me, foe, mv), 1.0),
		"Shell Armor não reduz mais o dano (sem o -10% inventado)"
	)
	a.free()
	var b := _still(_lent("rattata", "skill_link"), Mon.create("geodude", 10))
	var multi := {"id": "double_slap", "kind": "multi_arc", "hits_range": [2, 5], "power": 15}
	var all_max := true
	for i in 30:
		var r: Dictionary = b.moves.effects.roll_hits(multi, b.player)
		all_max = all_max and int(r.get("hits", 5)) == 5
	check(all_max, "Skill Link: sempre 5 acertos")
	b.free()
	var c := _still(_lent("venonat", "illuminate"), Mon.create("geodude", 10))
	check(c.abilities.acc_mult(c.player) == 1.0, "Illuminate sem bônus de precisão (Gen 9)")
	c.free()


## Rodadas: anda até a próxima rodada começar (troca sai no começo da rodada, substituto no fim) e mais
## `extra` s.
func _next_round(a: Node, extra := 0.2) -> void:
	var r: int = a.turns.round_n
	var t := 0.0
	while a.turns.round_n == r and t < 15.0:
		a.step(DT)
		t += DT
	_run(a, extra)
