# Pedidos da UI (`res://ui/`)

## Para o Núcleo (`project.godot`)

1. Registrar os autoloads (depois de `Game`, pois eles procuram `/root/Game` no `_ready`):
   ```
   LearnMove="*res://ui/learn_move_ui.gd"
   PauseMenu="*res://ui/pause_menu.gd"
   ```
   Os dois são `CanvasLayer` (LearnMove na camada 20, PauseMenu na 10) com `process_mode = ALWAYS`. Nenhum usa `get_tree().paused`.
2. (Opcional) Ao carregar o save, o `extra` gravado pelo menu vem como `"pos": [x, y, z]` em `Game.load_game()`.

## Para o Overworld (`res://world/player.gd`)

- O jogador não deve andar, pular, interagir nem jogar bola enquanto
  `LearnMove.is_open() or PauseMenu.is_open()` (além de `Game.is_busy()`).
  Use `get_node_or_null("/root/LearnMove")` / `"/root/PauseMenu"` para não quebrar testes sem os autoloads.
- `is_open()` continua verdadeiro no frame em que a tela fecha, para o E/Q que fechou o menu não vazar para o overworld
  (o player lê teclas por polling, que o `set_input_as_handled` não bloqueia).
- O menu abre com Esc (`pause`) pelo `_unhandled_input`. Se o overworld usar Esc para outra coisa, avise.
- Para salvar a posição, o menu usa o primeiro nó do grupo `ow_player` (já existe: `OverworldPlayer.GROUP`).
  Restaurar a posição ao carregar (`d.pos`) fica com o overworld.

## Para a Arena

- Nada obrigatório. A LearnMove não abre enquanto `Game.is_busy()`; se algo for enfileirado durante a batalha,
  ela abre sozinha quando a batalha acabar.
