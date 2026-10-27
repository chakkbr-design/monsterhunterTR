class_name BattlePlan
extends RefCounted
## Plano (estratégia) da IA: escolhido na entrada e reavaliado a cada PLAN_SECS s,
## sorteado por pesos (perfil, golpes, tipos, HP, energia, relevo, 1x1/2x2, ânimo, comando), com o
## melhor na frente mas sem ser sempre ele. O plano muda a faixa de distância, o recuo, a preferência de
## golpe e o alvo (BattleAI lê).
## - pressao: encosta e encadeia golpes baratos, quase não recua.
## - artilharia: fica no fim do alcance do golpe de longe (e no alto do morro, se tiver).
## - emboscada: espera atrás de cobertura (ou longe) e ataca com o alvo sem energia, de costas ou
##   recuperando.
## - desgaste: status primeiro, recua mais.
## - cacar: vai no alvo de HP mais baixo (2x2) e fica em cima dele.
## - proteger (2x2): fica entre o parceiro ferido e o inimigo mais perto dele.
##
## Memória do adversário (observe): cada IA conta os golpes que viu cada inimigo soltar (contato/investida,
## de longe, status) e guarda a velocidade recente dele (mira de área). Contra quem vive investindo
## (`foe_style` "dasher") fica mais longe, pronto para esquivar, e puxa artilharia; contra quem só
## atira ("ranged") encosta (pressão, caçar, emboscada na grama); contra quem vive de status, pressão.

const PRESS := "pressao"
const ARTILLERY := "artilharia"
const AMBUSH := "emboscada"
const ATTRITION := "desgaste"
const HUNT := "cacar"
const PROTECT := "proteger"
const ALL := [PRESS, ARTILLERY, AMBUSH, ATTRITION, HUNT, PROTECT]
## Reavalia a cada PLAN_SECS s (sorteado); o plano atual ganha STICKY no peso (não fica trocando à toa).
const PLAN_SECS := Vector2(6.0, 10.0)
const STICKY := 0.5
## Expoente dos pesos no sorteio: > 1 puxa para o plano mais forte sem tirar a chance dos outros.
const PICK_POW := 1.6
## Peso base de cada plano (antes do perfil e da situação).
const BASE_W := 1.0
## Faixa de distância (multiplicador) e recuo depois de bater (multiplicador) por plano.
const BAND := {PRESS: 0.75, ARTILLERY: 1.0, AMBUSH: 1.15, ATTRITION: 1.15, HUNT: 0.85, PROTECT: 1.0}
const RETREAT := {
	PRESS: 0.35, ARTILLERY: 1.0, AMBUSH: 1.1, ATTRITION: 1.25, HUNT: 0.5, PROTECT: 0.7
}
## Chance de, depois de bater, sair de lado em vez de recuar reto.
const SIDE_STEP := {
	PRESS: 0.7, ARTILLERY: 0.25, AMBUSH: 0.3, ATTRITION: 0.2, HUNT: 0.6, PROTECT: 0.4
}
## Artilharia: com golpe de longe, a faixa vai para ARTY_BAND (fração do alcance do golpe).
const ARTY_BAND := Vector2(0.72, 0.95)
## Emboscada: ataca quando o alvo tem menos de AMBUSH_EN de energia, está de costas (frente dele
## olhando para mim abaixo de AMBUSH_BACK) ou recuperando; esperou AMBUSH_MAX s, ataca assim mesmo.
const AMBUSH_EN := 35.0
const AMBUSH_BACK := 0.2
const AMBUSH_MAX := 5.0
const AMBUSH_KEEP := 1.3
## Preferência de golpe (multiplica a pontuação da escolha suave): pressão gosta do barato (custo até
## CHEAP_COST), artilharia do de longe e não do de contato, emboscada e caçar do mais forte.
const CHEAP_COST := 30.0
const CHEAP_BONUS := 0.25
const RANGED_BONUS := 0.2
const CONTACT_MALUS := 0.25
const STRONG_BONUS := 0.15
## Peso dos golpes de status: desgaste x STATUS_MORE, pressão e caçar x STATUS_LESS.
const STATUS_MORE := 1.8
const STATUS_LESS := 0.5
## Proteger: parceiro abaixo de PROTECT_HP; fica a até PROTECT_GAP m dele, na linha do inimigo.
const PROTECT_HP := 0.5
const PROTECT_GAP := 1.8
## Alvo com HP abaixo disso puxa caçar (e pressão).
const LOW_TARGET := 0.35
## Memória: confia no estilo do inimigo depois de MEM_MIN golpes vistos; "dasher" com MEM_DASH dos
## golpes de contato, "ranged" com MEM_RANGED de longe, "status" com MEM_STATUS de status. A faixa vai
## x MEM_FAR contra "dasher" (fora da pressão) e x MEM_CLOSE contra "ranged" (fora da artilharia).
## Velocidade lembrada: média com constante de tempo MEM_VEL_TAU s.
const MEM_MIN := 3
const MEM_DASH := 0.5
const MEM_RANGED := 0.7
const MEM_STATUS := 0.35
const MEM_FAR := 1.15
const MEM_CLOSE := 0.85
const MEM_VEL_TAU := 0.3
const MEM_CONTACT := ["dash", "arc", "multi_arc", "whip"]
const MEM_FAR_KINDS := ["projectile", "homing", "beam", "stream", "aoe_target", "zone"]


## Pesos de cada plano agora (0 = fora). `ai` é o BattleAI do lutador.
static func weights(ai) -> Dictionary:
	var f: BattleFighter = ai.f
	var w := {}
	for p in ALL:
		w[p] = BASE_W
	var contact := 0
	var ranged := 0
	var status := 0
	var cheap := 0
	for id in f.moves:
		var mv := Dex.move(String(id))
		if float(mv.get("power", 0)) <= 0.0:
			status += 1
			continue
		if ai.is_contact(String(id)):
			contact += 1
		elif ai.move_reach(String(id)) >= 4.0:
			ranged += 1
		if f.pp_cost_of(mv) <= CHEAP_COST:
			cheap += 1
	var n := maxf(contact + ranged, 1.0)
	w[PRESS] += 1.5 * contact / n + 0.3 * cheap
	w[ARTILLERY] += 1.8 * ranged / n
	w[ATTRITION] += 0.5 * status
	if ranged == 0:
		w[ARTILLERY] = 0.0
	if status == 0:
		w[ATTRITION] *= 0.4
	match f.profile:
		"brawler":
			w[PRESS] += 1.8
			w[HUNT] += 0.5
		"shooter":
			w[ARTILLERY] += 2.0
			w[AMBUSH] += 0.5
		"skirmisher":
			w[PRESS] += 0.8
			w[HUNT] += 0.8
			w[AMBUSH] += 0.8
		"wall":
			w[ATTRITION] += 1.2
			w[PROTECT] += 1.2
		"trickster":
			w[ATTRITION] += 1.5
			w[AMBUSH] += 1.0
		"flyer":
			w[ARTILLERY] += 0.8
			w[AMBUSH] += 1.2
	var hp := float(f.hp) / maxf(f.max_hp, 1)
	if hp < 0.4:
		w[AMBUSH] += 0.8
		w[ATTRITION] += 0.6
		w[PRESS] *= 0.6
	var opp := f.opponent
	if is_instance_valid(opp):
		var ohp := float(opp.hp) / maxf(opp.max_hp, 1)
		if ohp < LOW_TARGET:
			w[HUNT] += 1.5
			w[PRESS] += 0.8
		# Tipo: o melhor golpe tira quanto do alvo? Bom matchup puxa para cima dele; ruim, para longe.
		var best := 0.0
		for id in f.moves:
			best = maxf(best, ai._dmg(String(id)) / maxf(float(opp.hp), 1.0))
		if best >= 0.3:
			w[PRESS] += 0.7
			w[HUNT] += 0.5
		elif best < 0.12:
			w[ATTRITION] += 0.7
			w[AMBUSH] += 0.5
	if f.pp_max < AMBUSH_EN:
		w[AMBUSH] += 0.4
	var ter = f.arena.get("terrain")
	if ter != null and not ter.obstacles.is_empty():
		w[ARTILLERY] += 0.6 if w[ARTILLERY] > 0.0 else 0.0
		if ter.has_cover():
			w[AMBUSH] += 0.6
	match foe_style(ai, opp):
		"dasher":
			w[ARTILLERY] += 0.8 if w[ARTILLERY] > 0.0 else 0.0
			w[ATTRITION] += 0.3
			w[PRESS] *= 0.8
		"ranged":
			w[PRESS] += 1.0
			w[HUNT] += 0.4
			w[AMBUSH] += 0.4
			w[ARTILLERY] *= 0.7
		"status":
			w[PRESS] += 0.5
	var mates := ai.partner() != null
	var foes: int = f.arena.targets_of(f).size()
	if mates and ai._partner_hurt():
		w[PROTECT] += 2.0
	if not mates:
		w[PROTECT] = 0.0
	if foes >= 2:
		w[HUNT] += 0.8
	elif is_instance_valid(opp) and float(opp.hp) / maxf(opp.max_hp, 1) >= LOW_TARGET:
		w[HUNT] *= 0.5  # 1x1: caçar só faz sentido com o alvo fraco
	match f.mood_state:
		"fury":
			w[PRESS] += 2.0
			w[HUNT] += 1.0
		"panic":
			w[AMBUSH] += 1.0
			w[ATTRITION] += 0.8
	match ai.ally_mode():
		BattleAI.ATTACK:
			w[PRESS] += 1.2
			w[HUNT] += 0.8
		BattleAI.DEFEND:
			w[PROTECT] += 1.0 if mates else 0.0
			w[ATTRITION] += 0.5
		BattleAI.SUPPORT:
			w[ATTRITION] += 1.0
			w[PROTECT] += 0.8 if mates else 0.0
	if ai.plan != "" and float(w.get(ai.plan, 0.0)) > 0.0:
		w[ai.plan] += STICKY
	return w


## Sorteia um plano pelos pesos (peso ^ PICK_POW).
static func choose(ai) -> String:
	var w := weights(ai)
	var tot := 0.0
	for p in w:
		tot += pow(maxf(float(w[p]), 0.0), PICK_POW)
	if tot <= 0.0:
		return PRESS
	var r: float = ai._rng().randf() * tot
	for p in ALL:
		r -= pow(maxf(float(w[p]), 0.0), PICK_POW)
		if r <= 0.0:
			return p
	return PRESS


## Multiplicador da pontuação de um golpe de dano pelo plano.
static func move_bonus(ai, id: String) -> float:
	var f: BattleFighter = ai.f
	var mv := Dex.move(id)
	match String(ai.plan):
		PRESS:
			return 1.0 + (CHEAP_BONUS if f.pp_cost_of(mv) <= CHEAP_COST else 0.0)
		ARTILLERY:
			return 1.0 - CONTACT_MALUS if ai.is_contact(id) else 1.0 + RANGED_BONUS
		AMBUSH, HUNT:
			return 1.0 + STRONG_BONUS * clampf(float(mv.get("power", 0)) / 100.0, 0.0, 1.5)
	return 1.0


## Multiplicador do peso dos golpes de status pelo plano.
static func status_mult(plan: String) -> float:
	match plan:
		ATTRITION:
			return STATUS_MORE
		PRESS, HUNT:
			return STATUS_LESS
	return 1.0


## Memória: conta os golpes novos de cada inimigo em campo (pelo cast_n) e atualiza a velocidade média.
static func observe(ai, dt: float) -> void:
	var k := 1.0 - exp(-dt / MEM_VEL_TAU)
	for o in ai.f.arena.targets_of(ai.f):
		var id: int = o.get_instance_id()
		var v := Vector3(o.velocity.x, 0.0, o.velocity.z)
		if not ai.foe_mem.has(id):
			ai.foe_mem[id] = {"n": 0, "dash": 0, "ranged": 0, "status": 0, "seen": o.cast_n, "v": v}
			continue
		var m: Dictionary = ai.foe_mem[id]
		m.v = (m.v as Vector3).lerp(v, k)
		if o.cast_n == int(m.seen):
			continue
		m.seen = o.cast_n
		var mv: Dictionary = o.cast_move
		m.n += 1
		if String(mv.get("category", "")) == "status" or float(mv.get("power", 0)) <= 0.0:
			m.status += 1
		elif String(mv.get("kind", "")) in MEM_CONTACT:
			m.dash += 1
		elif String(mv.get("kind", "")) in MEM_FAR_KINDS:
			m.ranged += 1


## Estilo lembrado do inimigo: "" (pouco visto ou misto), "dasher", "ranged" ou "status".
static func foe_style(ai, o) -> String:
	if not is_instance_valid(o):
		return ""
	var m: Dictionary = ai.foe_mem.get(o.get_instance_id(), {})
	var n := int(m.get("n", 0))
	if n < MEM_MIN:
		return ""
	if float(m.dash) / n >= MEM_DASH:
		return "dasher"
	if float(m.ranged) / n >= MEM_RANGED:
		return "ranged"
	if float(m.status) / n >= MEM_STATUS:
		return "status"
	return ""


## Velocidade recente do inimigo (lembrada; sem memória ainda, a de agora).
static func foe_velocity(ai, o) -> Vector3:
	var m: Dictionary = ai.foe_mem.get(o.get_instance_id(), {})
	if m.has("v"):
		return m.v
	return Vector3(o.velocity.x, 0.0, o.velocity.z)


## Multiplicador da faixa de distância pela memória do alvo: longe de quem investe, perto de quem atira.
static func memory_band(ai) -> float:
	match foe_style(ai, ai.f.opponent):
		"dasher":
			return 1.0 if ai.plan == PRESS else MEM_FAR
		"ranged":
			return 1.0 if ai.plan == ARTILLERY else MEM_CLOSE
	return 1.0
