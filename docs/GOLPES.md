# Guia dos golpes

Gerado por `tools/move_guide.py` (não editar à mão): 622 golpes, agrupados por tipo e em ordem alfabética.

## Como ler este guia

Este guia explica, golpe por golpe, como cada golpe oficial (dados da Gen 9) foi adaptado ao combate em tempo real do PokmemonLike. São 622 golpes. Ele é gerado por `tools/move_guide.py` a partir de `data/moves.json` (e `data/species.json` para contar quem aprende cada golpe); para atualizar, rode `python tools/move_guide.py caminho/da/pagina.html` da raiz do projeto. Os textos de adaptação vêm dos campos de cada golpe e dos dicionários do script, que seguem `battle/battle_move_effects.gd`, `battle/battle_moves.gd` e `battle/battle_physics.gd`.

Em cada golpe: tipo, categoria, poder oficial (`bp`), precisão, PP oficial, o tipo de entrega no jogo, alcance/área/duração quando há, o custo de energia e o cooldown no modo de energia, quantas espécies do jogo aprendem o golpe (152 espécies) e o texto de Adaptação.

## Do turno ao tempo real

- **Dano.** A fórmula é a oficial Gen 5+ (`core/damage.gd`), com os arredondamentos oficiais: base com nível, poder e Ataque/Defesa já com estágios, depois spread, clima, crítico (1,5x), sorteio inteiro de 85 a 100%, STAB (1,5x), eficácia da tabela de 18 tipos, queimadura (0,5x no físico) e os 'outros' (telas, habilidades, combos). No fim, o ritmo do jogo multiplica o dano final por **0,75** (`damage_pace`): vale só sobre o dano dos golpes; veneno, queimadura, clima, dreno e cura usam o valor oficial.
- **Precisão = erro físico.** O golpe rola a precisão (com estágios de Precisão, (3+n)/3) ao sair. Se falhar, ele sai desviado do alvo mirado (projétil, raio e investida passam ao lado; área cai 2-3 m longe) e pode acertar outro. Só erram as entregas `dash`, `arc`, `multi_arc`, `whip`, `projectile`, `beam`, `aoe_target` e `zone`; `homing`, `stream`, `aoe_self` e golpes de status sem projétil nunca erram. Golpe sem precisão (Swift) nunca erra. Evasão (Double Team, Minimize) é uma chance de esquiva por alguns segundos. Fora isso, o jogo é físico: dá para pular a investida e sair da área avisada.
- **PP e energia.** Nos modos normais há um único pool de PP de 100: cada golpe gasta `100 / PP oficial` (os PP do oficial viram 'usos'). No **modo de energia** (padrão no treino) a barra de energia (0 a 100, enche 5/s) substitui o PP: o custo é `12 + 0,25 x poder` (teto 50), status custa 28, golpe de poder variável conta como 70, multi-hit conta pelos acertos (2-5 = 3,1 de média) e prioridade custa 0,6x.
- **Cooldown.** Cada golpe tem o seu: `(preparo + duração + peso/40) x 2,5`, com `peso` = 10 x custo de PP, mínimo 1,6 s. Golpe forte (poder > 70) alonga por `1 + (poder - 70)/80`. Status espera x3, mínimo 8 s. Prioridade multiplica o cooldown por 1,8 no modo de energia. Os números das tabelas são antes do fator de Speed e do GCD (1 s entre golpes).
- **Prioridade e Speed.** No modo VGC a rodada (4 s) ordena a fila pela prioridade do golpe e depois pela Speed (Trick Room inverte). Em qualquer modo, prioridade positiva sai quase sem preparo e com GCD 0,6x; negativa prepara 0,1 s a mais por nível.
- **Efeitos secundários e status.** A chance é rolada a cada acerto (Serene Grace dobra, Sheer Force tira o efeito e dá 1,3x). Os status seguem o oficial em rodadas e dano de fim de turno (queimadura 1/16, veneno 1/8, Toxic n/16, sono 1-3 rodadas...). Imunidades de tipo valem.
- **Campo e dupla.** Clima e terrenos duram 5 rodadas, telas 5, Tailwind 4, Gravity 5; Protect, Endure, Quick/Wide Guard e Follow Me valem até o fim da rodada. Golpes de vários alvos (`all_opponents`, `all_other_pokemon`) acertam todos e dão 0,75x se pegam mais de um.

## Tipos de entrega (`kind`)

A entrega diz como o golpe sai do corpo do Pokémon e como acerta. Ela define o que 'acertar' significa em tempo real.

| kind | Nome neste guia | Em palavras | Erra por precisão? |
|---|---|---|---|
| `dash` | Investida | O Pokémon corre até o alvo e bate no contato (golpe de corpo, mordida, investida). Sai do chão: espera pousar. | sim |
| `arc` | Arco (contato) | Golpe de contato em cone curto na frente do usuário (garra, soco, rabada). Acerta quem estiver no cone. | sim |
| `multi_arc` | Arco em sequência | Vários golpes de contato em sequência rápida no mesmo cone (Double Kick, Fury Swipes). | sim |
| `whip` | Chicote | Chicote: a ponta varre uma linha até o alcance e acerta o primeiro que tocar (Vine Whip). | sim |
| `projectile` | Projétil | Projétil que voa em linha reta (bola, folha, agulha, jato de água); dá para desviar. Pode sair em leque ou em arco. | sim |
| `homing` | Teleguiado | Projétil teleguiado que faz curva atrás do alvo (Swift, Aura Sphere); a curva fraca dos de dreno (Absorb) ainda deixa desviar. | não |
| `stream` | Jato | Jato ou sopro em cone mantido por uma fração de segundo (Flamethrower, Gust); o usuário fica parado e trava no alvo. | não |
| `beam` | Raio | Raio em linha reta com aviso no chão antes de disparar (Hyper Beam, Ice Beam); o usuário fica parado e vulnerável. | sim |
| `aoe_self` | Onda ao redor | Onda em volta do usuário, com aviso no chão (Earthquake, Surf, Explosion); quem está dentro do raio apanha, dá para pular ou sair. | não |
| `aoe_target` | Área no alvo | Marca uma área no chão sobre o alvo e bate depois do aviso (Thunder, Rock Slide, Psychic); quem sai da marca escapa. | sim |
| `zone` | Zona no chão | Área que fica no chão por alguns segundos e bate a cada pulso em quem estiver dentro (Fire Spin, Sand Tomb). | sim |
| `self_buff` | Efeito próprio | Sem alvo: o efeito cai no próprio usuário ou no campo (Swords Dance, Protect, Rain Dance). Nunca erra. | não |
| `debuff_aoe` | Efeito ao redor | Efeito de status em quem estiver até um raio do usuário (Growl, Tail Whip); sem multi_target só o mais perto é afetado. Nunca erra. | não |
| `clones` | Cópias | Cria cópias ilusórias em volta do usuário que absorvem golpes (Double Team). | não |

## Multi-hit: um acerto por alvo, exceto o multi-hit oficial

Regra do jogo: **um uso acerta cada alvo uma vez**. Jatos, nuvens, folhas em leque e socos em sequência desenham vários golpes, mas só o primeiro que alcança cada alvo dá dano e efeito (`BattleMoves.hits_of`, `_spend_hit`). Um golpe de alvo único acerta um alvo só por uso (o primeiro alcançado), mesmo que o cone pegue os dois.

A exceção são os golpes que no oficial batem várias vezes (`hits_range` nos dados). Double Kick e Twineedle fazem 2 acertos; Fury Swipes, Fury Attack, Double Slap, Pin Missile, Bullet Seed, Icicle Spear, Rock Blast e Scale Shot sorteiam de 2 a 5 com 35/35/15/15% (Skill Link sempre dá o máximo). Cada acerto usa o poder oficial inteiro e todos caem no mesmo alvo. Beat Up dá um acerto por Pokémon saudável do time. Nos golpes de projétil o sorteio vira o número de projéteis.

## Custo de energia e cooldown (modo de energia)

| Regra | Valor |
|---|---|
| Custo de golpe de dano | `12 + 0,25 x poder`, teto 50 (arredonda) |
| Custo de status | 28 |
| Poder variável / dano fixo | conta como poder 70 (custo 30) |
| Multi-hit | poder x acertos (fixo) ou x3,1 (2-5) |
| Prioridade positiva | custo x0,6 e cooldown x1,8 |
| Barra | máximo 100, enche 5/s (Speed 0,85x-1,2x; descansando longe do inimigo 1,8x), começa em 40% |

## Convenções do texto

- **Poder** é o oficial (`bp`); o jogo usa o mesmo número em cada acerto. 'variável' = a mecânica calcula o poder na hora (Adaptação explica).
- **Precisão** é a oficial; 'nunca erra' = o golpe não tem precisão nos dados.
- **PP oficial** é o `uses` dos dados (PP de série principal).
- **Alcance, raio, ângulo, preparo (windup)** são metros e segundos do jogo; a Adaptação traduz o que cada um significa na entrega.
- 'Rodada' = turno do oficial (4 s no modo VGC); efeitos que duram 'N rodadas' contam no fim de turno.

## Golpes por tipo

[Normal (150)](#tipo-normal) · [Fogo (36)](#tipo-fire) · [Água (36)](#tipo-water) · [Elétrico (31)](#tipo-electric) · [Planta (39)](#tipo-grass) · [Gelo (21)](#tipo-ice) · [Lutador (37)](#tipo-fighting) · [Veneno (26)](#tipo-poison) · [Terra (21)](#tipo-ground) · [Voador (23)](#tipo-flying) · [Psíquico (56)](#tipo-psychic) · [Inseto (24)](#tipo-bug) · [Pedra (16)](#tipo-rock) · [Fantasma (17)](#tipo-ghost) · [Dragão (21)](#tipo-dragon) · [Sombrio (32)](#tipo-dark) · [Aço (20)](#tipo-steel) · [Fada (16)](#tipo-fairy)

<a id="tipo-normal"></a>

## Normal (150)

### Acupressure

`acupressure` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Sorteia um atributo (Ataque, Defesa, At. Esp., Def. Esp., Speed ou Precisão) e o sobe +2.

### After You

`after_you` · Normal · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - O parceiro age já: zera o GCD dele e o cooldown do golpe mais pronto. Sem parceiro, falha.

### Attract

`attract` · Normal · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 10 m/s; dá para desviar. [alcance 9 m, 10 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Apaixona o alvo de gênero oposto: metade das vezes o golpe dele não sai. Sem gênero ou mesmo gênero, falha.

### Baton Pass

`baton_pass` · Normal · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 25 espécie(s) do jogo
- **Adaptação:**
  - O usuário sai e o próximo do banco entra herdando os estágios de atributo e o crítico. Sem reserva, falha.

### Belly Drum

`belly_drum` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Gasta metade do HP e leva o Ataque ao máximo (+12 estágios, limitado a +6). Falha com HP <= 50%.

### Bind

`bind` · Normal · Físico · poder 15 · precisão 85% · PP oficial 20

- **Entrega:** `stream` (Jato). Jato em cone: 1,6 m de alcance, 45° de abertura, durante 1,5 s (um pulso a cada 0,3 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 1,6 m, 45°, 1,5 s]
- **Energia:** custo 16 · cooldown 6,9 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,4 s (parado dentro da área).
  - Precisão oficial 85%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Block

`block` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Se acertar, o alvo não pode fugir nem trocar de Pokémon (Fantasma é imune).

### Body Slam

`body_slam` · Normal · Físico · poder 85 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,4 s no ar, 1,5 m de altura) e cai em cima do alvo (alcance 3,2 m). Só sai no chão (no ar espera pousar). [alcance 3,2 m, 12 m/s]
- **Energia:** custo 33 · cooldown 4,9 s
- **Aprendem:** 107 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Boomburst

`boomburst` · Normal · Especial · poder 140 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 5 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 5 m, preparo 0,5 s]
- **Energia:** custo 47 · cooldown 14,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Estrondo em volta do usuário (onda de 5 m) que acerta todo mundo, inclusive o parceiro. Golpe de som: atravessa o Substitute e a Garganta ferida o impede.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Conversion

`conversion` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - O usuário vira do tipo do primeiro golpe que tem.

### Conversion 2

`conversion_2` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - O usuário ganha um tipo que resiste ao último golpe que recebeu.

### Copycat

`copycat` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Usa o último golpe usado na luta por qualquer um (fora da lista proibida de Metronome/Copycat/Mimic).

### Covet

`covet` · Normal · Físico · poder 60 · precisão 100% · PP oficial 25

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3,5 m, 14 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3,5 m, 14 m/s]
- **Energia:** custo 27 · cooldown 2,5 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, rouba o item do treinador do alvo (só se o usuário estiver sem item).

### Crush Claw

`crush_claw` · Normal · Físico · poder 75 · precisão 95% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 100°. [alcance 2 m, 100°]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 50% de chance: baixa Defesa do alvo em 1 estágio.

### Cut

`cut` · Normal · Físico · poder 50 · precisão 95% · PP oficial 30

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 25 · cooldown 2,1 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Defense Curl

`defense_curl` · Normal · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Defesa +1 e marca o usuário como enrolado (o Rollout seguinte dobra de poder).

### Disable

`disable` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 8 m a 12 m/s; dá para desviar. [alcance 8 m, 12 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Trava o último golpe usado pelo alvo por 4 rodadas.

### Double Hit

`double_hit` · Normal · Físico · poder 35 x 2 · precisão 90% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 2 golpes no cone (2 m, 70°), um a cada 0,2 s. [alcance 2 m, 70°]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 35), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (35).

### Double Slap

`double_slap` · Normal · Físico · poder 15 x 2-5 · precisão 85% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (1,8 m, 60°), um a cada 0,1 s. [alcance 1,8 m, 60°]
- **Energia:** custo 24 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (15); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Double Team

`double_team` · Normal · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `clones` (Cópias). Cópias: cria 2 ilusões em volta do usuário. Nunca erra. [5 s]
- **Energia:** custo 28 · cooldown 50 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Cria 2 cópias ilusórias por 5 s; o usuário esquiva de golpes com 40% de chance e as cópias absorvem golpes.

### Double-Edge

`double_edge` · Normal · Físico · poder 120 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 18 m/s]
- **Energia:** custo 42 · cooldown 6,8 s
- **Aprendem:** 72 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Echoed Voice

`echoed_voice` · Normal · Especial · poder 40 · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,5 s]
- **Energia:** custo 22 · cooldown 5,4 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x(1 + usos seguidos do lado), até x5 (limite 200): cada uso dentro da janela solta mais forte que o anterior.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Encore

`encore` · Normal · Status · poder — · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 8 m a 12 m/s; dá para desviar. [alcance 8 m, 12 m/s]
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 36 espécie(s) do jogo
- **Adaptação:**
  - O alvo só pode repetir o último golpe por 3 rodadas (os outros ficam travados).

### Endeavor

`endeavor` · Normal · Físico · poder variável · precisão 100% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 30 · cooldown 12,5 s
- **Aprendem:** 40 espécie(s) do jogo
- **Adaptação:**
  - Reduz o HP do alvo até o HP do usuário (falha se o alvo já tem HP igual ou menor).

### Endure

`endure` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +4
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Até o fim da rodada, o usuário aguenta qualquer golpe com 1 HP.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Entrainment

`entrainment` · Normal · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - A habilidade do alvo vira a do usuário.

### Explosion

`explosion` · Normal · Físico · poder 250 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,5 s]
- **Energia:** custo 50 · cooldown 44,7 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 250), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O usuário desmaia depois da explosão (0,3 s depois do impacto).
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Extreme Speed

`extreme_speed` · Normal · Físico · poder 80 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 9 m, 26 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 9 m, preparo 0 s, 26 m/s]
- **Energia:** custo 19 · cooldown 25,4 s · prioridade +2
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Facade

`facade` · Normal · Físico · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 16 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o usuário está com queimadura, veneno, Toxic ou paralisia; a queimadura não corta o dano.

### Fake Out

`fake_out` · Normal · Físico · poder 40 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, preparo 0,03 s, 18 m/s]
- **Energia:** custo 13 · cooldown 11,3 s · prioridade +3
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só sai logo depois de entrar em campo (até 1,5 s); acerta primeiro (prioridade +3) e faz o alvo hesitar.
  - Sempre causa Hesitar no alvo (depois do dano). Hesitar: o alvo fica parado 0,5 s.
  - Prioridade +3: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### False Swipe

`false_swipe` · Normal · Físico · poder 40 · precisão 100% · PP oficial 40

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 22 · cooldown 1,6 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Nunca nocauteia: deixa o alvo com 1 HP.

### Feint

`feint` · Normal · Físico · poder 30 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6 m, 15 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6 m, preparo 0,05 s, 15 m/s]
- **Energia:** custo 12 · cooldown 11,5 s · prioridade +2
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Quebra o Protect/Quick Guard do alvo (a proteção cai) e bate normalmente.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Flail

`flail` · Normal · Físico · poder variável · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,8 m à frente, num arco de 90°. [alcance 1,8 m, 90°]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 20 a 200 pela tabela oficial do Flail/Reversal: quanto menos HP o usuário tem, mais forte.

### Flash

`flash` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Precisão do adversário mais perto cai em 1 estágio, alcance 6 m.

### Focus Energy

`focus_energy` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 27 espécie(s) do jogo
- **Adaptação:**
  - Chance de crítico do usuário +2 níveis (limite 4): o crítico passa de 1/24 para 1/2.

### Follow Me

`follow_me` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 16,9 s · prioridade +2
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Até o fim da rodada, os golpes de alvo único dos adversários passam a mirar o usuário.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Fury Attack

`fury_attack` · Normal · Físico · poder 15 x 2-5 · precisão 85% · PP oficial 20

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (1,8 m, 50°), um a cada 0,2 s. [alcance 1,8 m, 50°]
- **Energia:** custo 24 · cooldown 3,1 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (15); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Fury Swipes

`fury_swipes` · Normal · Físico · poder 18 x 2-5 · precisão 80% · PP oficial 15

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (1,9 m, 100°), um a cada 0,2 s. [alcance 1,9 m, 100°]
- **Energia:** custo 26 · cooldown 4,2 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 18), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (18); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Giga Impact

`giga_impact` · Normal · Físico · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 19 m/s]
- **Energia:** custo 50 · cooldown 25 s
- **Aprendem:** 80 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,7 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Glare

`glare` · Normal · Status · poder — · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 20 m/s; dá para desviar. [alcance 9 m, 20 m/s]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Causa Paralisia no alvo se acertar. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Growl

`growl` · Normal · Status · poder — · precisão 100% · PP oficial 40

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário. Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 34 espécie(s) do jogo
- **Adaptação:**
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Ataque de todos os adversários cai em 1 estágio, alcance 6 m.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Growth

`growth` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, At. Esp. +1.

### Guillotine

`guillotine` · Normal · Físico · poder variável · precisão 30% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 70°. [alcance 2 m, 70°, preparo 0,4 s]
- **Energia:** custo 30 · cooldown 13,5 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Nocaute em um golpe: tira todo o HP do alvo. A precisão sobe 1 ponto por nível do usuário acima do alvo; não afeta alvo de nível maior nem Sturdy.

### Harden

`harden` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Defesa do usuário sobe em 1 estágio (multiplicador (2+n)/2, limite de -6 a +6).

### Headbutt

`headbutt` · Normal · Físico · poder 70 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 15 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, 15 m/s]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Heal Bell

`heal_bell` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura o status principal de todo o time do usuário (os de campo e os do banco).

### Helping Hand

`helping_hand` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 16,9 s · prioridade +5
- **Aprendem:** 88 espécie(s) do jogo
- **Adaptação:**
  - Se o parceiro soltar um golpe de dano em até 4 s, ele sai com 1,5x por 2,5 s. Sem parceiro, falha.
  - Prioridade +5: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Hidden Power

`hidden_power` · Normal · Especial · poder 60 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 27 · cooldown 4,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O tipo vem dos IVs do Pokémon (a fórmula oficial: último bit de cada IV vira 1 de 16 tipos). O poder é 60 fixo.

### Horn Attack

`horn_attack` · Normal · Físico · poder 65 · precisão 100% · PP oficial 25

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 2,5 m, 14 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 2,5 m, 14 m/s]
- **Energia:** custo 28 · cooldown 2,5 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Horn Drill

`horn_drill` · Normal · Físico · poder variável · precisão 30% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3 m, 14 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3 m, 14 m/s]
- **Energia:** custo 30 · cooldown 12,5 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Nocaute em um golpe: tira todo o HP do alvo. A precisão sobe 1 ponto por nível do usuário acima do alvo; não afeta alvo de nível maior nem Sturdy.

### Howl

`howl` · Normal · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Ataque +1 do usuário e do parceiro.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.

### Hyper Beam

`hyper_beam` · Normal · Especial · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 16 m de alcance, 0,9 m de largura; avisa no chão por 0,7 s e dispara; o usuário fica parado 1,2 s depois. [alcance 16 m, largura 0,9 m, preparo 0,7 s]
- **Energia:** custo 50 · cooldown 28,5 s
- **Aprendem:** 79 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.

### Hyper Fang

`hyper_fang` · Normal · Físico · poder 80 · precisão 90% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,8 m à frente, num arco de 80°. [alcance 1,8 m, 80°]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Hyper Voice

`hyper_voice` · Normal · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 80° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 80°, 0,6 s]
- **Energia:** custo 35 · cooldown 9,7 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Judgment

`judgment` · Normal · Especial · poder 100 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 10 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 10 m, raio 2 m, preparo 0,7 s]
- **Energia:** custo 37 · cooldown 11 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Pilares de luz no alvo. O tipo é o primeiro tipo do usuário (a placa do oficial não existe aqui).

### Laser Focus

`laser_focus` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - O próximo golpe do usuário (neste turno e no seguinte) é crítico garantido.

### Last Resort

`last_resort` · Normal · Físico · poder 140 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 18 m/s]
- **Energia:** custo 47 · cooldown 23,4 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só sai depois de o usuário já ter usado todos os outros golpes que conhece.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,4 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Leer

`leer` · Normal · Status · poder — · precisão 100% · PP oficial 30

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário. Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 34 espécie(s) do jogo
- **Adaptação:**
  - Defesa de todos os adversários cai em 1 estágio, alcance 6 m.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Lock-On

`lock_on` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - O próximo golpe do usuário (neste turno e no seguinte) não erra.

### Lovely Kiss

`lovely_kiss` · Normal · Status · poder — · precisão 75% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 10 m/s; dá para desviar. [alcance 9 m, 10 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Causa Sono no alvo se acertar. Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.

### Mean Look

`mean_look` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Se acertar, o alvo não pode fugir nem trocar de Pokémon (Fantasma é imune).

### Mega Kick

`mega_kick` · Normal · Físico · poder 120 · precisão 75% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 70°. [alcance 2 m, 70°, preparo 0,25 s]
- **Energia:** custo 42 · cooldown 21,3 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Mega Punch

`mega_punch` · Normal · Físico · poder 80 · precisão 85% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Metronome

`metronome` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 37 espécie(s) do jogo
- **Adaptação:**
  - Usa um golpe sorteado do jogo (fora da lista proibida: Protect, Counter, Metronome, Copycat...).

### Milk Drink

`milk_drink` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura 50% do HP máximo do usuário.
  - Cura metade do HP máximo do usuário.

### Mimic

`mimic` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Troca o próprio Mimic pelo último golpe usado pelo adversário (fora da lista proibida).

### Mind Reader

`mind_reader` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O próximo golpe do usuário (neste turno e no seguinte) não erra.
  - Projétil que trava a mira: o próximo golpe do usuário nunca erra (como Lock-On).

### Minimize

`minimize` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra. [5 s]
- **Energia:** custo 28 · cooldown 56,3 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Evasão: por 5 s o usuário esquiva de golpes mirados nele com 40% de chance.

### Morning Sun

`morning_sun` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura o usuário em 1/2 do HP máximo; 2/3 sob sol forte, 1/4 sob qualquer outro clima (chuva, areia, neve).

### Nature Power

`nature_power` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Vira outro golpe conforme o terreno em que o usuário está (Earth Power, Ice Beam, Hydro Pump...).

### Noble Roar

`noble_roar` · Normal · Status · poder — · precisão 100% · PP oficial 30

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Rugido que derruba o Ataque e o At. Esp. do alvo mais perto em 1. Golpe de som.

### Odor Sleuth

`odor_sleuth` · Normal · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O alvo perde a evasão e deixa de ser imune: Fantasma passa a levar Normal e Lutador até sair de campo.

### Pain Split

`pain_split` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Soma o HP do usuário e do alvo e divide igual entre os dois.

### Pay Day

`pay_day` · Normal · Físico · poder 40 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 15 m/s; dá para desviar. Sai uma leva de 4 em leque de 30°. [alcance 10 m, 15 m/s]
- **Energia:** custo 22 · cooldown 3,1 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 4): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).

### Perish Song

`perish_song` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Quem estiver no raio (7 m) e ouvir desmaia em 3 rodadas, se não sair do campo.

### Play Nice

`play_nice` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Ignora Protect e Substitute do alvo.

### Pound

`pound` · Normal · Físico · poder 40 · precisão 100% · PP oficial 35

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 22 · cooldown 1,8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Present

`present` · Normal · Físico · poder variável · precisão 90% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,8 m): até 11 m a 11 m/s; dá para desviar. [alcance 11 m, 11 m/s]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder sorteado 40/80/120; 20% das vezes é um presente que cura o alvo em 1/4 do HP.

### Protect

`protect` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +4
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Bloqueia quase tudo até o fim da rodada. Usado em rodadas seguidas: chance 1, 1/3, 1/9... (zera quando uma rodada passa sem usar). Feint quebra.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Psych Up

`psych_up` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Copia os estágios de atributo e o crítico do adversário.

### Quick Attack

`quick_attack` · Normal · Físico · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8,5 m, 22 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8,5 m, preparo 0,05 s, 22 m/s]
- **Energia:** custo 13 · cooldown 4 s · prioridade +1
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Rage

`rage` · Normal · Físico · poder 20 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,8 m à frente, num arco de 90°. [alcance 1,8 m, 90°]
- **Energia:** custo 17 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só dano simples: o aumento de Ataque ao apanhar do oficial não foi implementado.

### Raging Bull

`raging_bull` · Normal · Físico · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 17 m/s]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se o golpe for eficaz, quebra o Reflect e o Light Screen do lado do alvo antes de acertar.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Rapid Spin

`rapid_spin` · Normal · Físico · poder 50 · precisão 100% · PP oficial 40

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 1,8 m, aviso de 0,2 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 1,8 m, preparo 0,2 s]
- **Energia:** custo 25 · cooldown 2,1 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de acertar, tira do usuário a Semente, o Wrap/Bind e as armadilhas (Spikes, Stealth Rock, Toxic Spikes) armadas pelo adversário.
  - Sempre sobe Speed do usuário em 1 estágio.
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Recover

`recover` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Cura 50% do HP máximo do usuário.

### Recycle

`recycle` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Devolve o item do treinador que já foi usado.

### Reflect Type

`reflect_type` · Normal · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - O usuário copia os tipos do alvo.

### Refresh

`refresh` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura queimadura, veneno ou paralisia do usuário.

### Relic Song

`relic_song` · Normal · Especial · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 6 m de alcance, 100° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 6 m, 100°, 0,5 s]
- **Energia:** custo 31 · cooldown 8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Cone de som que acerta todos os adversários; 10% de dormir. Golpe de som.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 10% de chance de causar Sono no alvo. Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Retaliate

`retaliate` · Normal · Físico · poder 70 · precisão 100% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 30 · cooldown 12,5 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se um aliado desmaiou nos últimos 8 s.

### Revelation Dance

`revelation_dance` · Normal · Especial · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,2 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,2 m, preparo 0,5 s]
- **Energia:** custo 35 · cooldown 6,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dança que solta uma onda ao redor; o tipo é o primeiro tipo do usuário.
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Revival Blessing

`revival_blessing` · Normal · Status · poder — · precisão nunca erra · PP oficial 1

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 187,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Reanima um Pokémon desmaiado do banco do usuário com metade do HP. Falha se ninguém desmaiou.

### Roar

`roar` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 5 m do usuário (só o mais perto). Nunca erra. [raio 5 m]
- **Energia:** custo 28 · cooldown 9,4 s · prioridade -6
- **Aprendem:** 26 espécie(s) do jogo
- **Adaptação:**
  - No oficial força a troca; aqui o alvo é arremessado 5 m para longe.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Prioridade -6: na fila da rodada sai depois dos normais; prepara 0,6 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Round

`round` · Normal · Especial · poder 60 · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 50° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 50°, 0,5 s]
- **Energia:** custo 27 · cooldown 5,4 s
- **Aprendem:** 40 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o parceiro usou Round há pouco (janela de 2 s).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Safeguard

`safeguard` · Normal · Status · poder — · precisão nunca erra · PP oficial 25

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Safeguard por 5 rodadas: o lado do usuário não recebe status nem confusão de golpes adversários.

### Scary Face

`scary_face` · Normal · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 48 espécie(s) do jogo
- **Adaptação:**
  - Speed do adversário mais perto cai em 2 estágios, alcance 6 m.

### Scratch

`scratch` · Normal · Físico · poder 40 · precisão 100% · PP oficial 35

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 100°. [alcance 1,9 m, 100°]
- **Energia:** custo 22 · cooldown 1,8 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Screech

`screech` · Normal · Status · poder — · precisão 85% · PP oficial 40

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 25 espécie(s) do jogo
- **Adaptação:**
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Defesa do adversário mais perto cai em 2 estágios, alcance 6 m.

### Self-Destruct

`self_destruct` · Normal · Físico · poder 200 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4 m, preparo 0,4 s]
- **Energia:** custo 50 · cooldown 35,4 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 200), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O usuário desmaia depois da explosão (0,3 s depois do impacto).
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Shed Tail

`shed_tail` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O usuário perde metade do HP, cria um substituto de 1/4 do HP máximo e troca; quem entra herda o substituto.

### Shell Smash

`shell_smash` · Normal · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +2, At. Esp. +2, Speed +2, Defesa -1, Def. Esp. -1.

### Simple Beam

`simple_beam` · Normal · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - A habilidade do alvo vira Simple (falha se já for).

### Sing

`sing` · Normal · Status · poder — · precisão 55% · PP oficial 15

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 8 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 8 m, raio 1,8 m, preparo 0,6 s]
- **Energia:** custo 28 · cooldown 17 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Causa Sono no alvo se acertar (75% de chance). Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.

### Sketch

`sketch` · Normal · Status · poder — · precisão nunca erra · PP oficial 1

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 187,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Copia de verdade o último golpe do alvo: o Sketch some da lista do usuário e o golpe novo fica no lugar, para o resto da vida do Pokémon.

### Skull Bash

`skull_bash` · Normal · Físico · poder 130 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4,5 m, 14 m/s) e bate no contato. [alcance 4,5 m, preparo 0,8 s, 14 m/s]
- **Energia:** custo 45 · cooldown 14,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Ao começar a usar, muda os atributos do usuário: Defesa +1 (o turno de carga do oficial).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,1 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Slack Off

`slack_off` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Cura 50% do HP máximo do usuário.

### Slam

`slam` · Normal · Físico · poder 80 · precisão 75% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3,5 m, 12 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3,5 m, 12 m/s]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Slash

`slash` · Normal · Físico · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Sleep Talk

`sleep_talk` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Só dormindo: usa um dos outros golpes do usuário (sorteado) sem acordar.

### Smokescreen

`smokescreen` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 5 m do usuário (só o mais perto). Nunca erra. [raio 5 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Precisão do adversário mais perto cai em 1 estágio, alcance 5 m.

### Snore

`snore` · Normal · Especial · poder 50 · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,5 s]
- **Energia:** custo 25 · cooldown 5,4 s
- **Aprendem:** 39 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só sai dormindo (a rodada sai mesmo com o usuário em sono).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Soft-Boiled

`soft_boiled` · Normal · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Cura 50% do HP máximo do usuário.

### Sonic Boom

`sonic_boom` · Normal · Especial · poder variável · precisão 90% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 18 m/s; dá para desviar. [alcance 9 m, 18 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo de 20 HP (não usa a fórmula; imunidade de tipo ainda vale). Só o ritmo x0,75 do jogo vai por cima.

### Spit Up

`spit_up` · Normal · Especial · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 14 m/s; dá para desviar. [alcance 10 m, 14 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 100 por Stockpile guardado (100/200/300); gasta os Stockpiles e devolve a Defesa e a Def. Esp. Falha sem Stockpile.

### Splash

`splash` · Normal · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Não faz nada (como o oficial).

### Stockpile

`stockpile` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Guarda uma carga (até 3): Defesa +1 e Def. Esp. +1 por carga, usadas por Spit Up e Swallow.

### Stomp

`stomp` · Normal · Físico · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,3 s no ar, 1 m de altura) e cai em cima do alvo (alcance 3,2 m). Só sai no chão (no ar espera pousar). [alcance 3,2 m, 12 m/s]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Strength

`strength` · Normal · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 5 m, 14 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 5 m, 14 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Stuff Cheeks

`stuff_cheeks` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O usuário come a frutinha que segura (ou uma a até 2 m dele no chão) e ganha 2 de Defesa; falha sem frutinha.

### Substitute

`substitute` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Gasta 1/4 do HP e cria um boneco com esse HP que leva os golpes e status no lugar do usuário (som atravessa). Falha com HP baixo ou se já existe.

### Super Fang

`super_fang` · Normal · Físico · poder variável · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo = metade do HP atual do alvo (mínimo 1). Só o ritmo x0,75 vai por cima.

### Supersonic

`supersonic` · Normal · Status · poder — · precisão 55% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 8 m a 10 m/s; dá para desviar. [alcance 8 m, 10 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Causa Confusão no alvo se acertar. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Swagger

`swagger` · Normal · Status · poder — · precisão 85% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 11 m/s; dá para desviar. [alcance 9 m, 11 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Além da confusão, sobe o Ataque do alvo (+2 estágios, como o Swagger).
  - Causa Confusão no alvo se acertar. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Swallow

`swallow` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Gasta os Stockpiles e cura 1/4, 1/2 ou todo o HP (1, 2 ou 3 cargas). Falha sem Stockpile.

### Sweet Scent

`sweet_scent` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - No jogo sobe a Precisão do usuário em +1 (equivale a baixar a evasão dos adversários).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Swift

`swift` · Normal · Especial · poder 60 · precisão nunca erra · PP oficial 20

- **Entrega:** `homing` (Teleguiado). Projétil teleguiado: faz curva atrás do alvo (curva 5), até 16 m a 11 m/s. Não erra. Solta 5, um a cada 0,08 s. [alcance 16 m, 11 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 80 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 5): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Swords Dance

`swords_dance` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 44 espécie(s) do jogo
- **Adaptação:**
  - Ataque do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Tackle

`tackle` · Normal · Físico · poder 40 · precisão 100% · PP oficial 35

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3 m, 11 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3 m, 11 m/s]
- **Energia:** custo 22 · cooldown 1,8 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Tail Whip

`tail_whip` · Normal · Status · poder — · precisão 100% · PP oficial 30

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário. Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 29 espécie(s) do jogo
- **Adaptação:**
  - Defesa de todos os adversários cai em 1 estágio, alcance 6 m.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Take Down

`take_down` · Normal · Físico · poder 90 · precisão 85% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 17 m/s]
- **Energia:** custo 35 · cooldown 3,9 s
- **Aprendem:** 91 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 25% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Tearful Look

`tearful_look` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Derruba o Ataque e o At. Esp. do alvo mais perto em 1.

### Teatime

`teatime` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Todos em campo comem a frutinha que seguram (Oran e Sitrus curam, Pecha e Persim tiram o status).

### Techno Blast

`techno_blast` · Normal · Especial · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,9 m de largura; avisa no chão por 0,6 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 0,9 m, preparo 0,6 s]
- **Energia:** custo 42 · cooldown 22,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de 120 de poder; o tipo vem do Drive que o usuário segura (Douse, Shock, Burn, Chill) e é Normal sem ele.

### Teeter Dance

`teeter_dance` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 4,5 m do usuário. Nunca erra. [raio 4,5 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Confunde todos ao redor (inclusive o parceiro, como no oficial, quando o alvo é 'todos').
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).

### Tera Blast

`tera_blast` · Normal · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 98 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Tera Starstorm

`tera_starstorm` · Normal · Especial · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 5,5 m, aviso de 0,8 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 5,5 m, preparo 0,8 s]
- **Energia:** custo 42 · cooldown 23,6 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Chuva de estrelas em volta do usuário que acerta todos os adversários. Sem forma Estelar, é Normal.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Terrain Pulse

`terrain_pulse` · Normal · Especial · poder 50 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 25 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 e tipo do terreno de campo ativo.

### Thrash

`thrash` · Normal · Físico · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 2,2 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 2,2 m, preparo 0,3 s]
- **Energia:** custo 42 · cooldown 11,4 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois que o golpe termina, o usuário fica confuso de cansaço (como o oficial, que repete 2-3 turnos e confunde ao fim).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Tickle

`tickle` · Normal · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Ataque e Defesa dos alvos -1 cada.

### Tidy Up

`tidy_up` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Sobe Ataque e Velocidade em 1 e limpa o campo: espinhos, pedras, teias de cenário e todos os substitutos.

### Transform

`transform` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra. [preparo 0,4 s]
- **Energia:** custo 28 · cooldown 21,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Vira cópia do alvo: tipos, stats (menos HP), golpes, habilidade e aparência (BattleTransform).

### Tri Attack

`tri_attack` · Normal · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 22 m/s; dá para desviar. [alcance 12 m, 22 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar, sorteado igual, Queimadura, Paralisia ou Congelamento (Tri Attack).

### Uproar

`uproar` · Normal · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 80° de abertura, durante 1 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 80°, 1 s]
- **Energia:** custo 35 · cooldown 10,9 s
- **Aprendem:** 32 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Barulho por 3 rodadas: acorda todos e impede qualquer um de dormir.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Vise Grip

`vice_grip` · Normal · Físico · poder 55 · precisão 100% · PP oficial 30

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,8 m à frente, num arco de 70°. [alcance 1,8 m, 70°]
- **Energia:** custo 26 · cooldown 2,1 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Weather Ball

`weather_ball` · Normal · Especial · poder 50 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 25 · cooldown 6,3 s
- **Aprendem:** 39 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Com clima ativo o tipo muda (sol: Fogo, chuva: Água, areia: Pedra, neve: Gelo) e o poder dobra.

### Whirlwind

`whirlwind` · Normal · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 5 m do usuário (só o mais perto). Nunca erra. [raio 5 m]
- **Energia:** custo 28 · cooldown 9,4 s · prioridade -6
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - No oficial força a troca; aqui o alvo é arremessado 5 m para longe.
  - Prioridade -6: na fila da rodada sai depois dos normais; prepara 0,6 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Wish

`wish` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Desejo: no fim da rodada seguinte cura 1/2 do HP máximo de quem desejou (ou de quem estiver no lugar dele).

### Work Up

`work_up` · Normal · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, At. Esp. +1.

### Wrap

`wrap` · Normal · Físico · poder 15 · precisão 90% · PP oficial 20

- **Entrega:** `stream` (Jato). Jato em cone: 1,6 m de alcance, 45° de abertura, durante 1,5 s (um pulso a cada 0,3 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 1,6 m, 45°, 1,5 s]
- **Energia:** custo 16 · cooldown 6,9 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,4 s (parado dentro da área).
  - Precisão oficial 90%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Yawn

`yawn` · Normal · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 8 m a 8 m/s; dá para desviar. [alcance 8 m, 8 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - O alvo fica sonolento e dorme no fim da rodada seguinte (se estiver sem status). Falha se já tem status ou sonolência.

<a id="tipo-fire"></a>

## Fogo (36)

### Armor Cannon

`armor_cannon` · Fogo · Especial · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 11 m/s; dá para desviar. [alcance 11 m, 11 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola grande de fogo (projétil lento e pesado); depois de sair, o usuário perde 1 de Defesa e 1 de Def. Esp.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Defesa -1, Def. Esp. -1.
  - Se acertar um alvo congelado, descongela.

### Blast Burn

`blast_burn` · Fogo · Especial · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2 m, preparo 0,8 s]
- **Energia:** custo 50 · cooldown 29 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.
  - Se acertar um alvo congelado, descongela.

### Blaze Kick

`blaze_kick` · Fogo · Físico · poder 85 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 70°. [alcance 2 m, 70°]
- **Energia:** custo 33 · cooldown 7,4 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Se acertar um alvo congelado, descongela.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Blue Flare

`blue_flare` · Fogo · Especial · poder 130 · precisão 85% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 10 m/s; dá para desviar. [alcance 11 m, 10 m/s]
- **Energia:** custo 45 · cooldown 21,9 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Chama azul grande e lenta (projétil); 20% de queimar.
  - 20% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Burn Up

`burn_up` · Fogo · Especial · poder 130 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 1,8 m, preparo 0,6 s]
- **Energia:** custo 45 · cooldown 24,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Coluna de fogo no alvo. Depois do acerto o usuário perde o tipo Fire (vira Normal). Só sai se o usuário ainda for Fire.
  - Se acertar um alvo congelado, descongela.

### Burning Jealousy

`burning_jealousy` · Fogo · Especial · poder 70 · precisão 100% · PP oficial 5

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 70° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 70°, 0,6 s]
- **Energia:** custo 30 · cooldown 14 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Além do dano, aplica queimadura só se o alvo subiu algum atributo na mesma rodada.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Ember

`ember` · Fogo · Especial · poder 40 · precisão 100% · PP oficial 25

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 14 m/s; dá para desviar. [alcance 12 m, 14 m/s]
- **Energia:** custo 22 · cooldown 2,5 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Eruption

`eruption` · Fogo · Especial · poder 150 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 5 m, aviso de 0,7 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 5 m, preparo 0,7 s]
- **Energia:** custo 50 · cooldown 28,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder proporcional ao HP atual do usuário (poder x HP atual / HP máximo, mínimo 1).
  - Onda de fogo em volta do usuário; o poder acompanha o HP (150 com HP cheio), igual ao Water Spout.
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Fiery Dance

`fiery_dance` · Fogo · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola de fogo que sai de uma dança; 50% de subir o At. Esp. do usuário.
  - 50% de chance: sobe At. Esp. do usuário em 1 estágio.
  - Se acertar um alvo congelado, descongela.

### Fire Blast

`fire_blast` · Fogo · Especial · poder 110 · precisão 85% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 13 m/s; dá para desviar. [alcance 12 m, 13 m/s]
- **Energia:** custo 40 · cooldown 18,8 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Fire Fang

`fire_fang` · Fogo · Físico · poder 65 · precisão 95% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 28 · cooldown 4,2 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - 10% de chance extra de o alvo hesitar (0,5 s parado).
  - Se acertar um alvo congelado, descongela.

### Fire Pledge

`fire_pledge` · Fogo · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 8 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 8 m, raio 1,5 m, preparo 0,7 s]
- **Energia:** custo 32 · cooldown 9 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se acertar um alvo congelado, descongela.

### Fire Punch

`fire_punch` · Fogo · Físico · poder 75 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 31 · cooldown 4,4 s
- **Aprendem:** 41 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Fire Spin

`fire_spin` · Fogo · Especial · poder 35 · precisão 85% · PP oficial 15

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 1,6 m de raio (alcance 8 m) que dura 2,5 s e bate a cada 0,5 s em quem estiver dentro. [alcance 8 m, raio 1,6 m, 2,5 s]
- **Energia:** custo 21 · cooldown 10,4 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 35), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,6 s (parado dentro da área).
  - Se acertar um alvo congelado, descongela.

### Flame Burst

`flame_burst` · Fogo · Especial · poder 70 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola de fogo que, ao acertar, solta faíscas: o adversário que estiver a até 2,2 m do alvo (dupla) perde 1/16 do HP.
  - Se acertar um alvo congelado, descongela.

### Flame Charge

`flame_charge` · Fogo · Físico · poder 50 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 25 · cooldown 3,1 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre sobe Speed do usuário em 1 estágio.
  - Se acertar um alvo congelado, descongela.

### Flame Wheel

`flame_wheel` · Fogo · Físico · poder 60 · precisão 100% · PP oficial 25

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6 m, 16 m/s]
- **Energia:** custo 27 · cooldown 2,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Flamethrower

`flamethrower` · Fogo · Especial · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 35° de abertura, durante 1 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 35°, 1 s]
- **Energia:** custo 35 · cooldown 8,3 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 8% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Flare Blitz

`flare_blitz` · Fogo · Físico · poder 120 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 18 m/s]
- **Energia:** custo 42 · cooldown 6,8 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Se acertar um alvo congelado, descongela.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Fusion Flare

`fusion_flare` · Fogo · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 11 m/s; dá para desviar. [alcance 11 m, 11 m/s]
- **Energia:** custo 37 · cooldown 17,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola de fogo gigante; dobra o poder se alguém usou Fusion Bolt nos últimos 4 s.
  - Se acertar um alvo congelado, descongela.

### Heat Crash

`heat_crash` · Fogo · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,5 s no ar, 2 m de altura) e cai em cima do alvo (alcance 3,2 m). Só sai no chão (no ar espera pousar). [alcance 3,2 m, 12 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 40 a 120 pela razão de peso usuário/alvo (>=2x: 60, >=3x: 80, >=4x: 100, >=5x: 120). Salta e cai em cima do alvo.
  - Se acertar um alvo congelado, descongela.

### Heat Wave

`heat_wave` · Fogo · Especial · poder 95 · precisão 90% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 70° de abertura, durante 0,8 s (um pulso a cada 0,2 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 70°, 0,8 s]
- **Energia:** custo 36 · cooldown 10,8 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 10% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 90%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Incinerate

`incinerate` · Fogo · Especial · poder 60 · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,6 s]
- **Energia:** custo 27 · cooldown 5,7 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Queima as frutinhas do chão perto do alvo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Inferno

`inferno` · Fogo · Especial · poder 100 · precisão 50% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 11 m/s; dá para desviar. [alcance 11 m, 11 m/s]
- **Energia:** custo 37 · cooldown 17,2 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre causa Queimadura no alvo (depois do dano). Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.

### Lava Plume

`lava_plume` · Fogo · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,5 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,5 m, preparo 0,4 s]
- **Energia:** custo 32 · cooldown 5,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Magma Storm

`magma_storm` · Fogo · Especial · poder 100 · precisão 75% · PP oficial 5

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 2 m de raio (alcance 8 m) que dura 2,5 s e bate a cada 0,5 s em quem estiver dentro. [alcance 8 m, raio 2 m, 2,5 s]
- **Energia:** custo 37 · cooldown 25,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Tempestade de magma numa zona de 2 m: prende o alvo por 4-5 rodadas (1/8 do HP por rodada) e impede a fuga.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,8 s (parado dentro da área).
  - Se acertar um alvo congelado, descongela.

### Mind Blown

`mind_blown` · Fogo · Especial · poder 150 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,5 s]
- **Energia:** custo 50 · cooldown 27,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Explosão em volta do usuário (acerta todos, até o parceiro). O usuário perde metade do HP máximo ao usar, acertando ou não (como o Steel Beam).
  - O usuário perde 50% do HP máximo ao atirar, acertando ou não.
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Mystical Fire

`mystical_fire` · Fogo · Especial · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa At. Esp. do alvo em 1 estágio.
  - Se acertar um alvo congelado, descongela.

### Overheat

`overheat` · Fogo · Especial · poder 130 · precisão 90% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 12 m de alcance, 1 m de largura; avisa no chão por 0,6 s e dispara; o usuário fica parado 0,7 s depois. [alcance 12 m, largura 1 m, preparo 0,55 s]
- **Energia:** custo 45 · cooldown 24,3 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -2.
  - Se acertar um alvo congelado, descongela.

### Raging Fury

`raging_fury` · Fogo · Físico · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 2,4 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 2,4 m, preparo 0,3 s]
- **Energia:** custo 42 · cooldown 11,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois que o golpe termina, o usuário fica confuso de cansaço (como o oficial, que repete 2-3 turnos e confunde ao fim).
  - Se acertar um alvo congelado, descongela.
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Searing Shot

`searing_shot` · Fogo · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4 m, preparo 0,4 s]
- **Energia:** custo 37 · cooldown 18,6 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Chamas em volta do usuário que acertam todos (até o parceiro); 30% de queimar.
  - 30% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Se acertar um alvo congelado, descongela.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Shell Trap

`shell_trap` · Fogo · Especial · poder 150 · precisão 100% · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 50 · cooldown 25 s · prioridade -3
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade -3 (prepara um pouco mais). Arma a armadilha por 1,5 s com o usuário parado: se levar um golpe físico nesse tempo, ela explode na hora em volta dele (onda de 3,8 m, poder 150, acerta todos os adversários); se ninguém o acertar fisicamente, o golpe falha.
  - Se acertar um alvo congelado, descongela.
  - Prioridade -3: na fila da rodada sai depois dos normais; prepara 0,3 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Sunny Day

`sunny_day` · Fogo · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 112 espécie(s) do jogo
- **Adaptação:**
  - Sol por 5 rodadas: Fogo 1,5x, Água 0,5x.

### Temper Flare

`temper_flare` · Fogo · Físico · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o golpe anterior do usuário falhou (errou, foi bloqueado ou sem efeito).
  - Se acertar um alvo congelado, descongela.

### Torch Song

`torch_song` · Fogo · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola de fogo cantada; sobe o At. Esp. do usuário em 1 (100%). Golpe de som.
  - Sempre sobe At. Esp. do usuário em 1 estágio.
  - Se acertar um alvo congelado, descongela.

### Will-O-Wisp

`will_o_wisp` · Fogo · Status · poder — · precisão 85% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 10 m/s; dá para desviar. [alcance 9 m, 10 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 19 espécie(s) do jogo
- **Adaptação:**
  - Causa Queimadura no alvo se acertar. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.

<a id="tipo-water"></a>

## Água (36)

### Aqua Jet

`aqua_jet` · Água · Físico · poder 40 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 20 m/s) e bate no contato. [alcance 8 m, preparo 0,05 s, 20 m/s]
- **Energia:** custo 13 · cooldown 5,9 s · prioridade +1
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Aqua Ring

`aqua_ring` · Água · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Anel de água: cura 1/16 do HP no fim de cada rodada até sair de campo (Aqua Ring).

### Aqua Tail

`aqua_tail` · Água · Físico · poder 90 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,4 m à frente, num arco de 110°. [alcance 2,4 m, 110°]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Brine

`brine` · Água · Especial · poder 65 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 28 · cooldown 6,3 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo está com menos da metade do HP.

### Bubble

`bubble` · Água · Especial · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 6 m a 15 m/s; dá para desviar. [alcance 6 m, 15 m/s]
- **Energia:** custo 22 · cooldown 2,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Bubble Beam

`bubble_beam` · Água · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 40° de abertura, durante 0,8 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 40°, 0,8 s]
- **Energia:** custo 28 · cooldown 5,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 10% de chance: baixa Speed do alvo em 1 estágio.
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Chilling Water

`chilling_water` · Água · Especial · poder 50 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. [alcance 11 m, 15 m/s]
- **Energia:** custo 25 · cooldown 3,1 s
- **Aprendem:** 35 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Ataque do alvo em 1 estágio.

### Crabhammer

`crabhammer` · Água · Físico · poder 100 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,1 m à frente, num arco de 90°. [alcance 2,1 m, 90°, preparo 0,3 s]
- **Energia:** custo 37 · cooldown 9,6 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Dive

`dive` · Água · Físico · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida por baixo: mergulha e anda por baixo do chão até 7 m, a 8 m/s, e sai sob o alvo. Só sai no chão (no ar espera pousar). [alcance 7 m, 8 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Mergulha (invulnerável), anda por baixo d'água até o alvo e sai sob ele. Só Surf e Whirlpool (dobro) o alcançam.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Flip Turn

`flip_turn` · Água · Físico · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 5 m, 17 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de bater, o usuário troca de lugar com o próximo Pokémon do banco (sai 0,35 s depois). Sem reserva, só bate.

### Hydro Cannon

`hydro_cannon` · Água · Especial · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 1 m de largura; avisa no chão por 0,7 s e dispara; o usuário fica parado 1 s depois. [alcance 14 m, largura 1 m, preparo 0,7 s]
- **Energia:** custo 50 · cooldown 28,5 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.

### Hydro Pump

`hydro_pump` · Água · Especial · poder 110 · precisão 80% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 0,9 m de largura; avisa no chão por 0,3 s e dispara; o usuário fica parado 0,6 s depois. [alcance 14 m, largura 0,9 m, preparo 0,35 s]
- **Energia:** custo 40 · cooldown 20,1 s
- **Aprendem:** 38 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Hydro Steam

`hydro_steam` · Água · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,6 m): até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Jato de água fervente em arco. Ao sol o poder triplica na conta (anula o 0,5x do sol sobre Água e fica 1,5x, como o oficial).

### Life Dew

`life_dew` · Água · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Cura 1/4 do HP máximo do usuário e do parceiro.

### Liquidation

`liquidation` · Água · Físico · poder 85 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 100°. [alcance 2,2 m, 100°]
- **Energia:** custo 33 · cooldown 7,4 s
- **Aprendem:** 26 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance: baixa Defesa do alvo em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Muddy Water

`muddy_water` · Água · Especial · poder 90 · precisão 85% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 80° de abertura, durante 0,7 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 80°, 0,7 s]
- **Energia:** custo 35 · cooldown 10 s
- **Aprendem:** 25 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 30% de chance: baixa Precisão do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 85%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Octazooka

`octazooka` · Água · Especial · poder 65 · precisão 85% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,4 m): até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 28 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Jato de tinta em arco; 50% de baixar a Precisão do alvo.
  - 50% de chance: baixa Precisão do alvo em 1 estágio.

### Origin Pulse

`origin_pulse` · Água · Especial · poder 110 · precisão 85% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 7 m de alcance, 120° de abertura, durante 0,8 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 7 m, 120°, 0,8 s]
- **Energia:** custo 40 · cooldown 12,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Onda larga de 120 graus que acerta todos os adversários no cone.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 85%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Rain Dance

`rain_dance` · Água · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 108 espécie(s) do jogo
- **Adaptação:**
  - Chuva por 5 rodadas: Água 1,5x, Fogo 0,5x; Thunder e Hurricane não erram.

### Razor Shell

`razor_shell` · Água · Físico · poder 75 · precisão 95% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 50% de chance: baixa Defesa do alvo em 1 estágio.

### Scald

`scald` · Água · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Descongela o alvo congelado, como os golpes de Fogo.
  - 30% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.

### Snipe Shot

`snipe_shot` · Água · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 15 m a 20 m/s; dá para desviar. [alcance 15 m, 20 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Projétil rápido com crítico mais provável que ignora o Cobrir do parceiro e o para-raios (Lightning Rod/Storm Drain).
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Soak

`soak` · Água · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Muda o tipo do alvo para Água.

### Sparkling Aria

`sparkling_aria` · Água · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,6 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,6 m, preparo 0,4 s]
- **Energia:** custo 35 · cooldown 9,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Cura a queimadura do alvo.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Steam Eruption

`steam_eruption` · Água · Especial · poder 110 · precisão 95% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 2 m, preparo 0,6 s]
- **Energia:** custo 40 · cooldown 21 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Coluna de vapor no alvo; 30% de queimar.
  - 30% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.

### Surf

`surf` · Água · Especial · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,35 s]
- **Energia:** custo 35 · cooldown 6,3 s
- **Aprendem:** 45 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Acerta quem está mergulhado (Dive) em dobro.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Water Gun

`water_gun` · Água · Especial · poder 40 · precisão 100% · PP oficial 25

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 16 m/s; dá para desviar. [alcance 12 m, 16 m/s]
- **Energia:** custo 22 · cooldown 2,5 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Water Pledge

`water_pledge` · Água · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 8 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 8 m, raio 1,5 m, preparo 0,7 s]
- **Energia:** custo 32 · cooldown 9 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Water Pulse

`water_pulse` · Água · Especial · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. [alcance 11 m, 15 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 34 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Water Shuriken

`water_shuriken` · Água · Especial · poder 15 x 2-5 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 20 m/s; dá para desviar. Sai uma leva em leque de 22° (quantidade sorteada, ver multi-hit). [alcance 11 m, 20 m/s]
- **Energia:** custo 14 · cooldown 5,6 s · prioridade +1
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - De 2 a 5 estrelas de água rápidas (35/35/15/15%), prioridade +1.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (15); Skill Link sempre dá 5. O visual solta os projéteis sorteados, todos no mesmo alvo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Water Sport

`water_sport` · Água · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Def. Esp. do usuário sobe em 1 estágio (multiplicador (2+n)/2, limite de -6 a +6).

### Water Spout

`water_spout` · Água · Especial · poder 150 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,45 s]
- **Energia:** custo 50 · cooldown 27,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder proporcional ao HP atual do usuário (poder x HP atual / HP máximo, mínimo 1).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Waterfall

`waterfall` · Água · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 29 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Wave Crash

`wave_crash` · Água · Físico · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 19 m/s]
- **Energia:** custo 42 · cooldown 10,2 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Whirlpool

`whirlpool` · Água · Especial · poder 35 · precisão 85% · PP oficial 15

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 1,6 m de raio (alcance 8 m) que dura 2,5 s e bate a cada 0,5 s em quem estiver dentro. [alcance 8 m, raio 1,6 m, 2,5 s]
- **Energia:** custo 21 · cooldown 10,4 s
- **Aprendem:** 37 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 35), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Acerta quem está mergulhado (Dive) em dobro.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,6 s (parado dentro da área).

### Withdraw

`withdraw` · Água · Status · poder — · precisão nunca erra · PP oficial 40

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Defesa do usuário sobe em 1 estágio (multiplicador (2+n)/2, limite de -6 a +6).

<a id="tipo-electric"></a>

## Elétrico (31)

### Charge

`charge` · Elétrico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - At. Esp. +1 e o próximo golpe Elétrico do usuário sai com poder x2 (vale até esse golpe acertar).

### Charge Beam

`charge_beam` · Elétrico · Especial · poder 50 · precisão 90% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,8 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 0,8 m, preparo 0,45 s]
- **Energia:** custo 25 · cooldown 7,4 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 70% de chance: sobe At. Esp. do usuário em 1 estágio.

### Discharge

`discharge` · Elétrico · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,5 m, preparo 0,3 s]
- **Energia:** custo 32 · cooldown 5,5 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Eerie Impulse

`eerie_impulse` · Elétrico · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - At. Esp. do adversário mais perto cai em 2 estágios, alcance 6 m.

### Electric Terrain

`electric_terrain` · Elétrico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Campo elétrico por 5 rodadas: Elétrico 1,3x para quem está no chão e ninguém no chão dorme. Um terreno tira o outro.

### Electro Ball

`electro_ball` · Elétrico · Especial · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 40 a 150 pela razão de Speed usuário/alvo (>=1x: 60, >=2x: 80, >=3x: 120, >=4x: 150).

### Electro Drift

`electro_drift` · Elétrico · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 21 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 21 m/s]
- **Energia:** custo 37 · cooldown 17,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Investida elétrica rápida; se o golpe é super efetivo o poder sobe 4/3 (o 'bônus de supereficaz' oficial).

### Electro Shot

`electro_shot` · Elétrico · Especial · poder 130 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 0,9 m de largura; avisa no chão por 0,9 s e dispara; o usuário fica parado 0,8 s depois. [alcance 14 m, largura 0,9 m, preparo 0,9 s]
- **Energia:** custo 45 · cooldown 14,9 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de 130 de poder com carga: no preparo longo o usuário ganha +1 de At. Esp.; na chuva a carga é pulada (preparo curto).
  - Ao começar a usar, muda os atributos do usuário: At. Esp. +1 (o turno de carga do oficial).

### Electroweb

`electroweb` · Elétrico · Especial · poder 55 · precisão 95% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 13 m/s; dá para desviar. Sai uma leva de 3 em leque de 35°. [alcance 10 m, 13 m/s]
- **Energia:** custo 26 · cooldown 4,2 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 3): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Sempre baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Magnet Rise

`magnet_rise` · Elétrico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Levita por 5 rodadas: imune a golpes de Terra e não pisa no chão (Gravity derruba).

### Magnetic Flux

`magnetic_flux` · Elétrico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Defesa +1 e Def. Esp. +1 do usuário e do parceiro que tenham Plus ou Minus. Falha se ninguém tem.

### Nuzzle

`nuzzle` · Elétrico · Físico · poder 20 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3,5 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3,5 m, 13 m/s]
- **Energia:** custo 17 · cooldown 3,1 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre causa Paralisia no alvo (depois do dano). Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Overdrive

`overdrive` · Elétrico · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 90° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 90°, 0,5 s]
- **Energia:** custo 32 · cooldown 8,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Riff de guitarra: onda de som em cone que acerta todos os adversários. Golpe de som.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Parabolic Charge

`parabolic_charge` · Elétrico · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,5 m, preparo 0,35 s]
- **Energia:** custo 28 · cooldown 4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Onda elétrica em volta do usuário, que acerta todos (até o parceiro) e cura o usuário com metade do dano total.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Rising Voltage

`rising_voltage` · Elétrico · Especial · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,5 m, preparo 0,45 s]
- **Energia:** custo 30 · cooldown 4,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Descarga que sobe do chão no alvo; o poder dobra se o Campo Elétrico está ativo e o alvo está no chão.

### Shock Wave

`shock_wave` · Elétrico · Especial · poder 60 · precisão nunca erra · PP oficial 20

- **Entrega:** `homing` (Teleguiado). Projétil teleguiado: faz curva atrás do alvo (curva 5), até 14 m a 16 m/s. Não erra. [alcance 14 m, 16 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Spark

`spark` · Elétrico · Físico · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Supercell Slam

`supercell_slam` · Elétrico · Físico · poder 100 · precisão 95% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 18 m/s]
- **Energia:** custo 37 · cooldown 5,7 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se errar ou for parado, o usuário se machuca em 50% do HP máximo (golpe de risco).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Thunder

`thunder` · Elétrico · Especial · poder 110 · precisão 70% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,2 m de raio sobre ele (alcance 14 m) e cai depois de 1 s; quem sair da marca escapa. [alcance 14 m, raio 2,2 m, preparo 1 s]
- **Energia:** custo 40 · cooldown 13,1 s
- **Aprendem:** 49 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Na chuva nunca erra (oficial). Atinge quem está no alto (Fly/Bounce).
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Thunder Cage

`thunder_cage` · Elétrico · Especial · poder 80 · precisão 90% · PP oficial 15

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,5 m, preparo 0,5 s]
- **Energia:** custo 32 · cooldown 6,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Gaiola elétrica na área do alvo; prende por 4-5 rodadas (1/8 do HP por rodada) e impede a fuga.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Prende o alvo no lugar por 0,8 s (parado dentro da área).

### Thunder Fang

`thunder_fang` · Elétrico · Físico · poder 65 · precisão 95% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 28 · cooldown 4,2 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - 10% de chance extra de o alvo hesitar (0,5 s parado).

### Thunder Punch

`thunder_punch` · Elétrico · Físico · poder 75 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 31 · cooldown 4,4 s
- **Aprendem:** 43 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Thunder Shock

`thunder_shock` · Elétrico · Especial · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 26 m/s; dá para desviar. [alcance 10 m, 26 m/s]
- **Energia:** custo 22 · cooldown 2,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 15% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Thunder Wave

`thunder_wave` · Elétrico · Status · poder — · precisão 90% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 20 m/s; dá para desviar. [alcance 9 m, 20 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 36 espécie(s) do jogo
- **Adaptação:**
  - Não afeta Terra (e Elétrico é imune à paralisia). Um alvo sob Substitute bloqueia.
  - Causa Paralisia no alvo se acertar. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Thunderbolt

`thunderbolt` · Elétrico · Especial · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 13 m a 30 m/s; dá para desviar. [alcance 13 m, 30 m/s]
- **Energia:** custo 35 · cooldown 5,2 s
- **Aprendem:** 50 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Thunderclap

`thunderclap` · Elétrico · Especial · poder 70 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,3 m de raio sobre ele (alcance 10 m) e cai depois de 0,1 s; quem sair da marca escapa. [alcance 10 m, raio 1,3 m, preparo 0,12 s]
- **Energia:** custo 18 · cooldown 23 s · prioridade +1
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio instantâneo (prioridade +1, preparo de 0,12 s) que só sai se o alvo estiver preparando um golpe de dano.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Volt Switch

`volt_switch` · Elétrico · Especial · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 22 m/s; dá para desviar. [alcance 11 m, 22 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de bater, o usuário troca de lugar com o próximo Pokémon do banco (sai 0,35 s depois). Sem reserva, só bate.

### Volt Tackle

`volt_tackle` · Elétrico · Físico · poder 120 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 9 m, 18 m/s) e bate no contato. [alcance 9 m, 18 m/s]
- **Energia:** custo 42 · cooldown 6,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Wild Charge

`wild_charge` · Elétrico · Físico · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 18 m/s]
- **Energia:** custo 35 · cooldown 5,2 s
- **Aprendem:** 19 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 25% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Wildbolt Storm

`wildbolt_storm` · Elétrico · Especial · poder 100 · precisão 80% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2,8 m, preparo 0,8 s]
- **Energia:** custo 37 · cooldown 11,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Tempestade elétrica numa área larga; 20% de paralisar. Na chuva nunca erra.
  - 20% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Zap Cannon

`zap_cannon` · Elétrico · Especial · poder 120 · precisão 50% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 11 m/s; dá para desviar. [alcance 11 m, 11 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre causa Paralisia no alvo (depois do dano). Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

<a id="tipo-grass"></a>

## Planta (39)

### Absorb

`absorb` · Planta · Especial · poder 20 · precisão 100% · PP oficial 25

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 17 · cooldown 2,5 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Apple Acid

`apple_acid` · Planta · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,8 m): até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Cusparada de suco em arco (projétil lento); cada acerto baixa a Def. Esp. do alvo em 1.
  - Sempre baixa Def. Esp. do alvo em 1 estágio.

### Aromatherapy

`aromatherapy` · Planta · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Cura o status principal de todo o time do usuário (os de campo e os do banco).

### Bullet Seed

`bullet_seed` · Planta · Físico · poder 25 x 2-5 · precisão 100% · PP oficial 30

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (1,9 m, 60°), um a cada 0,2 s. [alcance 1,9 m, 60°]
- **Energia:** custo 31 · cooldown 2,1 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Energy Ball

`energy_ball` · Planta · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 30 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Frenzy Plant

`frenzy_plant` · Planta · Especial · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2 m, preparo 0,8 s]
- **Energia:** custo 50 · cooldown 29 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.

### Giga Drain

`giga_drain` · Planta · Especial · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 9 m a 16 m/s; dá para desviar. [alcance 9 m, 16 m/s]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 32 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Grass Knot

`grass_knot` · Planta · Especial · poder variável · precisão 100% · PP oficial 20

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,3 m de raio sobre ele (alcance 8 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 8 m, raio 1,3 m, preparo 0,5 s]
- **Energia:** custo 30 · cooldown 4,4 s
- **Aprendem:** 36 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 20 a 120 pelo peso do alvo (tabela oficial: leve bate fraco, pesado bate forte).

### Grass Pledge

`grass_pledge` · Planta · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 8 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 8 m, raio 1,5 m, preparo 0,7 s]
- **Energia:** custo 32 · cooldown 9 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Grassy Glide

`grassy_glide` · Planta · Físico · poder 55 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 19 m/s]
- **Energia:** custo 26 · cooldown 3,1 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1 enquanto houver Grassy Terrain e o usuário estiver no chão.

### Grassy Terrain

`grassy_terrain` · Planta · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Campo de grama por 5 rodadas: Planta 1,3x para quem está no chão, cura 1/16 do HP por rodada no chão, Earthquake/Bulldoze/Magnitude 0,5x. Um terreno tira o outro.

### Ingrain

`ingrain` · Planta · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Cria raízes: cura 1/16 do HP no fim de cada rodada, o usuário não é empurrado nem pode trocar (Ingrain).

### Leaf Blade

`leaf_blade` · Planta · Físico · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 100°. [alcance 2,2 m, 100°]
- **Energia:** custo 35 · cooldown 5,2 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Leaf Storm

`leaf_storm` · Planta · Especial · poder 130 · precisão 90% · PP oficial 5

- **Entrega:** `stream` (Jato). Jato em cone: 6 m de alcance, 60° de abertura, durante 0,8 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 6 m, 60°, 0,8 s]
- **Energia:** custo 45 · cooldown 25,4 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -2.
  - Precisão oficial 90%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Leaf Tornado

`leaf_tornado` · Planta · Especial · poder 65 · precisão 90% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,7 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,7 m, preparo 0,5 s]
- **Energia:** custo 28 · cooldown 7,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Redemoinho de folhas na área do alvo; 50% de baixar a Precisão dele.
  - 50% de chance: baixa Precisão do alvo em 1 estágio.

### Leech Seed

`leech_seed` · Planta · Status · poder — · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 10 m/s; dá para desviar. [alcance 9 m, 10 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Causa Semente (Leech Seed) no alvo se acertar. Semente: 1/8 do HP por rodada passa para quem plantou; Planta é imune.

### Magical Leaf

`magical_leaf` · Planta · Especial · poder 60 · precisão nunca erra · PP oficial 20

- **Entrega:** `homing` (Teleguiado). Projétil teleguiado: faz curva atrás do alvo (curva 5), até 14 m a 13 m/s. Não erra. Solta 3, um a cada 0,08 s. [alcance 14 m, 13 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 3): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).

### Matcha Gotcha

`matcha_gotcha` · Planta · Especial · poder 80 · precisão 90% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Jato de chá em arco que cura o usuário com metade do dano; 20% de queimar.
  - 20% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Mega Drain

`mega_drain` · Planta · Especial · poder 40 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 9 m a 16 m/s; dá para desviar. [alcance 9 m, 16 m/s]
- **Energia:** custo 22 · cooldown 4,2 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Petal Blizzard

`petal_blizzard` · Planta · Físico · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,5 m, preparo 0,3 s]
- **Energia:** custo 35 · cooldown 6,1 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Petal Dance

`petal_dance` · Planta · Especial · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 80° de abertura, durante 1,8 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 80°, 1,8 s]
- **Energia:** custo 42 · cooldown 17,5 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois que o golpe termina, o usuário fica confuso de cansaço (como o oficial, que repete 2-3 turnos e confunde ao fim).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Power Whip

`power_whip` · Planta · Físico · poder 120 · precisão 85% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 17 m/s]
- **Energia:** custo 42 · cooldown 10,2 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Razor Leaf

`razor_leaf` · Planta · Físico · poder 55 · precisão 95% · PP oficial 25

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. Sai uma leva de 3 em leque de 30°. [alcance 11 m, 15 m/s]
- **Energia:** custo 26 · cooldown 2,5 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 3): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Seed Bomb

`seed_bomb` · Planta · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 13 m/s; dá para desviar. [alcance 10 m, 13 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Seed Flare

`seed_flare` · Planta · Especial · poder 120 · precisão 85% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,3 m de raio sobre ele (alcance 9 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 9 m, raio 2,3 m, preparo 0,7 s]
- **Energia:** custo 42 · cooldown 23,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Onda de luz no alvo; 40% de baixar 2 estágios da Def. Esp.
  - 40% de chance: baixa Def. Esp. do alvo em 2 estágios.

### Sleep Powder

`sleep_powder` · Planta · Status · poder — · precisão 75% · PP oficial 15

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 8 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 8 m, raio 1,8 m, preparo 0,6 s]
- **Energia:** custo 28 · cooldown 17 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Causa Sono no alvo se acertar (75% de chance). Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.

### Solar Beam

`solar_beam` · Planta · Especial · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 1 m de largura; avisa no chão por 1,1 s e dispara; o usuário fica parado 0,6 s depois. [alcance 14 m, largura 1 m, preparo 1,1 s]
- **Energia:** custo 42 · cooldown 14,6 s
- **Aprendem:** 37 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O 'turno de carga' virou o preparo do raio (windup). Sob chuva, areia ou neve o dano cai à metade (x0,5), como no oficial.

### Solar Blade

`solar_blade` · Planta · Físico · poder 125 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,4 m à frente, num arco de 100°. [alcance 2,4 m, 100°, preparo 1,1 s]
- **Energia:** custo 43 · cooldown 15,2 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 125), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Spicy Extract

`spicy_extract` · Planta · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O alvo ganha 2 de Ataque e perde 2 de Defesa.

### Spiky Shield

`spiky_shield` · Planta · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +4
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Protege como o Protect (prioridade +4, o turno todo). Quem encosta com golpe de contato perde 1/8 do HP.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Spore

`spore` · Planta · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 8 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 8 m, raio 1,8 m, preparo 0,6 s]
- **Energia:** custo 28 · cooldown 17 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Causa Sono no alvo se acertar. Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.

### Strength Sap

`strength_sap` · Planta · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura o usuário pelo valor do Ataque do alvo e baixa o Ataque do alvo em 1.

### Stun Spore

`stun_spore` · Planta · Status · poder — · precisão 75% · PP oficial 30

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 8 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 8 m, raio 1,8 m, preparo 0,6 s]
- **Energia:** custo 28 · cooldown 10,8 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Causa Paralisia no alvo se acertar (75% de chance). Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.

### Synthesis

`synthesis` · Planta · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Cura o usuário em 1/2 do HP máximo; 2/3 sob sol forte, 1/4 sob qualquer outro clima (chuva, areia, neve).

### Syrup Bomb

`syrup_bomb` · Planta · Especial · poder 60 · precisão 85% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,8 m): até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 27 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bomba de xarope: ao acertar, o alvo perde 1 de Velocidade no fim de cada uma das 3 rodadas seguintes.

### Trailblaze

`trailblaze` · Planta · Físico · poder 50 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 25 · cooldown 3,1 s
- **Aprendem:** 34 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre sobe Speed do usuário em 1 estágio.

### Vine Whip

`vine_whip` · Planta · Físico · poder 45 · precisão 100% · PP oficial 25

- **Entrega:** `whip` (Chicote). Chicote: 1 ponta(s) varrem uma linha de até 4 m e acertam o primeiro que tocar. [alcance 4 m]
- **Energia:** custo 23 · cooldown 2,5 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 45), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Wood Hammer

`wood_hammer` · Planta · Físico · poder 120 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, preparo 0,3 s, 16 m/s]
- **Energia:** custo 42 · cooldown 8 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Worry Seed

`worry_seed` · Planta · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - A habilidade do alvo vira Insomnia (e acorda quem dorme).

<a id="tipo-ice"></a>

## Gelo (21)

### Aurora Beam

`aurora_beam` · Gelo · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Ataque do alvo em 1 estágio.

### Avalanche

`avalanche` · Gelo · Físico · poder 60 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,6 m de raio sobre ele (alcance 7 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 7 m, raio 1,6 m, preparo 0,6 s]
- **Energia:** custo 27 · cooldown 7,8 s · prioridade -4
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo acertou o usuário nos últimos 1,5 s (o 'virou o jogo' do Revenge/Avalanche/Payback).
  - Prioridade -4: na fila da rodada sai depois dos normais; prepara 0,4 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Blizzard

`blizzard` · Gelo · Especial · poder 110 · precisão 70% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,8 m de raio sobre ele (alcance 10 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 10 m, raio 2,8 m, preparo 0,8 s]
- **Energia:** custo 40 · cooldown 21,8 s
- **Aprendem:** 61 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Freeze-Dry

`freeze_dry` · Gelo · Especial · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Água é fraca ao Gelo neste golpe (a resistência vira fraqueza).
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.

### Frost Breath

`frost_breath` · Gelo · Especial · poder 60 · precisão 90% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 50° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 50°, 0,5 s]
- **Energia:** custo 27 · cooldown 7,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sopro gelado em cone; sempre crítico.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Estágio de crítico +3.
  - Precisão oficial 90%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Glaciate

`glaciate` · Gelo · Especial · poder 65 · precisão 95% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 6,5 m de alcance, 110° de abertura, durante 0,7 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 6,5 m, 110°, 0,7 s]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sopro gelado largo (cone de 110 graus) que acerta todos os adversários e baixa a Velocidade deles em 1.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Sempre baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 95%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Hail

`hail` · Gelo · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Chama o granizo/neve no campo (clima de gelo por alguns turnos).

### Haze

`haze` · Gelo · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 32 espécie(s) do jogo
- **Adaptação:**
  - Zera os estágios de atributo de todos em campo.

### Ice Beam

`ice_beam` · Gelo · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,8 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 0,8 m, preparo 0,45 s]
- **Energia:** custo 35 · cooldown 9,2 s
- **Aprendem:** 61 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.

### Ice Fang

`ice_fang` · Gelo · Físico · poder 65 · precisão 95% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 28 · cooldown 4,2 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.
  - 10% de chance extra de o alvo hesitar (0,5 s parado).

### Ice Punch

`ice_punch` · Gelo · Físico · poder 75 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 31 · cooldown 4,4 s
- **Aprendem:** 41 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.

### Ice Shard

`ice_shard` · Gelo · Físico · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 20 m/s; dá para desviar. [alcance 11 m, 20 m/s]
- **Energia:** custo 13 · cooldown 3,8 s · prioridade +1
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Ice Spinner

`ice_spinner` · Gelo · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de bater, apaga qualquer terreno de campo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Icicle Crash

`icicle_crash` · Gelo · Físico · poder 85 · precisão 90% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,5 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,5 m, preparo 0,5 s]
- **Energia:** custo 33 · cooldown 8,9 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Icicle Spear

`icicle_spear` · Gelo · Físico · poder 25 x 2-5 · precisão 100% · PP oficial 30

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (1,9 m, 60°), um a cada 0,2 s. [alcance 1,9 m, 60°]
- **Energia:** custo 31 · cooldown 2,1 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Icy Wind

`icy_wind` · Gelo · Especial · poder 55 · precisão 95% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 70° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 70°, 0,6 s]
- **Energia:** custo 26 · cooldown 5,7 s
- **Aprendem:** 61 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Sempre baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 95%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Mist

`mist` · Gelo · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Névoa protetora por 5 rodadas: o lado do usuário não tem atributos baixados pelo adversário.

### Powder Snow

`powder_snow` · Gelo · Especial · poder 40 · precisão 100% · PP oficial 25

- **Entrega:** `stream` (Jato). Jato em cone: 4,5 m de alcance, 70° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 4,5 m, 70°, 0,6 s]
- **Energia:** custo 22 · cooldown 4 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 10% de chance de causar Congelamento no alvo. Congelamento: 20% de descongelar a cada tentativa de agir; golpe de Fogo descongela; Gelo é imune.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Sheer Cold

`sheer_cold` · Gelo · Especial · poder variável · precisão 30% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,4 m de raio sobre ele (alcance 8 m) e cai depois de 0,9 s; quem sair da marca escapa. [alcance 8 m, raio 1,4 m, preparo 0,9 s]
- **Energia:** custo 30 · cooldown 14,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Nocaute em um golpe: tira todo o HP do alvo. A precisão sobe 1 ponto por nível do usuário acima do alvo; não afeta alvo de nível maior nem Sturdy.

### Snowscape

`snowscape` · Gelo · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Chama o granizo/neve no campo (clima de gelo por alguns turnos).

### Triple Axel

`triple_axel` · Gelo · Físico · poder 20 x 3 · precisão 90% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (2 m, 80°), um a cada 0,2 s. [alcance 2 m, 80°]
- **Energia:** custo 27 · cooldown 6,3 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Três chutes seguidos; o poder cresce a cada acerto (20, 40, 60).
  - Multi-hit oficial: 3 acertos por uso no mesmo alvo, cada um com o poder oficial (20).

<a id="tipo-fighting"></a>

## Lutador (37)

### Aura Sphere

`aura_sphere` · Lutador · Especial · poder 80 · precisão nunca erra · PP oficial 20

- **Entrega:** `homing` (Teleguiado). Projétil teleguiado: faz curva atrás do alvo (curva 5), até 14 m a 13 m/s. Não erra. [alcance 14 m, 13 m/s]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Axe Kick

`axe_kick` · Lutador · Físico · poder 120 · precisão 90% · PP oficial 10

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,4 s no ar, 1,7 m de altura) e cai em cima do alvo (alcance 4,5 m). Só sai no chão (no ar espera pousar). [alcance 4,5 m, preparo 0,3 s, 14 m/s]
- **Energia:** custo 42 · cooldown 11,4 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.
  - Se errar ou for parado, o usuário se machuca em 50% do HP máximo (golpe de risco).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Body Press

`body_press` · Lutador · Físico · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 5 m, 15 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 5 m, 15 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Usa a Defesa do usuário no lugar do Ataque no cálculo do dano.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Brick Break

`brick_break` · Lutador · Físico · poder 75 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 31 · cooldown 4,4 s
- **Aprendem:** 57 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se o golpe for eficaz, quebra o Reflect e o Light Screen do lado do alvo antes de acertar.

### Bulk Up

`bulk_up` · Lutador · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, Defesa +1.

### Circle Throw

`circle_throw` · Lutador · Físico · poder 60 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 27 · cooldown 6,3 s · prioridade -6
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - No oficial força a troca; aqui o alvo é arremessado 4 m para longe depois do dano.
  - Prioridade -6: na fila da rodada sai depois dos normais; prepara 0,6 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Close Combat

`close_combat` · Lutador · Físico · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (2 m, 90°), um a cada 0,2 s. [alcance 2 m, 90°]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 3): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Defesa -1, Def. Esp. -1.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Coaching

`coaching` · Lutador · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Ataque +1 e Defesa +1 do parceiro. Sem parceiro, falha.

### Counter

`counter` · Lutador · Físico · poder variável · precisão 100% · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 30 · cooldown 3,1 s · prioridade -5
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Postura de 1 s parado (prioridade -5): o primeiro golpe físico recebido nela volta com o dobro do dano para quem bateu.
  - Prioridade -5: na fila da rodada sai depois dos normais; prepara 0,5 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Cross Chop

`cross_chop` · Lutador · Físico · poder 100 · precisão 80% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 37 · cooldown 17,2 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Detect

`detect` · Lutador · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 67,5 s · prioridade +4
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Bloqueia quase tudo até o fim da rodada. Usado em rodadas seguidas: chance 1, 1/3, 1/9... (zera quando uma rodada passa sem usar). Feint quebra.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Double Kick

`double_kick` · Lutador · Físico · poder 30 x 2 · precisão 100% · PP oficial 30

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 2 golpes no cone (1,9 m, 60°), um a cada 0,2 s. [alcance 1,9 m, 60°]
- **Energia:** custo 27 · cooldown 2,1 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (30).

### Drain Punch

`drain_punch` · Lutador · Físico · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 31 · cooldown 6,6 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Dynamic Punch

`dynamic_punch` · Lutador · Físico · poder 100 · precisão 50% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°, preparo 0,2 s]
- **Energia:** custo 37 · cooldown 17,9 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre causa Confusão no alvo (depois do dano). Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Final Gambit

`final_gambit` · Lutador · Especial · poder variável · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 18 m/s]
- **Energia:** custo 30 · cooldown 12,5 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano = HP atual do usuário, que desmaia depois.

### Focus Blast

`focus_blast` · Lutador · Especial · poder 120 · precisão 70% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 41 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Focus Punch

`focus_punch` · Lutador · Físico · poder 150 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°, preparo 1 s]
- **Energia:** custo 50 · cooldown 11,3 s · prioridade -3
- **Aprendem:** 37 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Concentra primeiro (prioridade -3); se o usuário levar dano antes de bater, perde a concentração e o golpe falha.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,7 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.
  - Prioridade -3: na fila da rodada sai depois dos normais; prepara 0,3 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Hammer Arm

`hammer_arm` · Lutador · Físico · poder 100 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°, preparo 0,2 s]
- **Energia:** custo 37 · cooldown 9,3 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Speed -1.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### High Jump Kick

`high_jump_kick` · Lutador · Físico · poder 130 · precisão 90% · PP oficial 10

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,6 s no ar, 2,4 m de altura) e cai em cima do alvo (alcance 5 m). Só sai no chão (no ar espera pousar). [alcance 5 m, preparo 0,3 s, 14 m/s]
- **Energia:** custo 45 · cooldown 12,3 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se errar ou for parado, o usuário se machuca em 50% do HP máximo (golpe de risco).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,1 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Karate Chop

`karate_chop` · Lutador · Físico · poder 50 · precisão 100% · PP oficial 25

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 25 · cooldown 2,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Low Kick

`low_kick` · Lutador · Físico · poder variável · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 30 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 20 a 120 pelo peso do alvo (tabela oficial: leve bate fraco, pesado bate forte).

### Low Sweep

`low_sweep` · Lutador · Físico · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 100°. [alcance 2 m, 100°]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Speed do alvo em 1 estágio.

### Mach Punch

`mach_punch` · Lutador · Físico · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 21 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, preparo 0,02 s, 21 m/s]
- **Energia:** custo 13 · cooldown 3,8 s · prioridade +1
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### No Retreat

`no_retreat` · Lutador · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Sobe todos os atributos em 1, mas o usuário fica preso: não pode fugir nem trocar até sair de campo.

### Octolock

`octolock` · Lutador · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Prende o alvo (não foge nem troca) por 4 rodadas; no fim de cada uma ele perde 1 de Defesa e 1 de Def. Esp. Um aperto curto trava o movimento dele.

### Quick Guard

`quick_guard` · Lutador · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 22,5 s · prioridade +3
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Até o fim da rodada, o lado do usuário não é atingido por golpes de prioridade.
  - Prioridade +3: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Revenge

`revenge` · Lutador · Físico · poder 60 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 27 · cooldown 6,3 s · prioridade -4
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo acertou o usuário nos últimos 1,5 s (o 'virou o jogo' do Revenge/Avalanche/Payback).
  - Prioridade -4: na fila da rodada sai depois dos normais; prepara 0,4 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Reversal

`reversal` · Lutador · Físico · poder variável · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 22 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 20 a 200 pela tabela oficial do Flail/Reversal: quanto menos HP o usuário tem, mais forte.

### Rock Smash

`rock_smash` · Lutador · Físico · poder 40 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 22 · cooldown 4,2 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 50% de chance: baixa Defesa do alvo em 1 estágio.

### Secret Sword

`secret_sword` · Lutador · Especial · poder 85 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,4 m à frente, num arco de 100°. [alcance 2,4 m, 100°]
- **Energia:** custo 33 · cooldown 7,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe especial calculado contra a Defesa física do alvo.
  - Corte de chifre em arco curto; é especial mas usa a Defesa do alvo em vez da Def. Esp. (como o Psyshock).

### Seismic Toss

`seismic_toss` · Lutador · Físico · poder variável · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 100°. [alcance 2 m, 100°]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo igual ao nível do usuário (Seismic Toss / Night Shade). Só o ritmo x0,75 vai por cima.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Storm Throw

`storm_throw` · Lutador · Físico · poder 60 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 80°. [alcance 2 m, 80°]
- **Energia:** custo 27 · cooldown 6,3 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Estágio de crítico +3.

### Submission

`submission` · Lutador · Físico · poder 80 · precisão 80% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3 m, 13 m/s]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 25% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Superpower

`superpower` · Lutador · Físico · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 17 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Ataque -1, Defesa -1.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Upper Hand

`upper_hand` · Lutador · Físico · poder 65 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 20 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, preparo 0,03 s, 20 m/s]
- **Energia:** custo 17 · cooldown 7,6 s · prioridade +3
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só sai se o alvo está preparando um golpe de prioridade; acerta primeiro e faz hesitar.
  - Sempre causa Hesitar no alvo (depois do dano). Hesitar: o alvo fica parado 0,5 s.
  - Prioridade +3: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Vacuum Wave

`vacuum_wave` · Lutador · Especial · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 20 m/s; dá para desviar. [alcance 11 m, 20 m/s]
- **Energia:** custo 13 · cooldown 3,8 s · prioridade +1
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Vital Throw

`vital_throw` · Lutador · Físico · poder 70 · precisão nunca erra · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 80°. [alcance 2 m, 80°]
- **Energia:** custo 30 · cooldown 6,3 s · prioridade -1
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade -1: na fila da rodada sai depois dos normais; prepara 0,1 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

<a id="tipo-poison"></a>

## Veneno (26)

### Acid

`acid` · Veneno · Especial · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 15 m/s; dá para desviar. [alcance 9 m, 15 m/s]
- **Energia:** custo 22 · cooldown 2,1 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Acid Armor

`acid_armor` · Veneno · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Defesa do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Acid Spray

`acid_spray` · Veneno · Especial · poder 40 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,6 m): até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 22 · cooldown 3,1 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Def. Esp. do alvo em 2 estágios.

### Belch

`belch` · Veneno · Especial · poder 120 · precisão 90% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 3,5 m de alcance, 60° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 3,5 m, 60°, 0,6 s]
- **Energia:** custo 42 · cooldown 12,6 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só pode ser usado depois de comer uma frutinha na luta (ver Pluck/Bug Bite).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 90%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Clear Smog

`clear_smog` · Veneno · Especial · poder 50 · precisão nunca erra · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 25 · cooldown 4,2 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, zera os estágios de atributo do alvo.

### Coil

`coil` · Veneno · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, Defesa +1, Precisão +1.

### Cross Poison

`cross_poison` · Veneno · Físico · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Gastro Acid

`gastro_acid` · Veneno · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,4 m): até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Anula a habilidade do alvo pelo resto da luta.

### Gunk Shot

`gunk_shot` · Veneno · Físico · poder 120 · precisão 80% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 2,4 m): até 10 m a 14 m/s; dá para desviar. [alcance 10 m, 14 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Malignant Chain

`malignant_chain` · Veneno · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `whip` (Chicote). Chicote: 2 ponta(s) varrem uma linha de até 4,5 m e acertam o primeiro que tocar. [alcance 4,5 m]
- **Energia:** custo 37 · cooldown 17,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Duas pontas de corrente que chicoteiam em arco curto; 50% de envenenar gravemente.
  - 50% de chance de causar Toxic (veneno grave) no alvo. Toxic: n/16 do HP no n-ésimo turno; Veneno e Aço são imunes.

### Poison Fang

`poison_fang` · Veneno · Físico · poder 50 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 25 · cooldown 4,2 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 50% de chance de causar Toxic (veneno grave) no alvo. Toxic: n/16 do HP no n-ésimo turno; Veneno e Aço são imunes.

### Poison Gas

`poison_gas` · Veneno · Status · poder — · precisão 90% · PP oficial 40

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Causa Veneno no alvo se acertar. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Poison Jab

`poison_jab` · Veneno · Físico · poder 80 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 40 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Poison Powder

`poison_powder` · Veneno · Status · poder — · precisão 75% · PP oficial 35

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 2,2 m de raio (alcance 7 m) que dura 4 s e bate a cada 0,5 s em quem estiver dentro. [alcance 7 m, raio 2,2 m, 4 s]
- **Energia:** custo 28 · cooldown 35,4 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Causa Veneno no alvo se acertar (35% de chance). Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.

### Poison Sting

`poison_sting` · Veneno · Físico · poder 15 · precisão 100% · PP oficial 35

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 18 m/s; dá para desviar. [alcance 9 m, 18 m/s]
- **Energia:** custo 16 · cooldown 1,8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 15), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Poison Tail

`poison_tail` · Veneno · Físico · poder 50 · precisão 100% · PP oficial 25

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 110°. [alcance 2,2 m, 110°]
- **Energia:** custo 25 · cooldown 2,5 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Purify

`purify` · Veneno · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura o status do alvo e o usuário recupera metade do HP máximo; falha se o alvo não tem status.

### Sludge

`sludge` · Veneno · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 2,2 m): até 9 m a 15 m/s; dá para desviar. [alcance 9 m, 15 m/s]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Sludge Bomb

`sludge_bomb` · Veneno · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 2,2 m): até 10 m a 14 m/s; dá para desviar. [alcance 10 m, 14 m/s]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 41 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Sludge Wave

`sludge_wave` · Veneno · Especial · poder 95 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,35 s]
- **Energia:** custo 36 · cooldown 9,4 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Smog

`smog` · Veneno · Especial · poder 30 · precisão 70% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 20 · cooldown 3,1 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 40% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Toxic

`toxic` · Veneno · Status · poder — · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,4 m): até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 31 espécie(s) do jogo
- **Adaptação:**
  - Não erra quando o usuário é do tipo Veneno (regra oficial).
  - Causa Toxic (veneno grave) no alvo se acertar. Toxic: n/16 do HP no n-ésimo turno; Veneno e Aço são imunes.

### Toxic Spikes

`toxic_spikes` · Veneno · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Espinhos venenosos no chão sob os adversários (duram 20 s): 1 camada envenena, 2 camadas dão Toxic; Veneno que pisa absorve.

### Toxic Thread

`toxic_thread` · Veneno · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Fio venenoso: envenena o alvo (100%) e derruba a Velocidade dele em 1.
  - Causa Veneno no alvo se acertar. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### Venom Drench

`venom_drench` · Veneno · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário. Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Se o alvo está envenenado, baixa Ataque, At. Esp. e Speed dele em 1 cada; senão sem efeito.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Venoshock

`venoshock` · Veneno · Especial · poder 65 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 14 m/s; dá para desviar. [alcance 10 m, 14 m/s]
- **Energia:** custo 28 · cooldown 6,3 s
- **Aprendem:** 33 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo está envenenado (veneno ou Toxic).

<a id="tipo-ground"></a>

## Terra (21)

### Bone Rush

`bone_rush` · Terra · Físico · poder 25 x 2-5 · precisão 90% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 3 golpes no cone (2 m, 80°), um a cada 0,1 s. [alcance 2 m, 80°]
- **Energia:** custo 31 · cooldown 6,3 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os golpes sorteados, todos no mesmo alvo.

### Bonemerang

`bonemerang` · Terra · Físico · poder 50 x 2 · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 37 · cooldown 6,3 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (50).

### Bulldoze

`bulldoze` · Terra · Físico · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). O usuário agacha, salta e bate no chão; o dano sai no pouso. [raio 4 m, preparo 0,35 s]
- **Energia:** custo 27 · cooldown 4 s
- **Aprendem:** 43 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - No Grassy Terrain cai à metade (x0,5) em quem está no chão.
  - Sempre baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Dig

`dig` · Terra · Físico · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida por baixo: afunda e anda por baixo do chão até 7 m, a 8 m/s, e sai sob o alvo. Só sai no chão (no ar espera pousar). [alcance 7 m, 8 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 70 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Afunda em 0,3 s (invulnerável), anda por baixo da terra até o alvo e sai sob ele. Só Earthquake, Magnitude (dobro) e Fissure o alcançam enquanto está sob a terra.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Drill Run

`drill_run` · Terra · Físico · poder 80 · precisão 95% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6 m, 14 m/s) e bate no contato. [alcance 6 m, 14 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Earth Power

`earth_power` · Terra · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,4 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 2,4 m, preparo 0,5 s]
- **Energia:** custo 35 · cooldown 9,4 s
- **Aprendem:** 29 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Earthquake

`earthquake` · Terra · Físico · poder 100 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). O usuário agacha, salta e bate no chão; o dano sai no pouso. [raio 4,5 m, preparo 0,4 s]
- **Energia:** custo 37 · cooldown 10 s
- **Aprendem:** 43 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Acerta quem está sob a terra (Dig) em dobro. No Grassy Terrain cai à metade (x0,5). Quem está no ar não é atingido; o parceiro pula ao ver o terremoto.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Fissure

`fissure` · Terra · Físico · poder variável · precisão 30% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,3 m de raio sobre ele (alcance 8 m) e cai depois de 0,9 s; quem sair da marca escapa. [alcance 8 m, raio 1,3 m, preparo 0,9 s]
- **Energia:** custo 30 · cooldown 14,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Nocaute em um golpe: tira todo o HP do alvo. A precisão sobe 1 ponto por nível do usuário acima do alvo; não afeta alvo de nível maior nem Sturdy.
  - Alcança quem está sob a terra (Dig), como o oficial.

### High Horsepower

`high_horsepower` · Terra · Físico · poder 95 · precisão 95% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 18 m/s]
- **Energia:** custo 36 · cooldown 8,2 s
- **Aprendem:** 19 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,1 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Magnitude

`magnitude` · Terra · Físico · poder variável · precisão 100% · PP oficial 30

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). O usuário agacha, salta e bate no chão; o dano sai no pouso. [raio 4 m, preparo 0,4 s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - No Grassy Terrain cai à metade (x0,5). Sorteia a magnitude (4 a 10) e ela define o poder, o pulo e o impacto. Acerta quem está sob a terra em dobro.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Mud Shot

`mud_shot` · Terra · Especial · poder 55 · precisão 95% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 26 · cooldown 4,2 s
- **Aprendem:** 38 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Speed do alvo em 1 estágio.

### Mud Sport

`mud_sport` · Terra · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cobre a quadra de lama por 5 rodadas: todo golpe Elétrico (de qualquer lado) sai com 1/3 do poder.

### Mud-Slap

`mud_slap` · Terra · Especial · poder 20 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 17 · cooldown 6,3 s
- **Aprendem:** 28 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Precisão do alvo em 1 estágio.

### Rototiller

`rototiller` · Terra · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Revolve o chão: todo Pokémon Grass no chão (de qualquer lado) ganha +1 de Ataque e +1 de At. Esp.

### Sand Attack

`sand_attack` · Terra · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 3 m de alcance, 40° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 3 m, 40°, 0,6 s]
- **Energia:** custo 28 · cooldown 17 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Baixa Precisão do alvo em 1 estágio.
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Sand Tomb

`sand_tomb` · Terra · Físico · poder 35 · precisão 85% · PP oficial 15

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 2,2 m de raio (alcance 7 m) que dura 4 s e bate a cada 0,5 s em quem estiver dentro. [alcance 7 m, raio 2,2 m, 4 s]
- **Energia:** custo 21 · cooldown 14,2 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 35), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,6 s (parado dentro da área).

### Sandsear Storm

`sandsear_storm` · Terra · Especial · poder 100 · precisão 80% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2,8 m, preparo 0,8 s]
- **Energia:** custo 37 · cooldown 11,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Tempestade de areia quente numa área larga; 20% de queimar.
  - 20% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Scorching Sands

`scorching_sands` · Terra · Especial · poder 70 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Queimadura no alvo. Queimadura: 1/16 do HP por rodada e o dano físico dele cai à metade; Fogo é imune.

### Shore Up

`shore_up` · Terra · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura metade do HP máximo (2/3 na tempestade de areia).

### Spikes

`spikes` · Terra · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Espinhos no chão sob cada adversário (duram 20 s): 1/8 do HP de quem pisa e não voa.

### Stomping Tantrum

`stomping_tantrum` · Terra · Físico · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 2,2 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). O usuário agacha, salta e bate no chão; o dano sai no pouso. [raio 2,2 m, preparo 0,35 s]
- **Energia:** custo 31 · cooldown 7,6 s
- **Aprendem:** 33 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o golpe anterior do usuário falhou (errou, foi bloqueado ou sem efeito).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

<a id="tipo-flying"></a>

## Voador (23)

### Acrobatics

`acrobatics` · Voador · Físico · poder 55 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 19 m/s]
- **Energia:** custo 26 · cooldown 4,2 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o usuário não tem item do treinador.

### Aerial Ace

`aerial_ace` · Voador · Físico · poder 60 · precisão nunca erra · PP oficial 20

- **Entrega:** `dash` (Investida). Teleporte: o Pokémon some e reaparece em cima do alvo (alcance 7 m). Só sai no chão (no ar espera pousar). [alcance 7 m, 14 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Some e reaparece em cima do alvo (nunca erra no oficial).

### Aeroblast

`aeroblast` · Voador · Especial · poder 100 · precisão 95% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 0,9 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 14 m, largura 0,9 m, preparo 0,5 s]
- **Energia:** custo 37 · cooldown 18,9 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de vento com aviso no chão; crítico mais provável (+1).
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Air Cutter

`air_cutter` · Voador · Especial · poder 60 · precisão 95% · PP oficial 25

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 16 m/s; dá para desviar. Sai uma leva de 3 em leque de 40°. [alcance 10 m, 16 m/s]
- **Energia:** custo 27 · cooldown 2,5 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso (o visual solta 3): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Air Slash

`air_slash` · Voador · Especial · poder 75 · precisão 95% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 31 · cooldown 4,4 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Bleakwind Storm

`bleakwind_storm` · Voador · Especial · poder 100 · precisão 80% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2,8 m, preparo 0,8 s]
- **Energia:** custo 37 · cooldown 11,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Tempestade de vento gelado numa área larga marcada no chão; 30% de baixar a Velocidade. Vale como golpe de vento (empurra quem é leve) e, na chuva, nunca erra.
  - 30% de chance: baixa Speed do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Bounce

`bounce` · Voador · Físico · poder 85 · precisão 85% · PP oficial 5

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (1,1 s no ar, 4,5 m de altura) e cai em cima do alvo (alcance 7 m); fica fora de alcance lá no alto. Só sai no chão (no ar espera pousar). [alcance 7 m, 10 m/s]
- **Energia:** custo 33 · cooldown 14,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Salta alto (fora de alcance no ar, 1,1 s) e cai sobre o alvo. Só Gust e Twister (dobro), Thunder, Hurricane, Sky Uppercut e Smack Down o alcançam lá em cima.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Brave Bird

`brave_bird` · Voador · Físico · poder 120 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 20 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 20 m/s]
- **Energia:** custo 42 · cooldown 6,8 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 33% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Chatter

`chatter` · Voador · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. [alcance 11 m, 15 m/s]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Notas musicais que voam em linha reta e confundem o alvo (100%). Golpe de som.
  - Sempre causa Confusão no alvo (depois do dano). Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Defog

`defog` · Voador · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Baixa a evasão do alvo e limpa o campo: telas do adversário, armadilhas (Spikes, Stealth Rock, Toxic Spikes) e terrenos.

### Drill Peck

`drill_peck` · Voador · Físico · poder 80 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 5 m, 14 m/s) e bate no contato. [alcance 5 m, 14 m/s]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Dual Wingbeat

`dual_wingbeat` · Voador · Físico · poder 40 x 2 · precisão 90% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 2 golpes no cone (1,9 m, 90°), um a cada 0,2 s. [alcance 1,9 m, 90°]
- **Energia:** custo 32 · cooldown 6,3 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (40).

### Feather Dance

`feather_dance` · Voador · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Ataque do adversário mais perto cai em 2 estágios, alcance 6 m.

### Fly

`fly` · Voador · Físico · poder 90 · precisão 95% · PP oficial 15

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (1,2 s no ar, 5 m de altura) e cai em cima do alvo (alcance 7 m); fica fora de alcance lá no alto. Só sai no chão (no ar espera pousar). [alcance 7 m, 10 m/s]
- **Energia:** custo 35 · cooldown 5,2 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Salta alto (fica fora de alcance no ar, 1,2 s) e cai sobre o alvo. Só Gust e Twister (dobro), Thunder, Hurricane, Sky Uppercut e Smack Down o alcançam lá em cima.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Gust

`gust` · Voador · Especial · poder 40 · precisão 100% · PP oficial 35

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 50° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 50°, 0,6 s]
- **Energia:** custo 22 · cooldown 3,3 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Acerta quem está no alto (Fly/Bounce) em dobro.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Hurricane

`hurricane` · Voador · Especial · poder 110 · precisão 70% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,8 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,8 s]
- **Energia:** custo 40 · cooldown 12,4 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Na chuva nunca erra (oficial). Atinge quem está no alto (Fly/Bounce).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 30% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.
  - Precisão oficial 70%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Oblivion Wing

`oblivion_wing` · Voador · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 11 m a 15 m/s; dá para desviar. [alcance 11 m, 15 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Projétil teleguiado fraco (a curva deixa desviar) que devolve 75% do dano em HP.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 75% do dano causado.

### Peck

`peck` · Voador · Físico · poder 35 · precisão 100% · PP oficial 35

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 2,5 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 2,5 m, 13 m/s]
- **Energia:** custo 21 · cooldown 1,8 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 35), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Pluck

`pluck` · Voador · Físico · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 2,8 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 2,8 m, 13 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se houver uma frutinha no chão perto do alvo, o usuário a come (cura 10% do HP) e libera o Belch.

### Roost

`roost` · Voador · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Cura 50% do HP máximo e, se for Voador, perde o tipo Voador até o fim da rodada (e desce ao chão).

### Sky Attack

`sky_attack` · Voador · Físico · poder 140 · precisão 90% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 9 m, 21 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 9 m, preparo 1 s, 21 m/s]
- **Energia:** custo 47 · cooldown 28,1 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,4 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Tailwind

`tailwind` · Voador · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Vento a favor por 4 rodadas: Speed x2 para o lado do usuário (decide a ordem da fila).

### Wing Attack

`wing_attack` · Voador · Físico · poder 60 · precisão 100% · PP oficial 35

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3 m, 13 m/s]
- **Energia:** custo 27 · cooldown 1,8 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

<a id="tipo-psychic"></a>

## Psíquico (56)

### Agility

`agility` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 50 espécie(s) do jogo
- **Adaptação:**
  - Speed do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Ally Switch

`ally_switch` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 22,5 s · prioridade +2
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - O usuário e o parceiro trocam de lugar. Sem parceiro, falha.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Amnesia

`amnesia` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 26 espécie(s) do jogo
- **Adaptação:**
  - Def. Esp. do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Calm Mind

`calm_mind` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: At. Esp. +1, Def. Esp. +1.

### Confusion

`confusion` · Psíquico · Especial · poder 50 · precisão 100% · PP oficial 25

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,4 m de raio sobre ele (alcance 8 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 8 m, raio 1,4 m, preparo 0,5 s]
- **Energia:** custo 25 · cooldown 3,8 s
- **Aprendem:** 16 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Cosmic Power

`cosmic_power` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Defesa +1, Def. Esp. +1.

### Dream Eater

`dream_eater` · Psíquico · Especial · poder 100 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 9 m a 11 m/s; dá para desviar. [alcance 9 m, 11 m/s]
- **Energia:** custo 37 · cooldown 5,7 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só sai com o alvo dormindo; o usuário recupera metade do dano causado.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Expanding Force

`expanding_force` · Psíquico · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 1,8 m, preparo 0,55 s]
- **Energia:** custo 32 · cooldown 8,6 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Extrasensory

`extrasensory` · Psíquico · Especial · poder 80 · precisão 100% · PP oficial 20

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,4 m de raio sobre ele (alcance 8 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 8 m, raio 1,4 m, preparo 0,5 s]
- **Energia:** custo 32 · cooldown 4,9 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Future Sight

`future_sight` · Psíquico · Especial · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,4 m de raio sobre ele (alcance 10 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 10 m, raio 1,4 m, preparo 0,7 s]
- **Energia:** custo 42 · cooldown 13 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Avisa agora e cai no fim da segunda rodada seguinte, na área do alvo da hora. Só cai se quem usou ainda está vivo.

### Gravity

`gravity` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Gravidade por 5 rodadas: ninguém pula, Voadores e levitando caem, golpes de Terra acertam Voador, precisão x5/3.

### Guard Split

`guard_split` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Os dois dividem a média dos atributos (Ataque/At. Esp. ou Defesa/Def. Esp.).

### Guard Swap

`guard_swap` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Troca as mudanças de estágio de Defesa/Def. Esp. (ou Ataque/At. Esp.) com o alvo.

### Heal Pulse

`heal_pulse` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Cura 1/2 do HP máximo do parceiro (do próprio usuário se estiver sozinho).

### Healing Wish

`healing_wish` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - O usuário desmaia; quem entrar no lugar dele volta com HP cheio e sem status. Só com reserva no banco.

### Hyperspace Hole

`hyperspace_hole` · Psíquico · Especial · poder 80 · precisão nunca erra · PP oficial 5

- **Entrega:** `dash` (Investida). Teleporte: o Pokémon some e reaparece em cima do alvo (alcance 7 m). Só sai no chão (no ar espera pousar). [alcance 7 m, 16 m/s]
- **Energia:** custo 32 · cooldown 14,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Quebra o Protect/Quick Guard do alvo (a proteção cai) e bate normalmente.
  - O usuário some num buraco e reaparece colado no alvo; nunca erra e atravessa o Protect (derruba a proteção do alvo).

### Hypnosis

`hypnosis` · Psíquico · Status · poder — · precisão 60% · PP oficial 20

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,6 m de raio sobre ele (alcance 8 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 8 m, raio 1,6 m, preparo 0,6 s]
- **Energia:** custo 28 · cooldown 13,9 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Causa Sono no alvo se acertar. Sono: não age por 1 a 3 rodadas; golpe recebido não acorda.

### Imprison

`imprison` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Os adversários não podem usar os golpes que o usuário também conhece.

### Kinesis

`kinesis` · Psíquico · Status · poder — · precisão 80% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Baixa Precisão do alvo em 1 estágio.

### Light Screen

`light_screen` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 30

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 42 espécie(s) do jogo
- **Adaptação:**
  - Light Screen por 5 rodadas: o lado do usuário leva 0,5x de golpes especiais (2/3 na dupla). Crítico ignora.

### Lumina Crash

`lumina_crash` · Psíquico · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,7 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,7 m, preparo 0,5 s]
- **Energia:** custo 32 · cooldown 8,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Luz que explode na área do alvo e derruba 2 estágios da Def. Esp. dele (100%).
  - Sempre baixa Def. Esp. do alvo em 2 estágios.

### Luster Purge

`luster_purge` · Psíquico · Especial · poder 95 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,7 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,7 m, preparo 0,5 s]
- **Energia:** custo 36 · cooldown 18 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Explosão de luz no alvo; 50% de baixar a Def. Esp. em 1.
  - 50% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Magic Coat

`magic_coat` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 22,5 s · prioridade +4
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Janela curta em que golpes de status do inimigo voltam contra quem os lançou.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Magic Powder

`magic_powder` · Psíquico · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Pó mágico: o alvo vira Psychic (puro). Golpe de pó: não pega Grass nem quem tem Overcoat.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.

### Magic Room

`magic_room` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Campo por alguns turnos: itens de treinador ficam sem efeito para todos.

### Mirror Coat

`mirror_coat` · Psíquico · Especial · poder variável · precisão 100% · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 30 · cooldown 3,1 s · prioridade -5
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Postura de 1 s parado (prioridade -5): o primeiro golpe especial recebido nela volta com o dobro do dano para quem bateu.
  - Prioridade -5: na fila da rodada sai depois dos normais; prepara 0,5 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Mist Ball

`mist_ball` · Psíquico · Especial · poder 95 · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 36 · cooldown 16,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola de névoa psíquica; 50% de baixar o At. Esp. do alvo.
  - 50% de chance: baixa At. Esp. do alvo em 1 estágio.

### Mystical Power

`mystical_power` · Psíquico · Especial · poder 70 · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola mística; ao acertar, o maior dos atributos do usuário (Ataque, Defesa, At. Esp., Def. Esp., Velocidade) sobe 1.

### Photon Geyser

`photon_geyser` · Psíquico · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 10 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 10 m, raio 1,8 m, preparo 0,7 s]
- **Energia:** custo 37 · cooldown 19,6 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Pilar de luz no alvo. Se o Ataque do usuário for maior que o At. Esp., o golpe usa o Ataque e a Defesa do alvo (vira físico).

### Power Split

`power_split` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Os dois dividem a média dos atributos (Ataque/At. Esp. ou Defesa/Def. Esp.).

### Power Swap

`power_swap` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Troca as mudanças de estágio de Defesa/Def. Esp. (ou Ataque/At. Esp.) com o alvo.

### Power Trick

`power_trick` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Troca o Ataque e a Defesa do usuário (usar de novo desfaz).

### Prismatic Laser

`prismatic_laser` · Psíquico · Especial · poder 160 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 15 m de alcance, 1 m de largura; avisa no chão por 0,7 s e dispara; o usuário fica parado 0,5 s depois. [alcance 15 m, largura 1 m, preparo 0,7 s]
- **Energia:** custo 50 · cooldown 17 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 160), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de 160 de poder; depois o usuário fica parado 1,6 s recarregando, como o Hyper Beam.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,6 s.

### Psybeam

`psybeam` · Psíquico · Especial · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `beam` (Raio). Raio em linha: 12 m de alcance, 0,7 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,6 s depois. [alcance 12 m, largura 0,7 m, preparo 0,5 s]
- **Energia:** custo 28 · cooldown 4,4 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Psychic

`psychic` · Psíquico · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,6 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 1,6 m, preparo 0,55 s]
- **Energia:** custo 35 · cooldown 9,5 s
- **Aprendem:** 35 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Psychic Fangs

`psychic_fangs` · Psíquico · Físico · poder 85 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 33 · cooldown 7,4 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se o golpe for eficaz, quebra o Reflect e o Light Screen do lado do alvo antes de acertar.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Psychic Noise

`psychic_noise` · Psíquico · Especial · poder 75 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,5 s]
- **Energia:** custo 31 · cooldown 8 s
- **Aprendem:** 15 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O alvo não pode se curar por 2 rodadas.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Psychic Terrain

`psychic_terrain` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Campo psíquico por 5 rodadas: Psíquico 1,3x para quem está no chão e golpes de prioridade não o alcançam. Um terreno tira o outro.

### Psycho Boost

`psycho_boost` · Psíquico · Especial · poder 140 · precisão 90% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 47 · cooldown 23,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Bola psíquica pesada de 140 de poder; depois o usuário perde 2 estágios de At. Esp.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -2.

### Psycho Cut

`psycho_cut` · Psíquico · Físico · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 16 m/s; dá para desviar. [alcance 11 m, 16 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Psycho Shift

`psycho_shift` · Psíquico · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Passa o status do usuário (queimadura, veneno, sono...) para o alvo, se o alvo estiver livre e o status pegar.

### Psyshock

`psyshock` · Psíquico · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,6 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 1,6 m, preparo 0,55 s]
- **Energia:** custo 32 · cooldown 8,6 s
- **Aprendem:** 22 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe especial calculado contra a Defesa física do alvo.

### Psystrike

`psystrike` · Psíquico · Especial · poder 100 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,3 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 1,3 m, preparo 0,45 s]
- **Energia:** custo 37 · cooldown 10,1 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe especial calculado contra a Defesa física do alvo.

### Reflect

`reflect` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 27 espécie(s) do jogo
- **Adaptação:**
  - Reflect por 5 rodadas: o lado do usuário leva 0,5x de golpes físicos (2/3 na dupla). Crítico ignora.

### Rest

`rest` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 146 espécie(s) do jogo
- **Adaptação:**
  - Cura tudo e dorme 2 rodadas (cura o status anterior). Falha com HP cheio ou já dormindo (e com Insomnia/Vital Spirit).

### Role Play

`role_play` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - O usuário copia a habilidade do alvo.

### Skill Swap

`skill_swap` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 27 espécie(s) do jogo
- **Adaptação:**
  - Troca a habilidade do usuário com a do alvo.

### Speed Swap

`speed_swap` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Troca a Speed com o alvo.

### Stored Power

`stored_power` · Psíquico · Especial · poder 20 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 14 m/s; dá para desviar. [alcance 10 m, 14 m/s]
- **Energia:** custo 17 · cooldown 6,3 s
- **Aprendem:** 21 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder = 20 + 20 por estágio de atributo positivo do usuário.

### Take Heart

`take_heart` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Cura o status do usuário e sobe At. Esp. e Def. Esp. em 1.

### Teleport

`teleport` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s · prioridade -6
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Some e reaparece num ponto livre da quadra, longe dos inimigos; solta de prisões.
  - Prioridade -6: na fila da rodada sai depois dos normais; prepara 0,6 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Trick

`trick` · Psíquico · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Troca o item do treinador entre o usuário e o alvo (falha se nenhum tiver item).

### Trick Room

`trick_room` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s · prioridade -7
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Prioridade -7: inverte a ordem da fila de Speed por 5 rodadas; usar de novo desliga.
  - Prioridade -7: na fila da rodada sai depois dos normais; prepara 0,7 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Twin Beam

`twin_beam` · Psíquico · Especial · poder 40 x 2 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 18 m/s; dá para desviar. Sai uma leva em leque de 12° (quantidade sorteada, ver multi-hit). [alcance 11 m, 18 m/s]
- **Energia:** custo 32 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dois feixes psíquicos em sequência (2 acertos de 40).
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (40).

### Wonder Room

`wonder_room` · Psíquico · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Defesa e Def. Esp. de todos trocadas por 5 rodadas; usar de novo desliga.

### Zen Headbutt

`zen_headbutt` · Psíquico · Físico · poder 80 · precisão 90% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 16 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 36 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

<a id="tipo-bug"></a>

## Inseto (24)

### Bug Bite

`bug_bite` · Inseto · Físico · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se houver uma frutinha no chão perto do alvo, o usuário a come (cura 10% do HP) e libera o Belch.

### Bug Buzz

`bug_buzz` · Inseto · Especial · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 70° de abertura, durante 0,9 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 70°, 0,9 s]
- **Energia:** custo 35 · cooldown 10,6 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Fell Stinger

`fell_stinger` · Inseto · Físico · poder 50 · precisão 100% · PP oficial 25

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 50°. [alcance 1,9 m, 50°]
- **Energia:** custo 25 · cooldown 2,5 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se o golpe nocautear o alvo, Ataque do usuário +3 estágios.

### First Impression

`first_impression` · Inseto · Físico · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 22 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, preparo 0,02 s, 22 m/s]
- **Energia:** custo 21 · cooldown 14,2 s · prioridade +2
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Só funciona como primeiro golpe do usuário em campo (o primeiro turno do oficial).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Fury Cutter

`fury_cutter` · Inseto · Físico · poder 40 · precisão 95% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 22 · cooldown 3,1 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Usos seguidos que acertam dobram o poder (até 2 dobras, x4); errar ou esperar demais zera a corrente.

### Infestation

`infestation` · Inseto · Especial · poder 20 · precisão 100% · PP oficial 20

- **Entrega:** `zone` (Zona no chão). Zona no chão: círculo de 1,6 m de raio (alcance 8 m) que dura 2,5 s e bate a cada 0,5 s em quem estiver dentro. [alcance 8 m, raio 1,6 m, 2,5 s]
- **Energia:** custo 17 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 20), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Enxame que cai no chão, prende o alvo por 4-5 rodadas (1/8 do HP por rodada) e não deixa fugir nem trocar.
  - Se causar dano, prende o alvo por 4-5 rodadas: 1/8 do HP no fim de cada rodada, sem fugir nem trocar (acaba se quem prendeu sair; Rapid Spin solta).
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Prende o alvo no lugar por 0,6 s (parado dentro da área).

### Leech Life

`leech_life` · Inseto · Físico · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Orbe de dreno: teleguiado de curva suave (2), até 9 m a 16 m/s; dá para desviar. [alcance 9 m, 16 m/s]
- **Energia:** custo 32 · cooldown 7 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 50% do dano causado.

### Lunge

`lunge` · Inseto · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 17 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Ataque do alvo em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Megahorn

`megahorn` · Inseto · Físico · poder 120 · precisão 85% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 5 m, 14 m/s) e bate no contato. [alcance 5 m, 14 m/s]
- **Energia:** custo 42 · cooldown 10,2 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,8 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Pin Missile

`pin_missile` · Inseto · Físico · poder 25 x 2-5 · precisão 95% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 14 m/s; dá para desviar. Sai uma leva em leque de 16° (quantidade sorteada, ver multi-hit). [alcance 10 m, 14 m/s]
- **Energia:** custo 31 · cooldown 3,1 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os projéteis sorteados, todos no mesmo alvo.

### Pollen Puff

`pollen_puff` · Inseto · Especial · poder 90 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 1,6 m): até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 35 · cooldown 5,2 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Pounce

`pounce` · Inseto · Físico · poder 50 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, 16 m/s]
- **Energia:** custo 25 · cooldown 3,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Speed do alvo em 1 estágio.

### Quiver Dance

`quiver_dance` · Inseto · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: At. Esp. +1, Def. Esp. +1, Speed +1.

### Rage Powder

`rage_powder` · Inseto · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 16,9 s · prioridade +2
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Até o fim da rodada, os golpes de alvo único dos adversários passam a mirar o usuário. Pó: não funciona contra Planta.
  - Golpe de pó: não afeta Planta nem quem tem Overcoat.
  - Prioridade +2: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Signal Beam

`signal_beam` · Inseto · Especial · poder 75 · precisão 100% · PP oficial 15

- **Entrega:** `beam` (Raio). Raio em linha: 12 m de alcance, 0,7 m de largura; avisa no chão por 0,4 s e dispara; o usuário fica parado 0,5 s depois. [alcance 12 m, largura 0,7 m, preparo 0,4 s]
- **Energia:** custo 31 · cooldown 5,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de luz fino; 10% de confundir.
  - 10% de chance de causar Confusão no alvo. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Silk Trap

`silk_trap` · Inseto · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +4
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Protege como o Protect (prioridade +4, o turno todo). Quem encosta com golpe de contato perde 1 de Velocidade.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Skitter Smack

`skitter_smack` · Inseto · Físico · poder 70 · precisão 90% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4,5 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4,5 m, 17 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa At. Esp. do alvo em 1 estágio.

### Sticky Web

`sticky_web` · Inseto · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Teia no chão do lado inimigo: em volta do adversário nascem até 3 teias; quem pisar (no chão, que não seja Inseto) fica preso 1 s e perde 1 de Velocidade. Sem o chão vivo (VGC/campo plano), baixa a Velocidade dele direto.

### String Shot

`string_shot` · Inseto · Status · poder — · precisão 95% · PP oficial 40

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Baixa Speed do alvo em 2 estágios.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Struggle Bug

`struggle_bug` · Inseto · Especial · poder 50 · precisão 100% · PP oficial 20

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 70° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 70°, 0,6 s]
- **Energia:** custo 25 · cooldown 4,6 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Sempre baixa At. Esp. do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Tail Glow

`tail_glow` · Inseto · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Sobe o At. Esp. do usuário em 3 estágios.

### Twineedle

`twineedle` · Inseto · Físico · poder 25 x 2 · precisão 100% · PP oficial 20

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 2 golpes no cone (1,9 m, 55°), um a cada 0,2 s. [alcance 1,9 m, 55°]
- **Energia:** custo 25 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (25).
  - 20% de chance de causar Veneno no alvo. Veneno: 1/8 do HP por rodada; Veneno e Aço são imunes.

### U-turn

`u_turn` · Inseto · Físico · poder 70 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 19 m/s]
- **Energia:** custo 30 · cooldown 3,1 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de bater, o usuário troca de lugar com o próximo Pokémon do banco (sai 0,35 s depois). Sem reserva, só bate.

### X-Scissor

`x_scissor` · Inseto · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 100°. [alcance 2 m, 100°]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

<a id="tipo-rock"></a>

## Pedra (16)

### Ancient Power

`ancient_power` · Pedra · Especial · poder 60 · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 27 · cooldown 12,5 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance de subir Ataque, Defesa, At. Esp., Def. Esp. e Speed do usuário em +1 (uma vez por uso).

### Head Smash

`head_smash` · Pedra · Físico · poder 150 · precisão 80% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 19 m/s]
- **Energia:** custo 50 · cooldown 25 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Recuo: o usuário perde 50% do dano causado (Rock Head anula).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,7 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Meteor Beam

`meteor_beam` · Pedra · Especial · poder 120 · precisão 90% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 1 m de largura; avisa no chão por 1,1 s e dispara; o usuário fica parado 0,6 s depois. [alcance 14 m, largura 1 m, preparo 1,1 s]
- **Energia:** custo 42 · cooldown 14,6 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Ao começar a usar, muda os atributos do usuário: At. Esp. +1 (o turno de carga do oficial).

### Power Gem

`power_gem` · Pedra · Especial · poder 80 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 32 · cooldown 3,5 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Rock Blast

`rock_blast` · Pedra · Físico · poder 25 x 2-5 · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. Sai uma leva em leque de 8° (quantidade sorteada, ver multi-hit). [alcance 11 m, 15 m/s]
- **Energia:** custo 31 · cooldown 6,3 s
- **Aprendem:** 19 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os projéteis sorteados, todos no mesmo alvo.

### Rock Polish

`rock_polish` · Pedra · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Speed do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Rock Slide

`rock_slide` · Pedra · Físico · poder 75 · precisão 90% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,4 m de raio sobre ele (alcance 9 m) e cai depois de 0,5 s; quem sair da marca escapa. [alcance 9 m, raio 2,4 m, preparo 0,5 s]
- **Energia:** custo 31 · cooldown 8 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Rock Throw

`rock_throw` · Pedra · Físico · poder 50 · precisão 90% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 9 m/s; dá para desviar. [alcance 9 m, 9 m/s]
- **Energia:** custo 25 · cooldown 4,2 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Rock Tomb

`rock_tomb` · Pedra · Físico · poder 60 · precisão 95% · PP oficial 15

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 9 m, raio 1,8 m, preparo 0,7 s]
- **Energia:** custo 27 · cooldown 5,9 s
- **Aprendem:** 46 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Speed do alvo em 1 estágio.
  - Prende o alvo no lugar por 2 s (parado dentro da área).

### Rollout

`rollout` · Pedra · Físico · poder 30 · precisão 90% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6 m, 13 m/s) e bate no contato. [alcance 6 m, 13 m/s]
- **Energia:** custo 20 · cooldown 3,1 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Usos seguidos que acertam dobram o poder (até 4 dobras, x16); errar ou esperar demais zera a corrente. Enrolado com Defense Curl, dobra de novo.

### Sandstorm

`sandstorm` · Pedra · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 38 espécie(s) do jogo
- **Adaptação:**
  - Tempestade de areia por 5 rodadas: 1/16 do HP por rodada em quem não é Pedra, Terra ou Aço; Def. Esp. dos de Pedra +50%.

### Smack Down

`smack_down` · Pedra · Físico · poder 50 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 16 m/s; dá para desviar. [alcance 11 m, 16 m/s]
- **Energia:** custo 25 · cooldown 4,2 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alcança quem está no alto (Fly/Bounce).

### Stealth Rock

`stealth_rock` · Pedra · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 27 espécie(s) do jogo
- **Adaptação:**
  - Pedras flutuando em volta de cada adversário (20 s): 1/8 do HP x eficácia de Pedra em quem se aproxima, mesmo voando.

### Stone Edge

`stone_edge` · Pedra · Físico · poder 100 · precisão 80% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 2 m, preparo 0,6 s]
- **Energia:** custo 37 · cooldown 19,3 s
- **Aprendem:** 28 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Tar Shot

`tar_shot` · Pedra · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O alvo perde 1 de Velocidade e fica coberto de piche: golpes de Fire contra ele saem com o dobro do poder até ele sair de campo.
  - Baixa Speed do alvo em 1 estágio.

### Wide Guard

`wide_guard` · Pedra · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +3
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Até o fim da rodada, o lado do usuário não é atingido por golpes de vários alvos.
  - Prioridade +3: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

<a id="tipo-ghost"></a>

## Fantasma (17)

### Astonish

`astonish` · Fantasma · Físico · poder 30 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,8 m à frente, num arco de 80°. [alcance 1,8 m, 80°]
- **Energia:** custo 20 · cooldown 4,2 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Confuse Ray

`confuse_ray` · Fantasma · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 11 m/s; dá para desviar. [alcance 9 m, 11 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Causa Confusão no alvo se acertar. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Curse

`curse` · Fantasma · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 43 espécie(s) do jogo
- **Adaptação:**
  - Fantasma: gasta metade do HP e amaldiçoa o adversário (perde 1/4 do HP a cada rodada até o Curse sair de campo). Outros tipos: Ataque +1, Defesa +1, Speed -1.

### Destiny Bond

`destiny_bond` · Fantasma · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Se o usuário for nocauteado pelo próximo golpe do alvo, o atacante cai junto. Vale até o usuário usar outro golpe.

### Hex

`hex` · Fantasma · Especial · poder 65 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 28 · cooldown 6,3 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo tem algum status principal.

### Lick

`lick` · Fantasma · Físico · poder 30 · precisão 100% · PP oficial 30

- **Entrega:** `whip` (Chicote). Chicote: 1 ponta(s) varrem uma linha de até 3,6 m e acertam o primeiro que tocar. [alcance 3,6 m]
- **Energia:** custo 20 · cooldown 2,1 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 30), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Moongeist Beam

`moongeist_beam` · Fantasma · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 14 m de alcance, 0,9 m de largura; avisa no chão por 0,6 s e dispara; o usuário fica parado 0,5 s depois. [alcance 14 m, largura 0,9 m, preparo 0,55 s]
- **Energia:** custo 37 · cooldown 19,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio fantasma com aviso no chão. A parte de ignorar a habilidade do alvo ficou simplificada (sem efeito extra).

### Night Shade

`night_shade` · Fantasma · Especial · poder variável · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 12 m/s; dá para desviar. [alcance 11 m, 12 m/s]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo igual ao nível do usuário (Seismic Toss / Night Shade). Só o ritmo x0,75 vai por cima.

### Phantom Force

`phantom_force` · Fantasma · Físico · poder 90 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Teleporte: o Pokémon some e reaparece em cima do alvo (alcance 7 m). Só sai no chão (no ar espera pousar). [alcance 7 m, preparo 0,25 s, 14 m/s]
- **Energia:** custo 35 · cooldown 8,6 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Ignora Protect e Substitute do alvo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Poltergeist

`poltergeist` · Fantasma · Físico · poder 110 · precisão 90% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil lançado em arco (altura 2,6 m): até 10 m a 13 m/s; dá para desviar. [alcance 10 m, 13 m/s]
- **Energia:** custo 40 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Arremessa o item do alvo; sem item, usa um objeto do cenário próximo; sem nenhum, falha.

### Rage Fist

`rage_fist` · Fantasma · Físico · poder 50 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 25 · cooldown 6,3 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder +50 por vez que o usuário levou golpe na luta, até 350.

### Shadow Ball

`shadow_ball` · Fantasma · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 42 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Shadow Claw

`shadow_claw` · Fantasma · Físico · poder 70 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,1 m à frente, num arco de 90°. [alcance 2,1 m, 90°]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Shadow Punch

`shadow_punch` · Fantasma · Físico · poder 60 · precisão nunca erra · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 70°. [alcance 1,9 m, 70°]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Shadow Sneak

`shadow_sneak` · Fantasma · Físico · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `dash` (Investida). Teleporte: o Pokémon some e reaparece em cima do alvo (alcance 6 m). Só sai no chão (no ar espera pousar). [alcance 6 m, 14 m/s]
- **Energia:** custo 13 · cooldown 3,8 s · prioridade +1
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Some e reaparece em cima do alvo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Spite

`spite` · Fantasma · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Corta o PP do último golpe do alvo (no modo de energia, tira energia).

### Trick-or-Treat

`trick_or_treat` · Fantasma · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Acrescenta o tipo Ghost ao alvo.

<a id="tipo-dragon"></a>

## Dragão (21)

### Breaking Swipe

`breaking_swipe` · Dragão · Físico · poder 60 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,6 m à frente, num arco de 150°. [alcance 2,6 m, 150°]
- **Energia:** custo 27 · cooldown 4,2 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Sempre baixa Ataque do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Clanging Scales

`clanging_scales` · Dragão · Especial · poder 110 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,5 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,45 s]
- **Energia:** custo 40 · cooldown 20,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 110), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Onda de som em volta do usuário que acerta todos os adversários; depois o usuário perde 1 de Defesa. Golpe de som.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Defesa -1.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Core Enforcer

`core_enforcer` · Dragão · Especial · poder 100 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 1,4 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 1,4 m, preparo 0,45 s]
- **Energia:** custo 37 · cooldown 10,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio largo. Se o alvo já agiu há pouco (nos últimos 3 s, o 'já se moveu neste turno' do oficial), a habilidade dele é anulada.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Draco Meteor

`draco_meteor` · Dragão · Especial · poder 130 · precisão 90% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 10 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 10 m, raio 1,8 m, preparo 0,8 s]
- **Energia:** custo 45 · cooldown 25,4 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -2.

### Dragon Breath

`dragon_breath` · Dragão · Especial · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 16 m/s; dá para desviar. [alcance 12 m, 16 m/s]
- **Energia:** custo 27 · cooldown 3,1 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Paralisia no alvo. Paralisia: Speed x0,5 e 20% de chance de o golpe falhar; Elétrico é imune.

### Dragon Cheer

`dragon_cheer` · Dragão · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - O parceiro ganha +1 de crítico (+2 se for Dragão). Sem parceiro, falha.

### Dragon Claw

`dragon_claw` · Dragão · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 100°. [alcance 2,2 m, 100°]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Dragon Dance

`dragon_dance` · Dragão · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, Speed +1.

### Dragon Energy

`dragon_energy` · Dragão · Especial · poder 150 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 5 m, aviso de 0,6 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 5 m, preparo 0,6 s]
- **Energia:** custo 50 · cooldown 28 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder proporcional ao HP atual do usuário (poder x HP atual / HP máximo, mínimo 1).
  - Onda de energia ao redor; o poder cai junto com o HP do usuário (150 com HP cheio), igual ao Water Spout.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Dragon Pulse

`dragon_pulse` · Dragão · Especial · poder 85 · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 33 · cooldown 7,4 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Dragon Rage

`dragon_rage` · Dragão · Especial · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 16 m/s; dá para desviar. [alcance 12 m, 16 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo de 40 HP (não usa a fórmula; imunidade de tipo ainda vale). Só o ritmo x0,75 do jogo vai por cima.

### Dragon Rush

`dragon_rush` · Dragão · Físico · poder 100 · precisão 75% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 8 m, 19 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 8 m, 19 m/s]
- **Energia:** custo 37 · cooldown 8,6 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Dragon Tail

`dragon_tail` · Dragão · Físico · poder 60 · precisão 90% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 110°. [alcance 2,2 m, 110°]
- **Energia:** custo 27 · cooldown 6,3 s · prioridade -6
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - No oficial força a troca; aqui o alvo é arremessado 4 m para longe depois do dano.
  - Prioridade -6: na fila da rodada sai depois dos normais; prepara 0,6 s mais devagar (0,1 s por nível) e segura o GCD um pouco mais.

### Dual Chop

`dual_chop` · Dragão · Físico · poder 40 x 2 · precisão 90% · PP oficial 15

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: 2 golpes no cone (2 m, 90°), um a cada 0,2 s. [alcance 2 m, 90°]
- **Energia:** custo 32 · cooldown 4,2 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (40).

### Dynamax Cannon

`dynamax_cannon` · Dragão · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 15 m de alcance, 1 m de largura; avisa no chão por 0,6 s e dispara; o usuário fica parado 0,7 s depois. [alcance 15 m, largura 1 m, preparo 0,6 s]
- **Energia:** custo 37 · cooldown 19,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio grosso de Dragão com aviso no chão. Sem Dynamax no jogo, o dano é o normal.

### Fickle Beam

`fickle_beam` · Dragão · Especial · poder 80 · precisão 100% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,7 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 0,7 m, preparo 0,5 s]
- **Energia:** custo 32 · cooldown 15,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio de Dragão. Ao sair, 30% de chance de uma segunda cabeça entrar e dobrar o poder (o aviso 'Poder dobrado!' aparece).

### Outrage

`outrage` · Dragão · Físico · poder 120 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 2,4 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 2,4 m, preparo 0,3 s]
- **Energia:** custo 42 · cooldown 11,4 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Depois que o golpe termina, o usuário fica confuso de cansaço (como o oficial, que repete 2-3 turnos e confunde ao fim).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Roar of Time

`roar_of_time` · Dragão · Especial · poder 150 · precisão 90% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 16 m de alcance, 1,1 m de largura; avisa no chão por 0,8 s e dispara; o usuário fica parado 1,2 s depois. [alcance 16 m, largura 1,1 m, preparo 0,8 s]
- **Energia:** custo 50 · cooldown 29 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 150), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio gigante de 150 de poder; depois o usuário fica parado 1,8 s recarregando.
  - Precisa recarregar: depois do golpe o usuário fica parado e vulnerável por 1,8 s.

### Scale Shot

`scale_shot` · Dragão · Físico · poder 25 x 2-5 · precisão 90% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 16 m/s; dá para desviar. Sai uma leva em leque de 8° (quantidade sorteada, ver multi-hit). [alcance 11 m, 16 m/s]
- **Energia:** custo 31 · cooldown 3,1 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 25), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Multi-hit oficial: sorteia 2 a 5 acertos por uso (35% / 35% / 15% / 15% para 2/3/4/5), cada um com o poder oficial (25); Skill Link sempre dá 5. O visual solta os projéteis sorteados, todos no mesmo alvo.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): Speed +1, Defesa -1.

### Spacial Rend

`spacial_rend` · Dragão · Especial · poder 100 · precisão 95% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 9 m) e cai depois de 0,6 s; quem sair da marca escapa. [alcance 9 m, raio 2 m, preparo 0,55 s]
- **Energia:** custo 37 · cooldown 19,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Rasgo no espaço na área do alvo; crítico mais provável (+1).
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Twister

`twister` · Dragão · Especial · poder 40 · precisão 100% · PP oficial 20

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,6 s]
- **Energia:** custo 22 · cooldown 4,6 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Acerta quem está no alto (Fly/Bounce) em dobro.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

<a id="tipo-dark"></a>

## Sombrio (32)

### Assurance

`assurance` · Sombrio · Físico · poder 60 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 27 · cooldown 6,3 s
- **Aprendem:** 17 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo levou dano nos últimos 1,5 s.

### Beat Up

`beat_up` · Sombrio · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `multi_arc` (Arco em sequência). Golpes de contato em sequência: um golpe por Pokémon saudável do time (cone de 1,9 m, 70°). [alcance 1,9 m, 70°]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Um golpe por Pokémon saudável do time, cada um com poder 5 + (Ataque base / 10).

### Bite

`bite` · Sombrio · Físico · poder 60 · precisão 100% · PP oficial 25

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,7 m à frente, num arco de 70°. [alcance 1,7 m, 70°]
- **Energia:** custo 27 · cooldown 2,5 s
- **Aprendem:** 24 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Brutal Swing

`brutal_swing` · Sombrio · Físico · poder 60 · precisão 100% · PP oficial 20

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3 m, preparo 0,3 s]
- **Energia:** custo 27 · cooldown 3,9 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Crunch

`crunch` · Sombrio · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 80°. [alcance 1,9 m, 80°]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance: baixa Defesa do alvo em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Dark Pulse

`dark_pulse` · Sombrio · Especial · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.

### Darkest Lariat

`darkest_lariat` · Sombrio · Físico · poder 85 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 2,4 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 2,4 m, preparo 0,3 s]
- **Energia:** custo 33 · cooldown 8,3 s
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Ignora as mudanças de Defesa e Def. Esp. do alvo.
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Fake Tears

`fake_tears` · Sombrio · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Def. Esp. do adversário mais perto cai em 2 estágios, alcance 6 m.

### Flatter

`flatter` · Sombrio · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 11 m/s; dá para desviar. [alcance 9 m, 11 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Além da confusão, sobe o At. Esp. do alvo (+1 estágio, como o Flatter).
  - Causa Confusão no alvo se acertar. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.

### Fling

`fling` · Sombrio · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 13 m/s; dá para desviar. [alcance 11 m, 13 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 60 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Arremessa o item do treinador do usuário (falha sem item) e o consome.

### Foul Play

`foul_play` · Sombrio · Físico · poder 95 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 36 · cooldown 5,5 s
- **Aprendem:** 22 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Usa o Ataque do alvo no lugar do Ataque do usuário.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,1 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Hone Claws

`hone_claws` · Sombrio · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Atributos do usuário: Ataque +1, Precisão +1.

### Knock Off

`knock_off` · Sombrio · Físico · poder 65 · precisão 100% · PP oficial 20

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 28 · cooldown 3,1 s
- **Aprendem:** 42 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 65), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x1,5 se o alvo tem item do treinador; se acertar, o alvo perde o item.

### Lash Out

`lash_out` · Sombrio · Físico · poder 75 · precisão 100% · PP oficial 5

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 31 · cooldown 13,3 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 75), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se algum atributo do usuário caiu nesta rodada.

### Memento

`memento` · Sombrio · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 12 m/s; dá para desviar. [alcance 9 m, 12 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - O usuário desmaia e derruba Ataque e At. Esp. do alvo em 2 estágios.

### Nasty Plot

`nasty_plot` · Sombrio · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 23 espécie(s) do jogo
- **Adaptação:**
  - At. Esp. do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Night Daze

`night_daze` · Sombrio · Especial · poder 85 · precisão 95% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 3,5 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 3,5 m, preparo 0,4 s]
- **Energia:** custo 33 · cooldown 8,6 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 85), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Onda escura em volta do usuário; 40% de baixar a Precisão de quem pegar.
  - 40% de chance: baixa Precisão do alvo em 1 estágio.
  - Precisão oficial 95%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Night Slash

`night_slash` · Sombrio · Físico · poder 70 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 30 · cooldown 4,2 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Alta chance de crítico (+1 no estágio: 1/8 em vez de 1/24).

### Obstruct

`obstruct` · Sombrio · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 17 · cooldown 33,8 s · prioridade +4
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Protege como o Protect (prioridade +4, o turno todo, uso seguido falha mais). Quem encosta com golpe de contato perde 2 estágios de Defesa.
  - Prioridade +4: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Parting Shot

`parting_shot` · Sombrio · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Ameaça de despedida: derruba Ataque e At. Esp. do alvo em 1 e o usuário troca com o próximo do banco.

### Payback

`payback` · Sombrio · Físico · poder 50 · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 90°. [alcance 2 m, 90°]
- **Energia:** custo 25 · cooldown 6,3 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder x2 se o alvo acertou o usuário nos últimos 1,5 s (o 'virou o jogo' do Revenge/Avalanche/Payback).

### Pursuit

`pursuit` · Sombrio · Físico · poder 40 · precisão 100% · PP oficial 20

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, 13 m/s]
- **Energia:** custo 22 · cooldown 3,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Quash

`quash` · Sombrio · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O alvo perde o ritmo: fica 1,6 s sem poder agir (o 'age por último' do oficial).

### Ruination

`ruination` · Sombrio · Especial · poder 1 · precisão 90% · PP oficial 10

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 1,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 1,8 m, preparo 0,8 s]
- **Energia:** custo 12 · cooldown 8,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo = metade do HP atual do alvo (mínimo 1). Só o ritmo x0,75 vai por cima.
  - Aplicação de ruína na área do alvo: tira metade do HP atual dele.

### Snarl

`snarl` · Sombrio · Especial · poder 55 · precisão 95% · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5,5 m de alcance, 70° de abertura, durante 0,6 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5,5 m, 70°, 0,6 s]
- **Energia:** custo 26 · cooldown 5,7 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 55), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Sempre baixa At. Esp. do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 95%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Sucker Punch

`sucker_punch` · Sombrio · Físico · poder 70 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 19 m/s) e bate no contato. [alcance 7 m, preparo 0,02 s, 19 m/s]
- **Energia:** custo 18 · cooldown 22,5 s · prioridade +1
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Switcheroo

`switcheroo` · Sombrio · Status · poder — · precisão 100% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 14 m/s; dá para desviar. [alcance 9 m, 14 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Troca o item do treinador entre o usuário e o alvo (falha se nenhum tiver item).
  - Fica fora da lista de Metronome/Copycat/Mimic (como o oficial).

### Taunt

`taunt` · Sombrio · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 41 espécie(s) do jogo
- **Adaptação:**
  - O alvo não pode usar golpes de status por 3 rodadas.

### Thief

`thief` · Sombrio · Físico · poder 60 · precisão 100% · PP oficial 25

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3,2 m, 14 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3,2 m, 14 m/s]
- **Energia:** custo 27 · cooldown 2,5 s
- **Aprendem:** 99 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 60), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, rouba o item do treinador do alvo (só se o usuário estiver sem item).
  - Fica fora da lista de Metronome/Copycat/Mimic (como o oficial).

### Throat Chop

`throat_chop` · Sombrio · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 80°. [alcance 2 m, 80°]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 27 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Se causar dano, o alvo não pode usar golpes de som por 2 rodadas.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Topsy-Turvy

`topsy_turvy` · Sombrio · Status · poder — · precisão nunca erra · PP oficial 20

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Inverte os estágios do alvo (+2 vira -2). Falha se ele não tem nenhum.

### Torment

`torment` · Sombrio · Status · poder — · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 13 m/s; dá para desviar. [alcance 9 m, 13 m/s]
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - O alvo não pode usar o mesmo golpe duas vezes seguidas (o golpe fica travado até ele usar outro).

<a id="tipo-steel"></a>

## Aço (20)

### Bullet Punch

`bullet_punch` · Aço · Físico · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 20 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, preparo 0,02 s, 20 m/s]
- **Energia:** custo 13 · cooldown 3,8 s · prioridade +1
- **Aprendem:** 1 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Doom Desire

`doom_desire` · Aço · Especial · poder 140 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2 m de raio sobre ele (alcance 10 m) e cai depois de 0,7 s; quem sair da marca escapa. [alcance 10 m, raio 2 m, preparo 0,7 s]
- **Energia:** custo 47 · cooldown 26,7 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Avisa agora e cai no fim da segunda rodada seguinte, na área do alvo da hora. Só cai se quem usou ainda está vivo.
  - Como Future Sight: o aviso cai no chão agora e o golpe de Aço bate no fim do 2º turno depois deste, no alvo de então.

### Flash Cannon

`flash_cannon` · Aço · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `beam` (Raio). Raio em linha: 12 m de alcance, 0,7 m de largura; avisa no chão por 0,5 s e dispara; o usuário fica parado 0,5 s depois. [alcance 12 m, largura 0,7 m, preparo 0,45 s]
- **Energia:** custo 32 · cooldown 8,3 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Def. Esp. do alvo em 1 estágio.

### Gyro Ball

`gyro_ball` · Aço · Físico · poder variável · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 16 m/s]
- **Energia:** custo 30 · cooldown 12,5 s
- **Aprendem:** 22 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder = 25 x Speed do alvo / Speed do usuário + 1 (máx. 150): quanto mais lento o usuário, mais forte.

### Hard Press

`hard_press` · Aço · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2 m à frente, num arco de 80°. [alcance 2 m, 80°]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder proporcional ao HP atual do alvo (mínimo 1).
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Heavy Slam

`heavy_slam` · Aço · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Salto: o Pokémon pula (0,5 s no ar, 2 m de altura) e cai em cima do alvo (alcance 3,2 m). Só sai no chão (no ar espera pousar). [alcance 3,2 m, 12 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 12 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Poder 40 a 120 pela razão de peso usuário/alvo (>=2x: 60, >=3x: 80, >=4x: 100, >=5x: 120). Salta e cai em cima do alvo.

### Iron Defense

`iron_defense` · Aço · Status · poder — · precisão nunca erra · PP oficial 15

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 12,5 s
- **Aprendem:** 25 espécie(s) do jogo
- **Adaptação:**
  - Defesa do usuário sobe em 2 estágios (multiplicador (2+n)/2, limite de -6 a +6).

### Iron Head

`iron_head` · Aço · Físico · poder 80 · precisão 100% · PP oficial 15

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 4 m, 15 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 4 m, 15 m/s]
- **Energia:** custo 32 · cooldown 4,7 s
- **Aprendem:** 18 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance de causar Hesitar no alvo. Hesitar: o alvo fica parado 0,5 s.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,6 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Iron Tail

`iron_tail` · Aço · Físico · poder 100 · precisão 75% · PP oficial 15

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,4 m à frente, num arco de 110°. [alcance 2,4 m, 110°]
- **Energia:** custo 37 · cooldown 5,7 s
- **Aprendem:** 22 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance: baixa Defesa do alvo em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 1,2 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Make It Rain

`make_it_rain` · Aço · Especial · poder 120 · precisão 100% · PP oficial 5

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 15 m/s; dá para desviar. Sai uma leva de 5 em leque de 60°. [alcance 11 m, 15 m/s]
- **Energia:** custo 42 · cooldown 20,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 120), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Rajada de moedas em leque (5 projéteis) que acerta todos os adversários; depois o usuário perde 1 de At. Esp.
  - Um acerto por alvo por uso (o visual solta 5): o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -1.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Metal Burst

`metal_burst` · Aço · Físico · poder variável · precisão 100% · PP oficial 10

- **Entrega:** `homing` (Teleguiado). Projétil teleguiado: faz curva atrás do alvo (curva 6), até 14 m a 20 m/s. Não erra. [alcance 14 m, 20 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder variável (ver abaixo)), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Devolve 1,5x o último dano recebido (janela de 2,5 s); falha se ninguém acertou.
  - Precisão oficial 100%: esta entrega (teleguiado) nunca erra, então a precisão não é rolada.

### Metal Claw

`metal_claw` · Aço · Físico · poder 50 · precisão 95% · PP oficial 35

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 1,9 m à frente, num arco de 90°. [alcance 1,9 m, 90°]
- **Energia:** custo 25 · cooldown 1,8 s
- **Aprendem:** 8 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: sobe Ataque do usuário em 1 estágio.

### Metal Sound

`metal_sound` · Aço · Status · poder — · precisão 85% · PP oficial 40

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 8 s
- **Aprendem:** 10 espécie(s) do jogo
- **Adaptação:**
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Def. Esp. do adversário mais perto cai em 2 estágios, alcance 6 m.

### Meteor Mash

`meteor_mash` · Aço · Físico · poder 90 · precisão 90% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 17 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 17 m/s]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 2 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 20% de chance: sobe Ataque do usuário em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Shift Gear

`shift_gear` · Aço · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Sobe o Ataque em 1 e a Velocidade em 2.

### Smart Strike

`smart_strike` · Aço · Físico · poder 70 · precisão nunca erra · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7 m, 18 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7 m, 18 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.

### Steel Beam

`steel_beam` · Aço · Especial · poder 140 · precisão 95% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,9 m de largura; avisa no chão por 0,7 s e dispara; o usuário fica parado 0,9 s depois. [alcance 13 m, largura 0,9 m, preparo 0,7 s]
- **Energia:** custo 47 · cooldown 26,7 s
- **Aprendem:** 3 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 140), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O usuário perde 50% do HP máximo ao atirar, acertando ou não.

### Steel Roller

`steel_roller` · Aço · Físico · poder 130 · precisão 100% · PP oficial 5

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 7,5 m, 15 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 7,5 m, preparo 0,4 s, 15 m/s]
- **Energia:** custo 45 · cooldown 23,6 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Aplaina o terreno de campo; só funciona com terreno ou morro/pico ao alcance.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 2,1 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Steel Wing

`steel_wing` · Aço · Físico · poder 70 · precisão 90% · PP oficial 25

- **Entrega:** `arc` (Arco (contato)). Golpe de contato em cone: acerta quem está até 2,2 m à frente, num arco de 110°. [alcance 2,2 m, 110°]
- **Energia:** custo 30 · cooldown 2,5 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 70), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: sobe Defesa do usuário em 1 estágio.

### Tachyon Cutter

`tachyon_cutter` · Aço · Especial · poder 50 x 2 · precisão nunca erra · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 22 m/s; dá para desviar. Sai uma leva em leque de 14° (quantidade sorteada, ver multi-hit). [alcance 11 m, 22 m/s]
- **Energia:** custo 37 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Duas lâminas rápidas em sequência (2 acertos de 50); não tem precisão, nunca erra.
  - Multi-hit oficial: 2 acertos por uso no mesmo alvo, cada um com o poder oficial (50).

<a id="tipo-fairy"></a>

## Fada (16)

### Alluring Voice

`alluring_voice` · Fada · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 60° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 60°, 0,5 s]
- **Energia:** custo 32 · cooldown 8,4 s
- **Aprendem:** 13 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Além do dano, aplica confusão só se o alvo subiu algum atributo na mesma rodada.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Precisão oficial 100%: esta entrega (jato) nunca erra, então a precisão não é rolada.

### Baby-Doll Eyes

`baby_doll_eyes` · Fada · Status · poder — · precisão 100% · PP oficial 30

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 17 · cooldown 14,4 s · prioridade +1
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Ataque do adversário mais perto cai em 1 estágio, alcance 6 m.
  - Prioridade +1: no modo VGC entra na frente da fila da rodada; em qualquer modo sai quase sem preparo (0,04 s) e com GCD 0,6x. No modo de energia custa 0,6x e o cooldown é 1,8x.

### Charm

`charm` · Fada · Status · poder — · precisão 100% · PP oficial 20

- **Entrega:** `debuff_aoe` (Efeito ao redor). Efeito ao redor: atinge quem estiver até 6 m do usuário (só o mais perto). Nunca erra. [raio 6 m]
- **Energia:** custo 28 · cooldown 9,4 s
- **Aprendem:** 37 espécie(s) do jogo
- **Adaptação:**
  - Ataque do adversário mais perto cai em 2 estágios, alcance 6 m.

### Dazzling Gleam

`dazzling_gleam` · Fada · Especial · poder 80 · precisão 100% · PP oficial 10

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,3 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,35 s]
- **Energia:** custo 32 · cooldown 8 s
- **Aprendem:** 20 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 80), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Disarming Voice

`disarming_voice` · Fada · Especial · poder 40 · precisão nunca erra · PP oficial 15

- **Entrega:** `stream` (Jato). Jato em cone: 5 m de alcance, 80° de abertura, durante 0,5 s (um pulso a cada 0,1 s); o usuário fica parado e trava no alvo. Não erra por precisão. [alcance 5 m, 80°, 0,5 s]
- **Energia:** custo 22 · cooldown 5,4 s
- **Aprendem:** 9 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Golpe de som: atravessa o Substitute e Throat Chop o bloqueia por 2 rodadas.
  - Um acerto por alvo por uso: o visual desenha o jato, a área ou os golpes seguidos, mas cada alvo leva dano e efeito uma vez só (no oficial não é multi-hit).
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Draining Kiss

`draining_kiss` · Fada · Especial · poder 50 · precisão 100% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 3 m, 13 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 3 m, 13 m/s]
- **Energia:** custo 25 · cooldown 6,3 s
- **Aprendem:** 11 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 50), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Dreno: orbe verde que, ao acertar, cura o usuário em 75% do dano causado.

### Fairy Wind

`fairy_wind` · Fada · Especial · poder 40 · precisão 100% · PP oficial 30

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 10 m a 16 m/s; dá para desviar. [alcance 10 m, 16 m/s]
- **Energia:** custo 22 · cooldown 2,1 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 40), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Rajada de vento rosa em linha reta; vale como golpe de vento (empurra quem é leve).

### Fleur Cannon

`fleur_cannon` · Fada · Especial · poder 130 · precisão 90% · PP oficial 5

- **Entrega:** `beam` (Raio). Raio em linha: 13 m de alcance, 0,9 m de largura; avisa no chão por 0,8 s e dispara; o usuário fica parado 0,5 s depois. [alcance 13 m, largura 0,9 m, preparo 0,75 s]
- **Energia:** custo 45 · cooldown 25,2 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 130), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Raio rosa de 130 de poder; o recuo baixa 2 estágios do At. Esp. do usuário.
  - Depois de acertar, muda os atributos do usuário (uma vez por uso): At. Esp. -2.

### Misty Explosion

`misty_explosion` · Fada · Especial · poder 100 · precisão 100% · PP oficial 5

- **Entrega:** `aoe_self` (Onda ao redor). Onda ao redor do usuário: raio 4,5 m, aviso de 0,4 s e depois bate em todo mundo dentro do raio. Não erra por precisão (pular ou sair da área desvia). [raio 4,5 m, preparo 0,4 s]
- **Energia:** custo 37 · cooldown 18,6 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - O usuário desmaia depois da explosão (0,3 s depois do impacto).
  - Golpe de vários alvos (todos os outros, inclusive o parceiro): acerta todos ao alcance, até o aliado; se um uso pega mais de um, dano x0,75 (spread).
  - Precisão oficial 100%: esta entrega (onda ao redor) nunca erra, então a precisão não é rolada.

### Misty Terrain

`misty_terrain` · Fada · Status · poder — · precisão nunca erra · PP oficial 10

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 6 espécie(s) do jogo
- **Adaptação:**
  - Campo de névoa por 5 rodadas: quem está no chão não sofre status nem confusão e Dragão bate 0,5x. Um terreno tira o outro.

### Moonblast

`moonblast` · Fada · Especial · poder 95 · precisão 100% · PP oficial 15

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 12 m a 13 m/s; dá para desviar. [alcance 12 m, 13 m/s]
- **Energia:** custo 36 · cooldown 5,5 s
- **Aprendem:** 5 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 95), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 30% de chance: baixa At. Esp. do alvo em 1 estágio.

### Moonlight

`moonlight` · Fada · Status · poder — · precisão nunca erra · PP oficial 5

- **Entrega:** `self_buff` (Efeito próprio). Efeito próprio: sem alvo, o efeito cai no usuário ou no campo. Nunca erra.
- **Energia:** custo 28 · cooldown 37,5 s
- **Aprendem:** 4 espécie(s) do jogo
- **Adaptação:**
  - Cura o usuário em 1/2 do HP máximo; 2/3 sob sol forte, 1/4 sob qualquer outro clima (chuva, areia, neve).

### Nature’s Madness

`natures_madness` · Fada · Especial · poder variável · precisão 90% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 11 m a 14 m/s; dá para desviar. [alcance 11 m, 14 m/s]
- **Energia:** custo 30 · cooldown 6,3 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano fixo = metade do HP atual do alvo (mínimo 1). Só o ritmo x0,75 vai por cima.
  - Projétil de fada que tira metade do HP atual do alvo (como Super Fang).

### Play Rough

`play_rough` · Fada · Físico · poder 90 · precisão 90% · PP oficial 10

- **Entrega:** `dash` (Investida). Investida: o Pokémon corre até o alvo (até 6,5 m, 16 m/s) e bate no contato. Só sai no chão (no ar espera pousar). [alcance 6,5 m, 16 m/s]
- **Energia:** custo 35 · cooldown 7,8 s
- **Aprendem:** 14 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, físico, poder 90), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - 10% de chance: baixa Ataque do alvo em 1 estágio.
  - Contato forte (poder >= 80): além do empurrão, arremessa o alvo 0,9 m; se ele bater na cerca, caixa ou pedra perde até 8% do HP.

### Springtide Storm

`springtide_storm` · Fada · Especial · poder 100 · precisão 80% · PP oficial 5

- **Entrega:** `aoe_target` (Área no alvo). Área no alvo: marca um círculo de 2,8 m de raio sobre ele (alcance 9 m) e cai depois de 0,8 s; quem sair da marca escapa. [alcance 9 m, raio 2,8 m, preparo 0,8 s]
- **Energia:** custo 37 · cooldown 19,9 s
- **Aprendem:** 0 espécie(s) do jogo
- **Adaptação:**
  - Dano pela fórmula oficial (Gen 5+, especial, poder 100), STAB, eficácia, crítico e sorteio de 85-100%, depois x0,75 do ritmo do jogo.
  - Tempestade de amor e ódio numa área larga; 30% de baixar o Ataque do alvo.
  - 30% de chance: baixa Ataque do alvo em 1 estágio.
  - Golpe de vários alvos (todos os adversários): acerta todos ao alcance; se um uso pega mais de um, dano x0,75 (spread).

### Sweet Kiss

`sweet_kiss` · Fada · Status · poder — · precisão 75% · PP oficial 10

- **Entrega:** `projectile` (Projétil). Projétil: voa em linha reta até 9 m a 10 m/s; dá para desviar. [alcance 9 m, 10 m/s]
- **Energia:** custo 28 · cooldown 18,8 s
- **Aprendem:** 7 espécie(s) do jogo
- **Adaptação:**
  - Causa Confusão no alvo se acertar. Confusão: 2 a 5 rodadas; 33% dos golpes saem em direção aleatória.
