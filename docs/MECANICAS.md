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
(`StatCalc.battle_speed_factor`: cooldown, GCD, fôlego, reflexo da IA) e velocidade de andar.

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

| Status | Oficial | Jogo (`fighter.gd` `STATUS_TIME`, `_tick_status`) |
|---|---|---|
| Queimadura | 1/16 por turno, físico 0,5x | 6 s, 1/16 por s, físico 0,5x na fórmula |
| Veneno | 1/8 por turno (Toxic n/16) | 6 s, 1/12 por s |
| Paralisia | Speed 0,5x, 25% não age | 6 s, Speed 0,5x, 20% de falhar o golpe |
| Sono | 1-3 turnos | 3 s (acorda ao levar golpe com empurrão) |
| Congelamento | 20% de descongelar por turno | não existe ainda |
| Confusão | 2-5 turnos, 33% se acerta | 4 s, 33% de sair em direção aleatória |
| Hesitar | só se o alvo age depois | 0,5 s parado |
| Leech Seed | 1/8 por turno para o usuário | 6 s, 1/16 por s para quem plantou |

Imunidades oficiais: Fogo não queima, Elétrico não paralisa, Veneno não envenena, Planta não pega
Leech Seed (`battle_moves.gd` `STATUS_IMMUNE`). O dano por segundo acompanha o ritmo (`fighter.gd`
`dot_scale`).

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
de proteção (`battle_move_effects.gd`) viram janelas curtas: Protect 0,8 s (Feint quebra), Quick Guard
1,2 s, Endure 0,8 s (aguenta com 1 HP), Wide Guard 0,8 s (golpes de vários alvos no lado). Counter/Mirror
Coat (-5): postura de 1 s parado; o golpe físico/especial recebido nela volta 2x para quem bateu.
Substitute: boneco com 1/4 do HP que leva dano e status até quebrar (som atravessa). Sem a chance
reduzida do uso seguido.

## 10. Clima e terreno

**Oficial:** chuva/sol 5 turnos (8 com pedra): Água/Fogo 1,5x/0,5x; Thunder/Hurricane 100% na chuva;
tempestade de areia 1/16 por turno em quem não é Pedra/Terra/Aço e +50% Def. Esp. de Pedra; neve (Gen 9)
+50% Def de Gelo. Terrenos 5 turnos, 1,3x no tipo para quem está no chão: Elétrico (sem sono), Grama
(cura 1/16, Earthquake 0,5x), Psíquico (bloqueia prioridade), Névoa (Dragão 0,5x, sem status).

**Jogo:** a fórmula já aceita clima (`Damage.weather_mult`) e terreno (`terrain_mult`), mas a arena ainda
não tem clima de luta: Rain Dance sobe At. Esp. "Terreno" do jogo é outra coisa: marcas no chão que
mudam o andar e às vezes queimam (cratera, buraco do Dig, poça, gelo, grama queimada, Spikes) em
`battle_field.gd`.

Terrenos de golpe (`battle_move_effects.gd`, 5 turnos de 1,6 s, um tira o outro): Grama (cura 1/16 por
turno, Planta 1,3x, Earthquake 0,5x), Elétrico (Elétrico 1,3x, ninguém no chão dorme), Névoa (no chão
sem status nem confusão, Dragão 0,5x). Ice Spinner e Defog apagam. Rain Dance/Sunny Day/Sandstorm criam
clima. Armadilhas: Spikes (marca no chão, 1/8 em quem pisa e não voa), Stealth Rock (pedras em volta do
adversário, 1/8 x eficácia de Pedra, pega quem voa), Toxic Spikes; Rapid Spin tira as do adversário,
Defog todas.

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
(`ROUND_SECS`). A arena chama `on_round_end()` no fim de cada rodada; BattleTurns consulta
`order_speed_mult(f)` e `priority_bonus(f, mv)` para a fila; `BattleMoves.hit` chama
`redirect(user, target, mv)` antes de `immune`. A ordem de ativação usa `arena.turns.speed_order`
(Trick Room inverte, empate no sorteio).

| Habilidade | Segue o oficial | Adaptado ao tempo real / rodada |
|---|---|---|
| Intimidate | -1 Ataque em todos os inimigos ativos (os dois no 2x2), na entrada e na troca; Inner Focus, Oblivious, Own Tempo seguram; Defiant/Competitive tomam o -1 e ganham +2 | espera o inimigo estar em campo |
| Drought | sol ao entrar, 5 turnos | 5 rodadas (`set_weather_rounds`); clima de golpe segue em segundos |
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
