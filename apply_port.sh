#!/usr/bin/env bash
# apply_port.sh - apply all local customizations after `repo sync`.
# Run from the build tree root (the dir that contains device/ and vendor/).
set -e
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# patch file : tree path
declare -A PATCH_TREE=(
  [device-mumba]="device/motorola/mumba"
  [mumba-refresh-defaults]="device/motorola/mumba"
  [speaker-eq-device]="device/motorola/mumba"
  [settings-provider-refresh-defaults]="frameworks/base"
  [vendor-mumba]="vendor/motorola/mumba"
  [speaker-eq-vendor]="vendor/motorola/mumba"
  [openeuicc-deps]="prebuilts/openeuicc-deps"
  [openeuicc-app]="packages/apps/OpenEUICC"
  [openeuicc-hide-launcher]="packages/apps/OpenEUICC"
  [settings-euicc-hardware-detection]="packages/apps/Settings"
  [uiccslot-physical-removable]="frameworks/opt/telephony"
  [dialer-autorecord]="packages/apps/Dialer"
  [perfd-client]="hardware/qcom-caf/common/libqti-perfd-client"
  [audio-kernel]="kernel/motorola/sm6435-modules"
  [audiomanifest]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [speaker-eq-audio]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [speaker-eq-audioflinger]="frameworks/av"
  [touch-kbuild]="kernel/motorola/sm6435-modules"
  [display-refresh]="kernel/motorola/sm6435-devicetrees"
)

for name in device-mumba mumba-refresh-defaults speaker-eq-device settings-provider-refresh-defaults vendor-mumba speaker-eq-vendor openeuicc-deps openeuicc-app openeuicc-hide-launcher settings-euicc-hardware-detection uiccslot-physical-removable dialer-autorecord perfd-client audio-kernel audiomanifest speaker-eq-audio speaker-eq-audioflinger touch-kbuild display-refresh; do
  patch="$SELF_DIR/port/$name.patch"
  tree="${PATCH_TREE[$name]}"
  if [ ! -f "$patch" ]; then
    echo "missing $patch"; exit 1
  fi
  if [ ! -d "$tree" ]; then
    echo "missing $tree (run repo sync first)"; exit 1
  fi
  if git -C "$tree" apply --check --whitespace=nowarn "$patch" >/dev/null 2>&1; then
    git -C "$tree" apply --whitespace=nowarn "$patch"
    echo "applied $patch -> $tree"
  elif git -C "$tree" apply --reverse --check --whitespace=nowarn "$patch" >/dev/null 2>&1; then
    echo "already applied: $patch -> $tree"
  else
    echo "cannot apply (or detect as already applied): $patch -> $tree"
    exit 1
  fi
done

# The effect implementation is a source asset rather than generated vendor data.
speaker_eq_source="$SELF_DIR/port/speaker-eq/MumbaSpeakerEqualizer.cpp"
speaker_eq_target="$PWD/device/motorola/mumba/audio/speaker_eq/MumbaSpeakerEqualizer.cpp"
mkdir -p "$(dirname "$speaker_eq_target")"
if [ -f "$speaker_eq_target" ]; then
  if ! cmp -s "$speaker_eq_source" "$speaker_eq_target"; then
    echo "speaker EQ source differs from $speaker_eq_source"
    exit 1
  fi
else
  cp "$speaker_eq_source" "$speaker_eq_target"
fi

# The messaging app contains Serbian translations in Cyrillic only. Generate
# the matching Latin-script resource qualifier when the device locale is sr-Latn.
python3 "$SELF_DIR/tools/generate_sr_latin_resources.py" \
  "$PWD/packages/apps/Messaging/res"
