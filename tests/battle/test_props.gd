extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_props.gd
## Objetos vivos do cenário (BattleProps, modo de energia): montagem pelos cenários, árvore (cobertura,
## energia de Grama, fogo, queda, tronco, golpe forte, Oran), Voltorb (acorda, aviso, explosão),
## arbusto (fruta, alcance de Grama/Inseto, queima e rebrota), cristal (reflete raio, carga e faísca,
## quebra) e a IA (tiro no Voltorb, derrubar a árvore, tabela no cristal, fruta, fugir do aviso).

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
	# Fruta: com HP baixo vai buscar se o caminho está livre; com inimigo no caminho, não.
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
	a.free()
