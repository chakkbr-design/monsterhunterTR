class_name BattleTerrainAI
extends RefCounted
## IA do cenário no modo de energia (BattleTerrain): um gancho só, chamado do começo de
## BattleAI._energy_steer. Não decide golpe nem faixa; só puxa o lutador para o lugar certo do cenário:
##
## - Fogo dentro do lago sai da água (lá ele toma dano e quase não recupera energia).
## - Na grama alta com inimigo que tem golpe de Fogo: sai da moita (ela pode pegar fogo com ele dentro).
## - Elétrico com golpe pronto: alvo dentro da água vira o alvo e o golpe Elétrico vira a intenção.
## - Precisando descansar, quem é de Grama ou do perfil Trapaceiro (emboscada) se esconde na grama alta
##   (recupera mais, golpe de longe erra mais) e espera lá; sem Fogo do outro lado.
##
## Devolve a direção desejada ou Vector3.INF (segue a IA normal).

const GRASS_REST_MAX := 7.0  ## distância máxima até a moita para ir descansar nela
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
	if fire_foe or not _likes_grass(f) or not _needs_rest(ai):
		return Vector3.INF
	var g: Dictionary = _grass_spot(f, ter)
	if g.is_empty():
		return Vector3.INF
	var to: Vector3 = g.pos - f.pos2(f.position)
	ai.tag = "rest_grass"
	ai._fly(d)
	if to.length() < float(g.r) * GRASS_STAY:
		return Vector3.ZERO  # escondido: espera a barra encher
	f.sprinting = to.length() > 3.0 and f.can_sprint(true)
	return to.normalized() * clampf(to.length(), 0.3, 1.0)


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


## Mesma conta do _energy_steer: o golpe pretendido falta energia e o lutador não é dos que seguem lutando.
static func _needs_rest(ai) -> bool:
	if ai.intent == "" or ai.recover_t > 0.0:
		return false
	var f: BattleFighter = ai.f
	var need := BattleEnergy.secs_to(f, f.pp_cost_of(Dex.move(ai.intent)))
	return need > BattleAI.ENERGY_WAIT and not ai._stays_fighting()


## Moita mais perto (até GRASS_REST_MAX m) sem inimigo dentro.
static func _grass_spot(f: BattleFighter, ter) -> Dictionary:
	var best := {}
	var best_d := GRASS_REST_MAX
	for g in ter.grass:
		var d: float = (g.pos - f.pos2(f.position)).length()
		if d >= best_d:
			continue
		var taken := false
		for o in f.arena.targets_of(f):
			if is_instance_valid(o) and (o.pos2(o.position) - g.pos).length() < float(g.r) + 1.0:
				taken = true
		if not taken:
			best_d = d
			best = g
	return best


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
