# Mecânicas: batalha oficial (Gen 9) e como o jogo adapta

Registro pedido pelo Caio (2026-10-24). Para cada regra: como é no jogo oficial atual (Scarlet/Violet,
mesma base desde a Gen 5) e como está no PokmemonLike (tempo real), com o arquivo onde mora.
Números de ritmo (`damage_pace`, cooldowns) são do Caio e não entram aqui.

## 1. Fórmula de dano

**Oficial (Gen 5+):**

```
base = floor(floor(floor(2 × Nível / 5 + 2) × Poder × A / D) / 50) + 2
dano = base × alvos × clima × crítico × aleatório × STAB × tipo × queimadura × outros
```

Ordem e arredondamento (cada passo arredonda; "pokeRound" = mais perto, .5 desce):

| Passo | Valor | Arredonda |
|---|---|---|
| Alvos (spread) | 0,75 se o golpe tem mais de um alvo | pokeRound |
| Clima | Chuva: Água 1,5 / Fogo 0,5; Sol: o contrário | pokeRound |
| Crítico | 1,5 | pokeRound |
| Aleatório | inteiro 85..100, /100 | floor |
| STAB | 1,5 (Adaptability 2,0; Tera mesmo tipo 2,0) | pokeRound |
| Tipo | 0 / 0,25 / 0,5 / 1 / 2 / 4 | floor |
| Queimadura | 0,5 no físico (não com Guts nem Facade) | pokeRound |
| Outros | Reflect/Light Screen, Life Orb, Expert Belt, Multiscale, Filter... | pokeRound |

Mínimo 1 (exceto imunidade). A e D já com os estágios.

**Jogo:** `core/damage.gd` (`Damage.compute`) faz exatamente essa ordem, com floor/pokeRound. Spread e clima
entram por `mods` (`{"spread": 0.75, "weather": "rain"}`) ou campos do attacker. Guts: `attacker.guts`
(o lutador preenche em `fighter.gd` `damage_profile`). Terreno: `terrain_mult` multiplica o poder (1,3 no
oficial Gen 8+; a arena hoje passa 1,0). Os "outros" do jogo ficam fora da fórmula: habilidades
(`battle_abilities.gd` `_mults`) e combos (`battle_combos.gd`) entram em `battle_moves.gd` `extra_mult`,
depois o ritmo (`damage_pace`). A IA estima com `BattleMoves.expected_damage` (média do aleatório 0,925,
precisão, spread).

Antes (até 2026-10-24) a fórmula era a Gen 3 (queimadura no Ataque, sem arredondamentos intermediários).

## 2. Crítico

**Oficial (Gen 7+):** estágio 0: 1/24, +1: 1/8, +2: 1/2, +3: sempre. Dano 1,5x. Ignora os estágios
negativos do atacante e os positivos do defensor (e as telas). Focus Energy +2, golpe "alta chance" +1,
Super Luck +1.

**Jogo:** igual. `core/stat_calc.gd` (`CRIT_CHANCES`, `CRIT_MULT`), estágio no lutador (`crit_stage`,
Focus Energy em `battle_moves.gd` `_self_buff`, Super Luck em `battle_abilities.gd`), golpe com `"crit": 1`
em `data/moves.json`. Stats sem os estágios ruins: `fighter.gd` `crit_stat`.

## 3. STAB e tipos

**Oficial:** STAB 1,5 se o golpe é do tipo do usuário. Tabela de 18 tipos desde a Gen 6 (Fada; Aço perdeu
a resistência a Fantasma e Sombrio).

**Jogo:** STAB em `damage.gd`; Adaptability sobe para ~2,0 em `battle_abilities.gd`. Tabela em
`data/types.json` (`Dex.effectiveness`), conferida com a oficial (18x18 sem diferenças). Sem Tera.

## 4. Prioridade

**Oficial:** faixas de -7 a +5; dentro da faixa decide a Speed (Trick Room inverte). Quick Attack/Aqua
Jet/Sucker Punch +1, Extreme Speed +2, Fake Out +3, Protect/Detect +4, Helping Hand +5, Whirlwind/Roar/
Dragon Tail/Circle Throw -6.

**Jogo:** rodadas em tempo real (`battle/battle_turns.gd`, desde 2026-10-24). No começo de cada rodada
(`ROUND_SECS` = 4 s) a IA escolhe o golpe; a fila sai como no oficial: prioridade do golpe (maior antes,
mais o bônus da habilidade em `BattleAbilities.priority_bonus`), depois a Speed efetiva (estágios,
paralisia 0,5x, Tailwind 2x, `BattleAbilities.order_speed_mult`), Trick Room invertendo dentro da faixa e
empate no sorteio. Cada lutador solta um golpe por rodada, na vez dele, com `MOVE_GAP` (0,8 s) entre um golpe
e o seguinte. Item do treinador entra como prioridade +6. Adaptado: a Speed decide a ordem, não quantas vezes
cada um ataca; quem entra no meio da rodada espera a próxima; quem não consegue soltar em `TURN_MAX` passa.
Por cima da fila continuam valendo: `"priority" > 0` sai quase sem preparo (0,04 s) e com GCD 0,6x, e a
prioridade negativa prepara mais devagar (`battle_moves.gd` `use`). Speed segue como fator de ritmo
(`StatCalc.battle_speed_factor`: cooldown, GCD, reflexo da IA) e velocidade de andar.

## 5. Precisão, evasão e estágios

**Oficial:** estágios de -6 a +6. Stats: (2+n)/2 ou 2/(2-n). Precisão/evasão: (3+n)/3 ou 3/(3-n).

**Jogo:** igual (`StatCalc.stage_mult`, `battle_moves.gd` `acc_mult`). Errar é físico: o golpe sai
desviado e pode acertar outro (`_miss_dir`). Evasão vem de Double Team/Minimize como chance de esquiva
por alguns segundos e clones (`battle_field.gd`). Golpes que nunca erram (Swift, Aerial Ace) não têm
`accuracy`.

## 6. Efeitos secundários

**Oficial:** chance por alvo depois do dano (ex.: Body Slam 30% paralisa). Serene Grace dobra, Sheer
Force tira o efeito e dá 1,3x, Shield Dust bloqueia.

**Jogo:** `"effect": {"status"|"stat", "chance", "self"}` em `data/moves.json`, rolado em `battle_moves.gd`
`hit`. Serene Grace/Sheer Force em `battle_abilities.gd`.

## 7. Status e duração

Desde 2026-10-24 os status seguem o oficial: duração em turnos (= rodadas de `BattleTurns`) e dano só no
fim de turno (`battle/battle_end_turn.gd`, uma vez por rodada; ver "Fim de turno (Gen 9)").

| Status | Oficial | Jogo (`fighter.gd`, `battle_end_turn.gd`) |
|---|---|---|
| Queimadura | 1/16 por turno, físico 0,5x, não acaba sozinha | igual |
| Veneno | 1/8 por turno, não acaba sozinho | igual |
| Toxic | n/16 no n-ésimo turno (n até 15, zera na troca) | igual (`toxic_n`; fora da luta vira veneno comum) |
| Paralisia | Speed 0,5x, 25% não age, não acaba sozinha | acaba sozinha depois de 10 s em campo (`PARALYSIS_SECS`, pedido do Caio; o que falta segue na troca), Speed 0,5x; falhar o golpe segue em 20% (`BattleMoves.PARALYSIS_FAIL`, não mexido) |
| Sono | 1-3 turnos (contador 2-4 que desce ao tentar agir); Rest 2 | igual (`sleep_turns`, `SLEEP_COUNTER`, `REST_COUNTER`); golpe não acorda |
| Congelamento | 20% de descongelar a cada tentativa de agir; Fogo descongela | igual (`THAW_CHANCE`) |
| Confusão | 2-5 turnos (contador desce ao tentar agir), 33% | contador 2-5 (`confusion_turns`); 33% de sair em direção aleatória |
| Troca | estágios, confusão, Leech Seed e contador do Toxic zeram; status principal fica (Toxic segue Toxic, sono guarda os turnos que faltam) | igual (lutador novo do `Mon`; `Mon.battle_status`/`sleep_left`/`par_left` guardam o resto dentro da luta; Baton Pass passa os estágios) |
| Hesitar | só se o alvo age depois | 0,5 s parado (tempo real) |
| Leech Seed | volátil, 1/8 por turno para quem plantou | igual (`seeded`, convive com outro status, sai na troca ou com Rapid Spin) |

"Tentativa de agir": para quem segue a fila de `BattleTurns` (IA em campo), o contador desce quando a vez
dele começa (`fighter.gd` `try_act`); quem acorda age na mesma vez, como no oficial. Quem não segue a
fila (Pokémon no teclado, `turn_mode` false) conta no fim de cada rodada, menos a rodada em que o status
começou (`round_count`). Mudou do tempo real antigo: o golpe com empurrão acordava; agora não acorda.

Imunidades oficiais: Fogo não queima, Elétrico não paralisa, Veneno não envenena, Planta não pega
Leech Seed (`battle_moves.gd` `STATUS_IMMUNE`).

**Dano residual sem o ritmo.** Regra do Caio: o 0,75 (`DAMAGE_PACE`) vale só sobre o dano final dos
golpes. Veneno, queimadura, Toxic, semente, Curse, Wrap/Bind, clima e Black Sludge (e as curas de fim de
turno) usam o valor oficial puro: `fighter.dot_scale()` não entra mais neles. `dot_scale` ficou só no dano
físico de tempo real (batida do arremesso em `battle_physics.gd`, chão queimado em `battle_field.gd`).

**Modo de energia: todo dano indireto e toda cura no ritmo (0,6).** Regra do Caio (2026-10-25): no modo de
energia o veneno, a queimadura e todo dano indireto (semente, Curse, Wrap/Bind, clima, Spikes, Stealth Rock,
Rough Skin, Aftermath, recuo do Desespero, lava, brasas, queda...) e toda cura em fração do HP (Recover,
Roost, Leftovers, Aqua Ring, Wish, frutinha, poção, Regenerator...) usam o mesmo fator do dano dos golpes
(`arena.damage_pace`, `BattleEnergy.DAMAGE_PACE` = 0,6), para tudo ficar proporcional. Fica de fora a cura
cheia (Rest, Healing Wish, Full Restore) e o que já sai do dano feito (dreno, recuo). Tudo passa por
`fighter.paced(n)` (e `dot_scale()`, que no modo de energia devolve o próprio 0,6). No VGC nada muda.

## 8. Regras de dupla

**Oficial:**
- Golpe de alvo único acerta um alvo; se ele caiu, vai para o outro adversário.
- Golpe de vários alvos ("all adjacent foes": Rock Slide, Heat Wave, Razor Leaf, Swift, Growl...; "all
  adjacent": Earthquake, Magnitude, Surf, Explosion acertam o parceiro também) dá 0,75x quando tem mais
  de um alvo.
- Follow Me / Rage Powder (+2): puxam para o usuário os golpes de alvo único do outro lado.
  Lightning Rod/Storm Drain puxam os de Elétrico/Água. Helping Hand (+5): golpe do parceiro 1,5x.
  Wide Guard bloqueia golpes de vários alvos; Ally Switch troca de lugar.

**Jogo:**
- `"multi_target": "all_opponents" | "all_other_pokemon"` em `data/moves.json` (dados oficiais).
  Sem o campo o golpe é de alvo único: cada uso acerta um alvo só, o mais perto/o primeiro alcançado,
  mesmo que o cone, o raio ou a área peguem os dois (`battle_moves.gd` `_claim`, `_victims`, estado do
  uso em `mv["_cast"]` criado em `_cast_copy`). Golpe de vários golpes (Double Kick) fica no mesmo alvo.
- Vários alvos acertam todos no alcance; com dois ou mais acertados no uso, dano 0,75x (`spread_of` ->
  `Damage.compute` mods). Área (aoe_self/aoe_target) conta quem está no raio no momento do impacto;
  projétil de vários alvos solta uma leva para cada adversário ao alcance (`_spread_shots`); jato
  (Heat Wave, Twister) conta quem está ao alcance ao soltar.
- `all_other_pokemon` acerta o parceiro perto (Earthquake). O parceiro pula quando vê o Earthquake do
  aliado (`battle_ai.gd` `_partner_quake`). Acerto no parceiro não marca combo nem aciona "Protegeu".
- Mesmo dano do 1x1: `DOUBLES_PACE = 1,0` (`battle_moves.gd`); só o spread muda o dano.
- Troca (oficial): sai antes de todos os golpes da rodada; quem entra não age nessa rodada e leva os golpes
  mirados em quem saiu; uma por lado por rodada (aqui por regra, no oficial por Pokémon); substituto de quem
  desmaiou no fim do turno. Jogo: `battle_arena.gd` `request_switch` / `begin_of_round` / `at_round_end`.
  Adaptado: quem cai no próprio fim de turno entra logo depois da virada e espera a rodada seguinte para agir.
- Follow Me ainda não existe; o mais parecido é "cobrir o parceiro" (`battle_moves.gd` `_cover`: em
  DEFENSIVO ou Muralha, com o parceiro abaixo de 60% de HP, 35% de chance de levar o golpe no lugar).
  Helping Hand existe nos dados, ainda sem efeito no parceiro.
- IA (`battle_ai.gd`): `expected_damage` conta o 0,75x; `_area_pick` escolhe o golpe de área quando os
  dois estão ao alcance e ele rende 1,25x o melhor de alvo único (`BattleMoves.expected_total` soma os
  alvos e desconta o parceiro); Earthquake com o parceiro perto é descontado em `pick`.

## 9. Proteção

**Oficial:** Protect/Detect (+4) bloqueiam quase tudo por um turno; uso seguido tem 1/3 de chance a cada
vez; Feint quebra; variantes punem contato (Spiky Shield, King's Shield, Baneful Bunker, Silk Trap,
Burning Bulwark).

**Jogo:** a defesa em tempo real é física: pular investida/terremoto, sair da área avisada, esquiva pela
evasão, CLASH de duas investidas (`battle_arena.gd` `_clash`), Dig/Fly fora de alcance (abaixo). Os golpes
de proteção (`battle_move_effects.gd`) valem a rodada inteira, como o turno do oficial: do uso até o fim
da rodada (`BattleEndTurn`, passo 17): Protect/Detect (Feint quebra), Quick Guard, Endure (aguenta com 1
HP), Wide Guard (golpes de vários alvos no lado), e também Follow Me/Rage Powder e Roost. Protect/Detect
em rodadas seguidas: chance 1, 1/3, 1/9... (`_stall_ok`), zera quando uma rodada passa sem usar (Detect
ainda não existe nos dados; o handler `special: "protect"` já serve). Com `turn_mode` false a rodada é o
relógio de `ROUND_SECS`. Counter/Mirror Coat (-5): postura de 1 s parado (tempo real); o golpe
físico/especial recebido nela volta 2x para quem bateu. Substitute: boneco com 1/4 do HP que leva dano e
status até quebrar (som atravessa).

## 10. Clima e terreno

**Oficial:** chuva/sol/areia/neve 5 turnos (8 com Heat/Damp/Smooth/Icy Rock): Água/Fogo 1,5x/0,5x;
Thunder/Hurricane 100% na chuva e 50% no sol; Blizzard 100% na neve; Solar Beam/Blade sem carga no
sol e 0,5x na chuva/areia/neve; Growth +2 no sol; ninguém congela no sol; Moonlight/Synthesis/Morning
Sun 2/3 no sol e 1/4 nos outros; Weather Ball muda de tipo e dobra. Tempestade de areia 1/16 por turno em
quem não é Pedra/Terra/Aço e +50% Def. Esp. de Pedra; neve (Gen 9, Snowscape/Snow Warning) +50% Def de
Gelo, sem dano. Habilidades: Drought/Drizzle/Sand Stream/Snow Warning criam o clima ao entrar;
Chlorophyll/Swift Swim/Sand Rush/Slush Rush dobram a Speed; Rain Dish, Ice Body, Dry Skin, Solar Power,
Hydration, Leaf Guard, Sand Veil/Snow Cloak, Sand Force; Cloud Nine/Air Lock suprimem. Terrenos 5
turnos, 1,3x no tipo para quem está no chão: Elétrico (sem sono), Grama (cura 1/16, Earthquake 0,5x),
Psíquico (bloqueia prioridade), Névoa (Dragão 0,5x, sem status).

**Jogo:** clima de luta em `battle_abilities.gd` (`weather_now`): Rain Dance/Sunny Day/Sandstorm/
Snowscape e Drought/Drizzle/Sand Stream/Snow Warning criam clima por 5 rodadas (`set_weather_rounds`;
8 com a pedra do clima como item segurado, `weather_rounds_for`), contadas no fim de turno; como no
oficial a rodada conta antes do efeito, então no 5º fim de turno o clima acaba sem tirar HP (a areia
tira 4 vezes). No modo de energia a "rodada" é o relógio de 4 s, então o clima dura 20 s. Tudo da lista
oficial acima vale (Def x1,5 em `_mults`, precisão em `BattleMoveEffects.accuracy_of`, carga do Solar
Beam/Blade em `move_for`, congelar/Leaf Guard em `blocks_status`, Hydration no passo do Shed Skin, Ice
Body/Rain Dish em `weather_residual`); o dano segue com o 0,75x do jogo no fim. A neve usa o id "hail".
`set_weather(kind, secs)` em segundos ficou só para testes; `arena.opts.weather` vale a luta toda (o
treino repassa `cfg.weather`).

Visual do clima: `battle/battle_weather_fx.gd` (filho da arena, monta só no primeiro clima da luta):
chuva com gotas, respingos, chão molhado com poças e relâmpago; neve com flocos e neve acumulando no
chão (derrete quando acaba); sol com feixes de luz, raios no canto da tela e poeira dourada; areia com
grãos, nuvens de poeira e névoa marrom. No mapa o chão é o do mundo (`WorldWeather.battle_cover` molha
ou cobre de neve os shaders do mapa); no treino vai um piso próprio (`gfx/shaders/weather_ground`).
Nome do clima e rodadas restantes no alto da tela. Fotos: `tests/battle/shot_weather.gd` (treino) e
`tests/battle/shot_weather_world.gd` (mapa), `-- weather=rain|hail|sun|sand`.

"Terreno" do jogo também são marcas no chão que mudam
o andar e às vezes queimam (cratera, buraco do Dig, poça, gelo, grama queimada, Spikes) em
`battle_field.gd`.

Terrenos de golpe (`battle_move_effects.gd`, 5 rodadas, um tira o outro): Grama (cura 1/16 no fim de
turno em quem está no chão, Planta 1,3x, Earthquake 0,5x), Elétrico (Elétrico 1,3x, ninguém no chão
dorme), Névoa (no chão sem status nem confusão, Dragão 0,5x). Ice Spinner e Defog apagam. Telas e lado:
Reflect/Light Screen/Safeguard/Mist 5 rodadas, Tailwind 4, Gravity 5, Trick Room 5
(`BattleTurns.trick_room_rounds`). Armadilhas: Spikes (marca no chão, 1/8 em quem pisa e não voa),
Stealth Rock (pedras em volta do adversário, 1/8 x eficácia de Pedra, pega quem voa), Toxic Spikes;
Rapid Spin tira as do adversário (e a semente e o Wrap de quem usa), Defog todas.

## Fim de turno (Gen 9)

**Oficial:** depois que todos agiram, os efeitos residuais saem numa ordem fixa (Showdown "residual
order"; dentro de cada passo pela Speed, Trick Room invertendo). Cada efeito com duração conta o turno
antes de agir: no turno em que acaba, não age.

**Jogo:** `battle/battle_end_turn.gd` (`arena.end_turn`), `run()` chamado UMA vez por rodada por
`BattleTurns._end_round` -> `arena.end_of_round` (com `turn_mode` false, a cada `ROUND_SECS`). Mostra
cada efeito na hora: popup no lutador ("-12 veneno", "+5 Leftovers"), clarão curto da cor do efeito no
sprite (`fighter.residual_damage/residual_heal/flash`), aviso no log quando algo de campo acaba e a linha
"Fim da rodada" no HUD (`warn`). `last_log` guarda os passos na ordem (testes).

| # | Passo | Valor |
|---|---|---|
| 1 | Clima: conta a rodada; areia; Rain Dish, Dry Skin, Solar Power | areia 1/16; Rain Dish +1/16; Dry Skin +1/8 chuva, -1/8 sol; Solar Power -1/8 |
| 2 | Future Sight cai (fim do 2º turno depois do uso) | dano do golpe |
| 3 | Wish cura (fim do turno seguinte) | +1/2 do HP de quem desejou |
| 4 | Por lutador: Grassy Terrain, Shed Skin, Leftovers / Black Sludge | +1/16; 1/3 de curar; +1/16; Black Sludge +1/16 no Veneno, -1/8 nos outros |
| 5 | Aqua Ring | +1/16 |
| 6 | Ingrain | +1/16 |
| 7 | Leech Seed | -1/8, o mesmo HP vai para quem plantou (ou quem está no lugar dele) |
| 8 | Veneno / Toxic (Poison Heal cura no lugar) | -1/8 / -n/16; Poison Heal +1/8 |
| 9 | Queimadura | -1/16 |
| 10 | Curse (Fantasma) | -1/4 até sair de campo |
| 11 | Wrap/Bind, Fire Spin, Whirlpool, Sand Tomb... | -1/8 por 4-5 turnos; acaba se quem prendeu sai; não deixa fugir |
| 12 | Fim de Taunt (3), Encore (3), Disable (4), Heal Block, Throat Chop (2); Yawn dorme | — |
| 13 | Lado: Reflect, Light Screen, Safeguard, Mist (5), Tailwind (4) | — |
| 14 | Campo: Trick Room (5), Gravity (5), terrenos (5) | — |
| 15 | Uproar (3) | — |
| 16 | Speed Boost (+1, não no turno em que entrou) e os adaptados Natural Cure, Regenerator 1/16, Pickup 2% | — |
| 17 | Acaba o que vale só a rodada: Protect, Endure, Quick/Wide Guard, Roost, Follow Me (e conta o Laser Focus, 2) | — |
| 18 | Sono/congelado/confusão de quem não segue a fila | — |

Todo dano/cura residual: `floor(HP máx. x fração)`, mínimo 1 (Toxic: `floor(HP/16)` x n). Magic Guard
segura o dano. Frutinhas seguradas agem na hora, como no oficial (não no fim de turno): Oran +10 e Sitrus
+1/4 com HP <= 1/2, Pecha contra veneno, Persim contra confusão (`BattleEndTurn.held_check`, chamado por
`take_damage`/`apply_status`). Item segurado = `trainer_item` (o mesmo de Fling/Knock Off/Trick);
Leftovers, Black Sludge e Sitrus Berry entraram em `data/items.json` (sem `hp`/`cure` no efeito, para a
IA não "usar" como item do treinador nem aparecerem na lista do treino).

Adaptado / fora do oficial: o turno é a rodada de `ROUND_SECS` (4 s); Natural Cure e Regenerator agem em
campo; sono/confusão de quem não segue a fila contam no fim da rodada; Future Sight só cai se quem usou
ainda está vivo. Não existem nos dados: Nightmare, Salt Cure, Hydration, Ice Body, Moody, Binding Band,
Big Root, Detect (handler pronto). Sem Trick Room nos golpes (só `toggle_trick_room`).

## 11. Semi-invulnerável (Dig, Fly, Bounce, Dive)

**Oficial:** dois turnos; no primeiro some. No subsolo (Dig) só Earthquake/Magnitude (2x) e Fissure
acertam; no alto (Fly/Bounce) Gust/Twister (2x), Thunder, Hurricane, Sky Uppercut, Smack Down; embaixo
d'água (Dive) Surf/Whirlpool (2x).

**Jogo (`battle/battle_physics.gd`, `fighter.gd` `hidden`):**
- Dig (`"tunnel": "dig"`): afunda em 0,3 s (sprite desce e some, invulnerável), anda por baixo até o
  alvo a `speed` m/s seguindo-o (até `range` m), deixa rastro de terra e sai embaixo dele: acerto com
  arremesso para cima e buraco no chão. Errar = sai do lado. Ganchos visuais (se existirem):
  `arena.vfx.burrow(user)`, `dig_trail(user, from, to, duração)`, `unburrow(user)`; senão poeira
  (`PixelFx.pop "dust"`).
- Fly/Bounce (tabela `LEAP_IDS`, "sky"): salto alto e longo, fora de alcance no meio.
- A lista de quem alcança e quem bate 2x é a oficial (`REACHES_HIDDEN`, `HIDDEN_DOUBLE`).
- A IA não ataca alvo escondido com golpe que não alcança (`battle_ai.gd` `_reaches`).

## 12. Troca forçada e empurrão (adaptação física)

**Oficial:** Whirlwind/Roar (-6) forçam troca; Dragon Tail/Circle Throw causam dano e forçam troca.
Não existe empurrão.

**Jogo (`battle_physics.gd`):**
- Todo golpe empurra (`"knockback"`); o empurrão é multiplicado pela eficácia (super 1,5x, 4x 1,9x, pouco
  efetivo 0,55x, 0,25x 0,35x), crítico 1,4x e peso (`weight_kg`, referência 40 kg) em `knock_mult`.
- Golpes de troca forçada arremessam o alvo longe (`"push"` em m; Whirlwind 5 m nos dados, Roar/
  Dragon Tail/Circle Throw pela tabela `PUSH_IDS`). Contato físico com poder >= 80 também arremessa
  (0,6 m + 1,2 m a cada 40 de poder acima de 80), no último acerto.
- Arremessado bate na cerca, em caixa/pedra (`battle_field.gd`) ou parede: para, perde até 8% do HP
  máximo (pela velocidade da batida) e o objeto leva o tranco. Gancho opcional: `arena.vfx.crash(f, at,
  o_que)` e `arena.vfx.launch(f, dir, dist)`.

## 13. Saltos e investidas

- Body Slam (`"leap"`), Stomp, Heavy Slam, Heat Crash, High Jump Kick: o atacante pula e cai em cima do
  alvo (segue o alvo nos primeiros 60% do salto); o acerto é no pouso, no alvo mais perto (até 1,3 m).
- Earthquake/Magnitude (`"slam": true`): agacha, pula no lugar e o tremor sai no pouso (Magnitude pula
  mais quanto maior a magnitude).
- Aerial Ace (`"blink"`, também Feint Attack/Shadow Sneak pela tabela): some por 0,18 s, reaparece no alto
  ao lado do alvo e cai acertando (nunca erra, como o oficial).
- Investidas longas (dash com `range` >= 6: Quick Attack 8,5 m a 22 m/s, Aqua Jet, Volt Tackle, Sucker
  Punch) fecham distância; a IA usa de longe (`battle_ai.gd` `_rush_move`). Volt Tackle ainda sem o
  recuo oficial de 1/3.

## Testes

`tests/battle/test_end_turn.gd`: fim de turno uma vez por rodada, valores oficiais (veneno, queimadura,
Toxic, Leftovers, Black Sludge, frutinhas, Leech Seed, areia e imunidades, Curse, Wrap, Aqua Ring,
Grassy), a ordem dos passos, a Speed dentro do passo (e o Trick Room), sono/confusão/congelado em
tentativas, clima/Tailwind/telas/Trick Room/Gravity/Taunt/Disable em rodadas, Protect a rodada toda e o
1/3 no uso seguido, Follow Me, Yawn, Wish, Future Sight e o dano residual sem o `damage_pace`.

`tests/battle/test_gen9_physics.gd`: fórmula (spread, queimadura, Guts, pokeRound, clima), spread 0,75x
no Earthquake, parceiro no `all_other_pokemon`, Swift nos dois, alvo único na dupla (cone, raio, multi-hit),
mesmo dano no 1x1 e 2x2, empurrão por eficácia/crítico/peso, Whirlwind, batida na cerca e na caixa, Body
Slam, Earthquake pulando, Aerial Ace, Dig e a IA.

## Habilidades (Gen 9 / VGC)

**Oficial:** "ao entrar" (Intimidate, Drought, Frisk, Unnerve, Cloud Nine) age na entrada e na troca, do
mais rápido ao mais lento; "fim de turno" (Speed Boost, Shed Skin, Rain Dish, Dry Skin, Solar Power,
Poison Heal, dano da areia) age no fim de cada turno, também pela Speed. Lightning Rod/Storm Drain puxam
golpes de alvo único do tipo, ficam imunes e ganham +1 At. Esp.; golpes de vários alvos não são puxados.

**Jogo (`battle/battle_abilities.gd`, `data/abilities.json`):** o turno é a rodada de `BattleTurns`
(`ROUND_SECS`). O fim de turno é `BattleEndTurn.run()` (os passos 1, 4, 8 e 16 chamam as habilidades;
`on_round_end()` faz só a parte delas); BattleTurns consulta
`order_speed_mult(f)` e `priority_bonus(f, mv)` para a fila; `BattleMoves.hit` chama
`redirect(user, target, mv)` antes de `immune`. A ordem de ativação usa `arena.turns.speed_order`
(Trick Room inverte, empate no sorteio).

| Habilidade | Segue o oficial | Adaptado ao tempo real / rodada |
|---|---|---|
| Intimidate | -1 Ataque em todos os inimigos ativos (os dois no 2x2), na entrada e na troca; Inner Focus, Oblivious, Own Tempo seguram; Defiant/Competitive tomam o -1 e ganham +2 | espera o inimigo estar em campo |
| Drought | sol ao entrar, 5 turnos | 5 rodadas (`set_weather_rounds`), como o clima de golpe |
| Cloud Nine, Frisk, Unnerve | anunciam ao entrar | Unnerve segura o item do treinador (não há frutinha) |
| Lightning Rod, Storm Drain | puxam golpe de alvo único do tipo mirado no parceiro; imunes, +1 At. Esp.; Discharge/Bubble (vários alvos) não | — |
| Speed Boost | +1 Speed no fim do turno, não no turno em que entrou | fim da rodada (antes: a cada 8 s) |
| Shed Skin, Rain Dish, Dry Skin, Solar Power, Poison Heal, areia | 1/3; 1/16; chuva +1/8, sol -1/8; -1/8; +1/8 sem dano de veneno; -1/16 | fim da rodada (antes: timers de 2–3 s); neve (hail) da Gen 9 sem dano |
| Natural Cure, Regenerator | curam status / 1/3 do HP ao sair na troca | em campo: Natural Cure cura no fim da rodada; Regenerator 1/16 por rodada |
| Chlorophyll, Swift Swim, Sand Rush, Unburden, Quick Feet | Speed 2x (Quick Feet 1,5x, sem o corte da paralisia) na ordem | andar e preparo x1,5 (`walk_mult`, `cast_speed_mult`) |
| Prankster, Gale Wings | +1 de prioridade (status; Voador com HP cheio); Prankster não pega em Sombrio | preparo do golpe mais rápido também |
| Friend Guard, Plus/Minus, Telepathy | parceiro 0,75x de dano; At. Esp. 1,5x com parceiro Plus/Minus; imune a golpe de dano do parceiro | Infiltrator ignora o Friend Guard (inventado) |
| Damp | ninguém explode com ele em campo; bloqueia Aftermath | o usuário da Autodestruição ainda cai |
| Multiplicadores | Huge Power 2x, Hustle 1,5x/precisão 0,8, Iron Fist 1,2x (só socos), Strong Jaw (mordidas), Reckless (recuo e queda), Tinted Lens 2x, Marvel Scale só no físico, Rough Skin 1/8, Aftermath só no contato, Cute Charm só sexo oposto, Effect Spore não pega em Planta, Soundproof com a lista oficial | — |
| Shell Armor, Battle Armor, Sniper, Skill Link, Illuminate | sem crítico; crítico 2,25x; golpe de vários acertos sempre no máximo; a precisão não cai | igual ao oficial (2026-10-24: o Caio pediu os números oficiais em tudo; só o dano final é escalado pelo `damage_pace`) |
| Adaptadas ao tempo real (Arena Trap, Magnet Pull, Run Away, Rock Head, Pickup, Sand Veil, Tangled Feet, No Guard) | — | efeitos contínuos valem contra todos os inimigos no 2x2; Pickup cura 2% por rodada; No Guard só nos golpes dele |

Supressão: Cloud Nine/Air Lock anulam o clima; Gastro Acid/Worry Seed trocam a habilidade por
`ability_override`. Mold Breaker/Teravolt/Turboblaze, Healer, Power of Alchemy, Receiver, Slush Rush e
Triage não existem nos dados. Trick Room não existe nos golpes; o handler `special: "trick_room"` já
chama `arena.turns.toggle_trick_room()` (`battle_move_effects.gd`). Testes:
`tests/battle/test_abilities.gd` e `test_gen9_abilities.gd`.

### As 151 habilidades que faltavam (`battle/battle_abilities_more.gd`)

Todas as habilidades da Gen 3-9 têm efeito (`desc_pt` em `data/abilities.json`). As de tabela (Pure Power,
Solid Rock, White Smoke, Magma Armor, Water Bubble, os `-surge`...) ficam em `battle_abilities.gd`; o resto
em `BattleAbilitiesMore` (estático, recebe o `BattleAbilities`), chamado pelos ganchos de sempre
(`_mults`, `immune`, `blocks_hit`, `on_hit`, `adjust_damage`, `tick`, `late_residual`, `move_for`...).
Texto sempre no mesmo formato: o que faz no jogo, com os números. Teste: `tests/battle/test_more_abilities.gd`.

| Grupo | Adaptação ao tempo real / rodada |
|---|---|
| Tipo do golpe (Normalize, Pixilate, Refrigerate, Liquid Voice, Protean, Libero, Color Change, Multitype, RKS System, Hunger Switch) | `BattleAbilities.move_for` troca o `type` do golpe na hora de usar (`BattleMoveEffects.move_for`); os -ate dão x1,3 (`ate`), Normalize x1,2; Protean/Libero uma vez por entrada em campo; Multitype/RKS sem Placa/Memória (não há no jogo) usam o tipo do melhor golpe que não é Normal |
| Formas sem arte (Zen Mode, Stance Change, Schooling, Shields Down, Disguise, Ice Face, Gulp Missile, Hunger Switch, Forecast, Zero to Hero, Tera Shift) | `BattleAbilitiesMore.set_form`: multiplica os stats da espécie pelos da forma oficial, tipo extra, tom do sprite (`form_tint`, lido por `BattleFighter._tint`) e tamanho; mesmo estilo do Transform. Zero to Hero vira Herói ao voltar de uma troca ou, em tempo real, ao cair para metade do HP; Disguise e Ice Face absorvem o 1º golpe (1/8 do HP no Disguise); Ice Face volta na neve |
| Campos e clima (Grassy/Electric/Misty/Psychic Surge, Orichalcum Pulse, Hadron Engine, Seed Sower, Sand Spit) | usam `BattleMoveEffects._set_terrain` e `set_weather_rounds` (5 rodadas) |
| Paradoxo (Protosynthesis, Quark Drive) | sol / campo elétrico (não há Booster Energy): melhor stat x1,3 (Speed x1,5) |
| Prioridade (Queenly Majesty, Dazzling, Armor Tail, Triage) | `blocks_hit` barra golpe de prioridade inimiga no time; Triage +3 e preparo x1,5 nos golpes de cura |
| Troca (Shadow Tag, Suction Cups, Guard Dog, Wimp Out, Emergency Exit) | Shadow Tag entra em `cant_escape`; Suction Cups/Guard Dog não são empurrados pelo Whirlwind/Roar (`anchored`; golpes novos de arrastar devem consultar); Wimp Out/Emergency Exit só trocam no modo de energia, ao cruzar a metade do HP |
| Item (Pickpocket, Magician, Symbiosis, Klutz, Ripen, Cheek Pouch, Cud Chew, Ball Fetch, Honey Gather) | o item do lutador é o `trainer_item`; Cud Chew devolve a frutinha na rodada seguinte; Ball Fetch devolve a 1ª bola que falhou; Honey Gather acha o item `honey` ao vencer (5% + 5% por 10 níveis, até 50%) |
| Time (Battery, Power Spot, Steely Spirit, Flower Gift/Veil, Sweet/Aroma Veil, Victory Star, Costar, Hospitality, Receiver, Commander, Dancer) | agem no parceiro do 2x2; Commander esconde o Tatsugiri na boca do Dondozo parceiro (`hidden = "commander"`, não age) e dá +2 em tudo; Dancer repete o golpe de dança 0,6 s depois sem custo |
| Ruin (Tablets/Sword/Vessel/Beads of Ruin) | quem não tem a habilidade bate x0,75 (físico/especial) ou apanha x1,33 |
| Contato e gatilho (Gooey, Mummy, Lingering Aroma, Wandering Spirit, Iron Barbs, Perish Body, Stamina, Steam Engine, Cotton Down, Toxic Debris, Berserk, Anger Shell...) | `BattleAbilitiesMore.on_hit`; Berserk/Anger Shell/Wimp Out olham o HP de antes do golpe (`adjust`) para ver se cruzou a metade |

Truant age uma rodada e vadia a outra (`move_blocked`); Slow Start dura 5 rodadas; Moody, Bad Dreams e
Hunger Switch agem no fim da rodada; Mirror Armor/Contrary/Simple ficam em `BattleMoves.change_stage`.
Turboblaze e Teravolt são Mold Breaker (`BREAKERS`). Prism Armor, Shadow Shield, Full Metal Body, Disguise
e Ice Face não são ignorados por ele (`UNBREAKABLE`).
