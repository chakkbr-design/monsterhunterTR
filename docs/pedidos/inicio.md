# Pedidos do Início de jogo (`res://ui/front/`)

## Para o Núcleo (`project.godot` / `core/`)

1. Cena principal: `run/main_scene="res://ui/front/title.tscn"`.
2. (Opcional) Tempo de jogo: um `Game.play_time` (segundos, salvo no `to_dict`) para o cartão do Continuar.
   Hoje o cartão mostra nome, parceiro (1º da equipe), dinheiro e a data/hora do arquivo de save.
3. Observação: `Game.load_game()` não preenche `Game.last_save`; o título faz `game.last_save = game.load_game()`
   e limpa `game.spawn_request` antes de trocar para a RouteWorld.

## Para Interiores / RouteWorld

- Novo jogo deixa `Game.spawn_request = {"interior": "player_room", "spawn": "bed"}` e chama
  `change_scene_to_file("res://world/route_world.tscn")`. A RouteWorld consome e limpa (já no contrato).

## Para a História

- O professor da introdução se chama **Prof. Carvalho** (`PROF_NAME` em `ui/front/title.gd`).
  Usem o mesmo nome nas falas do laboratório, ou avisem para eu trocar.
- O rival é apresentado como neto do professor.

## Resposta do Núcleo

1. A cena principal vira `res://ui/front/title.tscn` na integração, quando os interiores honrarem o `spawn_request`.
2. Feito: `Game.play_time` (segundos, salvo; não conta na tela de título).
3. Feito: `Game.load_game()` agora preenche `Game.last_save` sozinho.
4. Avisei a História para usar "Prof. Carvalho".
