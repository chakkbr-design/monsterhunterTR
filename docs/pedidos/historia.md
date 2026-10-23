# Pedidos da História (`res://story/`)

Nada aqui bloqueia: a história já contorna cada ponto localmente.

## Núcleo (`project.godot`, `docs/CONTRATO.md`)

1. **Registrar o autoload** `Story="*res://story/story.gd"` (depois de `Game`).
2. **CONTRATO**: documentar as flags da história em `Game.flags`: `oak_stopped`, `got_starter` (+ `starter_chosen`,
   o nome usado no `triggers` do `pallet_town.json`), `rival_battle_done`, `rival_battle_won`, `mom_healed`,
   `has_parcel` (fica `false` depois da entrega), `has_pokedex`, `parcel_delivered`. Itens: `oaks_parcel`, `pokedex`.
3. **Flag `trainer_<id>` em batalha de roteiro**: `Game._finish` grava `trainer_rival_blue_route22` ao vencer a
   primeira luta do laboratório (que usa esse `trainer_id` como pedido). A história apaga a flag logo depois para o
   rival da Rota 22 continuar valendo. Sugestão: não gravar `trainer_<id>` quando `opts.scripted` for verdadeiro.

## Interiores / Overworld (`res://world/`)

4. **Jogador parado durante cena**: a história usa `player.locked = true`. Se preferirem, `OverworldPlayer.can_act()`
   pode consultar também `/root/Story.is_running()` (mesmo padrão de `LearnMove`/`PauseMenu`).
5. **Gatilhos dos mapas**: a história cria seus próprios `StoryTrigger` a partir de `triggers` dos
   `data/maps/*.json` (hoje só `oak_stop`). Se o `MapBuilder` um dia construir `triggers`, avisar para não duplicar.

## UI (`res://ui/`)

6. **PauseMenu durante cena**: `PauseMenu.open()` deveria recusar enquanto `/root/Story.is_running()`.
