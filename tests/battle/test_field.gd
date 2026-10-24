extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_field.gd
## Terreno, objetos que quebram e clones: chamadas diretas com uma arena real.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0


func _initialize() -> void:
	_craters()
	_objects()
	_no_objects()
	_clones()
	_terrains()
	_clear()
	for i in 6:
		_full_battle(i)
	print("field: %d checks, %d falhas" % [_count, _fails])
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
	var got := {}
	a.finished.connect(func(r: Dictionary) -> void: got.merge(r), CONNECT_ONE_SHOT)
	a.set_meta("got", got)
	if not opts.has("speed"):
		opts["speed"] = 1.0
	if not opts.has("auto_battle"):
		opts["auto_battle"] = false
	a.start(party, enemies, opts)
	return a


func _still() -> Node:
	var a := _arena([Mon.create("charmander", 10)], [Mon.create("pidgey", 10)], {"seed": 7})
	for i in 80:
		a.step(DT)
	a.enemy.controller = "none"
	return a


func _craters() -> void:
	var a := _still()
	var f: BattleField = a.field
	var mv := Dex.move("earthquake")
	var at: Vector3 = a.player.position
	check(f.move_mult(a.player) == 1.0 or f.terrain_at(at) != "", "chão normal ou marca prévia")
	f.on_move_landed(a.enemy, mv, at, 1.5)
	check(f.terrain_at(at) == "crater", "cratera aparece")
	check(f.move_mult(a.player) < 0.8, "cratera reduz move_mult")
	for i in int(9.0 / DT):
		f.tick(DT)
	check(f.terrain_at(at) == "", "cratera some depois do tempo")
	check(f.move_mult(a.player) == 1.0, "move_mult volta a 1")
	for i in 20:
		f.on_move_landed(a.enemy, mv, Vector3(i * 0.5 - 5, 0, 3), 1.0)
	check(f.marks.size() <= BattleField.MAX_MARKS, "no máximo 12 manchas")
	_done(a)


func _objects() -> void:
	var a := _still()
	var f: BattleField = a.field
	check(f.objects.size() >= 2 and f.objects.size() <= 4, "2 a 4 objetos")
	for o in f.objects:
		check(o.pos.length() >= 3.0, "objeto longe do centro")
		check((o.pos - a.player_spot).length() >= 3.0, "objeto longe da entrada do jogador")
		check((o.pos - a.enemy_spot).length() >= 3.0, "objeto longe da entrada do inimigo")
	var o: Dictionary = f.objects[0]
	var n: int = f.objects.size()
	a.player.position = o.pos + Vector3(0.1, 0, 0)
	f.tick(DT)
	check(f.push_out(a.player) == Vector3.ZERO, "lutador empurrado para fora do objeto")
	for i in 3:
		f.on_move_landed(a.player, Dex.move("tackle"), o.pos, 0.8)
		for j in 30:
			f.tick(DT)
	check(f.objects.size() == n - 1, "objeto quebra com acertos")
	_done(a)


func _no_objects() -> void:
	var a := _arena(
		[Mon.create("charmander", 10)],
		[Mon.create("pidgey", 10)],
		{"seed": 3, "field_objects": false}
	)
	check(a.field.objects.is_empty(), "field_objects=false não cria objetos")
	_done(a)


func _clones() -> void:
	var a := _still()
	var f: BattleField = a.field
	var mv := Dex.move("double_team")
	f.spawn_clones(a.player, mv)
	check(f.clones.size() == 2, "dois clones")
	var absorbed := false
	for i in 40:
		if f.absorb_hit(a.enemy, a.player, mv):
			absorbed = true
			break
	check(absorbed and f.clones.size() == 1, "clone absorve e some")
	f.on_evaded(a.player)
	check(f.clones.is_empty(), "evasão tira um clone")
	f.spawn_clones(a.player, mv)
	for i in int(6.0 / DT):
		f.tick(DT)
	check(f.clones.is_empty(), "clones somem no fim da duração")
	_done(a)


func _terrains() -> void:
	var a := _still()
	var f: BattleField = a.field
	var p: Vector3 = a.player.position
	f.on_move_landed(a.enemy, Dex.move("water_gun"), p, 1.0)
	check(f.terrain_at(p) == "puddle", "poça")
	f.clear()
	f.on_move_landed(a.enemy, Dex.move("dig"), p, 1.0)
	check(f.terrain_at(p) == "hole", "buraco do Dig")
	f.clear()
	f.add_spikes(1, p)
	var hp: int = a.player.hp
	f.tick(DT)
	check(a.player.hp < hp, "spikes ferem quem pisa")
	f.clear()
	f.on_move_landed(a.enemy, Dex.move("ember"), p, 1.0)
	check(f.terrain_at(p) == "scorch", "grama queimada")
	hp = a.player.hp
	for i in 240:
		f.tick(DT)
	check(a.player.hp < hp and a.player.hp >= 1, "queimada fere sem matar")
	_done(a)


func _clear() -> void:
	var a := _still()
	var f: BattleField = a.field
	f.on_move_landed(a.enemy, Dex.move("earthquake"), Vector3(1, 0, 1), 1.5)
	f.spawn_clones(a.player, Dex.move("double_team"))
	f.clear()
	check(f.marks.is_empty() and f.objects.is_empty() and f.clones.is_empty(), "clear limpa tudo")
	_done(a)


func _full_battle(i: int) -> void:
	var a := _arena(
		[Mon.create("charmander", 12)],
		[Mon.create("pidgey", 12)],
		{"seed": 200 + i, "autoplay": true}
	)
	var t := 0.0
	while a.state != "done" and t < 600.0:
		a.step(DT)
		t += DT
	var outcome := String(a.get_meta("got").get("outcome", "none"))
	print("  luta %d -> %s em %.1f s" % [i, outcome, t])
	check(outcome in ["win", "lose"], "luta %d termina" % i)
	_done(a)


func _done(a: Node) -> void:
	a.free()
