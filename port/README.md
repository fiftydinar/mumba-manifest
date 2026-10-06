# Ported changes: A17 (moto-elysia) -> A16 (ZaraKinYu device tree)

`port/` contains twenty-two patches:
- `device-mumba.patch` -> `device/motorola/mumba` (device tree changes)
- `mumba-refresh-defaults.patch` -> `device/motorola/mumba` (clean-install refresh settings overlay)
- `speaker-eq-device.patch` -> `device/motorola/mumba` (build and install the speaker-only EQ effect)
- `display-srgb-device.patch` -> `device/motorola/mumba` (default to sRGB color management and initialize fresh installs in sRGB mode)
- `settings-provider-refresh-defaults.patch` -> `frameworks/base` (seed optional refresh settings on initial settings database creation)
- `vendor-mumba.patch` -> `vendor/motorola/mumba` (build fixes in generated vendor files)
- `speaker-eq-vendor.patch` -> `vendor/motorola/mumba` (attach the speaker EQ, remove stale Dolby effects, and select the source QTI effect factory)
- `openeuicc-deps.patch` -> `prebuilts/openeuicc-deps` (SDK 37 -> 36 for the A16 tree)
- `openeuicc-app.patch` -> `packages/apps/OpenEUICC` (use AOSP datastore module)
- `openeuicc-hide-launcher.patch` -> `packages/apps/OpenEUICC` (hide standalone launcher entry; keep the system LPA/LUI service)
- `settings-euicc-hardware-detection.patch` -> `packages/apps/Settings` (only show Settings' Add SIM entry when Telephony detects an eUICC card)
- `display-srgb-settings.patch` -> `packages/apps/Settings` (show a Native/sRGB color-mode selector in Display settings)
- `uiccslot-physical-removable.patch` -> `frameworks/opt/telephony` (don't mark a physical SIM non-removable just because its slot is listed as an eUICC)
- `dialer-autorecord.patch` -> `packages/apps/Dialer` (automatic call recording)
- `perfd-client.patch` -> `hardware/qcom-caf/common/libqti-perfd-client` (missing QTI perf API stubs)
- `audio-kernel.patch` -> `kernel/motorola/sm6435-modules` (enable the mumba FS1815 amplifier modules)
- `audiomanifest.patch` -> `hardware/qcom-caf/sm8450-6.6/audio/primary-hal` (drop unregistered `IModule/usb`/`r_submix` from the audio VINTF manifest)
- `speaker-eq-audio.patch` -> `hardware/qcom-caf/sm8450-6.6/audio/primary-hal` (parse and route speaker device effects in the QTI AIDL effect factory)
- `speaker-eq-audioflinger.patch` -> `frameworks/av` (allow this cut-only speaker device effect on the fast mixer output thread)
- `adb-root-debug.patch` -> `packages/modules/adb` (default Rooted debugging on for debuggable builds unless a saved preference overrides it)
- `touch-kbuild.patch` -> `kernel/motorola/sm6435-modules` (panel firmware selection, Chipone/Ilitek gesture flags, and DT2W input/wakeup fixes)
- `display-refresh.patch` -> `kernel/motorola/sm6435-devicetrees` (24/25/30/40/48/50/60/80/90/96/100/120 Hz DFPS rates for all three mumba panels)

Apply all with `../apply_port.sh`.

## Patch base revisions

These are the exact source commits the patch files were made against. The
device, vendor, and kernel revisions are pinned in `mumba.xml`; the OpenEUICC
patches are based on upstream commit `2a85b8dad6000eea9dd622a468b7558e79933b2a`.
Its manifest pin is a mirror-only child commit that rewrites the two submodule
URLs to the corresponding `fiftydinar` forks. The LineageOS project revisions
are from the resolved `lineage-23.2` manifest.

| Patch target | GitHub copy | Commit |
|---|---|---|
| `device/motorola/mumba` | [`android_device_motorola_mumba`](https://github.com/fiftydinar/android_device_motorola_mumba) | `c87184155fc8482f4dd469aa67b0ab98049cb735` |
| `vendor/motorola/mumba` | [`vendor_motorola_mumba_latest`](https://github.com/fiftydinar/vendor_motorola_mumba_latest) | `8bcc9d41ca36b5e2ae93d592226eac163225ade9` |
| `kernel/motorola/sm6435-modules` | [`android_kernel_motorola_sm6435-modules`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-modules) | `0659ac7d22557e405529e00e2b5fdace57964636` |
| `kernel/motorola/sm6435-devicetrees` | [`android_kernel_motorola_sm6435-devicetrees`](https://github.com/fiftydinar/android_kernel_motorola_sm6435-devicetrees) | `2c0587b0d4d90e0b3b00f87c9430360ea15ebdb6` |
| `prebuilts/openeuicc-deps` | [`android_prebuilts_openeuicc-deps`](https://github.com/fiftydinar/android_prebuilts_openeuicc-deps) | `540216793010cabc49782bd01844cd8dd28a4c7c` |
| `packages/apps/OpenEUICC` | [`OpenEUICC`](https://github.com/fiftydinar/OpenEUICC) | `2a85b8dad6000eea9dd622a468b7558e79933b2a` |
| `frameworks/base` | [`android_frameworks_base`](https://github.com/fiftydinar/android_frameworks_base) | `1c45e31a86be95f51a94ffd1a5014c3fb2019112` |
| `frameworks/opt/telephony` | [`android_frameworks_opt_telephony`](https://github.com/fiftydinar/android_frameworks_opt_telephony) | `566e62daf4e93be6f934001bc76d60aba087b4d6` |
| `packages/apps/Settings` | [`android_packages_apps_Settings`](https://github.com/fiftydinar/android_packages_apps_Settings) | `8d8f6486b274bcf0aa6e5d0cbba52c0b05ae5c65` |
| `packages/apps/Dialer` | [`android_packages_apps_Dialer`](https://github.com/fiftydinar/android_packages_apps_Dialer) | `6da8042323a97d5b3cba1fd975709cc42f29916f` |
| `hardware/qcom-caf/common` | [`android_hardware_qcom-caf_common`](https://github.com/fiftydinar/android_hardware_qcom-caf_common) | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| `hardware/qcom-caf/sm8450-6.6/audio/primary-hal` | [`android_hardware_qcom_audio-ar`](https://github.com/fiftydinar/android_hardware_qcom_audio-ar) | `6a42341357a56903eea27a74fdb161a26402dcc3` |

The device/vendor changes backport important fixes from the A17 device tree to
the A16 (LineageOS 23.2) tree. Dolby and Viper are intentionally NOT ported.

## What is ported

| File | Purpose |
|---|---|
| `camera/Android.bp`, `camera/CameraProviderExtension.cpp` | Camera service extension (`libcameraservice_extension.mumba`), wired via `soong_config_set(libcameraservice, ext_lib, ...)` in `device.mk` |
| `idc/double-tap.idc`, `keylayout/double-tap.kl` | Input mappings for the auxiliary `double-tap` device and the Chipone touchscreen wake key |
| `overlay/DeviceAsWebcamMumba/` | Device-as-webcam support (phone as USB webcam) |
| `overlay/EuiccOverlayMumba/` | eUICC slot/UI overlay |
| `overlay/FrameworksResMumba/res/xml/haptic_feedback_customization.xml` | Haptic feedback customization |
| `power_ext/` | Device-specific power HAL mode extension |

## Double tap to wake (done properly)

The A17 tree "fixed" DT2W with a hardcoded init write:
```
write /sys/class/touchscreen/primary/gesture 49
```
That forces DT2W on at every boot, so the Settings toggle has no effect.

Instead, this port wires the toggle to the node through the framework:
`Settings > Display > Tap to wake` (`Settings.Secure.DOUBLE_TAP_TO_WAKE`)
-> `PowerManagerService` -> power HAL `setMode(DOUBLE_TAP_TO_WAKE, enabled)`
-> `power_ext/PowerModeExtension.cpp` writes `/sys/class/touchscreen/primary/gesture`
(`49` when enabled, `48` when disabled; the driver ignores `0`).

`device.mk` selects the extension:
```make
$(call soong_config_set,power_libperfmgr,mode_extension_lib,//$(LOCAL_PATH)/power_ext:libpower_ext_mumba)
```

The driver parses decimal input and maps `49` (`0x31`) to DT2W enabled and
`48` (`0x30`) to DT2W disabled. Other values, including `0`, leave its internal
double-tap flag unchanged.

The Chipone driver additionally needs the gesture **wakeup** state enabled
(`gesture_en` Y, otherwise it suspends into `sleep`), so `PowerModeExtension`
writes that node too. Its sysfs `gesture` handler recognizes decimal `49` to
enable and `48` to disable the DT2W flag; `0` is ignored and leaves the previous
flag set. The power extension uses both values, which keeps the Settings toggle
effective across screen suspend/resume.

### chipone (BOE / CSOT panels)

Required kernel flags (added via `touch-kbuild.patch`, because the `Android.mk`
`KERNEL_CFLAGS`/`KBUILD_OPTIONS` path does not reach `EXTRA_CFLAGS`):
- `-DCTS_TP_MODULE_EN` -> per-panel firmware (`boe_/csot_chipone_firmware.bin`)
- `-DCONFIG_BOARD_USES_DOUBLE_TAP_CTRL` -> creates the `gesture` sysfs node
- `-DCHIPONE_SENSOR_EN` + `-DTOUCHSCREEN_PM_BRL_SPI` -> gesture IRQ report path

The kernel reports `BTN_TRIGGER_HAPPY6` on the auxiliary `double-tap` sensor
input and the primary `chipone-tddi` touchscreen input. The primary event is
the confirmed framework wake path; both matching keylayouts are installed.
The gesture callback also uses the wakeup source registered by the driver
rather than an uninitialized static pointer.

### ilitek (TXD panel)

Same mechanism; the gesture (`BTN_TRIGGER_HAPPY6`) is reported on the
`double-tap` input device:
- Kbuild: `-DILI_DOUBLE_TAP_CTRL` + `-DILI_PRIMARY_NODE`
- keylayout: `vendor/usr/keylayout/double-tap.kl`

## Init / node permissions

- `init/init.qcom.rc`: added the `# Powerhal` block — `chown`/`chmod` for the WALT
  rate-limit nodes (`policy0`/`policy4` `walt/up_rate_limit_us`, `down_rate_limit_us`)
  and `bus_dcvs/L3/boost_freq`.
  These are REQUIRED so the power HAL can write the rate-limit nodes already
  referenced by `configs/power/powerhint.json`. Also sets
  `vendor.powerhal.init=1` at `post-fs-data`; previously the property was nested
  under `vendor.radio.atfwd.start=false`, which never fired on this device. The
  AIDL power HAL was left waiting and its `NodeLooperThread` never applied
  `INTERACTION` boosts.
- `init/ueventd.qcom.rc`: added the `# Torch control` block (LED `torch_0`/`torch_1`/
  `switch_2` brightness -> owner `cameraserver`, group `camera`) to enable torch
  brightness/strength control.

Not ported (deliberately): the SurfaceFlinger big-cluster cpuset (battery trade-off);
`setprop vendor.powerhal.init 1` (already present in the A16 tree).

## Touchscreen (chipone firmware)

- `kernel/motorola/sm6435-modules`: the chipone touch driver only selected the
  panel-specific firmware when `CTS_TP_MODULE_EN` was defined; this was gated
  behind `CTS_MULTI_TP_MODULE_EN`, which is never set, so the driver always fell
  back to the (missing) generic `chipone_firmware.bin`. `touch-kbuild.patch`
  forces `-DCTS_TP_MODULE_EN`, letting `cts_parse_tp_module()` match the active
  DRM panel name (`boe_..._mumbai`) and load `boe_chipone_firmware.bin`.
- `vendor/motorola/mumba`: the BOE/CSOT firmware blobs are present in the pinned
  vendor source under `proprietary/vendor/firmware/`. `vendor-mumba.patch` adds
  the `PRODUCT_COPY_FILES` mappings that install them in `/vendor/firmware`.

## Adaptive refresh rate

All three mumba panel variants (BOE and CSOT ICNL9922C, plus TXD ILI7807S)
advertise 1080x2400 dynamic-porch refresh rates at **24/25/30/40/48/50/60/80/90/96/100/120 Hz**.
The common SDE display overlay sets `config_defaultRefreshRate` and
`config_defaultPeakRefreshRate` to 120 so the primary render-rate range can use
the panel's full range; the QTI display stack's content detection remains
enabled. The new rates use the existing `dfps_immediate_porch_mode_vfp` path,
which adjusts VFP while keeping the panel pixel clock fixed. On a clean install,
`min_refresh_rate` defaults to 24 Hz and `peak_refresh_rate` to 120 Hz. These are
seeded only when SettingsProvider first creates its settings database, so later
user choices are preserved. The test device had a 30 Hz floor; I changed it to
24 Hz for panel validation. After rebuilding and flashing the final
`dtbo_a`, `cmd display get-supported-modes 0` lists all twelve modes, with 10 Hz
absent. The active panel successfully switched to 25, 40, 48, 50, 80, 96, and
100 Hz when temporarily capped to each rate. The new modes reported active mode
IDs 5, 3, and 2 respectively. 24 Hz switched with a 24.5 Hz cap because the
reported mode is 24.000002 Hz. The cap was removed afterward; the settings were
restored to a 24 Hz floor and 120 Hz peak, and the display returned to 120 Hz.

- Generated 30-second 720x1600 H.264 clips at 24/25/48/50 fps and played them
  with Next Player (Media3). The controls overlay holds the display at 120 Hz;
  sampling after 8 seconds (the overlay hides at about 6 seconds) showed the
  screen matching each clip at 24/25/48/50 Hz.
- MediaCodec telemetry recorded the expected source-frame input totals for full
  30-second runs: 720, 750, 1440 and 1500 respectively. It does not expose a
  rendered-frame drop counter for this SurfaceView playback path; the user reports
  no visible stutter in Next Player at either 24 or 120 Hz.
- Installed F-Droid's Frogue game and configured Game Mode custom FPS to 40 for
  the user's manual test (`cmd game list-configs io.github.necrashter.natural_revenge`);
  the user confirmed the game works at 40 Hz.

An experimental 10 Hz mode was selectable with the floor/peak set to 10, but the
user found touch response poor and the transition back to 120 Hz visibly
juddery. It was removed from the panel lists. The test device is restored to
`min_refresh_rate=24` and `peak_refresh_rate=120`. Added 80 Hz as an exact
2x mode for 40 fps games, and 96/100 Hz as 2x modes for 48/50 fps interpolated
video.

The original 30/60/90/120 Hz tests selected 30 Hz for a 30 fps clip and 120 Hz during
interaction, returning to 30 Hz when input stopped. UiBench's one-iteration
trivial animation reported 3,009 frames, 0 jank and 0 missed vsyncs at 120 Hz.

BaikalOS Surya sources were checked directly (`BaikalOS-Devices/android_device_xiaomi_surya`,
branch `r11.1`). The compatible pieces here are the 120 Hz framework defaults
and Android's content-based rate selection. Its `vendor.display.idle_time=200`
setting was tested separately on mumba and caused SDM DRM atomic `EINVAL` spam
and visible flicker; mumba's stable value is `vendor.display.idle_time=0`.
This is a kernel/HWC difference: the Baikal Surya kernel registers and handles
the CRTC `idle_time` property (`drivers/gpu/drm/msm/sde/sde_crtc.c`,
`CRTC_PROP_IDLE_TIMEOUT`), while mumba's Linux 6.6 DPU CRTC does not expose that
property. The QTI HAL can therefore submit an invalid atomic-property request
when the non-zero vendor timeout is enabled. Keep it at `0`; do not copy the
Baikal video/HDR idle overrides without a separate test. Baikal's
`debug.sf.use_content_detection_v2` is not present in this Android 16
SurfaceFlinger tree; the supported
`ro.surface_flinger.use_content_detection_for_refresh_rate=true` is already
enabled. Xiaomi-specific `ro.vendor.smart_dfps.enable` and
`persist.vendor.power.dfps.level` are not part of Motorola's display stack.

The Baikal `set_display_power_timer_ms=2000` and shorter 200/500 ms idle/touch
timers are not applied yet; mumba retains its stable 500/1000 ms SF timers.
On this Android 16 tree the SF `idleTimer` is still empty in the runtime dump:
its setup is gated by `follower_arbitrary_refresh_rate_selection`, an Aconfig
flag documented for follower/multi-display scheduling. That flag is not enabled
for this single-panel device. Content detection and the touch timer do select
the tested 30/120 Hz modes without it.
No CPU/GPU kernel tuning has been applied yet; the measured animation test did
not show a frame-drop bottleneck, and battery draw still needs a controlled
comparison before changing governor or frequency policy.

For short repeatable UiBench runs, pass `-e iterations 1` to
`AndroidJUnitRunner`. The stock UiBench JankTest default is 20 iterations; its
navigation-drawer test performs four horizontal swipes per iteration. The
standalone JankBench app cannot inject input events outside instrumentation on
this Android build, so it is not used for automated results.

## Display color mode

The built-in display HAL reports `NATIVE` (0) and `SRGB` (7). `display-srgb-settings.patch`
adds a **Display → Color mode** list with those two choices; Android's display manager
persists the selected HWC mode. The list is shown only when the display reports both
modes. `display-srgb-device.patch` changes SurfaceFlinger from unmanaged/native output
to managed color output, removes the hard-forced color-mode property, and sets
`config_defaultDisplayDefaultColorMode=7` so a fresh data partition starts in sRGB.
Its post-fs-data action neutralizes stale persisted SurfaceFlinger mode properties
before SurfaceFlinger starts, while DisplayManager's own saved HWC mode remains the
user preference. This keeps Native selectable and preserves the selection over reboot.

The device reports no wide-color display and no HDR output types; neither sRGB mode
nor this UI adds P3 or HDR capability. The mode selector only chooses between the
panel's native output and its hardware-composer sRGB mode.

## Touch latency

The active BOE/Chipone input (`chipone-tddi`, event8) reports touch coordinates
at roughly 8 ms intervals while swiping (about 120 Hz); its firmware `game_mode`
is already enabled and the device tree/driver exposes no scan-rate knob. The
large latency came from the missing PowerHAL initialization trigger above, not
from a low controller sample rate. In one matching UiBench list-fling iteration,
the measured high input latency changed from about 101 ms to 3.9 ms after the
INTERACTION node looper started; jank went from 0.69% (4 missed deadlines) to
0.19% (1 missed deadline). Repeat runs are needed for a stable aggregate.

## Volume (audio policy)

- `vendor/motorola/mumba`: added `vendor/etc/default_volume_tables.xml` and
  `vendor/etc/r_submix_audio_policy_configuration.xml`. Both are referenced by
  `audio_policy_configuration.xml` but were missing from the vendor blob tree,
  which left the volume stuck (the APM could not build the volume tables).

## Audio compatibility fixes

- `vendor/motorola/mumba`: restored `vendor/etc/audio_policy_volumes.xml`, which is
  included by the vendor audio policy configuration.
- `hardware/qcom-caf/common/libqti-perfd-client`: added the missing
  `perf_get_prop_extn` and `perf_lock_rel_flush` compatibility symbols required by
  the proprietary QTI performance services.
- `device/motorola/mumba/configs/power/powerhint.json`: removed KGSL force-rail/clock
  hints because the kernel rejects them with `-EOPNOTSUPP` when the Adreno GMU is
  active; corrected the L3 boost request to its maximum advertised OPP (1420800 kHz).
- `kernel/motorola/sm6435-modules`: enabled `CONFIG_SND_SOC_FS181X` in both the
  audio Kbuild config and generated C config header. Mumba's audio DTS uses the
  FS1815 amplifier; the modules are therefore built and added to
  `modules.load.vendor_dlkm`.
- `hardware/qcom-caf/sm8450-6.6/audio/primary-hal`: removed `IModule/usb` and
  `IModule/r_submix` from `hal/default/manifest_audiocorehal_default.xml`. They
  were advertised in the VINTF manifest but never registered by any HAL (the QTI
  config only provides `default`), which made `audioserver` block on
  `IModule/usb` before registering `IAudioFlingerService`/`IAudioPolicyService`
  and triggered a Watchdog reboot on the boot animation. This was the final
  audio boot-loop fix.
- `BoardConfig.mk`: limits DTB/DTBO output to the two generic Parrot bases and two
  Mumba overlays, matching the stock layout.

## Built-in speaker correction

The [Notebookcheck Moto G57 Power review](https://www.notebookcheck.net/Huge-battery-and-sleek-design-Is-that-still-enough-against-Xiaomi-and-rivals-Motorola-Moto-G57-Power-review.1221966.0.html)
embeds a Pink Noise SVG. Notebookcheck says it measures with a calibrated
Earthworks M23R microphone at 15 cm and judges whether the audible bands are
roughly equally loud. In the inline SVG, series 0 reports SPL 25.5, N 0.7,
median 12, delta 6.5; series 1 is the loud curve (SPL 83.7 dB(A), N 56.8,
median 66.3 dB(A), delta 9). The complete SVG readings are transcribed below.
The x-axis values 31 and 63 are the graph's rounded labels for nominal 31.5 and
63 Hz.

| Hz | Series 0 dB(A) | Series 1 dB(A) |
|---:|---:|---:|
| 20 | 6.9 | 13.0 |
| 25 | 11.7 | 17.8 |
| 31.5 | 16.5 | 16.1 |
| 40 | 21.7 | 21.6 |
| 50 | 25.6 | 26.5 |
| 63 | 24.1 | 25.2 |
| 80 | 23.0 | 25.8 |
| 100 | 23.1 | 24.7 |
| 125 | 24.8 | 25.4 |
| 160 | 25.3 | 34.7 |
| 200 | 25.3 | 43.0 |
| 250 | 23.3 | 51.2 |
| 315 | 24.8 | 57.9 |
| 400 | 19.2 | 60.6 |
| 500 | 14.7 | 66.3 |
| 630 | 14.8 | 68.8 |
| 800 | 9.2 | 68.3 |
| 1,000 | 7.3 | 76.9 |
| 1,250 | 7.5 | 75.4 |
| 1,600 | 8.7 | 74.4 |
| 2,000 | 5.7 | 72.2 |
| 2,500 | 12.0 | 68.9 |
| 3,150 | 13.4 | 65.9 |
| 4,000 | 9.9 | 65.8 |
| 5,000 | 13.1 | 69.7 |
| 6,300 | 9.2 | 73.4 |
| 8,000 | 8.6 | 72.0 |
| 10,000 | 10.0 | 63.9 |
| 12,500 | 5.9 | 66.5 |
| 16,000 | 5.6 | 53.1 |

Notebookcheck's summary for this unit reports bass (100–315 Hz) 26.9% below its
median, mids (400–2,000 Hz) 5.4% above, highs (2–16 kHz) 3.1% from median, and
overall deviation 19.7%. Because the bass bins show the speaker's physical
roll-off, the EQ applies **no positive gain** and does not try to force the
entire spectrum down to the 100-Hz floor. Instead, a fixed cut-only parametric
profile brings the 500-Hz–8-kHz area to about 65 dB(A), close to the chart's
66.3-dB(A) median, with the 10-kHz and 16-kHz natural roll-offs retained.
It is installed as an AIDL `deviceEffects` effect for `AUDIO_DEVICE_OUT_SPEAKER`,
so wired and Bluetooth outputs are not processed. The profile is in
`port/speaker-eq/MumbaSpeakerEqualizer.cpp`; its 1/3-octave correction centers
are 630, 1,000, 1,250, 1,600, 2,000, 2,500, 5,000, 6,300, 8,000 and 12,500 Hz,
with respective cuts of 2.9, 9.7, 6.6, 6.4, 4.6, 1.9, 2.9, 6.9, 5.5 and 1.0 dB.
No boost is applied at any frequency.

The built-in speaker route no longer advertises direct PCM or compressed-offload
mix ports. Those paths can bypass software effects; speaker playback therefore
falls back to AudioFlinger's mixer before reaching the speaker EQ. Other output
devices retain their direct/offload routes. The trade-off is that high-resolution
or compressed playback through the phone speaker may use more CPU/battery and
will be mixed/resampled instead of bit-perfect.

The QTI factory's original parser did not handle AIDL `deviceEffects`; the
`speaker-eq-audio.patch` adds that support for the built-in speaker device.
`speaker-eq-vendor.patch` selects the matching source QTI effect factory rather
than the older vendor prebuilt and removes Dolby entries whose libraries are not
present in this Dolby-free build. Without those parser/config fixes, audio
policy cannot instantiate the speaker effect.
AudioFlinger's fast output thread normally rejects software device effects, so
`speaker-eq-audioflinger.patch` permits only this exact speaker EQ UUID on the
speaker device session; other effects retain the normal fast-thread restriction.

## Rooted debugging on debug builds

`adb-root-debug.patch` initializes ADBRootService's default to
`ANDROID_DEBUGGABLE`. A fresh `userdebug` or `eng` data partition therefore
starts with Rooted debugging enabled, while a `user` release build remains
unsupported for `adb root`. A saved value in `/data/adbroot/enabled` takes
precedence, so a developer can still switch Rooted debugging off and keep that
choice across reboot; formatting data restores the build-variant default. This
does not turn on USB debugging itself.

## SELinux audit and current boot findings

The `eng` and `userdebug` variants remain **Permissive**
(`androidboot.selinux=permissive`) for debugging. The `user` release variant
omits that argument and boots with SELinux enforcing by default; enforcing-mode
boot and hardware validation have not yet been completed. Debug variants also
set AVB flags `3` (disable verification/hashtree); the `user` variant omits
those debug flags so AVB verification stays enabled and can be re-signed with
the owner's AVB keys.
An earlier boot lost over 1,500 audit records because logd applied a 5/sec rate
limit and the kernel audit backlog was 64.

- Added a service-context alias for Motorola's camera post-process AIDL service,
  using the existing `vendor_hal_postproc_service` type.
- Added the missing `hal_audio` client relationship for `hal_vibrator_default`.
- Labelled the fingerprint HAL's `IMotoCaptiveSensorTest/default` with the existing
  `hal_fingerprint_service` type.
- Added narrowly scoped QTI location binder/QRTR/network rules and the GNSS
  framework sensor-service lookup, matching the neighboring Qualcomm policy.
  A proposed `vendor_location` lookup permission for CACert was rejected by an
  explicit upstream `neverallow` and was not included.
- Set `persist.logd.audit.rate=0` on the debug device (`adb shell setprop
  persist.logd.audit.rate 0`) and raised the kernel
  `audit_backlog_limit` to 4096 in the vendor-boot command line. Both the boot
  argument and persistent rate setting were verified after reboot; the latest
  full kernel/logcat audit scan showed no `audit_lost` records or AVC denials.

## Fingerprint and kernel comparison

- Lunaris and this build use matching hashes for the fingerprint selector, both
  HAL services, and the Jiiov/FPC vendor libraries. Lunaris's `init.mmi.rc` starts
  only `vendor.hal-fps-sh`; it has no `vendor.ident-fps-sh` or
  `/vendor/bin/init.oem.fingerprint.sh`. Removed that dangling call/service.
- Both DTBOs route Jiiov reset/IRQ to GPIOs 101/111 and supply L28B at 3.0 V / 5 mA.
  Ueventd and init grant the same access to `/dev/jiiov_fp`.
- The 6.6.139 FPC module lacked the class device required for the selector's
  `/sys/class/fingerprint/fpc1020/irq` readiness check. The external-module build
  path bypassed the old `BOARD_HAS_MULTI_FPS` option in `Android.mk`; `Kbuild` now
  explicitly defines `CONFIG_INPUT_MISC_FPC1020_SAVE_TO_CLASS_DEVICE`.
- Rebuilt and flashed the complete **current 6.6.139** kernel/module stack plus
  vendor image. FPC now creates the readiness node and reports HAL status `ok`;
  `dumpsys fingerprint` sees sensor ID 1 with no HAL deaths. The Lunaris kernel was
  useful for comparison but is not required for the fix.
- A Jiiov-first diagnostic boot still failed Jiiov, then FPC succeeded. The
  selector is restored to FPC-first. `last_vendor_id` is logged but does not
  control fallback order when current `vendor_id=none`.
- The rebuilt vendor image includes Lunaris's matching `snapdragon_services`
  binary and init rc; both are now stored in the pinned public vendor fork.
  After flashing slot A, init reports the service running;
  `ISnapdragonServices/default` and the QTI perf AIDL service are both registered.
  The installed blob hashes match the extracted source files. Fingerprint remains
  healthy after this boot: sensor ID 1, two enrolled prints, zero HAL deaths.
- The driver's `use pmic to contrl power failed, ret_val: 1` message is misleading:
  `vreg_setup()` keeps the positive `regulator_is_enabled()` result after calling
  `regulator_disable()`. The same message exists in Lunaris's Jiiov module.

Remaining items:
- Jiiov still fails in the earlier Jiiov-first diagnostic; the FPC sensor remains
  the working selection (two enrolled prints, zero HAL deaths).
- `smmu_proxy_dlkm` is loaded, but `/dev/qti-smmu-proxy` is absent and the Parrot
  device tree has no `smmu-proxy-sender` node. SnapAlloc still warns about the
  missing proxy and falls back to graphics-library alignment calculations. Do not
  add a dummy node without evidence that Parrot supports the sender protocol.

## Automatic call recording (Dialer)

LineageOS ships call recording in AOSP Dialer, but only **manual** (in-call
button). The auto-record change was proposed on Gerrit
([LineageOS change 251235](https://review.lineageos.org/c/251235), "Dialer: Add
autorecord feature") but never merged. `dialer-autorecord.patch` forwards that
change to our tree (originally on `CallButtonPresenter`/`sound_settings`).

What it adds:
- `cm_strings.xml`: `auto_call_recording_title` ("Record all calls") +
  `auto_call_recording_key` ("auto_call_recording").
- `sound_settings.xml`: a switch inside the existing `call_recording_category`
  (so it is hidden together with the category when recording is disabled for the
  current MCC).
- `CallButtonPresenter.java`:
  - reads the `auto_call_recording` preference on each `onStateChange`;
  - on `InCallState.INCALL`, after a 500 ms delay, triggers
    `callRecordClicked(true)` (auto-start);
  - when the call ends (`else` branch), calls `recorder.finishRecording()`;
  - guards against double-start (`isRecording` field + `isRecording()` checks);
  - restores the recording button state on UI ready.

Deviation from the original change: uses `SwitchPreferenceCompat` (consistent
with the rest of `sound_settings.xml`) instead of the deprecated
`SwitchPreference`.

Implementation detail: `CallRecorderService.isEnabled()` (the
`call_recording_enabled` bool) still gates the whole `call_recording_category`,
so auto-record only appears where LineageOS already allows recording for the
carrier MCC.

## eSIM: OpenEUICC integration

Vanilla LineageOS ships no LPA, so eSIM cannot be provisioned. OpenEUICC is
added as a privileged `system_ext` app that serves as the system
`EuiccService` (LPA), with no Google dependency.

- Sources (in the local manifest `mumba.xml`):
  - `fiftydinar/OpenEUICC` -> `packages/apps/OpenEUICC`, pinned to mirror commit
    `4130828243a2fb07aa1c07fc5813aa218ea912bf`, based on upstream
    `2a85b8dad6000eea9dd622a468b7558e79933b2a` (the last pre-SDK37 source commit;
    builds against API 36). Its two submodules point to `fiftydinar/lpac` and
    `fiftydinar/cJSON` and are fetched via `sync-s`.
  - `fiftydinar/android_prebuilts_openeuicc-deps` -> `prebuilts/openeuicc-deps`,
    pinned to `540216793010cabc49782bd01844cd8dd28a4c7c`.
- `device.mk`: `PRODUCT_PACKAGES += OpenEUICC`.
- Installs to `system_ext/priv-app/OpenEUICC/` with
  `system_ext/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml`.
- The standalone `MAIN`/`LAUNCHER` entry is hidden; Settings is the user entry
  point. Verified on-device via `Settings > Network & Internet > SIM cards >
  Add SIM`: this launches OpenEUICC's LUI, and `Download eSIM` reaches the
  eUICC/slot selection screen.

Two compatibility fixes are required for the A16 tree (applied by
`openeuicc-deps.patch` and `openeuicc-app.patch`):
1. deps `Android.bp`: `sdk_version: "37"` -> `"36"` (`prebuilts/sdk/37` has no
   `public/android.jar` in this tree).
2. app `app-deps/Android.bp`: use the AOSP module
    `androidx.datastore_datastore-preferences` (the deps no longer bundle it).

`openeuicc-hide-launcher.patch` is the third OpenEUICC patch; it hides the
standalone launcher while retaining the privileged LPA service and Settings
launch flow.

Verified: `m OpenEUICC` -> build completed successfully, APK + preopt produced.
On-device checks also confirmed that Telephony selected
`im.angry.openeuicc.service.OpenEuiccService`, reached `AvailableState`, and
returned `GetEuiccProfileInfoListResult: result=OK` for the non-removable eUICC
in slot 1. OpenEUICC's UI detected the slot and eID, displayed the empty profile
list, and opened the new-profile wizard through the pre-download confirmation
screen. A public Speedtest/Truphone profile was then tried with the user's
approval. With the slot's automatically supplied optional IMEI, RSP initiation
returned HTTP 200/`Executed-Success`, but OpenEUICC reported
`ES10B_ERROR_REASON_UNDEFINED` at `es10b_authenticate_server`. A temporary LPAC
instrumentation localized the uncategorized error to the optional IMEI GSM-BCD
conversion path. Retrying with that optional field empty succeeded through
`es10b_authenticate_server`, `es10b_prepare_download`, and
`es10b_load_bound_profile_package`; the eUICC installed the profile and OpenEUICC
showed it as **Enabled**. Android now lists an embedded subscription on slot 1,
and its SIM state is `LOADED`.

The eSIM profile is enabled, but slot 1 remains out of network service in Serbia.
No data plan was purchased; the free profile download does not include a paid
plan. Verbose logging was disabled, and the original system OpenEUICC app was
restored after the diagnostic retry. A successful network-registration/data test
therefore remains outstanding.

After the test, the user requested deletion. I disabled and deleted the
Speedtest profile in OpenEUICC, confirmed its name, and chose the physical `mt:s`
SIM as the mobile-data SIM. `dumpsys isub` now reports no embedded profiles,
`defaultDataSubId=1`, and the physical SIM remains in service.

This `mumba` product configuration is eSIM-specific: it unconditionally ships
`android.hardware.telephony.euicc.xml`, sets `ro.telephony.esim_slot_id=1`, and
overlays slot 1 as a built-in eUICC. It was verified on the Czech XT2537-5 SKU,
whose vendor property reports eSIM hardware. A physical-SIM-only sibling has not
been tested on this hardware. Settings' Add SIM entry now also checks
`TelephonyManager.uiccCardsInfo` for an actual eUICC, so a phone that only reports
physical SIM cards will not be offered a dead provisioning flow. Telephony also
applies the non-removable-slot overlay only when the card ATR identifies an
eUICC, so a physical SIM in slot 1 remains removable. The build still advertises
the generic `FEATURE_TELEPHONY_EUICC`; a no-eSIM SKU should use a SKU-specific
product variant that omits the feature XML, eSIM slot property, and built-in-eUICC
overlay for accurate feature reporting.

## Dolby fully removed

Dolby is removed from the ROM entirely (not just "not ported"):

- The A16 tree had no Dolby blobs, but some residual references were removed:
  - `props/vendor.prop`: `persist.vendor.audio.effectimplenter=dolby`,
    `persist.vendor.audio.dolby.tws_tuning`, `persist.vendor.audio_fx.current=dolby`,
    `vendor.audio.dolby.ds2.*`, `ro.vendor.dolby.dax.version` (and the `# Media (Dolby)` comment).
  - `configs/vintf/compatibility_matrix.device.xml`: the `vendor.dolby.dms` HAL entry.
- `extract-files.py` still excludes `media_codecs_*dolby_audio*` (removal, kept intentionally).
- Dolby / Viper files present in the A17 tree (`DolbyFrameworksResMumba`, `init.dolby.rc`,
  `init.v4a.sh`, `init.viper.rc`) were NOT ported.

## Not ported (by design)
- Dolby / Viper audio effects (see above).

## Still to consider (later)
- Speaker EQ profile baked into the audio config/driver.
