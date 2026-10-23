extends Node
## Estado do jogador e ponte overworld <-> batalha. Ver docs/CONTRATO.md.

signal battle_started
signal battle_finished(result: Dictionary)

const ARENA_SCENE := "res://battle/battle_arena.tscn"
const PARTY_MAX := 6
const START_MONEY := 3000

var party: Array = []
var pc: Array = []
var bag: Dictionary = {"poke_ball": 10, "potion": 3}
var money := START_MONEY
var flags: Dictionary = {}
## Pokédex: espécie -> true.
var seen: Dictionary = {}
var caught: Dictionary = {}

const TRAINER_PAYOUTS := {
	"rival": 35, "youngster": 16, "bug_catcher": 12, "lass": 16, "camper": 20,
	"picnicker": 20, "hiker": 36, "jr_trainer": 20, "gym_leader": 99,
}

var _arena: Node = null
var _opts := {}
var _enemies: Array = []


func is_busy() -> bool:
	return _arena != null


func first_healthy() -> int:
	for i in party.size():
		if not party[i].is_fainted():
			return i
	return -1


func mark_seen(species: String) -> void:
	seen[species] = true


func add_mon(m: Mon) -> void:
	seen[m.species] = true
	caught[m.species] = true
	if party.size() < PARTY_MAX:
		party.append(m)
	else:
		pc.append(m)


func heal_party() -> void:
	for m in party:
		m.heal_full()


func add_item(id: String, n := 1) -> void:
	bag[id] = int(bag.get(id, 0)) + n


## Desconta um item da bolsa. Falso se não tinha.
func take_item(id: String, n := 1) -> bool:
	if int(bag.get(id, 0)) < n:
		return false
	bag[id] = int(bag[id]) - n
	if bag[id] == 0:
		bag.erase(id)
	return true


func use_item(id: String, m: Mon) -> String:
	if not bag.has(id) or not Items.can_use(id, m):
		return ""
	var msg := Items.use(id, m)
	if Dex.item(id).get("category", "") != "tm":
		take_item(id)
	return msg


# --- Save: user://save.json, gravado num temporário e renomeado ---

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "party": party.map(func(m): return m.to_dict()),
		"pc": pc.map(func(m): return m.to_dict()), "bag": bag, "money": money, "flags": flags,
		"seen": seen.keys(), "caught": caught.keys()}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", []).map(func(x): return Mon.from_dict(x))
	pc = d.get("pc", []).map(func(x): return Mon.from_dict(x))
	bag = d.get("bag", {})
	money = int(d.get("money", START_MONEY))
	flags = d.get("flags", {})
	seen = {}
	caught = {}
	for sp in d.get("seen", []):
		seen[sp] = true
	for sp in d.get("caught", []):
		caught[sp] = true


func save_game(extra := {}) -> bool:
	var d := to_dict()
	d.merge(extra)
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH)) == OK


## Carrega o save e devolve o dicionário inteiro (vazio se não houver save).
func load_game() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return {}
	from_dict(d)
	return d


## Prêmio por vencer um treinador: reward fixo do JSON ou base da classe x nível do último Pokémon.
func trainer_payout(trainer_id: String, last_level: int) -> int:
	var t := Dex.trainer(trainer_id)
	if t.has("reward"):
		return int(t.reward)
	return int(TRAINER_PAYOUTS.get(String(t.get("class", "")), 16)) * maxi(last_level, 1)


func request_battle(enemies: Array, opts: Dictionary, host: Node3D, at: Vector3) -> void:
	if is_busy():
		return
	_opts = opts
	_enemies = enemies
	for e in enemies:
		mark_seen(e.species)
	if not ResourceLoader.exists(ARENA_SCENE):
		battle_started.emit()
		_finish({"outcome": "win"})
		return
	_arena = load(ARENA_SCENE).instantiate()
	host.add_child(_arena)
	_arena.global_position = at
	_arena.finished.connect(_on_arena_finished, CONNECT_ONE_SHOT)
	battle_started.emit()
	_arena.start(party, enemies, opts)


func _on_arena_finished(result: Dictionary) -> void:
	var a := _arena
	_arena = null
	if is_instance_valid(a):
		a.queue_free()
	_finish(result)


## Aplica as consequências da batalha e avisa o mundo. result ganha "prize" quando há dinheiro.
func _finish(result: Dictionary) -> void:
	var outcome: String = result.get("outcome", "")
	if outcome == "caught" and result.get("caught_mon") is Mon:
		add_mon(result.caught_mon)
	elif outcome == "win" and _opts.get("kind") == "trainer":
		var id := String(_opts.get("trainer_id", ""))
		var last: int = _enemies[-1].level if not _enemies.is_empty() else 1
		result.prize = trainer_payout(id, last)
		money += result.prize
		flags["trainer_" + id] = true
	elif outcome == "lose":
		money /= 2
		heal_party()
	_opts = {}
	_enemies = []
	battle_finished.emit(result)
