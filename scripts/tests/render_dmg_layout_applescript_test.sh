#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT="$("$ROOT/scripts/render_dmg_layout_applescript.sh" Zone Zone.app)"

[[ "$OUTPUT" == *'set current view of container window to icon view'* ]] || {
  echo "expected icon view setup"
  exit 1
}

[[ "$OUTPUT" == *'set position of item "Zone.app" of container window to {150, 190}'* ]] || {
  echo "expected Zone.app icon position"
  exit 1
}

[[ "$OUTPUT" == *'set position of item "Applications" of container window to {430, 190}'* ]] || {
  echo "expected Applications icon position"
  exit 1
}

echo "render_dmg_layout_applescript_test: ok"
