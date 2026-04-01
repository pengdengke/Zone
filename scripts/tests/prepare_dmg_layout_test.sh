#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

APP_SOURCE="$TMP_DIR/Zone.app"
STAGING_DIR="$TMP_DIR/staging"

mkdir -p "$APP_SOURCE/Contents/MacOS"
printf '#!/usr/bin/env bash\nexit 0\n' > "$APP_SOURCE/Contents/MacOS/Zone"
chmod +x "$APP_SOURCE/Contents/MacOS/Zone"

"$ROOT/scripts/prepare_dmg_layout.sh" "$APP_SOURCE" "$STAGING_DIR"

if [[ ! -d "$STAGING_DIR/Zone.app" ]]; then
  echo "expected staged app at $STAGING_DIR/Zone.app"
  exit 1
fi

if [[ ! -L "$STAGING_DIR/Applications" ]]; then
  echo "expected Applications symlink in DMG staging dir"
  exit 1
fi

if [[ "$(readlink "$STAGING_DIR/Applications")" != "/Applications" ]]; then
  echo "expected Applications symlink to point at /Applications"
  exit 1
fi

echo "prepare_dmg_layout_test: ok"
