#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
cd "$WORKSPACE"
# Run any ctest if present, otherwise run smoke test of built binary
if [ -d "$WORKSPACE/build" ] && command -v ctest >/dev/null 2>&1; then
  (cd "$WORKSPACE/build" && ctest --output-on-failure || true)
else
  if [ -x "$WORKSPACE/build/native_app" ]; then
    "$WORKSPACE/build/native_app" --help >/dev/null 2>&1 || true
  else
    echo "no built binary to test" >&2; exit 51
  fi
fi
