extends Node
## Estado do jogador e ponte overworld <-> batalha. Ver docs/CONTRATO.md.

signal battle_started
signal battle_finished(result: Dictionary)
## Há golpes esperando a tela de esquecer golpe (ver pending_learns).
signal learn_requested
## Há Pokémon esperando a tela de evolução (ver pending_evolutions).
signal evolution_requested

const ARENA_SCENE := "res://battle/battle_arena.tscn"
const PARTY_MAX := 6
const START_MONEY := 3000

var party: Array = []
var pc: Array = []
var bag: Dictionary = {"poke_ball": 10, "potion": 3}
var money := START_MONEY
var flags: Dictionary = {}
var player_name := "RED"
var rival_name := "BLUE"
## "male" ou "female".
var player_gender := "male"
## Tempo de jogo em segundos (conta fora da tela de título).
var play_time := 0.0
## Número do Cartão de Treinador (sorteado no novo jogo).
var trainer_id := 0

## Iniciais oferecidos no laboratório, na ordem da mesa.
const STARTERS := ["Bulbasaur", "Charmander", "Squirtle"]
## O rival pega o inicial com vantagem sobre o seu.
const RIVAL_PICK := {"Bulbasaur": "Charmander", "Charmander": "Squirtle", "Squirtle": "Bulbasaur"}
const STARTER_LEVEL := 5
## Pokédex: espécie -> true.
var seen: Dictionary = {}
var caught: Dictionary = {}

const TRAINER_PAYOUTS := {
	"rival": 35, "youngster": 16, "bug_catcher": 12, "lass": 16, "camper": 20,
	"picnicker": 20, "hiker": 36, "jr_trainer": 20, "gym_leader": 99,
}

## Golpes que não couberam: [{mon: Mon, move: String}]. A UI consome com resolve_learn.
var pending_learns: Array = []
## Pokémon que podem evoluir agora. A tela Evolution consome com resolve_evolution.
var pending_evolutions: Array = []

## Último save carregado (posição etc.). Vazio num jogo novo.
var last_save: Dictionary = {}
## Onde o próximo mapa deve pôr o jogador: {zone, spawn} ou {interior, spawn}. A RouteWorld consome e limpa.
var spawn_request: Dictionary = {}

var _arena: Node = null


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s and not s.scene_file_path.begins_with("res://ui/front/"):
		play_time += delta


func _ready() -> void:
	# Testes headless começam sempre de um jogo novo.
	if DisplayServer.get_name() != "headless":
		last_save = load_game()
var _opts := {}
var _enemies: Array = []


## Tipo da batalha em andamento ("wild", "trainer" ou "").
func battle_kind() -> String:
	return String(_opts.get("kind", ""))


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


## Novo jogo: zera tudo e guarda os nomes.
func new_game(p_name: String, r_name: String, gender := "male") -> void:
	party = []
	pc = []
	bag = {"potion": 1}
	money = START_MONEY
	flags = {}
	seen = {}
	caught = {}
	pending_learns = []
	last_save = {}
	player_name = p_name if p_name != "" else "RED"
	rival_name = r_name if r_name != "" else "BLUE"
	player_gender = gender
	play_time = 0.0
	trainer_id = randi_range(10000, 99999)


## Escolha do inicial: entra na equipe e define o do rival (flag rival_starter, lida pelo trainers.json).
func choose_starter(species: String) -> Mon:
	var m := Mon.create(species, STARTER_LEVEL)
	add_mon(m)
	flags["starter"] = m.species
	flags["rival_starter"] = RIVAL_PICK.get(m.species, "Squirtle")
	return m


## Troca {PLAYER} e {RIVAL} num texto de diálogo.
func fill_names(text: String) -> String:
	return text.replace("{PLAYER}", player_name).replace("{RIVAL}", rival_name)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


# --- PC: caixas de BOX_SIZE, lista única em pc ---

const BOX_SIZE := 30
const BOX_COUNT := 8


func pc_full() -> bool:
	return pc.size() >= BOX_SIZE * BOX_COUNT


## Guarda o Pokémon da equipe no PC. Recusa se ficaria sem Pokémon de pé na equipe.
func deposit(party_index: int) -> bool:
	if party_index < 0 or party_index >= party.size() or pc_full():
		return false
	var healthy := 0
	for i in party.size():
		if i != party_index and not party[i].is_fainted():
			healthy += 1
	if healthy == 0:
		return false
	pc.append(party.pop_at(party_index))
	return true


func withdraw(pc_index: int) -> bool:
	if pc_index < 0 or pc_index >= pc.size() or party.size() >= PARTY_MAX:
		return false
	party.append(pc.pop_at(pc_index))
	return true


func release(pc_index: int) -> bool:
	if pc_index < 0 or pc_index >= pc.size():
		return false
	pc.remove_at(pc_index)
	return true


func swap_party(a: int, b: int) -> void:
	if a >= 0 and b >= 0 and a < party.size() and b < party.size():
		var t = party[a]
		party[a] = party[b]
		party[b] = t


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
	var fx: Dictionary = Dex.item(id).get("effect", {})
	if fx.has("teach") and m.moves.size() >= Mon.MAX_MOVES:
		queue_learn(m, fx.teach)
		learn_requested.emit()
		return "%s quer aprender %s." % [m.display_name, Dex.move(fx.teach).get("name", fx.teach)]
	var wanted: Array = []
	if fx.has("level"):
		for e in Dex.species(m.species).get("learnset", []):
			if int(e[0]) > m.level and int(e[0]) <= m.level + int(fx.level):
				wanted.append(e[1])
	var msg := Items.use(id, m)
	for mv in wanted:
		queue_learn(m, mv)
	if not pending_learns.is_empty():
		learn_requested.emit()
	if Dex.item(id).get("category", "") != "tm":
		take_item(id)
	return msg


# --- Save: user://save.json, gravado num temporário e renomeado ---

## Testes trocam para não sobrescrever o save de verdade.
var save_path := "user://save.json"
const SAVE_VERSION := 1


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "party": party.map(func(m): return m.to_dict()),
		"pc": pc.map(func(m): return m.to_dict()), "bag": bag, "money": money, "flags": flags,
		"seen": seen.keys(), "caught": caught.keys(),
		"player_name": player_name, "rival_name": rival_name, "player_gender": player_gender, "play_time": play_time, "trainer_id": trainer_id}


func from_dict(d: Dictionary) -> void:
	party = d.get("party", []).map(func(x): return Mon.from_dict(x))
	pc = d.get("pc", []).map(func(x): return Mon.from_dict(x))
	bag = d.get("bag", {})
	money = int(d.get("money", START_MONEY))
	flags = d.get("flags", {})
	player_name = d.get("player_name", "RED")
	rival_name = d.get("rival_name", "BLUE")
	player_gender = d.get("player_gender", "male")
	play_time = float(d.get("play_time", 0.0))
	trainer_id = int(d.get("trainer_id", 0))
	seen = {}
	caught = {}
	for sp in d.get("seen", []):
		seen[sp] = true
	for sp in d.get("caught", []):
		caught[sp] = true


func save_game(extra := {}) -> bool:
	var d := to_dict()
	d.merge(extra)
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path)) == OK


## Carrega o save e devolve o dicionário inteiro (vazio se não houver save).
func load_game() -> Dictionary:
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return {}
	from_dict(d)
	last_save = d
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


## Depois da batalha: com a tela de evolução (autoload Evolution) põe na fila;
## sem ela (testes, headless), evolui na hora. Devolve [[de, para], ...] do que evoluiu na hora.
func _evolve_pending() -> Array:
	var out: Array = []
	var ui := get_node_or_null("/root/Evolution") if is_inside_tree() else null
	for m in party:
		if m.evolution_target() == "" or m.is_fainted():
			continue
		if ui:
			if not pending_evolutions.has(m):
				pending_evolutions.append(m)
		else:
			var from: String = m.display_name
			resolve_evolution(m, true)
			out.append([from, m.species])
	return out


## Conclui a evolução de m: aceitar evolui (golpes que não couberem vão para a fila); recusar cancela até o próximo nível.
func resolve_evolution(m: Mon, accept: bool) -> void:
	pending_evolutions.erase(m)
	if not accept:
		m.cancel_evolution()
		return
	var into := m.evolution_target()
	if into == "":
		return
	for mv in m.evolve(into):
		queue_learn(m, mv)
	seen[m.species] = true
	caught[m.species] = true


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
		if not _opts.get("scripted", false):
			flags["trainer_" + id] = true
	elif outcome == "lose":
		# Batalha de roteiro (opts.scripted): perder não custa dinheiro.
		if not _opts.get("scripted", false):
			money /= 2
		heal_party()
	result.evolved = _evolve_pending()
	for x in result.get("exp", []):
		for e in x.get("events", []):
			if e.get("type") == "move" and not e.get("learned", true):
				queue_learn(x.mon, e.move)
	_opts = {}
	_enemies = []
	battle_finished.emit(result)
	if not pending_evolutions.is_empty():
		evolution_requested.emit()
	if not pending_learns.is_empty():
		learn_requested.emit()


## Põe um golpe na fila da tela de esquecer golpe (se o Pokémon ainda não sabe).
func queue_learn(m: Mon, move_id: String) -> void:
	if m.moves.has(move_id):
		return
	if m.moves.size() < Mon.MAX_MOVES:
		m.moves.append(move_id)
		return
	pending_learns.append({"mon": m, "move": move_id})


## Resolve o primeiro da fila: slot 0..3 troca aquele golpe; -1 desiste de aprender.
func resolve_learn(slot: int) -> void:
	if pending_learns.is_empty():
		return
	var p: Dictionary = pending_learns.pop_front()
	if slot >= 0:
		p.mon.replace_move(slot, p.move)
