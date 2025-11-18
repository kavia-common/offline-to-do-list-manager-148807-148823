#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
cd "$WORKSPACE"
STARTED_PID=""
PID_FILE="$WORKSPACE/native_app.pid"
LOG="$WORKSPACE/native_app.log"
cleanup() {
  if [ -n "$STARTED_PID" ]; then
    if kill -0 "$STARTED_PID" >/dev/null 2>&1; then
      kill "$STARTED_PID" || true
      sleep 1
      if kill -0 "$STARTED_PID" >/dev/null 2>&1; then kill -9 "$STARTED_PID" || true; fi
    fi
  fi
  rm -f "$PID_FILE" || true
}
trap cleanup EXIT
# Ensure build script exists
if [ ! -x "${WORKSPACE}/build.sh" ]; then echo "build.sh missing or not executable" >&2; exit 11; fi
bash "${WORKSPACE}/build.sh"
# Ensure start script exists
if [ ! -x "${WORKSPACE}/start.sh" ]; then echo "start.sh missing or not executable" >&2; exit 12; fi
bash "${WORKSPACE}/start.sh"
if [ ! -f "$PID_FILE" ]; then echo "pid file not found" >&2; exit 13; fi
STARTED_PID=$(cat "$PID_FILE" 2>/dev/null || true)
if [ -z "$STARTED_PID" ]; then echo "pid file empty" >&2; exit 14; fi
# Verify process exists
if ! kill -0 "$STARTED_PID" >/dev/null 2>&1; then echo "process not running after start" >&2; tail -n 200 "$LOG" >&2 || true; exit 15; fi
EXE_PATH="$(readlink -f /proc/${STARTED_PID}/exe 2>/dev/null || true)"
EXPECTED_EXE="$(readlink -f "${WORKSPACE}/build/native_app" 2>/dev/null || true)"
if [ -z "$EXE_PATH" ] || [ "$EXE_PATH" != "$EXPECTED_EXE" ]; then
  echo "pid $STARTED_PID does not match expected binary (exe=$EXE_PATH expected=$EXPECTED_EXE)" >&2
  exit 16
fi
# ldd evidence
echo "ldd output:" || true
ldd "$EXPECTED_EXE" || true
# Tail logs
if [ -f "$LOG" ]; then
  echo "--- last 200 lines of $LOG ---"
  tail -n 200 "$LOG" || true
fi
# remove trap and cleanup now
trap - EXIT
cleanup
echo "validation: OK"
