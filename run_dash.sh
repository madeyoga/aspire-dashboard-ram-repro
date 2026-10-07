#!/usr/bin/env bash
# usage: run_dash.sh label [ENV=VAL ...]
# Starts the standalone Aspire.Dashboard binary, waits for idle, sends spans, reports RSS/PSS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
label=$1
shift
DASH_DIR="${DASH_DIR:-$ROOT/aspire.dashboard.sdk.linux-x64/tools}"
BIN="${DASH_DIR}/Aspire.Dashboard"
if [[ ! -x "$BIN" ]]; then
  echo "Missing $BIN — run ./download.sh first" >&2
  exit 1
fi
LOG="$ROOT/dash-${label}.log"
PYTHON="${PYTHON:-$ROOT/venv/bin/python}"
MEM="$ROOT/mem.sh"

cd "$DASH_DIR"
env \
  ASPNETCORE_URLS=http://localhost:18888 \
  ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL=http://localhost:4317 \
  ASPIRE_DASHBOARD_OTLP_HTTP_ENDPOINT_URL=http://localhost:4318 \
  ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS=true \
  "$@" \
  ./Aspire.Dashboard >"$LOG" 2>&1 &
pid=$!
sleep 0.2
if ! kill -0 "$pid" 2>/dev/null; then
  cat "$LOG" >&2
  exit 1
fi
# shellcheck disable=SC2034
for i in $(seq 60); do
  curl -s -o /dev/null http://localhost:18888/ && break
  sleep 0.5
done
echo "[$label] up after ~$((i / 2))s"
curl -s -o /dev/null -w "  UI http %{http_code}\n" http://localhost:18888/
sleep 20
"$MEM" idle "$pid"
cd "$ROOT"
"$PYTHON" traffic.py http 50 10
"$PYTHON" traffic.py grpc 50 10
sleep 10
"$MEM" after1000spans "$pid"
"$PYTHON" traffic.py http 1000 10
sleep 10
"$MEM" after11000spans "$pid"
curl -s -o /dev/null -w "  UI after load http %{http_code}\n" http://localhost:18888/traces
kill "$pid"
wait "$pid" 2>/dev/null || true
echo "[$label] stopped"
