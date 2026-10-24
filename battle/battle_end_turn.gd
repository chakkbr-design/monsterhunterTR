class_name BattleEndTurn
extends RefCounted
## Fim de turno oficial (Gen 9), uma vez por rodada (BattleTurns), depois que todos em campo agiram.
## A arena cria um por luta (arena.end_turn) e BattleTurns._end_round chama run() antes das
## substituições de quem desmaiou.

var arena: Node


func _init(a: Node) -> void:
	arena = a


## Roda os efeitos de fim de turno na ordem oficial.
func run() -> void:
	var ab = arena.get("abilities")
	if ab and ab.has_method("on_round_end"):
		ab.on_round_end()
