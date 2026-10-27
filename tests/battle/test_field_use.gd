extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_field_use.gd
## Uso do campo (simulação headless, IA nos dois lados): ninguém passa mais de CORNER_MAX do tempo
## num canto nem WALL_MAX na parede; na dupla os parceiros não se embolam, ninguém fica colado num
## inimigo.

const ARENA := "res://battle/battle_arena.tscn"
const DT := 1.0 / 60.0
const SECS := 60.0
## Canto: a menos de CORNER_M de duas paredes. Parede: a menos de WALL_M de uma.
const CORNER_M := 1.5
const WALL_M := 1.0
const CORNER_MAX := 0.1
const WALL_MAX := 0.3
## Parceiros a menos de CLUMP_M (embolados) e inimigos colados a menos de STICK_M.
const CLUMP_M := 1.2
const CLUMP_MAX := 0.1
const STICK_M := 1.0
const STICK_MAX := 0.25

const TEAMS := [
	[["charmander", "pidgey"], ["squirtle", "mankey"]],
	[["pikachu", "geodude"], ["rattata", "onix"]],
	[["bulbasaur", "zubat"], ["psyduck", "sandshrew"]],
	[["oddish", "clefairy"], ["paras", "jigglypuff"]],
]

var _fails := 0
var _count := 0


func _initialize() -> void:
	for i in TEAMS.size():
		_sim(i, true)
	for i in 2:
		_sim(i, false)
	_corner_escape()
	print("field_use: %d checks, %d falhas" % [_count, _fails])
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


func _team(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if not Dex.species(id).is_empty():
			out.append(Mon.create(id, 20))
	return out


func _wall(a: Node, p: Vector3) -> Array:
	var r: Rect2 = a.rect
	var dx := minf(p.x - r.position.x, r.end.x - p.x)
	var dz := minf(p.z - r.position.y, r.end.y - p.z)
	return [dx, dz]


func _sim(i: int, doubles: bool) -> void:
	var pa := _team(TEAMS[i][0])
	var pb := _team(TEAMS[i][1])
	var opts := {"kind": "trainer", "autoplay": true, "seed": 700 + i, "no_rewards": true}
	opts["battle_size"] = 2 if doubles else 1
	var a := _arena(pa, pb, opts)
	var tag := "%s %d" % ["2x2" if doubles else "1x1", i]
	var samples := {}  # id -> [n, canto, parede, colado]
	var pair_n := 0
	var clump := 0
	var t := 0.0
	while a.state != "done" and t < SECS:
		a.step(DT)
		t += DT
		if a.state != "fight":
			continue
		var live: Array = a.fighters.filter(func(f): return is_instance_valid(f) and f.active())
		for f in live:
			var id: int = f.get_instance_id()
			var s: Array = samples.get(id, [0, 0, 0, 0])
			var w := _wall(a, f.position)
			s[0] += 1
			if w[0] < CORNER_M and w[1] < CORNER_M:
				s[1] += 1
			if minf(w[0], w[1]) < WALL_M:
				s[2] += 1
			var waiting: bool = _waiting(a, f)
			for g in live:
				# Colado: dois de lados diferentes juntos sem ninguém atacando (a investida encosta).
				if (
					g.side != f.side
					and waiting
					and _waiting(a, g)
					and f.flat_to(g).length() < STICK_M
				):
					s[3] += 1
					break
			samples[id] = s
		for side in 2:
			var mates: Array = live.filter(func(f): return f.side == side)
			if mates.size() == 2:
				pair_n += 1
				if mates[0].flat_to(mates[1]).length() < CLUMP_M:
					clump += 1
	var worst := [0.0, 0.0, 0.0]
	for s in samples.values():
		if int(s[0]) < 120:
			continue
		worst[0] = maxf(worst[0], float(s[1]) / s[0])
		worst[1] = maxf(worst[1], float(s[2]) / s[0])
		worst[2] = maxf(worst[2], float(s[3]) / s[0])
	print(
		(
			"  %s: %.0f s, canto %.0f%%, parede %.0f%%, colado %.0f%%, embolado %.0f%%"
			% [
				tag,
				t,
				worst[0] * 100.0,
				worst[1] * 100.0,
				worst[2] * 100.0,
				100.0 * clump / maxf(pair_n, 1)
			]
		)
	)
	check(worst[0] <= CORNER_MAX, "ninguém no canto mais de %d%% (%s)" % [CORNER_MAX * 100, tag])
	check(worst[1] <= WALL_MAX, "ninguém na parede mais de %d%% (%s)" % [WALL_MAX * 100, tag])
	check(worst[2] <= STICK_MAX, "ninguém colado no inimigo (%s)" % tag)
	if doubles:
		check(float(clump) / maxf(pair_n, 1) <= CLUMP_MAX, "parceiros não se embolam (%s)" % tag)
	a.free()


## Parado de verdade: não está se recuperando de um golpe, nem apanhando, nem desviando.
func _waiting(a: Node, f: BattleFighter) -> bool:
	return (
		f.ai.recover_t <= 0.0
		and f.ai.dodge_t <= 0.0
		and f.ai.threat_id < 0
		and f.can_act()
		and f.knock.length() < 0.5
		and f.prepare_t <= 0.0
		and f.dash_t <= 0.0
	)


## Encurralado com inimigo perto: foge rodeando (de lado), indo para o centro.
func _corner_escape() -> void:
	var a := _arena(
		[Mon.create("charmander", 20)],
		[Mon.create("squirtle", 20)],
		{"autoplay": true, "seed": 5, "battle_size": 1}
	)
	for k in 90:
		a.step(DT)
	var r: Rect2 = a.rect
	var f: BattleFighter = a.player
	var e: BattleFighter = a.enemy
	f.position = Vector3(r.position.x + 0.6, 0, r.position.y + 0.6)
	e.position = f.position + Vector3(1.2, 0, 1.2)
	var esc: Vector3 = f.ai.corner_escape()
	var away := -f.flat_to(e).normalized()
	var to_c := Vector3(r.get_center().x, 0, r.get_center().y) - f.position
	check(esc.length() > 0.5, "encurralado foge")
	check(esc.dot(to_c.normalized()) > 0.0, "foge para o lado aberto (centro)")
	check(absf(esc.dot(away)) < 0.9, "foge rodeando, não reto para trás")
	e.position = f.position + Vector3(6, 0, 6)
	check(f.ai.corner_escape() == Vector3.ZERO, "sem inimigo perto não foge")
	a.free()
