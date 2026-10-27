extends SceneTree
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/battle/test_destruction.gd
## Obstáculos destrutíveis (BattleDestruction, modo de energia): fórmula do impacto, Snorlax arremessado
## com golpe forte quebra caixa, árvore (cai) e coluna; Rattata com golpe fraco não quebra a coluna (com
## golpe forte só a caixa); morro perde um degrau, montinho desaba; o que está em cima de um apoio
## destruído cai (pedregulho no morro, caixa na coluna, lutador no morro); obstacles_changed dispara;
## coluna destruída para de cobrir; efeitos (pedaços e entulho) só fora do fast_sim.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0
const D := preload("res://battle/battle_destruction.gd")

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_formula()
	_heavy()
	_light()
	_relief()
	_support()
	_fast_sim()
	print("destruction: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(party: Array, enemies: Array, seed: int, extra := {}, idle := true) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	var o := Cfg.arena_opts(Cfg.default_config(), Vector3.ZERO)
	o.merge(
		{
			"speed": 1.0,
			"seed": seed,
			"battle_size": 1,
			"scenario": "campo"
		},
		true
	)
	o.merge(extra, true)
	a.start(party, enemies, o)
	a.step(DT)
	if idle:
		for f in a.fighters:
			f.controller = "none"
	return a


## Tira o cenário todo (só ficam os objetos postos pelo teste).
func _clean(a: Node) -> void:
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
	for o in t.props.items.duplicate():
		t.props._remove(o)
	for o in t.biomes.solids:
		if is_instance_valid(o.get("node")):
			o.node.queue_free()
	t.biomes.solids.clear()
	var ex: BattleGroundExtras = t.ground.extras
	for l in [ex.pylons, ex.rocks, ex.snow]:
		for o in l:
			if is_instance_valid(o.get("node")):
				o.node.queue_free()
		l.clear()
	a.telegraphs.clear()
	# Os dois lutadores longe de tudo.
	_put(a.player, Vector3(-18, 0, -10))
	_put(a.enemy, Vector3(18, 0, 10))


func _put(f: BattleFighter, at: Vector3) -> void:
	f.position = Vector3(at.x, 0.0, at.z)
	f.ground_y = 0.0
	f.knock = Vector3.ZERO
	f.launch_t = 0.0


func _crate(a: Node, at: Vector3, extra := {}) -> Dictionary:
	a.field._add_object(at)
	var o: Dictionary = a.field.objects[-1]
	o.rock = false
	o.hp = 2
	o.berry = false
	o.merge(extra, true)
	return o


func _pillar(a: Node, at: Vector3) -> Dictionary:
	a.terrain.biomes._add_solid("pillar", at)
	return a.terrain.biomes.solids[-1]


## Arremessa `f` de `gap` m antes do contato com o que está em `at` (raio de contato `lim`), na direção
## +x, com um golpe de contato de poder `power` (distância de BattlePhysics.launch_dist; no mínimo
## `min_dist`), e roda o arremesso até parar.
func _throw(
	a: Node, f: BattleFighter, at: Vector3, lim: float, power: float, min_dist := 0.0, gap := 0.3
) -> void:
	_put(f, at - Vector3(lim + gap, 0, 0))
	f.stun_t = 0.0
	var mv := {"id": "test_hit", "power": power, "category": "physical", "kind": "dash"}
	var dist := maxf(a.moves.phys.launch_dist(mv, 1.0, false, f, true), min_dist)
	a.moves.phys.launch(f, Vector3(1, 0, 0), dist, false, power, a.player)
	for i in 90:
		if f.launch_t <= 0.0:
			break
		f._launch_step(DT)


func _count_fx(a: Node) -> Array:
	var debris := 0
	var rubble := 0
	for c in a.get_children():
		if c is ArenaDebris:
			debris += 1
		elif c.has_meta("rubble"):
			rubble += 1
	return [debris, rubble]


func _formula() -> void:
	var heavy := D.impact_of(120.0, 6.5, 460.0)
	var light := D.impact_of(40.0, 4.3, 3.5)
	check(heavy > float(D.TOUGH.pillar), "Snorlax + golpe forte passa da coluna (%.1f)" % heavy)
	check(
		light < float(D.TOUGH.pillar) * D.CHIP_MIN, "Rattata + golpe fraco nem lasca (%.1f)" % light
	)
	check(D.impact_of(0.0, 8.0, 40.0) > 0.0, "arremesso sem poder (Whirlwind) ainda bate")
	check(D.impact_of(120.0, 0.0, 460.0) == 0.0, "parado não quebra nada")


func _heavy() -> void:
	var a := _arena([Mon.create("snorlax", 50)], [Mon.create("rattata", 50)], 3)
	_clean(a)
	var ter: BattleTerrain = a.terrain
	var f: BattleFighter = a.player
	var fired: Array = []
	ter.obstacles_changed.connect(func(k: String, _p: Vector3) -> void: fired.append(k))
	var rev0 := ter.obstacles_rev
	# Caixa.
	var crate := _crate(a, Vector3(-6, 0, 0))
	var hp0 := f.hp
	_throw(a, f, crate.pos, BattleField.OBJ_R + BattleField.BODY_R, 120.0)
	check(not a.field.objects.has(crate), "Snorlax arremessado quebra a caixa")
	check(f.hp < hp0, "quem bateu ainda toma o dano da batida (%d -> %d)" % [hp0, f.hp])
	check("crate" in fired, "obstacles_changed avisa a caixa (%s)" % [fired])
	check(ter.obstacles_rev > rev0, "obstacles_rev sobe")
	var fx := _count_fx(a)
	check(fx[0] > 0, "pedaços voando (%d)" % fx[0])
	if ter.lattice:
		check(fx[1] > 0, "entulho de voxel no chão (%d)" % fx[1])
	# Árvore: cai na direção do arremesso.
	ter.props.add("tree", Vector3(0, 0, 4))
	var tree: Dictionary = ter.props.of_kind("tree")[0]
	_throw(a, f, tree.pos, BattleProps.SOLID_R.tree + D.BODY_R, 120.0)
	check(
		String(tree.state) in ["tip", "fallen"], "a árvore quebra com o impacto (%s)" % tree.state
	)
	for i in 30:
		ter.props.tick(DT)
	check(tree.kind == "log", "a árvore caiu e virou tronco")
	check(Vector3(tree.dir).dot(Vector3(1, 0, 0)) > 0.7, "caiu na direção do arremesso")
	check("tree" in fired, "obstacles_changed avisa a árvore")
	# Coluna.
	var col := _pillar(a, Vector3(6, 0, -4))
	var at: Vector3 = col.pos + Vector3(0, 1.0, 0)
	check(ter.blocks_shot(at), "coluna cobre antes")
	f.hp = f.max_hp
	_throw(a, f, col.pos, float(col.r) + D.BODY_R, 120.0)
	check(not ter.biomes.solids.has(col), "Snorlax arremessado derruba a coluna")
	check(not ter.blocks_shot(at), "coluna destruída não para mais tiro")
	check("pillar" in fired, "obstacles_changed avisa a coluna")
	a.free()


func _light() -> void:
	var a := _arena([Mon.create("rattata", 50)], [Mon.create("snorlax", 50)], 4)
	_clean(a)
	var ter: BattleTerrain = a.terrain
	var f: BattleFighter = a.player
	var col := _pillar(a, Vector3(4, 0, 0))
	# Golpe fraco (40): o empurrão mínimo do contato forte, o arremesso mais curto que existe.
	_throw(a, f, col.pos, float(col.r) + D.BODY_R, 40.0, 0.81)
	check(ter.biomes.solids.has(col), "Rattata com golpe fraco não derruba a coluna")
	check(float(col.get("wear", 0.0)) == 0.0, "nem lasca a coluna")
	_throw(a, f, col.pos, float(col.r) + D.BODY_R, 120.0)
	check(ter.biomes.solids.has(col), "Rattata nem com golpe forte derruba a coluna")
	var crate := _crate(a, Vector3(-4, 0, 5))
	_throw(a, f, crate.pos, BattleField.OBJ_R + BattleField.BODY_R, 120.0)
	check(not a.field.objects.has(crate), "Rattata com golpe forte quebra a caixa")
	a.free()


func _relief() -> void:
	var a := _arena([Mon.create("snorlax", 50)], [Mon.create("rattata", 50)], 5)
	_clean(a)
	var ter: BattleTerrain = a.terrain
	var f: BattleFighter = a.player
	ter._add("hill", Vector3(0, 0, 0), 2.0, 1.25, 1.0)
	var hill: Dictionary = ter.obstacles[-1]
	_throw(a, f, hill.pos, 2.0, 120.0, 0.0, 0.3)
	check(ter.obstacles.has(hill), "morro grande aguenta uma batida")
	check(int(hill.hp) == BattleTerrain.HILL_HP - 1, "perde um degrau (vida %d)" % int(hill.hp))
	ter._add("hill", Vector3(-8, 0, 6), 1.0, 0.5, 0.5)
	var mound: Dictionary = ter.obstacles[-1]
	_throw(a, f, mound.pos, 1.0, 120.0, 0.0, 0.2)
	check(not ter.obstacles.has(mound), "montinho de terra desaba de uma vez")
	a.free()


func _support() -> void:
	var a := _arena([Mon.create("snorlax", 50)], [Mon.create("rattata", 50)], 6)
	_clean(a)
	var ter: BattleTerrain = a.terrain
	var fired: Array = []
	ter.obstacles_changed.connect(func(k: String, _p: Vector3) -> void: fired.append(k))
	# Pedregulho no topo do morro e um lutador em cima: o morro sai, os dois caem.
	ter._add("hill", Vector3(0, 0, 0), 2.2, 1.25, 1.0)
	var hill: Dictionary = ter.obstacles[-1]
	ter.props.add("boulder", Vector3(0.5, 0, 0))
	var boulder: Dictionary = ter.props.of_kind("boulder")[0]
	check(boulder.get("hill") == hill and float(boulder.y) > 0.5, "pedregulho no topo do morro")
	var g: BattleFighter = a.enemy
	_put(g, hill.pos + Vector3(-0.5, 0, 0.3))
	g.ground_y = float(hill.h)
	var hp0 := g.hp
	check(ter.remove_obstacle(hill, a.player, "test"), "remove_obstacle tira o morro")
	check(not ter.obstacles.has(hill), "morro fora do jogo")
	check(not ter.props.items.has(boulder), "o pedregulho de cima cai e quebra")
	check(g.hp < hp0 and g.stun_t > 0.0, "quem estava em cima cai (%d -> %d)" % [hp0, g.hp])
	check(
		"hill" in fired and "boulder" in fired,
		"obstacles_changed: morro e pedregulho (%s)" % [fired]
	)
	check(not ter.remove_obstacle(hill), "remover de novo não faz nada")
	# Caixa empilhada na coluna (ligação explícita "on"): a coluna cai pelo impacto, a caixa junto.
	var col := _pillar(a, Vector3(6, 0, 3))
	var crate := _crate(a, col.pos, {"y": float(col.h), "on": col})
	_throw(a, a.player, col.pos, float(col.r) + D.BODY_R, 120.0)
	check(not ter.biomes.solids.has(col), "a coluna caiu")
	check(not a.field.objects.has(crate), "a caixa de cima caiu e quebrou")
	# Pela pegada (sem ligação): objeto elevado dentro do topo do apoio.
	var col2 := _pillar(a, Vector3(-6, 0, -3))
	var crate2 := _crate(a, col2.pos, {"y": float(col2.h)})
	ter.remove_obstacle(col2)
	check(not a.field.objects.has(crate2), "o que estava apoiado pela pegada também cai")
	a.free()


func _fast_sim() -> void:
	var a := _arena([Mon.create("snorlax", 50)], [Mon.create("rattata", 50)], 7, {"fast_sim": true})
	_clean(a)
	var ter: BattleTerrain = a.terrain
	var crate := _crate(a, Vector3(-6, 0, 0))
	var col := _pillar(a, Vector3(6, 0, -4))
	_throw(a, a.player, crate.pos, BattleField.OBJ_R + BattleField.BODY_R, 120.0)
	_throw(a, a.player, col.pos, float(col.r) + D.BODY_R, 120.0)
	check(not a.field.objects.has(crate), "fast_sim: a caixa quebra")
	check(not ter.biomes.solids.has(col), "fast_sim: a coluna cai")
	var fx := _count_fx(a)
	check(fx[0] == 0 and fx[1] == 0, "fast_sim: nada visual (%s)" % [fx])
	a.free()
	# Luta inteira rápida no fast_sim com a IA (nada quebra).
	var b := _arena(
		[Mon.create("snorlax", 50)], [Mon.create("machamp", 50)], 8, {"fast_sim": true}, false
	)
	for i in 600:
		b.step(DT)
	check(true, "fast_sim: 10 s de luta sem erro")
	b.free()


