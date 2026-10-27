#!/usr/bin/env bash
# Grava uma luta do treino sem HUD (com --write-movie, em retrato 1080x1920) e monta o vídeo vertical
# com o HUD do vídeo (make_vertical.py). Roda no PC, na raiz do projeto, no Git Bash.
#
# Uso: tools/video/record.sh [config.json] [pasta de saída] [fps]
#   config.json  times e opções no formato de user://training.json (padrão: tools/video/sample_6v6.json)
#   pasta        onde ficam raw.avi (gravação do jogo), match.json (arquivo da partida) e video.mp4
#   fps          quadros por segundo do vídeo (padrão 30)
# GODOT aponta para o executável (padrão: o Godot do PC do Caio).
set -euo pipefail
CFG=${1:-tools/video/sample_6v6.json}
OUT=${2:-.video/$(date +%Y%m%d_%H%M%S)}
FPS=${3:-30}
GODOT=${GODOT:-"/c/Users/User/Desktop/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe"}
PY=${PY:-python}
mkdir -p "$OUT"
abs() { if command -v cygpath >/dev/null; then cygpath -m "$(realpath "$1")"; else realpath "$1"; fi; }
CFG_ABS=$(abs "$CFG")
OUT_ABS=$(abs "$OUT")
"$GODOT" --path . --resolution 1080x1920 --write-movie "$OUT_ABS/raw.avi" --fixed-fps "$FPS" \
	res://ui/training/training_battle.tscn -- \
	--training-config="$CFG_ABS" --clean-hud --portrait=1080x1920 --quit-at-end \
	--match-file="$OUT_ABS/match.json" < /dev/null
"$PY" tools/video/make_vertical.py "$OUT/raw.avi" "$OUT/match.json" "$OUT/video.mp4"
echo "Video: $OUT/video.mp4"
