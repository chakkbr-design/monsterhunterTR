# Pedidos do Overworld

Pedidos da parte Overworld (`res://world/`) para o Núcleo e a Arena. Nenhum bloqueia o mapa de teste hoje.

## Para o Núcleo (`core/game.gd`)

1. **Prêmio em dinheiro de treinador.** Hoje ninguém paga o prêmio ao vencer um treinador.
   Sugestão: em `_on_arena_finished`, se `outcome == "win"` e `opts.kind == "trainer"`, somar a `Game.money`
   o `reward` de `Dex.trainer(id)` ou `TRAINER_PAYOUTS[class] × nível do último mon` (como na referência).
   Isso exige que o Game guarde os `opts` recebidos em `request_battle`. O caminho sem arena (vitória instantânea) também deveria pagar.
2. **Flag de treinador vencido.** O overworld grava `Game.flags["trainer_<id>"] = true` quando o resultado é `win`
   (mesma chave da referência). Se o Núcleo preferir fazer isso em `_on_arena_finished`, me avise que eu tiro do `world/trainer.gd`.
3. **(Opcional) Marcar como visto na Pokédex** ao começar a batalha (`mark_seen`), quando existir.

## Para a Arena (`battle/battle_arena.tscn`)

- Durante a batalha, o overworld **esconde** o placeholder do mon selvagem (cápsula em `world/wild_mon.gd`) e o libera
  depois, a não ser que o resultado seja `run` (aí ele reaparece com 4 s de paz). A arena deve criar o corpo do inimigo
  a partir de `enemies[0]` (o `Mon`), sem procurar um nó do overworld.
- O jogador do overworld fica parado enquanto `Game.is_busy()`. A câmera do overworld (`world/camera_rig.gd`) continua
  seguindo o jogador por baixo; a arena pode usar `make_current()` na própria câmera e devolver a anterior no fim.
- `host` = raiz do mapa (`Overworld`, um `Node3D`), `at` = posição do jogador.

## Resposta do Núcleo

1. Feito: `Game` guarda os `opts` e paga o prêmio ao vencer treinador (`reward` do JSON ou base da classe × nível do último Pokémon), inclusive sem arena. O valor volta em `result.prize`.
2. O `Game` também grava `flags["trainer_<id>"]`. Gravar de novo no `world/trainer.gd` é inofensivo.
3. Feito: `Game.seen` / `Game.caught` (marcados no início da batalha e na captura) e salvos no save.

## Rodada 2 — mapa real (`world/route_world.tscn`)

Pronto: `world/map_builder.gd` (`MapBuilder`) constrói uma zona a partir de `data/maps/<zona>.json` (chão, caminhos,
terraços com penhasco/rampas/ledges de mão única, água, prédios-caixa com porta "Fechado.", cercas, árvores, props,
mato alto com a tabela da zona, spawn zones com o `mode` da tabela (inclusive `swim` na água), placas, NPCs, itens
visíveis e paredes de borda). `world/route_world.tscn` (`RouteWorld`) junta Pallet Town + Route 1 + Viridian City com
streaming por distância (40 m, como o `zone_streamer`). O jogador nasce no `start` de Pallet (`data/world.json`).
O mapa antigo continua em `world/overworld.tscn`.

### Para o Núcleo (integrador)

1. **Cena principal:** trocar `run/main_scene` para `res://world/route_world.tscn` (o `CONTRATO.md` ainda diz `overworld.tscn`).
2. **(Opcional) Nomes do jogador/rival:** as falas do mapa usam `{PLAYER}`/`{RIVAL}`. O mapa lê `Game.player_name` e
   `Game.rival_name` se existirem; hoje cai em "RED"/"BLUE".
3. **(Opcional) Salvar posição:** quando houver menu de salvar, o mapa pode passar `{"zone": RouteWorld.active_zone,
   "pos": [x, y, z]}` em `Game.save_game(extra)`. Me avisem o formato que eu leio no `_ready`.
4. **Flags usadas pelo mapa:** `item_<uid>` (item pego), `trainer_<id>` (já existe), `has_pokedex` (abre a parede
   norte de Viridian; ninguém grava ainda). NPCs com `requires_flag`/`hidden_by_flag` seguem essas flags.

### Para a Arena

- Em `route_world` o `host` é a raiz `RouteWorld` e `at` é a posição do jogador, que pode estar num terraço (y 0.9 a 6.0)
  ou perto de prédios/árvores. Se a arena precisar de chão plano, use o `y` de `at` como piso.
- Camadas de colisão do mundo: 1 = chão/paredes, 2 = jogador, 4 = mons selvagens, 8 = NPCs, 16 = água.
