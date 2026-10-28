extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_entry.gd
## Entrada na troca e no substituto (Caio, 2026-10-27): sem reagrupar; o treinador escolhe onde o
## Pokémon entra (BattleArena._entry_at), na distância do perfil dele até o adversário, dentro da quadra.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0
var _ran := false


func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	_spot()
	_whole_fight()
	print("entry: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)
	return true


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _arena(seed: int) -> Node:
	var a: Node = load(ARENA).instantiate()
	a.manual = true
	root.add_child(a)
	a.start(
		[Mon.create("squirtle", 50), Mon.create("pikachu", 50), Mon.create("machop", 50)],
		[Mon.create("bulbasaur", 50), Mon.create("charmander", 50), Mon.create("abra", 50)],
		{
			"kind": "trainer",
			"autoplay": true,
			"seed": seed,
			"speed": 1.0,
			"no_rewards": true,
			"fast_sim": true,
			"arena": Cfg.ARENA
		}
	)
	for i in 600:
		if a.state != "intro":
			break
		a.step(DT)
	return a


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _spot() -> void:
	var a := _arena(5)
	var foe: BattleFighter = a.enemy
	foe.position = Vector3(6, 0, -4)
	var inner: Rect2 = a.rect.grow(-a.ENTRY_WALL + 0.01)
	for sp in ["machop", "abra", "pikachu"]:
		var at: Vector3 = a._entry_at(0, Mon.create(sp, 50), foe.position)
		var d := _flat(at, foe.position)
		check(
			d >= a.ENTRY_MIN - 0.01 and d <= a.ENTRY_MAX + 0.01,
			(
				"%s entra a %.1f m do adversário (entre %.0f e %.0f)"
				% [sp, d, a.ENTRY_MIN, a.ENTRY_MAX]
			)
		)
		check(inner.has_point(Vector2(at.x, at.z)), "%s entra dentro da quadra (%s)" % [sp, at])
	# Encostado na parede: o ponto vem para dentro.
	foe.position = Vector3(a.rect.end.x - 0.6, 0, 0)
	var at2: Vector3 = a._entry_at(0, Mon.create("abra", 50), foe.position)
	check(inner.has_point(Vector2(at2.x, at2.z)), "adversário na parede: entra dentro (%s)" % at2)
	check(a.get("regroup") == null, "sem reagrupar na arena")
	a.queue_free()


## Luta 3x3 inteira: os substitutos entram e a luta nunca para para reagrupar.
func _whole_fight() -> void:
	var a := _arena(11)
	var paused := 0
	var entries := 0
	var near := 0
	var seen := {}
	for i in int(400.0 / DT):
		if a.state != "fight":
			break
		a.step(DT)
		if a.energy_pause != "":
			paused += 1
		for f in a.fighters:
			if is_instance_valid(f) and f.active() and not seen.has(f):
				seen[f] = true
				entries += 1
				for o in a.fighters:
					if is_instance_valid(o) and o.active() and o.side != f.side:
						if _flat(o.position, f.position) < a.ENTRY_MIN - 0.5:
							near += 1
	check(a.state != "fight", "a luta 3x3 terminou (%s)" % a.state)
	check(paused == 0, "luta nunca parou para reagrupar (%d passos)" % paused)
	check(entries >= 4, "substitutos entraram (%d)" % entries)
	check(near == 0, "ninguém entrou colado no adversário (%d)" % near)
	a.queue_free()
