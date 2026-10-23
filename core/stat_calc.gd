class_name StatCalc
extends RefCounted

const STATS := ["hp", "atk", "def", "spa", "spd", "spe"]
const BATTLE_STATS := ["atk", "def", "spa", "spd", "spe"]
const STAT_NAMES := {
	"hp": "HP",
	"atk": "Attack",
	"def": "Defense",
	"spa": "Sp. Atk",
	"spd": "Sp. Def",
	"spe": "Speed"
}
const STAT_SHORT := {
	"hp": "HP", "atk": "Atk", "def": "Def", "spa": "SpA", "spd": "SpD", "spe": "Spe"
}

const IV_MAX := 31
const EV_MAX_STAT := 252
const EV_MAX_TOTAL := 510

const NATURE_UP := 1.1
const NATURE_DOWN := 0.9
const NATURES := {
	"hardy": [],
	"lonely": ["atk", "def"],
	"brave": ["atk", "spe"],
	"adamant": ["atk", "spa"],
	"naughty": ["atk", "spd"],
	"bold": ["def", "atk"],
	"docile": [],
	"relaxed": ["def", "spe"],
	"impish": ["def", "spa"],
	"lax": ["def", "spd"],
	"timid": ["spe", "atk"],
	"hasty": ["spe", "def"],
	"serious": [],
	"jolly": ["spe", "spa"],
	"naive": ["spe", "spd"],
	"modest": ["spa", "atk"],
	"mild": ["spa", "def"],
	"quiet": ["spa", "spe"],
	"bashful": [],
	"rash": ["spa", "spd"],
	"calm": ["spd", "atk"],
	"gentle": ["spd", "def"],
	"sassy": ["spd", "spe"],
	"careful": ["spd", "spa"],
	"quirky": [],
}

const BATTLE_SPEED_EDGE := 0.2

const BATTLE_SPEED_SCALE := 5.0


static func stat(s: String, base: int, iv: int, ev: int, level: int, nature: String) -> int:
	var core := int((2 * base + iv + int(ev / 4.0)) * level / 100.0)
	if s == "hp":
		return core + level + 10
	return int((core + 5) * nature_mult(nature, s))


static func nature_mult(nature: String, s: String) -> float:
	var n: Array = NATURES.get(nature, [])
	if n.is_empty():
		return 1.0
	if n[0] == s:
		return NATURE_UP
	if n[1] == s:
		return NATURE_DOWN
	return 1.0


static func nature_label(nature: String) -> String:
	var n: Array = NATURES.get(nature, [])
	if n.is_empty():
		return "%s (neutral)" % nature.capitalize()
	return "%s (+%s −%s)" % [nature.capitalize(), STAT_NAMES[n[0]], STAT_NAMES[n[1]]]


static func random_nature(rng: RandomNumberGenerator = null) -> String:
	var keys := NATURES.keys()
	return keys[(rng.randi() if rng else randi()) % keys.size()]


static func random_ivs(rng: RandomNumberGenerator = null) -> Dictionary:
	var d := {}
	for s in STATS:
		d[s] = (rng.randi_range(0, IV_MAX) if rng else randi_range(0, IV_MAX))
	return d


static func zero_evs() -> Dictionary:
	var d := {}
	for s in STATS:
		d[s] = 0
	return d


const CRIT_CHANCES := [1.0 / 24.0, 1.0 / 8.0, 0.5, 1.0]
const CRIT_MULT := 1.5


static func crit_chance(stage: int) -> float:
	return CRIT_CHANCES[clampi(stage, 0, CRIT_CHANCES.size() - 1)]


static func stage_mult(stage: int) -> float:
	return (2.0 + stage) / 2.0 if stage >= 0 else 2.0 / (2.0 - stage)


static func battle_speed_factor(mine: float, theirs: float) -> float:
	var d := (mine - theirs) / BATTLE_SPEED_SCALE
	return 1.0 + BATTLE_SPEED_EDGE * signf(d) * (1.0 - exp(-d * d))


static func acc_stage_mult(stage: int) -> float:
	return (3.0 + stage) / 3.0 if stage >= 0 else 3.0 / (3.0 - stage)
