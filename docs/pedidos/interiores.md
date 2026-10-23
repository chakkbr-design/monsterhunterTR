# Pedidos dos Interiores (`res://interiors/`, `res://world/`)

## O que está pronto (Rodada 3)

- Salas montadas em código dentro da `RouteWorld`, em `x >= 10000` (`InteriorDefs.BASE`, 40 m entre salas):
  `player_room`, `player_house`, `rival_house`, `oak_lab`, `pokemon_center_viridian`, `mart_viridian`,
  `trainer_school_viridian`, `viridian_house`. Definições em `interiors/interior_defs.gd`.
- Portas do mapa (`door.target_spawn` do `data/maps/*.json`) → sala (`InteriorDefs.DOOR_TARGETS`). Tapete de saída
  (andar em cima) → volta para o `spawn` da porta. Escada quarto ↔ sala.
- API na `RouteWorld`: `go_to_interior(id, spawn = "door")`, `go_to_zone(zone, spawn)` (com fade; `fade_time`),
  `signal location_changed(kind, id)`, `marker(interior_id, nome) -> Node3D`, `interior(id)`, `location_kind`/`location_id`,
  `save_extra()`, `set_interact_hook(interior_id, papel, callable)`.
- `Game.spawn_request` respeitado e limpo; prioridade `spawn_request` > `last_save` > `world.json`.
  Com `spawn_request` ou save, a RouteWorld não cria mais o Bulbasaur de teste.
- Batalha com `opts.scripted` não manda para o ponto de cura. Derrota normal → `Game.flags.last_heal`
  (gravado pela Enfermeira/Mamãe), padrão `player_house`.

## Para a UI (`ui/pause_menu.gd`) — já atendido pela UI

- Salvar passa `Overworld.of(...).save_extra()` (`{"pos": [x,y,z], "zone"|"interior": id}`) para `Game.save_game(extra)`.
  O formato antigo `{"pos"}` também funciona (a posição dentro de uma sala é reconhecida pelas coordenadas).

## Para o Núcleo (`docs/CONTRATO.md`)

1. Documentar no contrato: `save_extra()`, `set_interact_hook()` (ganchos de NPC das salas, papel = nome do marcador:
   `clerk`, `nurse`, `mom`, `pc`, ...; o callable recebe o NPC, pode ser corrotina e, se devolver `true`, pula o padrão),
   `Game.flags.last_heal` e os ids extras de sala (`rival_house`, `trainer_school_viridian`, `viridian_house`).
2. (Opcional) `Game.heal_party()` poderia também limpar `status` e PP — hoje chama `Mon.heal_full()`, que já basta se cobrir os dois.
3. (Opcional) PC de armazenamento (`Game.pc`): o terminal só mostra uma fala; quando houver UI de caixa, o `PcTerminal`
   (`interiors/pc_terminal.gd`) pode abrir ela.
