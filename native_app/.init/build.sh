#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
cd "$WORKSPACE"
if [ ! -x "${WORKSPACE}/build.sh" ]; then echo "build.sh not present or not executable" >&2; exit 21; fi
bash "${WORKSPACE}/build.sh"
# basic artifact check
if [ ! -x "${WORKSPACE}/build/native_app" ]; then echo "built binary not found: ${WORKSPACE}/build/native_app" >&2; exit 22; fi
