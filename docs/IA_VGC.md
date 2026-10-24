# IA no estilo VGC

Pedido do Caio (2026-10-24): pesquisa de como jogadores de VGC decidem e duas IAs em cima dela, uma do
treinador (trocas, itens) e uma de cada Pokémon (golpe e alvo no 2x2). Os números abaixo são ponto de
partida; dano e multiplicadores seguem o oficial (só o dano final em 0,75x).

## Pesquisa (resumo)

Fontes lidas: vgcguide.com (Protect, controle de Speed, singles para duplas, Worlds 2017 Tansley x Dunlop),
Smogon (Protect your Tool, Speed Control in VGC, Momentum in VGC), documentação das flags de IA do
pokeemerald-expansion (`docs/tutorials/ai_flags.md`) e a wiki da IA de troca dele. Victory Road, Nimbasa,
Trainer Tower e Pikalytics não abriram na pesquisa; os limiares marcados como "nosso" são escolha nossa.

| Tema | Regra que virou heurística |
|---|---|
| Alvo | Mirar quem dá KO ou quem mais ameaça o meu lado; suporte de Speed (Tailwind, Follow Me) vale mais. |
| Foco (double target) | Os dois no mesmo alvo quando juntos derrubam e nenhum derruba sozinho. Não gastar golpe em quem o parceiro já derruba. |
| Golpe de área | 0,75x por alvo com dois alvos; vale quando a soma passa o melhor de alvo único; acertar o parceiro conta contra (Earthquake), a não ser que ele seja imune (voando). |
| Redirecionamento | Lightning Rod/Storm Drain puxam golpe de alvo único do tipo: mirar o outro é desperdício. |
| Protect | Só com ameaça de KO, quando o parceiro resolve a ameaça, ou para queimar o Tailwind/Trick Room do outro lado. Seguido funciona 1/3 das vezes: quase nunca repetir. Prever o Protect do alvo ameaçado e sem Protect na rodada anterior. |
| Tailwind | Dobra a Speed por 4 turnos contando o do uso; mais forte no 1º turno e quando o meu lado é o mais lento. Inútil contra Trick Room. |
| Trick Room | 5 turnos, prioridade -7; só quando o meu lado é o mais lento. |
| Status | Paralisia em quem é mais rápido, queimadura em atacante físico, sono sempre bom; status em alvo quase caindo não paga. Buff só em rodada segura (aguento 2 golpes ou mais) e quando ainda preciso de vários golpes para derrubar. |
| Fake Out | Só no 1º turno em campo; muito valor. |
| Helping Hand | Quando o 1,5x faz o golpe do parceiro derrubar. |
| Troca | Sair com matchup ruim (leva muito e tira pouco), todos os golpes sem efeito, ou ataque em -2; só quem ainda tem HP para valer a troca (o fraco fica e bate); quem entra precisa aguentar o golpe da entrada. Evitar ping-pong; a IA oficial erra de propósito às vezes. |
| Quem entra depois do KO | Ordem do expansion: quem derruba e é mais rápido > quem derruba > bom matchup > o resto. |
| Item (jogo principal) | Curar só se a cura faz sobreviver à rodada; curar status que atrapalha. |
| Estrutura | Pontuação aditiva por (golpe, alvo), como as flags do expansion, com ruído e taxa de erro para não ficar previsível. |

## IA de cada Pokémon: `battle/battle_tactics.gd` (BattleTactics)

Chamada por `BattleAI.pick` (começo da rodada, `plan_round`). Cada golpe disponível ganha uma pontuação;
o maior vence (ruído de ±8% no ataque e no Protect, ±35% nos outros status). Escolhe também o alvo
(`f.opponent`, que fica a rodada inteira).

- **Dano:** fração do HP atual do alvo (até 1) + 0,8 se derruba, vezes o valor do alvo (1 + 0,6 x quanto ele
  ameaça o meu lado + 0,25 se faz suporte). Prioridade que derruba alguém mais rápido +0,6. Fake Out +0,7.
  Efeito de status do golpe +0,15 x chance.
- **Dupla:** foco +0,6 quando o golpe do parceiro (a intenção dele) e o meu juntos derrubam; se ele já
  derruba sozinho, o meu golpe ali vale quase nada. Área soma os alvos com 0,75x e desconta 1,5x a fração
  do parceiro (+1,5 se derruba o parceiro). Lightning Rod/Storm Drain redirecionam na conta. Alvo que deve
  usar Protect (ameaçado, com Protect livre) vale 0,8x.
- **Protect/Wide Guard:** a partir de ameaça de 50% do HP (o maior golpe de um inimigo + metade do segundo);
  +0,3 se o parceiro derruba quem me ameaça; seguido quase nunca.
- **Tailwind** com alguém do meu lado mais lento e sem Tailwind/Trick Room; **Trick Room** só com o meu
  lado mais lento; **Helping Hand** quando faz o parceiro derrubar; **Follow Me/Rage Powder** com o parceiro
  ameaçado e eu com HP; **Thunder Wave** nunca no Terra.
- **Buff:** 0,9 x o melhor ataque da rodada, vezes o quanto a rodada é segura; metade se já derrubo alguém
  em 2 golpes. Os outros status (telas, Taunt, Spikes) entram às vezes, pelo peso antigo.
- **Comando** (OFENSIVO/DEFENSIVO/SUPORTE/LIVRE), **Natureza** (temperamento de `BattleProfile`) e
  **ânimo** (Fúria/Pânico) multiplicam no fim. O nível da IA (`think_scale`) dá a chance de erro.
- Selvagem segue a IA antiga. `opts.vgc_ai: false` desliga; `[true, false]` liga só num lado.

## IA do treinador: `battle/battle_trainer_ai.gd` (BattleTrainerAI)

Um por lado em `arena.trainer_ai` (o adversário treinador e, sem teclado, o lado do jogador). Usa a
interface da thread de turnos: `round_start()` no começo da rodada, `request_switch`,
`request_trainer_item`, `bench_of`, `pick_replacement(slot)`.

- **Troca** (uma por rodada): matchup ruim = leva >= 50% e tira < 30%, ou nenhum golpe pega, ou ataque em
  -2; HP >= 40%; quem entra leva no máximo 60% (e no máximo 60% do que o atual levaria) e bate pelo menos
  80% do que o atual bate. Sem trocar o mesmo Pokémon de novo por 2 rodadas. Chance de trocar 0,7 no
  `think_scale` 1 (mais esperto, mais vezes).
- **Item do treinador** (um por Pokémon): cura com HP <= 35% se sobrevive à rodada curado; cura sono,
  paralisia, queimadura em físico, veneno com HP > 40%.
- **Substituto:** maior (dano que tira - 0,7 x dano que leva), +0,3 se derruba, +0,15 se é mais rápido.
- `opts.trainer_ai: false` desliga (`[lado 0, lado 1]` por lado).

## Treino

- Criador de times: **Jogador 1: IA / Manual**. Manual = o lado A no teclado (`opts.keyboard`), só na luta
  única; "Rodar série" sempre usa IA.
- Duelo de IAs: `tests/balance/ia_duel.gd` (times "Vento" e "Floresta" com Protect, Tailwind, Fake Out,
  Follow Me e golpes de área, mesmo time nos dois lados e cruzado, IA nova x antiga nos dois lados).

```bash
"/c/Users/User/Desktop/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --headless --fixed-fps 60 --path . --script res://tests/balance/ia_duel.gd -- seeds=5
```

Resultado de 2026-10-24 (5 sementes, 40 lutas, já com Protect valendo a rodada inteira): com o mesmo
time dos dois lados a IA nova venceu 14 de 20 (1 empate por tempo); contando os cruzados, 24 de 40. A IA
nova usou Protect em ~16% das ações, Tailwind 21 vezes, Helping Hand 40, Follow Me 18, trocou de 1 a 3
vezes por luta com o time "Vento" e usou a Super Poção quando a cura salvava.

## Testes

`tests/battle/test_vgc_ai.gd`: ligação nas opções, alvo super efetivo, KO primeiro, foco e sobra, área com
o parceiro no chão e voando, Protect (ameaça, não repetir, sem ameaça), Tailwind, Thunder Wave fora do
Terra, Helping Hand, comando no Protect, troca (matchup ruim, HP baixo, ping-pong), item (cura que salva,
morre de todo jeito), substituto e troca numa luta de verdade.
