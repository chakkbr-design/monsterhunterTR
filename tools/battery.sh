#!/usr/bin/env bash
# Bateria em paralelo: tools/battery.sh OUT N_TOTAL JOBS [opções do battery.gd...]
# Ex.: tools/battery.sh /tmp/b1 800 4 mode=energy size=mix
# Cada job roda N_TOTAL/JOBS lutas com sementes seguidas (o job k começa em SEED0 + k*por_job).
set -u
OUT=$1; N=$2; J=$3; shift 3
GODOT=${GODOT:-godot}
SEED0=${SEED0:-1000}
PER=$(( (N + J - 1) / J ))
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
for k in $(seq 0 $((J - 1))); do
  "$GODOT" --headless --fixed-fps 60 --path . --script res://tests/balance/battery.gd -- \
    n=$PER seed=$((SEED0 + k * PER)) out="$OUT" "$@" > "$OUT/job$k.log" 2>&1 &
done
wait
grep -h "^seed" "$OUT"/job*.log | wc -l
