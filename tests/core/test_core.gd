extends SceneTree
## Rodar: godot --headless --path . --script res://tests/core/test_core.gd

var _fails := 0
var _count := 0


func _init() -> void:
	_stats()
	_growth()
	_capture()
	_damage()
	_mon()
	_dex()
	print("core: %d checks, %d falhas" % [_count, _fails])
	quit(1 if _fails else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		print("FALHOU: ", what)


func _stats() -> void:
	# Bulbasaur base HP 45, IV 31, EV 0, nível 50 -> 120 HP (fórmula oficial).
	check(StatCalc.stat("hp", 45, 31, 0, 50, "hardy") == 120, "hp nível 50")
	check(StatCalc.stat("atk", 49, 31, 0, 50, "adamant") == int(69 * 1.1), "atk com natureza +")
	check(StatCalc.stage_mult(2) == 2.0 and StatCalc.stage_mult(-2) == 0.5, "estágios")
	check(is_equal_approx(StatCalc.acc_stage_mult(-3), 0.5), "estágio de precisão")
	check(
		(
			StatCalc.battle_speed_factor(100, 50) > 1.2
			and StatCalc.battle_speed_factor(100, 50) < 1.3
			and StatCalc.battle_speed_factor(50, 100) < 0.8
			and StatCalc.battle_speed_factor(500, 10) == 1.45
			and StatCalc.battle_speed_factor(10, 500) == 0.7
		),
		"fator de speed limitado"
	)
	check(StatCalc.battle_speed_factor(80, 80) == 1.0, "speed igual = 1")


func _growth() -> void:
	check(Growth.exp_for_level("medium_fast", 10) == 1000, "medium_fast é n³")
	check(Growth.exp_for_level("medium_slow", 5) == 135, "medium_slow nível 5")
	check(
		(
			Growth.level_for_exp("medium_fast", 1000) == 10
			and Growth.level_for_exp("medium_fast", 999) == 9
		),
		"nível pela XP"
	)
	check(Growth.exp_gain(64, 5, 5, true) > Growth.exp_gain(64, 5, 5, false), "treinador dá 1,5x")


func _capture() -> void:
	check(
		is_equal_approx(Capture.level_mult(5), 2.5) and Capture.level_mult(20) == 1.0,
		"bônus de nível baixo"
	)
	var full := Capture.modified_rate(20, 20, 45, 1.0, "", 25)
	var low := Capture.modified_rate(20, 1, 45, 1.0, "", 25)
	check(low > full, "HP baixo ajuda")
	check(Capture.modified_rate(20, 1, 45, 1.0, "sleep", 25) > low, "sono ajuda")
	check(Capture.catch_chance(255.0) == 1.0, "a>=255 sempre pega")
	check(Capture.throw_ball(20, 20, 45, "master_ball").caught, "master ball")


func _damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var atk := {"level": 10, "types": ["fire"], "atk": 20, "def": 20, "spa": 25, "spd": 20}
	var grass := {"level": 10, "types": ["grass"], "atk": 20, "def": 20, "spa": 20, "spd": 20}
	var water := {"level": 10, "types": ["water"], "atk": 20, "def": 20, "spa": 20, "spd": 20}
	var ember := Dex.move("ember")
	check(not ember.is_empty(), "ember existe")
	var a := Damage.compute(atk, grass, ember, rng)
	var b := Damage.compute(atk, water, ember, rng)
	check(a.eff == 2.0 and b.eff == 0.5, "efetividade fogo")
	check(a.damage > b.damage and a.stab, "dano e STAB")
	check(
		Damage.compute(atk, grass, Dex.move("growl"), rng).damage == 0, "golpe de status sem dano"
	)
	# Faixa exata: base = ((2*10/5+2)*40*25/20)/50+2 = 8; *1.5*2*[0.85..1]
	var lo := 999
	var hi := 0
	for i in 300:
		var r := Damage.compute(atk, grass, ember, rng)
		if not r.crit:
			lo = mini(lo, r.damage)
			hi = maxi(hi, r.damage)
	check(lo == int(8 * 3 * 0.85) and hi <= 24, "faixa de dano %d-%d" % [lo, hi])


func _mon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var m := Mon.create("bulbasaur", 5, rng)
	check(m.species == "Bulbasaur" and m.level == 5 and m.hp == m.max_hp, "create")
	check(m.moves.size() >= 1 and m.moves.size() <= 4, "golpes iniciais")
	var ev := m.add_exp(m.exp_next_level - m.xp)
	check(m.level == 6 and ev.size() >= 1, "subiu de nível")
	m.add_exp(Growth.exp_for_level(m.growth, 16) - m.xp)
	check(m.evolution_target() == "Ivysaur", "pode evoluir no 16")
	m.evolve(m.evolution_target())
	check(m.species == "Ivysaur", "evoluiu")
	var copy := Mon.from_dict(m.to_dict())
	check(
		copy.species == m.species and copy.stats == m.stats and copy.moves == m.moves, "save/load"
	)
	check(m.add_evs({"spa": 300}).get("spa") == 252, "limite de EV")


func _dex() -> void:
	check(Dex.canon("PIKACHU") == "Pikachu", "nome sem caixa")
	check(Dex.encounter_table("route_1").get("rate") == 21, "tabela da rota 1")
	check(not Dex.trainer("bug_catcher_rick").is_empty(), "treinador")
	check(Dex.item("poke_ball").get("catch_mult") == 1.0, "item bola")
	check(Dex.cooldown(Dex.move("tackle")) >= Dex.MIN_COOLDOWN, "cooldown mínimo")
