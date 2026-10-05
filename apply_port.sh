#!/usr/bin/env bash
# apply_port.sh - apply all local customizations after `repo sync`.
# Run from the build tree root (the dir that contains device/ and vendor/).
set -e
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# patch file : tree path
declare -A PATCH_TREE=(
  [device-mumba]="device/motorola/mumba"
  [mumba-refresh-defaults]="device/motorola/mumba"
  [settings-provider-refresh-defaults]="frameworks/base"
  [vendor-mumba]="vendor/motorola/mumba"
  [openeuicc-deps]="prebuilts/openeuicc-deps"
  [openeuicc-app]="packages/apps/OpenEUICC"
  [openeuicc-hide-launcher]="packages/apps/OpenEUICC"
  [settings-euicc-hardware-detection]="packages/apps/Settings"
  [uiccslot-physical-removable]="frameworks/opt/telephony"
  [dialer-autorecord]="packages/apps/Dialer"
  [perfd-client]="hardware/qcom-caf/common/libqti-perfd-client"
  [audio-kernel]="kernel/motorola/sm6435-modules"
  [audiomanifest]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [touch-kbuild]="kernel/motorola/sm6435-modules"
  [display-refresh]="kernel/motorola/sm6435-devicetrees"
)

for name in device-mumba mumba-refresh-defaults settings-provider-refresh-defaults vendor-mumba openeuicc-deps openeuicc-app openeuicc-hide-launcher settings-euicc-hardware-detection uiccslot-physical-removable dialer-autorecord perfd-client audio-kernel audiomanifest touch-kbuild display-refresh; do
  patch="$SELF_DIR/port/$name.patch"
  tree="${PATCH_TREE[$name]}"
  if [ ! -f "$patch" ]; then
    echo "missing $patch"; exit 1
  fi
  if [ ! -d "$tree" ]; then
    echo "missing $tree (run repo sync first)"; exit 1
  fi
  git -C "$tree" apply --whitespace=nowarn "$patch"
  echo "applied $patch -> $tree"
done
