#!/usr/bin/env bash
#
# flash_all.sh - flash LineageOS mumba via fastboot (userdebug/permissive build)
# Bypasses the OTA build-tag check that blocks `adb sideload`.
#
# Usage:
#   1. Phone -> bootloader:  adb reboot bootloader   (or Power+VolDown)
#   2. ./flash_all.sh
#
# WARNING: this wipes userdata (needed when switching from a differently-signed ROM).
#
set -e

# directory with the .img files (override with IMG_DIR=... )
IMG_DIR="${IMG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$IMG_DIR"

FB="fastboot"

need() { [ -f "$1" ] || { echo "missing: $1"; exit 1; }; }

echo "### verifying images in $IMG_DIR"
for f in boot init_boot vendor_boot dtbo pvmfw vbmeta vbmeta_system \
         system system_ext product vendor system_dlkm vendor_dlkm; do
  need "$f.img"
done

echo "### waiting for device in fastboot"
if ! $FB devices | grep -q .; then
  echo "No device in fastboot. Put the phone in bootloader mode, then re-run."
  exit 1
fi

echo "### boot-critical partitions"
$FB flash boot         boot.img
$FB flash init_boot    init_boot.img
$FB flash vendor_boot  vendor_boot.img
$FB flash dtbo         dtbo.img
$FB flash pvmfw        pvmfw.img

echo "### vbmeta (disable verity/verification)"
$FB --disable-verity --disable-verification flash vbmeta        vbmeta.img
$FB --disable-verity --disable-verification flash vbmeta_system vbmeta_system.img

echo "### switching to fastbootd for dynamic partitions"
$FB reboot fastboot
sleep 5
$FB devices
if ! $FB devices | grep -q .; then
  echo "Device did not enter fastbootd. Check 'fastboot devices' manually."
  exit 1
fi

$FB flash system        system.img
$FB flash system_ext    system_ext.img
$FB flash product       product.img
$FB flash vendor        vendor.img
$FB flash system_dlkm   system_dlkm.img
$FB flash vendor_dlkm   vendor_dlkm.img

echo "### wiping userdata (required for signature change)"
$FB -w

echo "### rebooting"
$FB reboot

echo "### done."
