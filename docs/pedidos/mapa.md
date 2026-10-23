# Pedidos do Mapa (Rodada 4: `world/`, `interiors/`, `story/`)

Nada aqui bloqueia: tudo já funciona com contorno local.

## O que está pronto

- RouteWorld faz streaming de 8 zonas: Pallet, Rota 1, Viridian, **Rota 22, Rota 2, Floresta de Viridian, Rota 2 norte, Pewter**.
  Cada uma com as tabelas de encontro e spawn zones do JSON. A Rota 3 não é carregada: a saída leste de Pewter fica fechada
  (borda da zona + placa "ROTA 3 - EM CONSTRUÇÃO" + gatilho `pewter_east_block` da história).
- A parede norte de Viridian (`flag_walls`, `until_flag: has_pokedex`) agora acompanha `Game.flags` ao vivo (`MapBuilder.refresh_flags()`).
- Portarias da floresta: `buildings[].back_door` do JSON vira uma segunda porta (fundos). Salas `forest_gate_south` e
  `forest_gate_north` com saída na frente e nos fundos (`exit_back`, spawn `back`).
- Salas novas: `pokemon_center_pewter` (cura + PC), `mart_pewter` (loja `pewter`), `pewter_gym` (Brock + Campista Liam),
  `pewter_museum`, `pewter_house1`, `pewter_house2`. Marcadores do ginásio: `brock`, `liam`, `arena_center`, `guide`.
- `WorldTrainer` agora lê do trainers.json: `requires_flag`, `hidden_by_flag`, `done_flag`, `won_flag`, `lose`, `leave_after`/`leave_to`.
  O rival da Rota 22 aparece só com `has_pokedex`, luta uma vez (`rival2_done`, `rival2_won`) e vai embora.
  Falas em português em `world/trainer_text.gd`. `WorldTrainer.battle_extra` (estático) acrescenta opts (testes: autoplay).
- Os caçadores de insetos vêm do JSON da floresta (saíram da Rota 1 e de Viridian, onde estavam à mão).
- História: guia de Pewter (uma vez, `pewter_guide_done`), aviso da saída leste, fluxo do Brock (gancho `pewter_gym/brock`):
  vitória → `flags.badge_boulder` e `flags.boulder_badge`, mensagem da insígnia, `Game.add_item("tm39")`.
- Terminais de PC (quarto e Centros) chamam `/root/PCStorage`.open() e esperam fechar; sem o autoload, a fala antiga.
- `player.ui_blocking()` inclui `/root/PCStorage` e `/root/Evolution`.

## Para o Núcleo

1. **CONTRATO**: documentar as flags novas (`badge_boulder` + `boulder_badge`, `pewter_guide_done`, `rival2_done`, `rival2_won`),
   os ids de sala novos e o `exit_back` / `back_door` das portarias.
2. **(Opcional) `Game.badges`**: uma lista de insígnias salva (hoje são só flags `badge_<id>`). Se existir, a história passa a preencher.
3. **(Opcional) Textos dos mapas em português**: falas de NPCs e placas em `data/maps/*.json` (Pewter, floresta, Rota 2/22) estão em inglês.
   Sugestão: campo `lines_pt` (o MapBuilder usaria quando houver) ou traduzir direto no JSON.
4. **(Opcional) `statics`** dos mapas (Pidgeotto na Rota 2, Fearow na Rota 2 norte, Butterfree/Beedrill na floresta, Primeape na Rota 22)
   ainda não são construídos: falta definir como é a luta com um Pokémon estático (fuga? captura única?). Me avisem que eu faço.

## Para a Arena

- Os campos `center` / `arena` / `arena_color` do trainers.json (ginásio) não são usados: a luta acontece onde o jogador está.
  Se a arena quiser centrar a luta do líder, o ginásio tem o marcador `arena_center` (`RouteWorld.marker("pewter_gym", "arena_center")`).
