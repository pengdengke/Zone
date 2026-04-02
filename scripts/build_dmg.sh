#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-pengdengke/Zone}"
GITHUB_API_BASE_URL="${GITHUB_API_BASE_URL:-https://api.github.com}"
GITHUB_API_VERSION="${GITHUB_API_VERSION:-2022-11-28}"
GITHUB_USER_AGENT="${GITHUB_USER_AGENT:-Zone}"
INFO_PLIST_PATH="$ROOT/App/Info.plist"

resolve_tag_name() {
  local tag_name
  tag_name="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"

  if [[ -z "$tag_name" ]]; then
    echo "error: current HEAD must match an exact git tag before packaging." >&2
    exit 1
  fi

  printf '%s\n' "$tag_name"
}

normalize_version_from_tag() {
  local tag_name="$1"
  local version="${tag_name#v}"

  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
    echo "error: tag $tag_name must use semantic versioning like v1.2.3." >&2
    exit 1
  fi

  printf '%s\n' "$version"
}

require_formal_release_for_tag() {
  local tag_name="$1"
  local release_json
  local release_url="$GITHUB_API_BASE_URL/repos/$GITHUB_REPOSITORY/releases/tags/$tag_name"
  local -a curl_args=(
    --silent
    --show-error
    --fail
    --location
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: $GITHUB_API_VERSION"
    -H "User-Agent: $GITHUB_USER_AGENT"
  )

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi

  if ! release_json="$(curl "${curl_args[@]}" "$release_url")"; then
    echo "error: GitHub Release for tag $tag_name was not found in $GITHUB_REPOSITORY." >&2
    exit 1
  fi

  if ! printf '%s' "$release_json" | python3 -c '
import json
import sys

tag_name = sys.argv[1]
payload = json.load(sys.stdin)

if payload.get("tag_name") != tag_name:
    sys.stderr.write(
        f"error: GitHub Release tag mismatch: expected {tag_name}, got {payload.get('tag_name')!r}.\n"
    )
    raise SystemExit(1)

if payload.get("draft"):
    sys.stderr.write(f"error: GitHub Release {tag_name} is still a draft.\n")
    raise SystemExit(1)

if payload.get("prerelease"):
    sys.stderr.write(f"error: GitHub Release {tag_name} is a pre-release; only formal releases are allowed.\n")
    raise SystemExit(1)
' "$tag_name"
  then
    exit 1
  fi
}

backup_source_artifacts() {
  mkdir -p "$BACKUP_ROOT"
  cp "$INFO_PLIST_PATH" "$INFO_PLIST_BACKUP"
  cp -R "$ICONSET" "$ICONSET_BACKUP"
}

restore_source_artifacts() {
  if [[ -f "$INFO_PLIST_BACKUP" ]]; then
    cp "$INFO_PLIST_BACKUP" "$INFO_PLIST_PATH"
  fi

  if [[ -d "$ICONSET_BACKUP" ]]; then
    rm -rf "$ICONSET"
    cp -R "$ICONSET_BACKUP" "$ICONSET"
  fi
}

set_plist_string() {
  local plist_path="$1"
  local key="$2"
  local value="$3"

  if ! /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_path" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_path" >/dev/null
  fi
}

stamp_release_version() {
  set_plist_string "$INFO_PLIST_PATH" "CFBundleShortVersionString" "$MARKETING_VERSION"
  set_plist_string "$INFO_PLIST_PATH" "CFBundleVersion" "$MARKETING_VERSION"
}

TAG_NAME="$(resolve_tag_name)"
MARKETING_VERSION="$(normalize_version_from_tag "$TAG_NAME")"
ICONSET="$ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"
ARCHIVE_PATH="$ROOT/build/Zone.xcarchive"
APP_PATH="$ROOT/build/Zone.app"
STAGING_PATH="$ROOT/build/Zone-dmg-root"
RW_DMG_PATH="$ROOT/build/Zone-${TAG_NAME}-temp.dmg"
DMG_PATH="$ROOT/build/Zone-${TAG_NAME}.dmg"
BACKUP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zone-build-source.XXXXXX")"
INFO_PLIST_BACKUP="$BACKUP_ROOT/Info.plist"
ICONSET_BACKUP="$BACKUP_ROOT/AppIcon.appiconset"
DEVICE_NAME=""

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e

  if [[ -n "$DEVICE_NAME" ]]; then
    hdiutil detach "$DEVICE_NAME" >/dev/null 2>&1 || true
  fi

  restore_source_artifacts
  rm -rf "$STAGING_PATH"
  rm -f "$RW_DMG_PATH"
  rm -rf "$BACKUP_ROOT"
  exit "$exit_code"
}
trap cleanup EXIT

mkdir -p "$ROOT/build"
rm -f "$ROOT/build/.DS_Store"
backup_source_artifacts
require_formal_release_for_tag "$TAG_NAME"
swift "$ROOT/scripts/generate_app_icon.swift" "$ICONSET"
xcodegen generate --spec "$ROOT/project.yml"
stamp_release_version
xcodebuild \
  -project "$ROOT/Zone.xcodeproj" \
  -scheme Zone \
  -configuration Release \
  -destination 'platform=macOS' \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$MARKETING_VERSION" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  archive \
  -archivePath "$ARCHIVE_PATH"

rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/Zone.app" "$APP_PATH"
"$ROOT/scripts/sign_app_bundle.sh" "$APP_PATH"
rm -rf "$STAGING_PATH"
rm -f "$RW_DMG_PATH"
rm -f "$DMG_PATH"
"$ROOT/scripts/prepare_dmg_layout.sh" "$APP_PATH" "$STAGING_PATH"
hdiutil create -volname Zone -srcfolder "$STAGING_PATH" -ov -format UDRW "$RW_DMG_PATH"

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
