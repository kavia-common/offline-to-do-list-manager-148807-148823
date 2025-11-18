#!/usr/bin/env bash
set -euo pipefail
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
mkdir -p "$WS/test/vendor"
# Prefer pinned Catch2 v3 single header
CATCH_URL="https://github.com/catchorg/Catch2/releases/download/v3.5.2/catch.hpp"
OUT="$WS/test/vendor/catch.hpp"
if [ ! -f "/usr/include/catch2/catch.hpp" ] && [ ! -f "$OUT" ]; then
  for i in 0 1 2; do
    curl -sSL --fail "$CATCH_URL" -o "$OUT" && break || sleep $((2**i))
  done
  if [ ! -s "$OUT" ]; then echo "Failed to download catch.hpp" >&2; exit 6; fi
  # basic sanity check: file should be > 1000 bytes
  if [ $(wc -c <"$OUT") -lt 1000 ]; then echo "Downloaded catch.hpp too small" >&2; exit 7; fi
fi
# Determine include line
if [ -f "/usr/include/catch2/catch.hpp" ]; then CATCH_INC='<catch2/catch.hpp>'; else CATCH_INC='"catch.hpp"'; fi
# Write test; use std::remove for cleanup
mkdir -p "$WS/test"
cat >"$WS/test/test_storage.cpp" <<CPP
#define CATCH_CONFIG_MAIN
#include $CATCH_INC
#include "storage.h"
#include <fstream>
#include <algorithm>
#include <cstdio>
TEST_CASE("storage add, load, save"){
  std::string p = std::string("$WS/build/native_todo_test.txt");
  { std::ofstream o(p); o<<"existing\n"; }
  Storage s(p);
  s.load();
  auto before = s.get_items();
  REQUIRE(before.size()>=1);
  s.add_item("newtask");
  s.save();
  Storage s2(p);
  s2.load();
  auto after = s2.get_items();
  REQUIRE(std::find(after.begin(), after.end(), std::string("newtask"))!=after.end());
  std::remove(p.c_str());
}
CPP
# Build and run tests
mkdir -p "$WS/build" && cd "$WS/build"
cmake .. 2>&1 | tee "$WS/native_test_cmake.log"
cmake --build . -- -j2 2>&1 | tee "$WS/native_test_build.log"
ctest --output-on-failure -j1 || { echo "Tests failed" >&2; exit 8; }
