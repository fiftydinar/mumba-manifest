# mumba-manifest

LineageOS **23.2** (Android 16) for the **Motorola Moto G57 Power / G100s** (**mumba**),
with the **kernel built from source**.

This repository contains:
- `mumba.xml` - local manifest (device tree, vendor, hardware, kernel
  source/modules/devicetrees, Aperture camera fork, OpenEUICC LPA) with **pinned
  revisions** (commit SHA) for custom and patch-target
  projects. Unmodified upstream projects still follow the `lineage-23.2` branch;
  run `repo manifest -r -o manifest-snapshot.xml` in a synced tree if you need
  a fully reproducible manifest snapshot.
- `build.sh` - userdebug build; `SYNC=false` reuses the synced source tree.
- `build_release.sh` + `sign_release.sh` - isolated `user` build and locally
  signed target-files/OTA release.
- `publish_release.sh` + `ota/` - publish a signed A/B OTA to GitHub Releases
  and update the LineageOS Updater feed on `main`.
- `apply_port.sh` + `port/` - twenty-seven local patches for device fixes, audio,
  debug tooling, touchscreen compatibility, adaptive refresh rates, OpenEUICC/eSIM,
  Dialer auto call recording, updater changelog/issues links, and the OTA feed URL,
  applied on top of a fresh `repo sync`; it also installs the required QCOM CAF
  Soong namespace markers.
- The framework fork contains restricted package-signature and Java boot-property
  compatibility mappings.

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
and per-variant output directories (`out-vanilla`, `out-gapps`), so it leaves the
normal userdebug checkout and artifacts alone and keeps the variants from
leaking files into each other. It builds the `user` target for the chosen
variant — `TARGET=lineage_mumba-bp4a-user` (vanilla, default) or
`TARGET=lineage_mumba_gapps-bp4a-user` (GApps) — including the target-files
package and the host releasetools required to sign it. The default release
concurrency is two jobs; override with `JOBS` if the build host has more memory.
The GApps target stages MindTheGapps into `vendor/partner_gms` before `lunch`
(see the GApps section); it is pinned by `MINDTHEGAPPS_TAG`, defaulting to a
fixed release.
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
signed target-files ZIP, signed full OTA, and SHA-256 checksums under the
per-variant release directory, e.g.
`out-vanilla/target/product/mumba/release-signed/` for the vanilla target
(`TARGET=lineage_mumba-bp4a-user`, the default) or
`out-gapps/target/product/mumba/release-signed/` for the GApps target
(`TARGET=lineage_mumba_gapps-bp4a-user`). It expects the key names shown
above; it remaps the platform/default APK keys, replaces APEX payload keys, and
signs vbmeta with the personal AVB keys, leaving GApps APKs `presigned` in the
GApps variant. Keep the same key set for future OTA
updates. The script refuses to overwrite a non-empty output directory or use
keys inside the repo/source tree. These are personal ROM/AVB keys, not Motorola
OEM keys, so they do not enable relocking the bootloader or OEM Verified Boot
trust.

### Build fingerprint and signing keys

`lineage_mumba.mk` overrides the generated build fingerprint to a stock Motorola
value:

```text
motorola/mumba_g/mumba:16/W1WAAS36.48-12-23-9/83f8c:user/test-keys
```

This is a compatibility override, not a statement about the signing keys:

- The final `test-keys` field is part of the fingerprint string that apps read
  through `ro.build.fingerprint`. It does not select, contain, or verify a
  signing key.
- The default `userdebug` build is signed with the public AOSP test keys.
- The signed `user` release is re-signed by `sign_release.sh` with the personal
  `releasekey`, platform/shared/media/... keys and the personal AVB keys. Its
  actual signer is your key, even though the overridden fingerprint still ends
  in `test-keys`.
- Keystore and Play Integrity attestation do not trust this string; they use
  attestation and the actual keys.
- To make the fingerprint reflect the real build instead, remove the
  `BuildFingerprint`/`BuildDesc` overrides or change `test-keys` to
  `release-keys`. That may affect app compatibility, which is why the stock
  value is kept.

### Publish an OTA to GitHub Releases

The ROM includes the LineageOS **Updater** app and uses Android's A/B
`update_engine`. `apply_port.sh` configures it to read the current update feed at
[`ota/updates.json`](ota/updates.json) from this repository's `main` branch; the
GApps variant uses the separate [`ota/updates-gapps.json`](ota/updates-gapps.json)
feed, so vanilla and GApps installs never receive each other's OTAs. Each
published release contains the signed full OTA, the flash images (boot, dtbo,
init_boot, vendor_boot, recovery, vbmeta, vbmeta_system) with per-file checksums,
and `copy-partitions-20220613-signed.zip`; the feed points to the versioned
GitHub Release asset. The updater downloads and
verifies the signed OTA, installs it to the inactive slot with `update_engine`,
and prompts for a reboot.

After `build_release.sh` and `sign_release.sh` complete, publish with GitHub CLI
authenticated as a user who can publish releases and push to `main`. Set
`VARIANT=gapps` for the GApps release (it publishes to `updates-gapps.json` and
labels the release "(GApps)"); the release directory must match the variant:

```bash
export SRC="$HOME/Documenti/lineage-mumba-release"

# vanilla (default)
bash publish_release.sh "mumba-23.2-YYYYMMDD" \
  "$SRC/out-vanilla/target/product/mumba/release-signed"

# GApps
VARIANT=gapps bash publish_release.sh "mumba-23.2-gapps-YYYYMMDD" \
  "$SRC/out-gapps/target/product/mumba/release-signed"
```

Both commands accept optional release notes and a matching recovery image as
the third and fourth arguments. The releases appear in the XDA thread download
links; both variants must use distinct tags.

The script validates that the target-files package is a `user` build for mumba,
that its version matches the selected variant, and that it matches the signed
A/B OTA metadata; it then uploads the OTA and checksum as the latest GitHub
Release and commits and pushes the new feed entry to `main`.
Use a new tag for each release. The manifest checkout must be clean, on `main`,
and synchronized with `origin/main`. If publishing succeeds but the feed push is
interrupted, the release remains available; resolve the local manifest commit
and push it to `main` to publish its feed entry.

The feed generator tests can be run with `python3 -m unittest discover -s tests`.
The device patch chain can be checked against the pinned tree with
`bash tools/check_device_patches.sh`.

## Components

| Path | Repository | Purpose |
|---|---|---|
| `device/motorola/mumba` | [fiftydinar/android_device_motorola_mumba](https://github.com/fiftydinar/android_device_motorola_mumba) | forked ZaraKinYu device tree; builds the kernel from source. The bundled microG FakeStore stub was removed (`fakestore/` directory dropped by `device-mumba-gapps.patch`) |
| `vendor/motorola/mumba` | [fiftydinar/vendor_motorola_mumba_latest](https://github.com/fiftydinar/vendor_motorola_mumba_latest) | forked lostsignal vendor tree; proprietary blobs and device firmware |
| `hardware/motorola` | [fiftydinar/android_hardware_motorola](https://github.com/fiftydinar/android_hardware_motorola) | forked Motorola HAL |
| `kernel/motorola/sm6435` | [fiftydinar/android_kernel_motorola_sm6435](https://github.com/fiftydinar/android_kernel_motorola_sm6435) | forked kernel source (Kbuild) |
| `kernel/motorola/sm6435-modules` | [fiftydinar/android_kernel_motorola_sm6435-modules](https://github.com/fiftydinar/android_kernel_motorola_sm6435-modules) | forked external modules |
| `kernel/motorola/sm6435-devicetrees` | [fiftydinar/android_kernel_motorola_sm6435-devicetrees](https://github.com/fiftydinar/android_kernel_motorola_sm6435-devicetrees) | forked DTS sources |
| `packages/apps/OpenEUICC` | [fiftydinar/OpenEUICC](https://github.com/fiftydinar/OpenEUICC) | GitHub mirror of PeterCxy OpenEUICC; eSIM LPA (system `EuiccService`) |
| `prebuilts/openeuicc-deps` | [fiftydinar/android_prebuilts_openeuicc-deps](https://github.com/fiftydinar/android_prebuilts_openeuicc-deps) | GitHub mirror of OpenEUICC prebuilt libraries |
| `packages/apps/Aperture` | [fiftydinar/android_packages_apps_Aperture](https://github.com/fiftydinar/android_packages_apps_Aperture) | mumba Camera2/GL preview, recording, and lens-switching fork |
| `packages/apps/Messaging` | [fiftydinar/android_packages_apps_Messaging](https://github.com/fiftydinar/android_packages_apps_Messaging) | fork with notification read and verification-code copy actions |
| `hardware/qcom-caf/common/libqti-perfd-client` | [fiftydinar/android_hardware_qcom-caf_common](https://github.com/fiftydinar/android_hardware_qcom-caf_common) | forked LineageOS CAF stub; QTI perf API compatibility |

The BOE and CSOT touchscreen firmware blobs are in the vendor fork's
[`lineage-23.2` branch](https://github.com/fiftydinar/vendor_motorola_mumba_latest/tree/lineage-23.2/proprietary/vendor/firmware):
[`boe_chipone_firmware.bin`](https://github.com/fiftydinar/vendor_motorola_mumba_latest/blob/lineage-23.2/proprietary/vendor/firmware/boe_chipone_firmware.bin)
and
[`csot_chipone_firmware.bin`](https://github.com/fiftydinar/vendor_motorola_mumba_latest/blob/lineage-23.2/proprietary/vendor/firmware/csot_chipone_firmware.bin).
`vendor-mumba.patch` adds the mappings that copy them into `/vendor/firmware`.
The additional Snapdragon Services executable and init rc are on the
[`mumba-vendor-service-blobs` branch](https://github.com/fiftydinar/vendor_motorola_mumba_latest/tree/mumba-vendor-service-blobs/proprietary/vendor)
and are included by the vendor commit pinned in `mumba.xml`.

Unlisted projects come from the **official LineageOS** manifest. `frameworks/base`
is the pinned fork listed below because it carries the microG and Java boot-property
compatibility changes.

## Aperture camera on mumba

The mumba-specific camera work is maintained in the
[`fiftydinar/android_packages_apps_Aperture` `mumba-test` branch](https://github.com/fiftydinar/android_packages_apps_Aperture/tree/mumba-test)
and currently pinned by `mumba.xml` to the upstream LineageOS Aperture commit
`1120b49b7f24e7ef04213db14a6f2e5e52b4f11c`. The mumba Camera2/GL work is paused and
is not yet part of the manifest, so a clean manifest sync selects the upstream camera.

On the Moto G57 Power, the fork uses a Camera2/GL path for aspect-ratio-aware
photo capture and supported SDR video profiles. Zoom is unified across the rear
sensors from 0.3× (native ultra-wide) to 8× (main) through pinch or the lens
buttons. Main, ultra-wide (0.3×), and selfie switches can stay in one video file
when that camera supports the selected resolution and frame rate. The selfie and
pause/resume controls remain separate while recording. Camera2 sessions are closed
before a profile resize/rebind, to avoid stale-session preview freezes during
PHOTO/VIDEO changes. A lens change draws its first frame with the crop for the
current zoom, so the viewfinder does not flash a native ultra-wide frame.

The phone exposes three Camera2 devices: rear main (`0`), front (`1`), and rear
ultra-wide (`2`). The front and ultra-wide sensors top out at 30fps; the main
camera supports FHD 60fps and 720p 120fps. Thus lens/selfie switching is exposed
for compatible profiles up to 30fps. The dedicated 720p120 constrained-high-speed
path remains main-camera-only. Motorola identifies the additional rear module as
a 2-in-1 ambient-light/flicker sensor, not an imaging/depth camera
([device specifications](https://en-us.support.motorola.com/app/answers/detail/a_id/190335/~/specifications---moto-g57-power)).

## Source revisions

The following revisions are pinned in `mumba.xml`:

| Path | GitHub copy | Original upstream | Upstream source commit | `mumba.xml` pin |
|---|---|---|---|---|
| `device/motorola/mumba` | [`fiftydinar/android_device_motorola_mumba`](https://github.com/fiftydinar/android_device_motorola_mumba) | `ZaraKinYu-Playground/android_device_motorola_mumba` | `c87184155fc8482f4dd469aa67b0ab98049cb735` | `2a34d1ed87fadfaf1dc34f503b99a7f418085f72` |
| `vendor/motorola/mumba` | [`fiftydinar/vendor_motorola_mumba_latest`](https://github.com/fiftydinar/vendor_motorola_mumba_latest) | `lostsignal-502/vendor_motorola_mumba_latest` | `8bcc9d41ca36b5e2ae93d592226eac163225ade9` | `3d41a357a60816d19321e74714f8bb6dfc024b43` |
| `hardware/motorola` | [`fiftydinar/android_hardware_motorola`](https://github.com/fiftydinar/android_hardware_motorola) | `lostsignal-502/android_hardware_motorola` | `8cee9a14b9bd59b1d4eeab69d838569a0935a106` | `8cee9a14b9bd59b1d4eeab69d838569a0935a106` |
| `kernel/motorola/sm6435` | [`fiftydinar/android_kernel_motorola_sm6435`](https://github.com/fiftydinar/android_kernel_motorola_sm6435) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435` | `2df509385d9c1df4c65a01cfda0302e7de52fc75` | `2df509385d9c1df4c65a01cfda0302e7de52fc75` |
| `kernel/motorola/sm6435-modules` | [`fiftydinar/android_kernel_motorola_sm6435-modules`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-modules) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435-modules` | `0659ac7d22557e405529e00e2b5fdace57964636` | `0659ac7d22557e405529e00e2b5fdace57964636` |
| `kernel/motorola/sm6435-devicetrees` | [`fiftydinar/android_kernel_motorola_sm6435-devicetrees`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-devicetrees) | `ZaraKinYu-Playground/android_kernel_motorola_sm6435-devicetrees` | `2c0587b0d4d90e0b3b00f87c9430360ea15ebdb6` | `2c0587b0d4d90e0b3b00f87c9430360ea15ebdb6` |
| `packages/apps/OpenEUICC` | [`fiftydinar/OpenEUICC`](https://github.com/fiftydinar/OpenEUICC) | `gitea.angry.im/PeterCxy/OpenEUICC` | `2a85b8dad6000eea9dd622a468b7558e79933b2a` | `4130828243a2fb07aa1c07fc5813aa218ea912bf` |
| `prebuilts/openeuicc-deps` | [`fiftydinar/android_prebuilts_openeuicc-deps`](https://github.com/fiftydinar/android_prebuilts_openeuicc-deps) | `gitea.angry.im/PeterCxy/android_prebuilts_openeuicc-deps` | `540216793010cabc49782bd01844cd8dd28a4c7c` | `540216793010cabc49782bd01844cd8dd28a4c7c` |
| `packages/apps/Aperture` | [`fiftydinar/android_packages_apps_Aperture`](https://github.com/fiftydinar/android_packages_apps_Aperture) | `LineageOS/android_packages_apps_Aperture` | `1120b49b7f24e7ef04213db14a6f2e5e52b4f11c` | `1120b49b7f24e7ef04213db14a6f2e5e52b4f11c` |
| `hardware/qcom-caf/sm8450/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `9f4dec53710a32af11cfffd89256daf7de2a9dee` | `9f4dec53710a32af11cfffd89256daf7de2a9dee` |
| `hardware/qcom-caf/sm8550/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `aa1495561e9ca90e80c5a2b898a67f75406dc874` | `aa1495561e9ca90e80c5a2b898a67f75406dc874` |
| `hardware/qcom-caf/sm8650/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `2aa541f626ecc029fce24f3882aaee84c11fb161` | `2aa541f626ecc029fce24f3882aaee84c11fb161` |
| `hardware/qcom-caf/sm8750/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `443dec4613a7e5dbc997eb2d7b087f0f07ae5258` | `443dec4613a7e5dbc997eb2d7b087f0f07ae5258` |

These customized LineageOS projects are also overridden in `mumba.xml`. The
upstream base SHAs are from the resolved `lineage-23.2` manifest
(`repo manifest -r`); the Messaging fork is pinned to its feature commit.

| Project path | GitHub copy | Original upstream | Base commit | `mumba.xml` pin |
|---|---|---|---|---|
| `frameworks/base` | [`fiftydinar/android_frameworks_base`](https://github.com/fiftydinar/android_frameworks_base) | `LineageOS/android_frameworks_base` | `1c45e31a86be95f51a94ffd1a5014c3fb2019112` | `427389d5e0a2fc4ad54db6d0fe49a420b7675156` |
| `frameworks/opt/telephony` | [`fiftydinar/android_frameworks_opt_telephony`](https://github.com/fiftydinar/android_frameworks_opt_telephony) | `LineageOS/android_frameworks_opt_telephony` | `566e62daf4e93be6f934001bc76d60aba087b4d6` | `566e62daf4e93be6f934001bc76d60aba087b4d6` |
| `packages/apps/Settings` | [`fiftydinar/android_packages_apps_Settings`](https://github.com/fiftydinar/android_packages_apps_Settings) | `LineageOS/android_packages_apps_Settings` | `8d8f6486b274bcf0aa6e5d0cbba52c0b05ae5c65` | `8d8f6486b274bcf0aa6e5d0cbba52c0b05ae5c65` |
| `packages/apps/Dialer` | [`fiftydinar/android_packages_apps_Dialer`](https://github.com/fiftydinar/android_packages_apps_Dialer) | `LineageOS/android_packages_apps_Dialer` | `6da8042323a97d5b3cba1fd975709cc42f29916f` | `6da8042323a97d5b3cba1fd975709cc42f29916f` |
| `packages/apps/Messaging` | [`fiftydinar/android_packages_apps_Messaging`](https://github.com/fiftydinar/android_packages_apps_Messaging) | `LineageOS/android_packages_apps_Messaging` | `6d131ed8e7249b0ece41169e17d8d0162beae7e0` | `d8feea90e13da21fa279e72982cc0bae49600f35` |
| `hardware/qcom-caf/common` | [`fiftydinar/android_hardware_qcom-caf_common`](https://github.com/fiftydinar/android_hardware_qcom-caf_common) | `LineageOS/android_hardware_qcom-caf_common` | `5cd53603d36aaddd9ba9d882dad5411f1b30fbed` | `5cd53603d36aaddd9ba9d882dad5411f1b30fbed` |
| `hardware/qcom-caf/sm8450-6.6/audio/primary-hal` | [`fiftydinar/android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `LineageOS/android_hardware_qcom_audio-ar` | `6a42341357a56903eea27a74fdb161a26402dcc3` | `6a42341357a56903eea27a74fdb161a26402dcc3` |
| `packages/apps/Updater` | LineageOS (via `remote="lineage"`) | `LineageOS/android_packages_apps_Updater` | `edcdadf41606ee7f1eb7adad4699d09374438c52` | `edcdadf41606ee7f1eb7adad4699d09374438c52` |
| `frameworks/av` | LineageOS (via `remote="lineage"`) | `LineageOS/android_frameworks_av` | `b6b36c1fdb3c6ffced822a054fbf035b544f0de2` | `b6b36c1fdb3c6ffced822a054fbf035b544f0de2` |
| `packages/modules/adb` | LineageOS (via `remote="lineage"`) | `LineageOS/android_packages_modules_adb` | `e7ed41a85f5a0a8c9db0ed7ba21c6ebd277b5db6` | `e7ed41a85f5a0a8c9db0ed7ba21c6ebd277b5db6` |
| `vendor/lineage` | LineageOS (via `remote="lineage"`) | `LineageOS/android_vendor_lineage` | `ca37c450e98fefb0cd53b864c469c1a7d024c53f` | `ca37c450e98fefb0cd53b864c469c1a7d024c53f` |

The `fiftydinar`-hosted projects are forks, except for the two OpenEUICC
repositories, which are full GitHub mirrors of their original Gitea
repositories. Official LineageOS projects that only need patches are pinned
through the `lineage` remote. The framework compatibility changes are pinned to
exact source commits in `mumba.xml`.

## Java boot-property compatibility behavior

The framework's Java `SystemProperties.get()` returns
`ro.boot.flash.locked=1` and `ro.boot.verifiedbootstate=green`. This does not
change the underlying boot properties, the actual unlocked bootloader state,
native property reads, or Keystore attestation; it is not a general root-hiding
patch.

## GApps

FakeStore is not bundled. `device-mumba.patch` removes the
`PRODUCT_PACKAGES += FakeStore` block from `device.mk` (the
`com.android.vending` stub conflicted with installing GApps), and
`device-mumba-gapps.patch` removes the now-unused `fakestore/` directory from
the device tree.

There are two ways to get Google apps:
- **Sideload afterwards** — for LineageOS 23 / Android 16, LineageOS recommends
  [MindTheGapps ARM64](https://github.com/MindTheGapps/16.0.0-arm64/releases),
  installed after the ROM and before the first system boot.
- **Integrated GApps build** — the separate `lineage_mumba_gapps` product
  (`TARGET=lineage_mumba_gapps-bp4a-user`) stages MindTheGapps into
  `vendor/partner_gms` via `tools/fetch_mindthegapps.py` and is pinned by
  `MINDTHEGAPPS_TAG`. Google APKs keep their original Google signatures
  (`presigned`), and AVB stays enabled because the GApps content is part of the
  signed `product`/`system_ext` hashtree. Updates arrive through the separate
  `ota/updates-gapps.json` feed. For a debug GApps build use
  `TARGET=lineage_mumba_gapps-bp4a-userdebug`; its output tree is `out-gapps`.
  The GApps product uses the vendor Google Euicc (`com.google.android.euicc`);
  OpenEUICC is not installed in this variant.

Sideloading MindTheGapps onto the vanilla product is different: OpenEUICC stays
installed, and GMS makes `EuiccPolicy` enable EuiccGoogle, so both LPAs can be
present. Use the integrated GApps product for a clean Google-eUICC setup, or
disable one of the two LPAs.

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
The action labels and clipboard feedback are also translated in all 77
language/region resource sets bundled with Messaging. Since upstream has Serbian
Cyrillic resources but no `sr-Latn` set, `apply_port.sh` generates the Latin
variant from those strings for devices set to `sr-Latn-RS`.

From the initialized build tree, run the detector/dispatch host tests and device
intent/clipboard-payload tests with:

```bash
m MessagingNotificationLogicTests MessagingNotificationActionTests messaging
atest --host MessagingNotificationLogicTests
atest MessagingNotificationActionTests
```

Do not fork `LineageOS/android` directly: its `fetch=".."` would break every remote in the manifest.

## Notes
- A clean flash is required when switching from a ROM signed with different keys
  (stock, official LineageOS, or another custom ROM). Later updates signed with
  the same release keys can be installed through the Updater without wiping.
- The userdebug build is SELinux permissive; the separate `user` release omits
  that boot argument, uses enforcing mode, and leaves AVB verification enabled.
- `flash_all.sh` runs `fastboot -w` and erases userdata. Set `IMG_DIR` to the
  build output directory, e.g. `IMG_DIR="/path/to/lineage-mumba/out-vanilla/target/product/mumba" bash flash_all.sh`.
- ccache speeds up rebuilds.
- The first build takes hours (kernel + ~170k targets).
- **eSIM** works on vanilla via **OpenEUICC** (privileged LPA, no Google).
  GApps uses the vendor Google Euicc (`com.google.android.euicc`) instead;
  OpenEUICC is not installed in the GApps variant. `EuiccPolicy` disables
  Google Euicc when GMS is absent, so each variant has exactly one LPA.
  The mirrored source is based on the last pre-SDK37 commit; the three
  `openeuicc-*` patches adapt it to the A16 tree and hide its standalone launcher.
  Vanilla initial setup uses LineageOS SetupWizard, which has no eSIM download
  flow; add the profile afterwards through Settings. In GApps, Google
  SetupWizard is active and can offer its eSIM setup flow through EuiccGoogle.
- Tested on the eSIM variant XT2537-5. Settings and telephony include runtime
  handling for physical-SIM-only variants, but a physical-only unit has not
  been tested.
- **Automatic call recording** (record all incoming/outgoing calls) is added to
  Dialer via `dialer-autorecord.patch` (Gerrit change 251235, never merged upstream).
- Audio compatibility patches enable the Mumba FS1815 modules, restore the vendor
  audio policy volumes file, add missing QTI perf symbols, and match the stock
  two-DTB/two-DTBO layout. The built-in speaker receives a speaker-only,
  cut-only Pink Noise correction derived from Notebookcheck measurements.

## License

The manifest, scripts, and documentation are licensed under Apache-2.0 (see
`LICENSE`). Patches that modify GPL-2.0 kernel sources remain under the kernel's
GPL-2.0 license.
