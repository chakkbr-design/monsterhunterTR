# Vídeos das lutas (Reels, TikTok, Shorts)

Pedido do Caio (2026-10-27): gravar lutas do treino sem HUD e montar um vídeo vertical (9:16) em que o
HUD do vídeo (nome e barra de vida de quem está em campo, 6 Poké Balls por time como no Game Boy) é
desenhado a partir do arquivo da partida, sozinho.

## No HUD (treino)

- Opção **No HUD** na tela de montar (`cfg.clean_hud`). Na luta somem os cartões, botões, log, avisos,
  faixas de golpe e a barra do treino (`arena.clean_hud`, `BattleHUD.clean`). Ficam a barra de vida
  em cima da cabeça (pedido do Caio), os números de dano (popups) e todos os efeitos da luta, o estádio e o telão.
- Quando a arena começa, um clarão branco de 3 quadros na tela inteira (acima da tela de load) marca o
  vt 0 do arquivo da partida: gravando com OBS, o montador acha o clarão sozinho.
- Cada luta grava `user://matches/match_<data>_<n>.json`
  (`%APPDATA%\Godot\app_userdata\PokmemonLike\matches`).

## Arquivo da partida (`BattleTelemetry`)

Além do que a bateria já usava (`events`, `samples`, `teams`), agora tem:

- `track`: a cada 0,1 s de vídeo, `{vt, t, st, hp: [[hp x6], [hp x6]], on: [[índices em campo], [...]]}`,
  vida em pontos de batalha de todos os 12 (banco incluso, desmaiado = 0).
- `vt` (relógio do vídeo): segundos reais de quadro desde a arena começar. Conta a abertura, as trocas
  paradas e a câmera lenta (o `t` da luta não conta). Todo evento leva `vt`.
- `teams[side][i]`: `name`, `lv`, `max` (vida máxima de batalha) além de espécie, golpes etc.
- `result.vt` (fim da luta no vídeo), `meta.names` (nomes dos times), `video.frame0`.

## Gravar e montar

No PC, na raiz do projeto (Git Bash):

```bash
tools/video/record.sh                         # times de exemplo (tools/video/sample_6v6.json)
tools/video/record.sh meus_times.json .video/x  # outro config (formato de user://training.json)
```

1. O Godot abre a luta direto (`training_battle.tscn` com `--training-config`, `--clean-hud`,
   `--portrait=1080x1920`, `--quit-at-end`, `--match-file`) e grava com `--write-movie` (AVI, 30 fps).
   Em retrato a câmera de ação deixa livres as faixas do HUD do vídeo (`PORTRAIT_BAND`).
2. `tools/video/make_vertical.py raw.avi match.json video.mp4` acha o clarão, corta até 2,5 s depois do
   fim e desenha o HUD quadro a quadro (H.264 + áudio do jogo, 1080x1920).

Gravando com OBS (tela deitada 16:9, com No HUD ligado): passe a gravação e o arquivo de
`user://matches` para `make_vertical.py`; o jogo fica numa faixa no meio com o fundo borrado.
`--offset S` pula a busca do clarão. Precisa de Python com numpy e Pillow, e ffmpeg (ou
`pip install imageio-ffmpeg`). Fonte: `original/assets/fonts/PixelifySans.ttf`.

Teste: `tests/ui_training/test_clean_hud.gd`.
