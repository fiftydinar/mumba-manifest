#!/usr/bin/env bash
# apply_port.sh - apply all local customizations after `repo sync`.
# Run from the build tree root (the dir that contains device/ and vendor/).
set -e
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# patch file : tree path
declare -A PATCH_TREE=(
  [device-mumba]="device/motorola/mumba"
  [mumba-ota-updater]="device/motorola/mumba"
  [mumba-refresh-defaults]="device/motorola/mumba"
  [speaker-eq-device]="device/motorola/mumba"
  [display-srgb-device]="device/motorola/mumba"
  [settings-provider-refresh-defaults]="frameworks/base"
  [vendor-mumba]="vendor/motorola/mumba"
  [speaker-eq-vendor]="vendor/motorola/mumba"
  [openeuicc-deps]="prebuilts/openeuicc-deps"
  [openeuicc-app]="packages/apps/OpenEUICC"
  [openeuicc-hide-launcher]="packages/apps/OpenEUICC"
  [settings-euicc-hardware-detection]="packages/apps/Settings"
  [display-srgb-settings]="packages/apps/Settings"
  [uiccslot-physical-removable]="frameworks/opt/telephony"
  [dialer-autorecord]="packages/apps/Dialer"
  [perfd-client]="hardware/qcom-caf/common/libqti-perfd-client"
  [audio-kernel]="kernel/motorola/sm6435-modules"
  [audiomanifest]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [speaker-eq-audio]="hardware/qcom-caf/sm8450-6.6/audio/primary-hal"
  [speaker-eq-audioflinger]="frameworks/av"
  [adb-root-debug]="packages/modules/adb"
  [touch-kbuild]="kernel/motorola/sm6435-modules"
  [display-refresh]="kernel/motorola/sm6435-devicetrees"
)

PORT_STATE_DIR="$PWD/.repo/local_manifests/mumba-port-state"
mkdir -p "$PORT_STATE_DIR"

for name in device-mumba mumba-ota-updater mumba-refresh-defaults speaker-eq-device display-srgb-device settings-provider-refresh-defaults vendor-mumba speaker-eq-vendor openeuicc-deps openeuicc-app openeuicc-hide-launcher settings-euicc-hardware-detection display-srgb-settings uiccslot-physical-removable dialer-autorecord perfd-client audio-kernel audiomanifest speaker-eq-audio speaker-eq-audioflinger adb-root-debug touch-kbuild display-refresh; do
  patch="$SELF_DIR/port/$name.patch"
  tree="${PATCH_TREE[$name]}"
  if [ ! -f "$patch" ]; then
    echo "missing $patch"; exit 1
  fi
  if [ ! -d "$tree" ]; then
    echo "missing $tree (run repo sync first)"; exit 1
  fi
  marker="$PORT_STATE_DIR/$name"
  patch_hash="$(sha256sum "$patch" | cut -d ' ' -f 1)"
  tree_revision="$(git -C "$tree" rev-parse HEAD)"
  if [ -f "$marker" ] && read -r applied_hash applied_revision < "$marker" && \
     [ "$patch_hash" = "$applied_hash" ] && [ "$tree_revision" = "$applied_revision" ]; then
    echo "already applied (state): $patch -> $tree"
    continue
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
  printf '%s %s\n' "$patch_hash" "$tree_revision" > "$marker"
done

# Use the bundled Perl for Kbuild's PERLASM scripts. This is necessary on hosts
# where system Perl is absent and keeps the kernel build independent of PATH.
python3 - "$PWD/device/motorola/mumba/BoardConfig.mk" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
setting = (
    "# Use the bundled Perl for kernel scripts.\n"
    "TARGET_KERNEL_ADDITIONAL_FLAGS += -j4 PERL=$(BUILD_TOP)/prebuilts/tools-lineage/linux-x86/bin/perl\n"
)
perl_setting = "TARGET_KERNEL_ADDITIONAL_FLAGS += -j4 PERL=$(BUILD_TOP)/prebuilts/tools-lineage/linux-x86/bin/perl\n"
if perl_setting in text:
    print("already configured: bundled Perl for Kbuild")
else:
    marker = "TARGET_KERNEL_VERSION := 6.6\n"
    if text.count(marker) != 1:
        raise SystemExit(f"cannot place bundled Perl setting in {path}")
    path.write_text(text.replace(marker, marker + setting, 1), encoding="utf-8")
    print("configured bundled Perl for Kbuild")
PY

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

# Give each legacy CAF SoC tree its own Soong namespace. These marker files
# exist in the established build checkout but are not tracked by the source repos.
qcom_caf_namespace_source="$SELF_DIR/port/qcom-caf-soong-namespaces/Android.bp"
qcom_caf_namespace_soc_dirs=(
  msm8953 msm8998 sdm660 sdm845
  sm8150 sm8250 sm8350 sm8450 sm8450-6.6 sm8550 sm8650 sm8750
)
for soc in "${qcom_caf_namespace_soc_dirs[@]}"; do
  qcom_caf_dir="$PWD/hardware/qcom-caf/$soc"
  qcom_caf_target="$qcom_caf_dir/Android.bp"
  if [ ! -d "$qcom_caf_dir" ]; then
    echo "missing QCOM CAF tree: $qcom_caf_dir"
    exit 1
  fi
  if [ "$soc" = msm8998 ]; then
    qcom_caf_source="$SELF_DIR/port/qcom-caf-soong-namespaces/msm8998-Android.bp"
  else
    qcom_caf_source="$qcom_caf_namespace_source"
  fi
  if [ -f "$qcom_caf_target" ]; then
    if ! cmp -s "$qcom_caf_source" "$qcom_caf_target"; then
      echo "unexpected QCOM CAF namespace marker: $qcom_caf_target"
      exit 1
    fi
  else
    cp "$qcom_caf_source" "$qcom_caf_target"
  fi
done
echo "installed/verified ${#qcom_caf_namespace_soc_dirs[@]} QCOM CAF Soong namespace markers"

# The messaging app contains Serbian translations in Cyrillic only. Generate
# the matching Latin-script resource qualifier when the device locale is sr-Latn.
python3 "$SELF_DIR/tools/generate_sr_latin_resources.py" \
  "$PWD/packages/apps/Messaging/res"
