#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

APP_PATH="$TMP_DIR/Zone.app"
mkdir -p "$APP_PATH/Contents/MacOS"

cat > "$APP_PATH/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Zone</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.Zone</string>
    <key>CFBundleName</key>
    <string>Zone</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF

printf '#!/usr/bin/env bash\nexit 0\n' > "$APP_PATH/Contents/MacOS/Zone"
chmod +x "$APP_PATH/Contents/MacOS/Zone"

"$ROOT/scripts/sign_app_bundle.sh" "$APP_PATH"

REQUIREMENTS="$(codesign -d -r- "$APP_PATH" 2>&1)"
DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"

[[ "$REQUIREMENTS" == *'designated => identifier "com.example.Zone"'* ]] || {
  echo "expected designated requirement to use the bundle identifier"
  exit 1
}

[[ "$DETAILS" == *'Identifier=com.example.Zone'* ]] || {
  echo "expected app signature identifier to match bundle identifier"
  exit 1
}

codesign --verify --verbose=4 "$APP_PATH" >/dev/null 2>&1 || {
  echo "expected signed app bundle to verify successfully"
  exit 1
}

echo "sign_app_bundle_test: ok"
