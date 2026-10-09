#!/usr/bin/env bash
# build.sh - one-command build for mumba (LineageOS 23.2, kernel built from source)
#
# Uses a local mumba.xml next to this script. If not present, falls back to
# MANIFEST_URL (e.g. the raw GitHub file once this repo is pushed).
set -euo pipefail

# --- settings ---
LINEAGE_BRANCH="${LINEAGE_BRANCH:-lineage-23.2}"
TARGET="${TARGET:-lineage_mumba-bp4a-userdebug}"
JOBS="${JOBS:-$(nproc --all)}"
SRC="${SRC:-$HOME/Documenti/lineage-mumba}"
OUT_DIR="${OUT_DIR:-out}"
BUILD_TARGET="${BUILD_TARGET:-bacon}"
SYNC="${SYNC:-true}"

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${MANIFEST_FILE:-$SELF_DIR/mumba.xml}"
MANIFEST_URL="${MANIFEST_URL:-https://raw.githubusercontent.com/fiftydinar/mumba-manifest/main/mumba.xml}"
# ----------------

export PATH="$HOME/.local/bin:$PATH"
export USE_CCACHE=1
# Fedora 44 no longer ships libcrypt.so.1, required by Lineage's bundled Perl
# during the kernel build. Reuse the local compatibility library if available.
if [[ -d "$HOME/.local/lib/perl-compat" ]]; then
  export LD_LIBRARY_PATH="$HOME/.local/lib/perl-compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

if [[ "$SYNC" != true && "$SYNC" != false ]]; then
  echo "error: SYNC must be true or false"
  exit 1
fi

command -v repo >/dev/null || { echo "error: 'repo' not found in PATH"; exit 1; }

mkdir -p "$SRC"
SRC="$(cd "$SRC" && pwd -P)"
if [[ "$OUT_DIR" != /* ]]; then
  mkdir -p "$SRC/$OUT_DIR"
else
  mkdir -p "$OUT_DIR"
  OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"
fi
export OUT_DIR
cd "$SRC"

if [ ! -d .repo ]; then
  echo "### repo init ($LINEAGE_BRANCH)"
  repo init -u https://github.com/LineageOS/android -b "$LINEAGE_BRANCH" --git-lfs
fi

mkdir -p .repo/local_manifests
if [ -f "$MANIFEST_FILE" ]; then
  echo "### local manifest: $MANIFEST_FILE"
  cp -f "$MANIFEST_FILE" .repo/local_manifests/mumba.xml
else
  echo "### local manifest (download): $MANIFEST_URL"
  curl -fsSL "$MANIFEST_URL" -o .repo/local_manifests/mumba.xml
fi

if [[ "$SYNC" == true ]]; then
  echo "### repo sync"
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags
else
  echo "### repo sync skipped (SYNC=false)"
fi

# The bundled Perl has RPATH $ORIGIN/../lib. Keep Fedora's libcrypt shim
# beside it so Kbuild can load it even when Ninja sanitizes LD_LIBRARY_PATH.
PERL_COMPAT_LIBRARY="$HOME/.local/lib/perl-compat/libcrypt.so.1"
if [[ -f "$PERL_COMPAT_LIBRARY" ]]; then
  LINEAGE_PERL_LIBRARY="$SRC/prebuilts/tools-lineage/linux-x86/lib/libcrypt.so.1"
  mkdir -p "$(dirname "$LINEAGE_PERL_LIBRARY")"
  if [[ ! -f "$LINEAGE_PERL_LIBRARY" ]]; then
    cp "$PERL_COMPAT_LIBRARY" "$LINEAGE_PERL_LIBRARY"
  elif ! cmp -s "$PERL_COMPAT_LIBRARY" "$LINEAGE_PERL_LIBRARY"; then
    echo "error: conflicting bundled Perl compatibility library: $LINEAGE_PERL_LIBRARY" >&2
    exit 1
  fi
  LINEAGE_PERL="$SRC/prebuilts/tools-lineage/linux-x86/bin/perl"
  if command -v patchelf >/dev/null && [[ "$(patchelf --print-rpath "$LINEAGE_PERL")" != '$ORIGIN/../lib' ]]; then
    patchelf --set-rpath '$ORIGIN/../lib' "$LINEAGE_PERL"
  fi
fi

echo "### apply local patches"
bash "$SELF_DIR/apply_port.sh"

echo "### build"
# Lineage envsetup/lunch use optional unset shell variables.
set +u
. build/envsetup.sh
lunch "$TARGET"
read -r -a BUILD_TARGETS <<< "$BUILD_TARGET"
mka "${BUILD_TARGETS[@]}" -j"$JOBS"
