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

**Jogo:** não há turnos. `"priority" > 0` sai quase sem preparo (0,04 s) e com GCD 0,6x
(`battle_moves.gd` `use`). Speed vira o fator de ritmo (`StatCalc.battle_speed_factor`: cooldown,
GCD, fôlego, reflexo da IA) e a velocidade de andar. Prioridade negativa ainda não atrasa nada.

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

**Jogo:** ainda não há Protect. A defesa em tempo real é física: pular investida/terremoto, sair da área
avisada, esquiva pela evasão, CLASH de duas investidas (`battle_arena.gd` `_clash`), Dig/Fly fora de
alcance (abaixo).

## 10. Clima e terreno

**Oficial:** chuva/sol 5 turnos (8 com pedra): Água/Fogo 1,5x/0,5x; Thunder/Hurricane 100% na chuva;
tempestade de areia 1/16 por turno em quem não é Pedra/Terra/Aço e +50% Def. Esp. de Pedra; neve (Gen 9)
+50% Def de Gelo. Terrenos 5 turnos, 1,3x no tipo para quem está no chão: Elétrico (sem sono), Grama
(cura 1/16, Earthquake 0,5x), Psíquico (bloqueia prioridade), Névoa (Dragão 0,5x, sem status).

**Jogo:** a fórmula já aceita clima (`Damage.weather_mult`) e terreno (`terrain_mult`), mas a arena ainda
não tem clima de luta: Rain Dance sobe At. Esp. "Terreno" do jogo é outra coisa: marcas no chão que
mudam o andar e às vezes queimam (cratera, buraco do Dig, poça, gelo, grama queimada, Spikes) em
`battle_field.gd`.

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
