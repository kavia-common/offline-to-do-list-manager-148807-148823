#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
cd "$WORKSPACE"
PID_FILE="$WORKSPACE/native_app.pid"
LOG="$WORKSPACE/native_app.log"
# ensure no stale pidfile
rm -f "$PID_FILE" || true
if [ ! -x "${WORKSPACE}/start.sh" ]; then echo "start.sh not present or not executable" >&2; exit 31; fi
bash "${WORKSPACE}/start.sh"
if [ ! -f "$PID_FILE" ]; then echo "pid file not created by start.sh" >&2; exit 32; fi
STARTED_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -z "$STARTED_PID" ]; then echo "pid file empty" >&2; exit 33; fi
if ! kill -0 "$STARTED_PID" >/dev/null 2>&1; then echo "process $STARTED_PID not running after start" >&2; tail -n 200 "$LOG" >&2 || true; exit 34; fi
echo "$STARTED_PID" > "$PID_FILE"
