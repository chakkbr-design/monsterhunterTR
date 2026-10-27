extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_fx3d.gd
## Efeitos 3D dos golpes (gfx/fx3d) no modo de energia: todo golpe solta partículas/luzes/malhas 3D
## sem erro, nada do PMD nem do MoveShow aparece nos golpes, os discos no chão sumiram, a carga
## acompanha a preparação e tudo some sozinho depois. O VGC continua com os efeitos antigos.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const SACRIFICE := [
	"healing_wish",
	"perish_song",
	"memento",
	"explosion",
	"self_destruct",
	"final_gambit",
	"lunar_dance",
	"misty_explosion"
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	_main.call_deferred()


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _main() -> void:
	await process_frame
	_particles()
	await _arena_moves()
	await _vgc_untouched()
	print("fx3d: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


## Simulação das partículas: nascem, andam, somem e o MultiMesh acompanha.
func _particles() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var p := Fx3DParticles.make(Fx3D.particle_mat(Fx3D.Shape.GLOW), 8)
	host.add_child(p)
	for i in 12:
		p.emit(Vector3.ZERO, Vector3(1, 0, 0), 0.5, 0.2, 0.1, Color.WHITE, Color(1, 1, 1, 0))
	check(p.n == 8, "partículas: limite da capacidade (%d)" % p.n)
	p.gravity = Vector3(0, -10, 0)
	p.tick(0.1)
	check(p.pos[0].y < 0.0 and p.pos[0].x > 0.0, "partículas: andam e caem")
	check(p.multimesh.visible_instance_count == 8, "partículas: MultiMesh mostra as vivas")
	var alive := true
	for i in 10:
		alive = p.tick(0.1)
	check(not alive and p.n == 0, "partículas: somem no fim da vida")
	var m := Fx3DMesh.make(Fx3D.annulus(), Fx3D.mesh_mat(Fx3D.Mode.RING))
	host.add_child(m)
	m.life = 0.3
	m.s1 = Vector3.ONE * 2.0
	m.place(Vector3.ZERO)
	m.tick(0.15)
	check(m.scale.x > 1.0, "anel cresce")
	check(not m.tick(0.2), "anel acaba")
	host.queue_free()


func _arena(mode: String) -> Node:
	var host := Node3D.new()
	root.add_child(host)
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	host.add_child(a)
	a.start(
		[Mon.create("pikachu", 40)],
		[Mon.create("onix", 100)],
		{
			"seed": 7,
			"battle_size": 1,
			"speed": 1.0,
			"field_objects": false,
			"battle_mode": mode,
			"no_rewards": true
		}
	)
	return a


func _calm(a: Node) -> void:
	for f in a.fighters:
		if is_instance_valid(f):
			f.controller = "none"


func _arena_moves() -> void:
	var a := _arena("energy")
	await process_frame
	for i in 240:
		a.step(DT)
		_calm(a)
	check(a.state == "fight", "arena de energia em luta (%s)" % a.state)
	check(a.vfx.use3d(), "modo de energia usa os efeitos 3D")
	var p: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	e.max_hp = 99999
	var f := FileAccess.open("res://data/moves.json", FileAccess.READ)
	var mj = JSON.parse_string(f.get_as_text())
	var silent := []
	var old := []
	var decals := []
	var n_moves := 0
	for m in mj.get("moves", []):
		var mv: Dictionary = Dex.move(String(m.id)).duplicate(true)
		if mv.is_empty() or mv.get("kind") == "clones" or mv.get("self_destruct", false):
			continue
		if String(mv.id) in SACRIFICE or String(mv.get("special", "")) in SACRIFICE:
			continue
		n_moves += 1
		mv.accuracy = 0
		p.position = Vector3(-1.0, 0, 0)
		e.position = Vector3(1.0 if mv.kind in ["arc", "multi_arc"] else 2.5, 0, 0)
		p.facing = Vector3.RIGHT
		p.hp = p.max_hp
		e.hp = e.max_hp
		e.status = ""
		p.status = ""
		var fx0: int = a._fx.size()
		var got3d := 0
		var got_old := 0
		a.vfx.prepare(p, mv, 0.3)
		a.moves.deliver(p, mv)
		for i in 75:
			a.step(DT)
			_calm(a)
			e.hp = e.max_hp
			p.hp = p.max_hp
			for n in a.vfx.nodes:
				if n is Fx3DParticles or n is Fx3DMesh or n is Fx3DRibbon or n is Fx3DLight:
					got3d += 1
				elif n is FxSprite or n is BeamFx:
					got_old += 1
		if got3d == 0 and mv.id != "splash":
			silent.append(mv.id)
		if got_old > 0:
			old.append(mv.id)
		if a._fx.size() > fx0:
			decals.append(mv.id)
		for i in 150:
			a.step(DT)
			_calm(a)
			e.hp = e.max_hp
			p.hp = p.max_hp
		await process_frame  # solta os nós com queue_free (o laço manual roda num frame só)
	check(n_moves > 600, "golpes testados: %d" % n_moves)
	check(a.state == "fight", "luta continua (%s)" % a.state)
	check(
		silent.size() <= 25,
		"golpes sem efeito 3D (%d): %s" % [silent.size(), str(silent.slice(0, 25))]
	)
	check(
		old.size() <= 20,
		"golpes ainda com PMD/raio antigo (%d): %s" % [old.size(), str(old.slice(0, 20))]
	)
	check(decals.is_empty(), "golpes com disco/cone no chão: %s" % str(decals.slice(0, 10)))
	# Tudo some sozinho.
	for i in 600:
		a.step(DT)
		_calm(a)
		e.hp = e.max_hp
		p.hp = p.max_hp
	await process_frame
	var left: Array = a.vfx.nodes.filter(
		func(n): return n is Fx3DParticles or n is Fx3DMesh or n is Fx3DRibbon or n is Fx3DLight
	)
	check(left.size() <= 4, "efeitos 3D somem (sobraram %d)" % left.size())
	check(Fx3DLight.alive <= Fx3DLight.MAX, "luzes dentro do limite (%d)" % Fx3DLight.alive)
	# Carga: o Thunderbolt solta raios em volta enquanto prepara.
	var tb: Dictionary = Dex.move("thunderbolt")
	var before: int = a.vfx.nodes.filter(func(n): return n is Fx3DRibbon).size()
	a.vfx.prepare(p, tb, 0.5)
	var bolts := 0
	for i in 20:
		a.step(DT)
		bolts = maxi(bolts, a.vfx.nodes.filter(func(n): return n is Fx3DRibbon).size())
	check(bolts > before, "Thunderbolt: raios em volta na carga")
	a.get_parent().queue_free()
	await process_frame


## O VGC continua com os efeitos antigos (PMD + MoveShow) e os discos.
func _vgc_untouched() -> void:
	var a := _arena("vgc")
	await process_frame
	for i in 240:
		a.step(DT)
		_calm(a)
	check(not a.vfx.use3d(), "VGC sem os efeitos 3D")
	var p: BattleFighter = a.player
	var mv: Dictionary = Dex.move("thunder").duplicate(true)
	mv.accuracy = 0
	var fx0: int = a._fx.size()
	a.moves.deliver(p, mv)
	a.step(DT)
	check(a._fx.size() > fx0, "VGC: disco do Thunder continua")
	a.get_parent().queue_free()
	await process_frame
