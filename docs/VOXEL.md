# Voxel: cenários, grade de 1 m, água e clima

Direção de arte decidida em 2026-10-25/26 (conceito B, "Vila de pedra"): cenário em voxel 3D,
personagens e Pokémon em sprite 2D (2.5D), luz forte no próprio Godot (sem render de Blender).
Pallet Town é a única zona nesse estilo; da Rota 1 em diante a arte antiga (HGSS) continua igual.
O campo de treino do modo de energia também é voxel (quadra de 48 × 28 m com estádio).
Céu contínuo, clima do mundo e níveis gráficos valem para todas as zonas.

## 1. Malha (lattice) e grade

- **Voxel do mundo:** 0,25 m (`VoxelGrid.VS`). O voxel `(i, j, k)` cobre `[i, i+1) × [j, j+1) × [k, k+1)`
  vezes 0,25 m no espaço do modelo.
- **Voxel de detalhe:** 1/16 m (`VoxelMat.DETAIL`), só para enfeites pequenos (flores, pedrinhas,
  plantação, tufos), feitos com `VoxelMesher.colored` e espalhados com MultiMesh.
- **Tile (grade de 1 m):** o tile `(tx, tz)` é o quadrado centrado nas coordenadas inteiras do mundo,
  com bordas em ,5. Ele ocupa os voxels `4*tx-2 .. 4*tx+1`. `TileGrid.cell_of(p) = (round(x), round(z))`.
- **Chão:** o topo do chão andável fica em **y = 0** (voxels `j <= -1`). Personagens, NPCs, placas e
  itens continuam em y = 0. Relevo andável só com altura por tile (`TileGrid.heights`).
- **Costura com a Rota 1:** fica em z = -19,5, que já é borda de tile.
- **Construções ocupam tiles inteiros.** As paredes externas (2 voxels = 0,5 m) ficam por dentro do
  contorno, então o tile vizinho fica livre e o jogador encosta a 0,5 m da parede.
- **Coordenadas do mapa (JSON):** `[x, z]` com x e z inteiros para tudo que é andável ou bloqueia.

## 2. Núcleo (gfx/voxel/)

| Arquivo | O que faz |
|---|---|
| `voxel_grid.gd` (`VoxelGrid`) | Volume denso. Cada célula tem 4 bytes: cor sRGB + id de material (0 = ar). Tem também 1 byte de **parte** por célula. Funções: `put`, `fill`, `fill_m` (em metros), `ellipsoid`, `cylinder`, `blit`, `top_y`, `texture()` (textura 3D RGBA8), `tops_image()` (topo de cada coluna), `hash01` (variação por voxel, sem RNG de batalha). |
| `voxel_mesher.gd` (`VoxelMesher`) | `greedy(g)`: junta faces só pela solidez (a cor vem da textura 3D) e devolve `{parte: ArrayMesh}`. `colored(g, escala, pivô)`: modelos pequenos com cor e AO no vértice. Faces da frente em sentido horário. |
| `voxel_mat.gd` (`VoxelMat`) | Ids de material (nunca renumerar; novos vão no fim) e a tabela LUT 256×1 (rugosidade, classe de emissão, porosidade, flags). `material(g)`, `detail_material()`, `instances(g, prefixo, params_por_parte)`. |
| `voxel.gdshader` | Cor e material por voxel (`texelFetch` na textura 3D), AO por fragmento a partir da ocupação (regra 0fps), bisel nas quinas convexas, emissão noturna (janelas e lâmpadas) e chuva/poça/neve onde o céu alcança. Usa espaço do modelo, então mover ou escalar a instância não troca as cores. |
| `voxel_detail.gdshader` | Enfeites com cor no vértice: balanço no vento, neve e chuva (uniform `weather`; 0 nas algas debaixo d'água). |

- **Partes:** a parte 0 é cenário fixo. Qualquer outro id vira uma malha própria: telhado e paredes
  de cada casa (para sumir quando o jogador entrar), copa de árvore (balança) e assim por diante.
- **Faces escondidas:** uma face só some se a vizinha for sólida **e** for da mesma parte ou da parte 0.
  Assim, esconder uma parte nunca abre buraco no que fica.
- **Velocidade (GDScript, nuvem):** volume de 240×64×200 voxels → greedy em ~3 s e ~30 mil quads.
  Zonas grandes são **assadas** (pré-geradas) e as arenas são geradas na hora (são pequenas).
- **Testes:** `tests/gfx/test_voxel.gd`.
- **Print:** `tests/gfx/shot_voxel.gd` (veja §8).

## 3. Luz, céu e globais de shader

### Céu contínuo (`WorldTimeOfDay`, world/sky/time_of_day.gd)

- O relógio anda como no original (20×, `data/time.json`), e o visual segue o minuto de jogo pelo
  `SkyCycle` (`data/time_of_day.json`), sem saltos entre períodos:
  - **sol** num arco das 06:00 às 18:30 (até 52° de altura);
  - **lua** numa `DirectionalLight3D` própria, das 18:45 às 05:45. As duas nunca se sobrepõem, então
    a sombra troca de uma para a outra com energia zero;
  - chaves de cor das 00:00 às 22:30 que **modulam** o look da zona (12:30 é a identidade). Dentro de
    casa o visual fica parado nas 12:30.
- **NightFill:** uma terceira `DirectionalLight3D`, sem sombra, vinda de trás da câmera. Só acende com o
  sol abaixo do horizonte, completa o que falta da lua (some quando a lua está cheia no céu) e cai com
  as nuvens. Assim os sprites (cartões de pé virados para a câmera) e as fachadas não ficam pretos no
  intervalo entre o pôr do sol e a lua, nem na lua nova. Nunca acende de dia nem dentro de casa.
- Nuvens (`cloud` do clima, §10) apagam o sol e a NightFill, amaciam a sombra e levantam o ambiente.
- **Lâmpadas:** `NightLights` (grupo `night_lights`): luz e janelas pelo multiplicador de noite
  (`set_period_mult`, `night_mult()`), sombra só nos postes mais perto do foco (quantos, pelo nível
  gráfico; entram e saem em 1,2 s), somem com a distância, tremulam de leve e têm um halo de névoa
  quando o nível roda névoa volumétrica e o look pede (`lamp_halos`). Janelas acesas em âmbar
  (~#f9a857): branco ou creme fica sem cor no AgX.

### Um Environment só (regra)

- O `WorldTimeOfDay` cria **um** `Environment` (com o céu `world/sky/sky.gdshader`) e ele vive a sessão
  toda. Mudar de lugar **copia as propriedades** do look (`world/look/*.tres`, escolhido pelo
  `look.env` da zona; `interior_env` / `cave_env` dentro) para esse Environment (lista `COPY`).
- **Nunca trocar o resource** (`WorldEnvironment.environment = outro`) no overworld: o SDFGI e a névoa
  volumétrica perdem o cache e a imagem pisca.
- Dois looks de fora se misturam em 1,5 s (`LOOK_BLEND`); o SDFGI entra e sai pela energia, sem estalo.
- O look pode ter os metadados `sun_energy`, `moon_energy`, `sky_neutral` e `lamp_halos`.
- Pallet usa `world/look/voxel_env.tres` (AgX, SDFGI de 0,25 m com 4 cascatas, SSR, SSAO, brilho,
  névoa volumétrica com densidade 0, usada só nos halos). Não há névoa global.

### Antisserrilhado: EdgeAA, nunca MSAA nem SMAA

- **MSAA quebra a água:** as leituras de profundidade e de tela do `water.gdshader` voltam vazias e a
  água transparente fica opaca. Nenhum nível usa MSAA, e o `tests/world/test_sky.gd` confere.
- **SMAA, FXAA, FSR 2 e TAA borram os sprites:** cada degrau de pixel da arte vira meio-tom. Nenhum
  nível usa.
- **EdgeAA** (`world/look/edge_aa.gd`, efeito de compositor): FXAA só nos pixels de borda da
  geometria (salto na profundidade ou dobra na normal), na imagem opaca, antes da água e das
  partículas. Sprites (rugosidade 1,0 no buffer de normal) ficam de fora com a vizinhança 3×3, então
  saem exatamente como desenhados. `GfxQuality.attach_aa` liga no mundo (TimeOfDay) e no estádio
  (`track`). `--edge-aa=debug` pinta a máscara (vermelho = sprite, verde = borda), `--edge-aa=off`
  desliga.
- Detalhes no §11.

### Globais (project.godot `[shader_globals]`)

Todas declaradas no project.godot, então existem desde a abertura (editor e testes).

| Global | Tipo | No mundo | No treino de energia (sem mundo) | Quem lê |
|---|---|---|---|---|
| `wind_dir`, `wind_strength`, `wind_gust`, `wind_time` | vec2/float | `world/sky/wind.gd` | — | grama, folhas, voxel (balanço), detalhe, água |
| `night_lamps`, `night_windows` | float 0..1 | TimeOfDay | estádio (`set_mood`) | voxel (emissão), `NightLights`, refletores |
| `sun_dir_world` | vec3 (para o sol) | TimeOfDay | estádio | água (brilho, cáusticas) |
| `sun_color_world`, `sun_amount` | color, float | TimeOfDay (`sun_amount` = sol visível × (1 - nuvens)) | estádio | água |
| `sky_top_color`, `sky_horizon_color` | color | TimeOfDay | estádio | água (reflexo quando o SSR erra) |
| `gi_sky_floor` | float | TimeOfDay (0,2 × energia do SDFGI; 0 sem SDFGI e ao sair do mundo) | — (0) | voxel, detalhe (piso de luz do céu: com SDFGI a GI troca todo o ambiente e fachadas sob copas e beirais ficavam pretas) |
| `rain_amount` | float 0..1 | clima (`WorldWeather`) | `BattleWeatherFx` | anéis de chuva na água e nas poças |
| `rain_wet`, `rain_puddle` | float 0..1 | clima | `BattleWeatherFx` | voxel (molhado, poças), detalhe |
| `snow_cover` | float 0..1 | clima | `BattleWeatherFx` | voxel, detalhe, água (geada) |
| `cloud_cover` | float 0..1 | clima | `BattleWeatherFx` | céu, sombras de nuvem |
| `lightning_flash` | float 0..1 | clima | `BattleWeatherFx` | céu, água |
| `main_cam_pos`, `weather_*` | (antigos) | camera_rig, clima (texel do `weather_map`) | — | shaders HGSS |

- **Quem é dono de quê:** o céu (TimeOfDay no mundo, `ArenaStadium` no treino) escreve sol, céu e
  noite; o clima (`WorldWeather` no mundo, `BattleWeatherFx` no treino) escreve chuva, neve, nuvem e
  relâmpago. Um nunca escreve os globais do outro. A luta dentro do mundo não escreve globais: o clima
  dela entra no `WorldWeather.battle_cover`. No treino o `BattleWeatherFx` devolve os valores de antes
  quando a luta acaba.
- `RenderingServer.global_shader_parameter_get` só existe no editor: em jogo dá erro a cada chamada
  e trava a renderização. Nunca chame no código do jogo; leia do nó dono (o clima, o TimeOfDay, o
  estádio).

## 4. Água (gfx/water/)

- `WaterSurface.make(size, opts) -> MeshInstance3D`: plano em y local 0, centrado no nó (`size` em
  metros, x/z), com um `ShaderMaterial` próprio e o metadado `water_kind`.
- **`opts`:**
  - `kind`: `pond`, `fountain`, `stream`, `sea` ou `puddle` (outro nome vira `pond`, com aviso);
  - `flow`: Vector2 em m/s (riachos); `depth`: profundidade típica do leito (padrão 1,0; poça 0,05),
    regula a absorção; `tint`: cor da água funda;
  - `shape`: `rect` (padrão) ou `ellipse` (também `disc`/`circle`), elipse inscrita no `size`, em
    degraus das colunas de 0,25 m;
  - `pixel`: `true` (padrão, grade de 1/16 m), `false` (liso) ou a grade em metros;
  - `life: false` tira peixes, folhas e pétalas; `fish` (0..4), `leaves` e `petals` (densidade);
  - `freeze` (0..1), `seed`, `ssr_steps` (padrão 20; 0 = só o céu no reflexo), `ripples` (como
    `set_ripples`), `params` ({uniform: valor}, aplicado por último).
- **Em tempo de execução:** `set_ripples(nó, fontes)` (até 12 pontos de agitação:
  `{pos, radius, strength}` ou `Vector4(x, z, raio, força)`, no espaço local), `set_freeze(nó, 0..1)`
  (gelo do raso até a superfície toda) e `set_param(nó, uniform, valor)`.
- O leito é **voxel escavado abaixo da superfície** (material `BED`). A água lê profundidade e tela:
  - transparência e refração na grade de pixel;
  - absorção Beer-Lambert (turquesa no raso, verde-azulado no fundo);
  - espuma na margem, seguindo os degraus, pedras e postes;
  - cáusticas no leito, pela luz do sol (nenhuma à noite);
  - reflexo SSR dentro do shader, com o céu dos globais como reserva, e brilho quente dos postes;
  - anéis de chuva, ondas do vento, relâmpago no reflexo, geada com neve;
  - vida: peixes com sombra (às vezes pulam), folhas, pétalas e brilhos de sol.
- **Escala:** os padrões vivem em metros do mundo, então `node.scale = Vector3(k, 1, k)` aumenta ou
  diminui um lago (de batalha) sem esticar nada. Escave o leito para o tamanho maior.
- **Regras:** nunca sobrepor duas superfícies (uma por corpo d'água; um plano pode cobrir o lago e o
  canal que chega nele). A água desenha antes dos outros transparentes (`RENDER_PRIORITY` -1) e grava
  profundidade: respingos e partículas por cima misturam, e o que fica abaixo some. Partículas opacas
  que passam por baixo da superfície aparecem refratadas, por isso a chuva e a neve são alpha-blended.
- `FountainFx.setup(spec)`: só a água em movimento (a pedra da fonte é voxel do gerador):
  - `jets`: `[{pos, height, count (1 = um jato, > 1 = coroa), radius, reach, dir, spread}]`;
  - `basins`: `[{pos, size, kind = "fountain", shape = "ellipse", depth = 0,4, ...}]` (WaterSurface);
  - `sheets`: `[{from, to, width, speed}]` (lâmina caindo de uma borda);
  - `curtains`: `[{centre, radius, drop, flare, from_deg, to_deg, speed}]` (cortina redonda de um andar);
  - `surfaces`: `[MeshInstance3D]` (outras superfícies que recebem as ondas de onde a água cai, por
    exemplo o lago embaixo de uma cascata);
  - `light` (cor da luz subaquática à noite) e `mist`.
  - Entra no grupo `night_lights` (a luz segue os postes); `set_night(v)` na batalha e nos testes.
- Zonas antigas (HGSS) continuam com a água antiga, porque não têm leito escavado.
- **Testes e prints:** `tests/gfx/test_water.gd`; `tests/gfx/shot_water.gd -- --view=pond,fountain,...
  --hour=noon|golden|night --weather=clear|rain|storm|snow [--freeze=x] [--debug=n]`.

## 5. Zonas voxel (overworld)

- O mapa da zona (`data/maps/<id>.json`) continua sendo a fonte da jogabilidade: NPCs, placas, itens,
  zonas de aparição, gatilhos, chegadas e portas.
- Ele ganha a chave `"voxel"`, que aponta para o desenho (`data/voxel/<id>.json`), e
  `"movement": "grid"`.
- O desenho tem o mapa de tiles em ASCII (uma letra por tile, com legenda) e a lista de objetos:
  casas, árvores, cercas, postes, fonte, lago, canteiros, plantação, props.
- O gerador (GDScript) monta o VoxelGrid, a TileGrid e os metadados:
  - luzes;
  - partes de cada casa (retângulo e altura, para o fader da câmera);
  - superfícies de água e âncoras da fonte;
  - instâncias de enfeite.
- O resultado é **assado** em `world/voxel/baked/<id>.*` com `tools/voxel/bake_zone.gd`.
  - O jogo carrega o assado, que é rápido e vem com hash do desenho.
  - Se o assado estiver velho, o jogo gera na hora e avisa. Um teste falha se o hash não bater.
- **Casas do tamanho dos interiores reais**, para no futuro mostrar o interior no lugar, escondendo
  paredes e telhado (por enquanto a porta ainda leva às salas separadas):

  | Casa | Contorno em tiles | Interior | Observação |
  |---|---|---|---|
  | `player_house` | 13 × 9 | 12 × 8 | 2 andares (2,75 m cada) |
  | `rival_house` | 13 × 8 | 12 × 7 | |
  | `lab` | 14 × 17 | 13 × 16 | paredes de 3,5 m |

  - Porta na fachada sul (+Z), com um tile de porta.
  - Por dentro, a casa fica oca e com piso.
  - Paredes, telhado, laje e vidro de cada casa são partes separadas.
- **Ambiente:** o `look.env` da zona voxel é `res://world/look/voxel_env.tres` (§3).

## 6. Andar em grade (só humanos)

- **Quem anda em grade:** o jogador e os NPCs humanos, nas zonas em grade (Pallet).
  Pokémon (seguidores, selvagens, pets) continuam livres.
- **Quando a zona é em grade:** o mapa tem `"movement": "grid"` ou o `MapBuilder.grid` está
  preenchido (a grade assada da zona voxel).
  - `RouteWorld.grid_at(pos)` devolve a `TileGrid` da zona; `null` em sala, em zona livre e em zona
    ainda não montada. `Overworld.grid_at` devolve `null` na base.
  - Zona em grade sem grade assada: `GridMotion.probe_zone` monta uma vez a partir dos colisores
    (camada 1 = parede, 16 = água; uma caixa de 0,7 m no centro de cada tile) e guarda no
    `builder.grid`. Ela espera os corpos entrarem na física (`GridMotion.bodies_ready`); até lá
    `grid_at` devolve `null`. Pallet usa a grade assada, sem sonda.
- **Jogador** (`OverworldPlayer`, world/player.gd):
  - 4 direções, tile a tile. Toque curto (menos de `TURN_DELAY` 0,1 s) só vira; segurar anda (na hora,
    se a tecla é a da frente).
  - Passos seguidos sem parada, na velocidade das zonas livres (andar 4 m/s, correr 7 m/s). A sobra
    passa de um tile para o outro e pela costura com a zona livre.
  - Movimento cinemático em XZ: nenhum meio-fio ou pet prende o jogador entre dois tiles.
  - Parede, água e gente bloqueiam: anda no lugar e toca o esbarrão (`Audio.sfx("bump")`, no máximo
    a cada `BUMP_GAP` 0,4 s).
  - Grama alta sorteia uma vez por tile (1 m no `EncounterRate`); Repel e passos contam por tile.
  - E fala com o tile da frente (ou o do outro lado de um balcão); E no meio do passo vale no fim.
  - Empurrar contra a porta, do tile da frente, entra (`WorldDoor.walk_in`). A área de entrada de
    1,2 m só vale nas zonas livres.
  - Depois de um warp, o movimento fica parado por `ARRIVE_HOLD` 0,2 s (a tecla ainda apertada não
    faz sair pela porta de novo).
  - Ressalto: pula dois tiles (`WorldLedge.jump` / `hop_to`).
  - Quando outra coisa move o corpo (cena da Story, batalha, teleporte, load), ele volta deslizando
    para o centro de tile livre mais perto, ou pula até lá se está longe (`SNAP_FAR` 1,6 m) ou dentro
    de algo.
  - `save_position()` devolve o centro do tile (o de destino no meio do passo); o save e o menu de
    pausa usam ele. `RouteWorld._put_player` põe o jogador no tile livre mais perto, então saves
    antigos dentro de parede se corrigem.
- **NPCs:** `WorldNpc` passeia tile a tile e reserva o tile na `TileGrid` antes de andar
  (`claim` / `release` / `claimed`, só em tempo de execução, nunca assado). Nunca pisa no tile do
  jogador (atual ou de destino), num tile `NO_NPC` nem no de outro NPC. Treinadores andam pelas linhas
  de tile e param no tile ao lado do jogador. `CharSprite.step_col` alterna o pé a cada tile
  (-1 = ciclo normal de andar).
- **Story:**
  - `StoryNpc.move_node(n, pos, speed, last_axis := -1)` anda tile a tile, um eixo e depois o outro
    (o jogador com `grid_walk`, os outros com `GridMotion.walk_node`). A reta antiga é
    `StoryNpc.tween_node`.
  - `Story.approach` para no tile vizinho pelo eixo dominante, a `max(1, round(distância))` tiles.
  - `Story.begin` espera o passo em andamento terminar (`settle()`); o fim da cena devolve o jogador ao
    centro de um tile livre (`resnap()`).
- **Interfaces:**
  - `Overworld.grid_at(pos) -> TileGrid` (`null` = livre) e `GridMotion.grid_for(nó)`.
  - `OverworldPlayer`: `grid_active()`, `save_position()`, `occupied_cells()`, `on_placed()`,
    `settle()` (await), `resnap()`, `grid_walk(to, speed := 3.5, last_axis := -1)` (await) e os sinais
    `step_finished(cell)` e `walk_done`.
  - `GridMotion` (world/grid/grid_motion.gd): `card`, `vec`, `center`, `axis_path`, `blocker_at`,
    `spot_free`, `nearest`, `walk_node`, `probe_zone`, `door_cell`. `MAX_RISE` (0,3 m) é o maior
    degrau andável entre tiles vizinhos.
  - Testes: `OverworldPlayer.force_mode` (`"grid"`, `"free"` ou `""`) e `force_zones`
    (`{zona: modo}`) forçam o modo; o teste que mexer neles volta para o padrão no fim.
- **Teste:** `tests/world/test_grid_motion.gd` (na RouteWorld de verdade, em Pallet, e num mundo
  pequeno para ressalto, grama, Repel e treinador).

## 7. Arenas do treino (modo de energia)

- **Tamanho:** 48 × 28 m (`Cfg.ARENA`; comprimento e largura dobrados em relação a 24 × 14,
  4× a área; `Cfg.SMALL_ARENA` 24 × 14 só nos testes).
  - Os Pokémon entram a 6 m do centro (`opts.entry_x` = `Cfg.ENTRY_X`), como na quadra antiga; cada
    treinador fica 0,8 m fora da linha de fundo (±24,8 m).
  - A câmera de ação vai até 47 m (`BattleDirector.MAX_DIST`) para caber a quadra inteira.
  - Ela enquadra na faixa livre entre o HUD (abaixo dos cartões, `BattleHUD.top_band`, e acima do
    log): a distância sai dessa faixa e a câmera sobe (`v_offset`) para centrar o quadro nela.
    Morros, picos, árvores e pedras entre ela e um lutador, ou grandes bem na frente da lente,
    ficam translúcidos enquanto estão no caminho.
- **Obstáculos:** são sorteados como hoje (dicionários analíticos de `BattleTerrain` etc. = jogabilidade).
  - As quantidades crescem na proporção da área: `BattleTerrain.count(n)` / `scale_count(n, k)`, com
    `k = área / 336` (`BASE_AREA`, a quadra de 24 × 14) e `COUNT_CURVE` 1,0. Zero continua zero.
  - Posição, raio e altura se encaixam na malha de 0,25 m (`LATTICE`).
  - O visual é voxel, gerado a partir desses dicionários (battle/voxel/: `ArenaPalette` cores por
    cenário, `ArenaFloor` piso pintado por tile com linhas de giz e barreira, `ArenaVoxels` morros,
    picos, lagos, moitas e marcas, `ArenaPropsVox` objetos vivos, caixas e pedras).
  - Nunca use `arena.rng` para o visual.
  - Com `fast_sim` não se gera nada visual.
  - **Destruição** (`ArenaDebris`, battle/voxel/arena_debris.gd; regras em `BattleDestruction`): obstáculo quebrado
    solta pedaços de voxel (caixas de `FINE`, material padrão cacheado por cor) que voam com gravidade, quicam no
    chão (`BattleTerrain.height_at`), giram e encolhem; árvore solta lascas e folhas que caem flutuando; poeira do
    `PixelFx`; tremida curta da câmera pelo `h_offset` (o `BattleDirector` só mexe em posição e `v_offset`); no
    lugar fica um monte baixo de entulho em voxel (1–3 voxels `FINE`, `meta rubble`). RNG própria (`randomize`).
- **Estádio voxel em volta, fora dos limites** (`ArenaStadium`, battle/voxel/arena_stadium.gd):
  - montado uma vez por cena de treino (`TrainingBattle._build_stage`), nunca com `fast_sim`; sem corpo físico (a arena consulta paredes na camada 1);
  - arquibancada em anel de 12 fileiras (`StadiumParts`: cadeiras, escadas, vomitórios, parapeito, fachada, túneis dos treinadores no meio das cabeceiras); a da frente (+z) fica abaixo da linha de 30° da câmera de ação;
  - torcida (`ArenaCrowd`): um MultiMesh por setor; `cheer(lado, força)` e `wave()` (ola), uniforms via `ArenaCrowd.set_param`;
    - os torcedores são os NPCs pixel-art do mundo (`ArenaCrowd.CROWD_SHEETS`: todas as folhas `npc_*` que mapas, treinadores e interiores usam, menos o protagonista, a protagonista, o rival e o Prof. Carvalho), sorteados por hash da cadeira (nunca `arena.rng`) e espelhados metade das vezes;
    - cada um é um quad billboard em Y (crowd_sprite.gdshader, como o `CharSprite`: iluminado, alpha cut, filtro nearest) com o quadro parado de frente, afundado 0,42 m na cadeira para só aparecer o tronco; um atlas montado em tempo de execução (uma linha por folha, os 3 quadros "de frente") e o custom data da instância escolhe a célula;
    - torcer: os do lado se levantam, pulam e alternam os quadros de passo; a ola levanta a faixa que corre pelo anel;
    - sem as folhas (original/ fora do repositório, nuvem) volta aos bonecos voxel antigos (crowd.gdshader, camisa com a cor do lado);
  - torres de refletor (SpotLight3D, sombra só nas duas do fundo), placar principal com a Poké Bola e dois placares nas cabeceiras (`score({names, alive, clock, scene, series, headline?})`; `headline` aparece grande no lugar do relógio, o "VS"/"FIGHT!" da abertura do treino; `screen_corners()` dá os cantos globais da tela do placar principal para a câmera da abertura), bandeiras e faixas ao vento (flag.gdshader), praça, árvores;
  - céu, sol e ambiente próprios (stadium_sky.gdshader, AgX, SSAO, brilho); `set_mood("dia" | "tarde" | "noite")` pela opção Hora do treino (`time_of_day`); `theme(cenário)` repinta o gramado de fora e muda o céu (caverna de noite, pântano nublado, vulcão) sem mexer no sol e no ambiente que o `BattleBiomes` ajustou para a luta.
- **Clima da luta no modo de energia:** `BattleWeatherFx` usa as peças do clima do mundo (§10) sobre a
  quadra mais 12 m (`STANDS_MARGIN`), com relâmpago e som; no treino ele dirige os globais de clima e
  devolve tudo no fim (§3).
- O piso continua com o topo em y = 0; o tapete do time e o botão da Poké Bola no centro são pintura do `ArenaFloor`.
- **Água das arenas:** lagos com `WaterSurface` redonda (`shape: "ellipse"`), o nível sobe e desce no buraco pelo raio; congelar usa o gelo do shader (`set_freeze`). A maré da praia é uma lâmina `sea` rasa (5 cm) com absorção forte e espuma só na beira.
- **Fotos:** `tests/battle/shot_arena_stadium.gd -- --scenario=<id> --mood=dia|tarde|noite --views=inicio,meio,ko,aberta,placar,tunel,torcida,lago,gelo,mare` (com `--fixed-fps 60`; sem `--out=<prefixo>` grava em `user://shots/arena/estadio_<vista>.png`).

## 8. Ferramentas

- **Testes:** `godot --headless --fixed-fps 60 --path . --script res://tests/<pasta>/<teste>.gd`.
- **Print na nuvem** (lavapipe):

  ```
  xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan --resolution 1600x900 --fixed-fps 60 --script <shot>.gd -- --out=<png>
  ```

  Precisa de `apt install mesa-vulkan-drivers xvfb libvulkan1`. Leva de 30 s a 4 min por imagem.
  Sem `--out`, os prints abaixo gravam dentro de `user://` (no Windows,
  `%APPDATA%\Godot\app_userdata\PokmemonLike`).
  Use `--fixed-fps 60`: sem ele os quadros lentos perdem os respingos da chuva e as lutas correm.
- **Prints prontos:** `tests/world/shot_pallet.gd` (§9), `tests/world/shot_sky_voxel.gd` (diorama:
  `--hours=`, `--weathers=`), `tests/world/shot_sky_world.gd` (zonas HGSS: `--places=`, `--hours=`,
  `--weather=`), `tests/gfx/shot_water.gd` (§4), `tests/battle/shot_arena_stadium.gd` (§7),
  `tests/battle/shot_weather.gd` (`weather=rain|snow`).
- **Formatação:** rodar `gdformat` nos scripts editados antes do commit.

## 9. Formato do desenho de zona (`data/voxel/<id>.json`)

O mapa da zona (`data/maps/<id>.json`) liga o desenho com
`"voxel": {"design": "<id>", "extent": [x, z, largura, profundidade]}`. O `extent` (em metros, bordas em
,5) cobre o desenho inteiro, inclusive a floresta de fora do `rect` jogável. O mesmo `extent` vai em
`data/world.json` (`zones.<id>.voxel.extent`): as zonas vizinhas não pintam chão, trilha nem enfeite
por baixo dele (`MapBuilder.voxel_rects`).

### Chaves

| Chave | O que é |
|---|---|
| `origin` `[x, z]` | Tile do mundo do primeiro caractere da primeira linha. |
| `rect` `[x0, z0, x1, z1]` | Tiles jogáveis (inclusive). O resto é cenário. |
| `ground` | Linhas de norte para sul, um caractere por tile: o que é pintado no chão. |
| `things` | Mesmo tamanho: o que fica em cima (`' '` = nada). Tudo que está em `things` bloqueia o tile. |
| `buildings` | Uma entrada por letra maiúscula de contorno usada em `things`. |
| `trees` | `[{"pos": [x, z], "species", "size"}]`: troca a espécie ou o tamanho de uma árvore. |
| `crops` | `[{"rect": [x0, z0, x1, z1], "crop": "wheat"}]` sobre tiles `c`. |
| `objects` | Coisas grandes: fonte, portão, corpos d'água. |
| `props` | `[{"model", "pos": [x, z], "rot", "block"}]`: props soltos em lugar exato (abaixo). |

**Chão (`ground`):** `.` gramado · `,` campo · `;` chão de floresta · `*` canteiro de flores ·
`=` calçamento · `+` laje (praça) · `:` terra · `%` terra arada · `_` areia · `~` água rasa ·
`w` água funda · `k` píer · `b` ponte (`k` e `b` são decks andáveis com água por baixo).

**Coisas (`things`):** `F` floresta · `T` carvalho · `K` cerejeira · `A` macieira · `Y` bétula ·
`I` pinheiro · `t` muda · `B` arbusto · `h` cerca viva · `f` cerca · `W` muro · `g` pilar ·
`l` poste · `n` banco · `v` jardineira · `e` poço · `u` barril · `x` caixote · `o` pedra ·
`y` espantalho · `c` plantação · `O` fonte · `d` porta. Letras maiúsculas fora dessa lista são
contornos de construção.

**Construções:** `{"char", "id", "style": "house"|"lab"|"shed"|"greenhouse", "footprint": [l, p],
"map": true, "storeys", "roof_color", "wall_color", "stone_color", "door_color", "shutter", "trim",
"flower_boxes", "timber_frame", "chimney": [deslocamento x, "n"|"s"]}` (cores em hex).
- `"map": true` quando o mapa JSON tem a porta dessa casa.
- O `d` encostado no lado sul do contorno é o tile da porta (bandeira `DOOR`). O tile da frente é a
  chegada (`<id>_door`) e tem de estar livre. No mapa, a porta usa `"door": {"tile": [x, z]}`.
- `"greenhouse"` (estufa): mureta de tijolo, caixilho branco, canteiros dentro e vidro numa parte
  `glass` sempre translúcida (`GLASS_ALPHA` 0,55), fora do fader da câmera.
- Partes de cada casa: `walls`, `roof`, `slab` e `glass`. Enfeites presos numa parte (jardineira com
  flores, hera, calha, lanterna de parede) somem junto com a casa; no assado a chave do enfeite é
  `modelo@parte`.

**Plantação (`crops`):** `wheat`, `corn`, `cabbage`, `lettuce`, `carrot`, `pumpkin`, `tomato`,
`strawberry`.

**Objetos (`objects`):**
- `{"kind": "fountain", "rect": [x0, z0, x1, z1]}` sobre tiles `O`: fonte de três andares, com as
  âncoras de `FountainFx` (jatos, bacias, lâminas, cortina, luz) nos metadados.
- `{"kind": "gate", "from": [x, z], "to": [x, z], "sign": "TEXTO"}`: arco entre dois pilares `g`.
  Os tiles do vão ganham `NO_NPC`.
- `{"kind": "water", "type": "pond"|"stream", "rect": [x0, z0, x1, z1], "level": y, "depth": m,
  "flow": [x, z]}`: um corpo d'água sobre os tiles `~`/`w` do retângulo, com **uma** `WaterSurface`.
  - Os retângulos nunca se sobrepõem (`VoxelDesign.validate`).
  - `level` é a altura da superfície (-0,12 = 12 cm abaixo da margem).
  - `depth` limita o leito.
  - O leito desce em degraus de 0,25 m a partir da margem (0,5 m no raso, até 1,5 m no fundo),
    com areia, lodo, cascalho e pedras.
  - Onde um corpo mais baixo encosta num mais alto, o gerador faz um **vertedouro** de pedra e uma
    **cascata** (`FountainFx` com uma lâmina) entre os dois.

**Props (`props`):** `{"model": modelo de VoxelModels ou enfeite de VoxelFlora, "pos": [x, z] em metros,
"rot": quartos de volta (frente +z = sul), "block": true bloqueia o tile}`.
- `"prop_laundry_post"` com `"line_to": [x, z]` estende duas cordas com roupas até o poste nesse ponto
  (as roupas balançam no vento) e bloqueia os tiles embaixo.
- `"prop_flagpole"` ganha uma bandeira que tremula (metadado `flags`).

**Escalas:** mundo 0,25 m; props a 1/8 m (`VoxelModels.PROP_VS`); árvores finas (`bush`, `shrub`) a
0,125 m (`VoxelTrees.model_vs()`); enfeites a 1/16 m.

### Tiles e bandeiras

`TileGrid`: `BLOCKED` (1), `WATER` (2), `GRASS` (4), `DOOR` (8), `LEDGE` (16), `NO_NPC` (32) e
`COVER` (64), mais a altura do chão por tile.
- Água e tudo de `things` bloqueiam.
- Placas e caixas de correio do mapa são desenhadas em voxel. O tile delas é sólido e a leitura é
  feita do tile vizinho.
- Os colisores saem da própria grade: caixas na camada 1 para tiles bloqueados e corpo `Water`
  (camada 16) para tiles de água. Assim, colisão e grade nunca discordam.

### Gerar, assar e carregar

- **Gerador:** `world/voxel/voxel_zone_gen.gd` (`VoxelZoneGen`, `VERSION`). Ele usa
  `voxel_build.gd` (casas), `voxel_props.gd` (cercas, postes, fonte, portão, props do desenho...),
  `voxel_models.gd` (props a 1/8 m: postes, bancos, caixas de correio, barris, poço, bandeira...),
  `voxel_trees.gd`, `voxel_flora.gd` (flores, plantação, juncos, nenúfares, algas em MultiMesh) e
  `voxel_pal.gd` (paleta).
- **Assar:**

  ```
  godot --headless --path . --script res://tools/voxel/bake_zone.gd -- zone=pallet_town
  ```

  O comando grava `world/voxel/baked/<id>.res` (volume zstd, malhas por bloco de 16 m, modelos de
  árvore e enfeite, MultiMesh) e `<id>.json` (metadados, grade, `hash`, `source_hash`, `version`).
  - Metadados: `lights`, `water`, `cascades`, `fountains`, partes das casas, `signs`, `smoke` (pontos
    de chaminé), `butterflies` (pontos sobre os canteiros), `flags` e `laundry`.
  - `hash` = desenho + mapa da zona + `VoxelZoneGen.VERSION`. É o único que o jogo confere: com ele
    diferente, a zona gera na hora (`stale`).
  - `source_hash` = md5 dos scripts de `VoxelZoneBake.SOURCES` (hoje `world/voxel/*.gd` menos
    `voxel_zone.gd`, mais `gfx/voxel/voxel_grid.gd` e `gfx/voxel/voxel_mesher.gd`). Quem confere é o
    `tests/world/test_voxel_zone.gd`.
  - Por isso, **depois de qualquer mudança em `data/voxel/<id>.json`, `data/maps/<id>.json` ou num
    script de `VoxelZoneBake.SOURCES` (até só `gdformat`), asse de novo.** Mudar só o
    `voxel_zone.gd` não pede assar.
  - A ferramenta sai com erro se algum script do gerador não compilar.
- **Em jogo:** `VoxelZone` (`world/voxel/voxel_zone.gd`, estende `MapBuilder`) é escolhida por
  `RouteWorld._make_builder` quando o mapa tem `"voxel"`.
  - Com o assado velho, ela gera na hora e avisa (`stale`).
  - A descompressão do volume roda num thread. Os nós entram aos poucos (`items_per_frame`).
  - Ela expõe `grid`, `houses` (fader da câmera), `lights` (em `NightLights`), `water_surfaces` e
    `fountain`.
  - Fumaça nas chaminés, borboletas sobre os canteiros (só de dia), bandeira e roupas no varal.
  - **Neve:** acima de `snow_cover` 0,45 (`SNOW_BURY`) a zona esconde flores, borboletas e tufos
    verdes (os tufos secos ficam). Ela lê o valor do nó de clima (grupo `weather`), nunca do global.
  - **Fader da câmera:** casas pelas partes; árvores da cidade e props altos têm retângulo próprio,
    que começa logo ao sul do pé (a câmera da zona olha para o norte).
- **Testes:** `tests/world/test_voxel_zone.gd` verifica:
  - assado fresco;
  - posições em centro de tile livre;
  - portas;
  - alcance a pé (BFS);
  - colisores iguais à grade;
  - tempo de carga;
  - caminhada com as teclas até cada porta, NPC, placa, margem do lago e portão.

  `tests/world/shot_pallet.gd` tira os prints: `--out=<pasta>` (padrão `user://shots/pallet`),
  `--spots=start,plaza,fountain,house,laundry,plantation,rival,lab,pond,dock,bridge,gate,orchard,
  south,paddock,west,east,centre,backyard,meadow,north,flag`,
  `--periods=morning,midday,afternoon,sunset,night` (só `--weather=rain|snow`) ou `--hours=HH:MM,...`
  (com qualquer tipo do `WorldWeather`: `--weather=clear|cloudy|overcast|rain|storm|snow|mist`; na
  nuvem, uma hora por execução), `--melt=<cobertura>` (com neve), `--no-lamps`, `--far=<m>`,
  `--pitch=<graus>`, `--settle=<quadros>`, `--env-off=ssao,ssil,sdfgi`.

## 10. Clima do mundo (world/sky/weather.gd)

- `WorldWeather` (grupo `weather`) troca a chuva única por dia por uma agenda (`WeatherSchedule`,
  `data/weather.json`). Tipos: `clear` (Limpo), `cloudy` (Nublado), `overcast` (Encoberto), `rain`
  (Chuva), `storm` (Tempestade), `snow` (Neve) e `mist` (Neblina leve, só entre 04:00 e 09:00).
- **Agenda:** cada dia de jogo é cortado em trechos de 1,5 a 5 h, e cada trecho sorteia o tipo pelo
  peso, com a semente do dia (o mesmo dia tem sempre o mesmo clima, a qualquer hora). Trechos vizinhos
  se misturam em 40 minutos de jogo, também na virada da meia-noite.
- **O chão segue no tempo de jogo:** molha com a chuva e seca depois (1,2 h), as poças enchem e secam
  mais devagar (3 h), a neve assenta e derrete (mais rápido na chuva e no sol).
- Publica os globais de clima (§3) e o texel do `weather_map` dos shaders HGSS (R molhado, G neve,
  B névoa, A nuvem). O clima de uma batalha (`battle_cover`) entra por cima como antes: o molhado da
  batalha sem a escala 0,8 do mundo e a areia/névoa dela no B. Dentro de casa nada cai, os globais
  ficam secos e a chuva se ouve abafada.
- Liga o céu (nuvem apaga o sol, tempestade escurece, relâmpago acende o ambiente) e o vento (na
  tempestade mais forte e com rajadas; a chuva inclina com ele).
- **Efeitos** (`gfx/weather/`, também usados no treino de energia):
  - `WeatherRig`: chuva em riscos finos alinhados à velocidade e iluminados pelo céu (não brilham),
    que param nos telhados por um heightfield de colisão e respingam em coroa e anel; neve em flocos
    redondos que pousam; névoa baixa em placas;
  - `WeatherLightning`: clarão azulado com 2 a 4 repiques, às vezes um raio em voxels, trovão
    atrasado pela distância (343 m/s);
  - `WeatherKit`: texturas e curvas; o som fica em `audio/weather_audio.gd` (chuva, vento, trovão).
  - As partículas são alpha-blended (não aparecem refratadas debaixo d'água) e seguem o orçamento do
    nível gráfico (`GfxQuality.particles()`). A camada de render dos efeitos (`WeatherKit.LAYER`) fica
    fora de todo `heightfield_mask`.
- **Névoa no chão:** só de manhã cedo (o tipo neblina, ou uma manhã limpa com orvalho) e por um tempo
  depois da chuva, sempre abaixo da altura dos personagens (regra do Caio: nada de véu na tela).
  Desliga em **Opções > NÉVOA DO CLIMA** ou na chave do painel F9: as duas gravam
  `settings.cfg [video] weather_mist` (padrão ligada) e mudam `WorldWeather.mist_enabled` na hora.
- **Forçar um tipo:** `--weather=<id>` (`off` = limpo), `WorldWeather.forced` ou o painel F9.
  `snap()` pula direto para o visual assentado (chão já molhado, neve já no chão).
- **Painel F9** (`world/debug/sky_panel.gd`, no overworld): hora, velocidade do relógio (0,5 a 120
  minutos de jogo por segundo, Normal e pausa), clima (Automático ou um tipo), botão de raio, chave da
  névoa, nível gráfico só desta sessão e leitura do sol, lua, exposição, lâmpadas e sombras. Não pega
  o foco do teclado. Na linha de comando: `--hour=HH:MM`, `--time-scale=N`, `--period=<id>`,
  `--weather=<id>`, `--quality=0..3`, `--sdfgi=off|on`.
- **Testes:** `tests/world/test_sky.gd` (céu, lâmpadas, painel, níveis) e
  `tests/world/test_weather_world.gd` (agenda, chão, globais, névoa, interiores).

## 11. Qualidade gráfica (world/look/gfx_quality.gd)

**Opções > GRÁFICOS:** Baixo, Médio, Alto (padrão) e Ultra, gravado em `settings.cfg [video] graphics`.
O `[options] quality` antigo continua gravado (Alto e Ultra = 1); save antigo com 0 vira Baixo e com
1 vira Alto. Uma tabela (`GfxQuality.TIERS`) decide tudo:

| | Baixo | Médio | Alto | Ultra |
|---|---|---|---|---|
| Resolução 3D | 0,75 (FSR) | 1,0 | 1,0 | 1,0 |
| Antisserrilhado | EdgeAA | EdgeAA | EdgeAA | EdgeAA |
| Luz rebatida | só SSAO | SSIL | SDFGI (meia resolução) | SDFGI cheio |
| Reflexo SSR | não | não | meia resolução | cheio |
| Névoa volumétrica (halos dos postes) | não | não | sim | sim |
| Sombra do sol | 2048, 32 m | 4096, 38 m | 4096, 45 m | 8192, 55 m, sombra mais suave longe do objeto |
| Postes com sombra | 0 | 2 | 4 | 6 |
| Partículas de clima | 0,5× | 0,75× | 1× | 1× |

- Nenhum nível usa MSAA nem SMAA / FXAA / FSR 2 (§3).
- O look da zona ainda escolhe o que quer; o nível só deixa ou proíbe. Com SDFGI ligado o SSIL sai.
- `Settings.apply` chama `GfxQuality.set_tier` e `apply_all`; os nós do grupo `gfx_quality` (céu,
  clima, a luta de energia) recebem `apply_quality()`. `GfxQuality.track(world_env)` faz outro
  Environment seguir o nível.
- `--quality=0..3` (ou `baixo`/`medio`/`alto`/`ultra`) força um nível nos prints; o painel F9 troca só
  nesta sessão.
- O custo só foi medido em renderização por software (lavapipe). Num GPU de verdade, o Alto foi pensado
  para uma placa da classe RTX 5070.

### Carregamento (tela e pré-carga)

A saída da casa para Pallet travava em preto: `RouteWorld._ensure_zone` montava a zona **de uma vez** (`items_per_frame` 0) quando ela ainda não existia (quem começa/continua no quarto nunca tinha carregado Pallet, pois o streaming mede a distância da posição do quarto, em x 10000+). Agora (1) dentro de um quarto o `_process` do `RouteWorld` já carrega a zona de fora (`active_zone`) em fatias de quadro; (2) se ainda faltar, `go_to_zone` mostra a tela `Loading` (autoload `ui/loading/loading_screen.gd`: Poké Ball de pixel, "Loading...", barra que corre; aparece depois de 0,2 s, fade de 0,15 s, mínimo 0,35 s na tela) e monta a zona em fatias, então ela nunca congela; (3) título -> mundo e Treino (montar -> luta, e entre lutas da série/Repetir) usam `Loading.begin_now("scene"/"battle")`. API: `begin(key)`, `begin_now(key)`, `end(key)`, `end_later(key, frames)`, `is_showing()`. Teste: `tests/ui_front/test_loading.gd`. O estádio do treino já é reaproveitado entre lutas (só a arena é refeita).
