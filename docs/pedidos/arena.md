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
6. ~~Itens na batalha~~ **feito (rodada 2)**: bolsa rápida (E) chama `Game.use_item(id, mon)` e ressincroniza o lutador;
   item do treinador usado pela IA uma vez com HP <= 35%. Pode tirar "itens durante a batalha" dos pendentes do CONTRATO.

## Rodada 2 (itens + 2x1)

7. **Atualizar o CONTRATO.md**: "itens durante a batalha" e "batalha 2x1 com aliado" estão prontos. Novos `opts` lidos só pela arena:
   - `battle_size: int` (padrão 2 em selvagem; 1 força 1x1; treinador é sempre 1x1).
   - `trainer_item: String` (sobrepõe o `item` do trainers.json; usado nos testes).
   - `game: Node` (instância de `core/game.gd` para a bolsa nos testes headless; sem isso usa `/root/Game`).
8. **`item` no trainers.json**: nenhum treinador tem o campo hoje (o `_doc` também não o lista). A arena já lê
   `Dex.trainer(id).item` (ex.: `"item": "super_potion"` para líderes). Pedido: adicionar o campo onde fizer sentido e documentar no `_doc`.
9. **Ação `ally_mode` (F)**: o CONTRATO já lista e `core/controls.gd` já registra. A arena mantém o fallback
   (`InputMap.has_action("ally_mode")` senão lê `KEY_F`), então nada a fazer.
10. **Texto de `Game.use_item`/`Items.use`** vem em português; os banners da arena estão em inglês. Sem bloqueio:
    se o Núcleo padronizar o idioma, a arena só repassa o texto.
11. **Ether / itens de PP**: `Items.can_use` não trata efeito de PP, então a bolsa rápida só lista itens com `hp`, `cure` ou `revive`.
    Se o Núcleo suportar PP (`mon.pp = pp_base`), a arena precisa só ressincronizar `pp_max` (avisar).
12. **Confusão** só existe dentro da luta: a Persim Berry é tratada localmente pela arena (zera a confusão e chama `Game.take_item`).
