# Pedidos da Arena (res://battle/) para o Núcleo

Nada aqui bloqueia a arena: ela já contorna localmente. São ajustes de contrato/núcleo.

1. **Documentar opts extras da arena no CONTRATO.md** (só a arena lê; o Game repassa como vierem):
   - `autoplay: bool` — a IA controla o mon do jogador (testes, demo).
   - `seed: int` — semente do RNG da batalha (dano, precisão, IA). Os IVs/natureza do `Mon.create` continuam no RNG global.
   - `speed: float` — velocidade da luta (o original tem Settings "Slow" 0.6 / "Fast" 1.0; padrão aqui 1.0).
     Se o Núcleo ganhar uma opção de configuração, basta o `Game.request_battle` injetar `opts.speed`.
   - `ball: String` — bola usada quando não existe autoload `Game` (testes headless).
2. **Campo extra no `result`**: `exp: Array` de `{mon: Mon, amount: int, events: Array}` (eventos de `Mon.add_exp`).
   - Eventos `{type:"move", learned:false}` precisam da tela de esquecer golpe (`Mon.replace_move`) — fica com o Núcleo/UI depois da batalha.
   - `Mon.evo_pending` também fica para o Núcleo/overworld tratar depois de `battle_finished`.
3. **Status persistente**: a arena grava `mon.hp`, `mon.pp` (pool) e `mon.status` (só `Mon.PERSIST_STATUS`) ao sair de campo e no fim.
   Estágios, confusão, leech, evasão e stagger não persistem (igual ao original). Se o Centro de cura não chamar `heal_full`, o PP não volta.
4. **Treinadores com `"@flag"` na party** (trainers.json): quem monta a lista `enemies` (Overworld/Núcleo) resolve a espécie via `Game.flags`.
   A arena só usa `trainer_id` para ler `ai_think_scale`.
5. **Prêmio em dinheiro de treinador** não é pago pela arena (o contrato não pede). Sugestão: o `Game._on_arena_finished` paga
   `reward` do trainers.json quando `outcome == "win"` e `opts.kind == "trainer"` (precisaria guardar o `trainer_id` do pedido).
6. **Itens na batalha** (poção/cura rápida, item de treinador usado pela IA): fora do MVP. Quando existir uma API
   `Items.use(id, mon)` estável, a arena pode chamar e ressincronizar o lutador. Hoje a arena só consome bolas com `Game.take_item`.
