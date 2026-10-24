class_name BattleAI
extends RefCounted
## IA de luta (Batalha Viva): escolhe o golpe que quer usar (intenção), anda até a faixa de distância
## dele, bate e recua pelo perfil (BattleProfile); obedece ao comando do treinador (Ofensivo, Defensivo,
## Suporte, Livre); desvia de golpe avisado (área, raio, projétil, investida) com reação pela Speed;
## Fúria ou Pânico com HP baixo pela Natureza. Mantém do original o golpe com menos acertos até o KO,
## punição na recuperação do oponente, pulo contra dash/terremoto e sprint ao se aproximar.

const THINK_MIN := 1.2
const THINK_MAX := 2.0
const THINK_RETRY := 0.25
const RECOVER := 0.5
const LOW_HP := 0.35
const KITE_MULT := 1.5
const MELEE_BAND := 3.6
const FAR_GAP := 2.0
const BAND_MAX := 3.5
const BAND_NEAR_RATIO := 0.7
const TACTIC_MISS_MULT := 1.5
const DODGE_TIME := 0.35
const WAIT_STRAFE := 0.6
const WAIT_RADIAL := 0.35
const JUMP_SHARP := 0.8
const JUMP_ERR := 0.44
const JUMP_ERR_SLOPE := 0.28
const JUMP_MISS_LIN := 0.54
const JUMP_MISS_QUAD := 0.475
const JUMP_MISS_MAX := 0.52
const JUMP_LATE := 0.25
const JUMP_CLEAR := 0.95
const SPRINT_REACT := 0.35
const SLOP_BASE := 0.8
const SLOP_MAX := 1.0
const SLOP_KNEE := 1.3
const SLOP_KNEE_VALUE := 0.8
const KIT_LOW_HP := 0.5
const KIT_STAT_DEPTH := 2
const KIT_STAT_SLOP := 0.4
const TRAINER_ITEM_HP := 0.35
const TARGET_FINISH_HP := 0.35
const TARGET_STICKY := 0.5
const GUARD_DIST := 1.5
const ATTACK_THINK := 0.75
const DEFEND_BUFF_CHANCE := 0.5
## Física Gen 9: investida longa (dash com alcance >= RUSH_MIN) fecha a distância de longe; golpe de área
## na dupla quando pega os dois e rende AREA_PREF x o melhor de alvo único.
const RUSH_MIN := 6.0
const RUSH_FROM := 4.5
const RUSH_CHANCE := 0.7
const AREA_PREF := 1.25
## Reação a golpe avisado: base (s) dividida pelo fator de Speed e vezes think_scale.
const REACT_BASE := 0.28
const DODGE_RUN := 0.45
const PROJ_LOOK := 4.5
## HP baixo: Fúria (agressivo) ou Pânico (medroso) pela Natureza; neutro tira a sorte.
const MOOD_HP := 0.25
const FURY_THINK := 0.6
const PANIC_THINK := 1.3
## Variação de ritmo para a luta não ficar previsível (+-5%).
const JITTER := 0.05
const STALL_SECS := 6.0
## Status com bom senso (jogador competitivo): golpe de parceiro só com parceiro vivo, buff até +2,
## debuff até -2, Focus Energy uma vez, peso por golpe e, depois de um status, STATUS_LOCK s preferindo
## atacar (só o urgente passa: Protect diante de ameaça, cura com HP muito baixo).
const PARTNER_MOVES := ["helping_hand", "follow_me", "rage_powder", "after_you", "quick_guard"]
const ONCE_MOVES := ["focus_energy"]
const LOW_VALUE_MOVES := ["sweet_scent", "worry_seed", "splash", "sand_attack", "smokescreen"]
const BUFF_CAP := 2
const DEBUFF_CAP := -2
const STATUS_LOCK := Vector2(4.0, 6.0)
const URGENT_HP := 0.35
const STATUS_W_SETUP := 0.4
const STATUS_W_BASE := 0.25
const STATUS_W_LOW := 0.08
const SETUP_STATS := ["atk", "spa", "spe"]
## Status sem golpe de dano pronto: peso x FILLER_MULT. Recusou todos: DECLINE_LOCK s sem rolar de novo.
const FILLER_MULT := 2.0
const DECLINE_LOCK := 1.5
## Comando: Ofensivo encurta a faixa e o recuo; Defensivo alonga e esquiva melhor.
const CMD_BAND := [0.75, 1.25, 1.35, 1.0]
const CMD_RETREAT := [0.4, 1.5, 1.2, 1.0]
const CMD_DODGE := [0.0, 0.2, 0.1, 0.0]
## Rodadas (BattleTurns): na vez, mira AIM_BASE s (x pensamento) antes de soltar.
const AIM_BASE := 0.15
## Posição fixa (rodadas): perto de HOME_NEAR m só balança; longe de HOME_RUN m corre de volta.
const HOME_NEAR := 0.35
const HOME_RUN := 1.0
const CONTACT_KINDS := ["dash", "arc", "multi_arc", "whip", "lunge", "aoe_self"]
## Longe da parede (m) e espaço mínimo de aliado e de inimigo (todos os lutadores, não só o parceiro).
const WALL_KEEP := 2.0
const SPACE_ALLY := 2.4
const SPACE_FOE := 1.8
## Encurralado: a menos de CORNER_M da parede com inimigo a menos de CORNER_FOE foge rodeando.
const CORNER_M := 1.6
const CORNER_FOE := 3.2
## Depois de bater perto da parede volta para o centro.
const CENTRE_PULL := 0.7
## Modo de energia (BattleEnergy): recua para recuperar quando o golpe pretendido ainda leva mais de
## ENERGY_WAIT s para ter energia; volta a fechar a distância quando a caminhada até o alcance cobre a
## espera. REPEAT_AVOID = chance de não repetir o último golpe quando há outro pronto.
const ENERGY_WAIT := 0.8
const ENERGY_KEEP := 1.0
const REPEAT_AVOID := 0.8
## Comandos (iguais aos da arena): Ofensivo, Defensivo, Suporte, Livre (perfil decide).
enum { ATTACK, DEFEND, SUPPORT, FREE }

var f: BattleFighter
var retarget_t := 0.0
var think_scale := 1.0
var think := 0.0
var recover_t := 0.0
var punished := false
var tactic_on := true
var dodge_t := 0.0
var strafe := 1.0
var jump_threat := ""
var jump_at := 0.0
var jump_done := false
var sprint_want := false
var sprint_seen := false
var react_t := 0.0
var intent := ""
var retreat_t := 0.0
var threat_id := -1
var threat_ok := false
var threat_wait := 0.0
var auto_cmd_t := 0.0
## Segundos sem soltar golpe: passado STALL_SECS para de fugir e vai para cima (sem empate eterno).
var idle_t := 0.0
## Depois de um golpe de status: segundos em que só o status urgente passa.
var status_lock_t := 0.0
## Golpes de uma vez por luta já usados (Focus Energy).
var used_once := {}
## Rodadas: tempo mirando na vez, rodadas vistas.
var aim_t := 0.0
var round_k := 0
var fired := false
var acted_round := -1
## Voltando para a posição depois de bater (rodadas) / protegendo o parceiro (DEFENSIVO) fora dela.
var returning := false
## Último golpe solto (modo de energia evita repetir).
var last_move := ""
var guarding := false
## Escolha de golpe e alvo no estilo VGC (BattleTactics); null no selvagem e com opts.vgc_ai = false.
var tactics: BattleTactics = null
var _tactics_checked := false


func _init(fighter: BattleFighter) -> void:
	f = fighter


func _rng() -> RandomNumberGenerator:
	return f.arena.rng


func error_chance() -> float:
	if think_scale <= SLOP_BASE:
		return 0.0
	if think_scale <= SLOP_KNEE:
		var t := (think_scale - SLOP_BASE) / (SLOP_KNEE - SLOP_BASE)
		return SLOP_KNEE_VALUE * t * t * (3.0 - 2.0 * t)
	return lerpf(
		SLOP_KNEE_VALUE, SLOP_MAX, clampf((think_scale - SLOP_KNEE) / (1.6 - SLOP_KNEE), 0.0, 1.0)
	)


func _jump_error() -> float:
	return maxf(JUMP_ERR + JUMP_ERR_SLOPE * (think_scale - JUMP_SHARP), 0.0)


func _jump_miss() -> float:
	var d := maxf(think_scale - JUMP_SHARP, 0.0)
	return minf(JUMP_MISS_MAX, JUMP_MISS_LIN * d + JUMP_MISS_QUAD * d * d)


func _tactic_ok() -> bool:
	return _rng().randf() >= minf(1.0, _jump_miss() * TACTIC_MISS_MULT)


func in_range(id: String, d: float) -> bool:
	var mv := Dex.move(id)
	match String(mv.get("kind", "")):
		"dash", "arc", "multi_arc", "whip":
			return d < float(mv.get("range", 2.0)) + 0.6
		"aoe_self", "debuff_aoe":
			return d < float(mv.get("radius", 3.0))
		"stream":
			return d < float(mv.get("range", 5.0))
		"self_buff", "clones":
			return true
		_:
			return d < float(mv.get("range", 10.0))


func reach() -> float:
	var r := 0.0
	for id in f.moves:
		var mv := Dex.move(id)
		if float(mv.get("power", 0)) <= 0.0:
			continue
		match String(mv.get("kind", "")):
			"dash", "arc", "multi_arc", "whip":
				r = maxf(r, float(mv.get("range", 2.0)) + 0.6)
			"aoe_self":
				r = maxf(r, float(mv.get("radius", 3.0)))
			_:
				r = maxf(r, minf(float(mv.get("range", 10.0)), 6.0))
	return r


func band() -> Vector2:
	var r := reach()
	if r <= 0.0:
		return Vector2(1.8, 3.0)
	var far := minf(r * 0.9, BAND_MAX)
	return Vector2(far * BAND_NEAR_RATIO, far)


func move_ready(d: float) -> bool:
	if f.moves.is_empty() or f.gcd_t > 0.0:
		return false
	for id in f.moves:
		if float(f.move_cd.get(id, 0.0)) <= 0.0 and in_range(id, d):
			return true
	return false


## Um passo de IA: devolve a direção desejada e ajusta f.sprinting; pode disparar golpes.
## Com a fila de rodadas (BattleTurns) só solta golpe na vez dele; fora dela escolhe um ponto no campo.
func step(dt: float) -> Vector3:
	f.sprinting = false
	status_lock_t = maxf(status_lock_t - dt, 0.0)
	pick_target(dt)
	_auto_command(dt)
	var opp := f.opponent
	if not is_instance_valid(opp) or not opp.active():
		return Vector3.ZERO
	var turns = f.arena.get("turns")
	var queued: bool = turns != null and turns.on and turns.tracked(f)
	var my_turn: bool = not queued or turns.can_fire(f)
	var up_next: bool = queued and turns.is_turn(f)
	if want_trainer_item() and my_turn:
		use_trainer_item()
		recover_t = RECOVER
		if queued:
			turns.done(f, "item")
		return Vector3.ZERO
	if f.status == "sleep":
		if my_turn and _sleep_move(f.flat_to(opp).length()) and queued:
			turns.done(f, "move")
		return Vector3.ZERO
	_mood()
	var to_o := f.flat_to(opp)
	var d := to_o.length()
	var dir := to_o / maxf(d, 0.001)
	var mode := ally_mode()
	if _rng().randf() < 0.004 * float(_p("strafe", 0.5)) + 0.001:
		strafe *= -1.0
	var side_v := Vector3(-dir.z, 0.0, dir.x) * strafe
	var dodge := _dodge(dt, d, side_v)
	if dodge != Vector3.ZERO:
		f.sprinting = f.can_sprint(true)
		return dodge
	if recover_t > 0.0:
		recover_t -= dt
		think -= dt
		retreat_t -= dt
		return _retreat_move(dir, side_v, d)
	if not f.moves.is_empty():
		if queued:
			if my_turn:
				_turn_fire(dt, d, turns)
		else:
			_free_fire(dt, d)
	if f.out_of_pp() and d > 1.4 and (not queued or up_next):
		return dir
	if queued and not up_next:
		return _off_turn(dt, d, dir, side_v)
	if f.energy_mode and not queued:
		var ew := _energy_steer(d, dir, side_v)
		if ew != Vector3.INF:
			return ew
	if queued:
		return _turn_move(dt, d, dir, side_v)
	if mode == DEFEND or (mode == FREE and bool(_p("guard", false)) and _partner_hurt()):
		var guard := guard_steer()
		if guard != Vector3.INF:
			return guard
	idle_t += dt
	var stall := idle_t > STALL_SECS and not queued
	var b := _band() * (0.7 if stall else 1.0)
	var low := float(f.hp) <= float(f.max_hp) * LOW_HP and not stall and not queued
	var kite := Vector2(b.x * 1.2, b.y * KITE_MULT) if low and f.mood_state != "fury" else b
	var slip := opp.root_t > 0.0 and d < b.y + 1.0 and intent == "" and not queued
	var want: Vector3
	var st := float(_p("strafe", 0.5))
	if slip:
		want = (side_v - dir * 0.4).normalized()
	elif d > kite.y:
		want = (dir + side_v * 0.3 * st).normalized()
	elif d < kite.x:
		want = (-dir + side_v * 0.5).normalized() * (1.0 if low else 0.8)
	elif intent != "" and in_range(intent, d) and (tactic_on or queued):
		want = side_v * (0.0 if queued else 0.15 * st)
	elif tactic_on:
		var centre := (b.x + b.y) * 0.5
		var radial := dir * clampf((centre - d) / maxf(b.y - b.x, 0.1), -1.0, 1.0)
		want = (side_v * (0.3 + WAIT_STRAFE * st) + radial * WAIT_RADIAL).normalized()
	else:
		want = side_v * 0.35
	want += f.arena.edge_push(f) + (_spread_all(true) if queued else _ally_spread())
	if want.length() > 1.0:
		want = want.normalized()
	_fly(d)
	var r := reach()
	var closing := d > kite.y and (r <= MELEE_BAND or d > r + FAR_GAP)
	var reason := (closing and float(_p("sprint", 1.0)) >= 0.5) or slip or (low and d < b.y)
	if (mode == ATTACK or stall or up_next) and d > b.y:
		reason = true
	if _try_jump(dt, d):
		return want
	f.sprinting = _sprint(dt, reason) and f.can_sprint(want.length() > 0.1)
	return want


## Ritmo antigo (fila desligada): pensa THINK_MIN-MAX s, solta quando o golpe está pronto e ao alcance,
## pune a recuperação do oponente.
func _free_fire(dt: float, d: float) -> void:
	var opp := f.opponent
	var mode := ally_mode()
	var punish := _punish(d)
	if not punish:
		punished = false
	think -= dt
	if think <= 0.0 and intent == "":
		intent = _plan()
		if intent == "":
			think = THINK_RETRY * think_scale
	var rush := _rush_move(d)
	if rush != "":
		intent = rush
	var fire := intent != "" and in_range(intent, d) and _ready(intent) and _reaches(opp, intent)
	if punish and not punished and tactic_on:
		fire = true
		punished = true
	# Sem PP: Desespero de perto (os dois sem PP ficavam rodando sem bater até o fim do tempo).
	if f.out_of_pp() and d < 2.2:
		fire = true
	if fire and f.can_act():
		tactic_on = _tactic_ok()
		if _use_best_move(d):
			_after_fire(mode)
		elif intent != "" and not _ready(intent):
			intent = ""


## Vez dele na fila: refaz a intenção se ela não está pronta, para, mira (AIM_BASE pelo pensamento) e
## solta. Sem nada pronto passa a vez; sem PP vai no Desespero de perto.
func _turn_fire(dt: float, d: float, turns) -> void:
	aim_t += dt
	if not f.can_act():
		return
	if not fired and think > 0.0:
		think -= dt  # segura a abertura (o selvagem e a bola do treinador) como no ritmo antigo
		return
	if f.out_of_pp():
		if d < 2.2 and f.struggle():
			idle_t = 0.0
			recover_t = RECOVER
			turns.done(f, "struggle")
		return
	if intent == "" or not _ready(intent) or not status_ok(intent, _has_connecting_move()):
		intent = _plan()
		if intent == "":
			# Fôlego voltando ou cooldown acabando dentro da vez: espera; senão passa a vez.
			if not _ready_soon(maxf(BattleTurns.TURN_MAX - turns.turn_t, 0.0)):
				turns.pass_turn(f)
			return
	var rush := _rush_move(d)
	if rush != "":
		intent = rush
	if aim_t < _aim_secs():
		return
	if not (in_range(intent, d) and _ready(intent) and _reaches(f.opponent, intent)):
		return
	tactic_on = _tactic_ok()
	if _use_best_move(d):
		turns.done(f, "move")
		_after_fire(ally_mode())


## Algum golpe fica pronto em `secs` s (cooldown e GCD acabam; o fôlego volta sozinho).
func _ready_soon(secs: float) -> bool:
	for id in f.moves:
		var mv := Dex.move(String(id))
		if mv.is_empty() or f.pp_max < f.pp_cost_of(mv):
			continue
		if not f.arena.moves.effects.usable(f, mv):
			continue
		if maxf(float(f.move_cd.get(id, 0.0)), f.gcd_t) < secs:
			return true
	return false


func _after_fire(mode: int) -> void:
	fired = true
	returning = true
	var turns = f.arena.get("turns")
	acted_round = turns.round_n if turns != null else -1
	idle_t = 0.0
	think = _think_secs()
	retreat_t = (
		float(_p("retreat", 0.5)) * CMD_RETREAT[mode] * (0.3 if f.mood_state == "fury" else 1.0)
	)
	recover_t = maxf(recover_t, retreat_t)
	intent = ""


## Começo da vez (BattleTurns): zera a mira.
func on_turn() -> void:
	aim_t = 0.0


## Tempo parado mirando antes de soltar na vez (pensamento, perfil, comando e ânimo).
func _aim_secs() -> float:
	var k := think_scale * float(_p("think", 1.0))
	if ally_mode() == ATTACK:
		k *= ATTACK_THINK
	if f.mood_state == "fury":
		k *= FURY_THINK
	return AIM_BASE * k


func _think_secs() -> float:
	var k := think_scale * float(_p("think", 1.0))
	if ally_mode() == ATTACK:
		k *= ATTACK_THINK
	if f.mood_state == "fury":
		k *= FURY_THINK
	elif f.mood_state == "panic":
		k *= PANIC_THINK
	return (
		_rng().randf_range(THINK_MIN, THINK_MAX) * k * (1.0 + _rng().randf_range(-JITTER, JITTER))
	)


## Golpe pronto (cooldown e GCD), sem olhar a distância.
func _ready(id: String) -> bool:
	return (
		f.gcd_t <= 0.0 and float(f.move_cd.get(id, 0.0)) <= 0.0 and f.arena.moves.can_afford(f, id)
	)


## Começo da rodada (BattleTurns): escolhe a intenção que entra na fila (a prioridade dela conta) e
## um ponto novo no campo; o Voador troca de altura.
func plan_round() -> void:
	if is_instance_valid(f.opponent) and f.opponent.active():
		intent = _plan()
	round_k += 1


## Intenção: o golpe que vai buscar agora (o mesmo critério de pick, sem olhar a distância).
func _plan() -> String:
	if f.out_of_pp():
		return ""
	var avail: Array = f.moves.filter(func(id): return _ready(String(id)))
	if f.energy_mode:
		# Energia: planeja também o golpe que ainda falta energia (recua até ter).
		avail = f.moves.filter(
			func(id):
				return (
					float(f.move_cd.get(id, 0.0)) <= 0.0
					and f.arena.moves.effects.usable(f, Dex.move(String(id)))
				)
		)
	if avail.is_empty():
		return ""
	if _immune_only(avail) and _has_connecting_move():
		avail = avail.filter(func(id): return _dmg(id) > 0.0)
		if avail.is_empty():
			return ""
	return pick(avail)


## Faixa de distância: a do golpe pretendido; sem intenção, a do perfil. Comando e ânimo mexem nela.
func _band() -> Vector2:
	var pb: Vector2 = _p("band", Vector2(1.8, 3.0))
	var b := pb
	if intent != "":
		var r := move_reach(intent)
		if r < INF:
			var hi := maxf(r * 0.85, 0.7)
			b = Vector2(minf(pb.x, hi * 0.6), minf(maxf(pb.y, hi * 0.7), hi))
	var mode := ally_mode()
	b *= CMD_BAND[mode]
	if mode == SUPPORT:
		b = Vector2(maxf(b.x, 3.5), maxf(b.y, 5.0))
	if f.mood_state == "fury":
		b *= 0.7
	elif f.mood_state == "panic":
		b *= 1.4
	b.x = maxf(b.x, 0.6)
	b.y = maxf(b.y, b.x + 0.5)
	return b


## Até onde o golpe chega (INF = buff, não precisa de distância).
func move_reach(id: String) -> float:
	var mv := Dex.move(id)
	match String(mv.get("kind", "")):
		"dash", "arc", "multi_arc", "whip":
			return float(mv.get("range", 2.0)) + 0.6
		"aoe_self", "debuff_aoe":
			return float(mv.get("radius", 3.0))
		"stream":
			return float(mv.get("range", 5.0))
		"self_buff", "clones":
			return INF
		_:
			return float(mv.get("range", 10.0))


## Modo de energia: planeja a posição pela próxima ação. Golpe pretendido sem energia: quem fica
## lutando (Fúria, OFENSIVO, alvo quase caindo, perfil que não recua) troca por um golpe que já dá;
## os outros recuam para longe dos inimigos (descansar enche mais rápido) e só voltam quando a
## caminhada até o alcance cobre o que falta encher. INF = segue a faixa normal.
func _energy_steer(d: float, dir: Vector3, side_v: Vector3) -> Vector3:
	if intent == "" or recover_t > 0.0:
		return Vector3.INF
	var need := BattleEnergy.secs_to(f, f.pp_cost_of(Dex.move(intent)))
	if need <= ENERGY_WAIT:
		return Vector3.INF
	if _stays_fighting():
		var cheap: Array = f.moves.filter(
			func(id):
				return (
					String(id) != intent
					and float(Dex.move(String(id)).get("power", 0)) > 0.0
					and _ready(String(id))
				)
		)
		if not cheap.is_empty():
			intent = pick(cheap)
			return Vector3.INF
	var r := move_reach(intent)
	r = 0.0 if r == INF else r
	var travel := maxf(d - r * 0.8, 0.0) / maxf(f.walk_speed(), 0.1)
	if travel >= need:
		return Vector3.INF  # já dá para ir: chega no alcance com a barra cheia o bastante
	var keep := BattleEnergy.REST_DIST + ENERGY_KEEP
	var want: Vector3
	if d < keep:
		want = (-dir + side_v * 0.5 * float(_p("strafe", 0.5))).normalized()
		if _wall_dist(f.pos2(f.position)) < WALL_KEEP:
			var esc := corner_escape()
			want = (want + (esc if esc != Vector3.ZERO else _to_centre())).normalized()
		f.sprinting = f.can_sprint(true)
	else:
		# Longe o bastante: rodeia devagar, de olho no alvo.
		want = side_v * 0.45 + dir * clampf((d - keep - 1.0) * 0.3, -0.3, 0.3)
	want += f.arena.edge_push(f) + _ally_spread()
	_fly(d)
	return want.normalized() if want.length() > 1.0 else want


func _stays_fighting() -> bool:
	if f.mood_state == "fury" or ally_mode() == ATTACK:
		return true
	var opp := f.opponent
	if is_instance_valid(opp) and float(opp.hp) <= float(opp.max_hp) * TARGET_FINISH_HP:
		return true
	return float(_p("retreat", 0.5)) < 0.3


## Depois de bater: recua até retreat_to pelo perfil (o Brigão quase não recua; o Atirador some).
func _retreat_move(dir: Vector3, side_v: Vector3, d: float) -> Vector3:
	if not f.can_act():
		return Vector3.ZERO
	var turns = f.arena.get("turns")
	if turns != null and turns.on and turns.tracked(f):
		return _go_home(side_v)  # rodadas: depois de bater volta para a posição dele
	if retreat_t <= 0.0:
		return Vector3.ZERO
	var to: float = float(_p("retreat_to", 3.0)) * CMD_BAND[ally_mode()]
	if d >= to:
		return side_v * 0.5
	var w := (-dir + side_v * 0.6 * float(_p("strafe", 0.5))).normalized()
	# Quem bateu perto da parede (ou encurralou alguém) volta para o centro, rodeando o alvo.
	if _wall_dist(f.pos2(f.position)) < WALL_KEEP + 1.0:
		w = (w + _to_centre() * CENTRE_PULL * 1.5).normalized()
	w += f.arena.edge_push(f)
	return w.normalized() if w.length() > 1.0 else w


## Voador: cruza alto e desce para atacar ou esperando a recarga.
func _fly(_d: float) -> void:
	var h := float(_p("fly", 0.0))
	if h <= 0.0:
		f.fly_target = 0.0
		return
	var tired := f.gcd_t > 0.0
	var turns = f.arena.get("turns")
	var low := false
	if turns != null and turns.on:
		# Rodadas: voa alto numa rodada e baixo na outra; desce para a vez dele e fica baixo depois de
		# bater até a rodada acabar (quem está no chão também tem a chance dele).
		low = turns.is_turn(f) or round_k % 2 == 0 or acted_round == turns.round_n
	f.fly_target = BattleFighter.DIVE_H if tired or recover_t > 0.0 or low else h


## Em dupla os parceiros não se embolam: empurra para longe do parceiro perto demais.
func _ally_spread() -> Vector3:
	var p := partner()
	if p == null:
		return Vector3.ZERO
	var to := f.flat_to(p)
	var dd := to.length()
	if dd > 2.2 or dd < 0.01:
		return Vector3.ZERO
	return -to / dd * (2.2 - dd) * 0.5


func partner() -> BattleFighter:
	for o in f.arena.fighters:
		if o != f and is_instance_valid(o) and o.side == f.side and o.active():
			return o
	return null


func _partner_hurt() -> bool:
	var p := partner()
	return p != null and float(p.hp) < float(p.max_hp) * 0.5


## HP baixo: uma vez por luta entra em Fúria (agressivo) ou Pânico (medroso) pela Natureza.
func _mood() -> void:
	if f.mood_state != "" or float(f.hp) > float(f.max_hp) * MOOD_HP or not f.alive():
		return
	var t := BattleProfile.temper(f.mon)
	if t == 0:
		t = 1 if _rng().randf() < 0.5 else -1
	f.mood_state = "fury" if t > 0 else "panic"
	if f.mood_state == "fury":
		f.popup("FÚRIA!", Color(1, 0.35, 0.25), 1.2, 0.9)
	else:
		f.popup("PÂNICO!", Color(0.6, 0.75, 1.0), 1.2, 0.9)
	if f.arena.has_method("say"):
		f.arena.say(
			(
				"%s entrou em %s!"
				% [f.mon.display_name, "fúria" if f.mood_state == "fury" else "pânico"]
			)
		)


## Treinador adversário (e o lado A no autoplay) troca o comando sozinho a cada 5-8 s pela situação.
func _auto_command(dt: float) -> void:
	if f.side == 0 and f.arena.get("ally") == f:
		return
	if f.side == 0 and f.arena.get("player") == f and f.arena.get("player_mode") != null:
		return
	if f.arena.get("kind") == "wild":
		f.command = FREE
		return
	auto_cmd_t -= dt
	if auto_cmd_t > 0.0:
		return
	auto_cmd_t = _rng().randf_range(5.0, 8.0)
	var hp := float(f.hp) / maxf(f.max_hp, 1)
	var opp := f.opponent
	var cmd := FREE
	if hp < 0.3:
		cmd = DEFEND
	elif is_instance_valid(opp) and float(opp.hp) / maxf(opp.max_hp, 1) < 0.35:
		cmd = ATTACK
	elif _partner_hurt() and f.moves.any(func(id): return is_support_move(String(id))):
		cmd = SUPPORT
	elif _rng().randf() < 0.3:
		cmd = ATTACK
	if cmd != f.command:
		f.command = cmd


## Comando atual (ATTACK/DEFEND/SUPPORT/FREE): o aliado e o controlado do jogador seguem os comandos
## da arena (F e G); os outros usam o próprio f.command (o treinador escolhe sozinho).
func ally_mode() -> int:
	if f.arena == null:
		return FREE
	if f.side == 0 and f.arena.get("ally") == f:
		return int(f.arena.ally_mode)
	if f.side == 0 and f.arena.get("player") == f and f.arena.get("player_mode") != null:
		return int(f.arena.player_mode)
	return f.command


func _p(k: String, def = 0.0):
	return f.prof.get(k, def)


func is_support_move(id: String) -> bool:
	var mv := Dex.move(id)
	return mv.get("category", "") == "status" or mv.get("effect") is Dictionary


func _stat_move_maxed(id: String) -> bool:
	var mv := Dex.move(id)
	match String(mv.get("kind", "")):
		"self_buff":
			return int(f.stages.get(String(mv.get("stat", "")), 0)) >= 6
		"debuff_aoe":
			return (
				is_instance_valid(f.opponent)
				and int(f.opponent.stages.get(String(mv.get("stat", "")), 0)) <= -6
			)
	return false


## DEFEND: ponto entre o líder (mon controlado) e o inimigo, a até 1,5 m do líder. INF = sem líder.
func guard_spot() -> Vector3:
	# O líder é do mesmo lado: o controlado para o lado do jogador, o parceiro para o adversário.
	var lead: BattleFighter = f.arena.get("player") if f.side == 0 else partner()
	if (
		not is_instance_valid(lead)
		or lead == f
		or not lead.active()
		or not is_instance_valid(f.opponent)
	):
		return Vector3.INF
	var to_f := lead.flat_to(f.opponent)
	return lead.pos2(lead.position) + to_f.normalized() * minf(GUARD_DIST, to_f.length() * 0.5)


func guard_steer() -> Vector3:
	var spot := guard_spot()
	if spot == Vector3.INF:
		return Vector3.INF
	var v := spot - f.pos2(f.position)
	if v.length() < 0.4:
		return Vector3.ZERO
	return v.normalized() * minf(1.0, v.length())


## Com mais de um alvo (2x1, 2x2): reavalia a cada 2-4 s (distância, último a acertar, HP baixo, alvo atual,
## tanque DEFEND e, no treinador, quem toma mais dano).
func pick_target(dt: float) -> void:
	var cands: Array = f.arena.targets_of(f)
	var cur := f.opponent
	var cur_ok := is_instance_valid(cur) and cur.active()
	retarget_t -= dt
	if cands.size() <= 1:
		if not cur_ok and cands.size() == 1:
			f.opponent = cands[0]
		return
	if cur_ok and retarget_t > 0.0:
		return
	var rng := _rng()
	retarget_t = rng.randf_range(2.0, 4.0)
	var best: BattleFighter = null
	var best_w := -INF
	for t in cands:
		var w := 2.0 / maxf(f.flat_to(t).length(), 1.0)
		if t == f.last_hit_by:
			w += 1.5
		if float(t.hp) / maxf(t.max_hp, 1) <= TARGET_FINISH_HP:
			w += 1.0
		if t == cur:
			w += TARGET_STICKY
		if t == f.arena.get("ally") and int(f.arena.ally_mode) == DEFEND:
			w += 2.0
		if f.arena.get("kind") != "wild":
			# Treinador: prefere quem toma mais dano dos seus golpes (tipo, defesa).
			var best_d := 0.0
			for id in f.moves:
				best_d = maxf(best_d, f.arena.moves.expected_damage(f, t, Dex.move(String(id))))
			w += clampf(best_d / maxf(float(t.hp), 1.0), 0.0, 1.5)
		w += rng.randf() * 0.2
		if w > best_w:
			best_w = w
			best = t
	if best:
		f.opponent = best


## Mon de treinador: usa o item do treinador uma vez (HP <= 35% para cura de HP, ou status que o item cura).
func want_trainer_item() -> bool:
	if f.trainer_item == "" or f.item_used or not f.alive():
		return false
	var tai = f.arena.get("trainer_ai")
	var rounds = f.arena.get("turns")
	if tai is Dictionary and tai.has(f.side) and rounds != null and rounds.on:
		return false  # o item sai pela IA do treinador (BattleTrainerAI) no começo da rodada
	var e: Dictionary = Dex.item(f.trainer_item).get("effect", {})
	if e.has("hp"):
		return float(f.hp) / maxf(f.max_hp, 1) <= TRAINER_ITEM_HP
	if e.has("cure"):
		return f.status != "" and (String(e.cure) == "all" or f.status == String(e.cure))
	return false


func use_trainer_item() -> void:
	f.item_used = true
	var it := Dex.item(f.trainer_item)
	var e: Dictionary = it.get("effect", {})
	if e.has("hp"):
		var amount: int = f.max_hp if str(e.hp) == "full" else int(e.hp)
		var before := f.hp
		f.heal(mini(amount, f.max_hp - f.hp))
		f.popup("+%d HP" % (f.hp - before), Color(0.55, 1.0, 0.6), 1.0, 0.5)
	elif e.has("cure"):
		f.clear_status()
	if f.arena.has_method("item_used_by_trainer"):
		f.arena.item_used_by_trainer(f, String(it.get("name", f.trainer_item)))


## Dormindo: só Snore/Sleep Talk saem (BattleMoveEffects.sleep_move). Na fila, só na vez.
func _sleep_move(d: float) -> bool:
	for id in f.moves:
		var mv := Dex.move(String(id))
		if (
			f.arena.moves.effects.sleep_move(f, mv)
			and in_range(String(id), d)
			and f.arena.moves.can_afford(f, String(id))
			and f.arena.moves.use(f, String(id))
		):
			note_used(String(id))
			return true
	return false


## Tem Snore/Sleep Talk para usar dormindo (a vez não passa logo por causa do sono).
func can_sleep_act() -> bool:
	if f.status != "sleep":
		return false
	for id in f.moves:
		if f.arena.moves.effects.sleep_move(f, Dex.move(String(id))):
			return true
	return false


func _punish(d: float) -> bool:
	var opp := f.opponent
	if not f.can_act():
		return false
	var orec := opp.ai.recover_t if opp.ai and opp.controller == "ai" else 0.0
	if orec <= 0.0 and opp.gcd_t <= 0.0:
		return false
	return move_ready(d)


func _use_best_move(d: float) -> bool:
	if f.out_of_pp():
		if d < 2.2:
			return f.struggle()
		return false
	var avail: Array = f.moves.filter(
		func(id):
			return (
				f.gcd_t <= 0.0
				and float(f.move_cd.get(id, 0.0)) <= 0.0
				and in_range(id, d)
				and f.arena.moves.can_afford(f, id)
			)
	)
	if avail.is_empty():
		return false
	if _immune_only(avail) and _has_connecting_move():
		return false
	var id := intent if intent in avail else pick(avail)
	if id == "":
		return false
	if f.arena.moves.use(f, id):
		recover_t = RECOVER
		note_used(id)
		return true
	return false


## Status usado: trava os próximos status (exceto urgente) e marca os de uma vez por luta.
func note_used(id: String) -> void:
	last_move = id
	if tactics != null:
		tactics.note_used(id)
	if float(Dex.move(id).get("power", 0)) > 0.0:
		return
	status_lock_t = _rng().randf_range(STATUS_LOCK.x, STATUS_LOCK.y)
	if id in ONCE_MOVES:
		used_once[id] = true


## BattleTactics criado na primeira escolha (a arena já existe aí).
func _tactics() -> BattleTactics:
	if not _tactics_checked and f.arena != null:
		_tactics_checked = true
		if BattleTactics.enabled_for(f):
			tactics = BattleTactics.new(self)
	return tactics


func _dmg(id: String) -> float:
	return f.arena.moves.expected_damage(f, f.opponent, Dex.move(id))


func _immune_only(avail: Array) -> bool:
	for id in avail:
		if float(Dex.move(id).get("power", 0)) <= 0.0 or _dmg(id) > 0.0:
			return false
	return true


func _has_connecting_move() -> bool:
	for id in f.moves:
		if float(Dex.move(id).get("power", 0)) > 0.0 and _dmg(id) > 0.0:
			return true
	return false


func pick(avail: Array) -> String:
	if f.energy_mode and avail.size() > 1 and last_move in avail:
		if _rng().randf() < REPEAT_AVOID:
			avail = avail.filter(func(id): return String(id) != last_move)
	var tac := _tactics()
	if tac != null:
		var chosen := tac.choose(avail)
		if chosen != "":
			return chosen
	var mode := ally_mode()
	var connects := _has_connecting_move()
	var useful: Array = avail.filter(func(id): return status_ok(String(id), connects))
	if useful.is_empty():
		# Só sobrou status ruim agora: com golpe de dano no repertório, espera ele em vez do status.
		if connects:
			return ""
		useful = avail.filter(func(id): return not _stat_move_maxed(id))
	if not useful.is_empty():
		avail = useful
	var pref: Array = []
	match mode:
		ATTACK:
			pref = avail.filter(func(id): return float(Dex.move(id).get("power", 0)) > 0.0)
		DEFEND:
			if _rng().randf() < DEFEND_BUFF_CHANCE:
				pref = avail.filter(func(id): return Dex.move(id).get("kind", "") == "self_buff")
		SUPPORT:
			pref = avail.filter(func(id): return is_support_move(id))
	var full := avail
	if not pref.is_empty():
		avail = pref
	var dmg := {}
	for id in full:
		if float(Dex.move(id).get("power", 0)) > 0.0:
			dmg[id] = _dmg(id)
			if BattleMoves.multi_target(Dex.move(id)) == "all_other_pokemon" and partner() != null:
				# Earthquake com o parceiro perto: o custo de acertar o parceiro entra na conta.
				var tot: float = f.arena.moves.expected_total(f, Dex.move(id))
				dmg[id] = minf(float(dmg[id]), maxf(tot, 0.0))
	var usable: Array = avail.filter(func(id): return not dmg.has(id) or dmg[id] > 0.0)
	var pool: Array = usable if not usable.is_empty() else avail
	var best := best_move(pool, dmg)
	if best != "" and dmg.get(best, 0.0) >= float(f.opponent.hp):
		return best
	var area := _area_pick(pool, dmg)
	if area != "":
		return area
	var rng := _rng()
	if rng.randf() < error_chance():
		return String(pool[rng.randi() % pool.size()])
	var has_hit := dmg.values().any(func(v): return v > 0.0)
	var kit: Array = pool.filter(func(id): return float(Dex.move(id).get("power", 0)) <= 0.0)
	if not kit.is_empty():
		if not connects:
			return String(kit[rng.randi() % kit.size()])
		# Cada status passa pelo próprio peso (o urgente sempre); com o golpe de dano só esperando o
		# cooldown o peso dobra (status de enchimento), e se nenhum passar a IA espera o ataque.
		var k := 1.0 if has_hit else FILLER_MULT
		var from := rng.randi() % kit.size()
		for i in kit.size():
			var id := String(kit[(from + i) % kit.size()])
			if rng.randf() < status_weight(id) * k:
				return id
		status_lock_t = maxf(status_lock_t, DECLINE_LOCK)
		if best == "":
			best = best_move(full.filter(func(id): return dmg.get(id, 0.0) > 0.0), dmg)
		if best == "":
			return ""
	return best if best != "" else String(pool[rng.randi() % pool.size()])


## Regras duras do status: o golpe faz sentido agora? Golpe de dano sempre passa. Na trava depois de um
## status só passa o urgente (com golpe de dano que conecta no repertório).
func status_ok(id: String, connects := true) -> bool:
	var mv := Dex.move(id)
	if float(mv.get("power", 0)) > 0.0:
		return true
	if tactics != null and id == intent and id == tactics.last_pick:
		return true  # BattleTactics já pesou este status nesta rodada
	if id in PARTNER_MOVES and partner() == null:
		return false
	if id in ONCE_MOVES and used_once.has(id):
		return false
	if not _worth_status(id, connects):
		return false
	if connects and status_lock_t > 0.0 and not status_urgent(id):
		return false
	return true


## Status que vale mesmo na trava: Protect/Quick Guard diante de ameaça, cura com HP bem baixo.
func status_urgent(id: String) -> bool:
	var mv := Dex.move(id)
	var hp := float(f.hp) / maxf(f.max_hp, 1)
	match String(mv.get("special", "")):
		"protect", "quick_guard":
			return f.arena.moves.effects._threatened(f)
		"endure", "wide_guard", "counter":
			return f.arena.moves.effects.ai_worth(f, mv) == true
		"roost", "heal_weather", "swallow", "rest", "healing_wish":
			return hp < URGENT_HP
		"life_dew":
			var p := partner()
			return hp < URGENT_HP or (p != null and float(p.hp) / maxf(p.max_hp, 1) < URGENT_HP)
	return false


## Chance de escolher este status (já aprovado por status_ok) quando há golpe de dano à mão.
func status_weight(id: String) -> float:
	if status_urgent(id):
		return 1.0
	var mv := Dex.move(id)
	var st := String(mv.get("stat", ""))
	var kind := String(mv.get("kind", ""))
	if (
		id in LOW_VALUE_MOVES
		or kind == "clones"
		or (kind == "self_buff" and st in ["acc", "evasion"])
	):
		return STATUS_W_LOW
	if kind == "self_buff" and String(mv.get("special", "")) == "":
		var ups := _raised(mv)
		if ups.any(func(k): return k in SETUP_STATS and int(f.stages.get(k, 0)) <= 0):
			return STATUS_W_SETUP
	return STATUS_W_BASE


## Atributos que o buff sobe (Shell Smash: atk, spa, spe).
func _raised(mv: Dictionary) -> Array:
	var stats = mv.get("stats")
	if stats is Dictionary:
		return stats.keys().filter(func(k): return int(stats[k]) > 0)
	if int(mv.get("stages", 1)) > 0 and mv.has("stat"):
		return [String(mv.stat)]
	return []


## Golpe com menos acertos até o KO; empate vai para o de maior dano.
func best_move(pool: Array, dmg: Dictionary) -> String:
	var best := ""
	var best_turns := INF
	var best_dmg := 0.0
	var hp := maxf(float(f.opponent.hp), 1.0)
	for id in pool:
		var d: float = dmg.get(id, 0.0)
		if d <= 0.0:
			continue
		var turns := ceilf(hp / d)
		if turns < best_turns or (turns == best_turns and d > best_dmg):
			best = id
			best_turns = turns
			best_dmg = d
	return best


func _worth_status(id: String, has_damage: bool) -> bool:
	var mv := Dex.move(id)
	if float(mv.get("power", 0)) > 0.0:
		return false
	var special = f.arena.moves.effects.ai_worth(f, mv)
	if special != null:
		return bool(special)
	if float(f.hp) / maxf(f.max_hp, 1) < KIT_LOW_HP:
		return false
	var stack_ok := not has_damage or error_chance() >= KIT_STAT_SLOP
	var opp := f.opponent
	match String(mv.get("kind", "")):
		"self_buff":
			var st := String(mv.get("stat", ""))
			var delta := int(mv.get("stages", 1))
			var cur := f.crit_stage if st == "crit" else int(f.stages.get(st, 0))
			if st == "evasion":
				return f.evasion_t <= 0.0
			# Vários atributos (Shell Smash, Quiver Dance): nenhum dos que sobem já em +2.
			for k in _raised(mv):
				if int(f.stages.get(String(k), 0)) >= BUFF_CAP:
					return false
			var moved := cur * signi(delta)
			return delta != 0 and (moved <= 0 or stack_ok) and moved < BUFF_CAP
		"debuff_aoe":
			return _debuff_ok(opp, String(mv.get("stat", "")), stack_ok)
		"clones":
			return f.evasion_t <= 0.0
	var ef = mv.get("effect")
	if String(mv.get("special", "")) == "thunder_wave" and "ground" in opp.types:
		return false
	if ef is Dictionary and ef.has("status"):
		return _status_lands(opp, String(ef.status), bool(mv.get("powder", false)))
	if ef is Dictionary and ef.has("stat"):
		return _debuff_ok(opp, String(ef.stat), stack_ok)
	return false


## Debuff no alvo: não já em -2 (ou menos) nem com habilidade que impede a queda (Clear Body...).
func _debuff_ok(opp: BattleFighter, st: String, stack_ok: bool) -> bool:
	var cur := int(opp.stages.get(st, 0))
	if cur <= DEBUFF_CAP or (cur < 0 and not stack_ok):
		return false
	var ab = f.arena.get("abilities")
	return not (ab and ab.has_method("ability_of") and _keeps_stat(String(ab.ability_of(opp)), st))


static func _keeps_stat(ability: String, st: String) -> bool:
	if not BattleAbilities.KEEP_STAT.has(ability):
		return false
	var keys: Array = BattleAbilities.KEEP_STAT[ability]
	return keys.is_empty() or st in keys


## O status pega no alvo agora: sem condição, sem imunidade de tipo/habilidade, sem Safeguard do lado
## dele; pó não pega em Planta.
func _status_lands(opp: BattleFighter, st: String, powder: bool) -> bool:
	if powder and "grass" in opp.types:
		return false
	var ab = f.arena.get("abilities")
	var a := String(ab.ability_of(opp)) if ab and ab.has_method("ability_of") else ""
	if a == "shield_dust" or st in BattleAbilities.BLOCKS.get(a, []):
		return false
	if f.arena.moves.effects.side_active(opp.side, "safeguard"):
		return false
	if st == "confusion":
		return opp.confusion_t <= 0.0
	if st == "leech":
		return not opp.seeded and not "grass" in opp.types
	if st in ["poison", "toxic"] and "steel" in opp.types:
		return false
	return opp.status == "" and not BattleMoves.STATUS_IMMUNE.get(st, "-") in opp.types


# --- Posição fixa no campo (rodadas) ---


## Fora da vez: fica na posição dele (arena.home_of, como numa quadra de VGC), de frente para o outro
## lado; só foge rodeando se ficar preso na parede com inimigo perto. O desvio vem antes, em step.
func _off_turn(dt: float, d: float, _dir: Vector3, side_v: Vector3) -> Vector3:
	_fly(d)
	var esc := corner_escape()
	if esc != Vector3.ZERO:
		return esc
	_try_jump(dt, d)
	var mode := ally_mode()
	guarding = false
	if mode == DEFEND or (mode == FREE and bool(_p("guard", false)) and _partner_hurt()):
		# DEFENSIVO: a posição dele vira o ponto entre o líder e o inimigo.
		var guard := guard_steer()
		if guard != Vector3.INF:
			guarding = true
			return guard
	return _go_home(side_v)


## Na vez: golpe de longe sai da própria posição (só anda até entrar no alcance); golpe de contato vai
## até o alvo, bate e volta (recover_t -> _go_home).
func _turn_move(dt: float, d: float, dir: Vector3, side_v: Vector3) -> Vector3:
	_fly(d)
	if _try_jump(dt, d):
		return Vector3.ZERO
	if intent == "" or f.out_of_pp():
		return _off_turn(dt, d, dir, side_v)
	if in_range(intent, d * (1.0 if is_contact(intent) else 1.05)):
		return Vector3.ZERO  # para e mira
	var want := (dir + _spread_all(true) * 0.5).limit_length(1.0)
	f.sprinting = d > 3.0 and f.can_sprint(true)
	return want


## Golpe que precisa encostar (investida, golpe de perto, área em volta de si).
func is_contact(id: String) -> bool:
	return String(Dex.move(id).get("kind", "")) in CONTACT_KINDS


## Anda até a posição dele; perto dela só balança um pouco de lado.
func _go_home(side_v: Vector3) -> Vector3:
	var home: Vector3 = f.arena.home_of(f)
	var v := home - f.pos2(f.position)
	# Só chegou de volta depois de sair: logo depois de soltar uma investida ele ainda está perto de casa.
	if v.length() < HOME_NEAR * 2.0 and f.dash_t <= 0.0 and f.lunge_t <= 0.0 and recover_t <= 0.0:
		returning = false
	if v.length() < HOME_NEAR:
		return side_v * 0.08 * float(_p("strafe", 0.5))
	if v.length() > HOME_RUN and f.can_sprint(true):
		f.sprinting = true
	return (v.normalized() * clampf(v.length(), 0.35, 1.0) + _spread_all(false) * 0.5).limit_length(
		1.0
	)


## Distância até a parede mais perto da quadra (m).
func _wall_dist(p: Vector3) -> float:
	var r: Rect2 = f.arena.rect
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.z - r.position.y, r.end.y - p.z))


func _to_centre() -> Vector3:
	var c: Vector2 = f.arena.rect.get_center()
	var v := Vector3(c.x, 0.0, c.y) - f.pos2(f.position)
	return v.normalized() if v.length() > 0.01 else Vector3.ZERO


## Perto da parede com inimigo perto: sai pelo lado aberto rodeando o inimigo (não reto para trás).
func corner_escape() -> Vector3:
	var me := f.pos2(f.position)
	if _wall_dist(me) >= CORNER_M:
		return Vector3.ZERO
	var foe: BattleFighter = null
	var best := CORNER_FOE
	for g in f.arena.targets_of(f):
		var dd := f.flat_to(g).length()
		if dd < best:
			best = dd
			foe = g
	if foe == null:
		return Vector3.ZERO
	var away := -f.flat_to(foe).normalized()
	var tang := Vector3(-away.z, 0.0, away.x)
	var to_c := _to_centre()
	if tang.dot(to_c) < 0.0:
		tang = -tang
	return (tang * 0.8 + to_c * 0.6 + away * 0.2).normalized()


## Espaço de todos os lutadores (aliado SPACE_ALLY, inimigo SPACE_FOE). Na vez o alvo não conta.
func _spread_all(on_turn: bool, skip: BattleFighter = null) -> Vector3:
	var out := Vector3.ZERO
	for g in f.arena.fighters:
		if g == f or g == skip or not is_instance_valid(g) or not g.active():
			continue
		if on_turn and g == f.opponent:
			continue
		var lim := SPACE_ALLY if g.side == f.side else SPACE_FOE
		var to := f.flat_to(g)
		var dd := to.length()
		if dd >= lim or dd < 0.01:
			continue
		out -= to / dd * (lim - dd) / lim
	return out


# --- Esquiva ---


func _aimed_at_me(dir: Vector3) -> bool:
	var to_me := f.position - f.opponent.position
	to_me.y = 0.0
	if to_me.length() < 0.01:
		return true
	return to_me.normalized().dot(Vector3(dir.x, 0.0, dir.z).normalized()) > 0.6


func _incoming_body_attack(d: float) -> Vector3:
	var o := f.opponent
	if o.dash_t > 0.0 and d - BattleFighter.HIT_RANGE <= float(o.dash_move.get("range", 0.0)):
		return o.dash_dir if _aimed_at_me(o.dash_dir) else Vector3.ZERO
	if (
		o.lunge_t > 0.0
		and d - BattleFighter.HIT_RANGE <= BattleFighter.LUNGE_SPEED * BattleFighter.LUNGE_TIME
	):
		return o.lunge_dir if _aimed_at_me(o.lunge_dir) else Vector3.ZERO
	return Vector3.ZERO


func _can_clear(att: BattleFighter) -> bool:
	return f.jump_height * JUMP_CLEAR >= att.dash_reach()


func _dodge(dt: float, d: float, side_v: Vector3) -> Vector3:
	if not f.can_act() or f.root_t > 0.0:
		dodge_t = 0.0
		return Vector3.ZERO
	var incoming := _incoming_body_attack(d) != Vector3.ZERO and not _can_clear(f.opponent)
	if incoming:
		if dodge_t <= 0.0:
			if not tactic_on:
				return Vector3.ZERO
			dodge_t = DODGE_TIME
			_emit_dodge("body")
		dodge_t -= dt
		return side_v.normalized()
	dodge_t = 0.0
	return _dodge_threat(dt, side_v)


## Golpe avisado (área no chão, raio, investida preparada) ou projétil vindo: sai da frente se o
## reflexo deixar. A chance e o tempo de reação vêm do perfil, do comando e da Speed.
func _dodge_threat(dt: float, side_v: Vector3) -> Vector3:
	var got := _threat()
	if got.is_empty():
		threat_id = -1
		return Vector3.ZERO
	if int(got.id) != threat_id:
		threat_id = int(got.id)
		var sf := f.speed_factor()
		var chance: float = (float(_p("dodge", 0.5)) + CMD_DODGE[ally_mode()]) * sf
		if f.mood_state == "panic":
			chance += 0.15
		chance = clampf(chance / maxf(think_scale, 0.3), 0.05, 0.95)
		threat_ok = _rng().randf() < chance
		threat_wait = REACT_BASE / sf * think_scale
	if not threat_ok:
		return Vector3.ZERO
	var was := threat_wait
	threat_wait -= dt
	if threat_wait > 0.0:
		return Vector3.ZERO
	if was > 0.0:
		_emit_dodge("area")
	var esc: Vector3 = got.away
	if esc.length() < 0.1:
		esc = side_v
	return (esc.normalized() + f.arena.edge_push(f)).normalized()


## A ameaça mais perto de mim: {id, away}. Vazio = nada vindo.
func _threat() -> Dictionary:
	var me := f.pos2(f.position)
	var tele = f.arena.get("telegraphs")
	if tele is Array:
		for e in tele:
			if int(e.side) == f.side or float(e.t) <= 0.0:
				continue
			if e.kind == "disc":
				var to: Vector3 = me - e.at
				if to.length() < float(e.r) + 0.5:
					return {"id": int(e.id), "away": to}
			else:
				var rel: Vector3 = me - e.from
				var dv: Vector3 = e.dir
				var along := rel.dot(dv)
				var perp := rel - dv * along
				if along > -0.5 and along < float(e.len) and perp.length() < float(e.w) * 0.5 + 0.6:
					return {
						"id": int(e.id),
						"away": perp if perp.length() > 0.05 else Vector3(-dv.z, 0, dv.x)
					}
	for p in f.arena.projectiles:
		if p.done or not is_instance_valid(p.user) or p.user.side == f.side:
			continue
		var v: Vector3 = Vector3(p.vel.x, 0, p.vel.z)
		if v.length() < 0.1:
			continue
		var vd := v.normalized()
		var rel2: Vector3 = me - f.pos2(p.position)
		var ahead := rel2.dot(vd)
		var off := rel2 - vd * ahead
		if ahead > 0.0 and ahead < PROJ_LOOK and off.length() < BattleProjectile.HIT_RADIUS + 0.45:
			return {
				"id": p.get_instance_id(),
				"away": off if off.length() > 0.05 else Vector3(-vd.z, 0, vd.x)
			}
	return {}


func _jump_threat(d: float) -> String:
	if not f.can_act() or f.jump_height <= 0.0:
		return ""
	var o := f.opponent
	var sig := "@%d" % o.cast_n
	var mv := o.cast_move
	if (
		o.root_t > 0.0
		and String(mv.get("kind", "")) == "aoe_self"
		and String(mv.get("type", "")) == "ground"
		and d <= float(mv.get("radius", 0.0))
	):
		return "quake" + sig
	var pq := _partner_quake()
	if pq != "":
		return pq
	if _incoming_body_attack(d) != Vector3.ZERO and _can_clear(o):
		return "dash" + sig
	return ""


func _jump_lead(threat: String, d: float) -> float:
	var o := f.opponent
	if threat.begins_with("quake"):
		return maxf(o.root_t - 0.1, 0.0)
	if threat.begins_with("pquake") and partner() != null:
		return maxf(partner().root_t - 0.1, 0.0)
	if o.dash_t > 0.0:
		return maxf((d - BattleFighter.HIT_RANGE) / maxf(o.dash_speed, 1.0), 0.0)
	return maxf((d - BattleFighter.HIT_RANGE) / BattleFighter.LUNGE_SPEED, 0.0)


func _try_jump(dt: float, d: float) -> bool:
	var threat := _jump_threat(d)
	if threat == "":
		jump_threat = ""
		jump_done = false
		return false
	var rng := _rng()
	if threat != jump_threat:
		jump_threat = threat
		jump_done = false
		var window := f.jump_time
		var err := rng.randf_range(-1.0, 1.0) * _jump_error() * window
		jump_at = maxf(_jump_lead(threat, d) - window * 0.5 + err, 0.0)
		if rng.randf() < _jump_miss():
			jump_at += JUMP_LATE + _jump_error() * window
	if jump_done or f.air_t > 0.0 or f.land_t > 0.0 or f.dash_t > 0.0 or f.lunge_t > 0.0:
		return false
	jump_at -= dt
	if jump_at > 0.0:
		return false
	if f.start_jump():
		jump_done = true
		_emit_dodge("jump")
		return true
	return false


func _emit_dodge(what: String) -> void:
	if f.arena.has_signal("dodged"):
		f.arena.emit_signal("dodged", f, what)


func _sprint(dt: float, reason: bool) -> bool:
	if not reason:
		sprint_want = false
		sprint_seen = false
		return false
	if sprint_want:
		return true
	if not sprint_seen:
		sprint_seen = true
		react_t = SPRINT_REACT * maxf(think_scale, 0.05)
	react_t -= dt
	if react_t > 0.0:
		return false
	react_t = SPRINT_REACT * maxf(think_scale, 0.05)
	sprint_want = true
	return true


# --- Física Gen 9 e regras de dupla ---


## Investida longa (Quick Attack, Aqua Jet, Volt Tackle...) pronta e o alvo longe: vai nela para fechar
## a distância (às vezes, para não ficar previsível).
func _rush_move(d: float) -> String:
	if d < RUSH_FROM or (intent != "" and in_range(intent, d)):
		return ""
	if not is_instance_valid(f.opponent) or f.opponent.hidden != "":
		return ""
	for id in f.moves:
		var mv := Dex.move(String(id))
		if (
			String(mv.get("kind", "")) == "dash"
			and float(mv.get("range", 0.0)) >= RUSH_MIN
			and float(mv.get("power", 0)) > 0.0
			and in_range(String(id), d)
			and _ready(String(id))
			and _dmg(String(id)) > 0.0
			and _rng().randf() < RUSH_CHANCE
		):
			return String(id)
	return ""


## O golpe alcança o alvo agora (Dig/Fly escondido só leva dos golpes que alcançam).
func _reaches(t: BattleFighter, id: String) -> bool:
	if not is_instance_valid(t) or t.hidden == "":
		return true
	var mv := Dex.move(id)
	return float(mv.get("power", 0)) <= 0.0 or f.arena.moves.phys.hidden_power(mv, t) > 0.0


## Dupla: golpe de vários alvos (com o 0,75x de cada) quando pega os dois e rende mais que o melhor de alvo
## único. Golpe de alvo único conta um alvo só.
func _area_pick(pool: Array, dmg: Dictionary) -> String:
	if f.arena.targets_of(f).size() < 2:
		return ""
	var best_single := 0.0
	for id in pool:
		if BattleMoves.multi_target(Dex.move(String(id))) == "":
			best_single = maxf(best_single, float(dmg.get(id, 0.0)))
	var pick_id := ""
	var best_v := best_single * AREA_PREF
	for id in pool:
		var mv := Dex.move(String(id))
		if BattleMoves.multi_target(mv) == "" or float(mv.get("power", 0)) <= 0.0:
			continue
		if f.arena.moves._in_reach(f, mv) < 2:
			continue
		var v: float = f.arena.moves.expected_total(f, mv)
		if v > best_v:
			best_v = v
			pick_id = String(id)
	return pick_id


## Parceiro preparando Earthquake/Magnitude perto de mim: pulo também (o tremor pega o parceiro).
func _partner_quake() -> String:
	var p := partner()
	if p == null or p.root_t <= 0.0:
		return ""
	var mv := p.cast_move
	if (
		BattleMoves.multi_target(mv) == "all_other_pokemon"
		and String(mv.get("kind", "")) == "aoe_self"
		and String(mv.get("type", "")) == "ground"
		and f.flat_to(p).length() <= float(mv.get("radius", 0.0))
	):
		return "pquake@%d" % p.cast_n
	return ""
