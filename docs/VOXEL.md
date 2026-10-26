# Voxel: cenários, grade de 1 m, água e clima

Direção de arte decidida em 2026-10-25/26 (conceito B, "Vila de pedra"): cenário em voxel 3D,
personagens e Pokémon em sprite 2D (2.5D), luz forte no próprio Godot (sem render de Blender).
Pallet Town é a primeira zona nesse estilo; as outras zonas continuam com a arte antiga por
enquanto. Os campos de treino do modo de energia também viram voxel (estádio). O VGC não muda.

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
| `voxel_detail.gdshader` | Enfeites com cor no vértice: balanço no vento, neve e chuva. |

- **Partes:** a parte 0 é cenário fixo. Qualquer outro id vira uma malha própria: telhado e paredes
  de cada casa (para sumir quando o jogador entrar), copa de árvore (balança) e assim por diante.
- **Faces escondidas:** uma face só some se a vizinha for sólida **e** for da mesma parte ou da parte 0.
  Assim, esconder uma parte nunca abre buraco no que fica.
- **Velocidade (GDScript, nuvem):** volume de 240×64×200 voxels → greedy em ~3 s e ~30 mil quads.
  Zonas grandes são **assadas** (pré-geradas) e as arenas são geradas na hora (são pequenas).
- **Testes:** `tests/gfx/test_voxel.gd`.
- **Print:** `tests/gfx/shot_voxel.gd` (veja §8).

## 3. Globais de shader (project.godot `[shader_globals]`)

Todas declaradas no project.godot, então existem desde a abertura (editor e testes).

| Global | Tipo | Quem escreve | Quem lê |
|---|---|---|---|
| `wind_dir`, `wind_strength`, `wind_gust`, `wind_time` | vec2/float | `world/sky/wind.gd` | grama, folhas, voxel (balanço), detalhe |
| `night_lamps`, `night_windows` | float 0..1 | TimeOfDay (e o estádio à noite) | voxel (emissão), `NightLights` |
| `sun_dir_world` | vec3 (para o sol) | TimeOfDay | água (brilho, cáusticas) |
| `sun_color_world`, `sun_amount` | color, float | TimeOfDay (`sun_amount` = sol visível × (1 - nuvens)) | água |
| `sky_top_color`, `sky_horizon_color` | color | TimeOfDay | água (reflexo quando o SSR erra) |
| `rain_amount` | float 0..1 | clima (mundo) / BattleWeatherFx (treino) | anéis de chuva na água e nas poças |
| `rain_wet`, `rain_puddle` | float 0..1 | clima | voxel (molhado, poças), detalhe |
| `snow_cover` | float 0..1 | clima | voxel, detalhe |
| `cloud_cover` | float 0..1 | clima | sol, céu, sombras de nuvem |
| `lightning_flash` | float 0..1 | clima | céu, água |
| `main_cam_pos`, `weather_*` | (antigos) | camera_rig, weather.gd | shaders HGSS |

## 4. Água (gfx/water/)

- `WaterSurface.make(size, opts) -> MeshInstance3D`: plano em y local 0, centrado no nó.
  - `opts.kind`: `pond`, `fountain`, `stream`, `sea` ou `puddle`.
  - `opts.flow`: Vector2 em m/s.
  - `opts.depth`: profundidade típica do leito.
- O leito é **voxel escavado abaixo da superfície** (material `BED`). A água lê profundidade e tela:
  - transparência e refração;
  - absorção Beer-Lambert;
  - espuma na margem;
  - cáusticas no leito;
  - reflexo SSR dentro do shader, com o céu como reserva;
  - anéis de chuva (`rain_amount`) e ondas do vento.
- `FountainFx.setup({jets, basins, sheets, light})`: jatos, cortinas entre as bacias, respingos, névoa
  e luz subaquática à noite. A pedra da fonte é voxel do gerador.
- Zonas antigas (HGSS) continuam com a água antiga, porque não têm leito escavado.

## 5. Zonas voxel (overworld)

- O mapa da zona (`data/maps/<id>.json`) continua sendo a fonte da jogabilidade: NPCs, placas, itens,
  zonas de aparição, gatilhos, chegadas e portas.
- Ele ganha a chave `"voxel"`, que aponta para o desenho (`data/voxel/<id>.json`), e
  `"movement": "grid"`.
- O desenho tem o mapa de tiles em ASCII (uma letra por tile, com legenda) e a lista de objetos:
  casas, árvores, cercas, postes, fonte, lago, canteiros, plantação.
- O gerador (GDScript) monta o VoxelGrid, a TileGrid e os metadados:
  - luzes;
  - partes de cada casa (retângulo e altura, para o fader da câmera);
  - superfícies de água e âncoras da fonte;
  - instâncias de enfeite.
- O resultado é **assado** em `world/voxel/baked/<id>.*` com `tools/voxel/bake_zone.gd`.
  - O jogo carrega o assado, que é rápido e vem com hash do desenho.
  - Se o assado estiver velho, o jogo gera na hora e avisa. Um teste falha se o hash não bater.
- **Casas do tamanho dos interiores reais**, para no futuro mostrar o interior no lugar, escondendo
  paredes e telhado:

  | Casa | Contorno em tiles | Interior | Observação |
  |---|---|---|---|
  | `player_house` | 13 × 9 | 12 × 8 | 2 andares (2,8 m cada) |
  | `rival_house` | 13 × 8 | 12 × 7 | |
  | `lab` | 14 × 17 | 13 × 16 | paredes de 3,4 m |

  - Porta na fachada sul (+Z), com um tile de porta.
  - Por dentro, a casa fica oca e com piso.
  - Paredes, telhado e laje de cada casa são partes separadas.
- **Ambiente:** o `look.env` da zona voxel é `res://world/look/voxel_env.tres`.

## 6. Andar em grade (só humanos)

- **Quem anda em grade:** o jogador e os NPCs humanos, nas zonas com `"movement": "grid"`.
  Pokémon (seguidores, selvagens, pets) continuam livres.
- **Regras:**
  - 4 direções, tile a tile.
  - Toque vira, segurar anda.
  - A corrida mantém a velocidade de hoje.
  - A porta entra ao empurrar contra ela.
  - O encontro em grama alta é sorteado uma vez por tile.
- **Interfaces:**
  - `MapBuilder.grid: TileGrid` (null nas zonas livres).
  - `Overworld.grid_at(pos)`.
  - `player.grid_active()`, `player.save_position()`, `player.grid_walk(to, speed)`.
- **Story:** quando o jogador termina uma cena fora do tile, ele volta para o centro do tile.

## 7. Arenas do treino (modo de energia)

- **Tamanho:** 34 × 20 m (o dobro da área de 24 × 14). O VGC continua com 24 × 14, sem nenhuma mudança.
- **Obstáculos:** são sorteados como hoje (dicionários analíticos de `BattleTerrain` etc. = jogabilidade).
  - As quantidades crescem na proporção da área.
  - O visual é voxel, gerado a partir desses dicionários.
  - Nunca use `arena.rng` para o visual.
  - Com `fast_sim` não se gera nada visual.
- **Estádio voxel em volta, fora dos limites:**
  - arquibancadas com torcida;
  - torres de refletor;
  - placar;
  - emblema de Poké Ball;
  - linhas do campo.
- O piso continua com o topo em y = 0.

## 8. Ferramentas

- **Testes:** `godot --headless --fixed-fps 60 --path . --script res://tests/<pasta>/<teste>.gd`.
- **Print na nuvem** (lavapipe):

  ```
  xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan --resolution 1600x900 --script <shot>.gd -- --out=<png>
  ```

  Precisa de `apt install mesa-vulkan-drivers xvfb libvulkan1`. Leva de 30 s a 2 min por imagem.
- **Formatação:** rodar `gdformat` nos scripts editados antes do commit.
