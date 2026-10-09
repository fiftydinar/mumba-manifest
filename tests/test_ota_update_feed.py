import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from ota.generate_updates import create_update


BUILD_TIMESTAMP = "1791387584"
OTA_PROPERTIES = (
    "payload.bin:4488:2048,payload_properties.txt:6536:156,metadata:69:672"
)


def write_target_files(path: Path, build_type: str = "user", timestamp: str = BUILD_TIMESTAMP):
    system_properties = "\n".join(
        (
            f"ro.build.type={build_type}",
            f"ro.build.date.utc={timestamp}",
            "ro.build.version.sdk=36",
            "ro.build.version.security_patch=2026-09-01",
            "ro.lineage.device=mumba",
        )
    )
    product_properties = "\n".join(
        (
            "ro.lineage.releasetype=UNOFFICIAL",
            "ro.lineage.version=23.2-20261007-UNOFFICIAL-mumba",
        )
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("SYSTEM/build.prop", system_properties)
        archive.writestr("PRODUCT/etc/build.prop", product_properties)


def write_ota(path: Path, ota_type: str = "AB", timestamp: str = BUILD_TIMESTAMP):
    metadata = "\n".join(
        (
            f"ota-type={ota_type}",
            f"post-timestamp={timestamp}",
            "post-sdk-level=36",
            "post-security-patch-level=2026-09-01",
            "pre-device=mumba_g",
            f"ota-streaming-property-files={OTA_PROPERTIES}",
        )
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("payload.bin", b"payload")
        archive.writestr("payload_properties.txt", b"FILE_HASH=abc\n")
        archive.writestr("META-INF/com/android/metadata", metadata)
        archive.writestr("META-INF/com/android/otacert", b"certificate")


class OtaUpdateFeedTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.target_files = self.root / "target_files.zip"
        self.ota = self.root / "lineage_mumba-signed-ota.zip"
        write_target_files(self.target_files)
        write_ota(self.ota)

    def tearDown(self):
        self.tempdir.cleanup()

    def test_generates_lineage_updater_feed_and_checksum(self):
        updates, checksum = create_update(
            self.target_files,
            self.ota,
            "mumba-23.2-20261007",
        )

        self.assertEqual(len(updates), 1)
        update = updates[0]
        self.assertEqual(update["datetime"], int(BUILD_TIMESTAMP))
        self.assertEqual(update["type"], "UNOFFICIAL")
        self.assertEqual(update["version"], "23.2-20261007-UNOFFICIAL-mumba")
        asset = update["files"][0]
        self.assertEqual(asset["sha256"], checksum)
        self.assertEqual(asset["ota_property_files"], OTA_PROPERTIES)
        self.assertEqual(
            asset["url"],
            "https://github.com/fiftydinar/mumba-manifest/releases/download/"
            "mumba-23.2-20261007/lineage_mumba-signed-ota.zip",
        )

    def test_rejects_non_user_build(self):
        write_target_files(self.target_files, build_type="userdebug")
        with self.assertRaisesRegex(ValueError, "non-user"):
            create_update(self.target_files, self.ota, "mumba-test")

    def test_rejects_non_ab_ota(self):
        write_ota(self.ota, ota_type="BLOCK")
        with self.assertRaisesRegex(ValueError, "not an A/B"):
            create_update(self.target_files, self.ota, "mumba-test")

    def test_rejects_mismatched_build_timestamp(self):
        write_ota(self.ota, timestamp="1791387585")
        with self.assertRaisesRegex(ValueError, "post-timestamp"):
            create_update(self.target_files, self.ota, "mumba-test")

    def test_feed_is_json_serializable(self):
        updates, _ = create_update(self.target_files, self.ota, "mumba-test")
        self.assertEqual(json.loads(json.dumps(updates))[0]["files"][0]["filename"], self.ota.name)


if __name__ == "__main__":
    unittest.main()
