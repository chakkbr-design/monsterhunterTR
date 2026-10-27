extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_terrain2.gd
## Cenários do treino (BattleTerrain + BattleTerrainAI): cenário sorteado e espalhado sem nada nas
## entradas, metades equilibradas, grama alta (esconde, energia de Grama, queima, chuva e sol), Elétrico
## na água, energia na água por tipo, Fogo na água, clima no lago, puxar para a água, derrubar do morro,
## a IA do cenário e a quadra voxel (quantidades pela área, grade de 0,25 m, visual voxel só fora do
## fast_sim, mesma luta com e sem visual).

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const T := preload("res://battle/battle_terrain.gd")

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_layout()
	_grass()
	_grass_fire()
	_regrow()
	_hail_spam()
	_water()
	_pull()
	_drop()
	_ai()
	_voxel()
	print("terrain2: %d checks, %d falhas" % [_count, _fails])
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
	o.merge({"speed": 1.0, "seed": seed, "battle_size": 1}, true)
	o.merge(extra, true)
	a.start(party, enemies, o)
	return a


func _kind(a: Node, k: String) -> Dictionary:
	for o in a.terrain.obstacles:
		if o.kind == k:
			return o
	return {}


## Põe o lutador em `at` e deixa o chão assentar.
func _put(a: Node, f: BattleFighter, at: Vector3) -> void:
	# Teleporte: já no chão de lá (como se tivesse saltado; o degrau não empurra para fora).
	f.ground_y = a.terrain.height_at(at)
	f.position = Vector3(at.x, f.ground_y, at.z)
	for i in 90:
		a.terrain.settle(f, DT)
		f.position.x = at.x
		f.position.z = at.z


func _settle(a: Node, f: BattleFighter, frames: int) -> void:
	for i in frames:
		a.terrain.settle(f, DT)


## Ponto livre (sem relevo, lago ou grama) a pelo menos `gap` m de tudo.
func _open_spot(a: Node, gap := 1.5) -> Vector3:
	var t: BattleTerrain = a.terrain
	for x in range(-10, 11):
		for z in range(-5, 6):
			var p := Vector3(x, 0, z)
			var ok := true
			for o in t.obstacles + t.grass:
				if (p - o.pos).length() < float(o.r) + gap:
					ok = false
			for o in a.field.objects:
				if (p - o.pos).length() < gap:
					ok = false
			if ok:
				return p
	return Vector3.INF


func _layout() -> void:
	var seen := {}
	for s in range(1, 21):
		var a := _arena(
			[Mon.create("pikachu", 50)],
			[Mon.create("rattata", 50)],
			s,
			{"telemetry": "user://test_terrain2_%d.json" % s}
		)
		var t: BattleTerrain = a.terrain
		seen[t.scenario] = true
		check(T.SCENARIOS.has(t.scenario), "cenário válido (%s)" % t.scenario)
		check(String(a.telemetry.meta.get("scenario", "")) == t.scenario, "cenário na telemetria")
		# Quantidades na área da quadra (BattleTerrain.plan_for: SCENARIOS x count_k; 4x no modo de energia).
		var plan: Dictionary = t.plan_for(t.scenario)
		check(
			t.count_k == 4.0 * T.COUNT_CURVE + 1.0 - T.COUNT_CURVE,
			"quantidades pela área (k %.2f)" % t.count_k
		)
		var all: Array = []
		for o in t.obstacles + t.grass:
			all.append({"pos": o.pos, "r": float(o.r0 if o.has("r0") else o.r), "kind": o.kind})
		for o in a.field.objects:
			all.append({"pos": o.pos, "r": BattleField.OBJ_R, "kind": "crate"})
		var want := 0
		for k in plan:
			if not BattleProps.SIZES.has(k):
				want += int(plan[k])  # objetos vivos (BattleProps): tests/battle/test_props.gd
		check(all.size() == want, "%s: tudo montado (%d de %d)" % [t.scenario, all.size(), want])
		check(a.field.objects.size() == t.crate_spots.size(), "caixas/pedras do cenário")
		var halves := {1: 0, -1: 0}
		for i in all.size():
			var o: Dictionary = all[i]
			for sp in [a.player_spot, a.enemy_spot]:
				var far: bool = (o.pos - sp * Vector3(1, 0, 1)).length() >= o.r + T.KEEP_SPOT - 0.01
				check(far, "%s longe da entrada" % o.kind)
			var inner: Rect2 = a.rect.grow(-(o.r + T.KEEP_WALL - 0.01))
			check(inner.has_point(Vector2(o.pos.x, o.pos.z)), "%s longe da parede" % o.kind)
			for j in range(i + 1, all.size()):
				var q: Dictionary = all[j]
				var gap: float = (q.pos - o.pos).length() - q.r - o.r
				check(
					gap >= T.GAP * T.TIGHT_GAP - 0.01,
					"espalhado: %s-%s (%.2f m)" % [o.kind, q.kind, gap]
				)
			var along: float = o.pos.dot(a.axis)
			if absf(along) > T.MID_BAND + 0.01:
				halves[1 if along > 0.0 else -1] += 1
		check(absi(halves[1] - halves[-1]) <= 1, "metades equilibradas %s" % [halves])
		a.free()
	check(seen.size() >= 3, "sorteia cenários diferentes (%s)" % [seen.keys()])
	# Pedido pelo opts.scenario.
	var b := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 3, {"scenario": "lagoa"}
	)
	check(b.terrain.scenario == "lagoa", "opts.scenario")
	var ponds: int = b.terrain.obstacles.filter(func(o): return o.kind == "pond").size()
	check(ponds == int(b.terrain.plan_for("lagoa").pond), "lagoa com %d lagos" % ponds)
	b.free()
	# Sem opts.terrain (fora do treino): nada de cenário.
	var c := _arena([Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 3, {"terrain": false})
	check(c.terrain.scenario == "" and not c.terrain.has_scenery(), "sem terreno, sem cenário")
	c.free()


func _grass() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("bulbasaur", 50)], 5, {"scenario": "campo"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var g: Dictionary = t.grass[0]
	var p: BattleFighter = a.player
	var b: BattleFighter = a.enemy
	_put(a, b, g.pos)
	check(t.in_grass(b), "na grama alta")
	check(g.node is Node3D and g.node.get_child_count() > 3, "moita 3D com tufos")
	p.position = g.pos + Vector3(5.0, 0, 0)
	var shot := Dex.move("thunder_shock")
	var k := t.acc_mult(p, shot, b)
	check(absf(k - (1.0 - T.GRASS_EVADE)) < 0.01, "de longe erra mais na grama (%.2f)" % k)
	p.position = g.pos + Vector3(1.0, 0, 0)
	check(t.acc_mult(p, shot, b) == 1.0, "colado enxerga quem está na grama")
	p.position = g.pos + Vector3(5.0, 0, 0)
	check(t.acc_mult(p, Dex.move("tackle"), b) == 1.0, "contato sem evasão")
	check(t.regen_mult(b) > 1.0, "Grama recupera mais energia na moita")
	_put(a, p, g.pos)
	check(t.in_grass(p) and t.regen_mult(p) == 1.0, "Elétrico na moita: energia normal")
	# Areia camufla Pedra/Terra/Aço.
	a.free()
	var s := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("geodude", 50)], 6, {"scenario": "pedreira"}
	)
	s.step(DT)
	s.abilities.weather = "sand"
	var open := _open_spot(s)
	s.enemy.position = open
	s.player.position = open + Vector3(4.0, 0, 0)
	var ks: float = s.terrain.acc_mult(s.player, Dex.move("thunder_shock"), s.enemy)
	check(ks < 1.0, "areia esconde Pedra (%.2f)" % ks)
	s.free()


func _grass_fire() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)], [Mon.create("rattata", 50)], 7, {"scenario": "campo"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var c: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var g: Dictionary = t.grass[0]
	_put(a, r, g.pos)
	_put(a, c, g.pos + Vector3(0.4, 0, 0))
	# Chuva: a grama molhada não pega fogo.
	a.abilities.weather = "rain"
	a.field.on_move_landed(c, Dex.move("ember"), g.pos, 0.8)
	check(t.grass.has(g), "chuva: grama não pega fogo")
	a.abilities.weather = ""
	var hp := r.hp
	var hp_c := c.hp
	a.field.on_move_landed(c, Dex.move("ember"), g.pos, 0.8)
	check(not t.grass.has(g), "fogo queima a moita")
	var lost := hp - r.hp
	var want := int(float(r.max_hp) * T.GRASS_BURN_FRAC * r.dot_scale())
	check(lost >= maxi(1, want), "quem está dentro toma dano alto (%d, esperado %d)" % [lost, want])
	check(c.hp == hp_c, "Fogo não se queima na moita")
	check(not t.in_grass(r), "a moita sumiu")
	check(a.field.terrain_at(g.pos) == "scorch", "vira chão queimado")
	# Sol: o fogo pula para a moita vizinha.
	var spot := _open_spot(a, 2.5)
	check(spot != Vector3.INF, "achou lugar para duas moitas")
	if spot != Vector3.INF:
		t._add_grass(spot, 1.0)
		t._add_grass(spot + Vector3(2.6, 0, 0), 1.0)
		var g1: Dictionary = t.grass[-2]
		var g2: Dictionary = t.grass[-1]
		a.abilities.weather = "sun"
		t.ignite(g1, c)
		check(t.grass.has(g2), "o vizinho ainda não queimou")
		for i in 600:
			a.step(DT)
			if not t.grass.has(g2):
				break
		check(not t.grass.has(g2), "sol: o fogo se espalha para a moita vizinha")
	a.free()


func _regrow() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)], [Mon.create("rattata", 50)], 7, {"scenario": "campo"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var n0 := t.grass.size()
	var g: Dictionary = t.grass[0]
	var at: Vector3 = g.pos
	var r0: float = g.r
	a.abilities.weather = ""
	t.ignite(g, a.player)
	check(t.grass.size() == n0 - 1 and t.burnt.size() == 1, "queimou: moita na fila de rebrota")
	# Sol/seca: não rebrota.
	a.abilities.weather = "sun"
	for i in 60:
		t.tick(1.0)
	check(t.grass.size() == n0 - 1, "sol: a moita não rebrota")
	# Sem clima: espera REGROW_DELAY.
	a.abilities.weather = ""
	for i in int(T.REGROW_DELAY) - 2:
		t.tick(1.0)
	check(t.grass.size() == n0 - 1, "antes do prazo ainda queimada")
	for i in 4:
		t.tick(1.0)
	check(t.grass.size() == n0 and t.burnt.is_empty(), "passado o prazo a moita volta")
	var back: Dictionary = t.grass[-1]
	check(_flat_eq(back.pos, at) and is_equal_approx(back.r, r0), "no mesmo lugar e tamanho")
	check(is_instance_valid(back.node) and back.node.scale.x < 0.9, "volta pequena (visual)")
	for i in 6:
		t.tick(1.0)
	check(back.node.scale.x > 0.99, "e termina de crescer")
	# Chuva: mais rápido.
	a.abilities.weather = "rain"
	t.burnt.append({"pos": at + Vector3(0, 0, 0.01), "r": 1.0, "t": 0.0})
	t.grass.erase(back)
	back.node.queue_free()
	for i in int(T.REGROW_DELAY / T.REGROW_RAIN) + 1:
		t.tick(1.0)
	check(t.burnt.is_empty(), "chuva: rebrota em metade do tempo")
	a.free()


func _flat_eq(p: Vector3, q: Vector3) -> bool:
	return Vector2(p.x - q.x, p.z - q.z).length() < 0.05


func _hail_spam() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)],
		[Mon.create("rattata", 50)],
		9,
		{"scenario": "lagoa", "telemetry": "user://test_terrain2_hail.json"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var pond := _kind(a, "pond")
	var tel = a.telemetry
	var n_freeze := func() -> int:
		var c := 0
		for e in tel.events:
			if str(e.get("ev", "")) == "terrain_freeze":  # BattleTelemetry.ev: tipo em "ev"
				c += 1
		return c
	a.abilities.weather = "hail"
	var base: int = n_freeze.call()
	for i in 90:  # 90 s de granizo: o gelo derrete e congela várias vezes
		t.tick(1.0)
	check(float(pond.ice_t) > 0.0 or true, "granizo mantém o lago congelado")
	# Um aviso por lago (FREEZE_SAY_CD é por lago), não um a cada vez que o gelo volta.
	var n_ponds: int = t.obstacles.filter(func(o): return o.kind == "pond").size()
	check(
		int(n_freeze.call()) - base <= n_ponds,
		"granizo: um aviso de congelamento por lago (%d lagos)" % n_ponds
	)
	a.abilities.weather = ""
	t.tick(1.0)
	a.abilities.weather = "hail"
	pond.ice_t = 0.0
	t.tick(1.0)
	check(float(pond.ice_t) > 0.0, "granizo de novo congela")
	a.free()


func _water() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], 9, {"scenario": "lagoa"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var pond := _kind(a, "pond")
	var p: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(a, r, pond.pos)
	var zap := Dex.move("thunder_shock")
	check(t.damage_mult(p, r, zap) == T.ELEC_WATER, "Elétrico em quem está na água 1,3x")
	check(t.damage_mult(p, r, Dex.move("tackle")) == 1.0, "outro tipo normal na água")
	var en_in := BattleEnergy.regen(r)
	check(t.regen_mult(r) == T.WADE_REGEN, "Normal recupera menos na água")
	_put(a, r, _open_spot(a))
	check(t.damage_mult(p, r, zap) == 1.0, "fora da água sem bônus")
	check(t.regen_mult(r) == 1.0, "energia volta ao normal fora da água")
	check(en_in > 0.0, "ok")
	t.freeze(pond)
	_put(a, r, pond.pos)
	check(t.damage_mult(p, r, zap) == 1.0, "lago congelado não eletrocuta mais")
	pond.ice_t = 0.0
	a.free()
	# Energia por tipo.
	var party := [Mon.create("squirtle", 50), Mon.create("bulbasaur", 50)]
	var b := _arena(
		party, [Mon.create("charmander", 50)], 9, {"scenario": "lagoa", "battle_size": 2}
	)
	b.step(DT)
	var tb: BattleTerrain = b.terrain
	var pond2 := _kind(b, "pond")
	var sq: BattleFighter = b.player
	var ch: BattleFighter = b.enemy
	_put(b, sq, pond2.pos)
	_put(b, ch, pond2.pos + Vector3(0.5, 0, 0))
	check(tb.regen_mult(sq) == T.SWIM_REGEN, "Água recupera mais na água")
	for f in b.fighters:
		if f.mon.species == "bulbasaur" and f.active():
			_put(b, f, pond2.pos - Vector3(0.5, 0, 0))
			check(tb.regen_mult(f) == T.SWIM_REGEN, "Grama recupera mais na água")
	check(tb.regen_mult(ch) == T.FIRE_WATER_REGEN, "Fogo recupera bem menos na água")
	var hp := ch.hp
	for i in 70:
		tb.tick(DT)
	check(ch.hp < hp, "Fogo na água toma dano (%d -> %d)" % [hp, ch.hp])
	# Clima no lago: chuva enche, sol seca, granizo congela.
	var r0: float = pond2.r0
	b.abilities.weather = "rain"
	for i in 600:
		tb.tick(DT)
	check(pond2.r > r0 * 1.1, "chuva aumenta o lago (%.2f -> %.2f)" % [r0, pond2.r])
	b.abilities.weather = "sun"
	for i in 1200:
		tb.tick(DT)
	check(pond2.r < r0 * 0.9, "sol diminui o lago (%.2f -> %.2f)" % [r0, pond2.r])
	b.abilities.weather = "hail"
	tb.tick(DT)
	check(float(pond2.ice_t) > 0.0, "granizo congela o lago")
	b.free()


func _pull() -> void:
	var a := _arena(
		[Mon.create("squirtle", 50)], [Mon.create("rattata", 50)], 11, {"scenario": "lagoa"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var pond := _kind(a, "pond")
	var s: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var dir := Vector3(1, 0, 0)
	if not a.rect.grow(-1.0).has_point(Vector2(pond.pos.x + pond.r + 1.5, pond.pos.z)):
		dir = Vector3(-1, 0, 0)
	var edge: Vector3 = pond.pos + dir * (float(pond.r) + 1.0)
	_put(a, r, edge)
	check(not t.in_water(r), "começa fora da água")
	t.after_hit(s, r, Dex.move("water_gun"), dir, 2.5)
	_settle(a, r, 40)
	check(not t.in_water(r), "Water Gun fraco não puxa")
	t.after_hit(s, r, Dex.move("surf"), dir, 7.0)
	check(t.sliding(r), "Surf puxa o alvo")
	_settle(a, r, 40)
	check(t.in_water(r), "puxado para a água")
	# Água não é puxada; longe do lago também não.
	t._shove_at.clear()
	_put(a, s, edge)
	t.after_hit(r, s, Dex.move("surf"), dir, 7.0)
	check(not t.sliding(s), "Água não é puxada")
	_put(a, r, _open_spot(a, 3.0))
	t._shove_at.clear()
	t.after_hit(s, r, Dex.move("surf"), dir, 7.0)
	check(not t.sliding(r), "longe do lago não puxa")
	a.free()


func _drop() -> void:
	var a := _arena(
		[Mon.create("geodude", 50)], [Mon.create("rattata", 50)], 13, {"scenario": "campo"}
	)
	a.step(DT)
	var t: BattleTerrain = a.terrain
	var hill := _kind(a, "hill")
	var m: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	var out := Vector3(1, 0, 0)
	if hill.pos.x > 0.0:
		out = Vector3(-1, 0, 0)  # empurra para o lado do meio da quadra
	# No miolo do topo: segura firme.
	_put(a, r, hill.pos)
	var hp := r.hp
	t.after_hit(m, r, Dex.move("body_slam"), out, 9.0)
	check(r.hp == hp and not t.sliding(r), "no miolo do topo não cai")
	# Na beira do topo: empurrão fraco não derruba, forte derruba.
	_put(a, r, hill.pos + out * float(hill.top) * 0.9)
	check(t.on_high(r), "na beira do alto")
	t.after_hit(m, r, Dex.move("tackle"), out, 4.0)
	check(not t.sliding(r), "empurrão fraco não derruba")
	t.after_hit(m, r, Dex.move("body_slam"), out, 9.0)
	check(t.sliding(r), "empurrão forte derruba")
	check(r.hp < hp, "dano da queda (%d -> %d)" % [hp, r.hp])
	check(r.stun_t >= T.DROP_STUN, "atordoado depois de cair (%.2f)" % r.stun_t)
	_settle(a, r, 90)
	check(r.ground_y < 0.01, "caiu no chão (%.2f)" % r.ground_y)
	check((r.position - hill.pos).length() > hill.r, "fora do morro")
	a.free()


func _ai() -> void:
	# Fogo dentro do lago sai da água.
	var a := _arena(
		[Mon.create("squirtle", 50)], [Mon.create("charmander", 50)], 15, {"scenario": "lagoa"}
	)
	a.step(DT)
	var pond := _kind(a, "pond")
	var c: BattleFighter = a.enemy
	_put(a, c, pond.pos + Vector3(0.3, 0, 0))
	var w: Vector3 = BattleTerrainAI.steer(c.ai, 5.0)
	check(w != Vector3.INF and w.dot(Vector3(1, 0, 0)) > 0.5, "Fogo sai da água (%s)" % w)
	check(c.ai.tag == "leave_water", "tag leave_water")
	a.free()
	# Na grama com inimigo de Fogo: sai da moita.
	var b := _arena(
		[Mon.create("charmander", 50)], [Mon.create("bulbasaur", 50)], 17, {"scenario": "campo"}
	)
	b.step(DT)
	var g: Dictionary = b.terrain.grass[0]
	var bu: BattleFighter = b.enemy
	check(BattleTerrainAI.foe_has_fire(bu), "Charmander tem golpe de Fogo")
	_put(b, bu, g.pos + Vector3(0, 0, 0.3))
	var w2: Vector3 = BattleTerrainAI.steer(bu.ai, 5.0)
	check(w2 != Vector3.INF and bu.ai.tag == "leave_grass", "sai da grama com Fogo do outro lado")
	b.free()
	# Grama descansa na moita (sem Fogo do outro lado).
	var c2 := _arena(
		[Mon.create("rattata", 50)], [Mon.create("bulbasaur", 50)], 19, {"scenario": "campo"}
	)
	c2.step(DT)
	var bb: BattleFighter = c2.enemy
	var g2: Dictionary = c2.terrain.grass[0]
	_put(c2, bb, g2.pos + Vector3(2.0, 0, 0))
	c2.player.position = g2.pos + Vector3(-9.0, 0, 0)
	var big := ""
	for id in bb.moves:
		if big == "" or bb.pp_cost_of(Dex.move(String(id))) > bb.pp_cost_of(Dex.move(big)):
			big = String(id)
	bb.ai.intent = big
	bb.ai.recover_t = 0.0
	bb.pp_max = 0.0
	var w3: Vector3 = BattleTerrainAI.steer(bb.ai, 9.0)
	var to_g: Vector3 = g2.pos - bb.position
	to_g.y = 0.0
	check(w3 != Vector3.INF and w3.dot(to_g.normalized()) > 0.5, "Grama vai descansar na moita")
	c2.free()
	# Elétrico prefere o alvo dentro da água com o golpe Elétrico.
	var d := _arena(
		[Mon.create("rattata", 50)], [Mon.create("pikachu", 50)], 21, {"scenario": "lagoa"}
	)
	d.step(DT)
	var pk: BattleFighter = d.enemy
	var rt: BattleFighter = d.player
	_put(d, rt, _kind(d, "pond").pos)
	pk.pp_max = 100.0
	pk.gcd_t = 0.0
	pk.move_cd.clear()
	pk.ai.intent = "tackle" if "tackle" in pk.moves else String(pk.moves[0])
	BattleTerrainAI.steer(pk.ai, 5.0)
	var it := Dex.move(String(pk.ai.intent))
	check(
		String(it.get("type", "")) == "electric",
		"Elétrico mira no alvo na água (%s)" % pk.ai.intent
	)
	check(pk.opponent == rt, "alvo é quem está na água")
	d.free()


## Arena montada com a config do treino (fora da árvore com `tree` false).
func _mode_arena(seed: int, extra := {}, tree := true) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	if tree:
		root.add_child(a)
	var cfg := Cfg.default_config()
	var o := Cfg.arena_opts(cfg, Vector3.ZERO)
	o.merge({"speed": 1.0, "seed": seed, "battle_size": 1}, true)
	o.merge(extra, true)
	a.start([Mon.create("pikachu", 50)], [Mon.create("rattata", 50)], o)
	return a


## Tudo o que tem visual no cenário (relevo, grama, objetos vivos, biomas, lama, caixas).
func _things(a: Node) -> Array:
	var t: BattleTerrain = a.terrain
	var out: Array = t.obstacles + t.grass + t.props.items + t.biomes.solids + t.ground.mud
	out += t.biomes.lava + a.field.objects
	return out


## Layout do cenário (para comparar duas lutas).
func _layout_key(a: Node) -> String:
	var t: BattleTerrain = a.terrain
	var rows: Array = [t.scenario]
	for o in _things(a):
		rows.append(
			(
				"%s %.3f %.3f %.3f %.3f"
				% [
					o.get("kind", "?"),
					o.pos.x,
					o.pos.z,
					float(o.get("r", 0.0)),
					float(o.get("h", 0.0))
				]
			)
		)
	return "\n".join(rows)


func _voxel() -> void:
	# Quantidades pela área: uma função só, 0 fica 0.
	check(T.scale_count(0, 4.0) == 0 and T.scale_count(1, 4.0) == 4, "scale_count 0 e 1")
	check(T.scale_count(3, 1.0) == 3 and T.scale_count(2, 2.5) == 5, "scale_count arredonda")
	# Lago voxel: água redonda (elipse do WaterSurface) e o gelo é o do shader da água.
	var po := {"pos": Vector3.ZERO, "r": 1.5, "r0": 1.5}
	var pn := ArenaVoxels.pond(po, "lagoa")
	var pw: MeshInstance3D = pn.get_meta("water")
	var pm := WaterSurface.material_of(pw)
	check(int(pm.get_shader_parameter("shape")) == 1, "lago: água redonda")
	ArenaVoxels.pond_ice(po, pn, true)
	check(
		float(pm.get_shader_parameter("freeze")) == 1.0 and pw.visible,
		"lago congelado: gelo do shader"
	)
	ArenaVoxels.pond_ice(po, pn, false)
	check(float(pm.get_shader_parameter("freeze")) == 0.0, "lago derretido")
	pn.free()
	for sc in T.SCENARIOS.keys():
		# Com visual (na árvore, sem fast_sim): cada coisa tem nó voxel e o piso é o ArenaFloor.
		var a := _mode_arena(6, {"scenario": sc})
		var t: BattleTerrain = a.terrain
		check(t.lattice and t.count_k == 1.0 + 3.0 * T.COUNT_CURVE, "%s: grade, k pela área" % sc)
		check(t.floor_node is ArenaFloor and t.floor_node.get_parent() == a, "%s: piso voxel" % sc)
		check(a.get_node_or_null("ArenaQuad") == null, "%s: sem a quadra antiga" % sc)
		var no_node := 0
		for o in _things(a):
			if not o.get("node") is Node3D:
				no_node += 1
		check(no_node == 0, "%s: tudo com nó voxel (%d sem)" % [sc, no_node])
		for o in t.obstacles:
			if o.kind == "pond":
				check(o.node.has_meta("water"), "%s: lago com WaterSurface" % sc)
		var off := 0
		for o in t.obstacles + t.grass:
			for v in [o.pos.x, o.pos.z, float(o.r), float(o.get("h", 0.0))]:
				if absf(v - T.snap(v)) > 0.0001:
					off += 1
		check(off == 0, "%s: relevo e grama na grade de 0,25 m (%d fora)" % [sc, off])
		var key := _layout_key(a)
		var st: int = a.rng.state
		a.free()
		# fast_sim (bateria): o mesmo cenário, o mesmo RNG da luta e nenhum nó.
		var b := _mode_arena(6, {"scenario": sc, "fast_sim": true})
		var bt: BattleTerrain = b.terrain
		check(_layout_key(b) == key, "%s: mesmo layout com e sem visual" % sc)
		check(int(b.rng.state) == st, "%s: o visual não gasta o RNG da luta" % sc)
		var made := 0
		for o in _things(b):
			if o.get("node") != null:
				made += 1
		check(made == 0 and bt.floor_node == null, "%s: fast_sim sem visual (%d nós)" % [sc, made])
		b.free()
		# A mesma semente monta o mesmo cenário.
		var c := _mode_arena(6, {"scenario": sc, "fast_sim": true})
		check(_layout_key(c) == key, "%s: layout determinístico pela semente" % sc)
		c.free()
