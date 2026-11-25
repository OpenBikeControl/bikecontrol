"""Tests for scripts/msstore_submission.py (no network).

    python3 -m unittest scripts/test_msstore_submission.py
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("msstore_submission", Path(__file__).with_name("msstore_submission.py"))
ms = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ms)


def submission():
    return {
        "applicationPackages": [{"fileName": "old.msix", "fileStatus": "Uploaded", "version": "7.6.2.0"}],
        "listings": {
            "en-us": {
                "baseListing": {
                    "releaseNotes": "old",
                    "images": [
                        {"fileName": "icon.png", "fileStatus": "Uploaded", "imageType": "Icon"},
                        {"fileName": "a.png", "fileStatus": "Uploaded", "imageType": "Screenshot"},
                    ],
                }
            }
        },
    }


class MsStoreSubmissionTest(unittest.TestCase):
    def test_package_replaces_the_old_one(self):
        s = submission()
        ms.replace_package(s, "bike_control.store.msix")
        self.assertEqual([(p["fileName"], p["fileStatus"]) for p in s["applicationPackages"]],
                         [("old.msix", "PendingDelete"), ("bike_control.store.msix", "PendingUpload")])

    def test_release_notes_go_to_every_listing_and_respect_the_limit(self):
        s = submission()
        ms.set_release_notes(s, "Fixes:\n• one")
        self.assertEqual(s["listings"]["en-us"]["baseListing"]["releaseNotes"], "Fixes:\n• one")
        with self.assertRaises(ValueError):
            ms.set_release_notes(s, "x" * 1501)

    def test_screenshots_replace_only_screenshots_in_order(self):
        s = submission()
        ms.replace_screenshots(s, ["screenshots/01.png", "screenshots/02.png"])
        images = s["listings"]["en-us"]["baseListing"]["images"]
        self.assertEqual([(i["fileName"], i["fileStatus"]) for i in images], [
            ("icon.png", "Uploaded"),
            ("a.png", "PendingDelete"),
            ("screenshots/01.png", "PendingUpload"),
            ("screenshots/02.png", "PendingUpload"),
        ])

    def test_screenshot_files_are_sorted_images_only(self):
        with tempfile.TemporaryDirectory() as d:
            for name in ["02-b.jpg", "01-a.png", "notes.txt"]:
                Path(d, name).write_bytes(b"x")
            self.assertEqual([p.name for p in ms.screenshot_files(Path(d))], ["01-a.png", "02-b.jpg"])
            with self.assertRaises(ValueError):
                ms.screenshot_files(Path(tempfile.mkdtemp()))

    def test_summary_names_the_changes(self):
        s = submission()
        ms.replace_package(s, "new.msix")
        lines = ms.summary(s)
        self.assertIn("package PendingUpload: new.msix", lines)
        self.assertIn("package PendingDelete: old.msix 7.6.2.0", lines)


if __name__ == "__main__":
    unittest.main()
