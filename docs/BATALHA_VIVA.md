# Batalha Viva

Reforma da batalha em tempo real (2026-10-24), a partir das respostas do Caio na página de propostas.
Os números são ponto de partida: o Caio balanceia pelo modo de treinamento.

## O que mudou

| Sistema | Onde | Resumo |
|---|---|---|
| Speed | `core/stat_calc.gd` | Fator `1 + 0,35·ln(minha/dele)`, limitado a 0,7–1,45 (cooldowns, GCD, fôlego, reflexo). Andar absoluto `3,0 + 0,012·Speed` m/s (2,4–5,6). Paralisia corta a Speed do fator pela metade. |
| Ritmo | `battle/battle_moves.gd` | Fórmula oficial Gen 5+ desde a Gen 9 física (`docs/MECANICAS.md`). O dano final é escalado por `damage_pace` (0,5, igual na dupla) e o PP gasto também. Abaixo de 1 a fração do dano passa para o próximo golpe no alvo (sem o mínimo de 1 por golpe), para o mesmo número de golpes por nocaute caber no PP. `opts.damage_pace` muda. Meta: 15–30 s por Pokémon. |
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
| Espetáculo | `battle/battle_hud.gd`, arena | Balão com o nome do golpe por lado, cena de impacto (a luta congela 0,4 s; no máx. 1 a cada 2,5 s), CLASH (duas investidas de frente se anulam), "Precisa recarregar!" depois do Hyper Beam, cobrir o parceiro com HP baixo (DEFENSIVO ou Muralha), cartões 2x2, etiquetas de comando, marcas e estágios, barra de Sintonia. |

## Testes novos

`tests/battle/test_doubles.gd`, `test_combos.gd`, `test_field.gd`, `test_abilities.gd`, `test_hud_viva.gd`.
`tests/battle/test_battle.gd` roda as regras no ritmo original (`damage_pace` 1,0, sem caixas no campo).

## Ainda não feito

- Chefe 1 contra vários (pergunta 9, para depois).
- Choque de raios (dois raios de frente) e golpe que muda o clima da arena.
- Times padrão do modo treino e seletor 1x1/2x2 na tela de treino (com a thread de testes, em `ui/training/`).
