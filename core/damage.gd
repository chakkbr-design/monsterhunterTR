class_name Damage
extends RefCounted
## Fórmula de dano (Gen 3), igual à do jogo de referência (moves.gd:367-377).
## attacker/defender: {level, types, atk, def, spa, spd, crit_stage, burned, terrain_mult}
## Os stats já vêm com estágios aplicados (burn NÃO: passe burned=true); no crítico, passe em crit_atk/crit_def os stats
## sem os estágios desfavoráveis (se ausentes, usa os normais).

const BURN_ATK_MULT := 0.5
const STAB := 1.5


static func compute(attacker: Dictionary, defender: Dictionary, move: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var eff := Dex.effectiveness(String(move.get("type", "normal")), defender.get("types", []))
	var out := {"damage": 0, "eff": eff, "crit": false, "stab": false}
	var power := float(move.get("power", 0))
	if power <= 0.0 or eff == 0.0:
		return out
	var physical: bool = move.get("category", "") == "physical"
	var crit_stage := int(move.get("crit", 0)) + int(attacker.get("crit_stage", 0))
	var crit := _randf(rng) < StatCalc.crit_chance(crit_stage)
	var ak := "atk" if physical else "spa"
	var dk := "def" if physical else "spd"
	var a := float(attacker.get("crit_" + ak, attacker.get(ak, 1))) if crit else float(attacker.get(ak, 1))
	var d := float(defender.get("crit_" + dk, defender.get(dk, 1))) if crit else float(defender.get(dk, 1))
	if physical and attacker.get("burned", false):
		a *= BURN_ATK_MULT
	var lv := float(attacker.get("level", 1))
	var base := ((2.0 * lv / 5.0 + 2.0) * power * a / maxf(d, 1.0)) / 50.0 + 2.0
	var stab: bool = move.get("type", "") in attacker.get("types", [])
	var roll := rng.randf_range(0.85, 1.0) if rng else randf_range(0.85, 1.0)
	var mult := (STAB if stab else 1.0) * eff * (StatCalc.CRIT_MULT if crit else 1.0) * roll * float(attacker.get("terrain_mult", 1.0))
	out.damage = maxi(1, int(base * mult))
	out.crit = crit
	out.stab = stab
	return out



static func _randf(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()
