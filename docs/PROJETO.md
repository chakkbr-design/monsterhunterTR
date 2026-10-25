# PokmemonLike — estado do projeto

Atualizado em 2026-10-24. Jogo em Godot 4.7 (GDScript), feito a partir do estudo do *Pokemon Battle Arena 0.2.0 demo* (fan game em Godot).
**Uso pessoal, não publicar**: usa a arte extraída do original (pasta `original/`, fora do git) e a marca Pokémon.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| `C:\Users\User\Documents\pokmemon-like` | O projeto Godot (repositório git local, sem remoto) |
| `C:\Users\User\Documents\pba-referencia` | Engenharia reversa do original: `codigo/` (164 scripts decompilados), `dados/` (JSONs), `analise/` (3 relatórios), `ferramentas/` (extrator do PCK, decompilador `.gdc`, conversor de arte) |
| `docs/MECANICAS.md` | Regras da batalha oficial atual (dano Gen 5+, crítico, prioridade, dupla, status, clima) e como o jogo adapta cada uma, com o arquivo |
| `docs/GOLPES.md` | Guia golpe por golpe de como cada golpe oficial (Gen 9) foi adaptado ao tempo real; gerado por `tools/move_guide.py` (também gera a página HTML) |
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
(os ressaltos pulam sozinhos) nem giro de câmera (o ângulo vem da zona).
Na batalha: Espaço pula, 1–4 golpes, Q Poké Ball, E bolsa, Tab troca Pokémon (ou qual dos dois você controla), F modo do aliado, R foge.

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
- Visual do original: modelos HGSS e Kenney, shaders de grama, caminho e água, sprites de NPCs e do jogador, Pokémon da frente seguindo o jogador, hora do dia (20× mais rápido) e uma chuva por dia de jogo.

### Batalha (tempo real, como o original)
- Arena no próprio mapa. Cooldown por golpe e global, pool único de PP, fator de Speed, estágios de stat, status com duração em segundos (queimado, envenenado, paralisado, dormindo, confuso, semente, hesitar).
- 14 tipos de entrega de golpe (investida, arco, projétil, raio, área, corrente etc.), acerto geométrico, dano da fórmula oficial Gen 5+ (spread 0,75x na dupla, golpe de alvo único acerta um só), empurrão pela eficácia, arremesso com batida na cerca/caixa, Body Slam pulando em cima, Aerial Ace, Dig por baixo da terra (`battle/battle_physics.gd`, detalhes em `docs/MECANICAS.md`).
- Posições fixas de VGC, um treinador atrás de cada lado, troca pela Pokébola só no começo da rodada, fim de turno oficial uma vez por rodada (`battle/battle_end_turn.gd`) e botões de modo na tela.
- Rodadas pela Speed (`battle/battle_turns.gd`): a cada ~4 s a fila sai pela prioridade do golpe e pela Speed (Trick Room inverte), cada Pokémon solta um golpe na vez dele com 0,8 s de folga entre golpes, e um anel com seta marca quem é o próximo. Fora da vez cada Pokémon fica na posição fixa do seu lado. Detalhes em `docs/BATALHA_VIVA.md`.
- **Modo de energia** (padrão no treino, `battle/battle_energy.gd`): sem rodadas nem posições fixas, barra de energia que enche com o tempo no lugar do PP, golpes gastam energia e têm cooldown, e a IA recua para recuperar ou fica lutando. Detalhes em `docs/BATALHA_VIVA.md`.
- IA do original (distância, desvio, escolha pelo menor número de golpes até o KO). 2x1 com aliado nas selvagens (modos Ataque/Defesa/Suporte).
- IA no estilo VGC (`docs/IA_VGC.md`): cada Pokémon escolhe golpe e alvo por pontuação (KO, super efetivo, foco com o parceiro, Protect, Tailwind) e o treinador troca, usa item e escolhe quem entra.
- Clima Gen 9 (sol, chuva, areia, neve) por golpe, habilidade ou pedra, com visual próprio: chuva com poças e relâmpago, neve acumulando no chão, feixes de sol e tempestade de areia (`battle/battle_weather_fx.gd`, regras em `docs/MECANICAS.md` §10).
- Captura com a fórmula do original, itens na batalha, item do treinador, XP e EVs divididos, sprites PMD animados, efeitos de cada golpe, HUD do original.

### Modo de treinamento (para balancear)
- Opção **MODO DE TREINAMENTO** no título (`ui/training/`). Não usa nem grava o save do jogo; a montagem fica em `user://training.json`.
- Tela de montar, tudo numa tela sem rolagem: dois times com 6 slots (slot vazio abre a lista de espécies), e por Pokémon natureza, habilidade, 4 golpes escolhidos numa lista só com os que a espécie aprende (em qualquer nível) e HP/PP/status iniciais. Todos lutam no **Nv 50**, com IV 31 e EV 0 (sem IVs e EVs no treino), e qualquer golpe que a espécie aprende vale. Por time, nome, item do treinador, nível da IA (`think_scale`) e **Times salvos** (10 slots em `user://training_teams.json`, para salvar e carregar em qualquer lado); **Times aleatórios** sorteiam só evoluções finais (espécie sem evolução para outra do jogo; 567 das 1025), equilibrados por tipo, com golpes coerentes (`Cfg.random_moves`): um golpe de dano de cada tipo da espécie na categoria do maior ataque (Atk físico, SpA especial), o resto preferindo essa categoria, a outra só com efeito secundário (queimar, paralisar...) e no máximo um golpe de status que valha (status, +2, vários atributos ou cura). Jogador 1 manual ou IA, formato 1x1/2x2, modo Energia/VGC, velocidade (0,6x a 4x), turbo, limite de tempo e semente.
- Arena fixa 24 x 14 com cerca e relevo 3D espelhado (morros, picos, lagos, caixas e pedras; `battle/battle_terrain.gd`, ver `docs/BATALHA_VIVA.md`), um treinador no meio de cada fundo, fora da área de luta. Os dois lados lutam sozinhos com a IA (`opts.autoplay`), sem XP, EVs, prêmio nem evolução (`opts.no_rewards`). Acima de 1x a arena anda em passos de no máximo 1x, para o resultado não mudar com a velocidade.
- Resultado com HP final de cada Pokémon, duração, semente e placar da série; "Rodar série" faz N lutas seguidas (com semente fixa, a luta k usa semente + k) e "Copiar registro" copia o log da luta.

### Progressão e sistemas
- 1025 espécies (a Pokédex nacional inteira), 742 golpes e 285 habilidades, todas com dados da Gen 9 (pipeline: `tools/gen9_new_moves.py` → `tools/gen9_species.py` → `tools/fidelity_check.py --fix`, que confere tudo contra o Showdown e completa os buracos da PokeAPI; golpes da Gen 2-9 em `tools/moves_more_a.py`/`moves_more_b.py` e `battle/battle_more_a.gd`/`battle_more_b.gd`, habilidades novas em `battle/battle_abilities_more.gd`, revisão em `docs/REVISAO_1025.md`). Antes eram 152 espécies (os 151 de Kanto e o Kingdra), 511 golpes, todas com dados da Gen 9: stats, tipos, habilidades normais e ocultas, learnsets completos com nível, TM, ovo e tutor (`tools/gen9_species.py`; golpes e adaptações em `tools/gen9_new_moves.py` e `docs/GOLPES.md`; ver docs/MECANICAS.md), 32 treinadores, 30 itens + 5 bolas, 22 tabelas de encontro (tudo em `data/`). Golpes de Kanto com mecânica própria em `battle/battle_kanto.gd` e Transform/Imposter em `battle/battle_transform.gd`. A arte das 66 espécies novas (PMD SpriteCollab, frente/costas BW, ícones) foi montada por `tools/kanto_sprites.py` e fica em `original/` (fora do git).
- Stats, naturezas, IVs, EVs, 6 curvas de XP, evolução por nível (tela animada, dá para cancelar) e por pedra, aprender e esquecer golpes, TMs, Rare Candy.
- Equipe de 6, PC com 8 caixas de 30, loja (compra e venda, Premier Ball de brinde), dinheiro e prêmio de treinador, Pokédex (vistos e capturados), Cartão de Treinador com insígnias, tempo de jogo, save e continuar.
- Telas no visual do original: título, novo jogo com teclado de nomes, menu de pausa (Pokédex, Pokémon, Bolsa, Cartão, Salvar, Opções, Controles), resumo em 3 páginas, PC, evolução, aprender golpe, HUD.
- Som: 20 efeitos e 10 músicas originais gerados em código (não são do original), trocando por lugar e por batalha.

## Arquitetura

Autoloads: `Controls` (input), `Game` (estado, save, ponte mundo↔batalha), `LearnMove`, `PauseMenu`, `Story` (roteiro e flags), `PCStorage`, `Evolution`, `Audio`.

| Pasta | Conteúdo |
|---|---|
| `core/` | Regras puras: `Dex`, `Mon`, `StatCalc`, `Growth`, `Capture`, `Damage`, `Items`, `Game`, `Controls` |
| `battle/` | Arena em tempo real: `battle_arena`, `fighter`, `battle_moves`, `battle_ai`, `battle_hud`, `battle_vfx`, `projectile` |
| `gfx/` | Visual compartilhado: `CreatureSprite` (sprites PMD), `PokemonSprites` (ícones), efeitos, Poké Ball 3D |
| `world/` | `RouteWorld` (zonas, streaming, API de salas), `MapBuilder`, `cave_builder`, jogador, câmera, NPCs, treinadores, mato, selvagens, céu e clima |
| `interiors/` | Definição e construção das salas, Centro, loja, PC |
| `story/` | Roteiro, gatilhos, inicial, Pokémon parados, fósseis |
| `ui/` | Kit visual do original e todas as telas |
| `audio/` | Sintetizador e sequenciador das músicas |
| `data/` | JSONs (espécies, golpes, tipos, itens, treinadores, encontros, mapas, salas, hora do dia, clima) |
| `original/` | Arte extraída do original (fora do git) |

Flags de história em `Game.flags`: `got_starter`, `rival_starter`, `has_parcel`, `has_pokedex`, `boulder_badge`/`badge_boulder`, `trainer_<id>`, `static_<uid>`, `mt_moon_cleared`, `mt_moon_fossil` e outras (lista completa em `docs/CONTRATO.md`).

## Testes

Suítes headless em `tests/` (todas as `test_*.gd`), todas passando na última rodada (core, game, battle, gfx, audio, ui, ui_front, ui_pc, ui_evolution, ui_training, world, interiors, story, content). Novas da rodada pela Speed: `tests/battle/test_turns.gd` e `tests/battle/test_field_use.gd`; do modo de energia: `tests/battle/test_energy.gd` (`-- vgc` roda as mesmas lutas no VGC para comparar). O teste do Mt. Moon leva de 10 a 15 minutos.

```bash
"/c/Users/User/Desktop/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --headless --fixed-fps 60 --path . --script res://tests/core/test_core.gd < /dev/null
```

Depois de criar scripts com `class_name` novos, ou depois de chegar arte nova em `original/` (ex.: os sprites de Vulpix, Ninetales, Venonat e Venomoth), rode `--headless --path . --import` uma vez antes dos testes. Abrir o projeto no editor faz a importação sozinho.

## O que falta ou foi simplificado

- Passada de equilíbrio (o Caio pediu para deixar de fora).
- Paredes e escadas do Mt. Moon ainda são caixas; a entrada da caverna não tem modelo.
- Chuva única para o mundo todo (no original as nuvens se deslocam); a camada de copas da floresta não foi portada.
- A Rota 4 e Cerulean não existem: a demo termina na saída do Mt. Moon.
- Logo do título copiado do original ("POKéMON BATTLE ADVANCED"), em `ui/front/logo.gd`.
- Batalha online e troca (WebRTC) do original não foram portadas.
