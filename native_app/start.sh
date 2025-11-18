#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${NATIVE_APP_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
BIN="$WORKSPACE/build/native_app"
PIDFILE="$WORKSPACE/native_app.pid"
LOG="$WORKSPACE/native_app.log"
# Do not override DISPLAY; rely on existing DISPLAY (container provides DISPLAY=:99)
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
    echo "already running: pid=$PID" >&2; exit 4
  else
    rm -f "$PIDFILE" || true
  fi
fi
if [ ! -x "$BIN" ]; then
  echo "Binary not found at $BIN. Please run ./build.sh first." >&2
  exit 5
fi
# start in background with redirected logs
nohup "$BIN" >"$LOG" 2>&1 &
echo $! > "$PIDFILE"
echo "native_app started with pid $(cat "$PIDFILE")"
