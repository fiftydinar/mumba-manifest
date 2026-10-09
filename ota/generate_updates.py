#!/usr/bin/env python3
"""Build the JSON feed consumed by LineageOS Updater from signed OTA artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from urllib.parse import quote


DEFAULT_REPOSITORY = "fiftydinar/mumba-manifest"
EXPECTED_DEVICE = "mumba"
ASSET_MAX_BYTES = 2 * 1024 * 1024 * 1024


def parse_properties(data: bytes) -> dict[str, str]:
    properties: dict[str, str] = {}
    for raw_line in data.decode("utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        properties.setdefault(key.strip(), value.strip())
    return properties


def load_target_properties(target_files: Path) -> dict[str, str]:
    # Properties are split between system and product build.prop files in target-files.
    property_archives = (
        "SYSTEM/build.prop",
        "SYSTEM_EXT/build.prop",
        "PRODUCT/etc/build.prop",
        "PRODUCT/build.prop",
        "VENDOR/build.prop",
    )
    properties: dict[str, str] = {}
    with zipfile.ZipFile(target_files) as archive:
        names = set(archive.namelist())
        for name in property_archives:
            if name in names:
                for key, value in parse_properties(archive.read(name)).items():
                    properties.setdefault(key, value)
    return properties


def parse_metadata(data: bytes) -> dict[str, str]:
    metadata: dict[str, str] = {}
    for line in data.decode("utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            metadata[key.strip()] = value.strip()
    return metadata


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def create_update(
    target_files: Path,
    ota: Path,
    tag: str,
    repository: str = DEFAULT_REPOSITORY,
) -> tuple[list[dict[str, object]], str]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", tag):
        raise ValueError("release tag may contain only letters, digits, '.', '_' and '-'")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError(f"invalid GitHub repository: {repository}")
    if ota.stat().st_size > ASSET_MAX_BYTES:
        raise ValueError("OTA exceeds GitHub's 2 GiB per-release-asset limit")

    props = load_target_properties(target_files)
    required_properties = (
        "ro.build.type",
        "ro.build.date.utc",
        "ro.build.version.sdk",
        "ro.build.version.security_patch",
        "ro.lineage.device",
        "ro.lineage.releasetype",
    )
    missing = [key for key in required_properties if not props.get(key)]
    if missing:
        raise ValueError(f"target-files is missing required build properties: {', '.join(missing)}")
    if props["ro.build.type"] != "user":
        raise ValueError("refusing to publish a non-user target-files package")
    if props["ro.lineage.device"] != EXPECTED_DEVICE:
        raise ValueError(
            f"target-files is for {props['ro.lineage.device']}, expected {EXPECTED_DEVICE}"
        )

    try:
        with zipfile.ZipFile(ota) as archive:
            names = set(archive.namelist())
            required_entries = {
                "payload.bin",
                "payload_properties.txt",
                "META-INF/com/android/metadata",
                "META-INF/com/android/otacert",
            }
            missing_entries = required_entries - names
            if missing_entries:
                raise ValueError(
                    "OTA is missing required A/B/signature entries: "
                    + ", ".join(sorted(missing_entries))
                )
            metadata = parse_metadata(archive.read("META-INF/com/android/metadata"))
    except zipfile.BadZipFile as error:
        raise ValueError(f"invalid OTA ZIP: {ota}") from error

    if metadata.get("ota-type") != "AB":
        raise ValueError("OTA package is not an A/B update")
    if EXPECTED_DEVICE not in metadata.get("pre-device", "").lower():
        raise ValueError("OTA pre-device metadata does not match mumba")

    try:
        build_timestamp = int(props["ro.build.date.utc"])
        ota_timestamp = int(metadata["post-timestamp"])
        sdk_level = int(props["ro.build.version.sdk"])
        ota_sdk_level = int(metadata["post-sdk-level"])
    except (KeyError, ValueError) as error:
        raise ValueError("target-files or OTA has invalid timestamp/SDK metadata") from error
    if build_timestamp != ota_timestamp:
        raise ValueError(
            "target-files build date and OTA post-timestamp do not match "
            f"({build_timestamp} != {ota_timestamp})"
        )
    if sdk_level != ota_sdk_level:
        raise ValueError("target-files SDK level and OTA post-sdk-level do not match")
    if props["ro.build.version.security_patch"] != metadata.get("post-security-patch-level"):
        raise ValueError("target-files security patch and OTA post-security-patch-level do not match")

    property_files = metadata.get("ota-streaming-property-files") or metadata.get(
        "ota-property-files", ""
    )
    ranges = {token.split(":", 1)[0].strip() for token in property_files.split(",") if token}
    if not {"payload.bin", "payload_properties.txt"}.issubset(ranges):
        raise ValueError("OTA metadata lacks A/B payload streaming ranges")

    version = props.get("ro.lineage.version") or props.get("ro.build.version.incremental")
    if not version:
        raise ValueError("target-files is missing the ROM version")

    checksum = sha256_file(ota)
    asset_url = (
        f"https://github.com/{repository}/releases/download/"
        f"{quote(tag, safe='')}/{quote(ota.name, safe='')}"
    )
    update = {
        "datetime": ota_timestamp,
        "files": [
            {
                "filename": ota.name,
                "os_patch_level": props["ro.build.version.security_patch"],
                "os_sdk_level": sdk_level,
                "ota_property_files": property_files,
                "sha256": checksum,
                "size": ota.stat().st_size,
                "url": asset_url,
            }
        ],
        "type": props["ro.lineage.releasetype"],
        "version": version,
    }
    return [update], checksum


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-files", required=True, type=Path)
    parser.add_argument("--ota", required=True, type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", default=DEFAULT_REPOSITORY)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--checksum-output", required=True, type=Path)
    args = parser.parse_args()

    try:
        updates, checksum = create_update(
            args.target_files,
            args.ota,
            args.tag,
            args.repository,
        )
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.error(str(error))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(updates, indent=2) + "\n", encoding="utf-8")
    args.checksum_output.parent.mkdir(parents=True, exist_ok=True)
    args.checksum_output.write_text(
        f"{checksum}  {args.ota.name}\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
