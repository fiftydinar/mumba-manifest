#!/usr/bin/env bash
# Build an isolated user/release target-files package. Signing is a separate step.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SELF_DIR/tools/out_dir.sh"
SRC="${SRC:-$HOME/Documenti/lineage-mumba-release}"
TARGET="${TARGET:-lineage_mumba-bp4a-user}"
OUT_DIR="${OUT_DIR:-$(mumba_out_dir "$TARGET")}"
BUILD_TARGET="${BUILD_TARGET:-target-files-package otatools-package}"
JOBS="${JOBS:-2}"

if [[ "$TARGET" != *-user ]]; then
  echo "error: release target must use the user build variant, got: $TARGET" >&2
  exit 1
fi
case " $BUILD_TARGET " in
  *" target-files-package "*) ;;
  *) echo "error: BUILD_TARGET must include target-files-package" >&2; exit 1 ;;
esac

export SRC OUT_DIR TARGET BUILD_TARGET JOBS
exec bash "$SELF_DIR/build.sh"
