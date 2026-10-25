# Revisão de fidelidade dos golpes e habilidades novos (Gen 2-9)

Revisão do EFEITO dos 231 golpes e 151 habilidades que entraram para as 1025 espécies, contra o oficial da Gen 9
(PokeAPI `effect_entries`/`meta` e Showdown `moves.json`/`abilities`). Os números (poder, precisão, PP, prioridade,
chance) já tinham sido conferidos por script e não foram refeitos. Testes: `tests/battle/test_revisao.gd`.

## O que foi conferido

- **Golpes (231)**: efeito secundário (status, chance, estágio, usuário x alvo), dreno, recuo, multi-acerto, crítico,
  `self`/`selfBoost`, flags (contato, som, soco, mordida, corte, vento, bala, pulso, dança) e as chaves especiais do
  Showdown (`ignoreAbility`, `thawsTarget`, `breaksProtect`, `stallingMove`, `mindBlownRecoil`...), um a um contra os
  dados de `tools/moves_more_a.py`/`moves_more_b.py`. Todo `special` usado nos dados tem tratamento no código; a
  mecânica de `battle_more_a.gd` e `battle_more_b.gd` foi lida inteira.
- **Habilidades (151)**: `desc_pt` contra o `effect_entries` da PokeAPI e contra o código de `battle_abilities_more.gd` e
  `battle_abilities.gd` (multiplicadores, gatilhos, bloqueios, formas), e a lista `UNBREAKABLE` contra a flag
  `breakable` do Showdown.
- **Tipo vazio** (Double Shock, Burn Up): nenhum `types[0]` fica sem guarda (HUD, Judgment, Multi-Attack, Revelation
  Dance, Reflect Type, STAB e eficácia funcionam sem tipo).

## O que estava errado e foi corrigido

| Onde | Problema | Correção |
|---|---|---|
| King's Shield | contato tirava -2 de Ataque (valor da Gen 6-7) | -1, como a Gen 8+ |
| Obstruct, Silk Trap | barravam também golpes de status | só barram golpes de dano (Spiky Shield segue barrando tudo) |
| Contato | só o `kind` decidia; 11 golpes oficialmente sem contato (Aura Wheel, Beak Blast, Fusion Bolt, Gigaton Hammer, Ivy Cudgel, Last Respects, Meteor Assault, Order Up, Salt Cure, Hyperspace Hole, Secret Sword) ativavam Rough Skin, Static, Tough Claws, Fluffy, King's Shield etc., e 4 de contato (Anchor Shot, Fire Lash, Mortal Spin, Comeuppance) não | campo `"contact"` nos dados vale mais que o `kind` (`_is_contact`, `BattleMoreA._contact`, `BattleMoreB._touches`) |
| Soundproof / Throat Chop | Clangorous Soul, Confide, Howl, Snarl (Soundproof) e Clangorous Soul, Confide, Grass Whistle, Parting Shot (Throat Chop) faltavam nas listas de som | incluídos |
| Wind Rider / Wind Power | Aeroblast faltava na lista de vento | incluído |
| Dancer | Clangorous Soul faltava nos golpes de dança | incluído |
| Moongeist Beam, Photon Geyser | `ignoreAbility` oficial não fazia nada ("simplificado") | passam por cima da habilidade do alvo durante o golpe (usuário vale como Mold Breaker, igual ao Sunsteel Strike) |
| Hydro Steam, Steam Eruption, Matcha Gotcha | não descongelavam o alvo (`thawsTarget`) | entraram em `THAW_MOVES` |
| Pixilate, Refrigerate | x1,3 (texto antigo da PokeAPI) | x1,2 (Gen 7+); `desc_pt` e `MECANICAS.md` atualizados |
| Mold Breaker | Disguise, Ice Face e Thermal Exchange estavam em `UNBREAKABLE`, mas o Showdown os marca `breakable` | Mold Breaker (e Turboblaze/Teravolt) passa por cima deles |
| Transform | falhava contra alvo sem tipo (Double Shock) | copia o alvo sem tipo; aviso com cor segura |
| `desc_pt` do Aroma Veil | não citava Torment, que o código já bloqueia | texto corrigido |

Double Shock continua deixando o usuário com `types = []` (sem tipo: neutro contra tudo e sem STAB, como o oficial);
o que podia quebrar foi guardado e está no teste.

## Adaptações intencionais (não são erro)

- Golpes de 2 turnos, `recharge`, Bide, Shell Trap, Thunderclap, Quash, Fairy Lock, Core Enforcer etc. usam janelas
  de segundos e rodadas (`set_rounds`/`count_round`), documentadas em `docs/GOLPES.md`.
- Mind Blown e Steel Beam perdem metade do HP máximo ao usar, acertando ou não.
- Supersweet Syrup baixa a Speed (no oficial, a evasão); Moody nunca mexe em precisão/evasão.
- Natural Gift tem poder fixo 80 e só as frutinhas que existem no jogo; Techno Blast/Multi-Attack/Judgment seguem
  Drive, Memória e Placa só quando o item existe (senão usam o tipo do usuário ou o melhor golpe).
- Mycelium Might e Stall atrasam o preparo do golpe (x0,7 e x0,75) em vez de "agir por último".
- Zen Mode, Schooling, Shields Down, Zero to Hero, Stance Change, Tera Shift: formas sem arte, por multiplicador de
  stat, tom e tamanho do sprite.
- Wimp Out / Emergency Exit só trocam no modo de energia (no VGC o jogador escolhe).

## O que ficou diferente do oficial

- Wind Rider e Wind Power não reagem ao Tailwind (só a golpes de vento); Sandstorm e Tailwind seguem fora de
  `WIND_MOVES`. Custa pouco e fica para depois.
- Dynamax Cannon não dobra contra Dynamax (não existe aqui); Flying Press não é cancelado por Gravity e não dobra
  contra Minimize.
- Infestation e as outras armadilhas de zona não ativam habilidades de contato a cada tique (só o primeiro golpe seria
  contato no oficial, e aqui o tique de 0,5 s ativaria Static e afins sem parar).
- Burn Up e Double Shock só são bloqueados se o usuário ainda tem o tipo, mas Burn Up deixa o usuário Normal (como o
  Roost), não sem tipo.
- Natural Gift, Aroma Veil (sem Cursed Body) e Flower Gift seguem simplificados como no `desc_pt`.
