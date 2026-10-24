extends RefCounted
## Modo de treinamento: a configuração das lutas (dois times, opções) e a montagem dos Mon.
## Formato (salvo em user://training.json, nunca no save do jogo):
##   {sides: [{name, item, think_scale, mons: [Mon.to_dict() + "hp_pct"]}, {...}],
##    speed, seed (-1 = aleatório), turbo (bool), time_limit (s de jogo, 0 = sem limite)}
## Uso: const Cfg := preload("res://ui/training/training_config.gd")

const PATH := "user://training.json"
## Arquivo em uso (os testes trocam para não mexer no do jogador).
static var path := PATH
const SIDES := 2
const PARTY_MAX := 6
## Quadra fixa do treino: o dobro da quadra padrão da arena (FIXED_ARENA 10 x 6).
const ARENA := Vector2(20, 12)
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
				"mons": [mon_entry("Bulbasaur", 15), mon_entry("Geodude", 15)]
			},
			{
				"name": "Time B",
				"item": "",
				"think_scale": 1.0,
				"mons": [mon_entry("Charmander", 15), mon_entry("Pikachu", 15)]
			},
		],
		"speed": 1.0,
		"seed": -1,
		"turbo": false,
		"time_limit": 0,
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
static func build_mon(d: Dictionary) -> Mon:
	var m := Mon.from_dict(d.duplicate(true))
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


## opts da arena para uma luta automática dos dois lados (contrato em battle/battle_arena.gd).
static func arena_opts(cfg: Dictionary, center: Vector3) -> Dictionary:
	var o := {
		"kind": "trainer",
		"autoplay": true,
		"auto_battle": true,
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
	}
	if int(cfg.get("seed", -1)) >= 0:
		o["seed"] = int(cfg.seed)
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
