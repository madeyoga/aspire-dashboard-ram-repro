#!/usr/bin/env bash
# usage: run_cli.sh label [extra aspire args...]
# Starts `aspire dashboard run`, measures the whole process tree (CLI + dashboard).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
label=$1
shift
if [[ -n "${ASPIRE_BIN:-}" ]]; then
  ASPIRE="$ASPIRE_BIN"
elif [[ -x "${HOME}/.aspire/bin/aspire" ]]; then
  ASPIRE="${HOME}/.aspire/bin/aspire"
elif command -v aspire >/dev/null 2>&1; then
  ASPIRE="$(command -v aspire)"
else
  echo "aspire not found — install Aspire.Cli or set ASPIRE_BIN" >&2
  exit 1
fi
LOG="$ROOT/cli-${label}.log"
PYTHON="${PYTHON:-$ROOT/venv/bin/python}"
MEM="$ROOT/mem.sh"

tree() {
  echo "$1"
  local c
  for c in $(pgrep -P "$1" 2>/dev/null || true); do
    tree "$c"
  done
}

cd "$ROOT"
setsid "$ASPIRE" dashboard run \
  --frontend-url http://localhost:18888 \
  --otlp-grpc-url http://localhost:4317 \
  --otlp-http-url http://localhost:4318 \
  --allow-anonymous \
  --non-interactive \
  --nologo \
  "$@" >"$LOG" 2>&1 &
pid=$!
# shellcheck disable=SC2034
for i in $(seq 120); do
  curl -s -o /dev/null http://localhost:18888/ && break
  sleep 0.5
done
echo "[$label] up after ~$((i / 2))s"
sleep 20
# shellcheck disable=SC2046
"$MEM" idle $(tree "$pid")
"$PYTHON" traffic.py http 50 10
"$PYTHON" traffic.py grpc 50 10
sleep 10
# shellcheck disable=SC2046
"$MEM" after1000spans $(tree "$pid")
"$PYTHON" traffic.py http 1000 10
sleep 10
# shellcheck disable=SC2046
"$MEM" after11000spans $(tree "$pid")
curl -s -o /dev/null -w "  UI after load http %{http_code}\n" http://localhost:18888/traces
kill -TERM -"$pid" 2>/dev/null || true
sleep 3
if pgrep -g "$pid" >/dev/null 2>&1; then
  kill -KILL -"$pid" 2>/dev/null || true
fi
wait "$pid" 2>/dev/null || true
echo "[$label] stopped"
