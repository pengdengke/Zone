#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?usage: sign_app_bundle.sh /path/to/App.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "error: Info.plist not found at $INFO_PLIST" >&2
  exit 1
fi

IDENTITY="${ZONE_CODESIGN_IDENTITY:--}"
REQUIREMENTS="${ZONE_CODESIGN_REQUIREMENTS:-}"

if [[ -z "$REQUIREMENTS" && "$IDENTITY" == "-" ]]; then
  BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$INFO_PLIST" 2>/dev/null || true)"

  if [[ -z "$BUNDLE_ID" ]]; then
    echo "error: CFBundleIdentifier is required for stable ad-hoc signing" >&2
    exit 1
  fi

  REQUIREMENTS="designated => identifier \"$BUNDLE_ID\""
fi

COMMAND=(codesign --force --deep --sign "$IDENTITY")

if [[ -n "$REQUIREMENTS" ]]; then
  COMMAND+=(--requirements "=$REQUIREMENTS")
fi

COMMAND+=("$APP_PATH")
"${COMMAND[@]}"
