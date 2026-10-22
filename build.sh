#!/usr/bin/env bash
# build.sh - one-command build for mumba (LineageOS 23.2, kernel built from source)
#
# Uses a local mumba.xml next to this script. If not present, falls back to
# MANIFEST_URL (e.g. the raw GitHub file once this repo is pushed).
set -euo pipefail

# --- settings ---
LINEAGE_BRANCH="${LINEAGE_BRANCH:-lineage-23.2}"
TARGET="${TARGET:-lineage_mumba-bp4a-userdebug}"
# Cap parallel jobs by memory as well as cores: a full AOSP build uses roughly
# 5 GiB per job, so nproc alone OOMs and the kernel gets killed mid-build.
JOBS="${JOBS:-$(python3 -c "
import os
page = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES')
cpu = os.cpu_count() or 1
print(max(1, min(cpu, int(page / (5 << 30)) * 2)))
")}"
SRC="${SRC:-$HOME/Documenti/lineage-mumba}"
OUT_DIR="${OUT_DIR:-}"
BUILD_TARGET="${BUILD_TARGET:-bacon}"
SYNC="${SYNC:-true}"

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${MANIFEST_FILE:-$SELF_DIR/mumba.xml}"
MANIFEST_URL="${MANIFEST_URL:-https://raw.githubusercontent.com/fiftydinar/mumba-manifest/main/mumba.xml}"
# Debug GApps builds need their own out tree just like release builds.
if [[ -z "$OUT_DIR" ]]; then
  if [[ "$TARGET" == *gapps* ]]; then
    OUT_DIR="out-gapps"
  else
    OUT_DIR="out"
  fi
fi
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

# GApps variant: stage the latest MindTheGapps into vendor/partner_gms before lunch.
if [[ "$TARGET" == lineage_mumba_gapps-* ]]; then
  # Pin an exact MindTheGapps release so GApps builds are reproducible.
  if [[ -z "${MINDTHEGAPPS_TAG:-}" ]]; then
    MINDTHEGAPPS_TAG="MindTheGapps-16.0.0-arm64-20260915_222150"
    echo "### MINDTHEGAPPS_TAG not set, using pinned default: $MINDTHEGAPPS_TAG"
  fi
  echo "### stage MindTheGapps (vendor/partner_gms)"
  python3 "$SELF_DIR/tools/fetch_mindthegapps.py" --tree "$SRC" --tag "$MINDTHEGAPPS_TAG"
fi

echo "### build"
# Lineage envsetup/lunch use optional unset shell variables.
set +u
. build/envsetup.sh
lunch "$TARGET"
read -r -a BUILD_TARGETS <<< "$BUILD_TARGET"
mka "${BUILD_TARGETS[@]}" -j"$JOBS"
