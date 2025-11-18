#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${NATIVE_APP_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
LOG="$WORKSPACE/build.log"
mkdir -p "$WORKSPACE/build" && cd "$WORKSPACE/build"
cmake -DCMAKE_BUILD_TYPE=Debug .. >"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 2; }
cmake --build . -- -j$(nproc) >>"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 3; }
