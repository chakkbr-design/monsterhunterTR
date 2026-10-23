extends SceneTree
## Headless: godot --headless --path . --script res://tests/world/test_encounters.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_rate_formulas()
	_test_expected_steps_monte_carlo()
	_test_grace_and_new_tile()
	_test_walk_distance()
	_test_weighted_pick()
	_test_levels()
	_test_corridor()
	print("[world] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func near(a: float, b: float, tol: float, what: String) -> void:
	check(absf(a - b) <= tol, "%s (got %f, want %f ±%f)" % [what, a, b, tol])


func _test_rate_formulas() -> void:
	near(EncounterRate.STEP_M, 1.6, 1e-6, "STEP_M")
	near(EncounterRate.per_step_chance(21), 0.21, 1e-6, "chance rate 21")
	near(EncounterRate.per_step_chance(10), 0.10, 1e-6, "chance rate 10")
	near(EncounterRate.per_step_chance(200), 1.0, 1e-6, "chance clamps to 1")
	check(EncounterRate.cooldown_steps(5) == 8, "cooldown rate<10 is 8")
	check(EncounterRate.cooldown_steps(10) == 7, "cooldown rate 10")
	check(EncounterRate.cooldown_steps(21) == 6, "cooldown rate 21")
	check(EncounterRate.cooldown_steps(79) == 1, "cooldown rate 79")
	check(EncounterRate.cooldown_steps(80) == 0, "cooldown rate 80")
	near(EncounterRate.steps_to_encounter(21), 10.33, 0.05, "expected steps rate 21")
	near(EncounterRate.metres_to_encounter(21), 16.5, 0.1, "expected metres rate 21")
	check(EncounterRate.steps_to_encounter(0) == INF, "rate 0 never")


## Simulated steps between encounters must match the closed form (no grace, no new tile).
func _test_expected_steps_monte_carlo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for rate in [10, 21, 50]:
		var e := EncounterRate.new()
		var n := 40000
		var steps := 0
		for i in n:
			while true:
				steps += 1
				if e.step(rate, rng):
					break
		var want := EncounterRate.steps_to_encounter(rate)
		near(float(steps) / n, want, want * 0.02, "monte carlo mean steps rate %d" % rate)


func _test_grace_and_new_tile() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var e := EncounterRate.new()
	e.battle_ended()
	check(e.grace == EncounterRate.GRACE_M and e.steps_since == 0, "battle_ended arms grace")
	var hits := 0
	for i in 2:  # 2 steps = 3.2 m < 4 m grace
		if e.walk(EncounterRate.STEP_M, 200, rng):
			hits += 1
	check(hits == 0, "no encounter during grace even at max rate")
	# After grace, rate>=80 has no cooldown and chance 1 -> next step hits.
	check(e.walk(EncounterRate.STEP_M, 200, rng), "encounter right after grace at rate 200")
	# New-tile gate: first step only passes 60% of the time (rate 200: chance 1, no cooldown).
	var passed := 0
	var n := 20000
	for i in n:
		var g := EncounterRate.new()
		g.enter_grass()
		if g.step(200, rng):
			passed += 1
		if g.new_tile:
			check(false, "new tile consumed by the first step")
	near(float(passed) / n, EncounterRate.NEW_TILE_GATE, 0.015, "new-tile gate 60%")
	# Cooldown bypass: right after an encounter at rate 21, a step passes cooldown only 5% then rolls 21%.
	var b := 0
	for i in n:
		var g := EncounterRate.new()
		if g.step(21, rng):
			b += 1
	near(float(b) / n, 0.05 * 0.21, 0.004, "cooldown bypass 5% x chance")


func _test_walk_distance() -> void:
	var rng := RandomNumberGenerator.new()
	var e := EncounterRate.new()
	check(not e.walk(1.5, 200, rng), "under one step: no roll")
	check(e.walk(0.2, 200, rng), "crossing 1.6 m rolls a step")


func _test_weighted_pick() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var t := {"rate": 15, "entries": [
		{"species": "A", "weight": 70, "mode": "both"},
		{"species": "B", "weight": 30, "mode": "grass"},
		{"species": "C", "weight": 50, "mode": "visible"},
		{"species": "D", "mode": "swim"},
	]}
	check(WildTable.rate(t) == 15, "table rate")
	check(WildTable.rate({}) == 21, "default rate 21")
	var n := 50000
	var grass := {"A": 0, "B": 0, "C": 0, "D": 0}
	var vis := {"A": 0, "B": 0, "C": 0, "D": 0}
	for i in n:
		grass[WildTable.pick(t, "grass", rng).species] += 1
		vis[WildTable.pick(t, "visible", rng).species] += 1
	near(float(grass.A) / n, 0.7, 0.01, "grass picks A 70%")
	near(float(grass.B) / n, 0.3, 0.01, "grass picks B 30%")
	check(grass.C == 0 and grass.D == 0, "grass excludes visible/swim")
	near(float(vis.A) / n, 70.0 / 120.0, 0.01, "visible picks A 70/120")
	near(float(vis.C) / n, 50.0 / 120.0, 0.01, "visible picks C 50/120")
	check(vis.B == 0, "visible excludes grass-only")
	check(WildTable.pick({"entries": [{"species": "D", "mode": "swim"}, {"species": "C", "weight": 50, "mode": "visible"}]}, "swim", rng).species == "D", "swim pool only")
	check(WildTable.pick({"entries": []}, "grass", rng).is_empty(), "empty table -> {}")
	# The real Route 1 table loads through Dex and splits 50/50.
	var r1 := Dex.encounter_table("route_1")
	check(WildTable.rate(r1) == 21, "route_1 rate 21")
	var pidgey := 0
	for i in 10000:
		if String(WildTable.pick(r1, "grass", rng).species) == "Pidgey":
			pidgey += 1
	near(pidgey / 10000.0, 0.5, 0.02, "route_1 Pidgey ~50%")


func _test_levels() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen := {}
	for i in 2000:
		var lv := WildTable.level_for({"level_range": [2, 5]}, rng)
		seen[lv] = true
	check(seen.keys().all(func(l: int) -> bool: return l >= 2 and l <= 5), "levels within 2..5")
	check(seen.size() == 4, "all levels 2..5 appear")
	check(WildTable.level_for({"level": 9, "level_range": [2, 5]}, rng) == 9, "fixed level wins")
	check(WildTable.level_for({}, rng) in [2, 3, 4], "default range 2..4")


func _test_corridor() -> void:
	var xf := Transform3D.IDENTITY  # facing -Z
	check(TrainerSight.in_corridor(xf, Vector3(0, 0, -3), 5.0), "ahead in sight")
	check(TrainerSight.in_corridor(xf, Vector3(0.85, 0, -4.9), 5.0), "edge of corridor")
	check(not TrainerSight.in_corridor(xf, Vector3(1.0, 0, -3), 5.0), "too wide")
	check(not TrainerSight.in_corridor(xf, Vector3(0, 0, -5.5), 5.0), "too far")
	check(not TrainerSight.in_corridor(xf, Vector3(0, 0, 2), 5.0), "behind")
	var turned := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(4, 0, -6))  # faces -X
	check(TrainerSight.in_corridor(turned, Vector3(0, 1, -6), 5.0), "turned trainer sees the path")
