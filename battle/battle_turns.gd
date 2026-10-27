class_name BattleTurns
extends RefCounted
## Relógio de rodadas do modo de energia: a cada ROUND_SECS s vira a rodada (o "turno" do oficial).
## No fim dela vêm os efeitos de fim de turno (BattleEndTurn.run, pela arena) e no começo a IA do
## treinador decide trocas e itens (arena.begin_of_round). Cada Pokémon solta golpe quando quer (energia
## e cooldown). Aqui ficam também a ordem pela Speed (habilidades, Trick Room) e a prioridade do golpe.

## Duração da rodada (s): o ritmo do fim de turno, do sono, do clima, das telas e do Trick Room.
const ROUND_SECS := 4.0
## Trick Room: 5 turnos (rodadas), contados no fim de turno (BattleEndTurn).
const TRICK_ROOM_ROUNDS := 5

var arena: Node
var round_n := 0
## Tempo desde o começo da rodada.
var round_t := 0.0
## Trick Room ligado por mais trick_room_rounds rodadas.
var trick_room_rounds := 0
var clock := 0.0
var _ties := {}


func _init(a: Node) -> void:
	arena = a


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
	return trick_room_rounds > 0


## Liga (ou desliga, se já está ligado, como o oficial) o Trick Room por `rounds` rodadas.
func toggle_trick_room(rounds := TRICK_ROOM_ROUNDS) -> bool:
	trick_room_rounds = 0 if trick_room_rounds > 0 else rounds
	return trick_room_rounds > 0


## Fim de turno: conta uma rodada do Trick Room; true se acabou agora.
func count_trick_room() -> bool:
	if trick_room_rounds <= 0:
		return false
	trick_room_rounds -= 1
	return trick_room_rounds == 0


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


# --- Por frame ---


func tick(dt: float) -> void:
	clock += dt
	round_t += dt
	if round_n == 0 or round_t >= ROUND_SECS:
		_end_round()
		_begin_round()


func _begin_round() -> void:
	round_n += 1
	round_t = 0.0
	_ties.clear()
	if arena.has_method("begin_of_round"):
		arena.begin_of_round()


func _end_round() -> void:
	if round_n == 0:
		return
	if arena.has_method("end_of_round"):
		arena.end_of_round()
