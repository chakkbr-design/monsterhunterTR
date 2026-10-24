# Contrato entre as partes do port

Projeto Godot 4.7 em **GDScript** (não usar C#). Referência do jogo original, só para leitura:
`C:\Users\User\Documents\pba-referencia` (código decompilado em `codigo/scripts`, análises em `analise/`).
Não copiar arte, sons nem modelos do jogo original: usar placeholders próprios (meshes simples, cores, Label3D).

Godot para testes headless:
`C:\Users\User\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`

## Donos de pasta (ninguém escreve na pasta do outro)

| Pasta | Dono | Conteúdo |
|---|---|---|
| `res://core/`, `res://data/`, `res://tests/core/`, `project.godot` | Núcleo | regras, dados, estado do jogo, autoloads, controles |
| `res://battle/`, `res://tests/battle/` | Arena | batalha em tempo real |
| `res://world/`, `res://tests/world/` | Overworld | jogador, câmera, mapa de teste, mato alto, encontros |

Precisa de algo novo no núcleo ou no `project.godot`? Escreva o pedido em `docs/pedidos/<sua-parte>.md`
e contorne localmente até ele existir. Não edite `core/` nem `project.godot`.

## Autoloads (registrados pelo Núcleo)

- `Controls` (`core/controls.gd`): cria o input map em código no `_ready`.
  Ações: `move_left` `move_right` `move_forward` `move_back` (WASD e setas), `jump` (Espaço),
  `sprint` (Shift), `interact` (E), `move_1`..`move_4` (teclas 1-4), `throw_ball` (Q),
  `swap_mon` (Tab), `run_away` (R), `pause` (Esc), `cam_left`/`cam_right` (Z/C), `ally_mode` (F).
- `Game` (`core/game.gd`): estado do jogador e ponte overworld ↔ batalha.

## API do núcleo (classes com `class_name`, funções estáticas onde indicado)

- `Dex` (estático): `species(id) -> Dictionary`, `move(id) -> Dictionary`, `item(id) -> Dictionary`,
  `effectiveness(atk_type: String, def_types: Array) -> float`, `moves_at(species, level) -> Array`,
  `pp_cost(move) -> float`, `cooldown(move) -> float`, `encounter_table(area) -> Dictionary`, `trainer(id) -> Dictionary`.
- `StatCalc` (estático): `stat(...)`, `stage_mult(stage)`, `acc_stage_mult(stage)`, `crit_chance(stage)`,
  `battle_speed_factor(mine, theirs)`, constantes `CRIT_MULT`, `STATS`.
- `Growth` (estático): `exp_for_level(rate, n)`, `level_for_exp(rate, xp)`, `exp_gain(base_exp, level, winner_level, trainer)`.
- `Capture` (estático): `throw_ball(max_hp, hp, catch_rate, ball_id, status, level) -> {a, shakes, caught}`, `catch_chance(a)`.
- `Damage` (estático): `compute(attacker: Dictionary, defender: Dictionary, move: Dictionary, rng = null) -> Dictionary`.
  `attacker`/`defender` = `{level, types, atk, def, spa, spd, crit_stage, burned, terrain_mult}` (stats já com estágios aplicados).
  Retorna `{damage: int, eff: float, crit: bool, stab: bool}`. Golpe com `power` 0 retorna dano 0.
- `Mon` (RefCounted): `Mon.create(species, level, rng = null)`, campos `species nickname level nature ivs evs stats hp status pp moves xp`,
  propriedades `max_hp types display_name`, `stat(k)`, `is_fainted()`, `heal_full()`, `add_exp(n) -> Array` (eventos),
  `exp_yield(winner_level, trainer)`, `add_evs(d)`, `to_dict()`, `Mon.from_dict(d)`.

## Ponte overworld ↔ batalha (`Game`)

- `Game.party: Array` (de `Mon`), `Game.bag: Dictionary` (id -> quantidade), `Game.money: int`.
- `Game.request_battle(enemies: Array, opts: Dictionary, host: Node3D, at: Vector3)`
  - `opts`: `{kind: "wild" | "trainer", trainer_id?: String, can_run: bool}`.
  - O Game instancia `res://battle/battle_arena.tscn` como filho de `host`, na posição `at`,
    e chama `arena.start(Game.party, enemies, opts)`. Se a cena não existir, resolve na hora com `{outcome: "win"}`.
  - Emite `Game.battle_started` e, quando a arena emitir `finished(result)`, emite `Game.battle_finished(result)`.
- `result`: `{outcome: "win" | "lose" | "run" | "caught", caught_mon?: Mon}`. XP e EVs já aplicados pela arena aos `Mon` da party.
- `Game.is_busy() -> bool`: verdadeiro durante batalha. O jogador do overworld não anda enquanto for verdadeiro.

### Contrato da cena da arena (`res://battle/battle_arena.tscn`, raiz `Node3D`)

- `func start(player_party: Array, enemies: Array, opts: Dictionary) -> void`
- `signal finished(result: Dictionary)`
- A arena cria a própria câmera de batalha e devolve a câmera anterior ao terminar.
- A arena controla o Pokémon ativo do jogador; o avatar do treinador no overworld fica parado.

## Adições do núcleo (já prontas)

- `Items` (estático): `can_use(id, mon)`, `use(id, mon) -> String` (texto do que aconteceu).
- `Game.add_item(id, n)`, `Game.take_item(id, n) -> bool`, `Game.use_item(id, mon) -> String` (desconta da bolsa, menos TM).
- `Game.save_game(extra := {})` / `Game.load_game() -> Dictionary` em `user://save.json`. Use `extra` para a posição do jogador.
- `StatCalc.acc_stage_mult(stage)` está em `StatCalc` (não em `Damage`).
- Testes: `tests/core/test_core.gd` e `tests/core/test_game.gd`. Em teste headless, não use `root.get_node("/root/Game")` no `_initialize`; instancie `load("res://core/game.gd").new()`.

## Integração (estado atual)

- `opts` extras lidos só pela arena: `autoplay: bool` (IA controla o seu Pokémon), `seed: int`, `speed: float`, `ball: String`.
- `result` traz também `exp: [{mon, amount, events}]`, `prize: int` (treinador vencido) e `evolved: [[de, para]]`.
- Depois da batalha o `Game` evolui quem ficou com evolução por nível pendente.
- A arena grava em cada `Mon` o HP, o pool de PP e o status persistente.
- Pendentes: tela de esquecer golpe (eventos `learned: false`), itens durante a batalha, batalha 2x1 com aliado.
- Cena principal: `res://world/route_world.tscn` (Pallet, Rota 1 e Viridian). O mapa de teste continua em `res://world/overworld.tscn`.
- Continuar: o `Game` carrega `user://save.json` no início (`Game.last_save`) e a `RouteWorld` põe o jogador em `last_save.pos`.

## Rodada 2 (pendentes) — donos de pasta

| Pasta | Dono |
|---|---|
| `res://core/`, `res://data/`, `project.godot`, `docs/CONTRATO.md` | Núcleo (integrador) |
| `res://ui/`, `res://tests/ui/` | UI (tela de esquecer golpe, menu de bolsa/party fora da batalha) |
| `res://battle/`, `res://tests/battle/` | Arena (itens na batalha, 2x1 com aliado) |
| `res://world/`, `res://tests/world/` | Mapa (rota real construída a partir de `data/maps/*.json`) |

### Fila de golpes (núcleo, já pronto)

- `Game.pending_learns: Array` de `{mon: Mon, move: String}` e `signal Game.learn_requested`.
- O `Game` enche a fila sozinho: golpes `learned:false` do `result.exp`, golpes que a evolução não coube, TM com 4 golpes e Rare Candy.
- `Game.queue_learn(mon, move)` (aprende direto se houver espaço), `Game.resolve_learn(slot)`: 0..3 troca aquele golpe, -1 desiste.
- A UI fica em `res://ui/learn_move_ui.gd` (um `CanvasLayer`), que o Núcleo registra como autoload `LearnMove`.
  Ela escuta `Game.learn_requested` e resolve a fila inteira. Enquanto aberta, `LearnMove.is_open()` é verdadeiro e o jogador do overworld não anda.

### Mapas

- `data/maps/*.json` (geometria das rotas do original) e `data/world.json` (zonas). Esquema documentado em
  `pba-referencia/analise/03-arquitetura-mundo.md`.
- Rodada 2 da arena (pronto): bolsa rápida na batalha (E), item de treinador (campo `item` do trainers.json ou `opts.trainer_item`), 2x1 com aliado em batalha selvagem (Tab troca o controle, F muda o modo ATAQUE/DEFESA/SUPORTE). Opts novos: `battle_size` (1 desliga o aliado), `trainer_item`, `game` (injeção em testes).

## Rodada 3 — interiores, história e início de jogo

| Pasta | Dono |
|---|---|
| `core/`, `data/`, `project.godot`, `docs/CONTRATO.md` | Núcleo |
| `interiors/`, `tests/interiors/`, e também `world/` (portas e ligação com a RouteWorld) | Interiores |
| `story/`, `tests/story/` | História |
| `ui/front/`, `tests/ui_front/` | Início de jogo |

### Núcleo (pronto)

- `Game.player_name`, `Game.rival_name`, `Game.player_gender` (salvos). `Game.fill_names(texto)` troca `{PLAYER}`/`{RIVAL}`.
- `Game.new_game(nome, rival, genero)` zera o estado. `Game.has_save()`.
- `Game.STARTERS` (Bulbasaur, Charmander, Squirtle), `Game.choose_starter(especie) -> Mon`: põe na equipe, grava `flags.starter` e `flags.rival_starter` (lido pelo `@rival_starter` do trainers.json).
- `Game.spawn_request: Dictionary` = `{zone, spawn}` ou `{interior, spawn}`: onde a RouteWorld deve pôr o jogador ao abrir. Ela consome e limpa.
- Prioridade ao abrir a RouteWorld: `spawn_request` > `last_save` > início do `world.json`.
- `data/interiors/pallet.json` e `viridian.json`: manifestos das salas do original (rect, spawns, next).
- `opts.scripted: true` na batalha: perder não custa dinheiro (o time é curado). O mundo decide se manda para o ponto de cura.
- Treinadores com item: brock e misty (`super_potion`), rival (`potion`).

### API dos Interiores (dono: Interiores; História e Início dependem dela)

- Salas montadas em código dentro da própria RouteWorld (não trocar de cena), longe do mapa externo; portas teletransportam com fade.
- Na RouteWorld (classe `RouteWorld`):
  - `go_to_interior(interior_id: String, spawn: String)` e `go_to_zone(zone: String, spawn: String)`.
  - `signal location_changed(kind: String, id: String)`, onde `kind` é `"zone"` ou `"interior"`.
  - `marker(interior_id: String, name: String) -> Node3D`: pontos nomeados nas salas para a história usar.
- Ids mínimos de sala: `player_room` (quarto, spawn `bed`), `player_house` (Mamãe), `oak_lab` (3 mesas de Pokébola nos marcadores `ball_1..3`, `oak`, `rival`), `pokemon_center_viridian`, `mart_viridian` (marcador `clerk`), `pokemon_center_pewter` opcional.
  O Centro Pokémon cura no balcão (`Game.heal_party`). A loja vende pelo `data/shops.json`, debitando `Game.money`.

### História (dono: História) — autoload `Story` em `res://story/story.gd`

- Roteiro FRLG simplificado, guiado por `Game.flags`: sair de casa → Oak barra no mato alto de Pallet → laboratório → escolher inicial (`Game.choose_starter`, UI própria em `story/`) → batalha com o rival (`trainer_id` `rival_blue_route22`, com a party do rival a partir de `flags.rival_starter`) → Viridian Mart entrega `oaks_parcel` → volta ao Oak → `flags.has_pokedex = true` e algumas Poké Balls.
- Enquanto uma cena da história roda, `Story.is_running()` é verdadeiro e o jogador não anda.

### Início de jogo (dono: Início) — cena principal `res://ui/front/title.tscn`

- Título: Continuar (só se `Game.has_save()`), Novo jogo, Sair.
- Novo jogo: fala do Oak, escolha de gênero, nome do jogador, nome do rival → `Game.new_game(...)` →
  `Game.spawn_request = {"interior": "player_room", "spawn": "bed"}` → `change_scene_to_file("res://world/route_world.tscn")`.
- Continuar: `Game.load_game()` (o `last_save` é preenchido) → muda para a RouteWorld.

### Flags da história (dono: História)

`oak_stopped`, `got_starter`, `starter_chosen`, `rival_battle_done`, `rival_battle_won`, `mom_healed`, `has_parcel`, `has_pokedex`, `parcel_delivered`.
Batalha com `opts.scripted` não grava `trainer_<id>`. O menu de pausa não abre durante uma cena da história.

### Interiores (pronto)

- Salas em `interiors/`, dentro da RouteWorld em x ≥ 10000: player_room, player_house, rival_house, oak_lab, pokemon_center_viridian, mart_viridian, trainer_school_viridian, viridian_house.
- RouteWorld: `await go_to_interior(id, spawn)`, `await go_to_zone(zone, spawn)`, `location_changed(kind, id)`, `marker(id, nome)`, `save_extra()` (usado pelo menu ao salvar), `set_interact_hook(sala, papel, cb)`.
- `Game.flags.last_heal`: onde o jogador volta ao perder. Curar usa `Mon.heal_full` (HP, PP e status).
- O jogador do mundo não anda enquanto `Story.is_running()`.
- Cena principal: `res://ui/front/title.tscn`.

## Rodada 4 — até Pewter, PC, evolução, som

| Pasta | Dono |
|---|---|
| `core/`, `data/`, `project.godot`, `docs/CONTRATO.md` | Núcleo |
| `world/`, `interiors/`, `story/`, `tests/world/`, `tests/interiors/`, `tests/story/` | Mapa (Rota 22, Rota 2, Floresta de Viridian, Pewter, ginásio) |
| `ui/pc/`, `tests/ui_pc/` | PC |
| `ui/evolution/`, `tests/ui_evolution/`, e também `ui/learn_move_ui.gd` (só para esperar a evolução) | Evolução |
| `audio/`, `tests/audio/`; pode acrescentar chamadas de uma linha a `Audio` em `battle/`, `ui/front/`, `ui/pause_menu.gd`, `ui/learn_move_ui.gd` | Som |

Autoloads novos que o Núcleo registra na integração: `PCStorage` (`res://ui/pc/pc_storage.gd`), `Evolution` (`res://ui/evolution/evolution_ui.gd`), `Audio` (`res://audio/audio.gd`).
Quem chama um autoload de outra parte usa `get_node_or_null("/root/<Nome>")`, para não quebrar testes sem ele.

### Núcleo (pronto)

- PC: `Game.pc` (lista única, `BOX_SIZE` 30 × `BOX_COUNT` 8), `deposit(i_equipe)` (recusa deixar a equipe sem Pokémon de pé), `withdraw(i_pc)`, `release(i_pc)`, `swap_party(a, b)`, `pc_full()`. Captura com equipe cheia já vai para o PC.
- Evolução: `Game.pending_evolutions` + `signal evolution_requested` (emitido depois de `battle_finished`). `Game.resolve_evolution(mon, aceitar)`: aceitar evolui e põe golpes que não couberam na fila de aprender; recusar cancela até o próximo nível.
  Sem o autoload `Evolution`, o Game evolui na hora (comportamento antigo, usado nos testes headless).
- A tela de aprender golpe deve esperar enquanto `Evolution.is_open()` ou houver evolução pendente.
- Evolução no próprio Pokémon (o original: evolution.gd): `Evolution.begin_on(mon, creature_sprite, game, {driven, auto, popup})`
  evolui no sprite com um painel pequeno embaixo e emite `finished(evoluiu)`. A arena chama no lutador controlado
  (a cada 0,4 s em "fight"; a luta fica parada; na selvagem o fim vem antes) e avança com `tick(dt)`. No mundo a
  fila usa o sprite do `WorldFollower` quando o Pokémon é o líder; os outros caem na tela cheia.
- Dados novos: `data/interiors/pewter.json`, `viridian_forest.json`. Mapas de route_22, route_2, route_2_north, viridian_forest e pewter_city já estão em `data/maps/`.

### Rodada 4 (pronto)

- Zonas: pallet_town, route_1, viridian_city, route_22, route_2, viridian_forest, route_2_north, pewter_city. A saída leste de Pewter (Rota 3) segue fechada.
- Salas novas: guaritas da floresta (com saída de trás), pokemon_center_pewter, mart_pewter, pewter_gym (Brock e Camper Liam), pewter_museum, pewter_house1, pewter_house2.
- Flags novas: `badge_boulder` (e `boulder_badge`), `pewter_guide_done`, `rival2_done`, `rival2_won`.
- Autoloads: PCStorage, Evolution e Audio registrados. Testes que precisam de uma instância própria removem o autoload antes (ver tests/ui_evolution e tests/audio).

## Rodada 5 — arte e UI do original, Rota 3, Mt. Moon

A arte do original foi extraída para `res://original/assets/...` (fora do git, só para uso pessoal; ver `original/LEIAME.md`).
O código do original usa `res://assets/...`; aqui o caminho equivalente é `res://original/assets/...`.
Tem: `pokemon/<espécie>/` (front, back, icon, party_icon, overworld + sprite.json, `pmd/*-Anim.png` + `pmd/anims.json`),
`sprites/` (NPCs, treinador, props), `models/hgss|kenney|pokemon/*.scn` (modelos 3D com textura embutida), `textures/`, `ui/badges`, `vfx/`, `fonts/` (Nunito, Pixelify Sans).
Dados novos em `data/`: `pmd_anims.json`, `move_fx.json`, `time_of_day.json`, `time.json`, `weather.json`.

| Dono | Pode editar |
|---|---|
| Núcleo | `core/`, `project.godot`, `docs/CONTRATO.md` |
| Visual da batalha | `gfx/` (helpers visuais compartilhados), `battle/`, `tests/battle/`, `tests/gfx/` |
| Visual da UI | `ui/` (todas as telas), `world/hud.gd`, `tests/ui*/` |
| Visual do mundo | `world/` (menos `hud.gd` e `cave_builder.gd`), `interiors/interior_room.gd`, `interiors/*` visuais, `tests/world/` |
| Conteúdo do mundo | `world/route_world.gd` (só a lista de zonas e ligações), `world/cave_builder.gd` (novo), `interiors/interior_defs.gd`, `story/`, `data/maps/*.json`, `data/trainers.json` (textos), `data/encounters/`, `tests/story/`, `tests/interiors/`, `tests/content/` |

- `gfx/creature_sprite.gd` (dono: Visual da batalha) é o porte do `pokemon_sprites.gd` + animação PMD do original: um nó 3D billboard que mostra a espécie e toca as animações (Idle, Walk, Attack, Hurt, Faint...). O mundo usa o mesmo nó para os selvagens e para o Pokémon que segue o jogador. Entrega primeiro uma versão simples (Idle/Walk) para o mundo poder usar cedo.
- Conflito em `route_world.gd`: o Conteúdo só mexe na lista de zonas/ligações; o resto é do Visual do mundo. Releia o arquivo antes de cada edição e mantenha as edições pequenas.

### Rodada 5 (pronto)

- Arte do original: `gfx/` (CreatureSprite, PokemonSprites, efeitos), batalha, UI e mundo usam `res://original/assets`.
- Arena: `opts.floor = true` quando não há chão (o mundo passa sozinho). Mundo: Pokémon da frente segue o jogador; hora do dia e chuva.
- Zonas: + `route_3` (abre com `boulder_badge`). Salas: `pokemon_center_mt_moon`, `mt_moon_1f`, `mt_moon_b1f`, `mt_moon_b2f` (cavernas por `world/cave_builder.gd`).
- Flags novas: `bought_magikarp`, `mt_moon_cleared`, `mt_moon_fossil`, `FLAG_GOT_DOME_FOSSIL` / `FLAG_GOT_HELIX_FOSSIL`, `FLAG_GOT_FOSSIL_FROM_MT_MOON`, `static_<uid>`.
- `trainers.json`: campo `display_name` em português. Textos de mapas e treinadores traduzidos.
- `Game.trainer_id` (número do Cartão de Treinador).
