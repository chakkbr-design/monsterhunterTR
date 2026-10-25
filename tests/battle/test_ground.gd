extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_ground.gd
## Chão do modo de energia (BattleGround): lama (atola, enlameado, lama nova, seca no sol, espalha na
## chuva), marcas de golpe (fenda, gelo, brasas, poça), a maré da praia, a IA (Terra na lama, Fogo sai da
## maré, contorna a lama), o seletor do treino e o VGC sem nada disso.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const G := preload("res://battle/battle_ground.gd")

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_mud()
	_mud_new()
	_mud_weather()
	_vgc()
	_fissure()
	_ice()
	_ember()
	_puddle()
	_tide()
	_ai()
	_picker()
	print("ground: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, seed: int, extra := {}) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var o := Cfg.arena_opts(Cfg.default_config(), Vector3.ZERO)
	(
		o
		. merge(
			{
				"speed": 1.0,
				"seed": seed,
				"battle_size": 1,
				"telemetry": "user://test_ground_%d.json" % seed,
			},
			true
		)
	)
	o.merge(extra, true)
	a.start(party, enemies, o)
	a.step(DT)
	return a


func _put(a: Node, f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.ground_y = 0.0
	f.velocity = Vector3.ZERO


func _events(a: Node, kind: String) -> int:
	var c := 0
	for e in a.telemetry.events:
		if String(e.get("ev", "")) == kind:
			c += 1
	return c


## Ponto livre (sem relevo, lago, grama, lama nem marca) a pelo menos `gap` m de tudo.
func _open_spot(a: Node, gap := 1.5, skip := 0) -> Vector3:
	var t: BattleTerrain = a.terrain
	var n := 0
	for x in range(-10, 11):
		for z in range(-5, 6):
			var p := Vector3(x, 0, z)
			var ok := true
			for o in t.obstacles + t.grass + t.ground.mud + t.ground.marks:
				if (p - o.pos).length() < float(o.r) + gap:
					ok = false
			for o in a.field.objects:
				if (p - o.pos).length() < gap:
					ok = false
			if ok:
				if n == skip:
					return p
				n += 1
	return Vector3.INF


func _tick(a: Node, secs: float) -> void:
	for i in ceili(secs / 0.1 - 0.001):
		a.terrain.tick(0.1)


func _mud() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 3, {"scenario": "misto"}
	)
	var t: BattleTerrain = a.terrain
	var g: BattleGround = t.ground
	check(g.on, "chão ligado no modo de energia")
	check(g.mud.size() == int(G.MUD_COUNT.misto), "misto com %d lamas" % g.mud.size())
	var m: Dictionary = g.mud[0]
	var r: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	_put(a, r, m.pos)
	check(g.in_mud(r), "na lama")
	check(absf(t.move_mult(r) - G.MUD_MULT) < 0.001, "Normal atola (%.2f)" % t.move_mult(r))
	var s := _arena(
		[Mon.create("sandshrew", 50)], [Mon.create("grimer", 50)], 3, {"scenario": "misto"}
	)
	var m2: Dictionary = s.terrain.ground.mud[0]
	_put(s, s.player, m2.pos)
	_put(s, s.enemy, m2.pos)
	check(s.terrain.move_mult(s.player) == 1.0, "Terra não atola")
	check(s.terrain.move_mult(s.enemy) == 1.0, "Veneno não atola")
	s.free()
	# Enlameado ao sair.
	g.tick(0.1)
	_put(a, r, m.pos + Vector3(float(m.r) + 1.0, 0, 0))
	g.tick(0.1)
	check(float(g.muddy.get(r.get_instance_id(), 0.0)) > 0.0, "enlameado ao sair da lama")
	check(_events(a, "terrain_muddy") >= 1, "telemetria terrain_muddy")
	_put(a, p, r.position + Vector3(5, 0, 0))
	var k := g.acc_mult(r, Dex.move("water_gun"), p)
	check(absf(k - G.MUDDY_ACC) < 0.001, "enlameado erra mais de longe (%.2f)" % k)
	check(g.acc_mult(r, Dex.move("tackle"), p) == 1.0, "contato sem efeito")
	_tick(a, G.MUDDY_SECS + 0.3)
	check(not g.muddy.has(r.get_instance_id()), "enlameado passa")
	# A IA contorna a lama (quem atola).
	_put(a, r, m.pos + Vector3(-(float(m.r) + 1.0), 0, 0))
	var w: Vector3 = t.steer(r, Vector3(1, 0, 0))
	check(absf(w.z) > 0.2, "contorna a lama (%s)" % w)
	a.free()


func _mud_new() -> void:
	var a := _arena(
		[Mon.create("sandshrew", 50)], [Mon.create("rattata", 50)], 5, {"scenario": "pedreira"}
	)
	var g: BattleGround = a.terrain.ground
	check(g.mud.is_empty(), "pedreira sem lama")
	var spot := _open_spot(a)
	g.on_move_landed(a.player, Dex.move("mud_slap"), spot, 0.8)
	check(g.mud.size() == 1 and float(g.mud[0].t) == G.MUD_LIFE, "golpe de Terra abre lama nova")
	check(_events(a, "terrain_mud_new") == 1, "telemetria mud_new")
	_put(a, a.enemy, spot)
	check(absf(a.terrain.move_mult(a.enemy) - G.MUD_NEW_MULT) < 0.001, "lama nova atola menos")
	g.on_move_landed(a.player, Dex.move("mud_slap"), spot, 0.8)
	check(g.mud.size() == 1, "no mesmo lugar renova")
	for i in 5:
		var q := _open_spot(a, 1.5, i)
		if q != Vector3.INF:
			g.on_move_landed(a.player, Dex.move("mud_slap"), q, 0.8)
	check(g.mud.size() <= G.MUD_NEW_MAX, "limite de lama nova (%d)" % g.mud.size())
	_tick(a, G.MUD_LIFE + 0.5)
	check(g.mud.is_empty(), "lama nova some")
	# Água na poça vira lama.
	var q2 := _open_spot(a)
	g.on_move_landed(a.player, Dex.move("water_gun"), q2, 0.8)
	check(g.marks.size() == 1 and g.marks[0].kind == "puddle", "poça")
	g.on_move_landed(a.player, Dex.move("water_gun"), q2, 0.8)
	check(g.marks.is_empty() and g.mud.size() == 1, "água na poça vira lama")
	a.free()


func _mud_weather() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 7, {"scenario": "praia"}
	)
	var g: BattleGround = a.terrain.ground
	var m: Dictionary = g.mud[0]
	a.abilities.weather = "sun"
	_tick(a, G.MUD_DRY_SECS + 0.5)
	check(m.cracked, "sol seca a lama")
	check(_events(a, "terrain_mud_dry") >= 1, "telemetria mud_dry")
	_put(a, a.enemy, m.pos)
	check(not g.in_mud(a.enemy) and g.move_mult(a.enemy) != G.MUD_MULT, "chão rachado sem efeito")
	a.abilities.weather = "rain"
	_tick(a, 10.0)
	check(not m.cracked, "chuva molha de novo")
	check(float(m.r) > float(m.r0) + 0.2, "chuva espalha a lama (%.2f)" % float(m.r))
	a.abilities.weather = ""
	a.free()


func _vgc() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)],
		[Mon.create("rattata", 50)],
		3,
		{"scenario": "misto", "battle_mode": "vgc"}
	)
	var g: BattleGround = a.terrain.ground
	check(not g.on and g.mud.is_empty() and g.tide.is_empty(), "VGC: sem lama nem maré")
	g.on_move_landed(a.player, Dex.move("earthquake"), Vector3.ZERO, 4.0)
	check(g.marks.is_empty(), "VGC: sem marcas")
	a.free()
	var seen_energy := {}
	for s in range(1, 13):
		var b := _arena(
			[Mon.create("pikachu", 50)],
			[Mon.create("rattata", 50)],
			s,
			{"battle_mode": "vgc" if s % 2 else "energy"}
		)
		var vgc := s % 2 == 1
		check(
			not b.terrain.scenario in BattleTerrain.PICK_ONLY, "o sorteio não pega os só escolhidos"
		)
		if vgc:
			check(
				not b.terrain.scenario in BattleTerrain.VGC_SKIP,
				"o sorteio do VGC não pega a praia"
			)
		else:
			seen_energy[b.terrain.scenario] = true
		b.free()
	# No modo de energia a praia entra no sorteio.
	for s in range(100, 140):
		if seen_energy.has("praia"):
			break
		var b := _arena([Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], s, {})
		seen_energy[b.terrain.scenario] = true
		b.free()
	check(seen_energy.has("praia"), "energia: a praia sai no sorteio (%s)" % [seen_energy.keys()])


func _fissure() -> void:
	var a := _arena(
		[Mon.create("sandshrew", 50)], [Mon.create("pikachu", 50)], 9, {"scenario": "pedreira"}
	)
	var t: BattleTerrain = a.terrain
	var g: BattleGround = t.ground
	var u: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	var spot := _open_spot(a, 2.5)
	u.facing = Vector3(1, 0, 0)
	g.on_move_landed(u, Dex.move("earthquake"), spot, 4.5)
	var fz: Array = g.marks.filter(func(x): return x.kind == "fissure")
	check(fz.size() == 1, "Earthquake abre fenda")
	check(_events(a, "terrain_mark_fissure") == 1, "telemetria mark_fissure")
	check(
		absf((fz[0].b - fz[0].a).length() - G.FISSURE_LEN) < 0.01, "fenda de %.1f m" % G.FISSURE_LEN
	)
	_put(a, e, spot)
	check(not g.fissure_of(e).is_empty(), "na fenda")
	_put(a, u, spot + Vector3(5, 0, 0))
	var k: float = t.acc_mult(u, Dex.move("thunderbolt"), e)
	check(absf(k - (1.0 - G.FISSURE_EVADE)) < 0.01, "tiro de longe erra mais na fenda (%.2f)" % k)
	check(t.shot_block(u.position, e.position) < INF, "raio para na beira da fenda")
	_put(a, u, spot + Vector3(1.5, 0, 0))
	check(t.acc_mult(u, Dex.move("thunderbolt"), e) == 1.0, "colado enxerga")
	check(t.shot_block(u.position, e.position) == INF, "colado o raio passa")
	g.on_move_landed(u, Dex.move("mud_slap"), _open_spot(a, 2.5), 0.8)
	check(
		g.marks.filter(func(x): return x.kind == "fissure").size() == 1,
		"Terra fraca não abre fenda"
	)
	_tick(a, G.FISSURE_SECS + 0.3)
	check(g.marks.filter(func(x): return x.kind == "fissure").is_empty(), "fenda fecha")
	a.free()


func _ice() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 11, {"scenario": "pedreira"}
	)
	var t: BattleTerrain = a.terrain
	var g: BattleGround = t.ground
	var r: BattleFighter = a.enemy
	var spot := _open_spot(a, 2.0)
	g.on_move_landed(a.player, Dex.move("ice_beam"), spot, 0.8)
	check(g.marks.size() == 1 and g.marks[0].kind == "ice", "Gelo deixa chão escorregadio")
	check(_events(a, "terrain_mark_ice") == 1, "telemetria mark_ice")
	_put(a, r, spot)
	r.velocity = Vector3(3, 0, 0)
	t.settle(r, DT)
	var before := r.position
	r.velocity = Vector3.ZERO
	for i in 10:
		t.settle(r, DT)
	check(
		r.position.x - before.x > 0.2,
		"no gelo mantém o embalo (%.2f m)" % (r.position.x - before.x)
	)
	g.on_move_landed(a.player, Dex.move("ember"), spot, 0.8)
	check(g.marks.is_empty(), "Fogo derrete o gelo")
	g.on_move_landed(a.player, Dex.move("ice_beam"), spot, 0.8)
	a.abilities.weather = "sun"
	_tick(a, G.ICE_SECS / G.SUN_FAST + 0.3)
	check(g.marks.is_empty(), "sol derrete o gelo antes")
	a.abilities.weather = ""
	a.free()


func _ember() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)], [Mon.create("rattata", 50)], 13, {"scenario": "pedreira"}
	)
	var g: BattleGround = a.terrain.ground
	var r: BattleFighter = a.enemy
	var c: BattleFighter = a.player
	_put(a, r, _open_spot(a, 3.0, 3))
	var spot := _open_spot(a, 2.0)
	g.on_move_landed(c, Dex.move("flamethrower"), spot, 0.8)
	check(g.marks.size() == 1 and g.marks[0].kind == "ember", "Fogo deixa brasas")
	check(_events(a, "terrain_mark_ember") == 1, "telemetria mark_ember")
	var hp := r.hp
	_put(a, r, spot)
	g.tick(DT)
	check(r.hp < hp, "pisou nas brasas (%d -> %d)" % [hp, r.hp])
	check(_events(a, "terrain_ember_hit") == 1, "telemetria ember_hit")
	hp = r.hp
	g.tick(DT)
	check(r.hp == hp, "uma vez por brasa")
	_put(a, c, spot)
	var hc := c.hp
	g.marks[0].hit.clear()
	g.tick(DT)
	check(c.hp == hc, "Fogo não se queima")
	_tick(a, G.EMBER_SECS + 0.2)
	check(g.marks.is_empty(), "brasas apagam sozinhas")
	a.abilities.weather = "rain"
	g.on_move_landed(c, Dex.move("flamethrower"), spot, 0.8)
	check(g.marks.is_empty(), "na chuva o Fogo não deixa brasas")
	a.abilities.weather = ""
	g.on_move_landed(c, Dex.move("flamethrower"), spot, 0.8)
	a.abilities.weather = "rain"
	g.tick(0.1)
	check(g.marks.is_empty(), "chuva apaga as brasas")
	a.abilities.weather = ""
	a.free()


func _puddle() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 15, {"scenario": "pedreira"}
	)
	var g: BattleGround = a.terrain.ground
	var r: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	var spot := _open_spot(a, 2.0)
	g.on_move_landed(p, Dex.move("water_gun"), spot, 0.8)
	check(g.marks.size() == 1 and g.marks[0].kind == "puddle", "Água deixa poça")
	check(_events(a, "terrain_mark_puddle") == 1, "telemetria mark_puddle")
	_put(a, r, spot + Vector3(0.7, 0, 0))
	_put(a, p, spot + Vector3(6, 0, 0))
	var hp := r.hp
	g.on_move_landed(p, Dex.move("thunder_shock"), spot - Vector3(0.3, 0, 0), 0.5)
	check(r.hp < hp, "a poça conduz o Elétrico (%d -> %d)" % [hp, r.hp])
	check(_events(a, "terrain_conduct") >= 1, "telemetria conduct")
	a.abilities.weather = "rain"
	_tick(a, G.PUDDLE_SECS + 0.5)
	check(g.marks.size() == 1, "chuva alonga a poça")
	a.abilities.weather = "sun"
	_tick(a, G.PUDDLE_SECS / G.SUN_FAST + 0.5)
	check(g.marks.is_empty(), "sol seca a poça")
	a.abilities.weather = ""
	a.free()


func _tide() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 17, {"scenario": "praia"}
	)
	var t: BattleTerrain = a.terrain
	var g: BattleGround = t.ground
	check(t.scenario == "praia" and not g.tide.is_empty(), "praia com maré")
	check(g.tide.phase == "dry", "começa seca")
	var r: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	var band: Vector3 = g._perp() * float(g.tide.side) * 4.5
	var dry: Vector3 = -band
	_tick(a, G.TIDE_FIRST - G.TIDE_WARN + 0.2)
	check(g.tide.phase == "warn", "aviso antes da maré")
	_tick(a, G.TIDE_WARN)
	check(g.tide.phase == "in", "maré cheia")
	check(_events(a, "terrain_tide_in") == 1, "telemetria tide_in")
	_put(a, r, _clear(a, band))
	check(g.in_tide(r), "na água rasa")
	check(absf(t.move_mult(r) - G.TIDE_WADE) < 0.001, "anda devagar na água rasa")
	check(t.regen_mult(r) == BattleTerrain.WADE_REGEN, "energia como no lago")
	var k: float = t.damage_mult(p, r, Dex.move("thunder_shock"))
	check(absf(k - BattleTerrain.ELEC_WATER) < 0.001, "Elétrico 1,3x na maré")
	var c := _arena(
		[Mon.create("squirtle", 50)], [Mon.create("charmander", 50)], 17, {"scenario": "praia"}
	)
	var cg: BattleGround = c.terrain.ground
	for i in int((G.TIDE_FIRST + 0.2) / 0.1):
		c.terrain.tick(0.1)
	var ch: BattleFighter = c.enemy
	_put(c, ch, _clear(c, cg._perp() * float(cg.tide.side) * 4.5))
	_put(c, c.player, _clear(c, cg._perp() * float(cg.tide.side) * 4.5 + Vector3(2, 0, 0)))
	check(cg.in_tide(ch), "Fogo na maré")
	check(c.terrain.regen_mult(ch) == BattleTerrain.FIRE_WATER_REGEN, "Fogo recupera menos")
	check(c.terrain.regen_mult(c.player) == BattleTerrain.SWIM_REGEN, "Água recupera mais")
	var hp := ch.hp
	for i in 30:
		c.terrain.tick(0.1)
	check(ch.hp == hp, "maré sem dano no Fogo")
	var w: Vector3 = G.steer_ai(ch.ai, 5.0)
	check(w != Vector3.INF and ch.ai.tag == "leave_tide", "Fogo sai da maré")
	check(w.dot(cg._perp() * float(cg.tide.side)) < -0.5, "para o lado seco (%s)" % w)
	c.free()
	var side := int(g.tide.side)
	_tick(a, G.TIDE_IN)
	check(g.tide.phase == "dry" and _events(a, "terrain_tide_out") == 1, "maré baixa")
	check(int(g.tide.side) == -side, "alterna o lado")
	check(not g.in_tide(r), "seco de novo")
	# Areia seca: Terra camuflada.
	var s := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("sandshrew", 50)], 19, {"scenario": "praia"}
	)
	var sg: BattleGround = s.terrain.ground
	_put(s, s.enemy, _clear(s, sg._perp() * -float(sg.tide.side) * 4.0))
	_put(s, s.player, s.enemy.position + Vector3(5, 0, 0))
	var sk: float = s.terrain.acc_mult(s.player, Dex.move("thunder_shock"), s.enemy)
	check(absf(sk - (1.0 - G.SAND_EVADE)) < 0.01, "Terra camuflada na areia (%.2f)" % sk)
	s.free()
	a.free()


## Ponto perto de `want` (do mesmo lado da linha do meio comprida) sem relevo, grama, lama nem caixa.
func _clear(a: Node, want: Vector3) -> Vector3:
	var t: BattleTerrain = a.terrain
	var perp: Vector3 = t.ground._perp()
	var half := signf(want.dot(perp))
	var inner: Rect2 = a.rect.grow(-1.0)
	for rad in range(0, 8):
		for i in 12:
			var p := want + Vector3(cos(i * PI / 6.0), 0, sin(i * PI / 6.0)) * rad
			if not inner.has_point(Vector2(p.x, p.z)) or p.dot(perp) * half < 1.0:
				continue
			var ok := t.height_at(p) < 0.01
			for o in t.obstacles + t.grass + t.ground.mud:
				if (p - o.pos).length() < float(o.r) + 0.6:
					ok = false
			for o in a.field.objects:
				if (p - o.pos).length() < 1.0:
					ok = false
			if ok:
				return p
	return want


func _ai() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("sandshrew", 50)], 21, {"scenario": "praia"}
	)
	var g: BattleGround = a.terrain.ground
	var m: Dictionary = g.mud[0]
	var s: BattleFighter = a.enemy
	var p: BattleFighter = a.player
	var off := Vector3(1, 0, 0) if m.pos.x < 0.0 else Vector3(-1, 0, 0)
	_put(a, p, m.pos + off * (float(m.r) + 0.8))
	_put(a, s, m.pos - off * (float(m.r) + 2.5))
	s.opponent = p
	s.pp_max = 100.0
	s.ai.intent = "mud_slap"
	s.ai.recover_t = 0.0
	var w: Vector3 = G.steer_ai(s.ai, 5.0)
	check(w != Vector3.INF and s.ai.tag == "mud_fight", "Terra vai lutar na lama")
	check(w.dot(off) > 0.5, "para dentro da lama (%s)" % w)
	_put(a, s, m.pos)
	var w2: Vector3 = G.steer_ai(s.ai, 3.0)
	check(w2 != Vector3.INF and w2.length() < 0.35, "na lama fica")
	# Não fica para sempre.
	g._hold[s.get_instance_id()] = G.MUD_HOLD + 0.1
	check(G.steer_ai(s.ai, 3.0) == Vector3.INF, "depois de MUD_HOLD s segue a IA normal")
	check(G.steer_ai(s.ai, 3.0) == Vector3.INF, "e espera um pouco")
	# Quem não é de Terra não procura a lama.
	p.ai.intent = "thunder_shock"
	check(G.steer_ai(p.ai, 5.0) == Vector3.INF, "Elétrico não procura a lama")
	a.free()


func _picker() -> void:
	check(
		Cfg.SCENARIOS.has("praia") and Cfg.SCENARIO_NAMES.has("praia"), "Praia no seletor do treino"
	)
	check(BattleTerrain.SCENARIOS.has("praia"), "praia nos cenários")
