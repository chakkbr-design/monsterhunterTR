# IA do treinador

Pedido do Caio (2026-10-24): pesquisa de como jogadores competitivos decidem trocas e itens, e a IA do
treinador em cima dela. A IA de cada Pokémon (golpe, alvo, movimento) é a do modo de energia
(`battle/battle_ai.gd` com os planos de `battle/battle_plan.gd`). Os números abaixo são ponto de partida.

## Pesquisa (resumo)

Fontes lidas: vgcguide.com (guia de jogo competitivo), Smogon (Momentum), documentação das flags de IA do pokeemerald-expansion
(`docs/tutorials/ai_flags.md`) e a wiki da IA de troca dele. Os limiares marcados como "nosso" são escolha
nossa.

| Tema | Regra que virou heurística |
|---|---|
| Troca | Sair com matchup ruim (leva muito e tira pouco), todos os golpes sem efeito, ou ataque em -2; só quem ainda tem HP para valer a troca (o fraco fica e bate); quem entra precisa aguentar o golpe da entrada. Evitar ping-pong; a IA oficial erra de propósito às vezes. |
| Quem entra depois do KO | Ordem do expansion: quem derruba e é mais rápido > quem derruba > bom matchup > o resto. |
| Item (jogo principal) | Curar só se a cura faz sobreviver; curar status que atrapalha. |

## `battle/battle_trainer_ai.gd` (BattleTrainerAI)

Um por lado em `arena.trainer_ai` (o adversário treinador e, sem teclado, o lado do jogador). A cada
rodada do relógio (`BattleTurns`, 4 s) a arena chama `round_start()`; a IA usa `request_switch`,
`request_trainer_item`, `bench_of` e `pick_replacement(slot)`. Pedidos saem na hora; a troca voluntária
respeita a trava de troca (`SWITCH_OPEN`/`SWITCH_LOCK`, `arena.switch_locked()`).

- **Troca** (uma por vez): matchup ruim = leva >= 50% e tira < 30%, ou nenhum golpe pega, ou ataque em
  -2; HP >= 40%; quem entra leva no máximo 60% (e no máximo 60% do que o atual levaria) e bate pelo menos
  80% do que o atual bate. Sem trocar o mesmo Pokémon de novo por 2 rodadas. Chance de trocar 0,7 no
  `think_scale` 1 (mais esperto, mais vezes).
- **Item do treinador** (um por Pokémon): cura com HP <= 35% se sobrevive curado; cura sono, paralisia,
  queimadura em físico, veneno com HP > 40%.
- **Substituto:** maior (dano que tira - 0,7 x dano que leva), +0,3 se derruba, +0,15 se é mais rápido.
- `opts.trainer_ai: false` desliga (`[lado 0, lado 1]` por lado).

## Testes

`tests/battle/test_trainer_ai.gd`: troca (matchup ruim, HP baixo, ping-pong), item (cura que salva, morre
de todo jeito), substituto e troca numa luta de verdade.
