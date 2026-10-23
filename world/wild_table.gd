class_name WildTable
extends RefCounted
## Pure helpers over an encounter table Dictionary ({rate, entries:[{species, level_range|level, weight, mode, behaviour}]}).

const DEFAULT_RATE := 21


static func rate(table: Dictionary) -> int:
	return int(table.get("rate", DEFAULT_RATE))


## Weighted pick among entries whose mode is `mode` or "both". Empty Dictionary if none.
static func pick(table: Dictionary, mode: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for e in table.get("entries", []):
		var m := String(e.get("mode", "both"))
		if m == mode or m == "both":
			pool.append(e)
			total += float(e.get("weight", 1))
	if pool.is_empty():
		return {}
	var r := rng.randf() * total
	for e in pool:
		r -= float(e.get("weight", 1))
		if r <= 0.0:
			return e
	return pool[-1]


static func level_for(entry: Dictionary, rng: RandomNumberGenerator) -> int:
	if entry.has("level"):
		return int(entry.level)
	var lr: Array = entry.get("level_range", [2, 4])
	return rng.randi_range(int(lr[0]), int(lr[1]))
