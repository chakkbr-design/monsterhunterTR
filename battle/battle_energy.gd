class_name BattleEnergy
extends RefCounted
## Modo de energia (opts.battle_mode = "energy"): sem rodadas nem posições fixas. Cada lutador tem uma
## barra de energia (no lugar do PP) que enche com o tempo; a Speed acelera um pouco e ficar longe dos
## inimigos sem atacar enche mais rápido (recuar para recuperar). Cada golpe gasta energia pelo poder
## (status gasta muito); prioridade gasta menos, mas tem cooldown maior. Os cooldowns por golpe e o GCD
## continuam os de Dex.cooldown (forte e status mais longos). Números iniciais: o Caio balanceia no treino.

## Barra cheia.
const MAX := 100.0
## Energia por segundo, base.
const REGEN := 5.0
## Speed: fator 1 + SPEED_K * ln(Speed / SPEED_REF), limitado a SPEED_MIN-SPEED_MAX (acelera pouco).
const SPEED_K := 0.12
const SPEED_REF := 100.0
const SPEED_MIN := 0.85
const SPEED_MAX := 1.2
## Descanso: sem inimigo a menos de REST_DIST m e sem golpe recente, a energia enche REST_MULT x.
const REST_DIST := 4.5
const REST_MULT := 1.8
## Custo: BASE_COST + bp * BP_COST (bp oficial), limitado a MAX_COST; status STATUS_COST.
const BASE_COST := 12.0
const BP_COST := 0.25
const MAX_COST := 50.0
const STATUS_COST := 28.0
## Golpe de poder variável ou dano fixo: custa como um de 70 de poder.
const VARIABLE_BP := 70.0
## Acertos médios do multi-hit 2-5 oficial (35/35/15/15%).
const MEAN_HITS_2_5 := 3.1
## Prioridade (Quick Attack...): custo PRIORITY_COST x, cooldown PRIORITY_CD x.
const PRIORITY_COST := 0.6
const PRIORITY_CD := 1.8
## Começa a luta com esta fração da barra.
const START := 0.4


static func on(arena) -> bool:
	return arena != null and arena.has_method("energy_on") and bool(arena.energy_on())


static func cost(mv: Dictionary) -> float:
	var c := STATUS_COST
	if String(mv.get("category", "")) != "status":
		c = minf(BASE_COST + nominal_bp(mv) * BP_COST, MAX_COST)
	if int(mv.get("priority", 0)) > 0:
		c *= PRIORITY_COST
	return roundf(c)


## Poder que o custo usa: o oficial vezes os acertos médios do multi-hit oficial (2-5 = 3,1; Double
## Kick = 2) e VARIABLE_BP nos golpes de poder variável ou dano fixo (Low Kick, Seismic Toss...), que
## sem isso sairiam pelo custo mínimo.
static func nominal_bp(mv: Dictionary) -> float:
	var bp := float(mv.get("bp", 0))
	if bp <= 0.0:
		return VARIABLE_BP
	var hr = mv.get("hits_range")
	if hr is Array:
		var lo := int(hr[0])
		var hi := int(hr[1])
		bp *= float(lo) if lo == hi else MEAN_HITS_2_5
	return bp


## Cooldown do golpe no modo de energia (antes do fator de Speed): o de Dex, prioridade mais longa.
static func cooldown(mv: Dictionary) -> float:
	var cd := Dex.cooldown(mv)
	if int(mv.get("priority", 0)) > 0:
		cd *= PRIORITY_CD
	return cd


static func speed_mult(f: BattleFighter) -> float:
	var s := maxf(f.eff_spe(), 1.0)
	return clampf(1.0 + SPEED_K * log(s / SPEED_REF), SPEED_MIN, SPEED_MAX)


## Descansando: longe de todo inimigo e sem golpe saindo.
static func resting(f: BattleFighter) -> bool:
	if f.gcd_t > 0.0 or f.prepare_t > 0.0 or f.arena == null:
		return false
	for o in f.arena.fighters:
		if is_instance_valid(o) and o.side != f.side and o.active():
			if f.flat_to(o).length() < REST_DIST:
				return false
	return true


static func regen(f: BattleFighter) -> float:
	return REGEN * speed_mult(f) * (REST_MULT if resting(f) else 1.0)


## Segundos até ter `need` de energia no ritmo de agora.
static func secs_to(f: BattleFighter, need: float) -> float:
	return maxf(need - f.pp_max, 0.0) / maxf(regen(f), 0.01)
