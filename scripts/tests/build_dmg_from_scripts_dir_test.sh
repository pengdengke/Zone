#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PROJECT_ROOT="$TMP_DIR/project-root"
mkdir -p "$TMP_DIR/bin" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/App/Resources/Assets.xcassets/AppIcon.appiconset"

cp "$ROOT/scripts/build_dmg.sh" "$PROJECT_ROOT/scripts/build_dmg.sh"
chmod +x "$PROJECT_ROOT/scripts/build_dmg.sh"

cat > "$PROJECT_ROOT/project.yml" <<'EOF'
name: Zone
EOF

cat > "$PROJECT_ROOT/App/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
</dict>
</plist>
EOF

cat > "$PROJECT_ROOT/scripts/generate_app_icon.swift" <<'EOF'
print("stub icon generation")
EOF

cat > "$PROJECT_ROOT/scripts/prepare_dmg_layout.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$2"
cp -R "$1" "$2/Zone.app"
ln -s /Applications "$2/Applications"
EOF
chmod +x "$PROJECT_ROOT/scripts/prepare_dmg_layout.sh"

cat > "$PROJECT_ROOT/scripts/render_dmg_layout_applescript.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'tell application "Finder"\nend tell\n'
EOF
chmod +x "$PROJECT_ROOT/scripts/render_dmg_layout_applescript.sh"

cat > "$PROJECT_ROOT/scripts/resolve_attached_dmg_device.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '/dev/disk99\n'
EOF
chmod +x "$PROJECT_ROOT/scripts/resolve_attached_dmg_device.sh"

cat > "$PROJECT_ROOT/scripts/sign_app_bundle.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -d "$1"
EOF
chmod +x "$PROJECT_ROOT/scripts/sign_app_bundle.sh"

cat > "$TMP_DIR/bin/xcodegen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "generate" && "${2:-}" == "--spec" ]]; then
  spec_path="$3"
else
  spec_path="$PWD/project.yml"
fi

if [[ ! -f "$spec_path" ]]; then
  echo "No project spec found at $spec_path" >&2
  exit 1
fi
EOF
chmod +x "$TMP_DIR/bin/xcodegen"

cat > "$TMP_DIR/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

archive_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -archivePath)
      archive_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "$archive_path/Products/Applications/Zone.app/Contents/MacOS"
cat > "$archive_path/Products/Applications/Zone.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Zone</string>
  <key>CFBundleIdentifier</key>
  <string>com.pengdengke.Zone</string>
  <key>CFBundleName</key>
  <string>Zone</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
PLIST
printf '#!/usr/bin/env bash\nexit 0\n' > "$archive_path/Products/Applications/Zone.app/Contents/MacOS/Zone"
chmod +x "$archive_path/Products/Applications/Zone.app/Contents/MacOS/Zone"
EOF
chmod +x "$TMP_DIR/bin/xcodebuild"

cat > "$TMP_DIR/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-C" ]]; then
  shift 2
fi

if [[ "$1" == "describe" && "$2" == "--tags" && "$3" == "--exact-match" ]]; then
  printf 'v1.2.3\n'
  exit 0
fi

echo "unexpected git invocation: $*" >&2
exit 1
EOF
chmod +x "$TMP_DIR/bin/git"

cat > "$TMP_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat <<'JSON'
{"tag_name":"v1.2.3","html_url":"https://github.com/pengdengke/Zone/releases/tag/v1.2.3","draft":false,"prerelease":false}
JSON
EOF
chmod +x "$TMP_DIR/bin/curl"

cat > "$TMP_DIR/bin/hdiutil" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  create)
    output_path="${@: -1}"
    : > "$output_path"
    ;;
  attach)
    printf '/dev/disk99\tGUID_partition_scheme\n'
    ;;
  detach)
    ;;
  convert)
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -o)
          output_base="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    : > "${output_base}.dmg"
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/hdiutil"

cat > "$TMP_DIR/bin/osascript" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
EOF
chmod +x "$TMP_DIR/bin/osascript"

(
  cd "$PROJECT_ROOT/scripts"
  PATH="$TMP_DIR/bin:$PATH" ./build_dmg.sh
)

echo "build_dmg_from_scripts_dir_test: ok"
