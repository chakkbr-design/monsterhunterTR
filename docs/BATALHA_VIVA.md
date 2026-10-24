# Batalha Viva

Reforma da batalha em tempo real (2026-10-24), a partir das respostas do Caio na página de propostas.
Os números são ponto de partida: o Caio balanceia pelo modo de treinamento.

## O que mudou

| Sistema | Onde | Resumo |
|---|---|---|
| Speed | `core/stat_calc.gd` | Fator `1 + 0,35·ln(minha/dele)`, limitado a 0,7–1,45 (cooldowns, GCD, fôlego, reflexo). Andar absoluto `3,0 + 0,012·Speed` m/s (2,4–5,6). Paralisia corta a Speed do fator pela metade. |
| Ritmo | `battle/battle_moves.gd` | Fórmula oficial Gen 5+ desde a Gen 9 física (`docs/MECANICAS.md`). O dano final é escalado por `damage_pace` (0,75, sempre igual no 1x1 e no 2x2; o Caio pediu 25% menos que o oficial). PP, dano de status e o resto seguem o oficial. Abaixo de 1 a fração do dano passa para o próximo golpe no alvo (sem o mínimo de 1 por golpe). `opts.damage_pace` muda. Meta: 15–30 s por Pokémon. |
| Prioridade | `data/moves.json` | `"priority": 1` (Quick Attack) sai quase sem preparo e com GCD 0,6x. |
| Perfis | `battle/battle_profile.gd` | Brigão, Atirador, Escaramuçador, Muralha, Trapaceiro, Voador, escolhidos pelos stats base e golpes, puxados pela Natureza (stat que sobe) e pela habilidade (`profile_bias`). Correção por espécie em `data/battle_profiles.json`. |
| IA | `battle/battle_ai.gd` | Ciclo intenção → aproximação → golpe → recuo: escolhe o golpe antes, anda até a faixa dele e recua pelo perfil. Desvia de área avisada, raio, investida preparada e projétil, com chance e reação pela Speed. Fúria ou Pânico com HP abaixo de 25% (pela Natureza). ±5% de variação nos cooldowns e no pensamento. Status com bom senso: golpe de parceiro só com parceiro vivo, buff até +2 e debuff até -2, campo/clima já ativo não repete, status só em alvo sem condição e não imune (Safeguard, tipo, habilidade, pó em Planta), Focus Energy uma vez, cura com HP baixo, peso por golpe (Sweet Scent/evasão quase nada) e trava de 4–6 s depois de um status (passa só Protect diante de ameaça e cura com HP < 35%). Sem PP, Desespero de perto. |
| Voo | `battle/fighter.gd` | Voador cruza a ~1,3 m e desce para atacar ou quando cansa. Investida de quem está no chão passa por baixo. |
| Comandos | `battle/battle_arena.gd` | OFENSIVO, DEFENSIVO, SUPORTE, LIVRE por Pokémon. F muda o do aliado, G o do controlado (também na pausa). O comando chega em 0,3–0,8 s pela amizade; amizade baixa às vezes ignora ("?") por 2 s. Sem teclado (autoplay, treino) os dois lados trocam sozinhos pela situação (`opts.auto_commands`). |
| Amizade | `battle/battle_arena.gd`, `fighter.gd` | +3 para quem vence de pé, +1 às vezes ao obedecer, −20 ao desmaiar (já existia). Devotado (220+) pode aguentar um golpe fatal com 1 HP uma vez por luta. Chance de ignorar: <70 30%, <150 10%, <220 3%, 220+ 0. |
| 2x2 | `battle/battle_arena.gd` | Treinador com `"doubles": true` no `trainers.json` (todos os do ginásio e alguns escolhidos) ou `opts.battle_size: 2` (treino). Só vira dupla se o jogador tiver dois de pé e o adversário dois. Quem cai é substituído pelo próximo; o último de pé ganha "Última esperança!" (+1 Ataque e At. Esp.). Anel amarelo/vermelho no chão. |
| Combos | `battle/battle_combos.gd`, `data/duo_moves.json` | Marcas de tipo (3 s), 11 reações quando o parceiro acerta o alvo marcado (até 1,5x, ICD 2,5 s), Ressonância (mesmo tipo em 1 s, +25%), Sintonia por lado e 11 golpes de dupla. |
| Terreno | `battle/battle_field.gd` | Cratera, buraco, poça, gelo, grama queimada, pó, Spikes; 2–4 caixas/pedras que quebram e às vezes soltam frutinha; clones do Double Team que absorvem golpe. `opts.field_objects: false` desliga os objetos. |
| Habilidades | `battle/battle_abilities.gd`, `data/abilities.json` | 86 habilidades com efeito (48 novas, todas com `desc_pt`), 1–3 por espécie, faixa no HUD quando agem. |
| Rodadas | `battle/battle_turns.gd`, `battle_ai.gd` | Rodada de `ROUND_SECS` (4,0 s) pela Speed (opção A do Caio). No começo dela a IA escolhe o golpe; a fila sai pela prioridade do golpe (`"priority"` dos dados, +habilidade) e, na faixa, pela Speed efetiva (estágios, paralisia, Tailwind, habilidade; Trick Room inverte; empate no sorteio). Cada um solta UM golpe na vez dele, com `MOVE_GAP` (0,8 s) de folga entre golpes; quem não consegue em `TURN_MAX` (2,2 s) passa. Recarga, sono, item do treinador e troca gastam a vez; quem entra no meio espera a próxima rodada. Cooldowns e GCD continuam valendo. Vale no 1x1, no 2x2 e no treino (o Pokémon guiado pelo teclado, com `auto_battle` desligado, e o boneco do treino ficam fora da fila). `opts.turn_mode: false` volta ao ritmo antigo (só testes velhos). Anel + seta brilhando em quem é o próximo (`battle_arena.gd` `_place_turn_mark`). Fim de rodada roda o fim de turno oficial da Gen 9 uma vez (`battle/battle_end_turn.gd`: status, clima, itens, campo e habilidades na ordem oficial; `docs/MECANICAS.md`, "Fim de turno"). |
| Posições fixas | `battle_arena.gd` `home_of`, `battle_ai.gd` | Como numa quadra de VGC: no 1x1 um ponto por lado; com dois do mesmo lado, esquerda (controlado / 1º do adversário) e direita (aliado / 2º), de frente para a outra dupla (`DOUBLES_GAP` 3,6 m, longe da parede `HOME_WALL`). Fora da vez cada um fica na posição dele e só desvia (DEFENSIVO fica entre o parceiro e o inimigo). Na vez, golpe de longe sai da própria posição (só anda até o alcance); golpe de contato vai, bate e volta. Substituiu a escolha de ponto livre. Encurralado na parede ainda foge rodeando. O Voador voa alto numa rodada e baixo na outra. |
| Treinadores e Pokébola | `battle_arena.gd` | Um treinador parado atrás de cada lado (o corpo do mundo quando a quadra é fixa; senão um boneco com o sprite do treinador; no selvagem só o do jogador). Troca e substituto: raio vermelho do Pokémon até a mão do treinador e a bola jogada em arco que abre e solta o novo (`SEND_FLIGHT`, `SEND_OPEN`, `RECALL_BEAM`). |
| Troca no VGC | `battle_arena.gd`, `battle_turns.gd` | A troca só sai no começo da rodada, antes dos golpes (`request_switch`; Tab do jogador vira pedido), uma por lado por rodada; quem entra não ataca nessa rodada e herda os golpes mirados em quem saiu. Quem desmaia é substituído no fim da rodada (depois do fim de turno); se a rodada acabou de virar, entra na hora. `SWITCH_HOLD` (1 s) segura o 1º golpe enquanto a bola voa. |
| Botões de modo | `battle_hud.gd` | Pílulas OFENSIVO/DEFENSIVO/SUPORTE/LIVRE ao lado do cartão de cada Pokémon do jogador (o modo atual cheio); clique = `order(slot, modo)`, igual às teclas F/G. Também no treino. |
| IA de treinador (interface) | `battle_arena.gd` | Para a thread de IA: `arena.trainer_ai[side]` com `round_start()` (começo de cada rodada, antes da fila) e `pick_replacement(slot) -> int` (índice de `bench_of(side)`, -1 = a arena escolhe); `request_switch(side, out, bench_idx)`, `request_trainer_item(side, item, target)` (o alvo não ataca na rodada), `bench_of(side)`, `pending_switch(side)`, `turns.sits_out(f)`. |
| Espetáculo | `battle/battle_hud.gd`, arena | Balão com o nome do golpe por lado, cena de impacto (a luta congela 0,4 s; no máx. 1 a cada 2,5 s), CLASH (duas investidas de frente se anulam), "Precisa recarregar!" depois do Hyper Beam, cobrir o parceiro com HP baixo (DEFENSIVO ou Muralha), cartões 2x2, etiquetas de comando, marcas e estágios, barra de Sintonia. |

## Testes novos

`tests/battle/test_doubles.gd`, `test_combos.gd`, `test_field.gd`, `test_abilities.gd`, `test_hud_viva.gd`,
`test_turns.gd` (ordem pela Speed, prioridade, Trick Room, empate, um golpe por rodada, folga mínima, marcador) e
`test_field_use.gd` (posições fixas: simulação headless com canto até 10% do tempo, parede até 30%, parceiros sem embolar e,
fora da vez, no máximo 30% do tempo a mais de 2 m da posição), `test_switch.gd` (troca no começo da rodada, uma por lado,
quem entra não ataca, herda o alvo, substituto no fim da rodada, IA de treinador, treinador e bola), `test_end_turn.gd`
(fim de turno oficial) e `test_mode_buttons.gd` (botões de modo). Screenshots: `tests/battle/shot_turns.gd` gera
`docs/screens/turns_*.png`.
Testes de regra que dependem do ritmo antigo passam `"turn_mode": false` (item do treinador na hora em `test_battle.gd`,
variedade de golpes em `test_gen9_moves.gd`).

**Constantes para o Caio ajustar:** `ROUND_SECS` (duração mínima da rodada, 4,0 s) e `MOVE_GAP` (folga entre golpes,
0,8 s) no topo de `battle/battle_turns.gd`; `TURN_MAX` (2,2 s) é quanto a vez espera antes de passar.
`tests/battle/test_battle.gd` roda as regras no ritmo original (`damage_pace` 1,0, sem caixas no campo).

## Ainda não feito

- Chefe 1 contra vários (pergunta 9, para depois).
- Choque de raios (dois raios de frente) e golpe que muda o clima da arena.
- Times padrão do modo treino e seletor 1x1/2x2 na tela de treino (com a thread de testes, em `ui/training/`).
