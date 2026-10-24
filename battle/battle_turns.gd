class_name BattleTurns
extends RefCounted
## Rodadas pela Speed (o turno oficial, em tempo real). No começo de cada rodada a IA de cada lutador
## ativo escolhe o golpe (intenção); a fila sai pela prioridade do golpe (maior antes) e, dentro da
## faixa, pela Speed efetiva (estágios, paralisia, Tailwind, habilidade; Trick Room inverte; empate no
## sorteio). Cada um solta UM golpe na vez dele, com MOVE_GAP s de folga entre um golpe e o seguinte;
## fora da vez só anda, desvia e usa o campo. Recarga (Hyper Beam), sono, item do treinador e troca
## gastam a vez. A rodada dura pelo menos ROUND_SECS s; no fim dela vêm os efeitos de fim de turno
## (BattleAbilities.on_round_end). Os cooldowns e o GCD continuam valendo por cima da fila.
## opts.turn_mode false desliga a fila (ritmo antigo, para testes velhos); o fim de rodada continua
## a cada ROUND_SECS s.

## Duração mínima da rodada (s). Ajuste aqui para a luta ficar mais lenta ou mais rápida.
const ROUND_SECS := 4.0
## Folga mínima entre um golpe e o seguinte (s), de qualquer lutador.
const MOVE_GAP := 0.8
## Na vez, quem não solta o golpe em TURN_MAX s (longe, sem nada pronto) passa a vez.
const TURN_MAX := 2.2
## Quem não pode agir na vez (sono, congelado, recarga, hesitar) passa depois de SKIP_HOLD s.
const SKIP_HOLD := 0.35
## Item do treinador sai antes dos golpes (como a bolsa no oficial).
const ITEM_PRIORITY := 6
## Trick Room: duração em s (5 turnos de TURN da série).
const TRICK_ROOM_SECS := 5 * 1.6

var arena: Node
## Fila ligada (false = ritmo antigo, só o relógio de fim de rodada).
var on := true
var round_n := 0
## Tempo desde o começo da rodada.
var round_t := 0.0
## Lutadores na ordem da rodada atual.
var queue: Array = []
var index := 0
## Quem está com a vez agora (null na folga ou com a fila vazia).
var current: BattleFighter = null
var turn_t := 0.0
var gap_t := 0.0
## Trick Room ligado por mais trick_room_t s.
var trick_room_t := 0.0
## Registro para testes e para o HUD: {round, who (BattleFighter), what, t, prio, spe}.
var history: Array = []
var clock := 0.0
var _last_action := -INF
var _ties := {}


func _init(a: Node, enabled := true) -> void:
	arena = a
	on = enabled


# --- Ordem ---


## Speed para a ordem: Speed com estágios e Tailwind (stat), paralisia 0,5x e o multiplicador da
## habilidade (Chlorophyll, Swift Swim... em BattleAbilities.order_speed_mult).
static func order_speed(f: BattleFighter) -> float:
	var v := f.eff_spe()
	var ab = f.arena.get("abilities") if f.arena else null
	if ab and ab.has_method("order_speed_mult"):
		v *= float(ab.order_speed_mult(f))
	return v


## Prioridade do golpe para este lutador (dados + habilidade: Prankster, Gale Wings...).
static func priority_of(f: BattleFighter, id: String) -> int:
	if id == "":
		return 0
	var mv := Dex.move(id)
	var p := int(mv.get("priority", 0))
	var ab = f.arena.get("abilities") if f.arena else null
	if ab and ab.has_method("priority_bonus"):
		p += int(ab.priority_bonus(f, mv))
	return p


func trick_room() -> bool:
	return trick_room_t > 0.0


## Liga (ou desliga, se já está ligado, como o oficial) o Trick Room.
func toggle_trick_room(secs := TRICK_ROOM_SECS) -> bool:
	trick_room_t = 0.0 if trick_room_t > 0.0 else secs
	return trick_room_t > 0.0


## Ordena pela Speed (Trick Room inverte; empate no sorteio, fixo dentro da rodada). Serve também
## para a ordem de ativação das habilidades.
func speed_order(list: Array) -> Array:
	var out := list.filter(func(f): return is_instance_valid(f))
	for f in out:
		if not _ties.has(f.get_instance_id()):
			_ties[f.get_instance_id()] = arena.rng.randf()
	var tr := trick_room()
	out.sort_custom(
		func(a, b):
			var sa := order_speed(a)
			var sb := order_speed(b)
			if not is_equal_approx(sa, sb):
				return sa < sb if tr else sa > sb
			return float(_ties[a.get_instance_id()]) < float(_ties[b.get_instance_id()])
	)
	return out


## Fila da rodada: prioridade da intenção (maior antes), depois speed_order.
func build_order(list: Array) -> Array:
	var by_speed := speed_order(list)
	var rank := {}
	for i in by_speed.size():
		rank[by_speed[i].get_instance_id()] = i
	var out := by_speed.duplicate()
	out.sort_custom(
		func(a, b):
			var pa := _queue_priority(a)
			var pb := _queue_priority(b)
			if pa != pb:
				return pa > pb
			return int(rank[a.get_instance_id()]) < int(rank[b.get_instance_id()])
	)
	return out


func _queue_priority(f: BattleFighter) -> int:
	if f.ai and f.ai.want_trainer_item():
		return ITEM_PRIORITY
	return priority_of(f, String(f.ai.intent) if f.ai else "")


# --- Quem entra na fila ---


## Lutador que segue a fila: IA em campo (o jogador com teclado, o boneco do treino e quem não tem
## IA ficam de fora).
func tracked(f: BattleFighter) -> bool:
	return is_instance_valid(f) and f.active() and f.controller == "ai" and f.ai != null


# --- Consultas da IA ---


## Pode soltar golpe agora: a fila desligada, ou é a vez dele e a folga já passou.
func can_fire(f: BattleFighter) -> bool:
	if not on or not tracked(f):
		return true
	return f == current and gap_t <= 0.0


## É a vez dele (ou a próxima, durante a folga).
func is_turn(f: BattleFighter) -> bool:
	return on and f != null and f == next_up()


## O próximo a agir: o da vez ou, na folga, o próximo da fila (para o marcador).
func next_up() -> BattleFighter:
	if not on:
		return null
	if current != null and is_instance_valid(current) and current.active():
		return current
	for i in range(index, queue.size()):
		var f = queue[i]
		if tracked(f):
			return f
	return null


## Quantos lutadores ainda agem antes dele nesta rodada (0 = é a vez dele; -1 = já agiu ou fora).
func wait_of(f: BattleFighter) -> int:
	if not on:
		return 0
	if f == current:
		return 0
	var n := 1 if current != null else 0
	for i in range(index, queue.size()):
		if queue[i] == f:
			return n
		if tracked(queue[i]):
			n += 1
	return -1


## O lutador gastou a vez (golpe, Desespero, item, troca). Abre a folga para o próximo.
func done(f: BattleFighter, what := "move") -> void:
	if not on or f != current:
		return
	_record(f, what)
	current = null
	gap_t = MOVE_GAP
	_last_action = clock


## Nada pronto na vez (tudo em cooldown): passa sem abrir a folga.
func pass_turn(f: BattleFighter) -> void:
	if not on or f != current:
		return
	_record(f, "pass")
	current = null


func _record(f: BattleFighter, what: String) -> void:
	history.append(
		{
			"round": round_n,
			"who": f,
			"what": what,
			"t": clock,
			"prio": _queue_priority(f) if what != "skip" else 0,
			"spe": order_speed(f),
			"intent": String(f.ai.intent) if f.ai else ""
		}
	)


# --- Por frame ---


func tick(dt: float) -> void:
	clock += dt
	round_t += dt
	trick_room_t = maxf(trick_room_t - dt, 0.0)
	if not on:
		if round_n == 0 or round_t >= ROUND_SECS:
			_end_round()
			_begin_round()
		return
	if round_n == 0:
		_begin_round()
		return
	gap_t = maxf(gap_t - dt, 0.0)
	if current != null:
		if not tracked(current):
			current = null
		else:
			turn_t += dt
			if not current.can_act() and turn_t >= SKIP_HOLD and not current.ai.can_sleep_act():
				_record(current, "skip")
				current = null
			elif turn_t >= TURN_MAX:
				_record(current, "timeout")
				current = null
		if current != null:
			return
	if gap_t > 0.0:
		return
	while index < queue.size():
		var f = queue[index]
		index += 1
		if tracked(f):
			current = f
			turn_t = 0.0
			if f.ai.has_method("on_turn"):
				f.ai.on_turn()
			return
	if round_t >= ROUND_SECS:
		_end_round()
		_begin_round()


func _begin_round() -> void:
	round_n += 1
	round_t = 0.0
	_ties.clear()
	queue = []
	if on:
		var live: Array = arena.fighters.filter(func(f): return tracked(f))
		for f in live:
			f.ai.plan_round()
		queue = build_order(live)
	index = 0
	current = null
	turn_t = 0.0


func _end_round() -> void:
	if round_n == 0:
		return
	if arena.has_method("end_of_round"):
		arena.end_of_round()
