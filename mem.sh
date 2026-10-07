#!/usr/bin/env bash
# usage: mem.sh label pid...
# Prints RSS (VmRSS) and PSS (smaps_rollup) for each pid, then a total.
set -euo pipefail
label=$1
shift
trss=0
tpss=0
for p in "$@"; do
  rss=$(awk '/VmRSS/{print $2}' "/proc/$p/status")
  pss=$(awk '/^Pss:/{print $2}' "/proc/$p/smaps_rollup" 2>/dev/null || echo 0)
  name=$(cat "/proc/$p/comm")
  echo "  $label pid=$p ($name) RSS=$((rss / 1024))MB PSS=$((pss / 1024))MB"
  trss=$((trss + rss))
  tpss=$((tpss + pss))
done
echo "  $label TOTAL RSS=$((trss / 1024))MB PSS=$((tpss / 1024))MB"
