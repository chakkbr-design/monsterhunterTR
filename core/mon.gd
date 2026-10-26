class_name Mon
extends RefCounted
## Um Pokémon do jogador ou selvagem: dados persistentes, sem nada de 3D.

const MAX_MOVES := 4
const FRIEND_START := 70
const PERSIST_STATUS := ["burn", "poison", "paralysis", "sleep"]

var species := ""
var nickname := ""
var level := 1
var nature := "hardy"
var ivs := {}
var evs := {}
var stats := {}
var hp := 0
var status := ""
## Só em memória, para a troca no meio da luta (BattleFighter.write_back/setup): segundos de
## paralisia que faltam (PARALYSIS_SECS), turnos de sono que faltam e status que não sobra fora da luta
## (toxic, que fica "poison" em status, e freeze).
var par_left := 0.0
var sleep_left := 0
var battle_status := ""
## Pool único de PP do Pokémon (não é por golpe).
var pp := 0.0
var gender := ""
var ability_slot := 0
var moves: Array = []
var xp := 0
var ball := "poke_ball"
var friend := FRIEND_START
var evo_pending := false
var evo_cancelled_level := 0

var display_name: String:
	get:
		return nickname if nickname != "" else species
var max_hp: int:
	get:
		return int(stats.get("hp", 1))
var pp_base: float:
	get:
		return float(_sp().get("pp", 100))
var types: Array:
	get:
		return _sp().get("types", ["normal"])
var growth: String:
	get:
		return _sp().get("growth", "medium_fast")
var ability: String:
	get:
		var abil: Array = _sp().get("abilities", [])
		return "" if abil.is_empty() else String(abil[clampi(ability_slot, 0, abil.size() - 1)])
var exp_this_level: int:
	get:
		return Growth.exp_for_level(growth, level)
var exp_next_level: int:
	get:
		return Growth.exp_for_level(growth, mini(level + 1, Growth.MAX_LEVEL))


static func create(species_id: String, lv: int, rng: RandomNumberGenerator = null) -> Mon:
	var m := Mon.new()
	m.species = Dex.canon(species_id)
	assert(m.species != "", "unknown species: %s" % species_id)
	m.level = clampi(lv, 1, Growth.MAX_LEVEL)
	m.ivs = StatCalc.random_ivs(rng)
	m.evs = StatCalc.zero_evs()
	m.nature = StatCalc.random_nature(rng)
	m.gender = _roll_gender(m.species, rng)
	m.ability_slot = _roll_ability_slot(m.species, rng)
	m.moves = Dex.moves_at(m.species, m.level)
	m.xp = Growth.exp_for_level(m.growth, m.level)
	m.recalc()
	m.heal_full()
	return m


func _sp() -> Dictionary:
	return Dex.species(species)


static func _roll_gender(species_id: String, rng: RandomNumberGenerator) -> String:
	var ratio := float(Dex.species(species_id).get("gender_ratio", 0.5))
	if ratio < 0.0:
		return ""
	return "female" if (rng.randf() if rng else randf()) < ratio else "male"


## Sorteia entre as habilidades normais; a oculta (hidden_ability, sempre a última) nunca sai sozinha.
static func _roll_ability_slot(species_id: String, rng: RandomNumberGenerator) -> int:
	var sp := Dex.species(species_id)
	var n: int = sp.get("abilities", []).size()
	if sp.has("hidden_ability") and n > 1:
		n -= 1
	if n < 2:
		return 0
	return 1 if (rng.randf() if rng else randf()) < 0.5 else 0


func recalc() -> void:
	var old_max := int(stats.get("hp", 0))
	var base: Dictionary = _sp().get("base", {})
	for s in StatCalc.STATS:
		stats[s] = StatCalc.stat(
			s, int(base.get(s, 50)), int(ivs.get(s, 0)), int(evs.get(s, 0)), level, nature
		)
	if old_max > 0:
		hp = clampi(hp + (max_hp - old_max), 0, max_hp)


func stat(k: String) -> int:
	return int(stats.get(k, 1))


func heal_full() -> void:
	hp = max_hp
	pp = pp_base
	cure()


## Tira o status e o que a luta guardou dele.
func cure() -> void:
	status = ""
	par_left = 0.0
	sleep_left = 0
	battle_status = ""


## Amizade 0..255 (mon.gd set_friend do original).
func set_friend(v: int) -> void:
	friend = clampi(v, 0, 255)


## Humor pela amizade (mon.gd mood do original): Wary < 70 <= Content < 150 <= Happy < 220 <= Devoted.
static func mood(v: int) -> String:
	if v < 70:
		return "Wary"
	if v < 150:
		return "Content"
	if v < 220:
		return "Happy"
	return "Devoted"


func is_fainted() -> bool:
	return hp <= 0


func catch_rate() -> int:
	return int(_sp().get("catch_rate", 190))


func ev_yield() -> Dictionary:
	return _sp().get("ev_yield", {})


func ev_total() -> int:
	var t := 0
	for s in evs:
		t += int(evs[s])
	return t


func add_evs(gain: Dictionary) -> Dictionary:
	var got := {}
	for s in gain:
		var room := mini(
			StatCalc.EV_MAX_STAT - int(evs.get(s, 0)), StatCalc.EV_MAX_TOTAL - ev_total()
		)
		var add := clampi(int(gain[s]), 0, maxi(room, 0))
		if add > 0:
			evs[s] = int(evs.get(s, 0)) + add
			got[s] = add
	if not got.is_empty():
		recalc()
	return got


## XP que este Pokémon dá ao ser derrotado por um de nível winner_level.
func exp_yield(winner_level: int, trainer := false) -> int:
	return Growth.exp_gain(int(_sp().get("base_exp", 50)), level, winner_level, trainer)


## Soma XP e devolve eventos: {type:"level", level} e {type:"move", move, learned}.
## Golpe com learned=false precisa da tela de esquecer golpe (replace_move).
func add_exp(amount: int) -> Array:
	var events: Array = []
	if level >= Growth.MAX_LEVEL or amount <= 0:
		return events
	xp += amount
	while level < Growth.MAX_LEVEL and xp >= Growth.exp_for_level(growth, level + 1):
		level += 1
		recalc()
		events.append({"type": "level", "level": level})
		if evolution_target() != "":
			evo_pending = true
		for e in _sp().get("learnset", []):
			if int(e[0]) == level and not moves.has(e[1]):
				var ok := moves.size() < MAX_MOVES
				if ok:
					moves.append(e[1])
				events.append({"type": "move", "move": e[1], "learned": ok})
	if level >= Growth.MAX_LEVEL:
		xp = Growth.exp_for_level(growth, Growth.MAX_LEVEL)
	return events


func evolution_target() -> String:
	var evo: Dictionary = _sp().get("evolution", {})
	if evo.is_empty() or String(evo.get("method", "level")) != "level":
		return ""
	if level < int(evo.get("level", 999)) or level <= evo_cancelled_level:
		return ""
	return Dex.canon(String(evo.get("into", "")))


## Evolui e devolve os golpes novos que não couberam.
func evolve(into: String) -> Array:
	species = Dex.canon(into)
	evo_cancelled_level = 0
	evo_pending = false
	var candidates: Array = []
	for e in _sp().get("learnset", []):
		if int(e[0]) == level:
			candidates.append(e[1])
	candidates.append_array(_sp().get("evo_moves", []))
	var missed: Array = []
	for id in candidates:
		if moves.has(id) or missed.has(id):
			continue
		if moves.size() < MAX_MOVES:
			moves.append(id)
		else:
			missed.append(id)
	recalc()
	return missed


func cancel_evolution() -> void:
	evo_cancelled_level = level
	evo_pending = false


func replace_move(k: int, id: String) -> void:
	if k >= 0 and k < moves.size():
		moves[k] = id


func to_dict() -> Dictionary:
	return {
		"species": species,
		"nickname": nickname,
		"level": level,
		"nature": nature,
		"ivs": ivs.duplicate(),
		"evs": evs.duplicate(),
		"hp": hp,
		"pp": pp,
		"status": status if status in PERSIST_STATUS else "",
		"gender": gender,
		"ability_slot": ability_slot,
		"moves": moves.duplicate(),
		"xp": xp,
		"ball": ball,
		"friend": friend,
		"evo_pending": evo_pending,
		"evo_cancelled_level": evo_cancelled_level
	}


static func from_dict(d: Dictionary) -> Mon:
	var m := Mon.new()
	m.species = Dex.canon(String(d.get("species", "")))
	m.nickname = d.get("nickname", "")
	m.level = int(d.get("level", 1))
	m.nature = d.get("nature", "hardy")
	m.ivs = d.get("ivs", StatCalc.random_ivs())
	m.evs = d.get("evs", StatCalc.zero_evs())
	m.gender = d.get("gender", "")
	m.ability_slot = int(d.get("ability_slot", 0))
	m.moves = d.get("moves", Dex.moves_at(m.species, m.level))
	m.xp = int(d.get("xp", Growth.exp_for_level(m.growth, m.level)))
	m.ball = d.get("ball", "poke_ball")
	m.friend = int(d.get("friend", FRIEND_START))
	m.evo_pending = bool(d.get("evo_pending", false))
	m.evo_cancelled_level = int(d.get("evo_cancelled_level", 0))
	m.recalc()
	m.hp = clampi(int(d.get("hp", m.max_hp)), 0, m.max_hp)
	m.pp = float(d.get("pp", m.pp_base))
	m.status = d.get("status", "")
	return m
