extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_vgc_ai.gd
## IA no estilo VGC (docs/IA_VGC.md): escolha de golpe e alvo por pontuação (BattleTactics) e IA do
## treinador (BattleTrainerAI: troca, item, substituto).

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_wiring()
	_super_effective_target()
	_ko_first()
	_focus_and_overkill()
	_spread_and_partner()
	_protect()
	_tailwind()
	_paralysis()
	_helping_hand()
	_command()
	_switch()
	_item()
	_replacement()
	_switch_in_battle()
	print("vgc_ai: %d checks, %d falhas" % [_count, _fails])
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
	a.start(party, enemies, opts)
	return a


func _run(a: Node, secs: float) -> void:
	for i in int(round(secs / DT)):
		a.step(DT)


func _mons(list: Array, lv := 40) -> Array:
	return list.map(func(s): return Mon.create(String(s), lv))


## Dupla de treinador parada (ninguém anda nem bate sozinho): os testes chamam a IA na mão.
func _still2(mine: Array, theirs: Array, seed_n := 3, extra := {}) -> Node:
	var o := {
		"kind": "trainer", "battle_size": 2, "autoplay": true, "seed": seed_n, "no_rewards": true
	}
	o.merge(extra, true)
	var tai: bool = bool(o.get("trainer_ai", true))
	o["trainer_ai"] = false  # ninguém troca sozinho enquanto o teste monta a cena
	var a := _arena(_mons(mine), _mons(theirs), o)
	for i in int(3.0 / DT):
		a.step(DT)
		for f in a.fighters:
			f.controller = "none"  # ninguém luta enquanto a cena entra (sem acaso de quem bateu)
	if tai:
		a.trainer_ai = {0: BattleTrainerAI.new(a, 0), 1: BattleTrainerAI.new(a, 1)}
	for f in a.fighters:
		f.controller = "none"
		f.hp = f.max_hp
		f.clear_status()
	return a


func _side(a: Node, side: int) -> Array:
	return a.fighters.filter(func(f): return f.side == side and f.active())


func _named(a: Node, sp: String) -> BattleFighter:
	for f in a.fighters:
		if f.active() and f.mon.species == Dex.canon(sp):
			return f
	return null


## Melhor golpe/alvo sem ruído nem erro (think_scale baixo).
func _choose(f: BattleFighter, moves: Array) -> String:
	f.moves = moves
	f.ai.think_scale = 0.5
	f.ai.status_lock_t = 0.0
	f.ai.intent = ""
	var t: BattleTactics = f.ai._tactics()
	return t.choose(moves)


func _wiring() -> void:
	var a := _arena(
		_mons(["squirtle", "pidgey"]),
		_mons(["geodude", "rattata"]),
		{"kind": "trainer", "battle_size": 2, "autoplay": true}
	)
	_run(a, 2.0)
	check(a.trainer_ai.get(1) is BattleTrainerAI, "treinador adversário com IA de treinador")
	check(a.trainer_ai.get(0) is BattleTrainerAI, "sem teclado o lado do jogador também")
	check(a.player.ai._tactics() != null, "IA VGC ligada no treinador")
	a.free()
	var b := _arena(
		_mons(["squirtle", "pidgey"]),
		_mons(["geodude", "rattata"]),
		{
			"kind": "trainer",
			"battle_size": 2,
			"autoplay": true,
			"trainer_ai": false,
			"vgc_ai": false
		}
	)
	_run(b, 2.0)
	check(b.trainer_ai.is_empty(), "opts.trainer_ai false desliga")
	check(b.player.ai._tactics() == null, "opts.vgc_ai false desliga")
	b.free()
	var c := _arena(_mons(["squirtle"]), _mons(["rattata"]), {"kind": "wild", "seed": 2})
	_run(c, 2.0)
	check(c.enemy.ai._tactics() == null, "selvagem segue a IA antiga")
	check(c.trainer_ai.is_empty(), "selvagem sem IA de treinador")
	c.free()


func _super_effective_target() -> void:
	var a := _still2(["squirtle", "pidgey"], ["geodude", "rattata"])
	var me := _named(a, "squirtle")
	var id := _choose(me, ["water_gun", "tackle"])
	check(id == "water_gun", "golpe super efetivo (%s)" % id)
	check(me.opponent == _named(a, "geodude"), "mira quem toma 4x (Geodude)")
	a.free()


func _ko_first() -> void:
	var a := _still2(["charmander", "pidgey"], ["bulbasaur", "rattata"])
	var me := _named(a, "charmander")
	var rat := _named(a, "rattata")
	rat.hp = 3
	_named(a, "bulbasaur").hp = _named(a, "bulbasaur").max_hp
	var id := _choose(me, ["tackle"])
	check(id == "tackle" and me.opponent == rat, "derruba quem está para cair")
	a.free()


func _focus_and_overkill() -> void:
	var a := _still2(["charmander", "pidgey"], ["bulbasaur", "rattata"])
	var me := _named(a, "charmander")
	var p := _named(a, "pidgey")
	var bulb := _named(a, "bulbasaur")
	var rat := _named(a, "rattata")
	var mv := Dex.move("tackle")
	# O parceiro já derruba o Rattata sozinho: eu vou no outro.
	rat.hp = 2
	p.moves = ["tackle"]
	p.ai.intent = "tackle"
	p.opponent = rat
	_choose(me, ["tackle"])
	check(me.opponent == bulb, "não gasta golpe em quem o parceiro já derruba")
	# Nenhum derruba sozinho, os dois juntos sim: foco no mesmo alvo.
	var dm: float = a.moves.expected_damage(me, rat, mv, false)
	var dp: float = a.moves.expected_damage(p, rat, mv, false)
	rat.hp = int(maxf(dm, dp) + minf(dm, dp) * 0.5) + 1
	bulb.hp = int(bulb.max_hp * 0.6)
	_choose(me, ["tackle"])
	check(me.opponent == rat, "foca o alvo que os dois juntos derrubam")
	a.free()


func _spread_and_partner() -> void:
	var a := _still2(["sandshrew", "charmander"], ["rattata", "spearow"])
	var me := _named(a, "sandshrew")
	var id := _choose(me, ["earthquake", "scratch"])
	check(id == "scratch", "não usa Earthquake com o parceiro no chão levando dano (%s)" % id)
	a.free()
	var b := _still2(["sandshrew", "pidgey"], ["rattata", "ekans"])
	var me2 := _named(b, "sandshrew")
	var id2 := _choose(me2, ["earthquake", "scratch"])
	check(id2 == "earthquake", "Earthquake com o parceiro voando (%s)" % id2)
	b.free()


func _protect() -> void:
	var a := _still2(["bulbasaur", "pidgey"], ["charmander", "spearow"])
	var me := _named(a, "bulbasaur")
	for f in _side(a, 1):
		f.moves = ["ember", "peck"]
	me.hp = int(me.max_hp * 0.25)
	var t: BattleTactics = me.ai._tactics()
	var id := _choose(me, ["protect", "tackle"])
	check(id == "protect", "Protect com ameaça de KO (%s)" % id)
	me.ai.note_used("protect")
	check(t.protected_last_round(), "marca a rodada do Protect")
	id = _choose(me, ["protect", "tackle"])
	check(id == "tackle", "não usa Protect duas rodadas seguidas (%s)" % id)
	t.protect_round = -99
	me.hp = me.max_hp
	for f in _side(a, 1):
		f.moves = ["growl"]
	id = _choose(me, ["protect", "tackle"])
	check(id == "tackle", "sem ameaça ataca em vez de proteger (%s)" % id)
	a.free()


func _tailwind() -> void:
	var a := _still2(["pidgey", "bulbasaur"], ["rattata", "spearow"])
	var me := _named(a, "pidgey")
	var id := _choose(me, ["tailwind", "tackle"])
	check(id == "tailwind", "Tailwind com o lado mais lento (%s)" % id)
	a.moves.effects.self_move(me, Dex.move("tailwind"))
	check(a.moves.effects.side_active(me.side, "tailwind"), "Tailwind ligado")
	id = _choose(me, ["tailwind", "tackle"])
	check(id == "tackle", "Tailwind já ativo não repete (%s)" % id)
	a.free()


func _paralysis() -> void:
	var a := _still2(["pikachu", "bulbasaur"], ["diglett", "rattata"])
	var me := _named(a, "pikachu")
	var id := _choose(me, ["thunder_wave"])
	check(id == "thunder_wave", "Thunder Wave usado")
	check(me.opponent == _named(a, "rattata"), "Thunder Wave não mira o Terra")
	a.free()


func _helping_hand() -> void:
	var a := _still2(["clefairy", "charmander"], ["bulbasaur", "rattata"])
	var me := _named(a, "clefairy")
	var p := _named(a, "charmander")
	var bulb := _named(a, "bulbasaur")
	p.moves = ["ember"]
	p.ai.intent = "ember"
	p.opponent = bulb
	var pd: float = a.moves.expected_damage(p, bulb, Dex.move("ember"), false)
	bulb.hp = int(pd * 1.45)
	var id := _choose(me, ["helping_hand", "pound"])
	check(id == "helping_hand", "Helping Hand quando faz o parceiro derrubar (%s)" % id)
	a.free()


func _command() -> void:
	var a := _still2(["bulbasaur", "pidgey"], ["charmander", "spearow"])
	var me := _named(a, "bulbasaur")
	for f in _side(a, 1):
		f.moves = ["ember", "peck"]
	me.hp = int(me.max_hp * 0.25)
	var t: BattleTactics = me.ai._tactics()
	me.moves = ["protect", "tackle"]
	var ctx := {"foes": _side(a, 1), "p": me.ai.partner(), "threat": t.incoming(me) / me.hp}
	var scores := []
	for c in [BattleAI.FREE, BattleAI.ATTACK, BattleAI.DEFEND]:
		me.command = c
		if me == a.player:
			a.player_mode = c
		elif me == a.ally:
			a.ally_mode = c
		scores.append(float(t.score_move("protect", ctx).score))
	var free_s: float = scores[0]
	var att_s: float = scores[1]
	var def_s: float = scores[2]
	check(
		att_s < free_s and free_s < def_s,
		"comando pesa no Protect (%.2f %.2f %.2f)" % [att_s, free_s, def_s]
	)
	a.free()


func _switch() -> void:
	# Charmander contra dois de Água, com Bulbasaur no banco: troca.
	var a := _still2(["charmander", "pidgey", "bulbasaur"], ["squirtle", "psyduck"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	for f in _side(a, 1):
		f.moves = ["water_pulse"]
	var me := _named(a, "charmander")
	me.moves = ["scratch"]
	var c := tr.switch_for(me, _side(a, 1))
	check(not c.is_empty(), "matchup ruim: quer trocar")
	if not c.is_empty():
		check(a.bench_of(0)[int(c.idx)].species == "Bulbasaur", "entra quem resiste (Bulbasaur)")
	me.hp = int(me.max_hp * 0.3)
	check(tr.switch_for(me, _side(a, 1)).is_empty(), "com HP baixo fica e bate")
	me.hp = me.max_hp
	tr._swapped[me.mon] = a.turns.round_n
	check(tr.switch_for(me, _side(a, 1)).is_empty(), "sem ping-pong logo depois de trocar")
	a.free()


func _item() -> void:
	var a := _still2(["charmander", "pidgey"], ["rattata", "spearow"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	var me := _named(a, "charmander")
	me.trainer_item = "super_potion"
	me.item_used = false
	for f in _side(a, 1):
		f.moves = ["tackle"]
	me.hp = int(me.max_hp * 0.3)
	check(tr.item_for(me) == "super_potion", "cura com HP baixo quando sobrevive")
	for f in _side(a, 1):
		f.moves = ["hyper_fang", "tackle"]
		f.stages["atk"] = 6
	me.hp = 2
	check(tr.item_for(me) == "", "não cura quem cai na rodada mesmo curado")
	me.hp = me.max_hp
	check(tr.item_for(me) == "", "HP cheio sem item")
	me.trainer_item = "paralyze_heal"
	me.status = "paralysis"
	if not Dex.item("paralyze_heal").is_empty():
		check(tr.item_for(me) == "paralyze_heal", "cura paralisia")
	a.free()


func _replacement() -> void:
	var a := _still2(["charmander", "pidgey", "rattata", "bulbasaur"], ["squirtle", "psyduck"])
	var tr: BattleTrainerAI = a.trainer_ai[0]
	for f in _side(a, 1):
		f.moves = ["water_gun"]
	var k := tr.pick_replacement(0)
	var bench: Array = a.bench_of(0)
	check(
		k >= 0 and bench[k].species == "Bulbasaur",
		"substituto: o que resiste e bate (%s)" % (bench[k].species if k >= 0 else "-")
	)
	a.free()


## Luta de verdade (rodadas): o treinador troca o Charmander que só apanharia.
func _switch_in_battle() -> void:
	var a := _arena(
		_mons(["squirtle", "psyduck"]),
		_mons(["charmander", "spearow", "bulbasaur"]),
		{"kind": "trainer", "battle_size": 2, "seed": 4, "no_rewards": true, "autoplay": true}
	)
	_run(a, 3.0)
	for f in _side(a, 0):
		f.moves = ["water_pulse"]
		f.controller = "none"  # só ameaçam: o Charmander não cai antes de o treinador decidir
	var ch := _named(a, "charmander")
	if ch != null:
		ch.moves = ["scratch"]
	for f in _side(a, 1):
		f.controller = "none"  # a decisão é do treinador; ninguém cai enquanto isso
	var tr: BattleTrainerAI = a.trainer_ai[1]
	check(
		ch != null and not tr.switch_for(ch, _side(a, 0)).is_empty(), "Charmander em matchup ruim"
	)
	for k in 20:  # a decisão tem chance (nível da IA); tenta até pedir
		if tr.switches > 0:
			break
		tr.round_start()
	check(tr.switches == 1 and not a.pending_switch(1).is_empty(), "pediu a troca na arena")
	var r: int = a.turns.round_n
	var t := 0.0
	while a.turns.round_n <= r + 1 and t < 20.0:
		a.step(DT)
		t += DT
	check(ch != null and not ch.on_field, "o Charmander saiu no começo da rodada")
	check(_side(a, 1).any(func(f): return f.mon.species == "Bulbasaur"), "entrou o Bulbasaur")
	a.free()
