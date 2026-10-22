#!/usr/bin/env bash
# Verify that the device-tree patch chain applies to the pinned device repository.
# This catches duplicate or conflicting hunks without requiring a full repo sync.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_REPO="https://github.com/fiftydinar/android_device_motorola_mumba"
DEVICE_PATH="device/motorola/mumba"
PATCHES=(
  device-mumba
  device-mumba-gapps
  mumba-ota-updater
  mumba-refresh-defaults
  speaker-eq-device
  display-srgb-device
)

pin="$(python3 - "$SELF_DIR/mumba.xml" "$DEVICE_PATH" <<'PY'
import sys
import xml.etree.ElementTree as ET

manifest, wanted_path = sys.argv[1], sys.argv[2]
for project in ET.parse(manifest).getroot().iter("project"):
    if project.get("path") == wanted_path:
        revision = project.get("revision")
        if not revision:
            sys.exit(f"{wanted_path} has no revision")
        print(revision)
        break
else:
    sys.exit(f"{wanted_path} not found in {manifest}")
PY
)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
git -C "$tmp" remote add origin "$DEVICE_REPO"
git -C "$tmp" fetch -q --depth=1 origin "$pin"
git -C "$tmp" checkout -q FETCH_HEAD

for name in "${PATCHES[@]}"; do
  patch="$SELF_DIR/port/$name.patch"
  [[ -f "$patch" ]] || { echo "missing patch: $patch" >&2; exit 1; }
  git -C "$tmp" apply --check --whitespace=nowarn "$patch"
  git -C "$tmp" apply --whitespace=nowarn "$patch"
  echo "applied $name"
done

echo "device patch chain applies at $pin"
