class_name EncounterRate
extends RefCounted
## Tall-grass ambush math (FRLG-style rate scaled to metres) plus the per-player step state.

const FRLG_TILE := 0.8
const SPACING := 2.0
const STEP_M := FRLG_TILE * SPACING  # one "step" = 1.6 m walked in grass
const DENOM := 1600.0
const COOLDOWN_BYPASS := 0.05
const NEW_TILE_GATE := 0.6
const GRACE_M := 4.0  # metres of grass without encounters after any battle

var steps_since := 0
var new_tile := false
var grace := 0.0
var _dist := 0.0


static func per_step_chance(rate: float) -> float:
	return clampf(rate * 16.0 / DENOM, 0.0, 1.0)


static func cooldown_steps(rate: float) -> int:
	if rate >= 80.0:
		return 0
	if rate < 10.0:
		return 8
	return 8 - int(rate / 10.0)


## Expected steps between encounters (starting right after one, ignoring the new-tile gate).
static func steps_to_encounter(rate: float) -> float:
	var p := per_step_chance(rate)
	if p <= 0.0:
		return INF
	var q := 1.0 - COOLDOWN_BYPASS * p
	var m := cooldown_steps(rate)
	var total := 0.0
	for k in m:
		total += pow(q, k)
	return total + pow(q, m) / p


static func metres_to_encounter(rate: float) -> float:
	return steps_to_encounter(rate) * STEP_M


## Called when the player goes from no grass to some grass.
func enter_grass() -> void:
	new_tile = true


func battle_ended() -> void:
	grace = GRACE_M
	steps_since = 0


## Accumulates distance walked in grass; returns true when a step rolls an encounter.
## blocked (Repel): the steps pass without any roll, like the original _grass_step.
func walk(d: float, rate: float, rng: RandomNumberGenerator, blocked := false) -> bool:
	_dist += d
	if grace > 0.0:
		grace = maxf(grace - d, 0.0)
	while _dist >= STEP_M:
		_dist -= STEP_M
		if not blocked and step(rate, rng):
			return true
	return false


## One grass step, in the reference order: grace, cooldown (5% bypass), first-step gate, chance.
func step(rate: float, rng: RandomNumberGenerator) -> bool:
	if grace > 0.0:
		return false
	var first := new_tile
	new_tile = false
	if steps_since < cooldown_steps(rate):
		steps_since += 1
		if rng.randf() >= COOLDOWN_BYPASS:
			return false
	if first and rng.randf() >= NEW_TILE_GATE:
		return false
	if rng.randf() < per_step_chance(rate):
		steps_since = 0
		return true
	return false
