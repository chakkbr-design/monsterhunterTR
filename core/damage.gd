class_name Damage
extends RefCounted
## Fórmula de dano da geração atual (Gen 5+, igual na Gen 9), com os arredondamentos oficiais.
## attacker/defender: {level, types, atk, def, spa, spd, crit_stage, burned, guts, terrain_mult, spread, weather}
## Os stats já vêm com estágios aplicados (burn NÃO: passe burned=true); no crítico, passe em crit_atk/crit_def os stats
## sem os estágios desfavoráveis (se ausentes, usa os normais).
## mods (opcional, vence o attacker): spread (0,75 quando o golpe acerta mais de um alvo), weather ("rain"/"sun").
##
## Ordem oficial (Bulbapedia, "Damage", Gen V onward):
##   base = floor(floor(floor(2*Nível/5 + 2) * Poder * A / D) / 50) + 2
##   x alvos (spread 0,75) -> x clima (1,5 / 0,5) -> x crítico 1,5 -> x aleatório (85..100)/100 (floor)
##   -> x STAB 1,5 -> x tipo (floor) -> x queimadura 0,5 (físico, sem Guts) -> x outros -> mínimo 1.
## Cada passo arredonda: floor no aleatório e no tipo, "round half down" (pokeRound) nos outros.

const BURN_ATK_MULT := 0.5
const STAB := 1.5
const SPREAD := 0.75
const WEATHER_UP := 1.5
const WEATHER_DOWN := 0.5
const TERRAIN := 1.3  ## Gen 8+: terreno elétrico/grama/psíquico sobe 1,3x o poder (vem em terrain_mult)


static func compute(
	attacker: Dictionary,
	defender: Dictionary,
	move: Dictionary,
	rng: RandomNumberGenerator = null,
	mods := {}
) -> Dictionary:
	var type := String(move.get("type", "normal"))
	var eff := Dex.effectiveness(type, defender.get("types", []))
	if move.has("also_type"):
		eff *= Dex.effectiveness(String(move.also_type), defender.get("types", []))  # Flying Press
	var out := {"damage": 0, "eff": eff, "crit": false, "stab": false}
	var power := float(move.get("power", 0)) * float(attacker.get("terrain_mult", 1.0))
	if power <= 0.0 or eff == 0.0:
		return out
	var physical: bool = move.get("category", "") == "physical"
	var crit_stage := int(move.get("crit", 0)) + int(attacker.get("crit_stage", 0))
	# Shell Armor / Battle Armor no defensor: sem crítico (defender.no_crit).
	var crit := (
		not bool(defender.get("no_crit", false)) and _randf(rng) < StatCalc.crit_chance(crit_stage)
	)
	var ak := "atk" if physical else "spa"
	var dk := "def" if physical else "spd"
	var a := (
		float(attacker.get("crit_" + ak, attacker.get(ak, 1)))
		if crit
		else float(attacker.get(ak, 1))
	)
	var d := (
		float(defender.get("crit_" + dk, defender.get(dk, 1)))
		if crit
		else float(defender.get(dk, 1))
	)
	var lv := float(attacker.get("level", 1))
	var dmg := floorf(floorf(floorf(2.0 * lv / 5.0 + 2.0) * power * a / maxf(d, 1.0)) / 50.0) + 2.0
	dmg = poke_round(dmg * float(mods.get("spread", attacker.get("spread", 1.0))))
	dmg = poke_round(
		dmg * weather_mult(type, String(mods.get("weather", attacker.get("weather", ""))))
	)
	if crit:
		dmg = poke_round(dmg * StatCalc.CRIT_MULT)
	var roll := rng.randi_range(85, 100) if rng else randi_range(85, 100)
	dmg = floorf(dmg * float(roll) / 100.0)
	var stab: bool = type in attacker.get("types", [])
	if stab:
		dmg = poke_round(dmg * STAB)
	dmg = floorf(dmg * eff)
	if physical and attacker.get("burned", false) and not attacker.get("guts", false):
		dmg = poke_round(dmg * BURN_ATK_MULT)
	out.damage = maxi(1, int(dmg))
	out.crit = crit
	out.stab = stab
	return out


## Arredonda para o inteiro mais perto; .5 desce (como o jogo oficial faz com os modificadores x/4096).
static func poke_round(x: float) -> float:
	var f := floorf(x)
	return f + 1.0 if x - f > 0.5 else f


## Chuva: Água 1,5x e Fogo 0,5x; Sol: o contrário.
static func weather_mult(type: String, weather: String) -> float:
	match weather:
		"rain":
			return WEATHER_UP if type == "water" else (WEATHER_DOWN if type == "fire" else 1.0)
		"sun":
			return WEATHER_UP if type == "fire" else (WEATHER_DOWN if type == "water" else 1.0)
	return 1.0


static func _randf(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()
