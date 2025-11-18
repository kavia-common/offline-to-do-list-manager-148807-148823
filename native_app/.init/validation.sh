#!/usr/bin/env bash
set -euo pipefail
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
cd "$WS"
# Ensure built artifacts exist
if [ ! -x "$WS/build/native_todo" ]; then echo "Built binary missing; run build step" >&2; exit 2; fi
# Run ctest to verify tests (may be no-op if already run)
if [ -d "$WS/build" ]; then (cd "$WS/build" && ctest --output-on-failure -j1) || { echo "Tests failed" >&2; exit 3; }; else echo "Build directory missing; run build step" >&2; exit 2; fi
# Start app via start.sh which is expected to use setsid and write pid after verification
if [ ! -x "$WS/start.sh" ]; then echo "start.sh missing or not executable" >&2; exit 5; fi
# launch start.sh (it should background the app and write native_app.pid)
"$WS/start.sh"
PIDFILE="$WS/native_app.pid"
LOG="$WS/native_app.log"
EVID="$WS/validation_evidence.txt"
: >"$EVID"
# Wait for PID file and confirm process alive
started=0
for i in {1..30}; do
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "${PID:-}" ] && ps -p "$PID" >/dev/null 2>&1; then
      echo "APP_OK pid=$PID" >"$EVID"
      echo "log=$LOG" >>"$EVID"
      started=1
      break
    fi
  fi
  sleep 1
done
if [ "$started" -ne 1 ]; then
  echo "App failed to start within timeout" >&2
  [ -f "$LOG" ] && tail -n 200 "$LOG" >&2 || true
  exit 4
fi
# Attempt graceful shutdown
PID=$(cat "$PIDFILE")
# send TERM to main pid
kill "$PID" >/dev/null 2>&1 || true
# wait for up to 15s for process to exit
stopped=0
for i in {1..15}; do
  if ! ps -p "$PID" >/dev/null 2>&1; then
    echo "STOPPED" >>"$EVID"
    stopped=1
    break
  fi
  sleep 1
done
if [ "$stopped" -ne 1 ]; then
  # escalate: attempt to signal process group (if PID is leader of a group)
  # Use pkill -TERM -g <pgid> || kill -KILL <pid>
  pkill -TERM -g "$PID" >/dev/null 2>&1 || kill -KILL "$PID" >/dev/null 2>&1 || true
  echo "KILLED" >>"$EVID"
fi
rm -f "$PIDFILE" || true
cat "$EVID"
