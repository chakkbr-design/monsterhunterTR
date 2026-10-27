extends RefCounted
## Modo de treinamento: a configuração das lutas (dois times, opções) e a montagem dos Mon.
## Formato (salvo em user://training.json, nunca no save do jogo):
##   {sides: [{name, item, think_scale, mons: [Mon.to_dict() + "hp_pct"]}, {...}],
##    speed, seed (-1 = aleatório), turbo (bool), time_limit (s de jogo, 0 = sem limite),
##    battle_size (1 ou 2), p1_control ("ai" = IA dos dois lados; "manual" = o Time A é do teclado,
##    só na luta única: a série roda com IA), scenario ("" = aleatório, padrão; ou campo, lagoa,
##    pedreira, misto, praia, ruinas, montanha, vulcao, caverna, pantano: o relevo da quadra,
##    opts.scenario do BattleTerrain), time_of_day ("dia", padrão; "tarde" = pôr do sol;
##    "noite": a hora no estádio voxel)}
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
## Quadra do treino (Caio, 2026-10-26): 48 x 28, estádio voxel em volta (docs/VOXEL.md). Os Pokémon
## entram a ENTRY_X m do centro; os treinadores ficam nas linhas de fundo.
const ARENA := Vector2(48, 28)
## Quadra pequena de antes (24 x 14), para os testes que lutam sem estádio.
const SMALL_ARENA := Vector2(24, 14)
const ENTRY_X := 6.0
## Cenários do relevo para escolher na tela (os ids são os de BattleTerrain.SCENARIOS).
const SCENARIOS := [
	"campo",
	"lagoa",
	"pedreira",
	"misto",
	"praia",
	"ruinas",
	"montanha",
	"vulcao",
	"caverna",
	"pantano"
]
const SCENARIO_NAMES := {
	"campo": "Field",
	"lagoa": "Pond",
	"pedreira": "Quarry",
	"misto": "Mixed",
	"praia": "Beach",
	"ruinas": "Ruins",
	"montanha": "Snowy Mountain",
	"vulcao": "Volcano",
	"caverna": "Dark Cave",
	"pantano": "Swamp",
}
## Hora do dia no estádio do modo de energia (ArenaStadium.MOODS): de noite os refletores acendem.
const TIMES := ["dia", "tarde", "noite"]
const TIME_NAMES := {"dia": "Day", "tarde": "Sunset", "noite": "Night"}
const SPEEDS := [0.6, 1.0, 2.0, 4.0]
## Turbo: passos da arena por quadro (cada passo no máximo 1x, para não pular colisões).
const TURBO_STEPS := 12
const STATUSES := ["", "burn", "poison", "paralysis", "sleep"]
const STATUS_NAMES := {
	"": "None", "burn": "Burned", "poison": "Poisoned", "paralysis": "Paralyzed", "sleep": "Asleep"
}

## Configuração em uso entre a tela de montar e a da luta (sobrevive à troca de cena).
static var current := {}


static func default_config() -> Dictionary:
	return {
		"sides":
		[
			{
				"name": "Team A",
				"item": "",
				"think_scale": 1.0,
				"mons": [mon_entry("Magnemite", LEVEL), mon_entry("Pidgey", LEVEL)]
			},
			{
				"name": "Team B",
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
		"scenario": "",
		"time_of_day": "dia",
		"p1_control": "ai",
		"random_legends": false,
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


## Nome do time para mostrar ("Team A"/"Team B" quando está em branco).
static func side_name(cfg: Dictionary, side: int) -> String:
	var n := String(cfg.sides[side].get("name", "")).strip_edges()
	return n if n != "" else ("Team A" if side == 0 else "Team B")


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
		"terrain": bool(cfg.get("terrain", true)),
		"mirror_court": true,
		# Quadra grande em voxel (BattleTerrain.lattice): obstáculos na grade de 0,25 m, piso, linhas e
		# cerca voxel; entradas a ENTRY_X m do centro.
		"voxel": true,
		"entry_x": ENTRY_X,
	}
	if scenario(cfg) != "":
		o["scenario"] = scenario(cfg)
	if int(cfg.get("seed", -1)) >= 0:
		o["seed"] = int(cfg.seed)
	# IA do treinador por lado ([lado 0, lado 1]); weather: clima da luta toda (sun, rain, sand,
	# hail), para testes e fotos.
	for k in ["trainer_ai", "weather"]:
		if cfg.has(k):
			o[k] = cfg[k]
	# Bateria de testes (tests/balance/battery.gd): telemetria, damage_pace etc. passam direto.
	if cfg.get("extra_opts") is Dictionary:
		o.merge(cfg.extra_opts, true)
	return o


## Cenário escolhido ("" = aleatório: a arena sorteia pela rng da luta).
static func scenario(cfg: Dictionary) -> String:
	var id := String(cfg.get("scenario", ""))
	return id if SCENARIOS.has(id) else ""


## Hora do dia do estádio (TIMES; "dia" se faltar ou for inválida).
static func time_of_day(cfg: Dictionary) -> String:
	var id := String(cfg.get("time_of_day", "dia"))
	return id if TIMES.has(id) else "dia"


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


# --- Times aleatórios ---


## Times sorteados só com evoluções finais: espécies sem evolução para outra espécie do jogo
## (as que não evoluem também entram; Golbat e Onix contam como finais, Crobat e Steelix não existem).
## legends = false tira lendários, míticos e Ultra Beasts (LEGEND_DEX).
static func random_pool(legends := true) -> Array:
	var out: Array = []
	for sp in Dex.all_species():
		var into := String(Dex.species(sp).get("evolution", {}).get("into", ""))
		if not legends and is_legend(sp):
			continue
		if into == "" or Dex.species(into).is_empty():
			out.append(sp)
	out.sort()  # mesma ordem sempre: a semente refaz os mesmos times
	return out


## Lendários, míticos e Ultra Beasts pelo número da Pokédex (Caio, 2026-10-27: a bateria mostrou
## Lunala, Zacian e Eternatus dominando o sorteio; os times aleatórios os deixam de fora por padrão).
const LEGEND_DEX := [
	[144, 146],
	[150, 151],
	[243, 245],
	[249, 251],
	[377, 386],
	[480, 494],
	[638, 649],
	[716, 721],
	[772, 773],
	[785, 809],
	[888, 898],
	[905, 905],
	[1001, 1004],
	[1007, 1008],
	[1014, 1017],
	[1024, 1025],
]


static func is_legend(sp: String) -> bool:
	var n := int(Dex.species(sp).get("dex_no", 0))
	for r in LEGEND_DEX:
		if n >= int(r[0]) and n <= int(r[1]):
			return true
	return false


## Sorteia os Pokémon dos dois times (o nome, o item e o nível da IA de cada lado ficam).
## cfg.random_legends (padrão falso) deixa lendários no sorteio.
static func randomize_sides(cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	for s in SIDES:
		cfg.sides[s]["mons"] = random_mons(rng, bool(cfg.get("random_legends", false)))


## PARTY_MAX espécies diferentes de random_pool() (evoluções finais), cada uma com habilidade
## (normal ou oculta) e golpes sorteados (random_moves). Equilibrado por tipo: sorteia primeiro um tipo (uniforme
## entre os que têm espécie livre) e depois uma espécie dele; dupla tipagem conta nos dois tipos.
static func random_mons(rng: RandomNumberGenerator, legends := true) -> Array:
	var pool := random_pool(legends)
	var out: Array = []
	for k in mini(PARTY_MAX, pool.size()):
		var sp := pick_by_type(pool, rng)
		pool.erase(sp)
		var d := mon_entry(sp, LEVEL)
		var n: int = Dex.species(sp).get("abilities", []).size()
		d["ability_slot"] = rng.randi() % maxi(n, 1)
		d["moves"] = random_moves(sp, rng)
		out.append(d)
	return out


## Uma espécie de `pool` (ordenado): tipo uniforme entre os presentes (ordem alfabética), depois a
## espécie entre as que têm esse tipo. Determinístico pela rng.
static func pick_by_type(pool: Array, rng: RandomNumberGenerator) -> String:
	var by_type := {}
	for sp in pool:
		for t in Dex.species(String(sp)).get("types", []):
			if not by_type.has(t):
				by_type[t] = []
			by_type[t].append(sp)
	var types: Array = by_type.keys()
	types.sort()
	var list: Array = by_type[types[rng.randi() % types.size()]]
	return String(list[rng.randi() % list.size()])


## Status que valem um espaço no sorteio: causam status de verdade (veneno, paralisia, sono...),
## sobem atributo forte (+2 ou vários de uma vez) ou curam. Leer, Growl e afins ficam de fora.
const RANDOM_STATUS := ["burn", "poison", "toxic", "paralysis", "sleep", "confusion", "freeze"]
const RANDOM_HEAL := [
	"rest",
	"roost",
	"recover",
	"soft_boiled",
	"milk_drink",
	"slack_off",
	"synthesis",
	"moonlight",
	"morning_sun",
	"heal_weather",
	"wish",
	"life_dew",
	"shore_up",
	"strength_sap"
]

## Golpes de dano que só funcionam em condição rara (dormindo, depois de comer, terreno...) ou que
## derrubam o próprio usuário: o sorteio não escolhe.
## Golpes Normais que quase todo Pokémon aprende por TM e rendem pouco sem STAB, status ou Terastal
## (bateria de 2026-10-27): só entram no sorteio de quem é do tipo Normal (ou no completar do fim).
const RANDOM_NORMAL_ONLY := ["facade", "tera_blast", "take_down", "double_edge"]
const RANDOM_SKIP := [
	"snore",
	"dream_eater",
	"belch",
	"last_resort",
	"spit_up",
	"fling",
	"natural_gift",
	"steel_roller",
	"synchronoise",
	"self_destruct",
	"explosion",
	"misty_explosion",
	"final_gambit",
	"focus_punch",
	"endeavor",
	"poltergeist"
]


## Categoria preferida pelo maior ataque: "physical" (Atk), "special" (SpA) ou "" (empate até 10%).
static func preferred_category(sp: String) -> String:
	var b: Dictionary = Dex.species(sp).get("base", {})
	var atk := float(b.get("atk", 0))
	var spa := float(b.get("spa", 0))
	if absf(atk - spa) <= maxf(atk, spa) * 0.1:
		return ""
	return "physical" if atk > spa else "special"


static func _status_worth(mv: Dictionary) -> bool:
	var eff: Dictionary = mv.get("effect", {})
	if RANDOM_STATUS.has(String(eff.get("status", ""))) and float(eff.get("chance", 0)) >= 0.5:
		return true
	if (
		mv.has("heal")
		or RANDOM_HEAL.has(String(mv.get("id", "")))
		or RANDOM_HEAL.has(String(mv.get("special", "")))
	):
		return true
	if String(mv.get("kind", "")) == "self_buff":
		return int(mv.get("stages", 0)) >= 2 or Dictionary(mv.get("stats", {})).size() >= 2
	return false


## Golpe de dano com efeito secundário que pesa (status com chance >= 10%, ou trava/dreno).
static func _secondary_worth(mv: Dictionary) -> bool:
	var eff: Dictionary = mv.get("effect", {})
	if RANDOM_STATUS.has(String(eff.get("status", ""))) and float(eff.get("chance", 0)) >= 0.1:
		return true
	return mv.has("drain") or mv.has("trap")


## Peso de um golpe de dano: o poder oficial (OHKO e dano fixo contam como 70).
static func _power_weight(mv: Dictionary) -> float:
	var bp := float(mv.get("bp", mv.get("power", 0)))
	if bp <= 1.0:
		bp = 70.0
	return bp


static func _weighted(ids: Array, weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	for i in ids.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return ids.size() - 1


## 4 golpes do learnset, coerentes com a espécie:
## 1. um golpe de dano de cada tipo da espécie (STAB), da categoria do maior ataque quando houver
##    (Atk alto prefere físico, SpA alto prefere especial), sorteado pelo poder (o mais forte sai mais);
## 2. o resto sorteado do learnset, ainda preferindo dano da categoria certa (tipos novos pesam mais);
##    golpe da outra categoria só se tiver efeito secundário que pesa (queimar, paralisar...), e no
##    máximo um golpe de status, só os que valem (status de verdade, +2, vários atributos ou cura).
static func random_moves(sp: String, rng: RandomNumberGenerator) -> Array:
	var cat := preferred_category(sp)
	var sp_types: Array = Dex.species(sp).get("types", [])
	var dmg: Array = []
	var status: Array = []
	for e in learnable_moves(sp):
		var mv := Dex.move(String(e.id))
		var c := String(mv.get("category", "status"))
		if c == "status":
			if _status_worth(mv):
				status.append(String(e.id))
		elif (
			float(mv.get("power", 0)) > 0
			and not RANDOM_SKIP.has(String(e.id))
			and not (RANDOM_NORMAL_ONLY.has(String(e.id)) and not "normal" in sp_types)
		):
			dmg.append(String(e.id))
	var good := func(id: String) -> bool: return cat == "" or Dex.move(id).get("category") == cat
	var picks: Array = []
	var covered: Array = []
	for t in Dex.species(sp).get("types", []):
		var stab := dmg.filter(func(id): return Dex.move(id).get("type") == t and not picks.has(id))
		var best := stab.filter(good)
		var list: Array = best if not best.is_empty() else stab
		if list.is_empty():
			continue
		var w := list.map(func(id): return pow(_power_weight(Dex.move(id)), 2.0))
		var i := _weighted(list, w, rng)
		picks.append(list[i])
		covered.append(t)
	var n_status := 0
	while picks.size() < Mon.MAX_MOVES:
		var ids: Array = []
		var w: Array = []
		for id in dmg:
			if picks.has(id):
				continue
			var mv := Dex.move(id)
			var weight := 0.0
			if good.call(id):
				weight = _power_weight(mv) / 10.0
				if not covered.has(mv.get("type")):
					weight *= 2.0
				if _secondary_worth(mv):
					weight *= 1.3
			elif _secondary_worth(mv):
				weight = 3.0
			if weight > 0.0:
				ids.append(id)
				w.append(weight)
		if n_status == 0:
			# Os golpes de status juntos valem ~1/4 do sorteio de cada espaço livre.
			var free := status.filter(func(id): return not picks.has(id))
			var total := 0.0
			for x in w:
				total += float(x)
			for id in free:
				ids.append(id)
				w.append(maxf(2.0, total / 3.0 / free.size()))
		var i := _weighted(ids, w, rng)
		if i < 0:
			break
		var pick: String = ids[i]
		picks.append(pick)
		var mv := Dex.move(pick)
		if String(mv.get("category")) == "status":
			n_status += 1
		elif not covered.has(mv.get("type")):
			covered.append(mv.get("type"))
	# Learnset curto demais para as regras acima: completa com qualquer golpe que a espécie aprende.
	var rest := (dmg + status).filter(func(id): return not picks.has(id))
	if picks.size() < Mon.MAX_MOVES:
		for e in learnable_moves(sp):
			if not picks.has(String(e.id)) and not rest.has(String(e.id)):
				rest.append(String(e.id))
	while picks.size() < Mon.MAX_MOVES and not rest.is_empty():
		picks.append(rest.pop_at(rng.randi() % rest.size()))
	return picks
