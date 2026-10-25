class_name BattleTerrainAI
extends RefCounted
## IA do cenário no modo de energia (BattleTerrain): um gancho só, chamado do começo de
## BattleAI._energy_steer. Não decide golpe nem faixa; só puxa o lutador para o lugar certo do cenário:
##
## - Fogo dentro do lago sai da água (lá ele toma dano e quase não recupera energia).
## - Na grama alta com inimigo que tem golpe de Fogo: sai da moita (ela pode pegar fogo com ele dentro).
## - Elétrico com golpe pronto: alvo dentro da água vira o alvo e o golpe Elétrico vira a intenção.
## - Emboscada na grama alta (plano emboscada; Grama e Trapaceiro fora de pressão/caçar/proteger): quando
##   convém (falta energia para o golpe ou o alvo ainda está fora do alcance dele) vai para uma moita
##   perto (até GRASS_NEAR m; descansando GRASS_REST_MAX), que não fica além do alvo e de onde o alvo
##   passa ao alcance; espera escondido (golpe de longe erra mais, Grama recupera 1,3x) e sai atacando
##   quando o alvo chega (contato: correndo, tag `ambush_strike`). Nunca fica para sempre: até GO_MAX s
##   para chegar, HIDE_MAX s escondido, depois GRASS_CD s sem voltar. Sai na hora com o parceiro sendo
##   atacado (2x2: largar ele sozinho, não), com inimigo de Fogo, com a barra cheia e o alvo ao alcance,
##   tomando golpe mesmo escondido ou com inimigo dentro da moita. Telemetria `ai_grass` (secs, why).
##
## Devolve a direção desejada ou Vector3.INF (segue a IA normal).

const GRASS_REST_MAX := 7.0  ## distância máxima até a moita para ir descansar nela
const GRASS_NEAR := 6.0  ## distância máxima até a moita para a emboscada
const GRASS_BEYOND := 1.5  ## a moita fica a no máximo distância do alvo + isso (não atravessa a quadra)
const USEFUL_GAP := 3.0  ## a moita fica a até alcance do golpe + isso do alvo
const USEFUL_MIN := 6.0
const HIDE_MAX := 5.0  ## segundos escondido na moita, no máximo
const GO_MAX := 3.0  ## segundos para chegar na moita; passou, desiste
const GRASS_CD := 8.0  ## recarga depois de sair da moita
const STRIKE_GAP := 2.5  ## golpe de contato: sai da moita com o alvo a até alcance + isso
const STRIKE_MAX := 1.5  ## corre para o alvo por até isso; depois larga a emboscada
const ALLY_HURT := 1.5  ## parceiro tomou dano há menos disso: está sendo focado
const ALLY_PRESS := 4.5  ## dois inimigos mirando o parceiro a até isso dele: está sendo focado
const FOE_NEAR := 1.5  ## inimigo a até raio da moita + isso: moita ocupada
const CLOSE_FOE := 2.5  ## alvo mais perto que isso: não vale ir se esconder
const HURT_CALM := 1.0  ## tomou dano há menos disso: não vai se esconder
const HOLD_MIN := 2.5  ## escondido, segura o golpe pronto por até isso (alvo aberto ou perto solta antes)
const HOLD_OPEN := 0.8  ## escondido há pelo menos isso, o alvo aberto já solta
const HOLD_GO := 2.0  ## indo para a moita, segura o golpe pronto por até isso
const GRASS_STAY := 0.35  ## dentro da moita a esta fração do raio do centro: para e espera
const AMBUSH_PROFILES := ["trickster"]
const SHOCK_RETARGET := 2.5  ## segura o alvo na água por este tempo antes de reavaliar


static func steer(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or not ter.has_method("has_scenery") or not ter.has_scenery():
		return Vector3.INF
	if ter.sliding(f):
		return Vector3.ZERO  # sendo puxado/derrubado
	if "fire" in f.types and ter.wet(f):
		ai.tag = "leave_water"
		return _out_of(f, ter.pond_at(f.position))
	var fire_foe := foe_has_fire(f)
	if fire_foe and not "fire" in f.types and ter.in_grass(f):
		ai.tag = "leave_grass"
		return _out_of(f, ter.grass_at(f.position))
	_shock_target(ai, ter)
	if fire_foe:
		if not ai.grass_spot.is_empty():
			end_grass(ai, "fire")
		return Vector3.INF
	return _grass_ambush(ai, ter, d)


## Emboscada na grama: escolhe/segura a moita e devolve a direção; INF = segue a IA normal.
static func _grass_ambush(ai, ter, d: float, retreating := false) -> Vector3:
	var f: BattleFighter = ai.f
	if not ai.grass_spot.is_empty():
		var why := _leave_why(ai, ter, d)
		if why != "":
			end_grass(ai, why)
			return Vector3.INF
	else:
		if not _hide_ok(ai, d, retreating):
			return Vector3.INF
		var pick := _ambush_spot(ai, ter, d, retreating)
		if pick.is_empty():
			return Vector3.INF
		ai.grass_spot = pick
		ai.grass_go_t = 0.0
		ai.grass_t = 0.0
		ai.grass_age = 0.0
		ai.grass_strike_t = -1.0
	var opp: BattleFighter = f.opponent
	ai._fly(d)
	if ai.grass_strike_t >= 0.0 or _strike_now(ai, d):
		# Sai da moita correndo para o golpe de contato.
		if ai.grass_strike_t < 0.0:
			ai.grass_strike_t = 0.0
		ai.tag = "ambush_strike"
		f.sprinting = f.can_sprint(true)
		return f.flat_to(opp).normalized()
	var g: Dictionary = ai.grass_spot
	var to: Vector3 = g.pos - f.pos2(f.position)
	if to.length() < float(g.r) * GRASS_STAY:
		ai.tag = "ambush_hide"
		return Vector3.ZERO  # escondido: espera o alvo chegar (ou a barra encher)
	ai.tag = "grass_go"
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


## Segura o golpe pronto durante a emboscada: indo para a moita (até HOLD_GO s) e escondido até
## HOLD_MIN s (no mínimo HOLD_OPEN s), a não ser que a barra esteja cheia, o alvo esteja aberto
## (BattleAI._ambush_open) ou perto (vê através da grama). Os limites da moita valem igual: nunca segura para sempre.
static func hold_fire(ai, d: float) -> bool:
	if ai.grass_spot.is_empty() or ai.grass_strike_t >= 0.0:
		return false
	var f: BattleFighter = ai.f
	if f.pp_max >= BattleEnergy.MAX - 0.5 or d <= BattleTerrain.GRASS_SEE + 1.0:
		return false
	if ai.grass_t <= 0.0:
		return ai.grass_go_t < HOLD_GO
	if ai.grass_t >= HOLD_MIN:
		return false
	if ai.grass_t < HOLD_OPEN:
		return true
	var opp: BattleFighter = f.opponent
	return not ai._ambush_open(opp, f.flat_to(opp) / maxf(d, 0.001))


## Relógios da moita (BattleAI._energy_tick): chegar, ficar e sair atacando têm limite.
static func tick(ai, dt: float) -> void:
	if ai.grass_spot.is_empty():
		ai.grass_cd = maxf(ai.grass_cd - dt, 0.0)
		return
	ai.grass_age += dt
	var ter = ai.f.arena.get("terrain")
	if ai.grass_strike_t >= 0.0:
		ai.grass_strike_t += dt
	elif ter != null and ter.in_grass(ai.f) and ter.grass_at(ai.f.position) == ai.grass_spot:
		ai.grass_t += dt
	else:
		ai.grass_go_t += dt
	if ai.grass_strike_t > STRIKE_MAX:
		end_grass(ai, "strike_late")
	elif ai.grass_t > HIDE_MAX:
		end_grass(ai, "time")
	elif ai.grass_go_t > GO_MAX:
		end_grass(ai, "far")


## Larga a moita: recarga GRASS_CD e telemetria (tempo escondido e por quê).
static func end_grass(ai, why: String) -> void:
	if ai.grass_spot.is_empty():
		return
	var tel = ai.f.arena.get("telemetry")
	if tel:
		(
			tel
			. note(
				"ai_grass",
				{
					"who": tel.uid(ai.f),
					"secs": snappedf(ai.grass_t, 0.01),
					"go": snappedf(ai.grass_go_t, 0.01),
					"why": why,
					"d":
					(
						snappedf(ai.f.flat_to(ai.f.opponent).length(), 0.1)
						if is_instance_valid(ai.f.opponent)
						else -1.0
					),
					"plan": String(ai.plan),
				}
			)
		)
	ai.grass_spot = {}
	ai.grass_t = 0.0
	ai.grass_go_t = 0.0
	ai.grass_age = 0.0
	ai.grass_strike_t = -1.0
	ai.grass_cd = GRASS_CD


## Quem usa a grama: plano emboscada; Grama/Trapaceiro fora dos planos de ficar em cima. Voador e
## Fúria/Ofensivo não se escondem.
static func eligible(ai) -> bool:
	var f: BattleFighter = ai.f
	if (
		float(ai._p("fly", 0.0)) > 0.0
		or f.mood_state == "fury"
		or ai.ally_mode() == BattleAI.ATTACK
	):
		return false
	if ai.plan == BattlePlan.AMBUSH:
		return true
	return (
		_likes_grass(f) and not ai.plan in [BattlePlan.PRESS, BattlePlan.HUNT, BattlePlan.PROTECT]
	)


## Vale ir se esconder agora: elegível, sem recarga, sem tomar dano, parceiro não focado, alvo não
## colado, e falta energia para o golpe ou o alvo ainda está fora do alcance dele.
static func _hide_ok(ai, d: float, retreating := false) -> bool:
	if ai.grass_cd > 0.0 or not eligible(ai):
		return false
	if ai.hurt_t < HURT_CALM or ally_focused(ai):
		return false
	if retreating:
		return true  # acabou de bater: recua para a moita e recarrega escondido
	if ai.intent == "" or ai.recover_t > 0.0 or d < CLOSE_FOE:
		return false
	return _short(ai) or not ai.in_range(ai.intent, d)


## Recuo depois de bater (BattleAI.step): quem usa a grama recua para a moita perto em vez de recuar
## reto (começa a emboscada lá). INF = recuo normal.
static func retreat_grass(ai, d: float) -> Vector3:
	var f: BattleFighter = ai.f
	var ter = f.arena.get("terrain") if f.arena else null
	if ter == null or not ter.has_method("has_scenery") or ter.grass.is_empty():
		return Vector3.INF
	if ter.sliding(f) or not f.can_act() or foe_has_fire(f):
		return Vector3.INF
	return _grass_ambush(ai, ter, d, true)


## O golpe pretendido ainda falta energia.
static func _short(ai) -> bool:
	var f: BattleFighter = ai.f
	if ai.intent == "":
		return true  # acabou de bater (o próximo golpe ainda não foi escolhido)
	return BattleEnergy.secs_to(f, f.pp_cost_of(Dex.move(ai.intent))) > BattleAI.ENERGY_WAIT


## Por que largar a moita agora ("" = fica).
static func _leave_why(ai, ter, d: float) -> String:
	var f: BattleFighter = ai.f
	var g: Dictionary = ai.grass_spot
	if not ter.grass.has(g):
		return "burn"
	if not eligible(ai):
		return "plan"
	if ally_focused(ai):
		return "ally"
	if ai.hurt_t < ai.grass_age:
		return "hit"  # tomando golpe mesmo escondido: esconder não está adiantando
	if ai.grass_strike_t >= 0.0:
		return ""
	if ai.intent != "" and f.pp_max >= BattleEnergy.MAX - 0.5 and ai.in_range(ai.intent, d):
		return "full"
	for o in f.arena.targets_of(f):
		if (f.pos2(o.position) - g.pos).length() < float(g.r) + 0.3:
			return "found"
	return ""


## Golpe de contato com energia e o alvo perto da moita: hora de sair atacando.
static func _strike_now(ai, d: float) -> bool:
	if ai.intent == "" or not ai.is_contact(ai.intent) or _short(ai):
		return false
	if float(ai.f.move_cd.get(ai.intent, 0.0)) > 0.5:
		return false
	return d <= ai.move_reach(ai.intent) + STRIKE_GAP


## 2x2: o parceiro está sendo atacado (tomou dano há pouco ou tem dois inimigos em cima dele).
static func ally_focused(ai) -> bool:
	var p: BattleFighter = ai.partner()
	if p == null:
		return false
	if p.ai != null and p.ai.hurt_t < ALLY_HURT:
		return true
	var n := 0
	for o in ai.f.arena.targets_of(ai.f):
		if o.opponent == p and o.flat_to(p).length() < ALLY_PRESS:
			n += 1
	return n >= 2


## Moita para a emboscada: perto, não além do alvo, sem inimigo dentro e de onde o alvo fica ao
## alcance (descansando, só perto e livre). A melhor junta perto de mim e perto do alcance.
static func _ambush_spot(ai, ter, d: float, retreating := false) -> Dictionary:
	var f: BattleFighter = ai.f
	var opp: BattleFighter = f.opponent
	var short := _short(ai)
	var reach: float = ai.move_reach(ai.intent) if ai.intent != "" else 6.0
	reach = 4.0 if reach == INF else minf(reach, 9.0)
	var near := GRASS_REST_MAX if short else GRASS_NEAR
	var me := f.pos2(f.position)
	var tp := f.pos2(opp.position)
	var best := {}
	var best_s := INF
	for g in ter.grass:
		var dm: float = (g.pos - me).length()
		var dt_: float = (g.pos - tp).length()
		if dm > near:
			continue
		if dm > d + GRASS_BEYOND and not (retreating and (g.pos - me).dot(tp - me) <= 0.0):
			continue  # além do alvo (recuando, vale a moita do lado oposto ao dele)
		if not short and dt_ > maxf(reach + USEFUL_GAP, USEFUL_MIN):
			continue
		var taken := false
		for o in f.arena.targets_of(f):
			if (
				is_instance_valid(o)
				and (f.pos2(o.position) - g.pos).length() < float(g.r) + FOE_NEAR
			):
				taken = true
		if taken:
			continue
		var s := dm + 0.5 * maxf(dt_ - reach * 0.8, 0.0)
		if s < best_s:
			best_s = s
			best = g
	return best


## Algum inimigo em campo tem golpe de Fogo que causa dano.
static func foe_has_fire(f: BattleFighter) -> bool:
	for o in f.arena.targets_of(f):
		if not is_instance_valid(o) or not o.active():
			continue
		for id in o.moves:
			var mv := Dex.move(String(id))
			if String(mv.get("type", "")) == "fire" and float(mv.get("power", 0)) > 0.0:
				return true
	return false


static func _likes_grass(f: BattleFighter) -> bool:
	return "grass" in f.types or f.profile in AMBUSH_PROFILES


## Direção para fora de um círculo (lago ou moita) pelo caminho mais curto.
static func _out_of(f: BattleFighter, area: Dictionary) -> Vector3:
	if area.is_empty():
		return Vector3.INF
	var away: Vector3 = f.pos2(f.position) - area.pos
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.RIGHT
	f.sprinting = f.can_sprint(true)
	return (away.normalized() + f.arena.edge_push(f) * 0.5).limit_length(1.0)


## Elétrico: com golpe Elétrico pronto e um inimigo dentro da água, mira nele com esse golpe.
static func _shock_target(ai, ter) -> void:
	var f: BattleFighter = ai.f
	var zap := ""
	for id in f.moves:
		var mv := Dex.move(String(id))
		if String(mv.get("type", "")) == "electric" and float(mv.get("power", 0)) > 0.0:
			if ai._ready(String(id)):
				zap = String(id)
				break
	if zap == "":
		return
	for o in f.arena.targets_of(f):
		if not is_instance_valid(o) or not o.active() or not ter.wet(o):
			continue
		if f.opponent != o:
			f.opponent = o
			ai.retarget_t = maxf(float(ai.retarget_t), SHOCK_RETARGET)
		if ai.intent != zap:
			ai.intent = zap
			ai.why = "shock_water"
			ter._tele("terrain_ai_shock", {"who": ter._uid(f), "tgt": ter._uid(o)})
		return
