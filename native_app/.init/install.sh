#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app"
cd "$WORKSPACE"
NEEDS_GTK_DEV=0
NEEDS_GTEST=0
# robust detection using grep -q and find -print -quit
if if grep -R -q "<gtk/" . 2>/dev/null; then true; else false; fi || if grep -R -q -E "find_package\(.*GTK|find_package.*gtk" . 2>/dev/null; then true; else false; fi; then
  NEEDS_GTK_DEV=1
fi
if find . -type f -name "*.ui" -print -quit | grep -q . 2>/dev/null; then NEEDS_GTK_DEV=1; fi
if grep -R -q -E "enable_testing|find_package\(GTest\)|\bgtest\b" . 2>/dev/null || [ -d "$WORKSPACE/test" ] || [ -d "$WORKSPACE/tests" ]; then
  NEEDS_GTEST=1
fi
PKGS=()
[ "$NEEDS_GTK_DEV" -eq 1 ] && PKGS+=(libgtk-4-dev)
[ "$NEEDS_GTEST" -eq 1 ] && PKGS+=(libgtest-dev)
# Only update/install when needed
if [ ${#PKGS[@]} -ne 0 ]; then
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${PKGS[@]}" || { echo "apt install failed for: ${PKGS[*]}" >&2; exit 2; }
fi
# If gtest sources installed, build them out-of-source and verify
if [ "$NEEDS_GTEST" -eq 1 ] && [ -d /usr/src/gtest ]; then
  sudo mkdir -p /tmp/gtest-build && sudo chown "$(id -u):$(id -g)" /tmp/gtest-build
  pushd /tmp/gtest-build >/dev/null
  cmake /usr/src/gtest -DCMAKE_INSTALL_PREFIX=/usr/local >gtest_build.log 2>&1 || { tail -n 200 gtest_build.log >&2; exit 3; }
  make -j"$(nproc)" >gtest_build.log 2>&1 || { tail -n 200 gtest_build.log >&2; exit 4; }
  sudo cp -a /usr/src/gtest/include/gtest /usr/local/include/ || true
  if [ -f libgtest.a ] || [ -f libgtest_main.a ]; then
    sudo cp -a libgtest*.a /usr/local/lib/ || true
    sudo ldconfig
  else
    echo "gtest libs not built as expected" >&2; tail -n 200 gtest_build.log >&2; exit 5
  fi
  popd >/dev/null
fi
# Ensure workspace writable non-recursively
if [ ! -w "$WORKSPACE" ]; then sudo chown "$(id -u):$(id -g)" "$WORKSPACE"; fi
# Emit minimal evidence: installed pkgs and tool versions
if [ ${#PKGS[@]} -ne 0 ]; then echo "installed: ${PKGS[*]}"; fi
command -v g++ >/dev/null 2>&1 && g++ --version | head -n1 || true
command -v cmake >/dev/null 2>&1 && cmake --version | head -n1 || true
