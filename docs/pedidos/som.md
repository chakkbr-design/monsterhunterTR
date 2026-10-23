# Pedidos do Som (Rodada 4)

## Núcleo
- Registrar o autoload `Audio="*res://audio/audio.gd"` no `project.godot` (depois de `Game`; a ordem não é crítica, ele se liga ao Game no frame seguinte ou quando um nó `/root/Game` entrar na árvore).
- Opcional: guardar o `kind` da batalha em algo público (hoje o Audio lê `Game._opts.kind` para escolher `battle_wild`/`battle_trainer`).

## Como chamar som de outras partes (uma linha, segura sem o autoload)
`preload("res://audio/cue.gd").sfx("nome")`, `preload("res://audio/cue.gd").ui(acao)` (acao = up/down/left/right/ok/back), `preload("res://audio/cue.gd").music("faixa")`.
Efeitos: ui_move ui_confirm ui_back hit hit_super hit_weak crit faint ball_throw ball_shake catch_ok catch_fail level_up heal door step_grass encounter item_get evolution run_away.
Faixas: title town route forest battle_wild battle_trainer victory center lab gym.

## Mapa (world/, interiors/, story/) — não editei, peço a linha:
- `step_grass`: no passo do jogador dentro do mato alto.
- `heal`: quando a enfermeira cura (`Game.heal_party` no balcão) e quando a Mamãe cura.
- `item_get`: ao receber item da história (encomenda do Oak, Poké Balls, Pokédex) e ao comprar na loja.
- `ui_move`/`ui_confirm`/`ui_back` no painel da loja (`interiors/mart_panel.gd`) e na escolha de inicial da história.
- Porta: já automático (o Audio toca `door` quando o `location_changed` entra ou sai de interior).
- Ginásio: o Audio põe a faixa `gym` em qualquer interior cujo id contenha `gym`.

## PC (ui/pc/) e Evolução (ui/evolution/) — não editei (fora da minha permissão nesta rodada):
- `ui/pc/pc_storage.gd`: primeira linha de `press(a)`: `preload("res://audio/cue.gd").ui(a)`.
- `ui/evolution/evolution_ui.gd`: em `press(a)` a mesma linha; em `_set_state`, no ramo `"anim"`: `preload("res://audio/cue.gd").sfx("evolution")`; em `_complete()` depois do `_set_state("done", ...)`: `preload("res://audio/cue.gd").sfx("item_get")`.
