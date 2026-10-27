class_name BattleAbilities
extends RefCounted
## Efeitos das habilidades (data/abilities.json) na luta em tempo real, com a faixa de habilidade no HUD.
## A arena cria um por luta (arena.abilities) e chama os ganchos abaixo.
## Regras oficiais (Gen 9) adaptadas à rodada (BattleTurns): o "fim de turno" do oficial roda em
## BattleEndTurn.run(), que chama os passos daqui na ordem oficial (count_weather_round +
## weather_residual, shed_skin, Poison Heal no passo do veneno, late_residual); on_round_end() faz só
## a parte das habilidades. "Ao entrar" dispara na troca e na substituição, em ordem pela Speed (do mais
## rápido ao mais lento; Trick Room inverte).
## Extras que a arena/moves/IA/turnos podem consultar: walk_mult(f), cast_speed_mult(f, mv),
## order_speed_mult(f), priority_bonus(f, mv), redirect(user, target, mv), profile_bias(f),
## blocks_stage_drop(f, stat).
## Clima: `weather_now()` ("" | sun | rain | sand | hail) vem de set_weather_rounds() (golpe e
## habilidade, 5 rodadas como os 5 turnos do oficial, contadas no fim de turno), de set_weather() (em
## segundos, para testes e efeitos de tempo real) ou de arena.opts.weather (a arena toda, sem fim). Cloud Nine/Air Lock o suprimem. "hail" é a neve da Gen 9
## (sem dano).

const PINCH := {"blaze": "fire", "torrent": "water", "overgrow": "grass", "swarm": "bug"}
const PINCH_MULT := 1.5
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "lunge"]
const CONTACT_CHANCE := 0.3
## Efeito por contato: habilidade -> status possíveis em quem encosta.
const CONTACT_STATUS := {
	"static": ["paralysis"],
	"poison_point": ["poison"],
	"flame_body": ["burn"],
	"effect_spore": ["poison", "paralysis", "sleep"],
}
## Golpes de som oficiais (Soundproof).
const SOUND_MOVES := [
	"growl",
	"sing",
	"supersonic",
	"screech",
	"metal_sound",
	"bug_buzz",
	"hyper_voice",
	"disarming_voice",
	"echoed_voice",
	"round",
	"roar",
	"snore",
	"uproar",
	"perish_song",
	"grass_whistle",
	"heal_bell",
	"boomburst",
	"noble_roar",
	"parting_shot",
	"relic_song",
	"sparkling_aria",
	"overdrive",
	"torch_song",
	"alluring_voice",
	"psychic_noise",
	"chatter",
	"clanging_scales",
	"clangorous_soul",
	"confide",
	"howl",
	"snarl",
]
## Golpes de soco oficiais (Iron Fist).
const PUNCH_MOVES := [
	"thunder_punch",
	"fire_punch",
	"ice_punch",
	"mega_punch",
	"comet_punch",
	"dizzy_punch",
	"dynamic_punch",
	"mach_punch",
	"bullet_punch",
	"drain_punch",
	"focus_punch",
	"power_up_punch",
	"shadow_punch",
	"hammer_arm",
	"sky_uppercut",
	"meteor_mash",
	"ice_hammer",
	"jet_punch",
	"rage_fist",
	"double_iron_bash",
	"plasma_fists",
	"headlong_rush",
	"wicked_blow",
	"surging_strikes",
]
## Mordidas oficiais (Strong Jaw).
const BITE_MOVES := [
	"bite",
	"crunch",
	"fire_fang",
	"ice_fang",
	"thunder_fang",
	"poison_fang",
	"hyper_fang",
	"psychic_fangs",
	"jaw_lock",
	"fishious_rend",
]
## Reckless: golpes com recuo ("recoil" nos dados) e os de queda (erro machuca).
const RECKLESS_MOVES := ["jump_kick", "high_jump_kick", "axe_kick", "supercell_slam", "head_smash"]
## Golpes que explodem (Damp impede).
const EXPLODE_MOVES := ["self_destruct", "explosion", "misty_explosion", "mind_blown"]
## Habilidades que seguram a intimidação (Gen 8+) e as que não deixam o Ataque cair.
## Defiant/Competitive não seguram: tomam o -1 e reagem com +2.
const INTIMIDATE_PROOF := [
	"inner_focus", "oblivious", "own_tempo", "scrappy", "clear_body", "hyper_cutter"
]
## Status bloqueado por habilidade.
const BLOCKS := {
	"inner_focus": ["flinch"],
	"own_tempo": ["confusion"],
	"vital_spirit": ["sleep"],
	"insomnia": ["sleep"],
	"water_veil": ["burn"],
	"limber": ["paralysis"],
	"immunity": ["poison"],
	"magma_armor": ["freeze"],
	"water_bubble": ["burn"],
	"thermal_exchange": ["burn"],
	"sweet_veil": ["sleep"],
}
## Queda de atributo anulada: habilidade -> chaves (vazio = todas).
const KEEP_STAT := {
	"clear_body": [],
	"hyper_cutter": ["atk"],
	"keen_eye": ["acc"],
	"illuminate": ["acc"],
	"big_pecks": ["def"],
	"white_smoke": [],
	"full_metal_body": [],
}
const STAGE_KEYS := ["atk", "def", "spa", "spd", "spe", "acc"]
## Habilidades que agem ao entrar (troca, substituição, começo da luta), em ordem pela Speed.
const ENTRY := [
	"intimidate",
	"drought",
	"drizzle",
	"sand_stream",
	"snow_warning",
	"frisk",
	"unnerve",
	"cloud_nine",
	"air_lock",
	"download",
	"anticipation",
	"forewarn",
	"pressure",
	"trace",
	"neutralizing_gas",
	"imposter",
	"grassy_surge",
	"electric_surge",
	"misty_surge",
	"psychic_surge",
	"orichalcum_pulse",
	"hadron_engine",
	"intrepid_sword",
	"dauntless_shield",
	"supersweet_syrup",
	"hospitality",
	"costar",
	"screen_cleaner",
	"slow_start",
	"illusion",
	"zero_to_hero",
	"tera_shift",
	"multitype",
	"rks_system",
]
## Habilidades que o Trace não copia.
const UNTRACEABLE := [
	"trace",
	"neutralizing_gas",
	"imposter",
	"illusion",
	"wonder_guard",
	"multitype",
	"rks_system",
	"stance_change",
	"schooling",
	"shields_down",
	"disguise",
	"gulp_missile",
	"ice_face",
	"zen_mode",
	"forecast",
	"flower_gift",
	"hunger_switch",
	"commander",
	"zero_to_hero",
	"tera_shift",
	"protosynthesis",
	"quark_drive",
	"receiver",
]
## Quem passa por cima das habilidades defensivas do alvo.
const BREAKERS := ["mold_breaker", "turboblaze", "teravolt"]
## Habilidades de gatilho que o Mold Breaker NÃO ignora (agem no portador, não protegem de um golpe).
const UNBREAKABLE := [
	"static",
	"poison_point",
	"flame_body",
	"effect_spore",
	"cute_charm",
	"rough_skin",
	"aftermath",
	"justified",
	"steadfast",
	"stench",
	"synchronize",
	"weak_armor",
	"rattled",
	"anger_point",
	"cursed_body",
	"liquid_ooze",
	"poison_touch",
	"pressure",
	"moxie",
	"defiant",
	"competitive",
	"neutralizing_gas",
	"mold_breaker",
	"turboblaze",
	"teravolt",
	"scrappy",
	"analytic",
	"prism_armor",
	"shadow_shield",
	"full_metal_body",
	"pickpocket",
	"magician",
	"stamina",
	"gooey",
	"mummy",
	"lingering_aroma",
	"wandering_spirit",
	"iron_barbs",
	"perish_body",
	"toxic_debris",
	"seed_sower",
	"sand_spit",
	"cotton_down",
	"berserk",
	"anger_shell",
	"wimp_out",
	"emergency_exit",
	"color_change",
	"innards_out",
	"gulp_missile",
	"electromorphosis",
	"wind_power",
	"water_compaction",
	"steam_engine",
]
## Habilidades que ignoram a imunidade de Fantasma (Scrappy): tipos de golpe que passam a acertar.
const SCRAPPY_TYPES := ["normal", "fighting"]
## Status que o Synchronize devolve.
const SYNC_STATUS := ["poison", "toxic", "burn", "paralysis"]
## Analytic: x1,3 em quem usou um golpe há menos de ANALYTIC_WINDOW s.
const ANALYTIC_MULT := 1.3
const ANALYTIC_WINDOW := 3.0
## Esquiva extra de Anticipation (golpe superefetivo) e Forewarn (o golpe revelado).
const ANTICIPATION_DODGE := 0.25
const FOREWARN_DODGE := 0.3
## Cursed Body: chance e segundos que o golpe que o acertou fica travado.
const CURSED_CHANCE := 0.3
const CURSED_LOCK := 6.0
## Weak Armor: no máximo um gatilho por ARMOR_GAP s (golpe de vários acertos não empilha tudo).
const ARMOR_GAP := 1.0
## Harvest: chance por rodada de a frutinha voltar (sempre no sol).
const HARVEST_CHANCE := 0.5
## Healer: chance por rodada de curar o aliado; sozinho em campo cura a si mesmo com HEALER_SELF.
const HEALER_CHANCE := 0.3
const HEALER_SELF := 0.1
## Poison Touch: chance de envenenar no golpe de contato.
const POISON_TOUCH_CHANCE := 0.3
## Pressure: inimigos a menos de PRESSURE_RANGE m gastam PRESSURE_COST x mais energia por golpe.
const PRESSURE_RANGE := 6.0
const PRESSURE_COST := 1.25
## Gluttony: a frutinha de HP é comida com esta fração a mais do HP máx. e cura GLUTTONY_HEAL x.
const GLUTTONY_BONUS := 0.25
const GLUTTONY_HEAL := 1.5
## Frutinhas que o Harvest planta de novo.
const BERRIES := ["oran_berry", "sitrus_berry", "pecha_berry", "persim_berry"]
## Habilidades que criam clima ao entrar (5 rodadas, 8 com a pedra do clima segurada).
const WEATHER_SETTERS := {
	"drought": "sun", "drizzle": "rain", "sand_stream": "sand", "snow_warning": "hail"
}
## Pedras que alongam o clima de quem segura (Heat/Damp/Smooth/Icy Rock): 8 turnos no oficial.
const WEATHER_ROCKS := {
	"sun": "heat_rock", "rain": "damp_rock", "sand": "smooth_rock", "hail": "icy_rock"
}
const ROCK_ROUNDS := 8
## Clima: duração padrão de set_weather (s, tempo real) e rodadas do clima de golpe/habilidade (5 turnos).
const WEATHER_SECS := 25.0
const WEATHER_ROUNDS := 5
const WEATHER_ALIAS := {
	"sunny": "sun",
	"sunny_day": "sun",
	"harsh_sunlight": "sun",
	"rainy": "rain",
	"rain_dance": "rain",
	"sandstorm": "sand",
	"hail": "hail",
	"snow": "hail",
	"snowstorm": "hail",
}
const SANDPROOF_TYPES := ["rock", "ground", "steel"]
const SANDPROOF := ["sand_rush", "sand_force", "sand_veil", "magic_guard", "overcoat"]
## Defesa x1,5 no clima (Gen 9): Pedra na areia (Def. Esp.), Gelo na neve (Def).
const WEATHER_DEF_MULT := 1.5
## Speed na ordem da rodada (oficial) e no andar/preparo (tempo real) dos que dobram a Speed.
const SPEED_DOUBLE := 2.0
const SPEED_WALK := 1.5
## No Guard: os golpes dele não erram (multiplicador de precisão que passa de 100%).
const NO_GUARD_ACC := 100.0
const BANNER_GAP := 3.0
const POPUP_GAP := 1.0
const COL_DEFAULT := Color(1.0, 0.85, 0.4)
const WEATHER_COLORS := {
	"sun": Color(1.0, 0.75, 0.3),
	"rain": Color(0.45, 0.65, 1.0),
	"sand": Color(0.85, 0.72, 0.42),
	"hail": Color(0.8, 0.93, 1.0),
}

## Perfis de movimento sugeridos (brawler, shooter, skirmisher, wall, trickster, flyer).
const PROFILES := {
	"levitate": "flyer",
	"gale_wings": "flyer",
	"big_pecks": "flyer",
	"sturdy": "wall",
	"shell_armor": "wall",
	"battle_armor": "wall",
	"multiscale": "wall",
	"thick_fat": "wall",
	"filter": "wall",
	"marvel_scale": "wall",
	"regenerator": "wall",
	"rough_skin": "wall",
	"speed_boost": "skirmisher",
	"quick_feet": "skirmisher",
	"swift_swim": "skirmisher",
	"chlorophyll": "skirmisher",
	"sand_rush": "skirmisher",
	"slush_rush": "skirmisher",
	"run_away": "skirmisher",
	"unburden": "skirmisher",
	"motor_drive": "skirmisher",
	"prankster": "trickster",
	"serene_grace": "trickster",
	"effect_spore": "trickster",
	"cute_charm": "trickster",
	"stench": "trickster",
	"shield_dust": "trickster",
	"iron_fist": "brawler",
	"guts": "brawler",
	"moxie": "brawler",
	"tough_claws": "brawler",
	"strong_jaw": "brawler",
	"huge_power": "brawler",
	"reckless": "brawler",
	"defiant": "brawler",
	"sheer_force": "brawler",
	"intimidate": "brawler",
	"sniper": "shooter",
	"compound_eyes": "shooter",
	"no_guard": "shooter",
	"technician": "shooter",
	"lightning_rod": "shooter",
	"storm_drain": "shooter",
	"competitive": "shooter",
	"plus": "shooter",
	"minus": "shooter",
	"skill_link": "shooter",
	# Kanto: pune a recuperação do alvo / entra e sai
	"analytic": "skirmisher",
	"anticipation": "skirmisher",
	"rattled": "skirmisher",
	"early_bird": "skirmisher",
	# Download/Trace/Forewarn/Neutralizing Gas/Synchronize: leitura e truque à distância
	"download": "shooter",
	"forewarn": "trickster",
	"trace": "trickster",
	"neutralizing_gas": "trickster",
	"synchronize": "trickster",
	# Pressure e quem quer o corpo a corpo
	"pressure": "brawler",
	"anger_point": "brawler",
	"mold_breaker": "brawler",
	"scrappy": "brawler",
	"poison_touch": "brawler",
	# Aguenta e devolve / se recupera em campo
	"cursed_body": "wall",
	"weak_armor": "wall",
	"liquid_ooze": "wall",
	"overcoat": "wall",
	"gluttony": "wall",
	"harvest": "wall",
	"healer": "wall",
	# Gen 3-9 que faltavam
	"pickpocket": "trickster",
	"magician": "trickster",
	"klutz": "brawler",
	"beast_boost": "brawler",
	"contrary": "trickster",
	"bulletproof": "wall",
	"protosynthesis": "brawler",
	"quark_drive": "brawler",
	"sweet_veil": "wall",
	"moody": "trickster",
	"heavy_metal": "wall",
	"light_metal": "skirmisher",
	"stakeout": "brawler",
	"protean": "trickster",
	"libero": "trickster",
	"magic_bounce": "trickster",
	"cheek_pouch": "wall",
	"aroma_veil": "wall",
	"fluffy": "wall",
	"shadow_tag": "trickster",
	"suction_cups": "wall",
	"simple": "trickster",
	"heatproof": "wall",
	"gooey": "wall",
	"solid_rock": "wall",
	"white_smoke": "wall",
	"flower_veil": "wall",
	"symbiosis": "wall",
	"corrosion": "shooter",
	"grassy_surge": "shooter",
	"electric_surge": "shooter",
	"misty_surge": "shooter",
	"psychic_surge": "shooter",
	"magma_armor": "wall",
	"wind_rider": "flyer",
	"truant": "wall",
	"sharpness": "brawler",
	"iron_barbs": "wall",
	"long_reach": "shooter",
	"liquid_voice": "shooter",
	"stamina": "wall",
	"steam_engine": "skirmisher",
	"ripen": "wall",
	"purifying_salt": "wall",
	"thermal_exchange": "wall",
	"toxic_chain": "shooter",
	"normalize": "brawler",
	"pure_power": "brawler",
	"flare_boost": "shooter",
	"slow_start": "wall",
	"mummy": "wall",
	"defeatist": "wall",
	"illusion": "trickster",
	"grass_pelt": "wall",
	"mega_launcher": "shooter",
	"refrigerate": "shooter",
	"pixilate": "shooter",
	"merciless": "brawler",
	"water_bubble": "wall",
	"water_compaction": "wall",
	"cotton_down": "wall",
	"sand_spit": "wall",
	"propeller_tail": "flyer",
	"ice_scales": "wall",
	"stalwart": "wall",
	"wind_power": "flyer",
	"guard_dog": "brawler",
	"mycelium_might": "trickster",
	"toxic_debris": "wall",
	"supersweet_syrup": "trickster",
	"hospitality": "wall",
	"wonder_guard": "wall",
	"stall": "wall",
	"toxic_boost": "brawler",
	"forecast": "trickster",
	"color_change": "trickster",
	"air_lock": "flyer",
	"flower_gift": "wall",
	"bad_dreams": "trickster",
	"multitype": "shooter",
	"victory_star": "shooter",
	"zen_mode": "brawler",
	"turboblaze": "brawler",
	"teravolt": "brawler",
	"fur_coat": "wall",
	"stance_change": "brawler",
	"fairy_aura": "shooter",
	"dark_aura": "shooter",
	"aura_break": "wall",
	"battery": "shooter",
	"dancer": "trickster",
	"schooling": "brawler",
	"queenly_majesty": "wall",
	"dazzling": "wall",
	"triage": "wall",
	"receiver": "wall",
	"wimp_out": "skirmisher",
	"emergency_exit": "skirmisher",
	"innards_out": "wall",
	"rks_system": "brawler",
	"shields_down": "wall",
	"comatose": "wall",
	"disguise": "trickster",
	"berserk": "shooter",
	"steelworker": "brawler",
	"full_metal_body": "wall",
	"shadow_shield": "wall",
	"prism_armor": "wall",
	"soul_heart": "shooter",
	"mirror_armor": "wall",
	"ball_fetch": "skirmisher",
	"gulp_missile": "flyer",
	"punk_rock": "shooter",
	"steely_spirit": "brawler",
	"perish_body": "wall",
	"screen_cleaner": "wall",
	"wandering_spirit": "trickster",
	"power_spot": "wall",
	"ice_face": "wall",
	"hunger_switch": "skirmisher",
	"intrepid_sword": "brawler",
	"dauntless_shield": "wall",
	"unseen_fist": "brawler",
	"transistor": "shooter",
	"dragons_maw": "shooter",
	"chilling_neigh": "brawler",
	"grim_neigh": "shooter",
	"lingering_aroma": "wall",
	"well_baked_body": "wall",
	"seed_sower": "wall",
	"electromorphosis": "shooter",
	"anger_shell": "brawler",
	"opportunist": "skirmisher",
	"rocky_payload": "brawler",
	"zero_to_hero": "brawler",
	"earth_eater": "wall",
	"costar": "wall",
	"commander": "wall",
	"cud_chew": "wall",
	"armor_tail": "wall",
	"supreme_overlord": "brawler",
	"good_as_gold": "wall",
	"tablets_of_ruin": "brawler",
	"sword_of_ruin": "brawler",
	"vessel_of_ruin": "shooter",
	"beads_of_ruin": "shooter",
	"orichalcum_pulse": "brawler",
	"hadron_engine": "shooter",
	"tera_shift": "brawler",
	"poison_puppeteer": "trickster",
	"honey_gather": "skirmisher",
}

var arena: Node
## Faixas realmente mostradas (depois do limite de 3 s) e a última, para testes.
var banners_shown := 0
var last_banner := ""
## Fins de rodada já passados (on_round_end).
var rounds := 0
## Ordem da última ativação "ao entrar" e do último fim de rodada (para testes).
var last_entry_order: Array = []
var last_round_order: Array = []

var _now := 0.0
var _st := {}  ## id do lutador -> estado (marcas)
var _pending_enter: Array = []  ## Intimidate, Drought, Frisk...: precisam de campo/inimigo prontos
var _field := {}  ## id -> lutador ativo no frame anterior (para ver quem saiu na troca)
var weather := ""  ## clima criado por golpe/habilidade
var weather_t := 0.0  ## segundos restantes (-1 = sem fim em segundos)
var weather_rounds := 0  ## rodadas restantes do clima de golpe/habilidade (0 = não conta rodada)
var weather_ended := ""
var _gas_prev := false  ## havia Neutralizing Gas no frame anterior  ## clima que acabou no último fim de turno (count_weather_round)
var once_used := {}  ## "uma vez por luta" (Intrepid Sword, Supersweet Syrup): "id do mon:chave" -> true
var bouncing := false  ## Magic Bounce devolvendo um golpe (o rebatido não rebate de novo)
var dancing := false  ## Dancer repetindo um passo (não entra em cadeia)
var seen_faint := {}  ## id do lutador -> já contado o desmaio (Soul Heart, Receiver)


func _init(a: Node) -> void:
	arena = a


# --- Utilidades ---


## Magic Guard: sem dano indireto (veneno, queimadura, semente).
func no_indirect(f: BattleFighter) -> bool:
	return ability_of(f) == "magic_guard"


func ability_of(f: BattleFighter) -> String:
	var a := _raw_ability(f)
	if a != "" and a != "neutralizing_gas" and _gas_on():
		return ""  # Neutralizing Gas: ninguém mais tem habilidade
	return a


## A habilidade sem o Neutralizing Gas (Gastro Acid / Worry Seed / Trace entram aqui).
func _raw_ability(f: BattleFighter) -> String:
	if not is_instance_valid(f) or f.mon == null:
		return ""
	if f.has_meta("ability_override"):  # Gastro Acid / Worry Seed / Trace
		return String(f.get_meta("ability_override"))
	return f.mon.ability


## Há um Neutralizing Gas em campo.
func _gas_on() -> bool:
	if arena == null:
		return false
	for g in arena.fighters:
		if is_instance_valid(g) and g.active() and _raw_ability(g) == "neutralizing_gas":
			return true
	return false


## Habilidade do alvo que vale contra este atacante: o Mold Breaker ignora as defensivas.
func _tab(user: BattleFighter, target: BattleFighter, mv := {}) -> String:
	var ta := ability_of(target)
	if ta == "":
		return ""
	if _breaker(user) and not ta in UNBREAKABLE:
		return ""
	# Mycelium Might: o golpe de estado passa por cima da habilidade do alvo.
	if (
		not mv.is_empty()
		and String(mv.get("category", "")) == "status"
		and ability_of(user) == "mycelium_might"
		and not ta in UNBREAKABLE
	):
		return ""
	return ta


## Mold Breaker, Turboblaze e Teravolt: o golpe passa por cima das habilidades defensivas.
func _breaker(user: BattleFighter) -> bool:
	return is_instance_valid(user) and ability_of(user) in BREAKERS


func _state(f: BattleFighter) -> Dictionary:
	var id := f.get_instance_id()
	if not _st.has(id):
		_st[id] = {
			"banner": -99.0,
			"popup": -99.0,
			"stages": f.stages.duplicate(),
			"enter_round": rounds,
			"unburdened": f.item_used,
			"flash": false,
			"item": "",
			"moved": -99.0,  # última vez que usou um golpe (Analytic olha no alvo)
			"armor": -99.0,  # último gatilho do Weak Armor
			"shudder": false,  # Anticipation viu golpe superefetivo
			"warn": {},  # Forewarn: id do inimigo -> golpe revelado
			"gas": false,  # havia Neutralizing Gas no frame anterior
		}
	return _st[id]


func partner_of(f: BattleFighter) -> BattleFighter:
	for g in arena.fighters:
		if g != f and is_instance_valid(g) and g.side == f.side and g.active():
			return g
	return null


func _is_contact(mv: Dictionary) -> bool:
	if mv.has("contact"):  # o dado diz (oficial): vale mais que o kind
		return bool(mv.contact)
	return String(mv.get("kind", "")) in CONTACT_KINDS


func _is_sound(mv: Dictionary) -> bool:
	return bool(mv.get("sound", false)) or String(mv.get("id", "")) in SOUND_MOVES


## Alguém ativo em campo com a habilidade `a`.
func _on_field(a: String) -> BattleFighter:
	for g in arena.fighters:
		if is_instance_valid(g) and g.active() and ability_of(g) == a:
			return g
	return null


## Ordem pela Speed (a da rodada: BattleTurns.speed_order, com Trick Room e sorteio no empate);
## sem turnos, pela Speed efetiva com order_speed_mult.
func _by_speed(list: Array) -> Array:
	var t = arena.get("turns")
	if t and t.has_method("speed_order"):
		return t.speed_order(list)
	var out := list.filter(func(f): return is_instance_valid(f))
	out.sort_custom(
		func(a, b): return a.eff_spe() * order_speed_mult(a) > b.eff_spe() * order_speed_mult(b)
	)
	return out


## Mostra a habilidade agindo: popup curto (no máx. 1/s) e faixa no HUD (no máx. 1 a cada 3 s).
func _fire(f: BattleFighter, col := COL_DEFAULT) -> void:
	if not is_instance_valid(f):
		return
	var id := ability_of(f)
	var nm := String(Dex.ability(id).get("name", id.to_upper()))
	var s := _state(f)
	if _now - float(s.popup) >= POPUP_GAP:
		s.popup = _now
		f.popup(nm, col, 0.8, 0.5)
	if _now - float(s.banner) >= BANNER_GAP:
		s.banner = _now
		banners_shown += 1
		last_banner = nm
		if arena.hud and arena.hud.has_method("ability_banner"):
			arena.hud.ability_banner(f, nm)


func _stage_up(f: BattleFighter, k: String, n: int) -> void:
	if f.alive() and int(f.stages.get(k, 0)) < 6:
		arena.moves.change_stage(f, k, n)


func _heal_pct(f: BattleFighter, pct: float) -> void:
	if f.alive() and f.hp < f.max_hp:
		f.heal(f.paced(maxi(1, int(float(f.max_hp) * pct))))


func _roll(chance: float) -> bool:
	return arena.rng.randf() < chance


# --- Ganchos ---


## Lutador entrou em campo (começo, troca ou substituição): Intimidate, Drought, Frisk...
## A ativação espera o campo pronto e sai em ordem pela Speed no próximo frame de luta.
func on_enter(f: BattleFighter) -> void:
	var a := ability_of(f)
	var s := _state(f)
	s.enter_round = rounds
	if a == "super_luck":
		f.crit_stage += 1
	elif a in ENTRY:
		_pending_enter.append(f)


## Ativação ao entrar. Falso = ainda não há inimigo em campo (tenta de novo no próximo frame).
func _entry(f: BattleFighter) -> bool:
	match ability_of(f):
		"intimidate":
			return _do_intimidate(f)
		"drought", "drizzle", "sand_stream", "snow_warning":
			var wk := String(WEATHER_SETTERS[ability_of(f)])
			set_weather_rounds(wk, weather_rounds_for(f, wk))
			_fire(f, WEATHER_COLORS.get(wk, COL_DEFAULT))
		"frisk":
			return _do_frisk(f)
		"unnerve":
			if arena.targets_of(f).is_empty():
				return false
			_fire(f, Color(0.75, 0.6, 0.9))
		"cloud_nine", "air_lock":
			_fire(f, Color(0.8, 0.9, 1.0))
		"download":
			return _do_download(f)
		"anticipation":
			return _do_anticipation(f)
		"forewarn":
			return _do_forewarn(f)
		"trace":
			return _do_trace(f)
		"pressure":
			_fire(f, Color(0.75, 0.55, 0.9))
			f.popup("Pressure!", Color(0.75, 0.55, 0.9), 0.9, 0.9)
		"neutralizing_gas":
			_fire(f, Color(0.7, 0.9, 0.5))
			f.popup("Neutralizing Gas!", Color(0.7, 0.9, 0.5), 0.9, 0.9)
		"imposter":
			return _do_imposter(f)
		_:
			return BattleAbilitiesMore.entry(self, f)
	return true


# --- Clima ---


## Cria clima por `secs` s (-1 = sem fim). Devolve falso se já há o mesmo clima ativo.
func set_weather(kind: String, secs := WEATHER_SECS) -> bool:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if kind == "" or _weather_on(kind):
		return false
	weather = kind
	weather_t = secs
	weather_rounds = 0
	return true


## Clima de golpe ou habilidade (Rain Dance, Drought): dura `n` rodadas, como os 5 turnos do oficial.
func set_weather_rounds(kind: String, n := WEATHER_ROUNDS) -> bool:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if kind == "" or _weather_on(kind):
		return false
	weather = kind
	weather_t = -1.0
	weather_rounds = n
	return true


## Rodadas do clima que `f` cria: 8 com a pedra do clima segurada, senão 5.
func weather_rounds_for(f: BattleFighter, kind: String) -> int:
	kind = String(WEATHER_ALIAS.get(kind, kind))
	if (
		is_instance_valid(f)
		and not f.item_used
		and f.trainer_item != ""
		and f.trainer_item == String(WEATHER_ROCKS.get(kind, "-"))
	):
		return ROCK_ROUNDS
	return WEATHER_ROUNDS


func _weather_on(kind: String) -> bool:
	return weather == kind and (weather_t != 0.0 or weather_rounds > 0)


func _suppressed() -> bool:
	return _on_field("cloud_nine") != null or _on_field("air_lock") != null


## Clima que vale agora ("" = nenhum ou suprimido por Cloud Nine).
func weather_now() -> String:
	var w := weather
	if w == "":
		w = String(
			WEATHER_ALIAS.get(String(arena.opts.get("weather", "")), arena.opts.get("weather", ""))
		)
	if w == "" or _suppressed():
		return ""
	return w


## Frisk: mostra o item dos inimigos.
func _do_frisk(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	_fire(f, Color(0.7, 0.9, 1.0))
	for t in foes:
		var it := String(Dex.item(t.trainer_item).get("name", t.trainer_item))
		var held: String = _state(t).item
		if held != "":
			it = String(Dex.item(held).get("name", held))
		f.popup(
			"%s: %s" % [t.mon.display_name, it if it != "" else "no item"],
			Color(0.7, 0.9, 1.0),
			0.8,
			0.9
		)
	return true


## Intimidate: -1 ATK em todos os inimigos ativos (os dois no 2x2). Falso se ainda não há inimigo.
func _do_intimidate(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	_fire(f, Color(1.0, 0.5, 0.35))
	for t in foes:
		var tb := ability_of(t)
		if tb == "guard_dog":
			_stage_up(t, "atk", 1)  # Guard Dog: a intimidação vira coragem
			_fire(t, Color(1.0, 0.7, 0.4))
		elif tb == "mirror_armor":
			_fire(t, Color(0.85, 0.9, 1.0))
			arena.moves.change_stage(f, "atk", -1)  # Mirror Armor devolve o -1
		elif tb in INTIMIDATE_PROOF:
			_fire(t)
		else:
			arena.moves.change_stage(t, "atk", -1)
			if ability_of(t) == "rattled":
				_stage_up(t, "spe", 1)  # Rattled: o susto dá pressa
				_fire(t, Color(0.6, 0.5, 0.7))
	return true


# --- Habilidades de Kanto: entrada ---


## Download: compara a Defesa e a Def. Esp. dos inimigos e sobe o Ataque ou o Atq. Esp.
func _do_download(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	var def_sum := 0.0
	var spd_sum := 0.0
	for t in foes:
		def_sum += t.stat("def")
		spd_sum += t.stat("spd")
	_fire(f, Color(0.5, 0.9, 1.0))
	_stage_up(f, "atk" if def_sum < spd_sum else "spa", 1)
	return true


## Golpe que assusta quem tem `types`: superefetivo ou nocaute de um golpe (OHKO).
static func _dangerous(mv: Dictionary, types: Array) -> bool:
	if String(mv.get("special", "")) == "ohko":
		return true
	return (
		float(mv.get("power", 0)) > 0.0
		and Dex.effectiveness(String(mv.get("type", "")), types) > 1.0
	)


## Anticipation: avisa se algum inimigo tem golpe perigoso contra ele; com o aviso, esquiva às vezes.
func _do_anticipation(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	var s := _state(f)
	for t in foes:
		for id in t.moves:
			if _dangerous(Dex.move(String(id)), f.types):
				s.shudder = true
	if s.shudder:
		f.popup("Shudder!", Color(0.8, 0.7, 1.0), 0.9, 0.9)
		_fire(f, Color(0.8, 0.7, 1.0))
	return true


## Poder que o Forewarn enxerga no golpe (OHKO 150, dano fixo ou variável 80, status 0).
static func _scary_power(mv: Dictionary) -> float:
	if String(mv.get("special", "")) == "ohko":
		return 150.0
	if String(mv.get("category", "status")) == "status":
		return 0.0
	var p := float(mv.get("power", 0))
	return p if p > 1.0 else 80.0


## Forewarn: revela o golpe mais forte de cada inimigo; contra esse golpe esquiva às vezes.
func _do_forewarn(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	var s := _state(f)
	s.warn = {}
	for t in foes:
		var best := ""
		var top := 0.0
		for id in t.moves:
			var p := _scary_power(Dex.move(String(id)))
			if p > top:
				top = p
				best = String(id)
		if best != "":
			s.warn[t.get_instance_id()] = best
			f.popup(
				"Forewarn: %s" % String(Dex.move(best).get("name", best)),
				Color(1.0, 0.8, 0.5),
				0.85,
				0.9
			)
	if not s.warn.is_empty():
		_fire(f, Color(1.0, 0.8, 0.5))
	return true


## Trace: copia a habilidade de um inimigo e a ativa na hora.
## Imposter (Ditto): ao entrar vira cópia do inimigo mais perto (BattleTransform, como o golpe Transform).
func _do_imposter(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	foes.sort_custom(
		func(a, b):
			return (
				f.global_position.distance_to(a.global_position)
				< f.global_position.distance_to(b.global_position)
			)
	)
	for t in foes:
		if BattleTransform.apply(arena, f, t):
			_fire(f, Color(0.8, 0.6, 0.95))
			return true
	return true


func _do_trace(f: BattleFighter) -> bool:
	var foes: Array = arena.targets_of(f)
	if foes.is_empty():
		return false
	var pool: Array = []
	for t in foes:
		var a := ability_of(t)
		if a != "" and not a in UNTRACEABLE:
			pool.append(a)
	if pool.is_empty():
		return true
	var got := String(pool[arena.rng.randi() % pool.size()])
	f.set_meta("ability_override", got)
	f.popup(
		"Copied %s" % String(Dex.ability(got).get("name", got.to_upper())),
		Color(0.7, 0.9, 1.0),
		0.9,
		0.9
	)
	if got == "super_luck":
		f.crit_stage += 1
	elif got in ENTRY:
		return _entry(f)
	return true


## Esquiva de Anticipation (golpe perigoso depois do arrepio) e Forewarn (o golpe revelado).
func _foresaw(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	var ta := ability_of(target)
	if ta != "anticipation" and ta != "forewarn":
		return false
	var s := _state(target)
	var chance := ANTICIPATION_DODGE
	if ta == "anticipation":
		if not s.shudder or not _dangerous(mv, target.types):
			return false
	else:
		if String(s.warn.get(user.get_instance_id(), "")) != String(mv.get("id", "-")):
			return false
		chance = FOREWARN_DODGE
	if not _roll(chance):
		return false
	target.popup("Foresaw!", Color(0.8, 0.9, 1.0), 1.0, 0.5)
	_fire(target, Color(0.8, 0.9, 1.0))
	return true


# --- Habilidades de Kanto: golpe e custo ---


## Registra o golpe usado (Analytic olha no alvo quando ele agiu).
func on_move_used(user: BattleFighter, mv: Dictionary) -> void:
	if is_instance_valid(user):
		_state(user).moved = _now
		BattleAbilitiesMore.on_move_used(self, user, mv)


## O lutador usou um golpe há menos de ANALYTIC_WINDOW s.
func _acted_recently(f: BattleFighter) -> bool:
	return _now - float(_state(f).moved) <= ANALYTIC_WINDOW


## Tipos do alvo como o golpe os enxerga: Scrappy acerta Fantasma com Normal e Lutador.
func hit_types(user: BattleFighter, _target: BattleFighter, mv: Dictionary, types: Array) -> Array:
	if (
		"ghost" in types
		and String(mv.get("type", "")) in SCRAPPY_TYPES
		and ability_of(user) == "scrappy"
	):
		var out: Array = types.filter(func(t): return t != "ghost")
		return out if not out.is_empty() else ["normal"]
	return types


## Pressure: o golpe custa PRESSURE_COST x mais com um inimigo com Pressure a menos de PRESSURE_RANGE m.
func cost_mult(f: BattleFighter) -> float:
	if not is_instance_valid(f) or arena == null:
		return 1.0
	for t in arena.targets_of(f):
		if ability_of(t) == "pressure" and f.flat_to(t).length() < PRESSURE_RANGE:
			return PRESSURE_COST
	return 1.0


## Liquid Ooze: o dreno do `target` (golpe, semente) faz mal a `user` em vez de curar. true = o HP de
## `gain` foi tirado do `user`.
func drain_backfires(user: BattleFighter, target: BattleFighter, gain: int) -> bool:
	if ability_of(target) != "liquid_ooze" or not is_instance_valid(user) or not user.alive():
		return false
	_fire(target, Color(0.6, 0.35, 0.7))
	if ability_of(user) != "magic_guard":
		user.popup("-%d" % gain, Color(0.6, 0.35, 0.7), 0.9, 0.5)
		user.take_damage(gain, Vector3.ZERO, 0.0)
	return true


## A IA pesa o golpe: dreno em Liquid Ooze quase não vale (o dano ainda conta, a cura vira dano).
func ai_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	if mv.has("drain") and ability_of(target) == "liquid_ooze":
		return 0.3
	return BattleAbilitiesMore.ai_mult(self, user, target, mv)


## Synchronize: o status (veneno, queimadura, paralisia) volta para quem o causou.
func on_status(f: BattleFighter, status: String, src: BattleFighter) -> void:
	BattleAbilitiesMore.on_status(self, f, status, src)  # Poison Puppeteer
	if (
		ability_of(f) != "synchronize"
		or not status in SYNC_STATUS
		or src == null
		or not is_instance_valid(src)
		or src == f
		or src.side == f.side
		or not src.alive()
	):
		return
	if BattleMoves.STATUS_IMMUNE.get(status, "-") in src.types or blocks_status(src, status):
		return
	if src.apply_status(status, f):
		_fire(f, Color(1.0, 0.7, 0.9))
		src.popup(
			String(BattleMoves.STATUS_WORDS.get(status, status.to_upper() + "!")),
			Color(1, 0.9, 0.6)
		)


# --- Dano ---


## Multiplicadores de dano de cada lado (sem efeitos colaterais).
func _mults(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> Dictionary:
	var ua := ability_of(user)
	var ta := _tab(user, target, mv)
	var um := 1.0
	var tm := 1.0
	var type := String(mv.get("type", "normal"))
	var power := float(mv.get("power", 0))
	var cat := String(mv.get("category", ""))
	var kind := String(mv.get("kind", ""))
	var id := String(mv.get("id", ""))
	if PINCH.get(ua, "") == type and user.hp * 3 <= user.max_hp:
		um *= PINCH_MULT
	var wx := weather_now()
	if power > 0.0:
		if (wx == "sun" and type == "fire") or (wx == "rain" and type == "water"):
			um *= 1.5
		elif (wx == "sun" and type == "water") or (wx == "rain" and type == "fire"):
			um *= 0.5
	match ua:
		"guts":
			if cat == "physical" and user.status != "":
				um *= 1.5
		"huge_power", "pure_power":
			if cat == "physical":
				um *= 2.0
		"analytic":
			# o alvo acabou de agir: pega ele no meio da recuperação
			if power > 0.0 and _acted_recently(target):
				um *= ANALYTIC_MULT
		"hustle":
			if cat == "physical":
				um *= 1.5
		"technician":
			if power > 0.0 and power <= 60.0:
				um *= 1.5
		"adaptability":
			# STAB 2,0 no lugar de 1,5
			if power > 0.0 and type in user.types:
				um *= 4.0 / 3.0
		"sheer_force":
			if mv.get("effect") is Dictionary:
				um *= 1.3
		"iron_fist":
			if id in PUNCH_MOVES:
				um *= 1.2
		"strong_jaw":
			if id in BITE_MOVES:
				um *= 1.5
		"tough_claws":
			if _is_contact(mv):
				um *= 1.3
		"reckless":
			if mv.has("recoil") or id in RECKLESS_MOVES:
				um *= 1.2
		"flash_fire":
			if type == "fire" and _state(user).flash:
				um *= 1.5
		"plus", "minus":
			if cat == "special":
				var p := partner_of(user)
				if p != null and ability_of(p) in ["plus", "minus"]:
					um *= 1.5
		"tinted_lens":
			if power > 0.0 and Dex.effectiveness(type, target.types) < 1.0:
				um *= 2.0
		"solar_power":
			if cat == "special" and wx == "sun":
				um *= 1.5
		"sand_force":
			if power > 0.0 and wx == "sand" and type in SANDPROOF_TYPES:
				um *= 1.3
		"rivalry":
			var g1: String = user.mon.gender
			var g2: String = target.mon.gender
			if power > 0.0 and g1 != "" and g2 != "":
				um *= 1.25 if g1 == g2 else 0.75
		"unaware":
			# ignora os estágios de defesa do alvo
			if power > 0.0 and cat in ["physical", "special"]:
				var dk := "def" if cat == "physical" else "spd"
				um *= StatCalc.stage_mult(int(target.stages.get(dk, 0)))
	match ta:
		"thick_fat":
			if type in ["fire", "ice"]:
				tm *= 0.5
		"multiscale":
			if target.hp >= target.max_hp:
				tm *= 0.5
		"marvel_scale":
			# Defesa x1,5 com status: só no físico
			if target.status != "" and cat == "physical":
				tm *= 2.0 / 3.0
		"filter", "solid_rock", "prism_armor":
			if power > 0.0 and Dex.effectiveness(type, target.types) > 1.0:
				tm *= 0.75
		"dry_skin":
			if type == "fire":
				tm *= 1.25
		"unaware":
			# ignora os estágios de ataque de quem bate
			if power > 0.0 and cat in ["physical", "special"]:
				var ak := "atk" if cat == "physical" else "spa"
				tm /= StatCalc.stage_mult(int(user.stages.get(ak, 0)))
	if power > 0.0:
		if wx == "sand" and cat == "special" and "rock" in target.types:
			tm /= WEATHER_DEF_MULT
		elif wx == "hail" and cat == "physical" and "ice" in target.types:
			tm /= WEATHER_DEF_MULT
	var more := BattleAbilitiesMore.mults(self, user, target, mv, ua, ta, wx)
	um *= float(more.user)
	tm *= float(more.target)
	var pa := partner_of(target)
	if (
		pa != null
		and ability_of(pa) == "friend_guard"
		and not ua in ["infiltrator", "mold_breaker", "turboblaze", "teravolt"]
	):
		tm *= 0.75
	return {"user": um, "target": tm}


## Shell Armor / Battle Armor: não leva crítico (oficial).
func no_crit(f: BattleFighter, user: BattleFighter = null) -> bool:
	var a := ability_of(f)
	if user != null and _breaker(user):
		return false  # Mold Breaker: o golpe passa por cima do Shell Armor
	return a in ["shell_armor", "battle_armor"]


## Sniper: o crítico dá 2,25x em vez de 1,5x (o fator extra por cima do CRIT_MULT).
func crit_bonus(user: BattleFighter) -> float:
	return 2.25 / StatCalc.CRIT_MULT if ability_of(user) == "sniper" else 1.0


## Multiplicador no fim da fórmula de dano (Blaze/Torrent/Overgrow/Swarm, Thick Fat...).
func damage_mult(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> float:
	var m := _mults(user, target, mv)
	return float(m.user) * float(m.target)


# --- Alvo e imunidade ---


## Habilidade que puxa golpes de alvo único do tipo (Lightning Rod, Storm Drain) ou "".
static func _rod_for(type: String) -> String:
	match type:
		"electric":
			return "lightning_rod"
		"water":
			return "storm_drain"
	return ""


## Para-raios / Dreno no 2x2: golpe inimigo de ALVO ÚNICO do tipo mirado no parceiro vai para o
## portador (que absorve em immune()). Golpe de vários alvos (Discharge, Bubble...) não é puxado.
## BattleMoves.hit chama antes de immune(); devolve quem leva o golpe.
func redirect(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> BattleFighter:
	if not is_instance_valid(user) or not is_instance_valid(target) or user.side == target.side:
		return target
	if BattleMoves.multi_target(mv) != "":
		return target
	if ability_of(user) in ["propeller_tail", "stalwart"]:
		return target  # Propeller Tail / Stalwart: nada puxa o golpe
	var rod := _rod_for(String(mv.get("type", "")))
	if rod == "" or ability_of(target) == rod:
		return target
	var p := partner_of(target)
	if p != null and ability_of(p) == rod:
		return p
	return target


## true = o alvo é imune a este golpe pela habilidade (Levitate, Water Absorb, Soundproof...).
func immune(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	var cat := String(mv.get("category", ""))
	# Damp: ninguém explode enquanto ele está em campo.
	if id in EXPLODE_MOVES:
		var d := _on_field("damp")
		if d != null:
			_fire(d)
			return true
	# Prankster: o golpe de status acelerado não pega em inimigo Sombrio (Gen 7+).
	if (
		ability_of(user) == "prankster"
		and cat == "status"
		and user.side != target.side
		and "dark" in target.types
	):
		target.popup("It doesn't affect...", Color(0.7, 0.7, 0.7))
		return true
	if user.side != target.side and _foresaw(user, target, mv):
		return true  # Anticipation / Forewarn: viu o golpe vindo
	var ta := _tab(user, target, mv)  # Mold Breaker ignora as defensivas
	if _absorbs(target, type, ta):
		return true
	if BattleAbilitiesMore.immune(self, user, target, mv, ta):
		return true
	match ta:
		"wonder_skin":
			# golpe de status de inimigo: precisão cai para 50%
			var acc := float(mv.get("accuracy", 0.0))
			if cat == "status" and user.side != target.side and acc > 50.0 and _roll(0.5):
				_fire(target)
				return true
		"levitate":
			if type == "ground":
				_fire(target)
				return true
		"soundproof":
			if _is_sound(mv):
				_fire(target)
				return true
		"sticky_hold":
			if id == "thief":
				_fire(target)
				return true
		"telepathy":
			# não leva golpe de dano do parceiro (Earthquake, Discharge...)
			if user.side == target.side and user != target and float(mv.get("power", 0)) > 0.0:
				_fire(target)
				return true
	return false


## Habilidades que absorvem um tipo (o golpe não causa dano).
func _absorbs(owner: BattleFighter, type: String, ab: String) -> bool:
	var col := Dex.type_color(type)
	match ab:
		"water_absorb":
			if type == "water":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"dry_skin":
			if type == "water":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"volt_absorb":
			if type == "electric":
				_heal_pct(owner, 0.25)
				_fire(owner, col)
				return true
		"motor_drive":
			if type == "electric":
				_stage_up(owner, "spe", 1)
				_fire(owner, col)
				return true
		"sap_sipper":
			if type == "grass":
				_stage_up(owner, "atk", 1)
				_fire(owner, col)
				return true
		"lightning_rod":
			if type == "electric":
				_stage_up(owner, "spa", 1)
				_fire(owner, col)
				return true
		"storm_drain":
			if type == "water":
				_stage_up(owner, "spa", 1)
				_fire(owner, col)
				return true
		"flash_fire":
			if type == "fire":
				_state(owner).flash = true
				_fire(owner, col)
				return true
	return false


## Dano final ajustado (Sturdy segura com 1 HP etc.). Devolve o dano a aplicar.
func adjust_damage(user: BattleFighter, target: BattleFighter, mv: Dictionary, dmg: int) -> int:
	dmg = BattleAbilitiesMore.adjust(self, user, target, mv, dmg)
	if _tab(user, target) == "sturdy" and target.hp >= target.max_hp and dmg >= target.hp:
		_fire(target, Color(0.8, 0.8, 0.9))
		return maxi(target.hp - 1, 0)
	return dmg


## Depois do acerto (Static, Poison Point, Effect Spore ao contato...). `crit` = o golpe foi crítico.
func on_hit(
	user: BattleFighter, target: BattleFighter, mv: Dictionary, dmg: int, crit := false
) -> void:
	if not is_instance_valid(user) or not is_instance_valid(target):
		return
	var ua := ability_of(user)
	var ta := ability_of(target)
	var m := _mults(user, target, mv)
	if float(m.user) != 1.0:
		_fire(user)
	if float(m.target) != 1.0:
		_fire(target)
	var contact := _is_contact(mv) and ua != "long_reach"  # Long Reach: nada que encosta
	if contact and user.alive():
		if CONTACT_STATUS.has(ta) and _roll(CONTACT_CHANCE):
			var opts: Array = CONTACT_STATUS[ta]
			var st := String(opts[arena.rng.randi() % opts.size()])
			var spore_proof: bool = (
				ta == "effect_spore" and ("grass" in user.types or ua == "overcoat")
			)
			if (
				not spore_proof
				and not BattleMoves.STATUS_IMMUNE.get(st, "-") in user.types
				and not blocks_status(user, st)
				and user.apply_status(st, target)
			):
				_fire(target)
				user.popup(
					String(BattleMoves.STATUS_WORDS.get(st, st.to_upper() + "!")),
					Color(1, 0.9, 0.6)
				)
		elif ta == "cute_charm" and ua != "oblivious" and _attracts(user, target):
			user.gcd_t += 1.2
			user.popup("Infatuated!", Color(1.0, 0.55, 0.75))
			_fire(target, Color(1.0, 0.55, 0.75))
		elif ta == "rough_skin" and ua != "magic_guard":
			var chip := user.paced(maxi(1, int(user.max_hp / 8.0)))
			_fire(target)
			user.popup("-%d" % chip, Color(0.8, 0.6, 0.4), 0.8)
			user.take_damage(chip, Vector3.ZERO, 0.0)
	if ua == "stench" and target.alive() and _roll(0.1) and not blocks_status(target, "flinch"):
		target.apply_status("flinch", user)
		_fire(user, Color(0.6, 0.5, 0.7))
	if ua == "serene_grace" and target.alive():
		_serene(user, target, mv)
	if target.alive():
		_kanto_on_hit(user, target, mv, crit, contact)
	BattleAbilitiesMore.on_hit(self, user, target, mv, dmg, crit, contact)
	if ta == "justified" and String(mv.get("type", "")) == "dark":
		_stage_up(target, "atk", 1)
		_fire(target)
	if target.hp <= 0:
		BattleAbilitiesMore.on_ko(self, user)
		if ua == "moxie":
			_stage_up(user, "atk", 1)
			_fire(user)
		if (
			ta == "aftermath"
			and contact
			and user.alive()
			and ua != "magic_guard"
			and _on_field("damp") == null
		):
			_fire(target)
			user.take_damage(user.paced(maxi(1, int(user.max_hp / 4.0))), Vector3.ZERO, 0.0)


## Anger Point, Cursed Body, Poison Touch, Rattled e Weak Armor (as de Kanto) depois do acerto.
func _kanto_on_hit(
	user: BattleFighter, target: BattleFighter, mv: Dictionary, crit: bool, contact: bool
) -> void:
	var ua := ability_of(user)
	var ta := ability_of(target)
	var type := String(mv.get("type", ""))
	var power := float(mv.get("power", 0))
	if ua == "poison_touch" and contact and _roll(POISON_TOUCH_CHANCE):
		if (
			not BattleMoves.STATUS_IMMUNE.get("poison", "-") in target.types
			and not blocks_status(target, "poison", user)
			and target.apply_status("poison", user)
		):
			_fire(user, Color(0.75, 0.35, 0.95))
			target.popup(
				String(BattleMoves.STATUS_WORDS.get("poison", "POISONED!")), Color(1, 0.9, 0.6)
			)
	if user.side == target.side or power <= 0.0:
		return
	match ta:
		"anger_point":
			if crit:
				_stage_up(target, "atk", 6)
				if target.mood_state == "":
					target.mood_state = "fury"  # a IA para de recuar
				target.popup("Rage!", Color(1.0, 0.4, 0.3), 1.0, 0.9, "special")
				_fire(target, Color(1.0, 0.4, 0.3))
		"cursed_body":
			var id := String(mv.get("id", ""))
			if user.alive() and id != "" and _roll(CURSED_CHANCE):
				user.move_cd[id] = maxf(float(user.move_cd.get(id, 0.0)), CURSED_LOCK)
				user.popup(
					"%s locked!" % String(mv.get("name", id)), Color(0.6, 0.45, 0.8), 0.9, 0.7
				)
				_fire(target, Color(0.6, 0.45, 0.8))
		"rattled":
			if type in ["bug", "ghost", "dark"]:
				_stage_up(target, "spe", 1)
				_fire(target, Color(0.6, 0.5, 0.7))
		"weak_armor":
			var s := _state(target)
			if String(mv.get("category", "")) == "physical" and _now - float(s.armor) >= ARMOR_GAP:
				s.armor = _now
				arena.moves.change_stage(target, "def", -1)
				_stage_up(target, "spe", 2)
				_fire(target, Color(0.8, 0.75, 0.6))


## Cute Charm: 30% ao contato, só entre sexos opostos (sem sexo não se enfeitiça).
func _attracts(user: BattleFighter, target: BattleFighter) -> bool:
	var g1: String = user.mon.gender
	var g2: String = target.mon.gender
	return g1 != "" and g2 != "" and g1 != g2 and _roll(CONTACT_CHANCE)


## Serene Grace: segunda chance para o efeito extra do golpe.
func _serene(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> void:
	var ef = mv.get("effect")
	if not ef is Dictionary or not _roll(float(ef.get("chance", 0.0))):
		return
	if ef.has("stat"):
		var who: BattleFighter = user if ef.get("self", false) else target
		arena.moves.change_stage(who, String(ef.stat), int(ef.stages))
	else:
		var st := String(ef.status)
		if (
			BattleMoves.STATUS_IMMUNE.get(st, "-") in target.types
			or blocks_status(target, st)
			or not target.apply_status(st, user)
		):
			return
	_fire(user)


## true = a habilidade bloqueia esse status (Inner Focus, Own Tempo, Vital Spirit...).
func blocks_status(f: BattleFighter, status: String, src: BattleFighter = null) -> bool:
	var a := ability_of(f)
	if src != null and a != "" and _breaker(src) and not a in UNBREAKABLE:
		a = ""  # Mold Breaker: Own Tempo, Insomnia, Shield Dust... não seguram
	if a == "shield_dust" or (BLOCKS.has(a) and status in BLOCKS[a]):
		_fire(f)
		return true
	if BattleAbilitiesMore.blocks_status(self, f, status, src):
		return true
	if a == "steadfast" and status == "flinch":
		_stage_up(f, "spe", 1)
		_fire(f)
	if weather_now() == "sun":
		# sol forte: ninguém congela; Leaf Guard não pega status nenhum (oficial)
		if status == "freeze":
			return true
		if a == "leaf_guard" and status in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
			_fire(f)
			return true
	return false


## Queda de atributo que a habilidade impede (Clear Body, Hyper Cutter, Keen Eye, Big Pecks).
func blocks_stage_drop(f: BattleFighter, k: String, src: BattleFighter = null) -> bool:
	var a := ability_of(f)
	if src != null and a != "" and _breaker(src) and not a in UNBREAKABLE:
		return false
	if BattleAbilitiesMore.keeps_stat(self, f, k, src):
		return true
	if not KEEP_STAT.has(a):
		return false
	var keys: Array = KEEP_STAT[a]
	return keys.is_empty() or k in keys


## Multiplicador de precisão do usuário (Compound Eyes, Hustle, No Guard).
func acc_mult(f: BattleFighter) -> float:
	var m := BattleAbilitiesMore.acc_bonus(self, f)  # Victory Star (o time todo)
	match ability_of(f):
		"compound_eyes":
			return 1.3 * m
		"no_guard":
			return NO_GUARD_ACC
		"hustle":
			return 0.8 * m
	return m


# --- Habilidades da Gen 3-9 que faltavam (battle_abilities_more.gd): ganchos de fora ---


## O golpe como `user` o solta (Normalize, Pixilate, Liquid Voice...): BattleMoveEffects.move_for chama.
func move_for(user: BattleFighter, mv: Dictionary) -> Dictionary:
	return BattleAbilitiesMore.move_for(self, user, mv)


## Golpe que não pode sair agora ("" = pode): Truant folgando, Tatsugiri na boca do Dondozo.
func move_blocked(user: BattleFighter, mv: Dictionary) -> String:
	return BattleAbilitiesMore.move_blocked(self, user, mv)


## Golpe de estado/prioridade parado pela habilidade do alvo (Magic Bounce, Good as Gold, Dazzling...).
func blocks_hit(user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	return BattleAbilitiesMore.blocks_hit(self, user, target, mv)


## Contrary inverte e Simple dobra a mudança de estágio (BattleMoves.change_stage).
func stage_delta(c: BattleFighter, delta: int) -> int:
	match ability_of(c):
		"simple":
			return delta * 2
		"contrary":
			return -delta
	return delta


## Mirror Armor: a queda de atributo causada por um inimigo volta para ele. true = refletiu.
func mirrors(c: BattleFighter, k: String, delta: int, src: BattleFighter) -> bool:
	if (
		delta >= 0
		or not is_instance_valid(src)
		or src.side == c.side
		or ability_of(c) != "mirror_armor"
		or _breaker(src)
	):
		return false
	_fire(c, Color(0.85, 0.9, 1.0))
	arena.moves.change_stage(src, k, delta)
	return true


## Shadow Tag: o inimigo (que não é Fantasma nem Shadow Tag) não consegue trocar nem fugir.
func traps(f: BattleFighter) -> bool:
	if not is_instance_valid(f) or "ghost" in f.types or ability_of(f) == "shadow_tag":
		return false
	for t in arena.targets_of(f):
		if ability_of(t) == "shadow_tag":
			return true
	return false


## Suction Cups e Guard Dog: não são empurrados nem arrastados para fora por Whirlwind, Roar & cia.
func anchored(f: BattleFighter) -> bool:
	return ability_of(f) in ["suction_cups", "guard_dog"]


## Unseen Fist: o golpe de contato atravessa o Protect.
func pierces_protect(user: BattleFighter, mv: Dictionary) -> bool:
	return ability_of(user) == "unseen_fist" and _is_contact(mv)


## Heatproof: a queimadura tira só metade.
func burn_mult(f: BattleFighter) -> float:
	return 0.5 if ability_of(f) == "heatproof" else 1.0


## Ajuste do perfil do atacante na fórmula de dano (Merciless: crítico em envenenado).
func tweak_attacker(user: BattleFighter, target: BattleFighter, p: Dictionary) -> void:
	BattleAbilitiesMore.crit_tweak(self, user, target, p)


## O lutador comeu a frutinha segurada (Cheek Pouch, Cud Chew).
func on_berry(f: BattleFighter) -> void:
	BattleAbilitiesMore.on_berry(self, f)


## Itens que as habilidades acharam na luta ganha (Honey Gather); a arena os põe na mochila.
func found_items() -> Array:
	return BattleAbilitiesMore.honey(self)


# --- Speed: ordem da rodada, andar e preparo ---


## Multiplicador da Speed na ordem da rodada (BattleTurns.order_speed, por cima de eff_spe):
## Chlorophyll/Swift Swim/Sand Rush 2x no clima, Quick Feet 1,5x com status (e sem o corte da
## paralisia), Unburden 2x depois de usar o item.
func order_speed_mult(f: BattleFighter) -> float:
	var a := ability_of(f)
	var extra := float(BattleAbilitiesMore.speed(self, f).order)  # Slow Start, Stall, paradoxos
	if _weather_speed(a):
		return SPEED_DOUBLE * extra
	match a:
		"quick_feet":
			if f.status != "":
				return 1.5 * (2.0 if f.status == "paralysis" else 1.0) * extra
		"unburden":
			if f.item_used:
				return SPEED_DOUBLE * extra
	return extra


## Prioridade extra do golpe (BattleTurns.priority_of): Prankster +1 em status, Gale Wings +1 em
## Voador com HP cheio (Gen 7+).
func priority_bonus(f: BattleFighter, mv: Dictionary) -> int:
	var tri := BattleAbilitiesMore.priority_bonus(self, f, mv)
	if tri != 0:
		return tri
	match ability_of(f):
		"prankster":
			if String(mv.get("category", "")) == "status":
				return 1
		"gale_wings":
			if String(mv.get("type", "")) == "flying" and f.hp >= f.max_hp:
				return 1
	return 0


## Multiplicador da velocidade de andar (a arena aplica em Fighter.drive).
func walk_mult(f: BattleFighter) -> float:
	var m := float(BattleAbilitiesMore.speed(self, f).walk)
	var a := ability_of(f)
	match a:
		"run_away":
			m *= 1.1
		"quick_feet":
			if f.status != "":
				m *= 1.3
		"unburden":
			if f.item_used:
				m *= SPEED_WALK
	if _weather_speed(a):
		m *= SPEED_WALK
	for t in arena.targets_of(f):
		var ta := ability_of(t)
		if ta == "arena_trap" and not f.is_airborne() and a != "levitate":
			m *= 0.9
		elif ta == "magnet_pull" and "steel" in f.types:
			m *= 0.9
	return m


## Speed dobrada no clima certo (Chlorophyll no sol, Swift Swim na chuva, Sand Rush na areia, Slush
## Rush na neve).
func _weather_speed(a: String) -> bool:
	var wx := weather_now()
	return (
		(a == "chlorophyll" and wx == "sun")
		or (a == "swift_swim" and wx == "rain")
		or (a == "sand_rush" and wx == "sand")
		or (a == "slush_rush" and wx == "hail")
	)


## Multiplicador da velocidade de lançar o golpe (o preparo em tempo real): >1 = sai mais rápido.
## A ordem da rodada vem de order_speed_mult/priority_bonus.
func cast_speed_mult(f: BattleFighter, mv: Dictionary) -> float:
	var a := ability_of(f)
	var more := (
		float(BattleAbilitiesMore.speed(self, f).cast) * BattleAbilitiesMore.cast_mult(self, f, mv)
	)
	if _weather_speed(a) or (a == "unburden" and f.item_used):
		return SPEED_WALK * more
	match a:
		"prankster":
			if String(mv.get("category", "")) == "status":
				return 1.5 * more
		"gale_wings":
			if String(mv.get("type", "")) == "flying" and f.hp >= f.max_hp:
				return 1.4 * more
		"quick_feet":
			if f.status != "":
				return 1.2 * more
	return more


## Perfil de movimento sugerido pela habilidade ("" = nenhum).
func profile_bias(f: BattleFighter) -> String:
	return String(PROFILES.get(ability_of(f), ""))


# --- Fim de rodada (o "fim de turno" do oficial) ---


## Fim de turno só das habilidades, na ordem oficial (clima; Shed Skin; Poison Heal; Speed Boost e
## o resto), pela Speed. A luta usa BattleEndTurn.run(), que chama os mesmos passos intercalados com
## status, itens e campo; este atalho serve aos testes e a quem não tem BattleEndTurn.
func on_round_end() -> void:
	var order := round_order()
	if count_weather_round():
		for f in order:
			if f.active():
				weather_residual(f)
	for f in order:
		if f.active():
			shed_skin(f)
	for f in order:
		if f.active() and ability_of(f) == "poison_heal" and f.status in ["poison", "toxic"]:
			_round_heal(f, 1.0 / 8.0)
	for f in order:
		if f.active():
			late_residual(f)
	finish_round(order)


## Lutadores ativos na ordem do fim de turno (Speed; Trick Room inverte).
func round_order() -> Array:
	return _by_speed(arena.fighters.filter(func(g): return is_instance_valid(g) and g.active()))


## Fecha o fim de turno: guarda a ordem (testes) e conta a rodada (Speed Boost olha a de entrada).
func finish_round(order: Array) -> void:
	last_round_order = order
	rounds += 1


## Passo 1 do fim de turno: conta a rodada do clima de golpe/habilidade (como o oficial, conta antes:
## no turno em que acaba não tira HP). true = o clima segue valendo e age (areia, Rain Dish...).
## weather_ended guarda o clima que acabou agora ("" se nenhum).
func count_weather_round() -> bool:
	weather_ended = ""
	if weather_rounds > 0:
		weather_rounds -= 1
		if weather_rounds == 0:
			weather_ended = weather
			weather = ""
			weather_t = 0.0
			return false
	return weather_now() != ""


## Clima no fim do turno, para um lutador: Rain Dish 1/16, Dry Skin +1/8 na chuva e -1/8 no sol,
## Solar Power -1/8, areia -1/16 em quem não é Pedra/Terra/Aço (nem Sand Veil/Rush/Force, Magic Guard,
## Overcoat), Ice Body +1/16 na neve. A neve (hail) da Gen 9 não tira HP.
func weather_residual(f: BattleFighter) -> void:
	var a := ability_of(f)
	var guard := a == "magic_guard"
	match weather_now():
		"rain":
			if a == "rain_dish":
				_round_heal(f, 1.0 / 16.0, "Rain Dish")
			elif a == "dry_skin":
				_round_heal(f, 1.0 / 8.0, "Dry Skin")
		"sun":
			if a in ["dry_skin", "solar_power"] and not guard:
				_weather_chip(f, 1.0 / 8.0, Color(1.0, 0.75, 0.3), "sun")
				_fire(f, Color(1.0, 0.75, 0.3))
		"sand":
			if not _sand_proof(f, a):
				_weather_chip(f, 1.0 / 16.0, Color(0.85, 0.72, 0.42), "sand")
		"hail":
			if a == "ice_body":
				_round_heal(f, 1.0 / 16.0, "Ice Body")


## Passo 4 (junto do Leftovers): Shed Skin, 1/3 de curar o status; Hydration cura sempre na chuva.
## true = curou.
func shed_skin(f: BattleFighter) -> bool:
	var a := ability_of(f)
	if (
		not a in ["shed_skin", "hydration"]
		or not f.status in Mon.PERSIST_STATUS + ["toxic", "freeze"]
	):
		return false
	if a == "hydration" and weather_now() != "rain":
		return false
	if a == "shed_skin" and not _roll(1.0 / 3.0):
		return false
	f.clear_status()
	_fire(f)
	return true


## Passo final das habilidades (oficial: Speed Boost, Moody, Pickup... depois dos efeitos de campo):
## Speed Boost +1 (não no turno em que entrou); adaptados ao tempo real: Natural Cure cura em campo,
## Regenerator 1/16, Pickup 2%.
func late_residual(f: BattleFighter) -> void:
	var a := ability_of(f)
	var s := _state(f)
	match a:
		"speed_boost":
			# não na rodada em que entrou (oficial: não no turno da troca)
			if int(s.enter_round) < rounds and int(f.stages.get("spe", 0)) < 6:
				_stage_up(f, "spe", 1)
				_fire(f)
		"natural_cure":
			# oficial: cura ao sair; em campo (tempo real) cura no fim da rodada
			if f.status in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
				f.clear_status()
				_fire(f, Color(0.6, 1.0, 0.7))
		"regenerator":
			# oficial: 1/3 ao sair; em campo, 1/16 por rodada
			_round_heal(f, 1.0 / 16.0)
		"pickup":
			_round_heal(f, 0.02)
		"early_bird":
			_early_bird(f)
		"harvest":
			_harvest(f)
		"healer":
			_healer(f)
	BattleAbilitiesMore.late(self, f, a, s)


## Early Bird: o sono corre em dobro (um passo a mais por rodada, fora a rodada em que dormiu).
func _early_bird(f: BattleFighter) -> void:
	if f.status != "sleep" or f.round_now() == f.status_round:
		return
	f.sleep_turns -= 1
	if f.sleep_turns <= 1:
		f.clear_status()
		f.popup("Woke up!", Color(0.85, 0.9, 1.0), 0.9)
		_fire(f, Color(1.0, 0.9, 0.5))


## Harvest: a frutinha comida volta a cada rodada (50%, sempre no sol).
func _harvest(f: BattleFighter) -> void:
	if not f.item_used or not f.trainer_item in BERRIES:
		return
	if weather_now() != "sun" and not _roll(HARVEST_CHANCE):
		return
	f.item_used = false
	f.set_meta("ate_berry", false)
	_state(f).unburdened = false
	f.popup("Harvested a Berry!", Color(0.6, 1.0, 0.5), 0.9, 0.7)
	_fire(f, Color(0.6, 1.0, 0.5))
	var et = arena.get("end_turn")
	if et and et.has_method("held_check"):
		et.held_check(f)


## Healer: cura o status do aliado (e, sozinho em campo, o próprio com chance menor).
func _healer(f: BattleFighter) -> void:
	var p := partner_of(f)
	var who := p if p != null else f
	if who.status == "" or not who.status in Mon.PERSIST_STATUS + ["toxic", "freeze"]:
		return
	if not _roll(HEALER_CHANCE if p != null else HEALER_SELF):
		return
	who.clear_status()
	who.popup("Cured!", Color(0.6, 1.0, 0.7), 0.9)
	_fire(f, Color(0.6, 1.0, 0.7))


func _round_heal(f: BattleFighter, pct: float, why := "") -> void:
	if f.hp < f.max_hp:
		f.residual_heal(f.paced(maxi(1, int(float(f.max_hp) * pct))), why)
		_fire(f, Color(0.5, 1.0, 0.6))


func _sand_proof(f: BattleFighter, a: String) -> bool:
	if a in SANDPROOF:
		return true
	for t in f.types:
		if t in SANDPROOF_TYPES:
			return true
	return false


## Dano de clima: x0,6 como todo dano indireto (fighter.paced).
func _weather_chip(f: BattleFighter, pct: float, col: Color, why: String) -> void:
	f.residual_damage(f.paced(maxi(1, int(float(f.max_hp) * pct))), why, col)


# --- Troca ---


## Saiu de campo vivo (troca): Natural Cure cura o status, Regenerator cura 1/3 do HP (oficial).
func _switched_out(f: BattleFighter) -> void:
	BattleAbilitiesMore.switched_out(self, f)
	match ability_of(f):
		"natural_cure":
			if f.status != "" or f.mon.status != "":
				f.clear_status()
				_fire(f, Color(0.6, 1.0, 0.7))
		"regenerator":
			var m: Mon = f.mon
			if m.hp > 0 and m.hp < m.max_hp:
				m.hp = mini(m.max_hp, m.hp + f.paced(maxi(1, int(m.max_hp / 3.0))))
				f.hp = m.hp
				_fire(f, Color(0.5, 1.0, 0.6))


## Quem estava em campo e saiu vivo (arena._recall) foi trocado.
func _watch_switches() -> void:
	for id in _field.keys():
		var f = _field[id]
		if not is_instance_valid(f):
			_field.erase(id)
		elif not f.on_field:
			_field.erase(id)
			if f.hp > 0:
				_switched_out(f)
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			_field[f.get_instance_id()] = f


# --- Por frame ---


func tick(dt: float) -> void:
	_now += dt
	_watch_switches()
	if not _pending_enter.is_empty() and arena.state == "fight":
		var keep: Array = []
		last_entry_order = []
		for f in _by_speed(_pending_enter):
			if not is_instance_valid(f) or not f.active():
				continue
			if _entry(f):
				last_entry_order.append(f)
			else:
				keep.append(f)
		_pending_enter = keep
	_watch_gas()
	BattleAbilitiesMore.tick(self, dt)
	if weather_t > 0.0:
		weather_t -= dt
		if weather_t <= 0.0:
			weather = ""
			weather_t = 0.0
	for f in arena.fighters:
		if is_instance_valid(f) and f.active():
			_unnerve(f)
			_tick_fighter(f)


## Neutralizing Gas: quando o último gás sai de campo, as habilidades voltam e as de entrada agem de
## novo (Intimidate, clima...).
func _watch_gas() -> void:
	var gas := _gas_on()
	if _gas_prev and not gas:
		for f in arena.fighters:
			if is_instance_valid(f) and f.active() and ability_of(f) in ENTRY:
				if not f in _pending_enter:
					_pending_enter.append(f)
	_gas_prev = gas


## Unnerve: enquanto há um inimigo com Unnerve em campo, o item do treinador não é usado.
func _unnerve(f: BattleFighter) -> void:
	var s := _state(f)
	var held := false
	for t in arena.targets_of(f):
		if ability_of(t) == "unnerve":
			held = true
	if held and f.trainer_item != "" and not f.item_used:
		s.item = f.trainer_item
		f.trainer_item = ""
		for t in arena.targets_of(f):
			if ability_of(t) == "unnerve":
				_fire(t)
	elif not held and s.item != "":
		f.trainer_item = String(s.item)
		s.item = ""


## Efeitos contínuos (não são de fim de turno no oficial): estágios, esquiva, Magic Guard...
func _tick_fighter(f: BattleFighter) -> void:
	var a := ability_of(f)
	if a == "":
		return
	var s := _state(f)
	_watch_stages(f, a, s)
	if f.confusion_t > 0.0 and a == "tangled_feet" and f.evasion_t <= 0.0:
		f.evasion = 0.2
		f.evasion_t = 0.5
	match a:
		"unburden":
			if f.item_used and not s.unburdened:
				s.unburdened = true
				_fire(f)
		"sand_veil", "snow_cloak":
			if f.evasion_t <= 0.0 and weather_now() == ("sand" if a == "sand_veil" else "hail"):
				f.evasion = 0.2
				f.evasion_t = 0.5


## Quedas de atributo: Clear Body & cia. desfazem; Defiant/Competitive reagem.
func _watch_stages(f: BattleFighter, a: String, s: Dictionary) -> void:
	var prev: Dictionary = s.stages
	var dropped := false
	for k in STAGE_KEYS:
		var cur := int(f.stages.get(k, 0))
		var was := int(prev.get(k, 0))
		if cur < was:
			if blocks_stage_drop(f, k):
				f.stages[k] = was
				_fire(f)
			else:
				dropped = true
	if dropped and a in ["defiant", "competitive"]:
		var key := "atk" if a == "defiant" else "spa"
		_stage_up(f, key, 2)
		_fire(f, Color(1.0, 0.5, 0.4))
	s.stages = f.stages.duplicate()
