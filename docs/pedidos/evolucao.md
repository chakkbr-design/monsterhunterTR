# Pedidos da Evolução (`res://ui/evolution/`)

## Para o Núcleo (`project.godot`)

1. Registrar o autoload depois de `Game` (ele procura `/root/Game` no `_ready`). A ordem em relação a `LearnMove` não importa:
   ```
   Evolution="*res://ui/evolution/evolution_ui.gd"
   ```
   É um `CanvasLayer` (camada 25, acima da LearnMove 20 e do PauseMenu 10), `process_mode = ALWAYS`, sem `get_tree().paused`.

## Para o Mapa (`res://world/player.gd`)

- Incluir `"/root/Evolution"` na lista de telas modais do jogador (hoje `["/root/LearnMove", "/root/PauseMenu"]`):
  o jogador não anda, pula, interage nem joga bola enquanto `Evolution.is_open()`.
  `is_open()` segue verdadeiro no frame em que a tela fecha (mesma regra da LearnMove).
- Esc e Q durante a evolução cancelam: a tela consome o evento no `_input`, mas o jogador lê por polling.
  Com o pedido acima, Q não joga bola.

## Para quem mantém `res://ui/pause_menu.gd`

- (Pequeno) `open()` não abrir enquanto `get_node_or_null("/root/Evolution")` existir e `is_open()`.
  Hoje já não abre por Esc (a Evolution consome o Esc no `_input`, e o menu abre pelo `_unhandled_input`), então é só garantia.

## Para o Som

- Pontos para `Audio` em `ui/evolution/evolution_ui.gd` (o Som pode pedir, ou acrescentar uma linha se o contrato permitir):
  `_begin` (música de evolução), `_set_state("anim")` (carga em loop), `_complete` (clarão + fanfarra), `_cancel` (som de cancelar).
