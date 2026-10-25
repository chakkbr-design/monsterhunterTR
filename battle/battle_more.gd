class_name BattleMore
extends RefCounted
## Ganchos dos golpes da Gen 2-9 que faltavam para as 1025 espécies: BattleMoveEffects (fx) chama daqui e
## cada gancho passa por BattleMoreA (golpes físicos e metade dos de status) e BattleMoreB (especiais e a
## outra metade), no mesmo estilo do BattleKanto: tudo estático, recebendo fx, sem referência de volta.


## Golpe que não pode sair agora: texto do motivo ("" = pode). A IA também consulta.
static func blocked(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> String:
	var r := BattleMoreA.blocked(fx, user, mv)
	if r != "":
		return r
	return BattleMoreB.blocked(fx, user, mv)


## Saiu um golpe (qualquer um), antes da entrega.
static func on_use(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> void:
	BattleMoreA.on_use(fx, user, mv)
	BattleMoreB.on_use(fx, user, mv)


## Golpe parado antes de acertar (proteções novas). true = parou.
static func blocks_hit(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary) -> bool:
	return BattleMoreA.blocks_hit(fx, user, target, mv) or BattleMoreB.blocks_hit(fx, user, target, mv)


## Poder deste acerto (poder variável). Devolve o poder novo.
static func power(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: float) -> float:
	return BattleMoreB.power(fx, user, target, m, BattleMoreA.power(fx, user, target, m, p))


## Tipo deste acerto (golpes que mudam de tipo). Devolve o tipo novo.
static func move_type(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, ty: String) -> String:
	return BattleMoreB.move_type(fx, user, target, m, BattleMoreA.move_type(fx, user, target, m, ty))


## Perfil do atacante (atk/spa/burned...) para a fórmula: muda p no lugar.
static func attacker(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: Dictionary) -> void:
	BattleMoreA.attacker(fx, user, target, m, p)
	BattleMoreB.attacker(fx, user, target, m, p)


## Perfil do defensor (def/spd/types...) para a fórmula: muda p no lugar.
static func defender(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, m: Dictionary, p: Dictionary) -> void:
	BattleMoreA.defender(fx, user, target, m, p)
	BattleMoreB.defender(fx, user, target, m, p)


## Depois do acerto (também golpes de status com alvo), com o dano tirado.
static func after_hit(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int) -> void:
	BattleMoreA.after_hit(fx, user, target, mv, dealt)
	BattleMoreB.after_hit(fx, user, target, mv, dealt)


## Golpe de status em si mesmo/no campo pelo special. true = tratado aqui.
static func self_move(fx: BattleMoveEffects, user: BattleFighter, mv: Dictionary) -> bool:
	return BattleMoreA.self_move(fx, user, mv) or BattleMoreB.self_move(fx, user, mv)


## A IA: vale usar agora? true/false, ou null = sem opinião.
static func ai_worth(fx: BattleMoveEffects, f: BattleFighter, mv: Dictionary) -> Variant:
	var r = BattleMoreA.ai_worth(fx, f, mv)
	if r != null:
		return r
	return BattleMoreB.ai_worth(fx, f, mv)


## Alvo levou dano de golpe.
static func note_damage(fx: BattleMoveEffects, user: BattleFighter, target: BattleFighter, mv: Dictionary, dealt: int) -> void:
	BattleMoreA.note_damage(fx, user, target, mv, dealt)
	BattleMoreB.note_damage(fx, user, target, mv, dealt)


## Um lutador desmaiou.
static func note_faint(fx: BattleMoveEffects, f: BattleFighter) -> void:
	BattleMoreA.note_faint(fx, f)
	BattleMoreB.note_faint(fx, f)


## Todo frame (fx.now já avançou).
static func tick(fx: BattleMoveEffects, dt: float) -> void:
	BattleMoreA.tick(fx, dt)
	BattleMoreB.tick(fx, dt)


## Fim de turno (uma vez por rodada) de cada lutador ativo: conte rodadas com fx.count_round.
static func end_turn(fx: BattleMoveEffects, f: BattleFighter) -> void:
	BattleMoreA.end_turn(fx, f)
	BattleMoreB.end_turn(fx, f)
