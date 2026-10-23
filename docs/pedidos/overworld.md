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
