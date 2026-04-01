#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ATTACH_OUTPUT="$(cat <<'EOF'
/dev/disk8	GUID_partition_scheme
/dev/disk8s1	Apple_APFS_ISC
/dev/disk9	EF57347C-0000-11AA-AA11-00306543ECAC
/dev/disk9s1	41504653-0000-11AA-AA11-00306543ECAC	/Volumes/Zone 1
EOF
)"

DEVICE_NAME="$(printf '%s\n' "$ATTACH_OUTPUT" | "$ROOT/scripts/resolve_attached_dmg_device.sh")"

if [[ "$DEVICE_NAME" != "/dev/disk8" ]]; then
  echo "expected /dev/disk8, got: $DEVICE_NAME"
  exit 1
fi

echo "resolve_attached_dmg_device_test: ok"
