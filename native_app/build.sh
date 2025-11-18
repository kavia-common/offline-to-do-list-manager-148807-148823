#!/usr/bin/env bash
set -euo pipefail

# Determine workspace (allows external orchestrator to set NATIVE_APP_WORKSPACE)
WORKSPACE="${NATIVE_APP_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
LOG="$WORKSPACE/build.log"

mkdir -p "$WORKSPACE/build"
cd "$WORKSPACE/build"

# Configure
cmake -DCMAKE_BUILD_TYPE=Debug .. >"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 2; }

# Build
cmake --build . -- -j"$(nproc)" >>"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 3; }

# Run tests (compile/link verification and basic sanity); do not require network or system gtest
# Use verbose on failure to aid CI diagnostics
if ctest --output-on-failure -j"$(nproc)" >>"$LOG" 2>&1; then
  :
else
  tail -n 200 "$LOG" >&2
  exit 4
fi
