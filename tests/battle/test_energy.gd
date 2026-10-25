extends SceneTree
## Rodar: godot --headless --path . --script res://tests/battle/test_energy.gd
## Modo de energia (BattleEnergy, opts.battle_mode "energy"): custo e cooldown, barra que enche,
## sem rodadas nem posições fixas, IA que recua para recuperar, não repete o mesmo golpe e luta até o
## fim no 1x1 e no 2x2; opção do treino.

const ARENA := "res://battle/battle_arena.tscn"
const Cfg := preload("res://ui/training/training_config.gd")
const DT := 1.0 / 60.0

var _fails := 0
var _count := 0
var _rest_sum := 0.0


func _initialize() -> void:
	_costs()
	_bar()
	for i in 3:
		_fight(i, false)
	_fight(0, true)
	# Com a barra enchendo rápido o descanso é curto: vale a soma das lutas.
	check(_rest_sum > 1.5, "recua para recuperar (%.1f s nas lutas)" % _rest_sum)
	_training()
	print("energy: %d checks, %d falhas" % [_count, _fails])
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
	# "-- vgc" roda as mesmas lutas no modo VGC, para comparar a duração.
	var mode := "vgc" if "vgc" in OS.get_cmdline_user_args() else "energy"
	opts.merge({"speed": 1.0, "battle_mode": mode, "no_rewards": true}, false)
	a.start(party, enemies, opts)
	return a


func _costs() -> void:
	var tackle := BattleEnergy.cost(Dex.move("tackle"))
	var flame := BattleEnergy.cost(Dex.move("flamethrower"))
	var beam := BattleEnergy.cost(Dex.move("hyper_beam"))
	var quick := BattleEnergy.cost(Dex.move("quick_attack"))
	check(
		tackle < flame and flame < beam,
		"golpe mais forte gasta mais (%d %d %d)" % [tackle, flame, beam]
	)
	check(beam <= BattleEnergy.MAX_COST, "custo limitado")
	check(BattleEnergy.cost(Dex.move("growl")) == BattleEnergy.STATUS_COST, "status gasta muito")
	check(quick < tackle, "prioridade gasta menos (%d < %d)" % [quick, tackle])
	var qmv := Dex.move("quick_attack")
	check(BattleEnergy.cooldown(qmv) > Dex.cooldown(qmv), "prioridade tem cooldown maior")
	check(
		BattleEnergy.cooldown(Dex.move("growl")) > BattleEnergy.cooldown(Dex.move("tackle")),
		"status com cooldown alto"
	)


func _bar() -> void:
	var a := _arena(
		[Mon.create("pikachu", 30)],
		[Mon.create("rattata", 30)],
		{"kind": "trainer", "battle_size": 1, "seed": 1}
	)
	var f: BattleFighter = a.player
	check(not a.turns.on, "sem fila de rodadas")
	check(f.energy_mode and f.pp_base == BattleEnergy.MAX, "barra de energia no lugar do PP")
	var pp_before := f.mon.pp
	a.step(DT)
	f.pp_max = 50.0
	f.gcd_t = 0.0
	f.move_cd.clear()
	var id := String(f.moves[0])
	var cost := f.pp_cost_of(Dex.move(id))
	f.stun_t = 0.0
	if a.moves.use(f, id):
		check(is_equal_approx(f.pp_max, 50.0 - cost), "golpe gasta energia")
	check(f.mon.pp == pp_before, "o PP do Pokémon não muda")
	f.pp_max = 0.0
	var e0 := f.pp_max
	for i in 60:
		f.tick(DT)
	check(f.pp_max > e0 + BattleEnergy.REGEN * 0.7, "energia enche com o tempo (%.1f)" % f.pp_max)
	f.stats["spe"] = 200.0
	var fast := BattleEnergy.speed_mult(f)
	f.stats["spe"] = 40.0
	var slw := BattleEnergy.speed_mult(f)
	check(fast > slw and fast <= BattleEnergy.SPEED_MAX, "Speed acelera um pouco")
	a.queue_free()


## Luta automática: golpes variados, sem repetir muito, recua para recuperar, anda pela arena e acaba.
func _fight(i: int, doubles: bool) -> void:
	var party := [Mon.create("pikachu", 30), Mon.create("geodude", 30)]
	var foes := [Mon.create("charmander", 30), Mon.create("squirtle", 30)]
	var a := _arena(
		party,
		foes,
		{
			"kind": "trainer",
			"battle_size": 2 if doubles else 1,
			"autoplay": true,
			"seed": 40 + i,
			"arena": Cfg.ARENA
		}
	)
	var tag := "%s seed %d" % ["2x2" if doubles else "1x1", i]
	var used := {}
	var last := {}
	var repeats := 0
	var total := 0
	var rest_t := 0.0
	var spots := {}
	var t := 0.0
	var prev_gcd := {}
	while t < 240.0 and a.state in ["intro", "fight"]:
		a.step(DT)
		t += DT
		if a.state != "fight":
			continue
		for f in a.fighters:
			if not is_instance_valid(f) or not f.active() or f.ai == null:
				continue
			var k: int = f.get_instance_id()
			if f.gcd_t > float(prev_gcd.get(k, 0.0)) + 0.01 and f.ai.last_move != "":
				total += 1
				used[f.ai.last_move] = true
				if last.get(k, "") == f.ai.last_move:
					repeats += 1
				last[k] = f.ai.last_move
			prev_gcd[k] = f.gcd_t
			if BattleEnergy.resting(f):
				rest_t += DT
			spots[Vector2i(int(f.position.x), int(f.position.z))] = true
	print(
		(
			"  %s: %.0f s, %d golpes, %d tipos, %d repetidos, descanso %.1f s, %d casas"
			% [tag, t, total, used.size(), repeats, rest_t, spots.size()]
		)
	)
	check(a.state not in ["intro", "fight"], "%s: a luta acaba (%.0f s)" % [tag, t])
	check(
		total >= 8 and used.size() >= 3,
		"%s: golpes variados (%d, %d tipos)" % [tag, total, used.size()]
	)
	check(repeats <= total * 0.45, "%s: pouca repetição (%d de %d)" % [tag, repeats, total])
	_rest_sum += rest_t
	check(spots.size() >= 12, "%s: anda pela arena (%d casas)" % [tag, spots.size()])
	a.queue_free()


func _training() -> void:
	var cfg := Cfg.default_config()
	check(Cfg.battle_mode(cfg) == "energy", "treino: energia é o padrão")
	check(Cfg.arena_opts(cfg, Vector3.ZERO).battle_mode == "energy", "treino: opção chega na arena")
	cfg.erase("battle_mode")
	check(Cfg.battle_mode(cfg) == "energy", "treino: config antiga vira energia")
	cfg["battle_mode"] = "vgc"
	check(Cfg.arena_opts(cfg, Vector3.ZERO).battle_mode == "vgc", "treino: VGC continua")
