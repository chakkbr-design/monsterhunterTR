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
