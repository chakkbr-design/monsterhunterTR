extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_props.gd
## Objetos vivos do cenário (BattleProps, modo de energia): montagem pelos cenários, árvore (cobertura,
## energia de Grama, fogo, queda, tronco, golpe forte, Oran), Voltorb (acorda, aviso, explosão),
## arbusto (fruta, alcance de Grama/Inseto, queima e rebrota), cristal (reflete raio, carga e faísca,
## quebra), pedregulho (rola morro abaixo, acerta e derruba, vira pedra, bate em objeto), gêiser (aviso,
## erupção, ar, vapor, Água/Fogo adianta), colmeia (enxame no mais perto, Inseto ignorado, Fogo espalha e
## queima), cogumelos (nuvem ao pisar, sono/veneno, Grama imune, chuva) e a IA (tiro no Voltorb, derrubar
## a árvore, tabela no cristal, rolar o pedregulho, enxame, gêiser, esporo, fruta, fugir do aviso,
## desviar dos esporos e do gêiser).

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const P := preload("res://battle/battle_props.gd")

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_layout()
	_tree()
	_tree_strong()
	_voltorb()
	_bush()
	_crystal()
	_boulder()
	_geyser()
	_hive()
	_mushroom()
	_ai()
	print("props: %d checks, %d falhas" % [_count, _fails])
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
	o.merge({"speed": 1.0, "seed": seed, "battle_size": 1, "battle_mode": "energy"}, true)
	o.merge(extra, true)
	a.start(party, enemies, o)
	a.step(DT)
	return a


## Tira o cenário todo e deixa só os objetos postos pelo teste (posições conhecidas).
func _clean(a: Node) -> BattleProps:
	var t: BattleTerrain = a.terrain
	for o in t.obstacles + t.grass:
		if is_instance_valid(o.get("node")):
			o.node.queue_free()
	t.obstacles.clear()
	t.grass.clear()
	for o in a.field.objects:
		if is_instance_valid(o.node):
			o.node.queue_free()
	a.field.objects.clear()
	var pr: BattleProps = t.props
	for o in pr.items.duplicate():
		pr._remove(o)
	for b in pr.berries.duplicate():
		pr._drop_berry_node(b)
	for sw in pr.swarms.duplicate():
		pr._end_swarm(sw, "test")
	pr.clouds.clear()
	a.telegraphs.clear()
	return pr


func _put(f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.ground_y = 0.0


func _events(a: Node, kind: String) -> Array:
	return a.telemetry.events.filter(func(e): return String(e.ev) == kind)


func _tick(a: Node, secs: float) -> void:
	for i in int(secs / DT):
		a.terrain.props.tick(DT)


func _layout() -> void:
	var counts := {}
	for s in range(1, 9):
		for sc in ["campo", "pedreira", "misto", "lagoa"]:
			var a := _arena(
				[Mon.create("pikachu", 50)],
				[Mon.create("rattata", 50)],
				s,
				{"scenario": sc, "telemetry": "user://test_props_%d.json" % s}
			)
			var pr: BattleProps = a.terrain.props
			var plan: Dictionary = BattleTerrain.SCENARIOS[sc]
			for k in P.ORDER:
				var n := pr.of_kind(k).size()
				counts[k] = int(counts.get(k, 0)) + n
				check(n <= int(plan.get(k, 0)), "%s: %s no máximo o plano" % [sc, k])
			for o in pr.items:
				check(o.node is Node3D, "%s 3D" % o.kind)
				if o.kind == "boulder":
					# No topo de um morro (o mais perto do ponto sorteado), não espalhado.
					var on_hill: bool = o.has("hill") and (o.pos - o.hill.pos).length() < 0.01
					check(on_hill and float(o.y) > 0.5, "pedregulho no topo do morro")
					continue
				for sp in [a.player_spot, a.enemy_spot]:
					var d: float = (o.pos - sp * Vector3(1, 0, 1)).length()
					check(d >= o.r + BattleTerrain.KEEP_SPOT - 0.01, "%s longe da entrada" % o.kind)
				for q in a.terrain.obstacles + a.terrain.grass:
					var gap: float = (q.pos - o.pos).length() - float(q.r) - float(o.r)
					check(
						gap >= BattleTerrain.GAP * BattleTerrain.TIGHT_GAP - 0.01,
						"%s espalhado" % o.kind
					)
			a.free()
	for k in P.ORDER:
		check(int(counts.get(k, 0)) > 0, "aparece %s nos cenários (%s)" % [k, counts])
	# Bateria (fast_sim): sem visual.
	var b := _arena(
		[Mon.create("pikachu", 50)],
		[Mon.create("rattata", 50)],
		3,
		{"scenario": "misto", "fast_sim": true}
	)
	check(not b.terrain.props.items.is_empty(), "fast_sim: objetos existem")
	check(b.terrain.props.items.all(func(o): return not o.has("node")), "fast_sim: sem nó 3D")
	b.free()


func _tree() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)],
		[Mon.create("bulbasaur", 50)],
		5,
		{"scenario": "campo", "telemetry": "user://test_props_tree.json"}
	)
	var pr := _clean(a)
	var t: BattleTerrain = a.terrain
	pr.add("tree", Vector3.ZERO)
	var tr: Dictionary = pr.items[-1]
	var c: BattleFighter = a.player
	var b: BattleFighter = a.enemy
	# Cobertura alta.
	check(t.blocks_shot(Vector3(0, 1.8, 0.2)), "árvore para tiro")
	check(t.shot_block(Vector3(-4, 0, 0), Vector3(4, 0, 0)) < INF, "árvore tapa a linha")
	check(t.has_cover(), "árvore conta como cobertura")
	_put(c, Vector3(3, 0, 1))
	var cs := t.cover_spot(c, Vector3(-5, 0, 0))
	check(cs != Vector3.INF and cs.x > 0.0, "esconderijo atrás da árvore (%s)" % cs)
	# Energia de Grama perto da árvore.
	_put(b, Vector3(1.5, 0, 0))
	check(is_equal_approx(pr.regen_mult(b), P.TREE_REGEN), "Grama perto da árvore 1,2x")
	_put(c, Vector3(1.5, 0, 0.5))
	check(pr.regen_mult(c) == 1.0, "Fogo perto da árvore: normal")
	_put(b, Vector3(4, 0, 0))
	check(pr.regen_mult(b) == 1.0, "Grama longe da árvore: normal")
	# Corpo sólido.
	_put(b, Vector3(0.2, 0, 0))
	pr.tick(DT)
	check(b.position.length() >= P.SOLID_R.tree + P.BODY_R - 0.01, "não atravessa o tronco")
	# Golpe comum derruba uma Oran (uma por TREE_BERRY_CD s).
	_put(b, Vector3(6, 0, 4))
	_put(c, Vector3(-6, 0, 4))
	a.field.on_move_landed(c, Dex.move("water_gun"), Vector3(-0.5, 0, 0), 0.3)
	check(pr.berries.size() == 1 and pr.berries[0].src == "tree", "golpe na árvore derruba Oran")
	_tick(a, 0.5)
	a.field.on_move_landed(c, Dex.move("water_gun"), Vector3(-0.5, 0, 0), 0.3)
	check(pr.berries.size() == 1, "Oran da árvore tem recarga")
	# Fogo: queima e cai para longe de quem pôs fogo, em cima de quem está na linha.
	_tick(a, 0.5)
	_put(c, Vector3(-4, 0, 0))
	_put(b, Vector3(1.6, 0, 0))
	var hp := b.hp
	a.field.on_move_landed(c, Dex.move("ember"), Vector3(-0.5, 0, 0), 0.3)
	check(tr.state == "burn", "fogo põe fogo na árvore")
	check(Vector3(tr.fall_dir).dot(Vector3.RIGHT) > 0.85, "cai para longe do atacante")
	_tick(a, P.TREE_BURN - P.TREE_WARN + 0.05)
	var warned: bool = a.telegraphs.any(func(e): return int(e.side) == -1 and e.kind == "line")
	check(warned, "aviso da queda no chão (os dois lados)")
	check(tr.kind == "tree", "ainda em pé queimando")
	_put(b, Vector3(1.6, 0, 0))
	_tick(a, P.TREE_WARN + 0.1)
	check(tr.kind == "log", "caiu e virou tronco")
	var lost := hp - b.hp
	var want := int(float(b.max_hp) * P.TREE_FRAC * b.dot_scale())
	check(lost >= maxi(1, want) and lost <= want + 1, "a queda acerta (%d, ~%d)" % [lost, want])
	check(b.last_hit_by == c, "o crédito é de quem derrubou")
	check(_events(a, "tree_fall").size() == 1, "telemetria tree_fall")
	check(_events(a, "tree_fall_hit").size() == 1, "telemetria tree_fall_hit")
	# Tronco: baixo, anda devagar, para investida.
	var ld: Vector3 = tr.dir
	var ln := Vector3(-ld.z, 0, ld.x)
	var on: Vector3 = tr.pos + ld * 1.3
	check(not t.blocks_shot(on + Vector3(0, 0.5, 0)), "tronco não para tiro")
	_put(b, on)
	check(is_equal_approx(pr.move_mult(b), P.LOG_SLOW), "anda devagar no tronco")
	_put(b, on + ln * 2.0)
	check(pr.move_mult(b) == 1.0, "fora do tronco: normal")
	_put(b, on + ln * 0.62)
	b.dash_t = 0.4
	b.dash_dir = -ln
	pr.tick(DT)
	check(b.dash_t == 0.0, "investida para no tronco")
	_put(b, on + ln * 0.62)
	b.dash_t = 0.4
	b.dash_dir = ln
	pr.tick(DT)
	check(b.dash_t > 0.0, "investida para longe do tronco segue")
	b.dash_t = 0.0
	# Some depois de LOG_LIFE.
	_tick(a, P.LOG_LIFE + 0.5)
	check(pr.items.is_empty(), "tronco some com o tempo")
	a.free()


func _tree_strong() -> void:
	var a := _arena(
		[Mon.create("mankey", 50)],
		[Mon.create("rattata", 50)],
		6,
		{"scenario": "campo", "telemetry": "user://test_props_tree2.json"}
	)
	var pr := _clean(a)
	pr.add("tree", Vector3.ZERO)
	var tr: Dictionary = pr.items[-1]
	var m: BattleFighter = a.player
	_put(m, Vector3(0, 0, -3))
	a.field.on_move_landed(m, Dex.move("rock_throw"), Vector3(0, 0, -0.5), 0.3)
	check(tr.state == "", "Pedra fraca não derruba")
	tr.cd = 0.0
	a.field.on_move_landed(m, Dex.move("focus_blast"), Vector3(0, 0, -0.5), 0.3)
	check(tr.state == "tip", "Lutador forte derruba")
	_tick(a, P.TREE_TIP + 0.1)
	check(tr.kind == "log", "caiu")
	check(Vector3(tr.dir).dot(Vector3(0, 0, 1)) > 0.85, "para longe do atacante")
	check(String(_events(a, "tree_fall")[0].cause) == "strong", "causa: golpe forte")
	a.free()


func _voltorb() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)],
		[Mon.create("rattata", 50)],
		7,
		{"scenario": "pedreira", "telemetry": "user://test_props_volt.json"}
	)
	var pr := _clean(a)
	var t: BattleTerrain = a.terrain
	pr.add("voltorb", Vector3.ZERO)
	var v: Dictionary = pr.items[-1]
	var c: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(c, Vector3(-5, 0, 0))
	_put(r, Vector3(1.4, 0, 0))
	check(t.blocks_shot(Vector3(0.2, 0.5, 0)), "Voltorb é cobertura baixa")
	check(not t.blocks_shot(Vector3(0.2, 1.2, 0)), "por cima passa")
	a.field.on_move_landed(c, Dex.move("water_gun"), Vector3(-0.4, 0, 0), 0.3)
	check(v.state == "", "Água fraca não acorda")
	v.cd = 0.0
	a.field.on_move_landed(c, Dex.move("ember"), Vector3(-0.4, 0, 0), 0.3)
	check(v.state == "armed", "Fogo acorda o Voltorb")
	var ring: bool = a.telegraphs.any(func(e): return int(e.side) == -1 and e.kind == "disc")
	check(ring, "anel de aviso no chão (os dois lados)")
	var hp := r.hp
	var hp_c := c.hp
	_tick(a, P.VOLT_WARN * 0.5)
	check(pr.items.has(v), "ainda no aviso")
	_tick(a, P.VOLT_WARN * 0.5 + 0.1)
	check(not pr.items.has(v), "explodiu e sumiu")
	var lost := hp - r.hp
	var want := int(float(r.max_hp) * P.VOLT_FRAC * r.dot_scale())
	check(lost >= maxi(1, want) and lost <= want + 1, "explosão acerta (%d, ~%d)" % [lost, want])
	check(c.hp == hp_c, "longe da explosão: nada")
	check(r.knock.length() > 0.1 or r.impact_knock.length() > 0.1, "empurra")
	check(_events(a, "voltorb_boom").size() == 1, "telemetria voltorb_boom")
	# Golpe forte de qualquer tipo também acorda.
	pr.add("voltorb", Vector3(3, 0, 3))
	var v2: Dictionary = pr.items[-1]
	a.field.on_move_landed(c, Dex.move("thunderbolt"), Vector3(3, 0, 3), 0.3)
	check(v2.state == "armed", "Elétrico acorda")
	pr.add("voltorb", Vector3(-6, 0, 3))
	var v3: Dictionary = pr.items[-1]
	a.field.on_move_landed(c, Dex.move("stone_edge"), Vector3(-6, 0, 3), 1.0)
	check(v3.state == "armed", "golpe forte (poder >= 80) acorda")
	a.free()


func _bush() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)],
		[Mon.create("bulbasaur", 50)],
		8,
		{"scenario": "campo", "telemetry": "user://test_props_bush.json"}
	)
	var pr := _clean(a)
	a._battle_size = 2  # cura no 2x2; no 1x1 só energia (fim do teste)
	pr.add("bush", Vector3.ZERO)
	var bu: Dictionary = pr.items[-1]
	var c: BattleFighter = a.player
	var b: BattleFighter = a.enemy
	_put(c, Vector3(-8, 0, 4))
	_put(b, Vector3(8, 0, 4))
	check(bu.grow_t >= P.BUSH_EVERY.x and bu.grow_t <= P.BUSH_EVERY.y, "fruta a cada 20-25 s")
	_tick(a, P.BUSH_EVERY.y + 0.1)
	check(pr.berries.size() == 1, "nasceu uma Oran do lado do arbusto")
	_tick(a, P.BUSH_EVERY.y + 0.1)
	check(pr.berries.size() == 1, "uma por vez")
	var be: Dictionary = pr.berries[0]
	# Alcance: Fogo (normal) não pega de 1,2 m; Grama pega.
	c.hp = c.max_hp / 2
	var off: Vector3 = (be.pos - bu.pos).normalized()
	_put(c, be.pos + Vector3(-off.z, 0, off.x) * 1.2)
	pr.tick(DT)
	check(pr.berries.size() == 1, "de 1,2 m o Fogo não pega")
	_put(c, Vector3(-8, 0, 4))
	b.hp = b.max_hp / 2
	b.pp_max = BattleEnergy.MAX
	_put(b, be.pos + Vector3(-off.z, 0, off.x) * 1.2)
	var hp := b.hp
	pr.tick(DT)
	check(pr.berries.is_empty(), "Grama pega de mais longe")
	var heal := int(float(b.max_hp) * P.BERRY_HEAL)
	check(b.hp - hp == heal, "Oran cura 1/8 (%d de %d)" % [b.hp - hp, heal])
	check(_events(a, "berry_pick").size() == 1, "telemetria berry_pick")
	# Com HP alto e pouca energia: energia.
	pr._drop_berry(bu, "bush", INF)
	b.hp = b.max_hp
	b.pp_max = 10.0
	_put(b, pr.berries[0].pos)
	pr.tick(DT)
	check(absf(b.pp_max - (10.0 + P.BERRY_EN)) < 0.5, "Oran dá +20 de energia (%.1f)" % b.pp_max)
	# Tudo cheio: deixa a fruta.
	pr._drop_berry(bu, "bush", INF)
	b.pp_max = BattleEnergy.MAX
	_put(b, pr.berries[0].pos)
	pr.tick(DT)
	check(pr.berries.size() == 1, "cheio: deixa a fruta no chão")
	_put(b, Vector3(8, 0, 4))
	# Fogo queima: sem fruta por 30 s, depois rebrota.
	a.field.on_move_landed(c, Dex.move("ember"), Vector3(0.4, 0, 0), 0.3)
	check(bu.burnt_t > 0.0 and pr.berries.is_empty(), "Fogo queima o arbusto e a fruta")
	_tick(a, P.BUSH_BURN - 1.0)
	check(pr.berries.is_empty(), "queimado: sem fruta")
	_tick(a, 1.2)
	check(bu.burnt_t <= 0.0, "rebrotou")
	_tick(a, P.BUSH_EVERY.y + 0.1)
	check(pr.berries.size() == 1, "volta a dar fruta")
	# 1x1: a Oran só dá energia (com a barra cheia fica no chão, mesmo com HP baixo).
	a._battle_size = 1
	b.hp = b.max_hp / 2
	b.pp_max = BattleEnergy.MAX
	_put(b, pr.berries[0].pos)
	pr.tick(DT)
	check(pr.berries.size() == 1, "1x1: barra cheia, não cura")
	b.pp_max = 30.0
	hp = b.hp
	pr.tick(DT)
	check(pr.berries.is_empty() and b.hp == hp and b.pp_max > 45.0, "1x1: Oran dá energia")
	a.free()


func _crystal() -> void:
	var a := _arena(
		[Mon.create("pikachu", 50)],
		[Mon.create("rattata", 50), Mon.create("rattata", 50)],
		9,
		{"scenario": "pedreira", "telemetry": "user://test_props_cry.json"}
	)
	var pr := _clean(a)
	var t: BattleTerrain = a.terrain
	pr.add("crystal", Vector3.ZERO)
	var cr: Dictionary = pr.items[-1]
	var p: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	check(t.blocks_shot(Vector3(0.1, 1.0, 0)), "cristal é cobertura")
	# Raio no cristal: reflete no ângulo espelhado.
	var from := Vector3(-5, 0, 0)
	var aim := Vector3(0, 0, -0.3)
	var d := (aim - from).normalized()
	var out := P.reflect_dir(from, d, cr.pos)
	check(out != Vector3.ZERO and out.x < 0.0, "reflete de volta para o lado (%s)" % out)
	check(absf(out.dot(Vector3(0, 0, -1))) > 0.1, "ângulo espelhado, não reto")
	var hit_at: Vector3 = from + d * P._ray_circle(from, d, cr.pos, P.SHOT_R.crystal)
	_put(p, from)
	_put(r, hit_at + out * 3.0)
	var hp := r.hp
	var beam := Dex.move("charge_beam")
	pr.on_beam(p, beam, d, 13.0, 0.8)
	check(r.hp < hp, "o raio refletido acerta do outro lado")
	check(_events(a, "crystal_reflect").size() == 1, "telemetria crystal_reflect")
	# Reflexo bate 0,7x: compara com o golpe direto de perto.
	var refl := hp - r.hp
	r.hp = r.max_hp
	var hp2 := r.hp
	a.moves.hit(p, r, beam, Vector3.RIGHT)
	var direct := hp2 - r.hp
	check(refl <= direct, "reflexo mais fraco (%d <= %d)" % [refl, direct])
	r.hp = r.max_hp
	# Elétrico carrega: faísca em quem está perto (Terra não sente).
	_put(r, Vector3(1.2, 0, 0))
	r.hp = r.max_hp
	var h0 := r.hp
	cr.cd = 0.0
	a.field.on_move_landed(p, Dex.move("thunder_shock"), Vector3(-0.4, 0, 0), 0.3)
	check(cr.charge_t > 0.0, "Elétrico carrega o cristal")
	_tick(a, 1.1)
	check(r.hp < h0, "faísca em quem está a 1,5 m")
	check(_events(a, "crystal_spark").size() >= 1, "telemetria crystal_spark")
	_tick(a, P.CHARGE)
	check(cr.charge_t <= 0.0, "a carga acaba")
	var h1 := r.hp
	_tick(a, 2.0)
	check(r.hp == h1, "sem carga, sem faísca")
	# Pedra/Lutador quebram.
	cr.cd = 0.0
	a.field.on_move_landed(p, Dex.move("rock_throw"), Vector3(-0.4, 0, 0), 0.3)
	check(pr.items.has(cr) and int(cr.hp) == P.CRYSTAL_HP - 1, "Pedra trinca o cristal")
	cr.cd = 0.0
	a.field.on_move_landed(p, Dex.move("rock_throw"), Vector3(-0.4, 0, 0), 0.3)
	check(not pr.items.has(cr), "Pedra quebra o cristal")
	a.free()


func _boulder() -> void:
	var a := _arena(
		[Mon.create("geodude", 50)],
		[Mon.create("rattata", 50)],
		6,
		{"scenario": "pedreira", "telemetry": "user://test_props_boulder.json"}
	)
	var pr := _clean(a)
	var t: BattleTerrain = a.terrain
	t._add("hill", Vector3(-2, 0, 0), 1.8, 1.0)
	pr.add("boulder", Vector3(-1, 0, 2))
	var bo: Dictionary = pr.of_kind("boulder")[0]
	check((bo.pos - Vector3(-2, 0, 0)).length() < 0.01, "pedregulho vai para o topo do morro")
	check(float(bo.y) > 0.9, "pedregulho no alto (y %.2f)" % float(bo.y))
	check(pr.blocks_shot(Vector3(-2, 1.4, 0)), "pedregulho é cobertura no alto do morro")
	var g: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(g, Vector3(-6, 0, 0))
	_put(r, Vector3(3, 0, 0.3))
	# Golpe fraco de outro tipo não empurra.
	pr.hit_prop(bo, g, Dex.move("water_gun"))
	check(bo.state == "", "Água fraca não empurra")
	bo.cd = 0.0
	# Golpe de Pedra que cai no morro: treme e rola na direção do golpe.
	pr.on_move_landed(g, Dex.move("rock_throw"), Vector3(-3.2, 0, 0), 0.3)
	check(bo.state == "wobble", "Pedra no morro: o pedregulho treme")
	check(Vector3(bo.dir).x > 0.99, "rola na direção do golpe")
	var tl: Array = a.telegraphs.filter(func(e): return e.kind == "line" and int(e.side) == -1)
	check(not tl.is_empty(), "linha de aviso para os dois lados")
	check(_events(a, "boulder_push").size() == 1, "telemetria boulder_push")
	var hp := r.hp
	_tick(a, P.BOULDER_WARN + 0.05)
	check(bo.state == "roll", "rola depois do aviso")
	_tick(a, 2.0)
	var want := maxi(1, int(float(r.max_hp) * P.BOULDER_FRAC * r.dot_scale()))
	check(hp - r.hp == want, "acerta quem está no caminho (%d de %d)" % [hp - r.hp, want])
	check(r.stun_t > 0.0, "derruba (atordoado)")
	check(_events(a, "boulder_hit").size() == 1, "telemetria boulder_hit (uma vez)")
	check(bo.kind == "stone", "parou e virou pedra")
	var inner: Rect2 = a.rect.grow(-0.7)
	var far := (
		float(bo.done) >= P.BOULDER_MAX - 0.2 or not inner.has_point(Vector2(bo.pos.x, bo.pos.z))
	)
	check(far, "rolou até a parede ou o máximo (%.1f m)" % float(bo.done))
	check(pr.blocks_shot(bo.pos + Vector3(0, 0.3, 0)), "pedra pequena é cobertura baixa")
	check(not pr.blocks_shot(bo.pos + Vector3(0, 1.0, 0)), "pedra pequena: tiro alto passa")
	pr.on_move_landed(g, Dex.move("rock_throw"), bo.pos, 0.3)
	check(bo.kind == "stone" and bo.state == "", "pedra não rola de novo")
	# Rola até o Voltorb: acorda.
	pr._remove(bo)
	t.obstacles.clear()
	t._add("hill", Vector3(-2, 0, 0), 1.8, 1.0)
	pr.add("boulder", Vector3(-2, 0, 0))
	pr.add("voltorb", Vector3(3, 0, 0))
	bo = pr.of_kind("boulder")[0]
	_put(r, Vector3(6, 0, 5))
	var path := pr.roll_path(bo, Vector3.RIGHT)
	check(not path.into.is_empty() and path.into.kind == "voltorb", "o caminho para no Voltorb")
	pr.hit_prop(bo, g, Dex.move("rock_throw"))
	_tick(a, 1.2)
	check(pr.of_kind("voltorb")[0].state == "armed", "o pedregulho acordou o Voltorb")
	# Lago no caminho: afunda.
	_clean(a)
	t._add("hill", Vector3(-2, 0, 0), 1.8, 1.0)
	t._add("pond", Vector3(3.5, 0, 0), 1.5, 0.0)
	pr.add("boulder", Vector3(-2, 0, 0))
	bo = pr.of_kind("boulder")[0]
	check(bool(pr.roll_path(bo, Vector3.RIGHT).sink), "no lago afunda")
	pr.hit_prop(bo, g, Dex.move("rock_throw"))
	_tick(a, 1.5)
	check(pr.of_kind("boulder").is_empty() and pr.of_kind("stone").is_empty(), "afundou e sumiu")
	a.free()


func _geyser() -> void:
	var a := _arena(
		[Mon.create("pidgey", 50)],
		[Mon.create("rattata", 50)],
		7,
		{"scenario": "lagoa", "telemetry": "user://test_props_geyser.json"}
	)
	var pr := _clean(a)
	pr.add("geyser", Vector3.ZERO)
	var ge: Dictionary = pr.items[-1]
	var p: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	check(float(ge.timer) >= P.GEYSER_FIRST.x and float(ge.timer) <= P.GEYSER_FIRST.y, "1a erupção")
	_put(p, Vector3(-6, 0, 0))
	_put(r, Vector3(0.3, 0, 0))
	ge.timer = P.GEYSER_WARN + 0.2
	_tick(a, 0.25)
	check(ge.state == "warn", "aviso de vapor antes da erupção")
	check(not pr.blocks_shot(Vector3(0, 1, 0)), "no aviso o tiro ainda passa")
	_tick(a, P.GEYSER_WARN)
	check(ge.state == "steam", "erupção")
	check(r.motion == "leap", "quem está em cima sobe")
	check(_events(a, "geyser_launch").size() == 1, "telemetria geyser_launch")
	check(pr.blocks_shot(Vector3(0, 1, 0)), "o vapor para tiro")
	check(pr.damage_mult(p, r, Dex.move("gust")) == P.GEYSER_FLY, "Voador no ar acerta mais")
	check(pr.damage_mult(p, r, Dex.move("water_gun")) == 1.0, "outros tipos: normal")
	# Investida passa por baixo de quem está no ar.
	for i in 20:
		r._motion_step(DT)
	check(p.passes_under(r), "investida passa por baixo de quem está no ar")
	_tick(a, P.STEAM_SECS)
	check(ge.state == "" and not pr.blocks_shot(Vector3(0, 1, 0)), "o vapor some")
	check(float(ge.timer) >= P.GEYSER_EVERY.x, "próxima erupção a cada 11-13 s")
	# Água adianta.
	r.end_motion()
	pr.hit_prop(ge, p, Dex.move("water_gun"))
	check(ge.state == "warn" and float(ge.t) <= P.GEYSER_EARLY + 0.01, "Água adianta (aviso curto)")
	check(_events(a, "geyser_early").size() == 1, "telemetria geyser_early")
	a.free()


func _hive() -> void:
	var a := _arena(
		[Mon.create("squirtle", 50)],
		[Mon.create("rattata", 50)],
		8,
		{"scenario": "misto", "telemetry": "user://test_props_hive.json"}
	)
	var pr := _clean(a)
	pr.add("hive", Vector3.ZERO)
	var hv: Dictionary = pr.items[-1]
	var s: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(s, Vector3(-6, 0, 0))
	_put(r, Vector3(1.0, 0, 0))
	check(pr.swarm_target(hv, s) == r, "enxame vai no mais perto da colmeia (o inimigo)")
	_put(r, Vector3(7, 0, 4))
	check(pr.swarm_target(hv, s) == s, "inimigo longe: vai em quem bateu")
	var types: Array = r.types
	r.types = ["bug"]
	_put(r, Vector3(1.0, 0, 0))
	check(pr.swarm_target(hv, s) == s, "Inseto é ignorado")
	r.types = types
	pr.hit_prop(hv, s, Dex.move("water_gun"))
	check(pr.swarms.size() == 1 and pr.swarms[0].target == r, "golpe solta o enxame")
	check(float(hv.rest_t) > 0.0, "colmeia quieta depois")
	var hp := r.hp
	_tick(a, 1.5)
	check(r.hp < hp, "ferroada no alvo")
	check(not _events(a, "swarm_sting").is_empty(), "telemetria swarm_sting")
	_tick(a, P.SWARM_SECS)
	check(pr.swarms.is_empty(), "o enxame acaba em 4 s")
	# Fogo perto espalha.
	hv.rest_t = 0.0
	pr.hit_prop(hv, s, Dex.move("water_gun"))
	check(pr.swarms.size() == 1, "solta de novo")
	pr.on_move_landed(r, Dex.move("ember"), pr.swarms[0].pos, 0.3)
	check(pr.swarms.is_empty(), "Fogo espalha o enxame")
	check(_events(a, "swarm_fire").size() == 1, "telemetria swarm_fire")
	# Fogo na colmeia: queima, sem enxame.
	hv.cd = 0.0
	hv.rest_t = 0.0
	pr.hit_prop(hv, r, Dex.move("ember"))
	check(pr.of_kind("hive").is_empty() and pr.swarms.is_empty(), "Fogo queima a colmeia")
	a.free()


func _mushroom() -> void:
	var a := _arena(
		[Mon.create("bulbasaur", 50)],
		[Mon.create("rattata", 50)],
		9,
		{"scenario": "campo", "telemetry": "user://test_props_spore.json"}
	)
	var pr := _clean(a)
	pr.add("mushroom", Vector3.ZERO)
	var mu: Dictionary = pr.items[-1]
	var b: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	_put(b, Vector3(0.3, 0, 0.3))  # Grama: imune
	_put(r, Vector3(3, 0, 0))
	pr.tick(DT)
	check(pr.clouds.size() == 1, "pisar solta a nuvem (mesmo Grama)")
	check(_events(a, "spore_cloud").size() == 1, "telemetria spore_cloud")
	_put(r, Vector3(0.8, 0, 0))
	pr.tick(DT)
	check(_events(a, "spore_status").size() == 1, "quem entra na nuvem sorteia uma vez")
	check(
		_events(a, "spore_status").all(func(e): return String(e.who) != a.telemetry.uid(b)),
		"Grama é imune"
	)
	_tick(a, 0.5)
	check(_events(a, "spore_status").size() == 1, "um sorteio por nuvem")
	_tick(a, P.SPORE_SECS)
	check(pr.clouds.is_empty(), "a nuvem some")
	_put(r, Vector3(3, 0, 0))
	pr.tick(DT)
	_put(r, Vector3(0.2, 0, 0))
	pr.tick(DT)
	check(pr.clouds.is_empty(), "recarregando: não solta")
	# Sono ~30%, veneno ~35% (sorteio).
	var got := {"sleep": 0, "poison": 0, "": 0}
	for i in 200:
		r.status = ""
		r.status_immune_t = 0.0
		pr.clouds.append({"pos": Vector3.ZERO, "t": 1.0, "hit": {}, "by": null})
		pr._tick_clouds(DT)
		pr.clouds.clear()
		got[r.status if r.status in got else ""] += 1
	check(got.sleep > 35 and got.sleep < 85, "sono ~30%% (%s)" % [got])
	check(got.poison > 45 and got.poison < 100, "veneno ~35%% (%s)" % [got])
	r.status = ""
	# Golpe nela também solta; chuva molha.
	mu.rest_t = 0.0
	a.abilities.weather = "rain"
	pr.hit_prop(mu, r, Dex.move("tackle"))
	check(pr.clouds.is_empty() and _events(a, "spore_wet").size() == 1, "chuva: esporo molhado")
	a.abilities.weather = ""
	mu.cd = 0.0
	pr.hit_prop(mu, r, Dex.move("tackle"))
	check(pr.clouds.size() == 1, "golpe solta a nuvem")
	a.free()


func _ai() -> void:
	var a := _arena(
		[Mon.create("charmander", 50)],
		[Mon.create("rattata", 50)],
		11,
		{"scenario": "pedreira", "telemetry": "user://test_props_ai.json"}
	)
	var pr := _clean(a)
	var c: BattleFighter = a.player
	var r: BattleFighter = a.enemy
	c.controller = "ai"
	if c.ai == null:
		c.ai = BattleAI.new(c)
	c.moves = ["ember"]
	c.pp_max = BattleEnergy.MAX
	c.move_cd.clear()
	c.gcd_t = 0.0
	c.opponent = r
	# Voltorb ao lado do inimigo: atira nele.
	pr.add("voltorb", Vector3.ZERO)
	_put(c, Vector3(-6, 0, 0))
	_put(r, Vector3(1.2, 0, 0.3))
	var me := Vector3(-6, 0, 0)
	check(
		not pr._voltorb_shot(c, Dex.move("ember"), me, 11.0).is_empty(),
		"vê o Voltorb perto do inimigo"
	)
	check(
		pr._voltorb_shot(c, Dex.move("water_gun"), me, 11.0).is_empty(),
		"Água fraca não serve para acordar"
	)
	_put(c, Vector3(-2.5, 0, 0))
	check(
		pr._voltorb_shot(c, Dex.move("ember"), Vector3(-2.5, 0, 0), 11.0).is_empty(),
		"perto demais: não atira"
	)
	_put(c, me)
	check(BattleProps.ai_shot(c.ai, 0), "IA atira no Voltorb")
	check(c.ai.why == "prop_voltorb", "motivo na IA (%s)" % c.ai.why)
	var v: Dictionary = pr.of_kind("voltorb")[0]
	for i in 90:
		c.tick(DT)
		a._fight_step(0.0)  # eventos atrasados (later)
		for p in a.projectiles:
			p.step(DT, a)
		pr.tick(DT)
		if v.state != "":
			break
	check(v.state == "armed", "o tiro acordou o Voltorb")
	# Fugir do anel de aviso.
	_put(r, Vector3(1.0, 0, 0))
	if r.ai == null:
		r.ai = BattleAI.new(r)
	var th: Dictionary = r.ai._threat()
	check(not th.is_empty() and Vector3(th.away).x > 0.0, "o anel é ameaça: foge para fora")
	pr._remove(v)
	a.telegraphs.clear()
	# Árvore: derruba com o inimigo na linha da queda.
	pr.add("tree", Vector3.ZERO)
	_put(r, Vector3(1.6, 0, 0.2))
	check(
		not pr._tree_shot(c, Dex.move("ember"), me, 11.0).is_empty(), "derruba a árvore no inimigo"
	)
	_put(r, Vector3(-1.6, 0, 3.0))
	check(pr._tree_shot(c, Dex.move("ember"), me, 11.0).is_empty(), "fora da linha: não")
	pr._remove(pr.of_kind("tree")[0])
	# Tabela no cristal: alvo escondido atrás de uma caixa, mas o reflexo chega nele.
	pr.add("crystal", Vector3.ZERO)
	var from := Vector3(-5, 0, -2)
	var mv := Dex.move("charge_beam")
	var shot := {}
	var tgt := Vector3.INF
	var side := Vector3(2, 0, -5).normalized()
	var k := 0.5
	var aimp: Vector3 = side * P.SHOT_R.crystal * k
	var d := (aimp - from).normalized()
	var out := P.reflect_dir(from, d, Vector3.ZERO)
	var hit: Vector3 = from + d * P._ray_circle(from, d, Vector3.ZERO, P.SHOT_R.crystal)
	tgt = hit + out * 4.0
	_put(c, from)
	_put(r, tgt)
	# Caixa no meio da linha direta.
	var mid := (from + tgt) * 0.5
	a.field._add_object(mid)
	check(a.terrain.shot_block(from, tgt) < INF, "linha direta tapada")
	shot = pr._bank_shot(c, mv, from)
	check(not shot.is_empty(), "acha a tabela no cristal")
	if not shot.is_empty():
		var aim_d := (Vector3(shot.pos) - from).normalized()
		var o2 := P.reflect_dir(from, aim_d, Vector3.ZERO)
		var h2: Vector3 = from + aim_d * P._ray_circle(from, aim_d, Vector3.ZERO, P.SHOT_R.crystal)
		var rel := tgt - h2
		var along := rel.dot(o2)
		check((rel - o2 * along).length() < 0.8 and along > 0.0, "a tabela chega no alvo")
		c.set_meta("prop_aim", {"id": "charge_beam", "pos": shot.pos, "until": pr._t + 3.0})
		var got := pr.aim_dir(c, mv, Vector3.RIGHT)
		check(got.dot(aim_d) > 0.99, "o golpe sai na direção da tabela")
		check(not c.has_meta("prop_aim"), "a mira é usada uma vez")
	# Fruta: com HP baixo vai buscar se o caminho está livre; com inimigo no caminho, não (2x2; no 1x1
	# só com energia baixa).
	a._battle_size = 2
	pr._remove(pr.of_kind("crystal")[0])
	pr.add("bush", Vector3(4, 0, 4))
	pr._drop_berry(pr.of_kind("bush")[0], "bush", INF)
	var be: Dictionary = pr.berries[0]
	_put(c, Vector3(0, 0, 4.5))
	_put(r, Vector3(-8, 0, -4))
	c.hp = int(c.max_hp * 0.3)
	var w := BattleProps.steer(c.ai, 8.0)
	check(w != Vector3.INF and w.dot((be.pos - c.position).normalized()) > 0.9, "vai na fruta")
	check(c.ai.tag == "berry", "tag berry")
	_put(r, (c.position + be.pos) * 0.5 + Vector3(0, 0, 0.5))
	pr._ai.clear()
	check(BattleProps.steer(c.ai, 2.0) == Vector3.INF, "inimigo no caminho: não vai")
	_put(r, Vector3(-8, 0, -4))
	c.hp = c.max_hp
	c.pp_max = BattleEnergy.MAX
	check(BattleProps.steer(c.ai, 8.0) == Vector3.INF, "HP e energia altos: não vai")
	# Limite de tempo atrás da fruta.
	c.hp = int(c.max_hp * 0.3)
	pr._ai.clear()
	BattleProps.steer(c.ai, 8.0)
	pr._t += P.BERRY_CHASE + 0.1
	check(BattleProps.steer(c.ai, 8.0) == Vector3.INF, "desiste depois de BERRY_CHASE s")
	a._battle_size = 1
	pr._ai.clear()
	check(BattleProps.steer(c.ai, 8.0) == Vector3.INF, "1x1: HP baixo com a barra cheia não vai")
	c.pp_max = 10.0
	pr._ai.clear()
	check(BattleProps.steer(c.ai, 8.0) != Vector3.INF, "1x1: energia baixa vai")
	pr._drop_berry_node(be)
	_ai_new(a, pr, c, r)
	a.free()


## IA dos objetos novos: pedregulho, colmeia, gêiser, esporo, cristal carregado e o desvio.
func _ai_new(a: Node, pr: BattleProps, c: BattleFighter, r: BattleFighter) -> void:
	for o in pr.items.duplicate():
		pr._remove(o)
	a.telegraphs.clear()
	var me := Vector3(-6, 0, 0)
	_put(c, me)
	var t: BattleTerrain = a.terrain
	t._add("hill", Vector3(-2, 0, 0), 1.8, 1.0)
	pr.add("boulder", Vector3(-2, 0, 1))
	var bo: Dictionary = pr.of_kind("boulder")[0]
	_put(r, Vector3(3, 0, 0.3))
	var rock := Dex.move("rock_throw")
	check(not pr._boulder_shot(c, rock, me, 9.0).is_empty(), "IA: rola o pedregulho no inimigo")
	check(pr._boulder_shot(c, Dex.move("ember"), me, 9.0).is_empty(), "IA: Fogo fraco não empurra")
	_put(r, Vector3(3, 0, 4))
	check(pr._boulder_shot(c, rock, me, 9.0).is_empty(), "IA: fora da linha não rola")
	pr._remove(bo)
	t.obstacles.clear()
	# Colmeia: inimigo colado nela, eu longe.
	pr.add("hive", Vector3.ZERO)
	_put(r, Vector3(1.0, 0, 0))
	var wg := Dex.move("water_gun")
	check(not pr._hive_shot(c, wg, me, 11.0).is_empty(), "IA: solta o enxame no inimigo colado")
	_put(r, Vector3(5, 0, 4))
	check(pr._hive_shot(c, wg, me, 11.0).is_empty(), "IA: inimigo longe da colmeia, não")
	check(pr._hive_shot(c, Dex.move("ember"), me, 11.0).is_empty(), "IA: Fogo queimaria a colmeia")
	pr._remove(pr.of_kind("hive")[0])
	# Gêiser: Água/Fogo com o inimigo em cima.
	pr.add("geyser", Vector3.ZERO)
	var ge: Dictionary = pr.of_kind("geyser")[0]
	ge.timer = 8.0
	_put(r, Vector3(0.3, 0, 0))
	check(not pr._geyser_shot(c, wg, me, 11.0).is_empty(), "IA: adianta o gêiser no inimigo")
	check(pr._geyser_shot(c, Dex.move("rock_throw"), me, 11.0).is_empty(), "IA: Pedra não ferve")
	# Desvio: perto da erupção não entra; longe, não liga.
	_put(c, Vector3(-2.2, 0, 0.3))
	var w := pr.avoid(c, Vector3(1, 0, 0))
	check(w.is_equal_approx(Vector3(1, 0, 0)), "IA: gêiser longe da erupção, passa")
	ge.timer = 0.8
	w = pr.avoid(c, Vector3(1, 0, 0))
	check(absf(w.z) > 0.2, "IA: gêiser quase explodindo, contorna (%s)" % w)
	pr._remove(ge)
	# Esporo: estoura com o inimigo dentro; contorna a mancha.
	pr.add("mushroom", Vector3.ZERO)
	_put(c, me)
	_put(r, Vector3(0.4, 0, 0))
	r.status = ""
	check(not pr._spore_shot(c, wg, me, 11.0).is_empty(), "IA: estoura os esporos no inimigo")
	_put(c, Vector3(-2.5, 0, 0.2))
	w = pr.avoid(c, Vector3(1, 0, 0))
	check(absf(w.z) > 0.2, "IA: contorna os esporos (%s)" % w)
	pr._remove(pr.of_kind("mushroom")[0])
	# Cristal: Elétrico carrega com o inimigo colado.
	pr.add("crystal", Vector3.ZERO)
	_put(c, me)
	_put(r, Vector3(1.0, 0, 0))
	var ts := Dex.move("thunder_shock")
	check(not pr._charge_shot(c, ts, me, 11.0).is_empty(), "IA: carrega o cristal no inimigo")
	pr._remove(pr.of_kind("crystal")[0])
	# O enxame atrás de mim: foge correndo.
	pr.add("hive", Vector3(-4, 0, 0))
	pr._release_swarm(pr.of_kind("hive")[0], r)
	check(not pr.swarms.is_empty() and pr.swarms[0].target == c, "enxame no mais perto (eu)")
	w = pr.avoid(c, Vector3(0, 0, 1))
	check(w.x < -0.1, "IA: foge do enxame (%s)" % w)
