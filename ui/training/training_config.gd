extends RefCounted
## Modo de treinamento: a configuração das lutas (dois times, opções) e a montagem dos Mon.
## Formato (salvo em user://training.json, nunca no save do jogo):
##   {sides: [{name, item, think_scale, mons: [Mon.to_dict() + "hp_pct"]}, {...}],
##    speed, seed (-1 = aleatório), turbo (bool), time_limit (s de jogo, 0 = sem limite),
##    battle_size (1 ou 2), p1_control ("ai" = IA dos dois lados; "manual" = o Time A é do teclado,
##    só na luta única: a série roda com IA)}
## Times salvos (user://training_teams.json): {slots: [lado ou {}, ...]}, TEAM_SLOTS posições;
## cada lado salvo é {name, item, think_scale, mons} + "saved_at" (data e hora em texto).
## Sem IVs e EVs no treino: todo Pokémon luta com IV 31 e EV 0 (só base, natureza e habilidade).
## Todos lutam no Nv 50 (LEVEL), mesmo entrada salva em outro nível; qualquer golpe da espécie vale.
## Uso: const Cfg := preload("res://ui/training/training_config.gd")

const PATH := "user://training.json"
const TEAMS_PATH := "user://training_teams.json"
const TEAM_SLOTS := 10
## Arquivos em uso (os testes trocam para não mexer nos do jogador).
static var path := PATH
static var teams_path := TEAMS_PATH
const SIDES := 2
const PARTY_MAX := 6
## Nível de todo Pokémon do treino (build_mon força este nível).
const LEVEL := 50
## Quadra fixa do treino: 16 x 10 (a quadra padrão da arena é 10 x 6).
const ARENA := Vector2(16, 10)
const SPEEDS := [0.6, 1.0, 2.0, 4.0]
## Turbo: passos da arena por quadro (cada passo no máximo 1x, para não pular colisões).
const TURBO_STEPS := 12
const STATUSES := ["", "burn", "poison", "paralysis", "sleep"]
const STATUS_NAMES := {
	"": "Nenhum",
	"burn": "Queimado",
	"poison": "Envenenado",
	"paralysis": "Paralisado",
	"sleep": "Dormindo"
}

## Configuração em uso entre a tela de montar e a da luta (sobrevive à troca de cena).
static var current := {}


static func default_config() -> Dictionary:
	return {
		"sides":
		[
			{
				"name": "Time A",
				"item": "",
				"think_scale": 1.0,
				"mons": [mon_entry("Magnemite", LEVEL), mon_entry("Pidgey", LEVEL)]
			},
			{
				"name": "Time B",
				"item": "",
				"think_scale": 1.0,
				"mons": [mon_entry("Bulbasaur", LEVEL), mon_entry("Charmander", LEVEL)]
			},
		],
		"speed": 1.0,
		"seed": -1,
		"turbo": false,
		"time_limit": 0,
		"battle_size": 2,
		"p1_control": "ai",
	}


## Entrada nova de um Pokémon: IVs 31, EVs 0, natureza neutra, golpes do nível, HP cheio.
static func mon_entry(species: String, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var m := Mon.create(species, level, rng)
	m.nature = "hardy"
	for s in StatCalc.STATS:
		m.ivs[s] = StatCalc.IV_MAX
	m.recalc()
	m.heal_full()
	var d := m.to_dict()
	d["hp_pct"] = 100
	return d


## Mon pronto para a luta a partir de uma entrada (HP pelo hp_pct, sem evoluir no meio da luta).
## Nível sempre LEVEL, e IVs e EVs sempre 31 e 0, mesmo numa config antiga com outros valores.
static func build_mon(d: Dictionary) -> Mon:
	var e := d.duplicate(true)
	e["level"] = LEVEL
	var m := Mon.from_dict(e)
	m.ivs = {}
	for s in StatCalc.STATS:
		m.ivs[s] = StatCalc.IV_MAX
	m.evs = StatCalc.zero_evs()
	m.moves = m.moves.filter(func(id): return not Dex.move(String(id)).is_empty())
	if m.moves.is_empty():
		m.moves = Dex.moves_at(m.species, m.level)
	m.xp = Growth.exp_for_level(m.growth, m.level)
	m.recalc()
	m.hp = clampi(
		ceili(m.max_hp * clampf(float(d.get("hp_pct", 100)), 0.0, 100.0) / 100.0), 1, m.max_hp
	)
	m.pp = clampf(float(d.get("pp", m.pp_base)), 0.0, m.pp_base)
	m.status = String(d.get("status", ""))
	m.cancel_evolution()
	return m


static func build_side(cfg: Dictionary, side: int) -> Array:
	var out: Array = []
	for d in cfg.sides[side].mons:
		if Dex.species(String(d.get("species", ""))).is_empty():
			continue
		out.append(build_mon(d))
	return out


## Pronta para lutar: os dois times com pelo menos um Pokémon válido.
static func can_start(cfg: Dictionary) -> bool:
	return not build_side(cfg, 0).is_empty() and not build_side(cfg, 1).is_empty()


## Nome do time para mostrar ("Time A"/"Time B" quando está em branco).
static func side_name(cfg: Dictionary, side: int) -> String:
	var n := String(cfg.sides[side].get("name", "")).strip_edges()
	return n if n != "" else ("Time A" if side == 0 else "Time B")


## opts da arena (contrato em battle/battle_arena.gd). Com p1_control "manual" o Time A é do
## teclado (keyboard) e a arena não anda sozinha; com "ai", as duas IAs lutam sozinhas.
static func arena_opts(cfg: Dictionary, center: Vector3) -> Dictionary:
	var manual := String(cfg.get("p1_control", "ai")) == "manual"
	var o := {
		"kind": "trainer",
		"autoplay": not manual,
		"auto_battle": not manual,
		"keyboard": manual,
		"can_run": false,
		"floor": false,
		"center": center,
		"arena": ARENA,
		"speed": float(cfg.get("speed", 1.0)),
		"trainer_name": side_name(cfg, 1),
		"trainer_item": String(cfg.sides[1].get("item", "")),
		"player_item": String(cfg.sides[0].get("item", "")),
		"player_think_scale": float(cfg.sides[0].get("think_scale", 1.0)),
		"enemy_think_scale": float(cfg.sides[1].get("think_scale", 1.0)),
		"no_rewards": true,
		"battle_size": clampi(int(cfg.get("battle_size", 2)), 1, 2),
	}
	if int(cfg.get("seed", -1)) >= 0:
		o["seed"] = int(cfg.seed)
	# Comparar IAs (tests/balance/ia_duel.gd): IA VGC e IA do treinador por lado ([lado 0, lado 1]).
	for k in ["vgc_ai", "trainer_ai"]:
		if cfg.has(k):
			o[k] = cfg[k]
	return o


static func load_config() -> Dictionary:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary and d.get("sides") is Array and d.sides.size() == SIDES:
			return d
	return default_config()


static func save_config(cfg: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg, "\t"))


## Golpes que a espécie aprende: [{id, level}], level 0 = a qualquer nível (evolução, TM, ovo,
## tutor, kit padrão). Lê do species.json: learnset [[nível, id]], evo_moves, tm, egg, tutor, moves.
## Só golpes que existem no moves.json; ordem: por nível, depois pelo nome.
static func learnable_moves(sp: String) -> Array:
	var d := Dex.species(sp)
	var lv := {}
	for key in ["evo_moves", "tm", "egg", "tutor", "moves"]:
		for id in d.get(key, []):
			lv[String(id)] = 0
	for e in d.get("learnset", []):
		var id := String(e[1])
		if not lv.has(id) or int(e[0]) < int(lv[id]):
			lv[id] = int(e[0])
	var out: Array = []
	for id in lv:
		if not Dex.move(id).is_empty():
			out.append({"id": id, "level": lv[id]})
	out.sort_custom(func(a, b): return [a.level, String(a.id)] < [b.level, String(b.id)])
	return out


## Nível em que a espécie aprende o golpe (0 = qualquer nível; -1 = não aprende).
static func learn_level(sp: String, id: String) -> int:
	for e in learnable_moves(sp):
		if e.id == id:
			return int(e.level)
	return -1


static func load_teams() -> Array:
	var out: Array = []
	var d = null
	if FileAccess.file_exists(teams_path):
		var f := FileAccess.open(teams_path, FileAccess.READ)
		d = JSON.parse_string(f.get_as_text()) if f else null
	var got: Array = d.get("slots", []) if d is Dictionary and d.get("slots") is Array else []
	for k in TEAM_SLOTS:
		var e = got[k] if k < got.size() else {}
		out.append(e if e is Dictionary and e.get("mons") is Array else {})
	return out


## Grava o lado `team` (cópia) no slot k; {} apaga o slot.
static func save_team(k: int, team: Dictionary) -> void:
	if k < 0 or k >= TEAM_SLOTS:
		return
	var all := load_teams()
	var t := team.duplicate(true)
	if not t.is_empty():
		t["saved_at"] = Time.get_datetime_string_from_system(false, true)
	all[k] = t
	var f := FileAccess.open(teams_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"slots": all}, "	"))


## Itens que a IA usa como item do treinador (BattleAI.want_trainer_item: cura de HP ou de status).
## Cada Pokémon do time usa o item uma vez.
static func battle_items() -> Array:
	var out: Array = []
	var it = Dex._load_json("res://data/items.json")
	for e in it.get("items", []) if it is Dictionary else []:
		var eff = e.get("effect", {})
		if eff is Dictionary and (eff.has("hp") or _cures_status(String(eff.get("cure", "")))):
			out.append(String(e.id))
	return out


## Cura que o item do treinador consegue usar (status de luta; confusão não conta).
static func _cures_status(cure: String) -> bool:
	return cure == "all" or (cure != "" and STATUSES.has(cure))


## Liga/desliga o menu de pausa do mundo (Esc) enquanto o modo de treinamento está aberto.
static func block_pause_menu(tree: SceneTree, on: bool) -> void:
	var pm := tree.root.get_node_or_null("PauseMenu") if tree else null
	if pm:
		pm.set_process_unhandled_input(not on)
		pm.set_process_input(not on)
