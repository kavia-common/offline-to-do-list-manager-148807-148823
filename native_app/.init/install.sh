#!/usr/bin/env bash
set -euo pipefail
# Install minimal system tooling for GTK4/CMake development and persist CC/CXX
WS="${WORKSPACE:-/home/kavia/workspace/code-generation/offline-to-do-list-manager-148807-148823/native_app}"
export WORKSPACE="$WS"
PKGS=(cmake pkg-config libgtk-4-dev libx11-dev libwayland-dev libsqlite3-dev gdb curl)
MISSING=()
for p in "${PKGS[@]}"; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then MISSING+=("$p"); fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  sudo apt-get update -q && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${MISSING[@]}" >/dev/null
fi
# Validate cmake version >=3.16
if ! command -v cmake >/dev/null 2>&1; then echo "ERROR: cmake not found; please install cmake >=3.16" >&2; exit 2; fi
CMVER=$(cmake --version | head -n1 | awk '{print $3}')
CM_MAJOR=$(echo "$CMVER" | cut -d. -f1)
CM_MINOR=$(echo "$CMVER" | cut -d. -f2)
if [ "$CM_MAJOR" -lt 3 ] || { [ "$CM_MAJOR" -eq 3 ] && [ "$CM_MINOR" -lt 16 ]; }; then
  echo "ERROR: cmake >=3.16 required (found $CMVER). Install newer cmake or provide it in PATH." >&2
  exit 3
fi
# Ensure pkg-config can find gtk4
if ! pkg-config --exists gtk4 >/dev/null 2>&1; then
  echo "ERROR: pkg-config cannot find gtk4; verify libgtk-4-dev is installed." >&2
  exit 4
fi
# Persist CC/CXX idempotently
PROFILE=/etc/profile.d/native_app_env.sh
NEW_CONTENT=$'## native_app toolchain settings\n[ -z "${CC+x}" ] && export CC="/usr/bin/gcc"\n[ -z "${CXX+x}" ] && export CXX="/usr/bin/g++"\n'
if sudo test -f "$PROFILE"; then
  if ! sudo grep -q "native_app toolchain settings" "$PROFILE"; then
    echo "$NEW_CONTENT" | sudo tee -a "$PROFILE" >/dev/null
  else
    # Ensure exports exist individually (idempotent append if missing)
    sudo bash -c "grep -q '\\bexport CC=' '$PROFILE' || echo '[ -z "\${CC+x}" ] && export CC="/usr/bin/gcc"' >> '$PROFILE'"
    sudo bash -c "grep -q '\\bexport CXX=' '$PROFILE' || echo '[ -z "\${CXX+x}" ] && export CXX="/usr/bin/g++"' >> '$PROFILE'"
  fi
else
  echo "$NEW_CONTENT" | sudo tee "$PROFILE" >/dev/null
  sudo chmod 644 "$PROFILE"
fi
# Ensure workspace exists and is owned by the invoking non-root user
mkdir -p "$WS"
OWN_USER="${SUDO_USER:-${USER:-}}"
if [ -n "$OWN_USER" ]; then
  sudo chown -R "$OWN_USER":"$OWN_USER" "$WS" || true
fi
# Optional tool notice
if ! command -v gdb >/dev/null 2>&1; then echo "NOTE: gdb not found (optional)" >&2; fi
# Final validation summary (minimal)
command -v cmake >/dev/null && cmake --version | head -n1
pkg-config --modversion gtk4 >/dev/null 2>&1 && echo "pkg-config: gtk4 OK"
exit 0
