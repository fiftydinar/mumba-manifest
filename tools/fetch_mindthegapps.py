#!/usr/bin/env python3
"""Stage the latest MindTheGapps (Android 16, arm64) as vendor/partner_gms.

Downloads the newest MindTheGapps 16.0.0-arm64 release, verifies its sha256 and
stages:

- proprietary/: product/ and system_ext/ from the zip (APKs are not used from the
  zip's overlay/ directory; overlays are rebuilt from source, see below).
- overlay/: runtime resource overlay SOURCES from the vendor_gapps commit that the
  release points to (the release body links it). Soong builds them, signed with
  our keys, so their target signatures match.
- Android.bp: android_app_import per APK (PRESIGNED, so the original Google
  signature is kept and the release signing step leaves them alone), plus
  runtime_resource_overlay modules come from overlay/*/Android.bp.
- products/gms_minimal.mk: PRODUCT_PACKAGES for APK and overlay modules, and
  PRODUCT_COPY_FILES for the remaining files (permissions, libs, jars).

Build rules forbid installing APKs through PRODUCT_COPY_FILES, so APKs must go
through Soong. Re-run to pick up a newer release; pass --tag to pin one.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPOSITORY = "MindTheGapps/16.0.0-arm64"
VENDOR_REPOSITORY = "MindTheGapps/vendor_gapps"
LATEST_API = f"https://api.github.com/repos/{REPOSITORY}/releases/latest"
TAG_API = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/{{tag}}"
TREE_API = f"https://api.github.com/repos/{VENDOR_REPOSITORY}/git/trees/{{commit}}?recursive=1"
RAW_URL = f"https://raw.githubusercontent.com/{VENDOR_REPOSITORY}/{{commit}}/{{path}}"
HEADERS = {"Accept": "application/vnd.github+json", "User-Agent": "mumba-partner-gms"}
if os.environ.get("GITHUB_TOKEN"):
    HEADERS["Authorization"] = f'Bearer {os.environ["GITHUB_TOKEN"]}'

COPY_OUT = {
    "product": "$(TARGET_COPY_OUT_PRODUCT)",
    "system_ext": "$(TARGET_COPY_OUT_SYSTEM_EXT)",
}
# Cache lives outside the build tree: Soong scans the tree for Android.bp files.
CACHE_DIR = Path.home() / ".cache" / "mumba-mindthegapps"
# Overlay source files we do not need for the build.
OVERLAY_SKIP = {"apktool.yml", "build_overlays.sh"}


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def vendor_commit(release: dict) -> str:
    """The release body links the vendor_gapps commit the package was built from."""
    match = re.search(r"vendor_gapps/tree/([0-9a-f]{40})", release.get("body") or "")
    if not match:
        sys.exit("error: release body does not reference a vendor_gapps commit")
    return match.group(1)


def stage_overlays(partner: Path, commit: str) -> list[str]:
    overlay_root = partner / "overlay"
    if overlay_root.exists():
        shutil.rmtree(overlay_root)
    # Tree listing is cached per commit: the GitHub API is rate limited.
    tree_cache = CACHE_DIR / f"vendor_gapps-{commit}.json"
    if tree_cache.exists():
        tree = json.loads(tree_cache.read_text(encoding="utf-8"))
    else:
        tree = fetch_json(TREE_API.format(commit=commit))
        tree_cache.parent.mkdir(parents=True, exist_ok=True)
        tree_cache.write_text(json.dumps(tree), encoding="utf-8")
    names: set[str] = set()
    for entry in tree.get("tree", []):
        path = entry["path"]
        if entry["type"] != "blob" or not path.startswith("overlay/"):
            continue
        relative = Path(path).relative_to("overlay")
        if relative.name in OVERLAY_SKIP or len(relative.parts) < 2:
            continue
        names.add(relative.parts[0])
        download(RAW_URL.format(commit=commit, path=path), overlay_root / relative)
    if not names:
        sys.exit("error: no overlay sources found at the vendor_gapps commit")
    return sorted(names)


def app_module(partition: str, relative: Path) -> dict:
    """Describe one APK as a Soong android_app_import module.

    relative is the path below the partition root, e.g. priv-app/GmsCore/GmsCore.apk.
    The module name is the APK's directory name so the installed path is unchanged.
    """
    top = relative.parts[0]
    name = relative.parent.name if len(relative.parts) > 2 else relative.stem
    props = {
        "name": name,
        "apk": f"proprietary/{partition}/{relative.as_posix()}",
        "partition": partition,
        "privileged": False,
    }
    if partition == "product":
        if top == "priv-app":
            props["privileged"] = True
        elif top != "app":
            sys.exit(f"error: unexpected MindTheGapps APK location: {partition}/{relative}")
    elif partition == "system_ext":
        if top != "priv-app":
            sys.exit(f"error: unexpected MindTheGapps APK location: {partition}/{relative}")
        props["privileged"] = True
    return props


def bp_module(props: dict) -> str:
    lines = [
        "android_app_import {",
        f'    name: "{props["name"]}",',
        '    owner: "gapps",',
        f'    apk: "{props["apk"]}",',
        "    presigned: true,",
        "    preprocessed: true,",
        "    dex_preopt: {",
        "        enabled: false,",
        "    },",
    ]
    if props["partition"] == "product":
        lines.append("    product_specific: true,")
    else:
        lines.append("    system_ext_specific: true,")
    if props["privileged"]:
        lines.append("    privileged: true,")
    lines.append("}")
    return "\n".join(lines)


def stage(partner: Path, staging: Path, tag: str, overlays: list[str]) -> tuple[int, int]:
    proprietary = partner / "proprietary"
    if proprietary.exists():
        shutil.rmtree(proprietary)
    proprietary.mkdir(parents=True)

    modules: list[dict] = []
    copy_lines: list[str] = []
    for partition, copy_out in COPY_OUT.items():
        source = staging / "system" / partition
        if not source.is_dir():
            continue
        destination = proprietary / partition
        shutil.copytree(source, destination)
        for path in sorted(destination.rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(destination)
            # Overlay APKs from the zip are replaced by the source build in overlay/.
            if relative.parts[0] == "overlay":
                continue
            if path.suffix == ".apk":
                modules.append(app_module(partition, relative))
            else:
                copy_lines.append(
                    f"PRODUCT_COPY_FILES += vendor/partner_gms/proprietary/{partition}/"
                    f"{relative.as_posix()}:{copy_out}/{relative.as_posix()}"
                )

    if not modules and not copy_lines:
        sys.exit("error: MindTheGapps package did not contain product/ or system_ext/ files")

    names = [module["name"] for module in modules]
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        sys.exit(f"error: duplicate APK module names: {', '.join(duplicates)}")
    clashes = sorted(set(names) & set(overlays))
    if clashes:
        sys.exit(f"error: APK and overlay module names collide: {', '.join(clashes)}")

    (partner / "Android.bp").write_text(
        "// Generated by tools/fetch_mindthegapps.py - do not edit.\n"
        f"// MindTheGapps {tag}\n\n"
        + "\n\n".join(bp_module(module) for module in modules)
        + "\n",
        encoding="utf-8",
    )

    packages = sorted(names + overlays)
    products = partner / "products"
    products.mkdir(parents=True, exist_ok=True)
    (products / "gms_minimal.mk").write_text(
        "# Generated by tools/fetch_mindthegapps.py - do not edit.\n"
        f"# MindTheGapps {tag}\n"
        "PRODUCT_PACKAGES += \\\n    " + " \\\n    ".join(packages) + "\n\n"
        + "\n".join(copy_lines) + "\n",
        encoding="utf-8",
    )
    return len(modules), len(overlays)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tree", type=Path, default=Path.cwd(),
                        help="build tree root (contains device/ and vendor/)")
    parser.add_argument("--cache", type=Path, default=None,
                        help="download cache dir (default: <tree>/.cache/mindthegapps)")
    parser.add_argument("--tag", default=None,
                        help="pin an exact MindTheGapps release tag (default: latest)")
    args = parser.parse_args()

    tree = args.tree.resolve()
    cache = (args.cache or CACHE_DIR).resolve()

    release = fetch_json(TAG_API.format(tag=args.tag) if args.tag else LATEST_API)
    tag = release["tag_name"]
    commit = vendor_commit(release)
    assets = {asset["name"]: asset["browser_download_url"] for asset in release["assets"]}
    zip_name = next((name for name in assets if name.endswith(".zip")), None)
    if zip_name is None:
        sys.exit("error: MindTheGapps release has no .zip asset")

    zip_path = cache / zip_name
    if not zip_path.exists():
        print(f"### downloading {zip_name}")
        download(assets[zip_name], zip_path)

    expected = None
    sha_name = zip_name + ".sha256sum"
    if sha_name in assets:
        sha_path = cache / sha_name
        if not sha_path.exists():
            download(assets[sha_name], sha_path)
        expected = sha_path.read_text(encoding="utf-8").split()[0].strip()

    actual = sha256_file(zip_path)
    if expected and expected != actual:
        zip_path.unlink(missing_ok=True)
        sys.exit(f"error: sha256 mismatch for {zip_name} (expected {expected}, got {actual})")
    print(f"### MindTheGapps {tag} sha256 {actual}")
    print(f"### vendor_gapps source commit {commit}")

    staging = cache / "extract"
    if staging.exists():
        shutil.rmtree(staging)
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(staging)

    partner = tree / "vendor" / "partner_gms"
    overlays = stage_overlays(partner, commit)
    apks, overlay_count = stage(partner, staging, tag, overlays)
    print(f"### staged {apks} APK modules and {overlay_count} overlay modules (source)")
    print("### wrote vendor/partner_gms/{Android.bp,overlay/,products/gms_minimal.mk}")


if __name__ == "__main__":
    main()
