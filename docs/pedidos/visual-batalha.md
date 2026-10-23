# Pedidos do Visual da batalha (`gfx/`, `battle/`, `tests/battle/`, `tests/gfx/`)

## Pronto (rodada 5)

- `gfx/creature_sprite.gd` (`CreatureSprite`, Node3D): sprite billboard da espécie com a arte do original.
  PMD (anims.json: durações, 8 direções, âncoras por quadro) com as cadeias de `data/pmd_anims.json`;
  sem PMD usa `overworld.png` (4 direções, sprite.json); sem overworld usa o 1º quadro do `front.png`.
  API: `species`, `scale_mult`, `auto_motion`/`auto_face` (padrão: velocidade pelo deslocamento do nó),
  `velocity`, `facing`, `face(dir)`, `face_point(p)`, `state` ("" automático; idle/move/fly/airborne/prepare/sleep/stagger),
  `play(anim)`, `play_chain([...])`, `play_move(mv, segundos)`, `hurt()`, `faint()`, `revive()`, `tint`, `set_alpha(a)`,
  `visible_height()`, `head_position(extra)`, `footprint()`, `reset_motion()`, `camera` (fixa a câmera de referência),
  `manual` + `tick(dt)` (sem _process), `sprite()`, `signal oneshot_finished(anim)`.
- `gfx/pokemon_sprites.gd` (`PokemonSprites`): `spec`, `icon`, `front`, `back`, `party_icon`, `*_frames`, `icon_fitted`, `disc_icon`,
  `resolve_chain`, `move_chain`, `pmd_anims`, `asset_path` ("res://assets/..." → "res://original/assets/...").
- `gfx/ui_draw.gd` (`UiDraw`): cores/fontes do ui_kit original (Pixelify Sans / Nunito), glass, barras, pílulas de tipo/status, chips de estágio, bola.
- `gfx/pmd_fx.gd` (`PmdFx`), `gfx/fx_sprite.gd` (`FxSprite`), `gfx/beam_fx.gd` (`BeamFx`, inclui o jato de fogo com o shader
  `gfx/shaders/flame_jet.gdshader` copiado do original), `gfx/poke_ball_3d.gd` (`PokeBall3D`). Os efeitos avançam em `tick(dt)`;
  com `auto = true` andam sozinhos (uso no mundo).
- Batalha: sprites PMD (Idle/Walk/Charge/Attack/Shoot/Hurt/Faint/Sleep...), HUD do original (cartões, golpes em losango, banner em pílula,
  faixas de introdução + "Lutem!", popups de dano em tela), efeitos do `move_fx.json` (user/travel/hit/beam/stream/tip, status e estágios),
  bola 3D com absorção/balanço/brilho/estrelas, fumaça ao entrar/sair. Jogabilidade igual (test_battle verde).

## Para o Núcleo (`docs/CONTRATO.md`)

1. Documentar o `opts.floor: bool` da arena (padrão falso): a arena não cria mais piso próprio — desenha só a quadra dourada
   do original sobre o chão do mundo. Em cena sem chão (testes, cenas soltas), passe `floor: true`.
2. Documentar `BattleFighter.popup(text, col, scale, extra, style)` e `arena.popup(at, text, col, scale, style)` (o `style` é opcional:
   damage, crit, super, weak, miss, dodge, stat_up, stat_down, status, heal, move, callout, info).
3. Novos testes: `tests/gfx/test_gfx.gd` e `tests/battle/test_battle_visual.gd` (este roda a arena dentro da árvore).
   `tests/battle/shot_battle.gd` gera `docs/screens/battle_original.png` e `capture.png` (rodar SEM `--headless`).

## Para o Som (`audio/`)

- `Audio.sfx` avisa "efeito desconhecido" para `hit`, `hit_super`, `hit_weak`, `crit` chamados pela batalha (já existiam antes desta rodada).

## Para o Visual do mundo

- A arena agora depende do chão do mundo (ver item 1 do Núcleo). Se algum lugar abre batalha sobre o vazio, mande `floor: true`.
- `world/sky/time_of_day.gd:285` usa `MapBuilder.GROUP`, que não existe: isso quebra a compilação de `story.gd`/`route_world.gd`
  em todos os testes headless (não afeta a batalha, mas polui a saída).
