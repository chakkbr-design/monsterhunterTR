class_name Dex
extends RefCounted
## Acesso estático aos dados em res://data. Ids de espécie aceitam qualquer caixa ("bulbasaur" ou "Bulbasaur").

static var _species := {}
static var _species_key := {}
static var _moves := {}
static var _move_order: Array = []
static var _types := {}
static var _abilities := {}
static var _items := {}
static var _trainers := {}
static var _encounters := {}
static var _loaded := false


static func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var s = _load_json("res://data/species.json")
	_species = s if s is Dictionary else {}
	_species.erase("_doc")
	for k in _species:
		_species_key[String(k).to_lower()] = k
	var m = _load_json("res://data/moves.json")
	if m is Dictionary:
		for mv in m.get("moves", []):
			_moves[mv.id] = mv
			_move_order.append(mv.id)
	var t = _load_json("res://data/types.json")
	_types = t if t is Dictionary else {}
	var a = _load_json("res://data/abilities.json")
	_abilities = a if a is Dictionary else {}
	_abilities.erase("_doc")
	var it = _load_json("res://data/items.json")
	if it is Dictionary:
		for b in it.get("balls", []):
			_items[b.id] = b
		for i in it.get("items", []):
			_items[i.id] = i
	var tr = _load_json("res://data/trainers.json")
	_trainers = tr if tr is Dictionary else {}
	_trainers.erase("_doc")


## Nome canônico da espécie como está no species.json ("" se não existir).
static func canon(id: String) -> String:
	_ensure()
	return String(_species_key.get(id.to_lower(), ""))


static func species(id: String) -> Dictionary:
	_ensure()
	return _species.get(canon(id), {})


static func all_species() -> Array:
	_ensure()
	return _species.keys()


static func move(id: String) -> Dictionary:
	_ensure()
	return _moves.get(id, {})


static func all_moves() -> Array:
	_ensure()
	return _move_order


static func ability(id: String) -> Dictionary:
	_ensure()
	return _abilities.get(id, {})


static func item(id: String) -> Dictionary:
	_ensure()
	return _items.get(id, {})


static func trainer(id: String) -> Dictionary:
	_ensure()
	return _trainers.get(id, {})


static func encounter_table(area: String) -> Dictionary:
	_ensure()
	if not _encounters.has(area):
		var e = _load_json("res://data/encounters/%s.json" % area)
		_encounters[area] = e if e is Dictionary else {}
	return _encounters[area]


static func moves_at(species_id: String, level: int) -> Array:
	var sp := species(species_id)
	var learned: Array = []
	for e in sp.get("learnset", []):
		if int(e[0]) <= level and not learned.has(e[1]) and _moves.has(e[1]):
			learned.append(e[1])
	if learned.is_empty():
		return sp.get("moves", []).duplicate()
	return learned.slice(maxi(learned.size() - 4, 0))


static func type_color(t: String) -> Color:
	_ensure()
	var c: Array = _types.get("colors", {}).get(t, [1, 1, 1])
	return Color(c[0], c[1], c[2])


static func effectiveness(atk_type: String, def_types: Array) -> float:
	_ensure()
	var row: Dictionary = _types.get("chart", {}).get(atk_type, {})
	var m := 1.0
	for t in def_types:
		m *= float(row.get(t, 1.0))
	return m


# --- Custos e tempos de golpe (mesmas regras do jogo de referência) ---

const PP_POOL_REF := 100.0
const COOLDOWN_SCALE := 2.5
const MIN_COOLDOWN := 1.6
const MIN_STATUS_COOLDOWN := 3.0
const STAT_MOVE_COOLDOWN_MULT := 2.5
## Golpes de status (todos) esperam bem mais: x3 no tempo base e no mínimo 8 s (o Caio pediu menos spam).
const STATUS_COOLDOWN_MULT := 3.0
const MIN_STATUS_COOLDOWN_VIVA := 8.0
## Golpes fortes: poder de verdade ("bp", Gen 9) acima de 70 alonga o cooldown: x(1 + (bp - 70) / 80).
const STRONG_BP := 70.0
const STRONG_BP_SPAN := 80.0
const GLOBAL_COOLDOWN := 1.0
## Especiais fortes (poder 80+) que saem do corpo carregam um pouco mais: a carga aparece.
const STRONG_SPECIAL_CHARGE := 0.4
const STRONG_SPECIAL_POWER := 80.0
const STRONG_SPECIAL_KINDS := ["projectile", "homing", "stream"]
const PREPARE_BY_KIND := {
	"dash": 0.18,
	"arc": 0.15,
	"multi_arc": 0.15,
	"whip": 0.15,
	"projectile": 0.15,
	"homing": 0.15,
	"stream": 0.2,
	"self_buff": 0.2,
	"debuff_aoe": 0.2,
	"clones": 0.2,
	"zone": 0.2,
}


static func pp_cost(mv: Dictionary) -> float:
	if mv.has("pp_cost"):
		return float(mv.pp_cost)
	if mv.has("uses"):
		return PP_POOL_REF / maxf(1.0, float(mv.uses))
	if mv.get("category", "") == "status":
		return 3.0
	var total := (
		float(mv.get("power", 0))
		* maxf(1.0, float(mv.get("count", 1)))
		* maxf(1.0, float(mv.get("hits", 1)))
	)
	if mv.get("kind", "") == "stream":
		total *= maxf(1.0, float(mv.get("duration", 1.0)) / float(mv.get("tick", 0.15)))
	return clampf(ceilf(total / 20.0), 1.0, 12.0)


static func prepare_time(mv: Dictionary) -> float:
	var kind := String(mv.get("kind", ""))
	if kind in ["beam", "aoe_self", "aoe_target"]:
		return 0.0
	var t := float(mv.windup) if mv.has("windup") else float(PREPARE_BY_KIND.get(kind, 0.15))
	if (
		kind in STRONG_SPECIAL_KINDS
		and String(mv.get("category", "")) == "special"
		and float(mv.get("power", 0.0)) >= STRONG_SPECIAL_POWER
	):
		t += STRONG_SPECIAL_CHARGE
	return t


static func cooldown(mv: Dictionary) -> float:
	if mv.has("cooldown"):
		return maxf(float(mv.cooldown), MIN_COOLDOWN)
	var weight := float(mv.fatigue) if mv.has("fatigue") else pp_cost(mv) * 10.0
	var cd := (
		(float(mv.get("windup", 0.0)) + float(mv.get("duration", 0.0)) + weight / 40.0)
		* COOLDOWN_SCALE
	)
	if mv.get("category", "") == "status":
		cd = maxf(cd * STATUS_COOLDOWN_MULT, MIN_STATUS_COOLDOWN_VIVA)
	else:
		cd = maxf(cd, MIN_COOLDOWN)
		var bp := float(mv.get("bp", 0))
		if bp > STRONG_BP:
			cd *= 1.0 + (bp - STRONG_BP) / STRONG_BP_SPAN
	return snappedf(cd, 0.1)


static func is_stat_move(mv: Dictionary) -> bool:
	if float(mv.get("power", 0)) > 0.0:
		return false
	if String(mv.get("kind", "")) in ["self_buff", "debuff_aoe"]:
		return true
	var fx: Dictionary = mv.get("effect", {})
	return fx.has("stat") and not fx.has("status")
