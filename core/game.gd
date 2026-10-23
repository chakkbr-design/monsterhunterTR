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

var _arena: Node = null


func is_busy() -> bool:
	return _arena != null


func first_healthy() -> int:
	for i in party.size():
		if not party[i].is_fainted():
			return i
	return -1


func add_mon(m: Mon) -> void:
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
		"pc": pc.map(func(m): return m.to_dict()), "bag": bag, "money": money, "flags": flags}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", []).map(func(x): return Mon.from_dict(x))
	pc = d.get("pc", []).map(func(x): return Mon.from_dict(x))
	bag = d.get("bag", {})
	money = int(d.get("money", START_MONEY))
	flags = d.get("flags", {})


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


func request_battle(enemies: Array, opts: Dictionary, host: Node3D, at: Vector3) -> void:
	if is_busy():
		return
	if not ResourceLoader.exists(ARENA_SCENE):
		battle_started.emit()
		battle_finished.emit({"outcome": "win"})
		return
	_arena = load(ARENA_SCENE).instantiate()
	host.add_child(_arena)
	_arena.global_position = at
	_arena.finished.connect(_on_arena_finished, CONNECT_ONE_SHOT)
	battle_started.emit()
	_arena.start(party, enemies, opts)


func _on_arena_finished(result: Dictionary) -> void:
	if result.get("outcome") == "caught" and result.get("caught_mon") is Mon:
		add_mon(result.caught_mon)
	if result.get("outcome") == "lose":
		money /= 2
		heal_party()
	var a := _arena
	_arena = null
	if is_instance_valid(a):
		a.queue_free()
	battle_finished.emit(result)
