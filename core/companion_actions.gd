class_name CompanionActions
extends RefCounted
## Regras puras do companheiro fora da bola (porte do companion_actions.gd do original):
## o que ele faz parado conforme o humor (COME / ORBIT / NAP / PLAY), cansaço e pedido de descanso,
## busca de fruta (ou cogumelo na caverna) e a escolha das atividades do piquenique.

const COME := "COME"
const ORBIT := "ORBIT"
const NAP := "NAP"
const PLAY := "PLAY"

## Parado há quanto tempo antes de o companheiro fazer algo.
const STILL_S := 4.0
## Devoted cochila depois de tanto tempo parado.
const NAP_S := 12.0
## Brincar precisa de pelo menos dois fora da bola.
const PLAY_MIN_OUT := 2

## Cansado abaixo de 60% de HP ou de PP.
const TIRED_FRAC := 0.6
const ASK_COOLDOWN_S := 180.0
const ASK_WAIT_S := 8.0
const REST_S := 20.0
const REST_FRIEND := 5
const IGNORE_FRIEND := -3
const IGNORE_SIT_S := 15.0

const PHASE_NONE := ""
const PHASE_ASK := "ask"
const PHASE_SIT := "sit"
const PHASE_REST := "rest"


static func tired(hp: int, max_hp: int, pp: float, pp_base: float) -> bool:
	if max_hp > 0 and float(hp) < TIRED_FRAC * float(max_hp):
		return true
	return pp_base > 0.0 and pp < TIRED_FRAC * pp_base


static func can_ask(now_s: float, last_ask_s: float) -> bool:
	return now_s - last_ask_s >= ASK_COOLDOWN_S


## Um passo do pedido de descanso: [fase, tempo que falta, amizade ganha/perdida].
static func ask_step(phase: String, left: float, delta: float) -> Array:
	if phase == PHASE_NONE:
		return [PHASE_NONE, 0.0, 0]
	left -= delta
	if left > 0.0:
		return [phase, left, 0]
	if phase == PHASE_ASK:
		return [PHASE_SIT, IGNORE_SIT_S, IGNORE_FRIEND]
	return [PHASE_NONE, 0.0, 0]


static func tier_of(friend: int) -> String:
	return Mon.mood(friend)


static func pick(
	tier: String, still_s: float, out_count: int, _weather: String, is_night: bool
) -> String:
	if still_s < STILL_S or is_night:
		return ""
	if tier == "Devoted" and still_s >= NAP_S:
		return NAP
	match tier:
		"Content":
			return COME
		"Happy", "Devoted":
			if out_count >= PLAY_MIN_OUT:
				return PLAY
			return ORBIT
	return ""


const FETCH_SPOT := "spot"
const FETCH_TRAVEL := "travel"
const FETCH_PAUSE := "pause"
const FETCH_RETURN := "return"
const FETCH_DELIVER := "deliver"

const FETCH_SPOT_S := 0.5
const FETCH_PAUSE_S := 1.0
const FETCH_MIN_D := 3.0
const FETCH_MAX_D := 5.0

## Humor -> [quantidade, intervalo entre buscas em s].
const FETCH_TIER := {
	"Wary": [1, 240.0],
	"Content": [1, 180.0],
	"Happy": [1, 120.0],
	"Devoted": [1, 75.0],
}
const FETCH_CAVE_MULT := 3.0

const MUSHROOM_BIG_ODDS := 8
const MUSHROOM_TINY := "tiny_mushroom"
const MUSHROOM_BIG := "big_mushroom"
const BERRY_ORAN := "oran_berry"


static func fetch_reward(tier: String) -> Array:
	return FETCH_TIER.get(tier, FETCH_TIER["Wary"])


static func fetch_count(tier: String) -> int:
	return int(fetch_reward(tier)[0])


static func fetch_cooldown(tier: String, in_cave := false) -> float:
	var cd := float(fetch_reward(tier)[1])
	return cd * FETCH_CAVE_MULT if in_cave else cd


static func fetch_due(tier: String, now_s: float, last_s: float, in_cave := false) -> bool:
	return now_s - last_s >= fetch_cooldown(tier, in_cave)


static func fetch_item(in_cave: bool, roll: int) -> String:
	if not in_cave:
		return BERRY_ORAN
	return MUSHROOM_BIG if posmod(roll, MUSHROOM_BIG_ODDS) == 0 else MUSHROOM_TINY


## Um passo da busca: [fase, tempo que falta, alvo ("spot" | "trainer" | "")].
static func fetch_step(phase: String, left: float, delta: float, arrived: bool) -> Array:
	match phase:
		FETCH_SPOT:
			left -= delta
			if left > 0.0:
				return [FETCH_SPOT, left, ""]
			return [FETCH_TRAVEL, 0.0, "spot"]
		FETCH_TRAVEL:
			if arrived:
				return [FETCH_PAUSE, FETCH_PAUSE_S, ""]
			return [FETCH_TRAVEL, 0.0, "spot"]
		FETCH_PAUSE:
			left -= delta
			if left > 0.0:
				return [FETCH_PAUSE, left, ""]
			return [FETCH_RETURN, 0.0, "trainer"]
		FETCH_RETURN:
			if arrived:
				return [FETCH_DELIVER, 0.0, ""]
			return [FETCH_RETURN, 0.0, "trainer"]
	return [FETCH_DELIVER, 0.0, ""]


const PICNIC_CHASE := "CHASE"
const PICNIC_CHAT := "CHAT"
const PICNIC_NAP := "NAP"
const PICNIC_SIT := "SIT"

const PICNIC_ROTATE_S := 12.0
const PICNIC_NAP_EVERY := 4
const PICNIC_CHAT_MAX := 2


static func picnic_chase_count(out_count: int) -> int:
	if out_count < 2:
		return 0
	return 3 if out_count >= 4 else 2


static func picnic_tired(m: Dictionary) -> bool:
	return float(m.get("hp", 1.0)) < TIRED_FRAC or float(m.get("pp", 1.0)) < TIRED_FRAC


## mons: [{hp (fração), pp (fração), mood}]. Devolve uma atividade PICNIC_* por mon.
static func picnic_assign(mons: Array, rotation_t: float) -> Array:
	var n := mons.size()
	var acts: Array = []
	acts.resize(n)
	var tired_of: Array = []
	for i in n:
		tired_of.append(picnic_tired(mons[i]))
		acts[i] = PICNIC_NAP if tired_of[i] else PICNIC_SIT
	var healthy: Array = []
	for i in n:
		if not bool(tired_of[i]):
			healthy.append(i)
	var chase_n := mini(picnic_chase_count(n), healthy.size())
	if chase_n < 2:
		chase_n = 0
	for k in chase_n:
		acts[healthy[k]] = PICNIC_CHASE
	_spread_rest(acts, mons, healthy.slice(chase_n))
	_picnic_rotate(acts, tired_of, int(rotation_t / PICNIC_ROTATE_S))
	return acts


static func _spread_rest(acts: Array, mons: Array, rest: Array) -> void:
	var rn := rest.size()
	if rn == 0:
		return
	var order := rest.duplicate()
	order.sort_custom(
		func(a, b):
			var sa := _sit_score(mons[a])
			var sb := _sit_score(mons[b])
			return a < b if sa == sb else sa > sb
	)
	var chat_n := 0
	if rn >= 2:
		chat_n = mini(PICNIC_CHAT_MAX, rn - 1)
	elif _sit_score(mons[rest[0]]) < 2:
		chat_n = 1
	var sit_n := rn - chat_n
	for k in rn:
		acts[order[k]] = PICNIC_SIT if k < sit_n else PICNIC_CHAT


static func _sit_score(m: Dictionary) -> int:
	match String(m.get("mood", "Content")):
		"Devoted":
			return 3
		"Happy":
			return 2
		"Content":
			return 1
	return 0


static func _picnic_rotate(acts: Array, tired_of: Array, phase: int) -> void:
	if phase <= 0:
		return
	var eligible: Array = []
	for i in acts.size():
		if not bool(tired_of[i]) and acts[i] != PICNIC_CHASE:
			eligible.append(i)
	if eligible.is_empty():
		return
	var mover: int = eligible[(phase - 1) % eligible.size()]
	acts[mover] = _rotated(acts[mover], phase)


static func _rotated(act: String, phase: int) -> String:
	if act == PICNIC_CHAT:
		return PICNIC_SIT
	if act == PICNIC_SIT:
		return PICNIC_NAP if phase % PICNIC_NAP_EVERY == 0 else PICNIC_CHAT
	return act
