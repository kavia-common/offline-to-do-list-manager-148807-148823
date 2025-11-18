#!/usr/bin/env bash
set -euo pipefail

# Determine workspace (allows external orchestrator to set NATIVE_APP_WORKSPACE)
WORKSPACE="${NATIVE_APP_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
LOG="$WORKSPACE/build.log"

# Optional: allow disabling tests via env or arg
# Usage: DISABLE_TESTS=1 ./build.sh  OR ./build.sh --no-tests
DISABLE_TESTS="${DISABLE_TESTS:-0}"
if [[ "${1:-}" == "--no-tests" ]]; then
  DISABLE_TESTS=1
fi

mkdir -p "$WORKSPACE/build"
cd "$WORKSPACE/build"

# Configure: Always prefer vendored googletest; tests can be disabled cleanly
CMAKE_OPTS=(-DCMAKE_BUILD_TYPE=Debug)
if [[ "$DISABLE_TESTS" == "1" ]]; then
  CMAKE_OPTS+=(-DBUILD_TESTING=OFF)
fi

echo "[native_app] Configuring (tests ${DISABLE_TESTS==1 && "disabled" || "enabled"})..." > "$LOG"
cmake "${CMAKE_OPTS[@]}" .. >>"$LOG" 2>&1 || { echo "[native_app] CMake configure failed. Last 200 lines:" >&2; tail -n 200 "$LOG" >&2; exit 2; }

# Build
echo "[native_app] Building..." >>"$LOG"
cmake --build . -- -j"$(nproc)" >>"$LOG" 2>&1 || { echo "[native_app] Build failed. Last 200 lines:" >&2; tail -n 200 "$LOG" >&2; exit 3; }

# Run tests (if enabled): No external/system gtest checks; use vendored only
if [[ "$DISABLE_TESTS" != "1" ]]; then
  echo "[native_app] Running tests..." >>"$LOG"
  if ctest --output-on-failure -j"$(nproc)" >>"$LOG" 2>&1; then
    echo "[native_app] Tests passed." >>"$LOG"
  else
    echo "[native_app] Tests failed. Last 200 lines:" >&2
    tail -n 200 "$LOG" >&2
    exit 4
  fi
else
  echo "[native_app] Tests skipped by configuration." >>"$LOG"
fi
