class_name BattleAbilitiesMore
extends RefCounted
## As 151 habilidades que faltavam para as 1025 espécies (Gen 3-9). Tudo estático, recebendo o
## BattleAbilities (`ab`) e sem referência de volta; battle_abilities.gd chama daqui pelos ganchos de
## sempre (_mults, immune, on_hit, adjust_damage, tick, late_residual, blocks_status...).
##   - estado por lutador: ab._state(f) (campos extras com get/[]); do jogo: ab.once_used.
##   - formas (Zen Mode, Schooling, Disguise...): sem arte nova; mudam stats/tipo, mostram popup e
##     tingem o sprite (meta "form_tint", lida por BattleFighter._tint) como o Transform faz com a espécie.
## Um turno do oficial = uma rodada (4 s): Slow Start, Truant, Moody, Cud Chew contam rodadas.

## Golpes por categoria (Bulletproof, Wind Rider, Sharpness, Mega Launcher, Dancer, Triage).
const BULLET_MOVES := [
	"acid_spray",
	"aura_sphere",
	"barrage",
	"beak_blast",
	"bullet_seed",
	"egg_bomb",
	"electro_ball",
	"energy_ball",
	"focus_blast",
	"gyro_ball",
	"ice_ball",
	"magnet_bomb",
	"mist_ball",
	"mud_bomb",
	"octazooka",
	"pollen_puff",
	"pyro_ball",
	"rock_blast",
	"rock_wrecker",
	"searing_shot",
	"seed_bomb",
	"shadow_ball",
	"sludge_bomb",
	"syrup_bomb",
	"weather_ball",
	"zap_cannon",
]
const WIND_MOVES := [
	"air_cutter",
	"bleakwind_storm",
	"blizzard",
	"fairy_wind",
	"gust",
	"heat_wave",
	"hurricane",
	"icy_wind",
	"petal_blizzard",
	"sandsear_storm",
	"springtide_storm",
	"twister",
	"whirlwind",
	"wildbolt_storm",
]
const SLICE_MOVES := [
	"aerial_ace",
	"air_cutter",
	"air_slash",
	"aqua_cutter",
	"behemoth_blade",
	"bitter_blade",
	"ceaseless_edge",
	"cross_poison",
	"cut",
	"fury_cutter",
	"kowtow_cleave",
	"leaf_blade",
	"mighty_cleave",
	"night_slash",
	"population_bomb",
	"psyblade",
	"psycho_cut",
	"razor_leaf",
	"razor_shell",
	"sacred_sword",
	"secret_sword",
	"slash",
	"solar_blade",
	"stone_axe",
	"tachyon_cutter",
	"x_scissor",
]
const PULSE_MOVES := [
	"aura_sphere",
	"dark_pulse",
	"dragon_pulse",
	"heal_pulse",
	"origin_pulse",
	"terrain_pulse",
	"water_pulse",
]
const DANCE_MOVES := [
	"swords_dance",
	"dragon_dance",
	"quiver_dance",
	"feather_dance",
	"petal_dance",
	"fiery_dance",
	"lunar_dance",
	"revelation_dance",
	"teeter_dance",
	"victory_dance",
	"aqua_step",
]
const HEAL_MOVES := [
	"recover",
	"soft_boiled",
	"roost",
	"moonlight",
	"morning_sun",
	"synthesis",
	"slack_off",
	"milk_drink",
	"heal_order",
	"shore_up",
	"life_dew",
	"jungle_healing",
	"floral_healing",
	"heal_pulse",
	"wish",
	"rest",
	"healing_wish",
	"lunar_dance",
	"strength_sap",
	"swallow",
]
## Golpes de estado que o Aroma Veil segura (a mente do aliado).
const AROMA_BLOCKED := ["taunt", "encore", "disable", "heal_block", "attract", "torment"]
## Golpes que o Normalize/-ate não mexem (o tipo vem de outra regra).
const KEEP_TYPE := [
	"hidden_power",
	"natural_gift",
	"weather_ball",
	"terrain_pulse",
	"judgment",
	"multi_attack",
	"techno_blast",
	"revelation_dance",
	"tera_blast",
	"aura_wheel",
	"struggle",
]
## Habilidades que nada copia, troca ou sobrescreve (Trace, Mummy, Wandering Spirit, Receiver...).
const NO_COPY := [
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
	"comatose",
	"commander",
	"zero_to_hero",
	"tera_shift",
	"protosynthesis",
	"quark_drive",
	"receiver",
	"power_construct",
]
const MAJOR := ["burn", "poison", "toxic", "paralysis", "sleep", "freeze"]
const BOOST_KEYS := ["atk", "def", "spa", "spd", "spe"]

## Números das habilidades.
const OFFENSE_TYPE := {
	"transistor": ["electric", 1.3],
	"dragons_maw": ["dragon", 1.5],
	"rocky_payload": ["rock", 1.5],
	"steelworker": ["steel", 1.5],
}
const SLICE_MULT := 1.5
const PULSE_MULT := 1.5
const PUNK_MULT := 1.3
const STATUS_BOOST := 1.5
const ATE_MULT := 1.3
const NORMALIZE_MULT := 1.2
const RUIN_MULT := 0.75
const AURA_MULT := 4.0 / 3.0
const AURA_BREAK_MULT := 0.75
const TEAM_MULT := 1.3
const STEEL_SPIRIT_MULT := 1.5
const FLOWER_GIFT_MULT := 1.5
const OVERLORD_STEP := 0.1
const OVERLORD_MAX := 5
const PARADOX_MULT := 1.3
const PARADOX_SPEED := 1.5
const ENGINE_MULT := 4.0 / 3.0
const STAKEOUT_WINDOW := 4.0
const STAKEOUT_MULT := 2.0
const FLUFFY_MULT := 0.5
const SLOW_START_ROUNDS := 5
const TOXIC_CHAIN_CHANCE := 0.3
const DEBRIS_GAP := 1.5
const GULP_DMG := 0.25
const DISGUISE_CHIP := 0.125
const IRON_BARBS_CHIP := 0.125
const BAD_DREAMS_CHIP := 0.125
const SWITCH_DELAY := 0.35
const DANCE_DELAY := 0.6
const HONEY_BASE := 0.05
const CHEEK_HEAL := 1.0 / 3.0
const EARTH_EATER_HEAL := 0.25
const HOSPITALITY_HEAL := 0.25
const COLORS := {
	"zen": Color(0.7, 0.8, 1.0),
	"form": Color(1.0, 0.85, 0.5),
	"bad": Color(0.55, 0.45, 0.75),
}

## Formas sem arte: multiplicadores de stat sobre a base da espécie, tom do sprite, tamanho e tipo extra.
const FORMS := {
	"zen":
	{
		"m": {"atk": 0.21, "def": 1.9, "spa": 4.7, "spd": 1.9, "spe": 0.58},
		"tint": Color(0.7, 0.8, 1.15),
		"type": "psychic",
		"text": "Modo Zen!",
	},
	"blade":
	{
		"m": {"atk": 2.8, "def": 0.36, "spa": 2.8, "spd": 0.36},
		"tint": Color(1.25, 0.85, 0.85),
		"text": "Forma Lâmina!",
	},
	"school":
	{
		"m": {"atk": 7.0, "def": 6.5, "spa": 5.6, "spd": 5.4, "spe": 0.75},
		"tint": Color(0.85, 0.95, 1.25),
		"scale": 1.6,
		"text": "Cardume!",
	},
	"core":
	{
		"m": {"atk": 1.67, "def": 0.6, "spa": 1.67, "spd": 0.6, "spe": 2.0},
		"tint": Color(1.3, 1.1, 0.8),
		"scale": 0.8,
		"text": "Forma Núcleo!",
	},
	"noice":
	{
		"m": {"def": 0.64, "spd": 0.56, "spe": 2.6},
		"tint": Color(0.85, 0.9, 1.1),
		"text": "Gelo quebrado!",
	},
	"busted": {"m": {}, "tint": Color(0.6, 0.55, 0.7), "text": "Disfarce rompido!"},
	"hero":
	{
		"m": {"atk": 2.29, "def": 1.35, "spa": 2.0, "spd": 1.4},
		"tint": Color(0.8, 1.1, 1.3),
		"scale": 1.2,
		"text": "Forma Herói!",
	},
	"terastal":
	{
		"m": {"atk": 1.46, "def": 1.29, "spa": 1.62, "spd": 1.29, "spe": 1.42},
		"tint": Color(1.2, 1.15, 1.3),
		"text": "Forma Terastal!",
	},
	"hangry": {"m": {}, "tint": Color(1.2, 0.8, 0.9), "text": "Faminto!"},
	"gulp_arrokuda": {"m": {}, "tint": Color(0.8, 1.15, 0.9), "text": "Engoliu uma presa!"},
	"gulp_pikachu": {"m": {}, "tint": Color(1.2, 1.2, 0.7), "text": "Engoliu uma presa!"},
}

## Castform: o clima muda o tipo e o tom.
const FORECAST := {
	"sun": ["fire", Color(1.25, 0.9, 0.7)],
	"rain": ["water", Color(0.8, 0.9, 1.25)],
	"hail": ["ice", Color(0.9, 1.1, 1.25)],
}

# --- Utilidades ---


static func _fx(ab: BattleAbilities) -> BattleMoveEffects:
	return ab.arena.moves.effects


static func _s(ab: BattleAbilities, f: BattleFighter) -> Dictionary:
	return ab._state(f)


## Alguém em campo além de `who` com a habilidade `a`.
static func other_has(ab: BattleAbilities, who: BattleFighter, a: String) -> bool:
	for g in ab.arena.fighters:
		if g != who and is_instance_valid(g) and g.active() and ab.ability_of(g) == a:
			return true
	return false


## Alguém em campo (qualquer um, inclusive `who`) com a habilidade `a`.
static func any_has(ab: BattleAbilities, a: String) -> bool:
	return ab._on_field(a) != null


## O lutador ou o parceiro dele tem a habilidade `a`.
static func team_has(ab: BattleAbilities, f: BattleFighter, a: String) -> bool:
	if ab.ability_of(f) == a:
		return true
	var p := ab.partner_of(f)
	return p != null and ab.ability_of(p) == a


static func _is_heal(mv: Dictionary) -> bool:
	return String(mv.get("id", "")) in HEAL_MOVES or mv.has("drain")


## Golpes que mudam de tipo por conta própria ficam de fora do Normalize e dos -ate.
static func _keeps_type(mv: Dictionary) -> bool:
	return String(mv.get("id", "")) in KEEP_TYPE or String(mv.get("special", "")) in KEEP_TYPE


## Prioridade efetiva do golpe (a do golpe mais o bônus de Prankster, Gale Wings, Triage).
static func _priority(ab: BattleAbilities, user: BattleFighter, mv: Dictionary) -> int:
	return int(mv.get("priority", 0)) + ab.priority_bonus(user, mv)


## Estágios não baixam de -6 nem sobem de 6: o maior stat bruto (com estágios) entre atk/def/spa/spd/spe.
static func best_stat(f: BattleFighter) -> String:
	var best := "atk"
	var top := -1.0
	for k in BOOST_KEYS:
		var v := float(f.stats.get(k, 0)) * StatCalc.stage_mult(int(f.stages.get(k, 0)))
		if v > top:
			top = v
			best = k
	return best


## Protosynthesis (sol) e Quark Drive (campo elétrico): o stat que está valendo mais ("" = desligado).
static func boosted(ab: BattleAbilities, f: BattleFighter) -> String:
	var a := ab.ability_of(f)
	if a == "protosynthesis":
		if ab.weather_now() != "sun":
			return ""
	elif a == "quark_drive":
		var fx := _fx(ab)
		if not fx.active(fx.field, "electric"):
			return ""
	else:
		return ""
	return best_stat(f)


## Companheiros de equipe caídos (Supreme Overlord): do banco do próprio lado.
static func fallen(ab: BattleAbilities, f: BattleFighter) -> int:
	var list = ab.arena.get("party") if f.side == 0 else ab.arena.get("enemies")
	if not list is Array:
		return 0
	var n := 0
	for m in list:
		if m is Mon and m != f.mon and m.is_fainted():
			n += 1
	return mini(n, OVERLORD_MAX)


# --- Formas (sem arte nova) ---


static func form_of(f: BattleFighter) -> String:
	return String(f.get_meta("form", "")) if is_instance_valid(f) else ""


## Tira a forma e devolve stats e tipos como eram.
static func restore_form(f: BattleFighter) -> void:
	if f.has_meta("form_orig"):
		var o: Dictionary = f.get_meta("form_orig")
		for k in o.stats:
			f.stats[k] = o.stats[k]
		f.types = (o.types as Array).duplicate()
		f.remove_meta("form_orig")
	f.remove_meta("form")
	f.remove_meta("form_tint")
	if f.look:
		f.look.scale_mult = 1.0


## Põe a forma `key` ("" = a base): stats multiplicados, tipo extra, tom e tamanho do sprite.
static func set_form(f: BattleFighter, key: String, say := true) -> void:
	if not is_instance_valid(f) or BattleTransform.is_transformed(f) or form_of(f) == key:
		return
	restore_form(f)
	if key == "":
		return
	var d: Dictionary = FORMS[key]
	f.set_meta("form", key)
	f.set_meta("form_orig", {"stats": f.stats.duplicate(), "types": f.types.duplicate()})
	var m: Dictionary = d.m
	for k in m:
		f.stats[k] = maxi(1, int(round(float(f.stats.get(k, 10)) * float(m[k]))))
	var ty := String(d.get("type", ""))
	if ty != "" and not ty in f.types:
		f.types = f.types + [ty]
	f.set_meta("form_tint", d.tint)
	if f.look:
		f.look.scale_mult = float(d.get("scale", 1.0))
	if say:
		f.popup(String(d.text), Color(d.tint).lightened(0.2), 1.0, 0.8)


# --- Multiplicadores de dano ---


## Fatores de cada lado ({user, target}) das habilidades novas. ua/ta já passaram pelo Mold Breaker.
static func mults(
	ab: BattleAbilities,
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	ua: String,
	ta: String,
	wx: String
) -> Dictionary:
	var um := 1.0
	var tm := 1.0
	var power := float(mv.get("power", 0))
	if power <= 0.0:
		return {"user": um, "target": tm}
	var type := String(mv.get("type", "normal"))
	var cat := String(mv.get("category", ""))
	var id := String(mv.get("id", ""))
	var phys := cat == "physical"
	var spec := cat == "special"
	var fx := _fx(ab)
	if OFFENSE_TYPE.has(ua) and type == String(OFFENSE_TYPE[ua][0]):
		um *= float(OFFENSE_TYPE[ua][1])
	match ua:
		"sharpness":
			if id in SLICE_MOVES:
				um *= SLICE_MULT
		"mega_launcher":
			if id in PULSE_MOVES:
				um *= PULSE_MULT
		"punk_rock":
			if ab._is_sound(mv):
				um *= PUNK_MULT
		"toxic_boost":
			if phys and user.status in ["poison", "toxic"]:
				um *= STATUS_BOOST
		"flare_boost":
			if spec and user.status == "burn":
				um *= STATUS_BOOST
		"defeatist":
			if user.hp * 2 <= user.max_hp:
				um *= 0.5
		"slow_start":
			if phys and slow_start_on(ab, user):
				um *= 0.5
		"supreme_overlord":
			um *= 1.0 + OVERLORD_STEP * float(fallen(ab, user))
		"stakeout":
			if now_since_entry(ab, target) <= STAKEOUT_WINDOW:
				um *= STAKEOUT_MULT
		"normalize":
			um *= NORMALIZE_MULT
		"pixilate", "refrigerate":
			um *= float(mv.get("ate", 1.0))
		"water_bubble":
			if type == "water":
				um *= 2.0
		"orichalcum_pulse":
			if phys and wx == "sun":
				um *= ENGINE_MULT
		"hadron_engine":
			if spec and fx.active(fx.field, "electric"):
				um *= ENGINE_MULT
		"protosynthesis", "quark_drive":
			var bk := boosted(ab, user)
			if (bk == "atk" and phys) or (bk == "spa" and spec):
				um *= PARADOX_MULT
	# Ruin: quem não tem a habilidade perde 25% do stat (ou entrega 33% a mais de dano).
	if phys and other_has(ab, user, "tablets_of_ruin"):
		um *= RUIN_MULT
	if spec and other_has(ab, user, "vessel_of_ruin"):
		um *= RUIN_MULT
	if phys and other_has(ab, target, "sword_of_ruin"):
		tm /= RUIN_MULT
	if spec and other_has(ab, target, "beads_of_ruin"):
		tm /= RUIN_MULT
	# Time: o parceiro (ou o próprio) ajuda.
	var pu := ab.partner_of(user)
	if pu != null:
		var pa := ab.ability_of(pu)
		if pa == "battery" and spec:
			um *= TEAM_MULT
		elif pa == "power_spot":
			um *= TEAM_MULT
	if type == "steel" and team_has(ab, user, "steely_spirit"):
		um *= STEEL_SPIRIT_MULT
	if wx == "sun":
		if phys and team_has(ab, user, "flower_gift"):
			um *= FLOWER_GIFT_MULT
		if spec and team_has(ab, target, "flower_gift"):
			tm /= FLOWER_GIFT_MULT
	# Auras: valem para todos em campo.
	if type == "fairy" and any_has(ab, "fairy_aura"):
		um *= AURA_BREAK_MULT if any_has(ab, "aura_break") else AURA_MULT
	if type == "dark" and any_has(ab, "dark_aura"):
		um *= AURA_BREAK_MULT if any_has(ab, "aura_break") else AURA_MULT
	# Quem apanha.
	match ta:
		"fluffy":
			if ab._is_contact(mv) and ua != "long_reach":
				tm *= FLUFFY_MULT
			if type == "fire":
				tm *= 2.0
		"fur_coat":
			if phys:
				tm *= 0.5
		"ice_scales":
			if spec:
				tm *= 0.5
		"heatproof", "water_bubble":
			if type == "fire":
				tm *= 0.5
		"purifying_salt":
			if type == "ghost":
				tm *= 0.5
		"punk_rock":
			if ab._is_sound(mv):
				tm *= 0.5
		"grass_pelt":
			if phys and fx.active(fx.field, "grassy"):
				tm /= 1.5
		"shadow_shield":
			if target.hp >= target.max_hp:
				tm *= 0.5
		"filter", "solid_rock", "prism_armor":
			pass  # na tabela de battle_abilities
		"protosynthesis", "quark_drive":
			var tk := boosted(ab, target)
			if (tk == "def" and phys) or (tk == "spd" and spec):
				tm /= PARADOX_MULT
	return {"user": um, "target": tm}


static func now_since_entry(ab: BattleAbilities, f: BattleFighter) -> float:
	var fx := _fx(ab)
	return fx.now - float(fx.st(f).entered)


static func slow_start_on(ab: BattleAbilities, f: BattleFighter) -> bool:
	return ab.rounds - int(_s(ab, f).enter_round) < SLOW_START_ROUNDS


# --- Golpe: tipo, bloqueio e uso ---


## O golpe como este lutador o solta: Normalize, Pixilate, Refrigerate, Liquid Voice, Judgment,
## Multi-Attack e Aura Wheel mudam o tipo (e o poder, nos -ate).
static func move_for(ab: BattleAbilities, user: BattleFighter, mv: Dictionary) -> Dictionary:
	var a := ab.ability_of(user)
	if a == "":
		return mv
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	var ty := type
	var boost := 1.0
	match a:
		"normalize":
			if not _keeps_type(mv):
				ty = "normal"
		"pixilate", "refrigerate":
			if type == "normal" and float(mv.get("power", 0)) > 0.0 and not _keeps_type(mv):
				ty = "fairy" if a == "pixilate" else "ice"
				boost = ATE_MULT
		"liquid_voice":
			if ab._is_sound(mv):
				ty = "water"
		"multitype":
			if id == "judgment" and not user.types.is_empty():
				ty = String(user.types[0])
		"rks_system":
			if id == "multi_attack" and not user.types.is_empty():
				ty = String(user.types[0])
		"hunger_switch":
			if id == "aura_wheel" and form_of(user) == "hangry":
				ty = "dark"
	if ty == type and boost == 1.0:
		return mv
	var out := mv.duplicate()
	out["type"] = ty
	if boost != 1.0:
		out["ate"] = boost
	return out


## Golpe que não pode sair agora (texto do motivo, "" = pode): Truant folgando, Tatsugiri na boca.
static func move_blocked(ab: BattleAbilities, user: BattleFighter, _mv: Dictionary) -> String:
	var a := ab.ability_of(user)
	if a == "truant" and int(_s(ab, user).get("loaf", 0)) == 2:
		return "Está vadiando..."
	if a == "commander" and user.hidden == "commander":
		return "Está na boca do Dondozo!"
	return ""


## Registra o golpe usado: Protean/Libero, Stance Change, Gulp Missile, Truant, Dancer.
static func on_move_used(ab: BattleAbilities, user: BattleFighter, mv: Dictionary) -> void:
	var a := ab.ability_of(user)
	var s := _s(ab, user)
	var id := String(mv.get("id", ""))
	var type := String(mv.get("type", ""))
	var damaging := String(mv.get("category", "status")) != "status"
	match a:
		"protean", "libero":
			if (
				not bool(s.get("protean", false))
				and type != ""
				and not (user.types.size() == 1 and user.types[0] == type)
			):
				s["protean"] = true  # uma vez por entrada em campo (Gen 9)
				user.types = [type]
				user.popup("Tipo %s!" % type.to_upper(), Dex.type_color(type), 0.9, 0.7)
				ab._fire(user, Dex.type_color(type))
		"stance_change":
			if damaging:
				_stance(ab, user, "blade")
			elif id in ["kings_shield", "king_s_shield"]:
				_stance(ab, user, "")
		"gulp_missile":
			if id in ["surf", "dive"] and String(s.get("gulp", "")) == "":
				s["gulp"] = "arrokuda" if user.hp * 2 > user.max_hp else "pikachu"
				set_form(user, "gulp_" + String(s.gulp))
				ab._fire(user)
		"truant":
			if int(s.get("loaf", 0)) == 0:
				s["loaf"] = 1
	if id in DANCE_MOVES and not ab.dancing:
		_dancers(ab, user, mv)


static func _stance(ab: BattleAbilities, f: BattleFighter, to: String) -> void:
	if form_of(f) != to:
		set_form(f, to)
		ab._fire(f, Color(1.0, 0.75, 0.75))


## Dancer: quem tem a habilidade repete o passo logo depois (sem gastar energia).
static func _dancers(ab: BattleAbilities, user: BattleFighter, mv: Dictionary) -> void:
	for g in ab.arena.fighters:
		if g == user or not is_instance_valid(g) or not g.active() or ab.ability_of(g) != "dancer":
			continue
		ab.arena.later(DANCE_DELAY, func() -> void: _dance(ab, g, mv))


static func _dance(ab: BattleAbilities, g: BattleFighter, mv: Dictionary) -> void:
	if not is_instance_valid(g) or not g.active() or not g.can_act() or g.hidden != "":
		return
	ab.dancing = true
	ab._fire(g, Color(1.0, 0.7, 0.9))
	var m: Dictionary = ab.arena.moves.effects.move_for(g, mv)
	ab.arena.moves.effects.on_use(g, m)
	ab.arena.on_move_used(g, m)
	ab.arena.moves.deliver(g, m)
	ab.dancing = false


# --- Imunidade e bloqueios ---


## Imunidade a golpe de dano (ta já passou pelo Mold Breaker). true = não acerta.
static func immune(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, mv: Dictionary, ta: String
) -> bool:
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	var power := float(mv.get("power", 0))
	var foe := user.side != target.side
	match ta:
		"bulletproof":
			if id in BULLET_MOVES:
				ab._fire(target)
				return true
		"wind_rider":
			if id in WIND_MOVES:
				ab._stage_up(target, "atk", 1)
				ab._fire(target)
				return true
		"earth_eater":
			if type == "ground":
				ab._heal_pct(target, EARTH_EATER_HEAL)
				ab._fire(target, Dex.type_color("ground"))
				return true
		"well_baked_body":
			if type == "fire":
				ab._stage_up(target, "def", 2)
				ab._fire(target, Dex.type_color("fire"))
				return true
		"wonder_guard":
			if (
				foe
				and power > 0.0
				and Dex.effectiveness(type, ab.hit_types(user, target, mv, target.types)) <= 1.0
			):
				target.popup("Guarda-Maravilha!", Color(0.8, 0.9, 1.0), 1.0, 0.8)
				ab._fire(target, Color(0.8, 0.9, 1.0))
				return true
	return false


## Golpe de estado ou prioridade parado pela habilidade (BattleMoveEffects.blocks_hit chama para
## golpes de outro lado). true = parou.
static func blocks_hit(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> bool:
	var ta := ab._tab(user, target, mv)
	var status := float(mv.get("power", 0)) <= 0.0 and String(mv.get("category", "")) == "status"
	var id := String(mv.get("id", ""))
	if status:
		match ta:
			"good_as_gold":
				target.popup("Bom como ouro!", Color(1.0, 0.9, 0.5), 1.0, 0.8)
				ab._fire(target, Color(1.0, 0.9, 0.5))
				return true
			"wind_rider":
				if id in WIND_MOVES:
					ab._stage_up(target, "atk", 1)
					ab._fire(target)
					return true
			"magic_bounce":
				if not ab.bouncing and not bool(mv.get("bounced", false)):
					ab._fire(target, Color(0.85, 0.7, 1.0))
					target.popup("Rebateu!", Color(0.85, 0.7, 1.0), 1.1)
					ab.bouncing = true
					BattleKanto._reflect(_fx(ab), user, target, mv)
					ab.bouncing = false
					return true
		if _aroma(ab, user, target, mv):
			return true
	if _priority(ab, user, mv) > 0:
		for g in [target, ab.partner_of(target)]:
			if g == null or not is_instance_valid(g):
				continue
			var ga := ab.ability_of(g)
			if (
				ga in ["queenly_majesty", "dazzling", "armor_tail"]
				and not (ab._breaker(user) and not ga in BattleAbilities.UNBREAKABLE)
			):
				target.popup("Prioridade barrada!", Color(1.0, 0.8, 0.9), 1.0, 0.8)
				ab._fire(g, Color(1.0, 0.8, 0.9))
				return true
	return false


## Aroma Veil: o time não leva golpe que mexe com a cabeça (Taunt, Encore, Attract...).
static func _aroma(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> bool:
	var id := String(mv.get("id", ""))
	var sp := String(mv.get("special", ""))
	if not (id in AROMA_BLOCKED or sp in AROMA_BLOCKED):
		return false
	if ab._breaker(user) or not team_has(ab, target, "aroma_veil"):
		return false
	target.popup("Aroma protege!", Color(1.0, 0.8, 0.9), 1.0, 0.8)
	return true


## Proteção de status extra: Purifying Salt, Comatose, Shields Down (meteoro), e o time (Sweet Veil,
## Flower Veil, Aroma Veil). `src` = quem causou (Mold Breaker passa por cima das de time).
static func blocks_status(
	ab: BattleAbilities, f: BattleFighter, status: String, src: BattleFighter
) -> bool:
	var a := ab.ability_of(f)
	var major := status in MAJOR
	if (
		major
		and (a in ["purifying_salt", "comatose"] or (a == "shields_down" and form_of(f) != "core"))
	):
		ab._fire(f)
		return true
	if src != null and is_instance_valid(src) and ab._breaker(src):
		return false
	for g in [f, ab.partner_of(f)]:
		if g == null or not is_instance_valid(g):
			continue
		match ab.ability_of(g):
			"sweet_veil":
				if status == "sleep":
					ab._fire(g)
					return true
			"flower_veil":
				if major and "grass" in f.types:
					ab._fire(g)
					return true
			"aroma_veil":
				if status == "confusion":
					ab._fire(g)
					return true
	return false


## Flower Veil: os Grama do time não perdem atributo para o inimigo.
static func keeps_stat(
	ab: BattleAbilities, f: BattleFighter, _k: String, src: BattleFighter
) -> bool:
	if src != null and is_instance_valid(src) and src.side == f.side:
		return false
	if not "grass" in f.types:
		return false
	return team_has(ab, f, "flower_veil")


## Poison Puppeteer: veneno de quem tem a habilidade também confunde. Corrosion/Merciless não entram.
static func on_status(
	ab: BattleAbilities, f: BattleFighter, status: String, src: BattleFighter
) -> void:
	if (
		src != null
		and is_instance_valid(src)
		and src.side != f.side
		and status in ["poison", "toxic"]
		and ab.ability_of(src) == "poison_puppeteer"
		and f.alive()
	):
		if f.apply_status("confusion", src):
			f.popup("Confuso!", Dex.type_color("psychic"), 0.9, 0.7)
			ab._fire(src, Dex.type_color("poison"))


## Corrosion: veneno pega em Veneno e Aço.
static func corrodes(ab: BattleAbilities, user: BattleFighter, status: String) -> bool:
	return (
		ab != null
		and is_instance_valid(user)
		and status in ["poison", "toxic"]
		and ab.ability_of(user) == "corrosion"
	)


# --- Dano: antes e depois do acerto ---


## Antes de tirar o HP: guarda o HP de antes (Berserk, Innards Out) e segura o golpe (Disguise, Ice Face).
static func adjust(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, mv: Dictionary, dmg: int
) -> int:
	var s := _s(ab, target)
	s["hp_pre"] = target.hp
	if user.side == target.side or float(mv.get("power", 0)) <= 0.0:
		return dmg
	match ab.ability_of(target):
		"disguise":
			if form_of(target) != "busted" and not bool(s.get("busted", false)):
				s["busted"] = true
				set_form(target, "busted")
				ab._fire(target, Color(0.75, 0.65, 0.9))
				var chip := maxi(1, int(target.max_hp * DISGUISE_CHIP))
				if ab.ability_of(user) != "magic_guard":
					target.popup("-%d" % chip, Color(0.8, 0.7, 0.9), 0.8)
					target.take_damage(mini(chip, target.hp - 1), Vector3.ZERO, 0.0)
				return 0
		"ice_face":
			if String(mv.get("category", "")) == "physical" and form_of(target) != "noice":
				set_form(target, "noice")
				s["ice_t"] = ab._now
				ab._fire(target, Color(0.8, 0.9, 1.0))
				return 0
	return dmg


## Depois do acerto (o alvo levou o golpe de dano de outro lado): contato, gatilhos de tipo, limiares de HP.
static func on_hit(
	ab: BattleAbilities,
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	_dmg: int,
	_crit: bool,
	contact: bool
) -> void:
	var power := float(mv.get("power", 0))
	if power <= 0.0 or user.side == target.side:
		return
	var ua := ab.ability_of(user)
	var ta := ab.ability_of(target)
	var type := String(mv.get("type", ""))
	var id := String(mv.get("id", ""))
	var phys := String(mv.get("category", "")) == "physical"
	var s := _s(ab, target)
	# Quem bate.
	if target.alive() and user.alive():
		match ua:
			"magician":
				_steal(ab, user, target, user)
			"toxic_chain":
				if ab._roll(TOXIC_CHAIN_CHANCE):
					_poison(ab, user, target, "toxic")
	if ta == "wind_power" and id in WIND_MOVES:
		_charge(ab, target)
	if ta == "electromorphosis" and target.alive():
		_charge(ab, target)
	# Quem apanha, vivo.
	if target.alive():
		_victim(ab, user, target, mv, ua, ta, type, phys, contact, s)
		_threshold(ab, target, ta, s)
	# Desmaiou: Innards Out cobra o HP que restava.
	if target.hp <= 0 and ta == "innards_out" and user.alive() and ua != "magic_guard":
		var left := int(s.get("hp_pre", 0))
		if left > 0:
			ab._fire(target, Color(0.9, 0.4, 0.4))
			user.popup("-%d" % left, Color(0.9, 0.5, 0.5), 0.9)
			user.take_damage(left, Vector3.ZERO, 0.0)


static func _victim(
	ab: BattleAbilities,
	user: BattleFighter,
	target: BattleFighter,
	mv: Dictionary,
	ua: String,
	ta: String,
	type: String,
	phys: bool,
	contact: bool,
	s: Dictionary
) -> void:
	var fx := _fx(ab)
	if contact and user.alive():
		match ta:
			"pickpocket":
				_steal(ab, target, user, target)
			"gooey":
				ab._fire(target, Color(0.9, 0.8, 0.4))
				ab.arena.moves.change_stage(user, "spe", -1, target)
			"mummy", "lingering_aroma":
				_overwrite(ab, user, target, ta)
			"wandering_spirit":
				_swap(ab, user, target)
			"iron_barbs":
				if ua != "magic_guard":
					var chip := maxi(1, int(user.max_hp * IRON_BARBS_CHIP))
					ab._fire(target)
					user.popup("-%d" % chip, Color(0.7, 0.7, 0.8), 0.8)
					user.take_damage(chip, Vector3.ZERO, 0.0)
			"perish_body":
				_perish(ab, user, target)
	match ta:
		"stamina":
			ab._stage_up(target, "def", 1)
			ab._fire(target)
		"water_compaction":
			if type == "water":
				ab._stage_up(target, "def", 2)
				ab._fire(target, Dex.type_color("water"))
		"steam_engine":
			if type in ["fire", "water"]:
				ab._stage_up(target, "spe", 6)
				ab._fire(target, Color(0.9, 0.9, 0.95))
		"thermal_exchange":
			if type == "fire":
				ab._stage_up(target, "atk", 1)
				ab._fire(target, Dex.type_color("fire"))
		"sand_spit":
			if ab.set_weather_rounds("sand", ab.weather_rounds_for(target, "sand")):
				ab._fire(target, BattleAbilities.WEATHER_COLORS.sand)
		"seed_sower":
			if not fx.active(fx.field, "grassy"):
				fx._set_terrain("grassy", target, "Campo de grama!", "grass")
				ab._fire(target, Dex.type_color("grass"))
		"cotton_down":
			ab._fire(target, Color(1.0, 1.0, 1.0))
			for g in ab.arena.fighters:
				if g != target and is_instance_valid(g) and g.active():
					ab.arena.moves.change_stage(g, "spe", -1, target)
		"toxic_debris":
			if phys and ab._now - float(s.get("debris_t", -99.0)) >= DEBRIS_GAP:
				s["debris_t"] = ab._now
				ab._fire(target, Dex.type_color("poison"))
				fx._lay_toxic_spikes(target)
		"color_change":
			if type != "" and not (target.types.size() == 1 and target.types[0] == type):
				target.types = [type]
				target.popup("Tipo %s!" % type.to_upper(), Dex.type_color(type), 0.9, 0.7)
				ab._fire(target, Dex.type_color(type))
		"gulp_missile":
			_spit(ab, user, target, s)
		"illusion":
			_unveil(ab, target)


## Limiares de HP ao cruzar a metade com este golpe: Berserk, Anger Shell, Wimp Out, Emergency Exit.
static func _threshold(ab: BattleAbilities, f: BattleFighter, a: String, s: Dictionary) -> void:
	var pre := int(s.get("hp_pre", f.max_hp))
	if not (pre * 2 > f.max_hp and f.hp * 2 <= f.max_hp):
		return
	match a:
		"berserk":
			ab._stage_up(f, "spa", 1)
			ab._fire(f, Color(1.0, 0.5, 0.5))
		"anger_shell":
			ab._fire(f, Color(1.0, 0.4, 0.3))
			ab.arena.moves.change_stage(f, "def", -1)
			ab.arena.moves.change_stage(f, "spd", -1)
			for k in ["atk", "spa", "spe"]:
				ab._stage_up(f, k, 1)
		"wimp_out", "emergency_exit":
			_eject(ab, f)


## Wimp Out / Emergency Exit: ao cair da metade do HP foge para o banco (só no modo de energia).
static func _eject(ab: BattleAbilities, f: BattleFighter) -> void:
	if not ab.arena.energy_on() or not _fx(ab).has_reserve(f):
		return
	ab._fire(f, Color(0.8, 0.9, 1.0))
	f.popup("Fugiu!", Color(0.8, 0.9, 1.0), 1.0, 0.8)
	ab.arena.later(
		SWITCH_DELAY,
		func() -> void:
			if is_instance_valid(f) and f.active():
				ab.arena.switch_out(f)
	)


## Gulp Missile: a presa engolida volta contra quem bate (1/4 do HP dele e Def -1 ou paralisia).
static func _spit(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, s: Dictionary
) -> void:
	var prey := String(s.get("gulp", ""))
	if prey == "":
		return
	s["gulp"] = ""
	set_form(target, "")
	ab._fire(target, Color(1.0, 0.9, 0.5))
	if user.alive() and ab.ability_of(user) != "magic_guard":
		var n := maxi(1, int(user.max_hp * GULP_DMG))
		user.popup("-%d" % n, Color(1.0, 0.8, 0.5), 0.9)
		user.take_damage(n, Vector3.ZERO, 0.0)
	if user.alive():
		if prey == "arrokuda":
			ab.arena.moves.change_stage(user, "def", -1, target)
		elif (
			not BattleMoves.STATUS_IMMUNE.get("paralysis", "-") in user.types
			and not ab.blocks_status(user, "paralysis", target)
			and user.apply_status("paralysis", target)
		):
			user.popup("PARALISADO!", Color(1, 0.9, 0.6))


static func _charge(ab: BattleAbilities, f: BattleFighter) -> void:
	var fx := _fx(ab)
	var st := fx.st(f)
	if not fx.active(st, "charged"):
		st.charged = fx.now + BattleMoveEffects.FOREVER
		f.popup("Carregado!", Dex.type_color("electric"))
		ab._fire(f, Dex.type_color("electric"))


static func _poison(
	ab: BattleAbilities, src: BattleFighter, victim: BattleFighter, st: String
) -> void:
	var immune_type: bool = "poison" in victim.types or "steel" in victim.types
	if (
		(not immune_type or corrodes(ab, src, st))
		and not ab.blocks_status(victim, st, src)
		and victim.apply_status(st, src)
	):
		ab._fire(src, Dex.type_color("poison"))
		victim.popup(
			String(BattleMoves.STATUS_WORDS.get(st, st.to_upper() + "!")), Color(1, 0.9, 0.6)
		)


## Pickpocket/Magician: `thief` leva o item de `victim` (só com a mão vazia). `who` mostra a habilidade.
static func _steal(
	ab: BattleAbilities, thief: BattleFighter, victim: BattleFighter, who: BattleFighter
) -> void:
	if ab.ability_of(victim) == "sticky_hold" or victim.trainer_item == "" or victim.item_used:
		return
	if thief.trainer_item != "" or not thief.alive():
		return
	_fx(ab)._steal_item(thief, victim)
	ab._fire(who, Color(0.9, 0.8, 0.5))


## Mummy / Lingering Aroma: quem encosta passa a ter a habilidade do alvo.
static func _overwrite(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, a: String
) -> void:
	var ua := ab.ability_of(user)
	if ua == a or ua in NO_COPY or ua == "":
		return
	user.set_meta("ability_override", a)
	user.popup(String(Dex.ability(a).get("name", a.to_upper())), Color(0.85, 0.75, 0.55), 0.9, 0.7)
	ab._fire(target, Color(0.85, 0.75, 0.55))


## Wandering Spirit: os dois trocam de habilidade no contato.
static func _swap(ab: BattleAbilities, user: BattleFighter, target: BattleFighter) -> void:
	var ua := ab.ability_of(user)
	if ua == "" or ua in NO_COPY or ua == "wandering_spirit":
		return
	target.set_meta("ability_override", ua)
	user.set_meta("ability_override", "wandering_spirit")
	user.popup("Trocou de habilidade!", Color(0.8, 0.8, 1.0), 0.9, 0.7)
	ab._fire(target, Color(0.8, 0.8, 1.0))


## Perish Body: no contato, os dois começam a Canção da Morte (3 rodadas), se ainda não.
static func _perish(ab: BattleAbilities, user: BattleFighter, target: BattleFighter) -> void:
	var fx := _fx(ab)
	var any := false
	for f in [user, target]:
		var fs := fx.st(f)
		if not fx.active(fs, "perish"):
			fx.set_rounds(fs, "perish", BattleKanto.PERISH_TURNS)
			f.popup(
				"Canção da morte: %d" % BattleKanto.PERISH_TURNS, BattleKanto.PERISH_COL, 1.0, 0.7
			)
			any = true
	if any:
		ab._fire(target, BattleKanto.PERISH_COL)


## Ilusão desfeita: o Zoroark mostra a cara de verdade ao levar um golpe.
static func _unveil(ab: BattleAbilities, f: BattleFighter) -> void:
	var s := _s(ab, f)
	if String(s.get("illusion", "")) == "":
		return
	s["illusion"] = ""
	if f.look:
		f.look.species = f.mon.species
	f.popup("Ilusão desfeita!", Color(0.9, 0.7, 0.95), 1.0, 0.8)
	ab._fire(f, Color(0.9, 0.7, 0.95))


## O alvo desmaiou por este golpe: Beast Boost, Chilling/Grim Neigh.
static func on_ko(ab: BattleAbilities, user: BattleFighter) -> void:
	match ab.ability_of(user):
		"beast_boost":
			ab._stage_up(user, best_stat(user), 1)
			ab._fire(user, Color(0.8, 0.5, 1.0))
		"chilling_neigh":
			ab._stage_up(user, "atk", 1)
			ab._fire(user, Color(0.7, 0.9, 1.0))
		"grim_neigh":
			ab._stage_up(user, "spa", 1)
			ab._fire(user, Color(0.6, 0.4, 0.8))


## Merciless: crítico garantido em quem está envenenado.
static func crit_tweak(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, p: Dictionary
) -> void:
	if ab.ability_of(user) == "merciless" and target.status in ["poison", "toxic"]:
		p["crit_stage"] = 3


# --- Velocidade ---


## Fatores de Speed (ordem da rodada, andar, preparo do golpe) de Slow Start, Stall e dos paradoxos.
static func speed(ab: BattleAbilities, f: BattleFighter) -> Dictionary:
	match ab.ability_of(f):
		"slow_start":
			if slow_start_on(ab, f):
				return {"order": 0.5, "walk": 0.75, "cast": 0.75}
		"stall":
			return {"order": 0.01, "walk": 1.0, "cast": 0.75}
		"protosynthesis", "quark_drive":
			if boosted(ab, f) == "spe":
				return {"order": PARADOX_SPEED, "walk": 1.3, "cast": 1.3}
	return {"order": 1.0, "walk": 1.0, "cast": 1.0}


## Prioridade extra: Triage dá +3 aos golpes que curam.
static func priority_bonus(ab: BattleAbilities, f: BattleFighter, mv: Dictionary) -> int:
	if ab.ability_of(f) == "triage" and _is_heal(mv):
		return 3
	return 0


## Preparo do golpe: Triage acelera os de cura, Mycelium Might atrasa os de estado.
static func cast_mult(ab: BattleAbilities, f: BattleFighter, mv: Dictionary) -> float:
	match ab.ability_of(f):
		"triage":
			if _is_heal(mv):
				return 1.5
		"mycelium_might":
			if String(mv.get("category", "")) == "status":
				return 0.7
	return 1.0


## Precisão extra do time (Victory Star: x1,1 para o dono e o parceiro).
static func acc_bonus(ab: BattleAbilities, f: BattleFighter) -> float:
	return 1.1 if team_has(ab, f, "victory_star") else 1.0


# --- Entrada em campo ---


static func _terrain(ab: BattleAbilities, f: BattleFighter, kind: String) -> void:
	var fx := _fx(ab)
	var type := String(
		{"grassy": "grass", "electric": "electric", "misty": "fairy", "psychic": "psychic"}[kind]
	)
	if not fx.active(fx.field, kind):
		fx._set_terrain(
			kind,
			f,
			String(
				{
					"grassy": "Campo de grama!",
					"electric": "Campo elétrico!",
					"misty": "Campo de névoa!",
					"psychic": "Campo psíquico!"
				}[kind]
			),
			type
		)
	ab._fire(f, Dex.type_color(type))


static func _once(ab: BattleAbilities, f: BattleFighter, key: String) -> bool:
	var k := "%d:%s" % [f.mon.get_instance_id(), key]
	if ab.once_used.has(k):
		return false
	ab.once_used[k] = true
	return true


## Ativação ao entrar. false = ainda não dá (tenta no próximo frame).
static func entry(ab: BattleAbilities, f: BattleFighter) -> bool:
	var a := ab.ability_of(f)
	var fx := _fx(ab)
	match a:
		"grassy_surge":
			_terrain(ab, f, "grassy")
		"electric_surge":
			_terrain(ab, f, "electric")
		"misty_surge":
			_terrain(ab, f, "misty")
		"psychic_surge":
			_terrain(ab, f, "psychic")
		"hadron_engine":
			_terrain(ab, f, "electric")
		"orichalcum_pulse":
			ab.set_weather_rounds("sun", ab.weather_rounds_for(f, "sun"))
			ab._fire(f, BattleAbilities.WEATHER_COLORS.sun)
		"intrepid_sword", "dauntless_shield":
			if _once(ab, f, a):
				ab._stage_up(f, "atk" if a == "intrepid_sword" else "def", 1)
				ab._fire(f, Color(0.9, 0.8, 0.5))
		"supersweet_syrup":
			var foes: Array = ab.arena.targets_of(f)
			if foes.is_empty():
				return false
			if _once(ab, f, a):
				ab._fire(f, Color(1.0, 0.8, 0.4))
				f.popup("Xarope!", Color(1.0, 0.8, 0.4), 0.9, 0.9)
				for t in foes:
					ab.arena.moves.change_stage(t, "spe", -1, f)
		"hospitality":
			var p := ab.partner_of(f)
			if p != null and p.hp < p.max_hp:
				fx._heal(p, maxi(1, int(p.max_hp * HOSPITALITY_HEAL)))
				ab._fire(f, Color(1.0, 0.85, 0.7))
		"costar":
			var q := ab.partner_of(f)
			if q != null:
				for k in BattleAbilities.STAGE_KEYS:
					f.stages[k] = int(q.stages.get(k, 0))
				f.crit_stage = q.crit_stage
				ab._fire(f, Color(0.9, 0.8, 1.0))
		"screen_cleaner":
			var cleared := false
			for side in [0, 1]:
				var sd := fx._sd(side)
				for k in ["light_screen", "reflect", "aurora_veil"]:
					if fx.active(sd, k):
						sd.erase(k)
						sd.erase(k + "#")
						cleared = true
			if cleared:
				ab._fire(f, Color(0.8, 1.0, 1.0))
				f.popup("Telas limpas!", Color(0.8, 1.0, 1.0), 0.9, 0.9)
		"slow_start":
			f.popup("Começou devagar...", Color(0.75, 0.75, 0.85), 0.9, 0.9)
			ab._fire(f, Color(0.75, 0.75, 0.85))
		"illusion":
			_veil(ab, f)
		"zero_to_hero":
			if is_hero(ab, f):
				set_form(f, "hero")
				ab._fire(f, Color(0.8, 1.0, 1.0))
		"tera_shift":
			set_form(f, "terastal")
			ab._fire(f, Color(1.0, 0.9, 1.0))
		"multitype", "rks_system":
			_mimic_type(ab, f, "plate" if a == "multitype" else "memory")
	return true


## Illusion: entra com a cara do último do time que ainda está de pé.
static func _veil(ab: BattleAbilities, f: BattleFighter) -> void:
	var list = ab.arena.get("party") if f.side == 0 else ab.arena.get("enemies")
	if not list is Array or f.look == null:
		return
	for i in range(list.size() - 1, -1, -1):
		var m = list[i]
		if m is Mon and m != f.mon and not m.is_fainted():
			_s(ab, f)["illusion"] = String(m.species)
			f.look.species = String(m.species)
			return


## Multitype / RKS System: o tipo vem da Placa/Memória segurada; sem elas, do melhor golpe que não é
## Normal (o Judgment/Multi-Attack segue esse tipo).
static func _mimic_type(ab: BattleAbilities, f: BattleFighter, suffix: String) -> void:
	var ty := ""
	var item := f.trainer_item
	if item.ends_with("_" + suffix):
		ty = item.trim_suffix("_" + suffix)
	if not ty in BattleKanto.TYPES:
		ty = ""
		var top := 0.0
		for id in f.moves:
			var mv := Dex.move(String(id))
			var t := String(mv.get("type", "normal"))
			if t != "normal" and float(mv.get("power", 0)) > top:
				top = float(mv.get("power", 0))
				ty = t
	if ty == "" or (f.types.size() == 1 and f.types[0] == ty):
		return
	f.types = [ty]
	f.popup("Tipo %s!" % ty.to_upper(), Dex.type_color(ty), 0.9, 0.9)
	ab._fire(f, Dex.type_color(ty))


## Palafin: o Herói vale só até o fim desta luta (marca em ab.once_used).
static func is_hero(ab: BattleAbilities, f: BattleFighter) -> bool:
	return ab.once_used.has("hero:%d" % f.mon.get_instance_id())


static func make_hero(ab: BattleAbilities, f: BattleFighter) -> void:
	ab.once_used["hero:%d" % f.mon.get_instance_id()] = true


## Saiu de campo vivo (troca): Zero to Hero vira Herói para a próxima entrada.
static func switched_out(ab: BattleAbilities, f: BattleFighter) -> void:
	if ab.ability_of(f) == "zero_to_hero":
		make_hero(ab, f)


# --- Por frame ---


static func tick(ab: BattleAbilities, _dt: float) -> void:
	_watch_faints(ab)
	for f in ab.arena.fighters:
		if is_instance_valid(f) and f.active():
			_tick_fighter(ab, f)


## Quem desmaiou agora: Soul Heart (todo mundo que fica), Receiver (o aliado herda a habilidade).
static func _watch_faints(ab: BattleAbilities) -> void:
	for f in ab.arena.fighters:
		if not is_instance_valid(f) or f.alive():
			continue
		var id: int = f.get_instance_id()
		if ab.seen_faint.has(id):
			continue
		ab.seen_faint[id] = true
		var fa := ab._raw_ability(f)
		for g in ab.arena.fighters:
			if g == f or not is_instance_valid(g) or not g.active():
				continue
			var ga := ab.ability_of(g)
			if ga == "soul_heart":
				ab._stage_up(g, "spa", 1)
				ab._fire(g, Color(1.0, 0.7, 0.85))
			elif ga == "receiver" and g.side == f.side and fa != "" and not fa in NO_COPY:
				g.set_meta("ability_override", fa)
				g.popup(
					"Recebeu %s" % String(Dex.ability(fa).get("name", fa.to_upper())),
					Color(0.8, 0.9, 1.0),
					0.9,
					0.9
				)


static func _tick_fighter(ab: BattleAbilities, f: BattleFighter) -> void:
	var a := ab.ability_of(f)
	if a == "":
		return
	var s := _s(ab, f)
	match a:
		"zen_mode":
			set_form(f, "zen" if f.hp * 2 <= f.max_hp else "")
		"schooling":
			set_form(f, "school" if f.level >= 20 and f.hp * 4 >= f.max_hp else "")
		"shields_down":
			set_form(f, "core" if f.hp * 2 <= f.max_hp else "")
		"zero_to_hero":
			if f.hp * 2 <= f.max_hp and form_of(f) != "hero":
				make_hero(ab, f)  # no aperto o herói aparece (sem troca em tempo real)
				set_form(f, "hero")
				ab._fire(f, Color(0.8, 1.0, 1.0))
		"forecast":
			_forecast(ab, f, s)
		"ice_face":
			if form_of(f) == "noice" and ab.weather_now() == "hail":
				set_form(f, "")
				f.popup("Gelo refeito!", Color(0.8, 0.95, 1.0), 0.9, 0.8)
		"protosynthesis", "quark_drive":
			var on := boosted(ab, f) != ""
			if on != bool(s.get("paradox", false)):
				s["paradox"] = on
				if on:
					f.popup(
						"%s ↑" % BattleHUD.VivaTags.short_stat(boosted(ab, f)),
						Color(1.0, 0.85, 0.4),
						0.9,
						0.9
					)
					ab._fire(f, Color(1.0, 0.85, 0.4))
		"commander":
			_commander(ab, f, s)
		"symbiosis":
			_symbiosis(ab, f)
		"opportunist":
			_opportunist(ab, f, s)


## Castform: o tipo e o tom seguem o clima.
static func _forecast(ab: BattleAbilities, f: BattleFighter, s: Dictionary) -> void:
	if BattleTransform.is_transformed(f):
		return
	var wx := ab.weather_now()
	if String(s.get("forecast", "-")) == wx:
		return
	s["forecast"] = wx
	if not s.has("forecast_types"):
		s["forecast_types"] = f.types.duplicate()
	if FORECAST.has(wx):
		var row: Array = FORECAST[wx]
		f.types = [String(row[0])]
		f.set_meta("form_tint", row[1])
		f.popup(
			"Previsão: %s" % String(row[0]).to_upper(), Dex.type_color(String(row[0])), 0.9, 0.8
		)
	else:
		f.types = (s.forecast_types as Array).duplicate()
		f.remove_meta("form_tint")
		f.popup("Previsão: normal", Color(0.9, 0.9, 0.9), 0.9, 0.8)
	ab._fire(f, Color(0.9, 0.95, 1.0))


## Commander: o Tatsugiri entra na boca do Dondozo parceiro (some, não age) e dá +2 em tudo a ele.
static func _commander(ab: BattleAbilities, f: BattleFighter, s: Dictionary) -> void:
	var p := ab.partner_of(f)
	var host := p != null and p.body_id() == "dondozo"
	if host and not bool(s.get("cmd", false)):
		s["cmd"] = true
		f.hidden = "commander"
		f.visible = false
		for k in BOOST_KEYS:
			ab._stage_up(p, k, 2)
		p.popup("Comandado!", Color(1.0, 0.8, 0.4), 1.0, 0.9)
		ab._fire(f, Color(1.0, 0.8, 0.4))
	elif not host and bool(s.get("cmd", false)):
		s["cmd"] = false
		f.hidden = ""
		f.visible = true
		f.popup("Saiu da boca!", Color(1.0, 0.8, 0.4), 0.9, 0.9)
	if bool(s.get("cmd", false)) and p != null:
		f.position = p.position


## Symbiosis: quando o item do parceiro acaba, passa o seu para ele.
static func _symbiosis(ab: BattleAbilities, f: BattleFighter) -> void:
	var p := ab.partner_of(f)
	if p == null or not p.item_used or p.trainer_item == "":
		return
	if f.trainer_item == "" or f.item_used:
		return
	p.trainer_item = f.trainer_item
	p.item_used = false
	f.item_used = true
	ab._fire(f, Color(0.7, 1.0, 0.8))
	p.popup(
		"Recebeu %s" % String(Dex.item(p.trainer_item).get("name", p.trainer_item)),
		Color(0.7, 1.0, 0.8),
		0.9,
		0.8
	)
	var et = ab.arena.get("end_turn")
	if et and et.has_method("held_check"):
		et.held_check(p)


## Opportunist: copia na hora os aumentos de atributo dos inimigos.
static func _opportunist(ab: BattleAbilities, f: BattleFighter, s: Dictionary) -> void:
	var seen: Dictionary = s.get("opp", {})
	for g in ab.arena.targets_of(f):
		var id: int = g.get_instance_id()
		var prev: Dictionary = seen.get(id, {})
		if not prev.is_empty():
			for k in BattleAbilities.STAGE_KEYS:
				var d := int(g.stages.get(k, 0)) - int(prev.get(k, 0))
				if d > 0:
					ab._stage_up(f, k, d)
					ab._fire(f, Color(1.0, 0.85, 0.6))
		seen[id] = g.stages.duplicate()
	s["opp"] = seen


# --- Fim de rodada ---


## Passo de fim de rodada das habilidades novas (chamado por late_residual).
static func late(ab: BattleAbilities, f: BattleFighter, a: String, s: Dictionary) -> void:
	match a:
		"moody":
			_moody(ab, f)
		"bad_dreams":
			for t in ab.arena.targets_of(f):
				if t.status == "sleep" and ab.ability_of(t) != "magic_guard":
					ab._fire(f, COLORS.bad)
					t.residual_damage(
						maxi(1, int(t.max_hp * BAD_DREAMS_CHIP)), "pesadelo", COLORS.bad
					)
		"truant":
			var loaf := int(s.get("loaf", 0))
			if loaf == 1:
				s["loaf"] = 2
				f.popup("Vai vadiar...", Color(0.75, 0.75, 0.8), 0.9, 0.8)
				ab._fire(f, Color(0.75, 0.75, 0.8))
			elif loaf == 2:
				s["loaf"] = 0
		"slow_start":
			if ab.rounds - int(s.enter_round) == SLOW_START_ROUNDS - 1:
				f.popup("Pegou ritmo!", Color(1.0, 0.9, 0.5), 0.9, 0.8)
		"hunger_switch":
			set_form(f, "" if form_of(f) == "hangry" else "hangry")
			ab._fire(f, Color(1.0, 0.8, 0.5))
		"cud_chew":
			_cud(ab, f, s)


## Moody: um atributo ao acaso +2 e outro -1 (nunca o de precisão).
static func _moody(ab: BattleAbilities, f: BattleFighter) -> void:
	var ups: Array = BOOST_KEYS.filter(func(k): return int(f.stages.get(k, 0)) < 6)
	if ups.is_empty():
		return
	var up := String(ups[ab.arena.rng.randi() % ups.size()])
	ab._stage_up(f, up, 2)
	var downs: Array = BOOST_KEYS.filter(func(k): return k != up and int(f.stages.get(k, 0)) > -6)
	if not downs.is_empty():
		ab.arena.moves.change_stage(f, String(downs[ab.arena.rng.randi() % downs.size()]), -1)
	ab._fire(f, Color(1.0, 0.7, 0.9))


## Cud Chew: a frutinha comida volta a ser comida na rodada seguinte.
static func _cud(ab: BattleAbilities, f: BattleFighter, s: Dictionary) -> void:
	var due := int(s.get("cud_round", -1))
	if due < 0 or ab.rounds < due or f.trainer_item == "":
		return
	s["cud_round"] = -1
	s["cud_busy"] = true
	f.item_used = false
	ab._fire(f, Color(0.8, 1.0, 0.7))
	f.popup("Remastigou!", Color(0.8, 1.0, 0.7), 0.9, 0.8)
	var et = ab.arena.get("end_turn")
	if et and et.has_method("held_check"):
		et.held_check(f)
	s["cud_busy"] = false


## Comeu a frutinha (BattleEndTurn._eat): Cheek Pouch cura 1/3 e Cud Chew marca a remastigada.
static func on_berry(ab: BattleAbilities, f: BattleFighter) -> void:
	var s := _s(ab, f)
	match ab.ability_of(f):
		"cheek_pouch":
			ab._fire(f, Color(1.0, 0.85, 0.7))
			f.residual_heal(maxi(1, int(f.max_hp * CHEEK_HEAL)), "bochechas")
		"cud_chew":
			if not bool(s.get("cud_busy", false)):
				s["cud_round"] = ab.rounds + 1


# --- Fim da luta ---


## Venceu: Honey Gather encontra mel (5% + 5% a cada 10 níveis, até 50%). Devolve os ids achados.
static func honey(ab: BattleAbilities) -> Array:
	var out: Array = []
	for f in ab.arena.fighters:
		if (
			is_instance_valid(f)
			and f.side == 0
			and f.alive()
			and ab.ability_of(f) == "honey_gather"
			and ab._roll(minf(HONEY_BASE + HONEY_BASE * floorf(float(f.level) / 10.0), 0.5))
		):
			out.append("honey")
	return out


# --- IA ---


## A IA pesa o golpe: imunidades das habilidades novas valem quase zero.
static func ai_mult(
	ab: BattleAbilities, user: BattleFighter, target: BattleFighter, mv: Dictionary
) -> float:
	var ta := ab._tab(user, target, mv)
	var type := String(mv.get("type", "normal"))
	var id := String(mv.get("id", ""))
	match ta:
		"bulletproof":
			if id in BULLET_MOVES:
				return 0.05
		"wind_rider":
			if id in WIND_MOVES:
				return 0.05
		"earth_eater":
			if type == "ground":
				return 0.05
		"well_baked_body":
			if type == "fire":
				return 0.05
		"wonder_guard":
			if Dex.effectiveness(type, target.types) <= 1.0:
				return 0.05
		"disguise":
			if form_of(target) != "busted":
				return 0.4
		"ice_face":
			if form_of(target) != "noice" and String(mv.get("category", "")) == "physical":
				return 0.4
		"fluffy":
			if type == "fire":
				return 1.5
	return 1.0
