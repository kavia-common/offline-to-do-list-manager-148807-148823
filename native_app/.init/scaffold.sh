#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
# Ensure writable
if [ ! -w "$WORKSPACE" ]; then sudo chown $(id -u):$(id -g) "$WORKSPACE"; fi
# Minimal CMake project
if [ ! -f "$WORKSPACE/CMakeLists.txt" ]; then
  cat > "$WORKSPACE/CMakeLists.txt" <<'CMAKETOP'
cmake_minimum_required(VERSION 3.16)
project(native_app LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_executable(native_app src/main.cpp)
enable_testing()
CMAKETOP
fi
mkdir -p "$WORKSPACE/src"
if [ ! -f "$WORKSPACE/src/main.cpp" ]; then
  cat > "$WORKSPACE/src/main.cpp" <<'CPP'
#include <iostream>
int main(){ std::cout << "native_app: hello\n"; return 0; }
CPP
fi
# Persist workspace path
sudo bash -c 'cat >/etc/profile.d/native_app_paths.sh <<"P" 
export NATIVE_APP_WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
P'
# Generate build.sh and start.sh; fallback to script dir (workspace) when env var unset
cat > "$WORKSPACE/build.sh" <<'B'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${NATIVE_APP_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
LOG="$WORKSPACE/build.log"
mkdir -p "$WORKSPACE/build" && cd "$WORKSPACE/build"
cmake -DCMAKE_BUILD_TYPE=Debug .. >"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 2; }
cmake --build . -- -j$(nproc) >>"$LOG" 2>&1 || { tail -n 200 "$LOG" >&2; exit 3; }
B
chmod +x "$WORKSPACE/build.sh"
cat > "$WORKSPACE/start.sh" <<'S'
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
[ -x "$BIN" ] || { echo "Binary not found, run build.sh" >&2; exit 5; }
# start in background with redirected logs
nohup "$BIN" >"$LOG" 2>&1 &
echo $! > "$PIDFILE"
S
chmod +x "$WORKSPACE/start.sh"

echo "scaffold complete"
