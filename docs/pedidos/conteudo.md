# Pedidos do Conteúdo do mundo (Rodada 5: Rota 3, Monte da Lua, textos em português)

Nada aqui bloqueia: tudo já funciona com contorno local.

## O que está pronto

- **Rota 3** (`route_3` em `RouteWorld.ZONES`; o mapa já inclui a Rota 4 oeste e a boca do Monte da Lua).
  A saída leste de Pewter só abre com a Insígnia da Rocha: `flag_walls` em `pewter_city.json`
  (`until_flag: boulder_badge`), o gatilho `pewter_east_block` não dispara com a insígnia e o garoto
  que barra some (`hidden_by_flag`). A placa "ROTA 3 - EM CONSTRUÇÃO" (`EXTRAS` da RouteWorld) saiu.
- **Monte da Lua**: salas `mt_moon_1f`, `mt_moon_b1f`, `mt_moon_b2f` (InteriorDefs, `"cave": "<andar>"`, em
  x da vaga normal e z ≥ 200) montadas por `world/cave_builder.gd` a partir de `data/maps/mt_moon_floors.json`
  e `mt_moon_events.json` (0,9 m por tile): rochas, escadas (`InteriorTrigger`, spawns `warp_<i>`), itens,
  treinadores (Equipe Rocket `rocket_1..4` no B2F), placa do Zubat, zonas de encontro `mt_moon_<andar>`,
  luzes fracas (`cave_dark`, grupo `cave_light`, `CaveBuilder.set_flash(room, on)` para um futuro FLASH).
  Entrada: porta `mtmoon_west` da Rota 3 (spawn `r4_west_mouth`) → `mt_moon_1f/west_in`. Saída do B1F para a
  Rota 4 leste: cena `mt_moon_exit` ("Continua...", flag `mt_moon_cleared`).
- **Fósseis**: cena `mt_moon_fossils` (gatilho perto do Supernerd Miguel ou falar com ele / com um fóssil):
  luta (Miguel com `sight: 0` no trainers.json), escolha Domo/Hélice. Flags `FLAG_GOT_DOME_FOSSIL` ou
  `FLAG_GOT_HELIX_FOSSIL`, `FLAG_GOT_FOSSIL_FROM_MT_MOON`, `mt_moon_fossil` = "dome" | "helix"; item na bolsa.
- **Centro Pokémon do Monte da Lua** (`pokemon_center_mt_moon`, porta `mm_center_in` da Rota 4) com o
  vendedor de Magikarp (P500, uma vez, flag `bought_magikarp`).
- **Estáticos** (`statics` dos mapas): `story/static_mon.gd` (`StaticMon`). Visível: E → luta selvagem;
  `hidden`: pula quando o jogador chega perto. Vencer/capturar grava `flags.static_<uid>` e ele não volta.
  Opts da batalha: `{kind: "wild", can_run: true, static_uid}`.
- **Textos em português**: falas, placas, portas e nomes de NPC de `data/maps/*.json` e todas as falas do
  `data/trainers.json` (ids mantidos). Campo novo `display_name` no trainers.json (nome completo do banner).
- Ligação sem editar `world/`: o autoload `Story` decora as salas `cave` e cada `MapBuilder` quando entram
  na árvore (`CaveBuilder.decorate` / `decorate_zone`).
- Testes: `tests/content/test_mt_moon.gd`, `tests/content/test_texts_pt.gd`.

## Para o Visual do mundo

1. (FEITO) `tests/world/test_route_pewter.gd` (`_pewter_east`) ainda espera a Rota 3 fechada e a placa
   `Route3Closed`. Agora: sem insígnia a saída continua fechada (parede de flag + aviso), mas
   `w.zones.has("route_3")` é verdadeiro e a placa não existe mais.
2. (FEITO) `world/spawn_zone.gd:27`: `_alive.filter(func(c: WildMon) ...)` quebra quando um WildMon da lista foi
   liberado ("Cannot convert argument 1 from Object to Object" + "Trying to assign an array of type Array").
   Sugestão: `func(c) -> bool: return is_instance_valid(c)` (sem tipo no parâmetro) e `_alive.assign(...)`.
3. (FEITO pelo Visual do mundo) `WorldTrainer`/`TrainerText.display_name`: usar `def.display_name` quando existir ("Recruta da Equipe
   Rocket", "Supernerd Miguel", "Nadador Luis"). Hoje o CaveBuilder troca o nome depois do `_ready`.
   Se preferir só a tabela: `CLASS_PT` com `"team_rocket": "Recruta da Equipe Rocket"` (nome vazio),
   `"super_nerd": "Supernerd"`, `"swimmer": "Nadador"`.
4. (Opcional) `InteriorRoom._ready`: chamar `CaveBuilder.decorate(self)` quando `def.has("cave")` (é idempotente),
   e o `MapBuilder` chamar `CaveBuilder.decorate_zone(self)` no fim do `build()`. Assim não depende do Story.
5. (Opcional) MapBuilder: ler `doors` e `statics` direto (hoje vêm do CaveBuilder) e um modelo de boca de
   caverna para a porta `mtmoon_west` (hoje é a placa de porta comum).
6. (Opcional) Visual das cavernas: rochas são caixas (`CaveRocks`, `Rock<n>`); escadas `LadderMesh<i>`.

## Para o Núcleo

- CONTRATO: flags novas (`FLAG_GOT_DOME_FOSSIL`, `FLAG_GOT_HELIX_FOSSIL`, `FLAG_GOT_FOSSIL_FROM_MT_MOON`,
  `mt_moon_fossil`, `mt_moon_cleared`, `bought_magikarp`, `static_<uid>`), salas novas e o campo `display_name`.
- `world.json`: o spawn `r4_west_mouth` (boca do Monte da Lua) não está na lista `spawns` da zona `route_3`.
- (Opcional) `Game.TRAINER_PAYOUTS` sem `team_rocket`/`super_nerd` (não afeta: todos têm `reward`).
