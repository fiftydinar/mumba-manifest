#!/usr/bin/env bash
# Sign a user target-files package and create a signed full OTA.
set -euo pipefail

usage() {
  echo "Usage: $0 KEY_DIR [TARGET_FILES.zip] [RELEASE_DIR]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 3 ]] || usage

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="${SRC:-$HOME/Documenti/lineage-mumba-release}"
[[ -d "$SRC" ]] || { echo "error: source tree not found: $SRC" >&2; exit 1; }
SRC="$(cd "$SRC" && pwd -P)"
OUT_DIR="${OUT_DIR:-$SRC/out}"
if [[ "$OUT_DIR" != /* ]]; then
  OUT_DIR="$SRC/$OUT_DIR"
fi
[[ -d "$OUT_DIR" ]] || { echo "error: output directory not found: $OUT_DIR" >&2; exit 1; }
OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"
PRODUCT_OUT="$OUT_DIR/target/product/mumba"
HOST_TOOLS="$OUT_DIR/host/linux-x86"
SIGN_TOOL="$HOST_TOOLS/bin/sign_target_files_apks"
OTA_TOOL="$HOST_TOOLS/bin/ota_from_target_files"

KEY_DIR="$1"
[[ -d "$KEY_DIR" ]] || { echo "error: signing key directory not found: $KEY_DIR" >&2; exit 1; }
KEY_DIR="$(cd "$KEY_DIR" && pwd -P)"
if [[ "$KEY_DIR" == "$SELF_DIR" || "$KEY_DIR" == "$SELF_DIR/"* || \
      "$KEY_DIR" == "$SRC" || "$KEY_DIR" == "$SRC/"* || \
      "$KEY_DIR" == "$OUT_DIR" || "$KEY_DIR" == "$OUT_DIR/"* ]]; then
  echo "error: keep private signing keys outside the repository, source tree, and output tree" >&2
  exit 1
fi

required_keys=(
  releasekey.pk8 releasekey.x509.pem
  platform.pk8 platform.x509.pem
  shared.pk8 shared.x509.pem
  media.pk8 media.x509.pem
  networkstack.pk8 networkstack.x509.pem
  sdk_sandbox.pk8 sdk_sandbox.x509.pem
  bluetooth.pk8 bluetooth.x509.pem
  nfc.pk8 nfc.x509.pem
  avb-vbmeta-rsa4096.pem avb-vbmeta-system-rsa2048.pem
  apex-payload-rsa4096.pem
)
for key in "${required_keys[@]}"; do
  [[ -f "$KEY_DIR/$key" ]] || { echo "error: missing signing key: $KEY_DIR/$key" >&2; exit 1; }
done

if [[ $# -ge 2 ]]; then
  TARGET_FILES="$2"
  [[ "$TARGET_FILES" == /* ]] || TARGET_FILES="$PWD/$TARGET_FILES"
  [[ -f "$TARGET_FILES" ]] || { echo "error: target-files archive not found: $TARGET_FILES" >&2; exit 1; }
else
  shopt -s nullglob
  target_files=("$PRODUCT_OUT"/obj/PACKAGING/target_files_intermediates/*target_files*.zip)
  if [[ ${#target_files[@]} -ne 1 ]]; then
    echo "error: expected exactly one target-files ZIP under $PRODUCT_OUT/obj/PACKAGING/target_files_intermediates" >&2
    echo "       pass the desired ZIP explicitly if multiple builds are present" >&2
    exit 1
  fi
  TARGET_FILES="${target_files[0]}"
fi

if ! unzip -p "$TARGET_FILES" SYSTEM/build.prop | grep -Fx 'ro.build.type=user' >/dev/null; then
  echo "error: target-files package is not a user build; refusing to sign it as a release" >&2
  exit 1
fi

[[ -x "$SIGN_TOOL" ]] || { echo "error: missing releasetools binary: $SIGN_TOOL" >&2; exit 1; }
[[ -x "$OTA_TOOL" ]] || { echo "error: missing releasetools binary: $OTA_TOOL" >&2; exit 1; }

RELEASE_DIR="${3:-$PRODUCT_OUT/release-signed}"
if [[ -d "$RELEASE_DIR" ]]; then
  shopt -s nullglob dotglob
  existing=("$RELEASE_DIR"/*)
  if [[ ${#existing[@]} -ne 0 ]]; then
    echo "error: output directory is not empty: $RELEASE_DIR" >&2
    echo "       choose a new RELEASE_DIR to preserve existing artifacts" >&2
    exit 1
  fi
else
  mkdir -p "$RELEASE_DIR"
fi

SIGNED_TARGET_FILES="$RELEASE_DIR/lineage_mumba-signed-target_files.zip"
SIGNED_OTA="$RELEASE_DIR/lineage_mumba-signed-ota.zip"

echo "### signing target-files with release APK/OTA and AVB keys"
"$SIGN_TOOL" -p "$HOST_TOOLS" -o -d "$KEY_DIR" \
  -k "build/make/target/product/security/nfc=$KEY_DIR/nfc" \
  --override_apex_keys "$KEY_DIR/apex-payload-rsa4096.pem" \
  --avb_vbmeta_algorithm SHA256_RSA4096 \
  --avb_vbmeta_key "$KEY_DIR/avb-vbmeta-rsa4096.pem" \
  --avb_vbmeta_system_algorithm SHA256_RSA2048 \
  --avb_vbmeta_system_key "$KEY_DIR/avb-vbmeta-system-rsa2048.pem" \
  "$TARGET_FILES" "$SIGNED_TARGET_FILES"

echo "### generating signed full OTA"
"$OTA_TOOL" -p "$HOST_TOOLS" -k "$KEY_DIR/releasekey" \
  "$SIGNED_TARGET_FILES" "$SIGNED_OTA"

sha256sum "$SIGNED_TARGET_FILES" "$SIGNED_OTA" > "$RELEASE_DIR/SHA256SUMS"
echo "Signed target-files: $SIGNED_TARGET_FILES"
echo "Signed OTA:          $SIGNED_OTA"
echo "Checksums:           $RELEASE_DIR/SHA256SUMS"
