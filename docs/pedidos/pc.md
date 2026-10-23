# Pedidos do PC (Rodada 4)

Pronto: `res://ui/pc/pc_storage.gd` (CanvasLayer, layer 11). Testes: `tests/ui_pc/test_pc.gd`.
Captura real: `tests/ui_pc/shot_pc.gd` (sem `--headless`) gera `docs/screens/pc.png`.

## Núcleo

- Registrar o autoload `PCStorage="*res://ui/pc/pc_storage.gd"` no `project.godot`.

## Mapa (world/, interiors/)

- O terminal de PC chama `var pc := get_node_or_null("/root/PCStorage")` e `if pc: pc.open()` ao interagir.
  `open()` devolve `false` (e não abre) se o Game estiver ocupado ou se PauseMenu/LearnMove/Evolution/Story estiverem abertos.
- O jogador do overworld não deve andar nem interagir enquanto `PCStorage.is_open()` for verdadeiro
  (fica verdadeiro também no frame em que fechou, igual ao PauseMenu, para o E/Esc não vazar).

## Observação de teclas

`ui_kit.nav` já usa E = confirmar e Q = voltar, então Q/E não trocam de caixa. Na tela da caixa:
←/→ na borda da grade passam para a caixa anterior/seguinte, e PgUp/PgDn (ou Z/C) trocam direto.
