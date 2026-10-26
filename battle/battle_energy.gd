class_name BattleEnergy
extends RefCounted
## Modo de energia (opts.battle_mode = "energy"): sem rodadas nem posições fixas. Cada lutador tem uma
## barra de energia (no lugar do PP) que enche com o tempo; a Speed acelera um pouco e ficar longe dos
## inimigos sem atacar enche mais rápido (recuar para recuperar). Cada golpe gasta energia pelo poder,
## crescendo mais que ele, e o efeito secundário cobra a mais; status grave e sono custam caro;
## prioridade gasta menos, mas tem cooldown maior. Cooldown próprio pelo poder e pelo efeito.

## Barra cheia.
const MAX := 100.0
## Energia por segundo, base.
const REGEN := 15.0
## Speed: fator 1 + SPEED_K * ln(Speed / SPEED_REF), limitado a SPEED_MIN-SPEED_MAX (acelera pouco).
const SPEED_K := 0.12
const SPEED_REF := 100.0
const SPEED_MIN := 0.85
const SPEED_MAX := 1.2
## Descanso: sem inimigo a menos de REST_DIST m e sem golpe recente, a energia enche REST_MULT x.
const REST_DIST := 4.5
const REST_MULT := 1.8
## Custo (Caio, 2026-10-25): golpe fraco e sem efeito é barato e rápido; o custo cresce mais que o
## poder (BASE_COST + BP_COST * bp + BP_COST2 * bp^2) e o efeito secundário cobra a mais
## (sec_weight * SEC_COST, crescendo com o poder: forte + efeito custa mais ainda). Até MAX_COST.
const BASE_COST := 10.0
const BP_COST := 0.15
const BP_COST2 := 0.0025
const MAX_COST := 95.0
const SEC_COST := 30.0
## Status: STATUS_COST; golpe que só causa status grave (Toxic, Will-O-Wisp, Thunder Wave) INFLICT_COST;
## sono SLEEP_COST; Protect/Detect PROTECT_COST.
const STATUS_COST := 28.0
const INFLICT_COST := 42.0
const SLEEP_COST := 50.0
const PROTECT_COST := 20.0
## Cooldown no modo de energia: CD_BASE + CD_K * (bp / CD_BP)^2 (mín. CD_MIN; cresce rápido nos fortes)
## + metade do preparo/duração do golpe, mais CD_SEC x peso do efeito; status grave INFLICT_CD, sono
## SLEEP_CD (os outros status como em Dex).
const CD_BASE := 0.4
const CD_K := 0.9
const CD_BP := 50.0
const CD_MIN := 1.2
const CD_SEC := 2.0
const INFLICT_CD := 7.0
const SLEEP_CD := 9.0
const MAJOR := ["burn", "poison", "toxic", "paralysis", "freeze", "sleep"]
## Golpe de poder variável ou dano fixo: custa como um de 70 de poder.
const VARIABLE_BP := 70.0
## Acertos médios do multi-hit 2-5 oficial (35/35/15/15%).
const MEAN_HITS_2_5 := 3.1
## Prioridade (Quick Attack...): custo PRIORITY_COST x, cooldown PRIORITY_CD x.
const PRIORITY_COST := 0.6
const PRIORITY_CD := 1.8
## Dano final no modo de energia (o VGC fica no BattleMoves.DAMAGE_PACE, 0,75). O Caio escolheu 0,6
## em 2026-10-25 pela bateria: menos "entrou e morreu" e ~21 s por Pokémon. opts.damage_pace muda.
const DAMAGE_PACE := 0.6
## Andar no modo de energia (Caio, 2026-10-25: a luta estava rápida demais): todo Pokémon anda
## WALK_PACE x da velocidade pela Speed (StatCalc.walk_speed). Investidas e golpes não mudam.
const WALK_PACE := 0.8
## Começa a luta com esta fração da barra.
const START := 0.4
## Status no modo de energia (Caio, 2026-10-25: veneno, queimadura e paralisia estavam fortes demais).
## Chance de pegar: efeito secundário de golpe de dano x SEC_STATUS_MULT; golpe de status x
## STATUS_MOVE_MULT (sono SLEEP_MOVE_MULT). Duração em segundos (STATUS_SECS); descansando passa
## REST_CURE x mais rápido. Depois que passa, STATUS_IMMUNE s sem pegar o mesmo status de novo.
const STATUS_CHANCE_KEYS := ["burn", "poison", "toxic", "paralysis"]
const SEC_STATUS_MULT := 0.5
const STATUS_MOVE_MULT := 0.7
const SLEEP_MOVE_MULT := 0.8
const STATUS_SECS := {"burn": 16.0, "poison": 12.0, "toxic": 12.0, "paralysis": 8.0, "freeze": 6.0}
const REST_CURE := 1.6
const STATUS_IMMUNE := 6.0
## Entrada protegida: quem acabou de entrar toma ENTRY_MULT do dano por ENTRY_GUARD s e não cai de
## HP cheio com um golpe só (fica com 1).
const ENTRY_GUARD := 3.0
const ENTRY_MULT := 0.5


static func on(arena) -> bool:
	return arena != null and arena.has_method("energy_on") and bool(arena.energy_on())


static func cost(mv: Dictionary) -> float:
	var c := STATUS_COST
	if String(mv.get("category", "")) != "status":
		var bp := nominal_bp(mv)
		c = BASE_COST + bp * BP_COST + bp * bp * BP_COST2
		c += sec_weight(mv) * SEC_COST * (0.6 + bp / 100.0)
		c = minf(c, MAX_COST)
	else:
		c = status_cost(mv)
	if int(mv.get("priority", 0)) > 0 and String(mv.get("special", "")) != "protect":
		c *= PRIORITY_COST
	return roundf(c)


static func status_cost(mv: Dictionary) -> float:
	var sp := String(mv.get("special", ""))
	if sp in ["protect", "detect"]:
		return PROTECT_COST
	var ef = mv.get("effect")
	if ef is Dictionary and String(ef.get("status", "")) in MAJOR:
		return SLEEP_COST if String(ef.status) == "sleep" else INFLICT_COST
	return STATUS_COST


## Peso do efeito secundário de um golpe de dano (0 = nenhum): chance x valor do efeito. Status grave
## 1, sono/congelar 1,3, hesitar 0,7, confusão 0,5, queda de atributo do alvo 0,35 por estágio, buff
## próprio 0,5, dreno 0,25 x fração, crítico alto 0,15. Queda de atributo própria (Close Combat) não cobra.
static func sec_weight(mv: Dictionary) -> float:
	var w := 0.0
	var ef = mv.get("effect")
	if ef is Dictionary:
		var ch := float(ef.get("chance", 0.0))
		if ef.has("status"):
			var st := String(ef.status)
			if st in ["sleep", "freeze"]:
				w += 1.3 * ch
			elif st in MAJOR:
				w += ch
			elif st == "flinch":
				w += 0.7 * ch
			elif st == "confusion":
				w += 0.5 * ch
			else:
				w += 0.4 * ch
		elif ef.has("stat"):
			var n := absi(int(ef.get("stages", 1)))
			w += (0.5 if bool(ef.get("self", false)) else 0.35 * n) * ch
	if mv.has("flinch"):
		w += 0.7 * float(mv.flinch)
	if mv.has("drain"):
		w += 0.25 * float(mv.drain) * 2.0
	if int(mv.get("crit", 0)) > 0:
		w += 0.15
	return w


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


## Cooldown do golpe no modo de energia (antes do fator de Speed): pelo poder e pelo efeito (forte e com
## efeito demora mais), prioridade mais longa; status grave e sono longos, outros status como em Dex.
static func cooldown(mv: Dictionary) -> float:
	var cd: float
	if String(mv.get("category", "")) == "status":
		cd = Dex.cooldown(mv)
		var ef = mv.get("effect")
		if ef is Dictionary and String(ef.get("status", "")) in MAJOR:
			cd = maxf(cd, SLEEP_CD if String(ef.status) == "sleep" else INFLICT_CD)
	else:
		var bp := nominal_bp(mv)
		cd = maxf(CD_MIN, CD_BASE + CD_K * pow(bp / CD_BP, 2.0))
		cd += float(mv.get("windup", 0.0)) * 0.5 + float(mv.get("duration", 0.0)) * 0.5
		cd += CD_SEC * sec_weight(mv)
		cd = snappedf(cd, 0.1)
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
	var k := REST_MULT if resting(f) else 1.0
	if f.arena and f.arena.get("terrain"):
		k *= f.arena.terrain.regen_mult(f)  # lago e grama alta pelo tipo (BattleTerrain)
		k *= f.arena.terrain.props.regen_mult(f)  # Grama perto de árvore (BattleProps)
	if f.breath_t > 0.0:
		k *= BattlePassives.BREATH_REGEN  # Fôlego depois do pulo de desespero
	return REGEN * speed_mult(f) * k


## Segundos até ter `need` de energia no ritmo de agora.
static func secs_to(f: BattleFighter, need: float) -> float:
	return maxf(need - f.pp_max, 0.0) / maxf(regen(f), 0.01)


## Multiplicador da chance de um status pegar (BattleMoveEffects.status_chance_mult).
static func status_chance_mult(mv: Dictionary, st: String) -> float:
	var status_move := String(mv.get("category", "")) == "status"
	if st == "sleep":
		return SLEEP_MOVE_MULT if status_move else 1.0
	if not st in STATUS_CHANCE_KEYS:
		return 1.0
	return STATUS_MOVE_MULT if status_move else SEC_STATUS_MULT


## Dano depois da entrada protegida.
static func entry_damage(f: BattleFighter, dmg: int) -> int:
	if f.entry_t <= 0.0 or dmg <= 0:
		return dmg
	dmg = maxi(1, int(round(float(dmg) * ENTRY_MULT)))
	if dmg >= f.hp and f.hp >= f.max_hp:
		dmg = f.hp - 1
		f.popup("Held on at entry!", Color(0.7, 0.9, 1.0), 1.0, 0.7)
	return dmg
