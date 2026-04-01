#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <volume-name> <app-name>" >&2
  exit 64
fi

VOLUME_NAME="$1"
APP_NAME="$2"

cat <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        tell container window
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {120, 120, 640, 420}
        end tell
        tell icon view options of container window
            set arrangement of icon view options of container window to not arranged
            set icon size of icon view options of container window to 128
            set text size of icon view options of container window to 16
        end tell
        set position of item "$APP_NAME" of container window to {150, 190}
        set position of item "Applications" of container window to {430, 190}
        update without registering applications
        delay 1
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF
