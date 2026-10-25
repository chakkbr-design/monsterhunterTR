"""Golpes da Gen 2-9 que faltavam para as 1025 espécies, parte B (especiais e a outra metade dos de status).

Mesmo formato de tools/gen9_new_moves.py: NEW[id] = (campos de jogo, descrição em inglês); tipo, categoria, PP,
precisão, prioridade e alvo vêm da PokeAPI. FX[id] = visual (data/move_fx.json). Mecânicas: battle/battle_more_b.gd.
"""

RUSH = {"kind": "dash", "allowed_midair": False, "range": 8.0, "speed": 18, "knockback": 10}
SELF = {"kind": "self_buff", "power": 0}

NEW = {}

FX = {}

# Texto do guia (docs/GOLPES.md, tools/move_guide.py): como o golpe foi adaptado ao tempo real, em pt-BR.
GUIDE = {}
