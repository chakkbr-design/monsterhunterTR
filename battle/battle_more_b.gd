class_name BattleMoreB
extends RefCounted
## Golpes da Gen 2-9 (parte B: especiais e a outra metade dos de status; tools/moves_more_b.py).
## Ganchos chamados por BattleMore (battle_more.gd); fx = BattleMoveEffects (fx.st(f), fx.set_rounds...).


## Golpe que não pode sair agora: texto do motivo ("" = pode). A IA também consulta.
static func blocked(_fx: BattleMoveEffects, _user: BattleFighter, _mv: Dictionary) -> String:
	return ""


## Saiu um golpe (qualquer um), antes da entrega.
static func on_use(_fx: BattleMoveEffects, _user: BattleFighter, _mv: Dictionary) -> void:
	pass


## Golpe parado antes de acertar (proteções novas). true = parou.
static func blocks_hit(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _mv: Dictionary) -> bool:
	return false


## Poder deste acerto (poder variável). Devolve o poder novo.
static func power(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _m: Dictionary, p: float) -> float:
	return p


## Tipo deste acerto (golpes que mudam de tipo). Devolve o tipo novo.
static func move_type(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _m: Dictionary, ty: String) -> String:
	return ty


## Perfil do atacante (atk/spa/burned...) para a fórmula: muda p no lugar.
static func attacker(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _m: Dictionary, _p: Dictionary) -> void:
	pass


## Perfil do defensor (def/spd/types...) para a fórmula: muda p no lugar.
static func defender(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _m: Dictionary, _p: Dictionary) -> void:
	pass


## Depois do acerto (também golpes de status com alvo), com o dano tirado.
static func after_hit(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _mv: Dictionary, _dealt: int) -> void:
	pass


## Golpe de status em si mesmo/no campo pelo special. true = tratado aqui.
static func self_move(_fx: BattleMoveEffects, _user: BattleFighter, _mv: Dictionary) -> bool:
	return false


## A IA: vale usar agora? true/false, ou null = sem opinião.
static func ai_worth(_fx: BattleMoveEffects, _f: BattleFighter, _mv: Dictionary) -> Variant:
	return null


## Alvo levou dano de golpe.
static func note_damage(_fx: BattleMoveEffects, _user: BattleFighter, _target: BattleFighter, _mv: Dictionary, _dealt: int) -> void:
	pass


## Um lutador desmaiou.
static func note_faint(_fx: BattleMoveEffects, _f: BattleFighter) -> void:
	pass


## Todo frame (fx.now já avançou).
static func tick(_fx: BattleMoveEffects, _dt: float) -> void:
	pass


## Fim de turno (uma vez por rodada) de cada lutador ativo: conte rodadas com fx.count_round.
static func end_turn(_fx: BattleMoveEffects, _f: BattleFighter) -> void:
	pass
