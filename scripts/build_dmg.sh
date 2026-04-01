#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
ARCHIVE_PATH="$ROOT/build/Zone.xcarchive"
APP_PATH="$ROOT/build/Zone.app"
DMG_PATH="$ROOT/build/Zone.dmg"

mkdir -p "$ROOT/build"
swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
xcodegen generate
xcodebuild \
  -project "$ROOT/Zone.xcodeproj" \
  -scheme Zone \
  -configuration Release \
  -destination 'platform=macOS' \
  archive \
  -archivePath "$ARCHIVE_PATH"

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Zone.app" "$APP_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname Zone -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"
