# shellcheck shell=bash
# Sourced by the build/sign/publish scripts.
# Vanilla and GApps are separate products and must not share an output tree:
# building one after the other in the same out/ leaks the other's files into the
# packaged image (e.g. GApps showing up in the vanilla product/).

# Echo the per-variant output directory (relative to the source tree).
mumba_out_dir() {
  case "${1:-}" in
    *gapps*) echo "out-gapps" ;;
    *)       echo "out-vanilla" ;;
  esac
}
