#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
ARCHIVE_PATH="$ROOT/build/Zone.xcarchive"
APP_PATH="$ROOT/build/Zone.app"
STAGING_PATH="$ROOT/build/Zone-dmg-root"
RW_DMG_PATH="$ROOT/build/Zone-temp.dmg"
DMG_PATH="$ROOT/build/Zone.dmg"

mkdir -p "$ROOT/build"
rm -f "$ROOT/build/.DS_Store"
swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
xcodegen generate
xcodebuild \
  -project "$ROOT/Zone.xcodeproj" \
  -scheme Zone \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive \
  -archivePath "$ARCHIVE_PATH"

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Zone.app" "$APP_PATH"
rm -rf "$STAGING_PATH"
rm -f "$RW_DMG_PATH"
rm -f "$DMG_PATH"
"$ROOT/scripts/prepare_dmg_layout.sh" "$APP_PATH" "$STAGING_PATH"
hdiutil create -volname Zone -srcfolder "$STAGING_PATH" -ov -format UDRW "$RW_DMG_PATH"

DEVICE_NAME=""
cleanup() {
  if [[ -n "$DEVICE_NAME" ]]; then
    hdiutil detach "$DEVICE_NAME" >/dev/null 2>&1 || true
  fi

  rm -rf "$STAGING_PATH"
  rm -f "$RW_DMG_PATH"
}
trap cleanup EXIT

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG_PATH")"
DEVICE_NAME="$(printf '%s\n' "$ATTACH_OUTPUT" | "$ROOT/scripts/resolve_attached_dmg_device.sh")"

if [[ -n "$DEVICE_NAME" ]]; then
  if ! "$ROOT/scripts/render_dmg_layout_applescript.sh" Zone Zone.app | osascript >/dev/null 2>&1; then
    echo "warning: Finder layout customization skipped; DMG contents are still valid." >&2
  fi
  hdiutil detach "$DEVICE_NAME"
  DEVICE_NAME=""
fi

hdiutil convert "$RW_DMG_PATH" -ov -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH%.dmg}"
rm -rf "$ARCHIVE_PATH"
rm -rf "$APP_PATH"
rm -f "$ROOT/build/.DS_Store"
