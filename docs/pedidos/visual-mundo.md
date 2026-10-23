# Pedidos do Visual do mundo (Rodada 5)

Nada aqui bloqueia o mundo: todos têm contorno local.

## Núcleo (`project.godot`)

1. **(Opcional) `[shader_globals]`** com os globais do original: `wind_dir` (vec2), `wind_strength`, `wind_gust`,
   `wind_time`, `weather_time`, `weather_px` (float), `weather_origin` (vec2), `main_cam_pos` (vec3),
   `weather_map` (sampler2D). Hoje `world/world_fx.gd` (`WorldFx.ensure_globals`) registra todos em tempo de
   execução antes de carregar qualquer shader de `world/shaders/`; se o projeto declarar, ele só usa os existentes.
   Declarar no projeto evita erros de compilação se algum outro código carregar esses shaders antes do mundo.

## Conteúdo (`interiors/interior_defs.gd`, `data/maps`, `story/`)

1. NPCs das salas aceitam `"sprite": "npc_xxx.png"` (folha 3x4 de `original/assets/sprites/`). Sem ele, o
   `WorldNpc` adivinha pelo papel (marcador `oak`, `mom`, `nurse`, `clerk`...) ou por palavra no nome
   (Enfermeira, Vendedor, Cientista, Menina, Senhor...). Vale pôr `sprite` nos NPCs com nome genérico.
2. Mobília: nomes reconhecidos em `interiors/interior_look.gd` (`FURNITURE`): Planta, Estante, Mesa, Rocha, Banco,
   Prateleira, Carteira, Tapete, TV, Caixa, Cadeira, Vitrine, Videogame, Travesseiro, Escrivaninha, Computador,
   Cama, Bancada, Balcão, Sofá, Geladeira, Fogão, Pia, Lâmpada. Outros nomes (Quadro, Lousa, Plataforma) continuam caixa colorida.
3. `story/starter_ball.gd` ainda desenha a bola com hemisférios próprios; dá para usar `PokeBall3D.create()` de `gfx/`
   (o `world/item_ball.gd` já usa).
4. `tests/world/test_route_pewter.gd` foi ajustado: a Rota 3 agora existe como zona, então tirei as checagens
   "Route 3 not built" e da placa "Em construção" (a placa saiu do `EXTRAS`).
5. Prédios com `"rot"` (Rota 3: Centro Pokémon com rot 180) agora giram porta e chegada junto com o modelo.

## Visual da batalha (`gfx/`, `battle/`)

- O mundo passa `opts.floor = true` quando não há chão sólido 3 m abaixo do jogador (`Overworld._ground_under`).
- Os selvagens e o Pokémon que segue o jogador usam `CreatureSprite` (carregado por caminho, com fallback).
