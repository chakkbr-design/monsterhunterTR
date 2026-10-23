class_name Capture
extends RefCounted

const STATUS_MULT:= { "sleep": 2.5, "freeze": 2.5, "paralysis": 1.5, "poison": 1.5, "burn": 1.5}
const CHECKS:= 4

const LOW_LEVEL_CAP:= 20
const LOW_LEVEL_BASE:= 30.0

static var _balls:= {}

static func balls() -> Dictionary:
	if _balls.is_empty():
		var f:= FileAccess.open("res://data/items.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		for b in d.balls:
			_balls[b.id] = b
	return _balls

static func ball(id: String) -> Dictionary:
	return balls().get(id, {})

static func ball_ids() -> Array:
	return balls().keys()

static func level_mult(level: int) -> float:
	if level >= LOW_LEVEL_CAP:
		return 1.0
	return (LOW_LEVEL_BASE - float(maxi(level, 1))) / 10.0

static func modified_rate(max_hp: int, hp: int, catch_rate: int, ball_mult: float, status:= "", level:= 100) -> float:
	var m:= float(maxi(max_hp, 1))
	var a:= (3.0 * m - 2.0 * float(clampi(hp, 1, max_hp))) * float(catch_rate) * ball_mult / (3.0 * m)
	a *= level_mult(level)
	return maxf(a * float(STATUS_MULT.get(status, 1.0)), 1.0)

static func shake_prob(a: float) -> float:
	if a >= 255.0:
		return 1.0
	var b:= floorf(65536.0 / pow(255.0 / a, 0.1875))
	return clampf(b / 65536.0, 0.0, 1.0)

static func catch_chance(a: float) -> float:
	return pow(shake_prob(a), CHECKS)

static func roll(a: float, rng: RandomNumberGenerator = null) -> int:
	if a >= 255.0:
		return CHECKS
	var b:= floori(65536.0 / pow(255.0 / a, 0.1875))
	for i in CHECKS:
		var r:= rng.randi_range(0, 65535) if rng else randi_range(0, 65535)
		if r >= b:
			return i
	return CHECKS

static func throw_ball(max_hp: int, hp: int, catch_rate: int, ball_id: String, status:= "", level:= 100) -> Dictionary:
	var bd:= ball(ball_id)
	if bd.get("guaranteed", false):
		return { "a": 255.0, "shakes": CHECKS, "caught": true}
	var a:= modified_rate(max_hp, hp, catch_rate, float(bd.get("catch_mult", 1.0)), status, level)
	var s:= roll(a)
	return { "a": a, "shakes": s, "caught": s >= CHECKS}

static func fail_line(shakes: int) -> String:
	return["Oh no! The Pokémon broke free!", "Aww! It appeared to be caught!", "Aargh! Almost had it!", "Gah! It was so close, too!"][clampi(shakes, 0, 3)]
