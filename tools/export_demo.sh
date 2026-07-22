#!/usr/bin/env bash
# Build demo binaries using Project export presets (Godot 4.7+).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
mkdir -p build/web

echo "== Checking export templates =="
# Godot looks in ~/Library/Application Support/Godot/export_templates/<version>
VER="$($GODOT --version 2>/dev/null | head -1 | sed -E 's/.*([0-9]+\.[0-9]+).*/\1/' || true)"
echo "Godot: $($GODOT --version 2>/dev/null | head -1)"

export_one() {
  local name="$1" out="$2"
  echo "== Export: $name → $out =="
  $GODOT --headless --path "$ROOT" --export-release "$name" "$out" 2>&1 | tail -30
}

case "${1:-all}" in
  mac|macos)
    export_one "macOS" "build/AshenDepths.app"
    if [[ -d build/AshenDepths.app ]]; then
      echo "== Ad-hoc codesign (no Apple Developer cert) =="
      codesign --force --deep --sign - "build/AshenDepths.app" || true
      codesign -dv --verbose=2 "build/AshenDepths.app" 2>&1 | head -15 || true
    fi
    ;;
  win|windows)
    export_one "Windows Desktop" "build/AshenDepths.exe"
    ;;
  web)
    export_one "Web" "build/web/index.html"
    ;;
  all)
    "$0" macos || true
    "$0" windows || true
    "$0" web || true
    ;;
  *)
    echo "Usage: $0 [macos|windows|web|all]"
    exit 1
    ;;
esac
echo "Done. See docs/EXPORT.md"
