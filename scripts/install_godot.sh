#!/usr/bin/env bash
# Installs the pinned Godot binary and the single-threaded web export templates.
# Used by CI and pasted into the cloud environment's Setup script field.
# Needs: curl, unzip, network access to github.com and release-assets.githubusercontent.com.
# Optional env: GODOT_VERSION (default: .godot-version or the fallback below),
#               INSTALL_DIR (default /opt/godot), GODOT_USER_DIR (default $HOME/.local/share/godot).
set -euo pipefail

FALLBACK_VERSION="4.4.1-stable"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo .)"
if [ -z "${GODOT_VERSION:-}" ]; then
  if [ -f "$HERE/../.godot-version" ]; then GODOT_VERSION="$(tr -d '[:space:]' < "$HERE/../.godot-version")"
  elif [ -f mera/.godot-version ]; then GODOT_VERSION="$(tr -d '[:space:]' < mera/.godot-version)"
  else GODOT_VERSION="$FALLBACK_VERSION"; fi
fi
INSTALL_DIR="${INSTALL_DIR:-/opt/godot}"
GODOT_USER_DIR="${GODOT_USER_DIR:-$HOME/.local/share/godot}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"
BIN="$INSTALL_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
TEMPLATE_DIR="$GODOT_USER_DIR/export_templates/${GODOT_VERSION/-/.}"   # 4.4.1-stable -> 4.4.1.stable
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BIN" ]; then
  mkdir -p "$INSTALL_DIR"
  curl -fsSL --retry 3 -o "$WORK/godot.zip" "$BASE/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -q -o "$WORK/godot.zip" -d "$INSTALL_DIR"
  chmod +x "$BIN"
fi

if [ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]; then
  mkdir -p "$TEMPLATE_DIR"
  # The full templates archive is ~1.2 GB; keep only the single-threaded web templates.
  curl -fsSL --retry 3 -o "$WORK/templates.tpz" "$BASE/Godot_v${GODOT_VERSION}_export_templates.tpz"
  unzip -q -o -j "$WORK/templates.tpz" 'templates/web_nothreads_*.zip' 'templates/version.txt' -d "$TEMPLATE_DIR"
  rm -f "$WORK/templates.tpz"
fi

# Convenience: `godot` on PATH when we are allowed to write there (cloud setup runs as root).
if [ -w /usr/local/bin ]; then ln -sf "$BIN" /usr/local/bin/godot; fi
# In GitHub Actions, expose the binary to later steps.
if [ -n "${GITHUB_ENV:-}" ]; then echo "GODOT=$BIN" >> "$GITHUB_ENV"; fi

echo "Godot $("$BIN" --version) installed at $BIN"
echo "Web templates in $TEMPLATE_DIR"
