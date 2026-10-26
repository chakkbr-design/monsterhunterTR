extends Node
## Estado do jogador e ponte overworld <-> batalha. Ver docs/CONTRATO.md.

signal battle_started
signal battle_finished(result: Dictionary)
## Há golpes esperando a tela de esquecer golpe (ver pending_learns).
signal learn_requested
## Há Pokémon esperando a tela de evolução (ver pending_evolutions).
signal evolution_requested
## Autosave gravou (o HUD mostra "Salvando…").
signal saved

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
## Passos que ainda faltam do Repel (salvo). Ver use_field_item.
var repel_steps := 0
## Autosave ligado (SaveGame.enabled do original): só depois de new_game/load_game.
var save_enabled := false

## Iniciais oferecidos no laboratório, na ordem da mesa.
const STARTERS := ["Bulbasaur", "Charmander", "Squirtle"]
## O rival pega o inicial com vantagem sobre o seu.
const RIVAL_PICK := {"Bulbasaur": "Charmander", "Charmander": "Squirtle", "Squirtle": "Bulbasaur"}
const STARTER_LEVEL := 5
## Pokédex: espécie -> true.
var seen: Dictionary = {}
var caught: Dictionary = {}

const TRAINER_PAYOUTS := {
	"rival": 35,
	"youngster": 16,
	"bug_catcher": 12,
	"lass": 16,
	"camper": 20,
	"picnicker": 20,
	"hiker": 36,
	"jr_trainer": 20,
	"gym_leader": 99,
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

## PP_WORLD_REGEN do original (game.gd:232): fora da batalha cada Pokémon da equipe recupera
## 0,5% do PP base por segundo, mesmo dentro da bola.
const PP_WORLD_REGEN := 0.005


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s and not s.scene_file_path.begins_with("res://ui/front/"):
		play_time += delta
		if not is_busy():
			regen_pp(delta)
			friend_tick(delta)


## _regen_pp do original: devolve PP a quem está de pé e abaixo do máximo. Quem está fora da bola
## num piquenique ou descansando recupera pelo ritmo do piquenique (world/picnic.gd), não por aqui.
func regen_pp(delta: float) -> void:
	var picnicking := is_inside_tree() and get_tree().get_first_node_in_group("picnic") != null
	for m in party:
		if m.hp <= 0 or m.pp >= m.pp_base:
			continue
		if out.has(m) and (picnicking or resting.has(m)):
			continue
		m.pp = minf(m.pp_base, m.pp + m.pp_base * PP_WORLD_REGEN * delta)


# --- Companheiros fora da bola e amizade (game.gd:17-23, 636-860 do original) ---

const PET_GAIN := 6
const FEED_GAIN := 8
const PET_CD := 60.0
const FEED_CD := 90.0
const PASSIVE_TICK_S := 10.0
const PASSIVE_GAIN := 1
## Amizade perdida quando o Pokémon desmaia na batalha (battle.gd:1251 do original).
const FAINT_LOSS := 20

## Pokémon da equipe fora da bola, andando com o jogador (Game.companions do original; não vai
## para o save). As teclas 1-6 mandam e recolhem cada um; o mundo desenha um WorldCompanion por Mon.
var out: Array = []
## Mons descansando com o jogador (fase "rest" do pedido de descanso): o mundo cuida do ritmo.
var resting: Dictionary = {}
var _friend_cd: Dictionary = {}  ## Mon -> s até o próximo carinho/comida (um só para os dois)
var _passive_t := 0.0


func is_out(i: int) -> bool:
	return i >= 0 and i < party.size() and out.has(party[i])


## Índices da equipe fora da bola, em ordem.
func out_indices() -> Array:
	var r: Array = []
	for i in party.size():
		if out.has(party[i]):
			r.append(i)
	return r


## first_healthy(prefer_out) do original: quem está fora e de pé primeiro, senão o 1º de pé.
func lead_index() -> int:
	for i in party.size():
		if out.has(party[i]) and not party[i].is_fainted():
			return i
	return first_healthy()


## send_out do original. Devolve "" ou o aviso para o HUD.
func send_out(i: int) -> String:
	if i < 0 or i >= party.size() or is_out(i):
		return ""
	if party[i].is_fainted():
		return "%s fainted!" % party[i].display_name
	out.append(party[i])
	return ""


func recall(i: int) -> void:
	if i >= 0 and i < party.size():
		out.erase(party[i])
		resting.erase(party[i])


## _party_key do original fora da batalha: tecla 1-6 manda ou recolhe aquele Pokémon.
func party_key(i: int) -> String:
	if i < 0 or i >= party.size() or is_busy():
		return ""
	if is_out(i):
		recall(i)
		return ""
	return send_out(i)


## Tira de `out` quem não está mais na equipe (PC, troca) ou desmaiou.
func prune_out() -> void:
	out = out.filter(func(m): return party.has(m) and not m.is_fainted())
	for m in resting.keys():
		if not out.has(m):
			resting.erase(m)


func _can_friend(i: int) -> bool:
	return is_out(i) and not party[i].is_fainted() and not is_busy()


## Carinho (E no companheiro): {ok, text}. +6 de amizade, espera 60 s.
func pet(i: int) -> Dictionary:
	if not _can_friend(i):
		return {"ok": false, "text": ""}
	var m: Mon = party[i]
	if float(_friend_cd.get(m, 0.0)) > 0.0:
		return {"ok": false, "text": "%s is still happy from the last pat." % m.display_name}
	m.set_friend(m.friend + PET_GAIN)
	_friend_cd[m] = PET_CD
	return {"ok": true, "text": ""}


## Comida (F no companheiro): {ok, text}. +8 de amizade, espera 90 s.
func feed(i: int) -> Dictionary:
	if not _can_friend(i):
		return {"ok": false, "text": ""}
	var m: Mon = party[i]
	if float(_friend_cd.get(m, 0.0)) > 0.0:
		return {"ok": false, "text": "%s isn't hungry right now." % m.display_name}
	m.set_friend(m.friend + FEED_GAIN)
	_friend_cd[m] = FEED_CD
	return {"ok": true, "text": ""}


## _friend_tick do original: esperas do carinho/comida e +1 de amizade a cada 10 s fora da bola.
func friend_tick(delta: float) -> void:
	for m in _friend_cd.keys():
		var left := float(_friend_cd[m]) - delta
		if left <= 0.0:
			_friend_cd.erase(m)
		else:
			_friend_cd[m] = left
	_passive_t += delta
	while _passive_t >= PASSIVE_TICK_S:
		_passive_t -= PASSIVE_TICK_S
		for m in party:
			if out.has(m) and m.hp > 0:
				m.set_friend(m.friend + PASSIVE_GAIN)


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
		m.heal_full()  # vai para a caixa curado, como deposit_to_box do original
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
	pending_evolutions = []
	last_save = {}
	player_name = p_name if p_name != "" else "RED"
	rival_name = r_name if r_name != "" else "BLUE"
	player_gender = gender
	play_time = 0.0
	trainer_id = randi_range(10000, 99999)
	repel_steps = 0
	save_enabled = true
	out = []
	resting = {}


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
	var m: Mon = party.pop_at(party_index)
	out.erase(m)  # quem estava fora da bola volta para ela antes de ir para o PC
	m.heal_full()  # game_state.gd:296 do original: a caixa cura
	pc.append(m)
	return true


func withdraw(pc_index: int) -> bool:
	if pc_index < 0 or pc_index >= pc.size() or party.size() >= PARTY_MAX:
		return false
	var m: Mon = pc.pop_at(pc_index)
	m.heal_full()  # game_state.gd:307 do original
	party.append(m)
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
		return "%s wants to learn %s." % [m.display_name, Dex.move(fx.teach).get("name", fx.teach)]
	var wanted: Array = []
	if fx.has("level"):
		for e in Dex.species(m.species).get("learnset", []):
			if int(e[0]) > m.level and int(e[0]) <= m.level + int(fx.level):
				wanted.append(e[1])
	var msg := Items.use(id, m)
	if fx.has("evolve") and msg != "":
		# Pedra: Pokédex e golpes da evolução que não couberam (como resolve_evolution).
		seen[m.species] = true
		caught[m.species] = true
		for e in Dex.species(m.species).get("learnset", []):
			if int(e[0]) == m.level:
				wanted.append(e[1])
		wanted.append_array(Dex.species(m.species).get("evo_moves", []))
	for mv in wanted:
		queue_learn(m, mv)
	# Rare Candy até o nível de evolução: evolui antes da fila de golpes (na batalha, o _finish cuida).
	if fx.has("level") and msg != "" and not is_busy():
		_evolve_pending()
		if not pending_evolutions.is_empty():
			evolution_requested.emit()
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
	return {
		"version": SAVE_VERSION,
		"party": party.map(func(m): return m.to_dict()),
		"pc": pc.map(func(m): return m.to_dict()),
		"bag": bag,
		"money": money,
		"flags": flags,
		"seen": seen.keys(),
		"caught": caught.keys(),
		"player_name": player_name,
		"rival_name": rival_name,
		"player_gender": player_gender,
		"play_time": play_time,
		"trainer_id": trainer_id,
		"repel_steps": repel_steps
	}


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
	repel_steps = maxi(int(d.get("repel_steps", 0)), 0)
	out = []
	resting = {}
	seen = {}
	caught = {}
	pending_learns = []
	pending_evolutions = []
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
	return (
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path)
		)
		== OK
	)


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
	save_enabled = true
	return d


## Autosave do original (SaveGame.autosave: fim de cada porta e de cada cena): grava com
## world.save_extra() só se o jogo começou (save_enabled) e nada está no meio (batalha, cena,
## diálogo, viagem, tela modal). Em teste headless nunca grava no save de verdade.
func autosave(world: Node) -> void:
	if not can_autosave(world):
		return
	if save_game(world.save_extra()):
		saved.emit()


func can_autosave(world: Node) -> bool:
	if not save_enabled or is_busy() or world == null or not is_instance_valid(world):
		return false
	if not world.has_method("save_extra") or not world.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless" and save_path == "user://save.json":
		return false
	if bool(world.get("traveling")):
		return false
	var st := get_node_or_null("/root/Story")
	if st and st.has_method("is_running") and st.is_running():
		return false
	for path in ["/root/LearnMove", "/root/PauseMenu", "/root/PCStorage", "/root/Evolution"]:
		var n := get_node_or_null(path)
		if n and n.has_method("is_open") and n.is_open():
			return false
	var hud := Overworld.hud_of(world) if world is Node3D else null
	if hud and hud.has_method("is_dialog_open") and hud.is_dialog_open():
		return false
	return true


# --- Repel (bag_panel.gd:279 e player.gd:131 do original) ---

## Passos de cada item de campo do tipo Repel quando o items.json não diz.
const REPEL_STEPS := {"repel": 100, "super_repel": 200, "max_repel": 250}


## Usa um item de campo que não mira Pokémon (Repel). Tira da bolsa e devolve a mensagem;
## "" se não é item de campo ou não há na bolsa.
func use_field_item(id: String) -> String:
	var fx: Dictionary = Dex.item(id).get("effect", {})
	if not fx.has("repel") and not REPEL_STEPS.has(id):
		return ""
	if not take_item(id):
		return ""
	repel_steps = int(fx.get("repel", REPEL_STEPS.get(id, 100)))
	return "Repel used! Wild Pokémon won't appear for a while."


func repel_active() -> bool:
	return repel_steps > 0


## O original (player.gd:211) não rola encontro nenhum com Repel ativo, seja qual for o nível.
func repel_blocks(_level: int) -> bool:
	return repel_active()


## Um passo andado. true quando o Repel acabou agora ("O efeito do Repel acabou.").
func repel_step() -> bool:
	if repel_steps <= 0:
		return false
	repel_steps -= 1
	return repel_steps == 0


## Prêmio por vencer um treinador: reward fixo do JSON ou base da classe x nível do último Pokémon.
func trainer_payout(trainer_id: String, last_level: int, trainer_class := "") -> int:
	if trainer_class != "":
		# opts.trainer_class (1ª luta com o rival): base da classe x nível, como o original.
		return int(TRAINER_PAYOUTS.get(trainer_class, 16)) * maxi(last_level, 1)
	var t := Dex.trainer(trainer_id)
	if t.has("reward"):
		return int(t.reward)
	return int(TRAINER_PAYOUTS.get(String(t.get("class", "")), 16)) * maxi(last_level, 1)


func request_battle(enemies: Array, opts: Dictionary, host: Node3D, at: Vector3) -> void:
	if is_busy():
		return
	if not opts.has("out"):
		# A arena escolhe o líder e o aliado pelo que está fora da bola (battle.gd:316-327).
		opts = opts.duplicate()
		opts["out"] = out_indices()
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
	if result.get("out_mons") is Array:
		# Quem lutou e não desmaiou continua fora da bola (end_battle do original: FOLLOW).
		out = result.out_mons.duplicate()
	prune_out()
	if outcome == "caught" and result.get("caught_mon") is Mon:
		add_mon(result.caught_mon)
	elif outcome == "win" and _opts.get("kind") == "trainer":
		var id := String(_opts.get("trainer_id", ""))
		var last: int = _enemies[-1].level if not _enemies.is_empty() else 1
		result.prize = trainer_payout(id, last, String(_opts.get("trainer_class", "")))
		money += result.prize
		if not _opts.get("scripted", false):
			flags["trainer_" + id] = true
	elif outcome == "lose":
		# Batalha de roteiro (opts.scripted): perder não custa dinheiro.
		if not _opts.get("scripted", false):
			money -= money / 2  # like the original (rounds the loss down)
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
