#!/usr/bin/env bash
# Publish a signed user A/B OTA as a GitHub Release and update the public feed.
set -euo pipefail

usage() {
  echo "Usage: $0 TAG [RELEASE_DIR] [RELEASE_NOTES.md] [RECOVERY.img]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 4 ]] || usage

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY="fiftydinar/mumba-manifest"
TAG="$1"
SRC="${SRC:-$HOME/Documenti/lineage-mumba-release}"
RELEASE_DIR="${2:-$SRC/out/target/product/mumba/release-signed}"
NOTES_FILE="${3:-}"
RECOVERY_IMG="${4:-}"

[[ "$TAG" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  echo "error: invalid release tag: $TAG" >&2
  exit 1
}
[[ -d "$RELEASE_DIR" ]] || { echo "error: release directory not found: $RELEASE_DIR" >&2; exit 1; }
RELEASE_DIR="$(cd "$RELEASE_DIR" && pwd -P)"
OTA="$RELEASE_DIR/lineage_mumba-signed-ota.zip"
TARGET_FILES="$RELEASE_DIR/lineage_mumba-signed-target_files.zip"
[[ -f "$OTA" ]] || { echo "error: signed OTA not found: $OTA" >&2; exit 1; }
[[ -f "$TARGET_FILES" ]] || { echo "error: signed target-files not found: $TARGET_FILES" >&2; exit 1; }
if [[ -n "$NOTES_FILE" && ! -f "$NOTES_FILE" ]]; then
  echo "error: release notes file not found: $NOTES_FILE" >&2
  exit 1
fi
if [[ -n "$NOTES_FILE" ]]; then
  NOTES_FILE="$(cd "$(dirname "$NOTES_FILE")" && pwd -P)/$(basename "$NOTES_FILE")"
fi
if [[ -n "$RECOVERY_IMG" ]]; then
  [[ -f "$RECOVERY_IMG" ]] || { echo "error: recovery image not found: $RECOVERY_IMG" >&2; exit 1; }
  RECOVERY_IMG="$(cd "$(dirname "$RECOVERY_IMG")" && pwd -P)/$(basename "$RECOVERY_IMG")"
  if [[ "$(stat -c %s "$RECOVERY_IMG")" -gt $((2 * 1024 * 1024 * 1024)) ]]; then
    echo "error: recovery image exceeds GitHub's 2 GiB per-release-asset limit" >&2
    exit 1
  fi
fi

cd "$SELF_DIR"
[[ "$(git branch --show-current)" == "main" ]] || {
  echo "error: publish from the manifest main branch" >&2
  exit 1
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "error: manifest worktree must be clean before publishing" >&2
  exit 1
}
git fetch --quiet origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || {
  echo "error: local main is not up to date with origin/main; pull and retry" >&2
  exit 1
}
gh auth status --hostname github.com >/dev/null
if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  echo "error: release already exists: $TAG" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
OTA_NAME="$(basename "$OTA")"
CHECKSUM_FILE="$TEMP_DIR/$OTA_NAME.sha256"
FEED_FILE="$TEMP_DIR/updates.json"
RELEASE_ASSETS=("$OTA" "$CHECKSUM_FILE")
python3 "$SELF_DIR/ota/generate_updates.py" \
  --target-files "$TARGET_FILES" \
  --ota "$OTA" \
  --tag "$TAG" \
  --repository "$REPOSITORY" \
  --output "$FEED_FILE" \
  --checksum-output "$CHECKSUM_FILE"

if [[ -n "$RECOVERY_IMG" ]]; then
  RECOVERY_CHECKSUM_FILE="$TEMP_DIR/$(basename "$RECOVERY_IMG").sha256"
  python3 - "$RECOVERY_IMG" "$RECOVERY_CHECKSUM_FILE" <<'PY'
import hashlib
import sys
from pathlib import Path

asset = Path(sys.argv[1])
checksum_file = Path(sys.argv[2])
digest = hashlib.sha256()
with asset.open("rb") as stream:
    for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
        digest.update(chunk)
checksum_file.write_text(
    f"{digest.hexdigest()}  {asset.name}\n",
    encoding="utf-8",
)
PY
  RELEASE_ASSETS+=("$RECOVERY_IMG" "$RECOVERY_CHECKSUM_FILE")
fi

TITLE="LineageOS 23.2 for mumba — $TAG"
if [[ -n "$NOTES_FILE" ]]; then
  gh release create "$TAG" "${RELEASE_ASSETS[@]}" \
    --repo "$REPOSITORY" \
    --title "$TITLE" \
    --notes-file "$NOTES_FILE" \
    --latest
else
  RELEASE_NOTES="Signed full A/B OTA for Motorola Moto G57 Power / G100s (mumba)."
  if [[ -n "$RECOVERY_IMG" ]]; then
    RELEASE_NOTES+=$'\n\nRecovery image included for manual recovery use.'
  fi
  gh release create "$TAG" "${RELEASE_ASSETS[@]}" \
    --repo "$REPOSITORY" \
    --title "$TITLE" \
    --notes "$RELEASE_NOTES" \
    --latest
fi

python3 - "$FEED_FILE" "$SELF_DIR/ota/updates.json" <<'PY'
import os
import shutil
import sys
import tempfile
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
    temporary_path = Path(temporary.name)
    with source.open("rb") as input_file:
        shutil.copyfileobj(input_file, temporary)
os.replace(temporary_path, destination)
PY

git add ota/updates.json
git commit -m "ota: Publish $TAG"
if ! git push origin main; then
  echo "error: release is live, but the feed commit was not pushed; resolve main and push it" >&2
  exit 1
fi

echo "Published GitHub release: https://github.com/$REPOSITORY/releases/tag/$TAG"
echo "Updater feed: https://raw.githubusercontent.com/$REPOSITORY/main/ota/updates.json"
