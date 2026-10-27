# PokmemonLike — estado do projeto

Atualizado em 2026-10-26. Jogo em Godot 4.7 (GDScript), feito a partir do estudo do *Pokemon Battle Arena 0.2.0 demo* (fan game em Godot).
**Uso pessoal, não publicar**: usa a arte extraída do original (pasta `original/`, fora do git) e a marca Pokémon.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| `C:\Users\User\Documents\pokmemon-like` | O projeto Godot (repositório git local, sem remoto) |
| `C:\Users\User\Documents\pba-referencia` | Engenharia reversa do original: `codigo/` (164 scripts decompilados), `dados/` (JSONs), `analise/` (3 relatórios), `ferramentas/` (extrator do PCK, decompilador `.gdc`, conversor de arte) |
| `docs/MECANICAS.md` | Regras da batalha oficial atual (dano Gen 5+, crítico, prioridade, dupla, status, clima) e como o jogo adapta cada uma, com o arquivo |
| `docs/GOLPES.md` | Guia golpe por golpe de como cada golpe oficial (Gen 9) foi adaptado ao tempo real; gerado por `tools/move_guide.py` (também gera a página HTML) |
| `docs/VOXEL.md` | Arte voxel (Pallet e o estádio do treino), grade de 1 m, água, céu, clima e níveis gráficos: formato, APIs e regras |
| `docs/CONTRATO.md` | Regras de quem edita qual pasta e as APIs entre as partes (histórico de todas as rodadas) |
| `docs/pedidos/*.md` | Pedidos que cada parte fez às outras |
| `docs/screens/*.png` | Capturas reais de cada parte do jogo |
| `docs/audio_preview/` | WAVs das músicas e efeitos (fora do git) |
| Godot usado | `C:\Users\User\Desktop\Godot_v4.7.2-stable_mono_win64\` (o `_console.exe` roda os testes) |

## Como rodar

- Abrir o projeto no Godot e apertar F5: abre a tela de título (`res://ui/front/title.tscn`).
- Cenas de teste: `res://battle/battle_test.tscn` (só batalha), `res://world/overworld.tscn` (mapa de teste antigo).
- Save do jogador: `user://save.json` (`%APPDATA%\Godot\app_userdata\PokmemonLike`). Os testes usam outros arquivos e nunca mexem nele.

**Controles:** WASD anda, Shift corre, E interage, Esc abre o menu. Como no original, não há pulo no mundo
(os ressaltos pulam sozinhos) nem giro de câmera (o ângulo vem da zona). Em Pallet o jogador anda em
grade, tile a tile (toque vira, segurar anda, empurrar a porta entra). F9 abre o painel do céu.
Na batalha: Espaço pula, 1–4 golpes, Q Poké Ball, E bolsa, Tab troca Pokémon (ou qual dos dois você controla), F modo do aliado, R foge.

### Como testar a arte nova (2026-10-26)

- **Pallet em voxel:** Novo jogo (ou Continuar com o save em Pallet). O jogador acorda no quarto e
  sai na cidade nova: casas de pedra, fonte de três andares na praça, plantação ao lado da casa, lago
  com píer e riacho, flores, borboletas e postes que acendem à noite. A Rota 1 em diante não mudou.
- **Hora e clima:** F9 abre o painel do céu: arraste a hora, mude a velocidade do relógio (ou pause) e
  escolha o clima (Automático, Limpo, Nublado, Encoberto, Chuva, Tempestade, Neve, Neblina leve);
  o botão Raio força um relâmpago. Pela linha de comando: `--hour=21:00`, `--weather=rain`.
- **Gráficos:** Opções > GRÁFICOS (Baixo, Médio, Alto, Ultra; Alto é o padrão) e NÉVOA DO CLIMA
  (Sim/Não), no título ou no menu de pausa.
- **Estádio do treino:** MODO DE TREINAMENTO > Cenário (os 10 ou Aleatório) e Hora
  (Dia, Pôr do sol, Noite). A quadra é de 48 x 28 m com o estádio em volta.

## O que o jogo tem

### Campanha (Pallet até a saída do Mt. Moon)
1. Título → novo jogo com o Prof. Carvalho, gênero, nome do jogador e do rival → acorda no quarto.
2. Pallet: o Professor te barra no mato → laboratório → escolha do inicial (Bulbasaur, Charmander, Squirtle) → batalha com o rival.
3. Viridian: a loja entrega a Encomenda → volta ao laboratório → Pokédex + 5 Poké Balls → abre o norte de Viridian.
4. Rota 22 (rival, uma vez), Rota 2, Floresta de Viridian (5 Bug Catchers), Pewter (guia até o ginásio).
5. Ginásio de Pewter: Camper Liam e Brock → Insígnia da Rocha, TM39, P1400.
6. Rota 3 (abre com a insígnia), Centro do Mt. Moon com o vendedor de Magikarp.
7. Mt. Moon 1F/B1F/B2F: escadas, itens, Equipe Rocket, Supernerd Miguel e a escolha do fóssil Dome ou Helix → saída para a Rota 4 com "Continua...".

### Mundo
- 9 zonas contínuas com streaming: pallet_town, route_1, viridian_city, route_22, route_2, viridian_forest, route_2_north, pewter_city, route_3. Montadas em código a partir de `data/maps/*.json`.
- 22 salas: quarto, casa, casa do rival, laboratório, Centros (Viridian, Pewter, Mt. Moon), lojas (Viridian, Pewter), escola, casas, guaritas da floresta, ginásio e museu de Pewter, Mt. Moon 1F/B1F/B2F.
- Mato alto com a taxa de encontro do original, selvagens visíveis andando (passivos, fogem, agressivos), 6 Pokémon parados que lutam uma vez, treinadores com campo de visão, itens no chão, placas, portas e desníveis.
- Visual do original: modelos HGSS e Kenney, shaders de grama, caminho e água, sprites de NPCs e do jogador, Pokémon da frente seguindo o jogador.
- **Pallet em voxel** (conceito B, "Vila de pedra", `docs/VOXEL.md`): cenário 3D em voxel de 0,25 m e personagens em sprite 2D. Desenho em `data/voxel/pallet_town.json`, gerador em `world/voxel/`, assado em `world/voxel/baked/`. Casas do tamanho dos interiores reais (o interior no lugar fica para depois: a porta ainda leva às salas), praça com fonte, plantação, lago, riacho, estufa do laboratório, varal, bandeira, fumaça nas chaminés, borboletas, cidade iluminada à noite. Só Pallet: da Rota 1 em diante a arte é a do original.
- **Andar em grade** de 1 m nas zonas voxel, só para humanos (jogador, NPCs, treinadores, cenas da Story); Pokémon continuam livres (`world/grid/`, `docs/VOXEL.md` §6).
- **Água nova** (`gfx/water/`): transparente sobre o leito voxel, com refração, espuma, cáusticas, reflexo, anéis de chuva, peixes, folhas e gelo; fonte com jatos, cortinas e respingos (`FountainFx`). As zonas antigas mantêm a água antiga.
- **Céu contínuo** (`world/sky/`): o relógio de 20× move sol e lua sem saltos, com cores por hora, lâmpadas e janelas que acendem e uma luz de preenchimento à noite; um Environment só para o mundo todo.
- **Clima do mundo** (`world/sky/weather.gd`, `gfx/weather/`): limpo, nublado, encoberto, chuva, tempestade com raio e trovão, neve que acumula e neblina leve de manhã, sorteados por dia (o mesmo dia tem sempre o mesmo clima); chão molhado, poças, som de chuva e vento.
- **Níveis gráficos** Baixo / Médio / Alto / Ultra (`world/look/gfx_quality.gd`), nas Opções.

### Batalha (tempo real, como o original)
- Arena no próprio mapa. Cooldown por golpe e global, barra de energia no lugar do PP, fator de Speed, estágios de stat, status com duração em segundos (queimado, envenenado, paralisado, dormindo, confuso, semente, hesitar).
- 14 tipos de entrega de golpe (investida, arco, projétil, raio, área, corrente etc.), acerto geométrico, dano da fórmula oficial Gen 5+ (spread 0,75x na dupla, golpe de alvo único acerta um só), empurrão pela eficácia, arremesso com batida na cerca/caixa, Body Slam pulando em cima, Aerial Ace, Dig por baixo da terra (`battle/battle_physics.gd`, detalhes em `docs/MECANICAS.md`).
- Um treinador atrás de cada lado, troca pela Pokébola na hora (com trava entre trocas), fim de turno oficial uma vez por rodada (`battle/battle_end_turn.gd`) e botões de modo na tela.
- Relógio de rodada (`battle/battle_turns.gd`): a cada 4 s roda o fim de turno oficial e o `round_start` da IA do treinador; guarda também o Trick Room e a ordem pela Speed. Não há fila de golpes. Detalhes em `docs/BATALHA_VIVA.md`.
- **Modo de energia** (único modo de batalha, no treino e na campanha, `battle/battle_energy.gd`): sem turnos nem posições fixas, barra de energia que enche com o tempo no lugar do PP, golpes gastam energia e têm cooldown, e a IA recua para recuperar ou fica lutando. Detalhes em `docs/BATALHA_VIVA.md`.
- IA do original (distância, desvio, escolha pelo menor número de golpes até o KO). 2x1 com aliado nas selvagens (modos Ataque/Defesa/Suporte).
- IA do treinador (`docs/IA_TREINADOR.md`): o treinador troca com matchup ruim, usa item que salva e escolhe quem entra.
- Clima Gen 9 (sol, chuva, areia, neve) por golpe, habilidade ou pedra, com visual próprio: chuva com poças e relâmpago, neve acumulando no chão, feixes de sol e tempestade de areia (`battle/battle_weather_fx.gd`, regras em `docs/MECANICAS.md` §10). A chuva, a neve e o relâmpago usam as peças do clima do mundo (`gfx/weather/`) e cobrem o estádio.
- Captura com a fórmula do original, itens na batalha, item do treinador, XP e EVs divididos, sprites PMD animados, efeitos de cada golpe, HUD do original.

### Modo de treinamento (para balancear)
- Opção **MODO DE TREINAMENTO** no título (`ui/training/`). Não usa nem grava o save do jogo; a montagem fica em `user://training.json`.
- Tela de montar, tudo numa tela sem rolagem: dois times com 6 slots (slot vazio abre a lista de espécies), e por Pokémon natureza, habilidade, 4 golpes escolhidos numa lista só com os que a espécie aprende (em qualquer nível) e HP/PP/status iniciais. Todos lutam no **Nv 50**, com IV 31 e EV 0 (sem IVs e EVs no treino), e qualquer golpe que a espécie aprende vale. Por time, nome, item do treinador, nível da IA (`think_scale`) e **Times salvos** (10 slots em `user://training_teams.json`, para salvar e carregar em qualquer lado); **Times aleatórios** sorteiam só evoluções finais (espécie sem evolução para outra do jogo; 567 das 1025), equilibrados por tipo, com golpes coerentes (`Cfg.random_moves`): um golpe de dano de cada tipo da espécie na categoria do maior ataque (Atk físico, SpA especial), o resto preferindo essa categoria, a outra só com efeito secundário (queimar, paralisar...) e no máximo um golpe de status que valha (status, +2, vários atributos ou cura). Jogador 1 manual ou IA, formato 1x1/2x2, velocidade (0,6x a 4x), turbo, limite de tempo e semente.
- Câmera de ação no modo de energia (`battle/battle_director.gd`): enquadra os Pokémon de perto, hit-stop, zoom e câmera lenta 0,5x só no nocaute de verdade, destaque nos golpes de poder 100+ e todo mundo parado na troca. Depois de um nocaute todos voltam ao ponto de entrada e a luta só recomeça com todos os lugares cheios (`battle/battle_regroup.gd`; detalhes em `docs/BATALHA_VIVA.md`). Cada bola é uma cena: close no treinador que prepara o arremesso, a câmera segue a bola (maior, girando, com rastro, quique e clarão ao abrir) e fecha no Pokémon que se materializa. Toda luta de treino abre com os nomes dos times no telão do estádio, a arena inteira e os treinadores jogando os titulares; só depois do "Fight!" a luta começa (`battle/battle_opening.gd`).
- Arena com relevo 3D (morros, picos, lagos, caixas e pedras; `battle/battle_terrain.gd`, ver `docs/BATALHA_VIVA.md`), um treinador no meio de cada fundo, fora da área de luta. A quadra é uma **quadra voxel de 48 x 28** (o dobro de comprimento e de largura, obstáculos em proporção à área) dentro de um **estádio voxel** (`battle/voxel/`: arquibancada com torcida que comemora e faz ola, refletores, placares ao vivo, túneis, bandeiras), com a opção **Hora** (Dia, Pôr do sol, Noite) na tela de montar. Os dois lados lutam sozinhos com a IA (`opts.autoplay`), sem XP, EVs, prêmio nem evolução (`opts.no_rewards`). Acima de 1x a arena anda em passos de no máximo 1x, para o resultado não mudar com a velocidade.
- Resultado com HP final de cada Pokémon, duração, semente e placar da série; "Rodar série" faz N lutas seguidas (com semente fixa, a luta k usa semente + k) e "Copiar registro" copia o log da luta.

### Progressão e sistemas
- 1025 espécies (a Pokédex nacional inteira), 742 golpes e 285 habilidades, todas com dados da Gen 9 (pipeline: `tools/gen9_new_moves.py` → `tools/gen9_species.py` → `tools/fidelity_check.py --fix`, que confere tudo contra o Showdown e completa os buracos da PokeAPI; golpes da Gen 2-9 em `tools/moves_more_a.py`/`moves_more_b.py` e `battle/battle_more_a.gd`/`battle_more_b.gd`, habilidades novas em `battle/battle_abilities_more.gd`, revisão em `docs/REVISAO_1025.md`). Antes eram 152 espécies (os 151 de Kanto e o Kingdra), 511 golpes, todas com dados da Gen 9: stats, tipos, habilidades normais e ocultas, learnsets completos com nível, TM, ovo e tutor (`tools/gen9_species.py`; golpes e adaptações em `tools/gen9_new_moves.py` e `docs/GOLPES.md`; ver docs/MECANICAS.md), 32 treinadores, 30 itens + 5 bolas, 22 tabelas de encontro (tudo em `data/`). Golpes de Kanto com mecânica própria em `battle/battle_kanto.gd` e Transform/Imposter em `battle/battle_transform.gd`. A arte das 66 espécies novas (PMD SpriteCollab, frente/costas BW, ícones) foi montada por `tools/kanto_sprites.py` e fica em `original/` (fora do git).
- Stats, naturezas, IVs, EVs, 6 curvas de XP, evolução por nível (tela animada, dá para cancelar) e por pedra, aprender e esquecer golpes, TMs, Rare Candy.
- **Exp. Share sempre ligado** (regra da Gen 8/9, sem item): cada participante de pé ganha a EXP cheia do Pokémon derrotado (sem dividir), o resto da party de pé ganha metade (`BattleArena.EXP_SHARE`), desmaiado não ganha. Capturar também dá EXP. No fim da batalha não há mais caixas de confirmação: o **painel de EXP** (`battle/battle_exp_panel.gd`, como o de Scarlet/Violet) mostra a party inteira à direita com a barra enchendo; quem sobe de nível pisca "Level up!" e abre a janela de stats (+N, depois os valores novos). Tudo corre sozinho; E pula. O prêmio e os golpes novos vão para o log.
- Equipe de 6, PC com 8 caixas de 30, loja (compra e venda, Premier Ball de brinde), dinheiro e prêmio de treinador, Pokédex (vistos e capturados), Cartão de Treinador com insígnias, tempo de jogo, save e continuar.
- Telas no visual do original: título, novo jogo com teclado de nomes, menu de pausa (Pokédex, Pokémon, Bolsa, Cartão, Salvar, Opções, Controles), resumo em 3 páginas, PC, evolução, aprender golpe, HUD.
- Som: 24 efeitos e 14 músicas originais gerados em código (não são do original), trocando por lugar e por batalha; chuva, vento e trovão sintetizados (`audio/weather_audio.gd`).

## Arquitetura

Autoloads: `Controls` (input), `Game` (estado, save, ponte mundo↔batalha), `LearnMove`, `PauseMenu`, `Story` (roteiro e flags), `PCStorage`, `Evolution`, `Audio`.

| Pasta | Conteúdo |
|---|---|
| `core/` | Regras puras: `Dex`, `Mon`, `StatCalc`, `Growth`, `Capture`, `Damage`, `Items`, `Game`, `Controls` |
| `battle/` | Arena em tempo real: `battle_arena`, `fighter`, `battle_moves`, `battle_ai`, `battle_hud`, `battle_vfx`, `projectile`; `battle/voxel/` = quadra voxel e estádio do modo de energia |
| `gfx/` | Visual compartilhado: `CreatureSprite` (sprites PMD), `PokemonSprites` (ícones), efeitos, Poké Ball 3D; `voxel/` (núcleo voxel), `water/` (água e fonte), `weather/` (chuva, neve, névoa, raio) |
| `world/` | `RouteWorld` (zonas, streaming, API de salas), `MapBuilder`, `cave_builder`, jogador, câmera, NPCs, treinadores, mato, selvagens; `voxel/` (Pallet), `grid/` (andar em grade), `sky/` (céu, clima, vento), `look/` (ambientes e níveis gráficos), `debug/` (painel F9) |
| `interiors/` | Definição e construção das salas, Centro, loja, PC |
| `story/` | Roteiro, gatilhos, inicial, Pokémon parados, fósseis |
| `ui/` | Kit visual do original e todas as telas |
| `audio/` | Sintetizador e sequenciador das músicas |
| `data/` | JSONs (espécies, golpes, tipos, itens, treinadores, encontros, mapas, salas, hora do dia, clima) |
| `original/` | Arte extraída do original (fora do git) |

Flags de história em `Game.flags`: `got_starter`, `rival_starter`, `has_parcel`, `has_pokedex`, `boulder_badge`/`badge_boulder`, `trainer_<id>`, `static_<uid>`, `mt_moon_cleared`, `mt_moon_fossil` e outras (lista completa em `docs/CONTRATO.md`).

## Testes

Suítes headless em `tests/` (todas as `test_*.gd`: core, game, battle, gfx, audio, ui, ui_front, ui_pc, ui_evolution, ui_training, world, interiors, story, content). Na última rodada todas passaram, menos as falhas conhecidas: `tests/battle/test_ai_plans.gd` falha em "a luta acaba (7: 150 s)" (o duelo Squirtle x Nidoran F em pânico da semente 7 passa do limite de 150 s) e `tests/battle/test_gen9_ai.gd` falha às vezes (intermitente). `tests/gfx/test_gfx.gd` só passa com a arte do original toda em `original/`. Novas da rodada pela Speed: `tests/battle/test_field_use.gd`; do modo de energia: `tests/battle/test_energy.gd`; da IA do treinador: `tests/battle/test_trainer_ai.gd`. Da arte voxel: `tests/world/test_voxel_zone.gd`, `test_grid_motion.gd`, `test_sky.gd`, `test_weather_world.gd`, `tests/gfx/test_water.gd`, `tests/ui_training/test_stadium.gd` (prints com renderização real: `docs/VOXEL.md` §8). O teste do Mt. Moon leva de 10 a 15 minutos.

```bash
"/c/Users/User/Desktop/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --headless --fixed-fps 60 --path . --script res://tests/core/test_core.gd < /dev/null
```

Depois de criar scripts com `class_name` novos, ou depois de chegar arte nova em `original/` (ex.: os sprites de Vulpix, Ninetales, Venonat e Venomoth), rode `--headless --path . --import` uma vez antes dos testes. Abrir o projeto no editor faz a importação sozinho.

## O que falta ou foi simplificado

- Passada de equilíbrio (o Caio pediu para deixar de fora).
- Paredes e escadas do Mt. Moon ainda são caixas; a entrada da caverna não tem modelo.
- O clima é o mesmo no mundo todo ao mesmo tempo (no original as nuvens se deslocam); a camada de copas da floresta não foi portada.
- Só Pallet está em voxel. As casas já têm o tamanho dos interiores, mas o interior no lugar (sem trocar de sala) fica para depois.
- A Rota 4 e Cerulean não existem: a demo termina na saída do Mt. Moon.
- Logo do título copiado do original ("POKéMON BATTLE ADVANCED"), em `ui/front/logo.gd`.
- Batalha online e troca (WebRTC) do original não foram portadas.

## Idioma

- O jogo inteiro está em inglês (termos FireRed/LeafGreen: Prof. Oak, Pallet Town, Route 1, Viridian Forest...). Falas, placas, nomes de NPC, treinadores e classes (`world/trainer_text.gd`), interiores, painel F9, `desc_pt` das habilidades (agora inglês; a chave continua), nomes dos golpes de dupla e do clima ficam em inglês.
- Nomes de móveis dos interiores (`interiors/interior_defs.gd`) são chaves de `InteriorLook.FURNITURE` e `SEATS_FACE`: mudam juntos. As palavras-chave de `WorldNpc.NAME_SHEETS` cobrem os nomes em inglês.
- Teste de texto: `tests/content/test_texts_en.gd` (nenhuma palavra portuguesa nos mapas/treinadores).
