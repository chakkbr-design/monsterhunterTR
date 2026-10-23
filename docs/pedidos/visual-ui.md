# Pedidos do Visual da UI (Rodada 5)

O kit visual do original está em `res://ui/ui_kit.gd` (`const Kit := preload("res://ui/ui_kit.gd")`) e pode ser
usado por qualquer parte: `Kit.Win` (janela de papel com aba de título), `Kit.row`, `Kit.hint`, `Kit.Dialog`,
`Kit.PartyRow`, `Kit.ItemIcon`, `Kit.tag` (pílula de tipo), `Kit.bar`, `Kit.draw_ring`, `Kit.item_icon`, `Kit.ball`,
fontes `Kit.title_font()`/`Kit.body_font()`, sprites `Kit.mon_front/mon_icon/party_icon/mon_fitted/mon_disc`
(passam pelo `gfx/pokemon_sprites.gd`) e `Kit.format_money`/`Kit.format_time`.

## Para o Visual do mundo / Conteúdo (`world/player.gd`, `world/route_world.gd`)

1. Textos do aviso de interação em português: `_prompt_for` devolve `"E: Battle %s"` e `"E: Talk"`.
   Sugestão: `"E: Batalhar com %s"` e `"E: Falar"`. (O HUD já traduz esses dois enquanto isso.)
2. O HUD agora mostra o nome do lugar numa pílula no canto superior direito, ligado ao
   `location_changed` da RouteWorld (procura o nó do grupo `ow_root`). O `hud.toast(nome do lugar)`
   em `_place_in_interior` e `_track_location` ficou redundante; pode tirar se quiser (não quebra nada se ficar).
3. O HUD esconde orbes, pílula e dicas enquanto `Game.is_busy()` (batalha).

## Para o Núcleo (opcional)

- O Cartão de Treinador mostra um Nº ID derivado do nome. Se o Núcleo quiser um ID fixo salvo,
  um `Game.trainer_id: int` seria usado automaticamente (hoje não é lido).

## Para o Visual da batalha

- Nada obrigatório. O HUD da batalha é de vocês; o kit acima tem as peças do original
  (pílulas de status `Kit.status_pill`, barras `Kit.bar`, anéis `Kit.draw_ring`) se quiserem o mesmo visual.
