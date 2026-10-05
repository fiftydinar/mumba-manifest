# mumba-manifest

LineageOS **23.2** (Android 16) for the **Motorola Moto G57 Power / G100s** (**mumba**),
with the **kernel built from source**.

This repository contains:
- `mumba.xml` - local manifest (device tree, vendor, hardware, kernel source/modules/devicetrees,
  OpenEUICC LPA) with **pinned revisions** (commit SHA) for reproducible builds.
- `build.sh` - userdebug build; `SYNC=false` reuses the synced source tree.
- `build_release.sh` + `sign_release.sh` - isolated `user` build and locally
  signed target-files/OTA release.
- `apply_port.sh` + `port/` - fifteen local patches for device fixes, audio and
  touchscreen compatibility, adaptive refresh rates, OpenEUICC/eSIM, and Dialer
  auto call recording, applied on top of a fresh `repo sync`.

## Usage

```bash
# clone this repository and start the build
git clone https://github.com/fiftydinar/mumba-manifest.git
cd mumba-manifest
bash build.sh

# or, from the build tree, install the local manifest and patches manually
export PATH=~/.local/bin:$PATH
repo init -u https://github.com/LineageOS/android -b lineage-23.2 --git-lfs
mkdir -p .repo/local_manifests
curl -fsSL https://raw.githubusercontent.com/fiftydinar/mumba-manifest/main/mumba.xml \
     -o .repo/local_manifests/mumba.xml
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags

# apply all local customizations and compatibility fixes
bash apply_port.sh

. build/envsetup.sh
lunch lineage_mumba-bp4a-userdebug
mka bacon -j$(nproc)
```

Output: `out/target/product/mumba/lineage-23.2-*-mumba.zip`

## Separate signed user release

`build_release.sh` uses a separate source tree (`$HOME/Documenti/lineage-mumba-release`)
and output directory, so it leaves the normal userdebug checkout and artifacts
alone. It builds `lineage_mumba-bp4a-user` and creates a target-files package.
For subsequent builds in that tree, `SYNC=false bash build_release.sh` skips
`repo sync`; patch application is safe to repeat. The normal debug build can
likewise be rebuilt without syncing using `SYNC=false bash build.sh`.

Create personal signing keys outside both source/output trees and this
repository. For example:

```bash
SRC="$HOME/Documenti/lineage-mumba-release"
KEYS="$HOME/.android-certs/mumba"
umask 077
mkdir -m 700 -p "$KEYS"
chmod 700 "$KEYS"
for key in releasekey platform shared media networkstack sdk_sandbox bluetooth nfc; do
  "$SRC/development/tools/make_key" "$KEYS/$key" "/CN=Mumba Release/"
done
openssl genrsa -out "$KEYS/avb-vbmeta-rsa4096.pem" 4096
openssl genrsa -out "$KEYS/avb-vbmeta-system-rsa2048.pem" 2048
openssl genrsa -out "$KEYS/apex-payload-rsa4096.pem" 4096
```

Then build and sign:

```bash
bash build_release.sh
SRC="$HOME/Documenti/lineage-mumba-release" bash sign_release.sh "$KEYS"
```

`sign_release.sh` preserves the unsigned target-files package and writes a
signed target-files ZIP, signed full OTA, and SHA-256 checksums under
`out/target/product/mumba/release-signed/`. It expects the key names shown
above; it remaps the platform/default APK keys, replaces APEX payload keys, and
signs vbmeta with the personal AVB keys. Keep the same key set for future OTA
updates. The script refuses to overwrite a non-empty output directory or use
keys inside the repo/source tree. These are personal ROM/AVB keys, not Motorola
OEM keys, so they do not enable relocking the bootloader or OEM Verified Boot
trust.

## Components

| Path | Repository | Purpose |
|---|---|---|
| `device/motorola/mumba` | [fiftydinar/android_device_motorola_mumba](https://github.com/fiftydinar/android_device_motorola_mumba) | forked ZaraKinYu device tree; builds the kernel from source |
| `vendor/motorola/mumba` | [fiftydinar/vendor_motorola_mumba_latest](https://github.com/fiftydinar/vendor_motorola_mumba_latest) | forked lostsignal vendor tree; proprietary blobs |
| `hardware/motorola` | [fiftydinar/android_hardware_motorola](https://github.com/fiftydinar/android_hardware_motorola) | forked Motorola HAL |
| `kernel/motorola/sm6435` | [fiftydinar/android_kernel_motorola_sm6435](https://github.com/fiftydinar/android_kernel_motorola_sm6435) | forked kernel source (Kbuild) |
| `kernel/motorola/sm6435-modules` | [fiftydinar/android_kernel_motorola_sm6435-modules](https://github.com/fiftydinar/android_kernel_motorola_sm6435-modules) | forked external modules |
| `kernel/motorola/sm6435-devicetrees` | [fiftydinar/android_kernel_motorola_sm6435-devicetrees](https://github.com/fiftydinar/android_kernel_motorola_sm6435-devicetrees) | forked DTS sources |
| `packages/apps/OpenEUICC` | [fiftydinar/OpenEUICC](https://github.com/fiftydinar/OpenEUICC) | GitHub mirror of PeterCxy OpenEUICC; eSIM LPA (system `EuiccService`) |
| `prebuilts/openeuicc-deps` | [fiftydinar/android_prebuilts_openeuicc-deps](https://github.com/fiftydinar/android_prebuilts_openeuicc-deps) | GitHub mirror of OpenEUICC prebuilt libraries |
| `packages/apps/Messaging` | [fiftydinar/android_packages_apps_Messaging](https://github.com/fiftydinar/android_packages_apps_Messaging) | fork with notification read and verification-code copy actions |
| `hardware/qcom-caf/common/libqti-perfd-client` | [fiftydinar/android_hardware_qcom-caf_common](https://github.com/fiftydinar/android_hardware_qcom-caf_common) | forked LineageOS CAF stub; QTI perf API compatibility |

Everything else (framework, etc.) comes from the **official LineageOS** manifest.

## Source revisions

The following revisions are pinned in `mumba.xml`:

| Path | GitHub copy | Original upstream | Upstream source commit | `mumba.xml` pin |
|---|---|---|---|---|
| `device/motorola/mumba` | [`fiftydinar/android_device_motorola_mumba`](https://github.com/fiftydinar/android_device_motorola_mumba) | `ZaraKinYu-Playground/android_device_motorola_mumba` | `c87184155fc8482f4dd469aa67b0ab98049cb735` | `c87184155fc8482f4dd469aa67b0ab98049cb735` |
| `vendor/motorola/mumba` | [`fiftydinar/vendor_motorola_mumba_latest`](https://github.com/fiftydinar/vendor_motorola_mumba_latest) | `lostsignal-502/vendor_motorola_mumba_latest` | `8bcc9d41ca36b5e2ae93d592226eac163225ade9` | `8bcc9d41ca36b5e2ae93d592226eac163225ade9` |
| `hardware/motorola` | [`fiftydinar/android_hardware_motorola`](https://github.com/fiftydinar/android_hardware_motorola) | `lostsignal-502/android_hardware_motorola` | `8cee9a14b9bd59b1d4eeab69d838569a0935a106` | `8cee9a14b9bd59b1d4eeab69d838569a0935a106` |
| `kernel/motorola/sm6435` | [`fiftydinar/android_kernel_motorola_sm6435`](https://github.com/fiftydinar/android_kernel_motorola_sm6435) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435` | `2df509385d9c1df4c65a01cfda0302e7de52fc75` | `2df509385d9c1df4c65a01cfda0302e7de52fc75` |
| `kernel/motorola/sm6435-modules` | [`fiftydinar/android_kernel_motorola_sm6435-modules`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-modules) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435-modules` | `0659ac7d22557e405529e00e2b5fdace57964636` | `0659ac7d22557e405529e00e2b5fdace57964636` |
| `kernel/motorola/sm6435-devicetrees` | [`fiftydinar/android_kernel_motorola_sm6435-devicetrees`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-devicetrees) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435-devicetrees` | `2c0587b0d4d90e0b3b00f87c9430360ea15ebdb6` | `2c0587b0d4d90e0b3b00f87c9430360ea15ebdb6` |
| `packages/apps/OpenEUICC` | [`fiftydinar/OpenEUICC`](https://github.com/fiftydinar/OpenEUICC) | `gitea.angry.im/PeterCxy/OpenEUICC` | `2a85b8dad6000eea9dd622a468b7558e79933b2a` | `4130828243a2fb07aa1c07fc5813aa218ea912bf` |
| `prebuilts/openeuicc-deps` | [`fiftydinar/android_prebuilts_openeuicc-deps`](https://github.com/fiftydinar/android_prebuilts_openeuicc-deps) | `gitea.angry.im/PeterCxy/android_prebuilts_openeuicc-deps` | `540216793010cabc49782bd01844cd8dd28a4c7c` | `540216793010cabc49782bd01844cd8dd28a4c7c` |
| `hardware/qcom-caf/sm8450/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `9f4dec53710a32af11cfffd89256daf7de2a9dee` | `9f4dec53710a32af11cfffd89256daf7de2a9dee` |
| `hardware/qcom-caf/sm8550/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `aa1495561e9ca90e80c5a2b898a67f75406dc874` | `aa1495561e9ca90e80c5a2b898a67f75406dc874` |
| `hardware/qcom-caf/sm8650/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `2aa541f626ecc029fce24f3882aaee84c11fb161` | `2aa541f626ecc029fce24f3882aaee84c11fb161` |
| `hardware/qcom-caf/sm8750/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `443dec4613a7e5dbc997eb2d7b087f0f07ae5258` | `443dec4613a7e5dbc997eb2d7b087f0f07ae5258` |

These customized LineageOS projects are also overridden in `mumba.xml`. The
upstream base SHAs are from the resolved `lineage-23.2` manifest
(`repo manifest -r`); the Messaging fork is pinned to its feature commit.

| Project path | GitHub copy | Original upstream | Base commit | `mumba.xml` pin |
|---|---|---|---|---|
| `frameworks/base` | [`fiftydinar/android_frameworks_base`](https://github.com/fiftydinar/android_frameworks_base) | `LineageOS/android_frameworks_base` | `1c45e31a86be95f51a94ffd1a5014c3fb2019112` | `1c45e31a86be95f51a94ffd1a5014c3fb2019112` |
| `frameworks/opt/telephony` | [`fiftydinar/android_frameworks_opt_telephony`](https://github.com/fiftydinar/android_frameworks_opt_telephony) | `LineageOS/android_frameworks_opt_telephony` | `566e62daf4e93be6f934001bc76d60aba087b4d6` | `566e62daf4e93be6f934001bc76d60aba087b4d6` |
| `packages/apps/Settings` | [`fiftydinar/android_packages_apps_Settings`](https://github.com/fiftydinar/android_packages_apps_Settings) | `LineageOS/android_packages_apps_Settings` | `8d8f6486b274bcf0aa6e5d0cbba52c0b05ae5c65` | `8d8f6486b274bcf0aa6e5d0cbba52c0b05ae5c65` |
| `packages/apps/Dialer` | [`fiftydinar/android_packages_apps_Dialer`](https://github.com/fiftydinar/android_packages_apps_Dialer) | `LineageOS/android_packages_apps_Dialer` | `6da8042323a97d5b3cba1fd975709cc42f29916f` | `6da8042323a97d5b3cba1fd975709cc42f29916f` |
| `packages/apps/Messaging` | [`fiftydinar/android_packages_apps_Messaging`](https://github.com/fiftydinar/android_packages_apps_Messaging) | `LineageOS/android_packages_apps_Messaging` | `6d131ed8e7249b0ece41169e17d8d0162beae7e0` | `65d835a1749c0ac520fc3903fda01275165a3787` |
| `hardware/qcom-caf/common` | [`fiftydinar/android_hardware_qcom-caf_common`](https://github.com/fiftydinar/android_hardware_qcom-caf_common) | `LineageOS/android_hardware_qcom-caf_common` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| `hardware/qcom-caf/sm8450-6.6/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `6a42341357a56903eea27a74fdb161a26402dcc3` | `6a42341357a56903eea27a74fdb161a26402dcc3` |

The GitHub projects are forks, except for the two OpenEUICC repositories,
which are full GitHub mirrors of their original Gitea repositories.

OpenEUICC's submodules also use GitHub forks, pinned by the OpenEUICC gitlinks:

| Path | GitHub copy | Original upstream | Submodule commit |
|---|---|---|---|
| `OpenEUICC/libs/lpac-jni/src/main/jni/lpac` | [`fiftydinar/lpac`](https://github.com/fiftydinar/lpac) | `estkme-group/lpac` | `d214738fa0bdb23faf5833d3d798963079a00468` |
| `OpenEUICC/libs/lpac-jni/src/main/jni/cjson/cjson` | [`fiftydinar/cJSON`](https://github.com/fiftydinar/cJSON) | `DaveGamble/cJSON` | `c859b25da02955fef659d658b8f324b5cde87be3` |

## Forks and local changes

- `mumba.xml` fetches the pinned projects from the public copies under
  `github.com/fiftydinar`; each project stays pinned to its documented source SHA.
- Port patches remain in `port/` and are applied by `apply_port.sh`; Messaging's
  notification changes are maintained in its pinned component fork.
- The forks preserve their upstream Git history and branches. OpenEUICC and its
  dependencies are mirrored from Gitea, so they do not have a GitHub fork parent.

## Messaging notification actions

Incoming-message notifications now offer **Mark as read**. A single-conversation
notification also offers **Copy code** when the latest message contains one clear
4–8 digit code or 4–10 character alphanumeric token containing a digit near
verification wording (for example, “verification code”, “OTP”, or “passcode”).
The code is copied only after the user taps the action. Ambiguous detections and
messages without a verification keyword are ignored. The keyword set covers all
70 language codes shipped by Messaging (including both Serbian and Chinese
scripts); detection accepts Unicode decimal digits and grouped three-digit codes.

From the initialized build tree, run the detector/dispatch host tests and device
intent/clipboard-payload tests with:

```bash
m MessagingNotificationLogicTests MessagingNotificationActionTests messaging
atest --host MessagingNotificationLogicTests
atest MessagingNotificationActionTests
```

Do not fork `LineageOS/android` directly: its `fetch=".."` would break every remote in the manifest.

## Notes
- Build uses test-keys -> the first flash is a **clean flash**.
- The userdebug build is SELinux permissive; the separate `user` release omits
  that boot argument, uses enforcing mode, and leaves AVB verification enabled.
- `flash_all.sh` runs `fastboot -w` and erases userdata. Set `IMG_DIR` to the
  build output directory, e.g. `IMG_DIR="/path/to/lineage-mumba/out/target/product/mumba" bash flash_all.sh`.
- ccache speeds up rebuilds.
- The first build takes hours (kernel + ~170k targets).
- **eSIM** works on vanilla via **OpenEUICC** (privileged LPA, no Google).
  The mirrored source is based on the last pre-SDK37 commit; the three
  `openeuicc-*` patches adapt it to the A16 tree and hide its standalone launcher.
- Tested on the eSIM variant XT2537-5. Settings and telephony include runtime
  handling for physical-SIM-only variants, but a physical-only unit has not
  been tested.
- **Automatic call recording** (record all incoming/outgoing calls) is added to
  Dialer via `dialer-autorecord.patch` (Gerrit change 251235, never merged upstream).
- Audio compatibility patches enable the Mumba FS1815 modules, restore the vendor
  audio policy volumes file, add missing QTI perf symbols, and match the stock
  two-DTB/two-DTBO layout.
