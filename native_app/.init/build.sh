#!/usr/bin/env bash
set -euo pipefail
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
mkdir -p "$WS/build" && cd "$WS/build"
cmake .. 2>&1 | tee "$WS/native_build_cmake.log"
cmake --build . -- -j2 2>&1 | tee "$WS/native_build_build.log"
