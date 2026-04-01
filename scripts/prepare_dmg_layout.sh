#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <app-source> <staging-dir>" >&2
  exit 64
fi

APP_SOURCE="$1"
STAGING_DIR="$2"
APP_NAME="$(basename "$APP_SOURCE")"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "app source not found: $APP_SOURCE" >&2
  exit 66
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_SOURCE" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

