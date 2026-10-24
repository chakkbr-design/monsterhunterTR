extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_pixel_fx.gd

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_catalog()
	await _in_arena()
	print("pixel_fx: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _catalog() -> void:
	for k in PixelFx.FX:
		var f := PixelFx.from_key(k, 1.0)
		check(f != null, "efeito carrega: " + k)
		if f:
			f.free()
	check(PixelFx.make("res://nao_existe.png", 1, 1, 10.0, 0.05) == null, "sem arquivo = null")
	check(PixelFx.icon("cmd_ofensivo") != null, "icone carrega")
	var f := PixelFx.make(PixelFx.DIR + "fx/fire_loop.png", 8, 8, 16.0, 0.05)
	var alive := true
	var n := 0
	while alive and n < 200:
		alive = f.tick(DT)
		n += 1
	check(n > 5 and n < 60, "tick acaba sozinho (%d)" % n)
	f.free()


func _in_arena() -> void:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	await process_frame
	a.start(
		[Mon.create("charmander", 20)],
		[Mon.create("rattata", 20)],
		{"seed": 5, "kind": "wild", "speed": 1.0, "auto_battle": false}
	)
	for i in 30:
		a.step(DT)
	var before: int = a.vfx.spawned
	var fx := PixelFx.pop(a, "fire", Vector3(0, 1, 0), 2.0, 0.3)
	check(fx != null and a.vfx.spawned == before + 1, "pop registra no vfx")
	for i in 40:
		a.step(DT)
	check(not is_instance_valid(fx) or fx.is_queued_for_deletion(), "pop some depois da vida")
	var n0: int = a.vfx.spawned
	a.combos._detonate(a.player, a.enemy, BattleCombos.REACTIONS[1])
	check(a.vfx.spawned >= n0 + 2, "reação solta estouro + floco")
	a.field._add_mark("crater", Vector3(2, 0, 2), 1.2, 0)
	check(a.field.marks[-1].node is Sprite3D, "crater usa decalque")
	a.field._add_object(Vector3(-3, 0, 3))
	check(a.field.objects[-1].node is Sprite3D, "objeto usa sprite")
	a.field._break(a.field.objects[-1])
	for i in 60:
		a.step(DT)
	a.queue_free()
