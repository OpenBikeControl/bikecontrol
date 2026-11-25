#!/usr/bin/env python3
"""Microsoft Store submission through the Partner Center submission API.

Creates a submission for BikeControl (a copy of the last published one),
replaces what was passed, uploads the files and commits it for certification:

  python3 scripts/msstore_submission.py \
      [--msix build/.../bike_control.store.msix] \
      [--release-notes notes.txt] \
      [--screenshots screenshots/store/en/androidTablet10] \
      [--dry-run]

  --msix           replaces the app package (the old one is removed).
  --release-notes  plain text for every listing language (the Store takes
                   1500 characters; see scripts/get_latest_changelog.sh --windows).
  --screenshots    replaces the listing's screenshots with the directory's
                   images, in file-name order. JPEGs are converted to PNG
                   (needs Pillow), since the Store takes PNG only.
  --dry-run        reads the last published submission and prints what would
                   change; creates nothing.

Limitation: with Partner Center's advanced pricing model (BikeControl: base
price "Base" + 7-day trial) the v1 API cannot save a submission without
resetting the price to Free; the script detects that and deletes its
submission before committing. Until the API supports it, submit packages
through Partner Center (Start update -> Packages -> upload -> Save -> Submit).

Credentials (an Entra ID app with the Manager role in Partner Center, here
"uploadmsix" in the openbikecontrol.onmicrosoft.com tenant) come from
MSSTORE_TENANT_ID, MSSTORE_CLIENT_ID and MSSTORE_CLIENT_SECRET.

API: https://learn.microsoft.com/windows/uwp/monetize/manage-app-submissions
"""

from __future__ import annotations

import argparse
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

APP_ID = "9NP42GS03Z26"
API = f"https://manage.devcenter.microsoft.com/v1.0/my/applications/{APP_ID}"
RELEASE_NOTES_LIMIT = 1500
SCREENSHOT_SUFFIXES = {".png", ".jpg", ".jpeg"}

# Commit is done once the status leaves these; CommitFailed is the only failure.
COMMIT_PENDING = {"CommitStarted"}


# ---------------------------------------------------------------- pure parts

def replace_package(submission: dict, file_name: str) -> None:
    """Marks the current packages for removal and adds [file_name]."""
    for package in submission.get("applicationPackages", []):
        package["fileStatus"] = "PendingDelete"
    submission.setdefault("applicationPackages", []).append({
        "fileName": file_name,
        "fileStatus": "PendingUpload",
        "minimumDirectXVersion": "None",
        "minimumSystemRam": "None",
    })


def set_release_notes(submission: dict, notes: str) -> None:
    if len(notes) > RELEASE_NOTES_LIMIT:
        raise ValueError(f"release notes are {len(notes)} characters, the Store takes {RELEASE_NOTES_LIMIT}")
    for listing in submission.get("listings", {}).values():
        listing.setdefault("baseListing", {})["releaseNotes"] = notes


def replace_screenshots(submission: dict, file_names: list[str]) -> None:
    """Marks every listing's screenshots for removal and adds [file_names] in
    order. Other images (icons, logos) stay."""
    for listing in submission.get("listings", {}).values():
        images = listing.setdefault("baseListing", {}).setdefault("images", [])
        for image in images:
            if image.get("imageType") == "Screenshot":
                image["fileStatus"] = "PendingDelete"
        for name in file_names:
            images.append({"fileName": name, "fileStatus": "PendingUpload", "imageType": "Screenshot", "description": ""})


def screenshot_files(directory: Path) -> list[Path]:
    files = sorted(p for p in directory.iterdir() if p.suffix.lower() in SCREENSHOT_SUFFIXES)
    if not files:
        raise ValueError(f"no screenshots in {directory}")
    if len(files) > 10:
        raise ValueError(f"{len(files)} screenshots in {directory}, the Store takes 10")
    return files


def update_body(submission: dict) -> dict:
    """The submission as the update (PUT) takes it. With the advanced pricing
    model the copy reports the price as priceId "Base", which the update
    rejects ("'Base' is not a valid PriceId"), while leaving pricing out is
    rejected too. So pricing goes back without priceId; the price stays as it
    is in Partner Center (checked after the update, see [same_pricing])."""
    body = dict(submission)
    pricing = body.get("pricing", {})
    if pricing.get("priceId") == "Base":
        body["pricing"] = {k: v for k, v in pricing.items() if k != "priceId"}
    return body


def same_pricing(before: dict, after: dict) -> bool:
    return before.get("pricing") == after.get("pricing")


def summary(submission: dict) -> list[str]:
    """What the submission adds and removes, for logs and --dry-run."""
    lines = []
    for p in submission.get("applicationPackages", []):
        if p.get("fileStatus") in ("PendingDelete", "PendingUpload"):
            lines.append(f"package {p['fileStatus']}: {p.get('fileName')} {p.get('version', '')}".rstrip())
    for locale, listing in submission.get("listings", {}).items():
        base = listing.get("baseListing", {})
        for image in base.get("images", []):
            if image.get("fileStatus") in ("PendingDelete", "PendingUpload"):
                lines.append(f"{locale} {image['imageType']} {image['fileStatus']}: {image.get('fileName')}")
        lines.append(f"{locale} release notes: {len(base.get('releaseNotes', ''))} characters")
    return lines


# ---------------------------------------------------------------- API

class Store:
    def __init__(self, tenant: str, client_id: str, secret: str):
        body = urllib.parse.urlencode({
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": secret,
            "resource": "https://manage.devcenter.microsoft.com",
        }).encode()
        with urllib.request.urlopen(f"https://login.microsoftonline.com/{tenant}/oauth2/token", body) as r:
            self._token = json.load(r)["access_token"]

    def call(self, method: str, path: str = "", body: dict | None = None) -> dict:
        request = urllib.request.Request(
            API + path,
            method=method,
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self._token}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request) as r:
                text = r.read().decode()
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{method} {path or '/'} -> HTTP {e.code}: {e.read().decode()[:2000]}") from None
        return json.loads(text) if text else {}


def upload_zip(url: str, payload: bytes) -> None:
    # The SAS URL can contain '+', which the blob service reads as a space.
    request = urllib.request.Request(
        url.replace("+", "%2B"), method="PUT", data=payload, headers={"x-ms-blob-type": "BlockBlob"}
    )
    with urllib.request.urlopen(request) as r:
        if r.status not in (200, 201):
            raise RuntimeError(f"upload -> HTTP {r.status}")


def png_bytes(path: Path) -> bytes:
    if path.suffix.lower() == ".png":
        return path.read_bytes()
    from PIL import Image  # only needed for JPEG sources
    out = io.BytesIO()
    Image.open(path).convert("RGB").save(out, "PNG", optimize=True)
    return out.getvalue()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--msix", type=Path)
    parser.add_argument("--release-notes", type=Path)
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--wait-minutes", type=int, default=30, help="how long to wait for the commit to finish")
    args = parser.parse_args(argv)
    if not (args.msix or args.release_notes or args.screenshots):
        parser.error("nothing to submit: pass --msix, --release-notes and/or --screenshots")

    store = Store(os.environ["MSSTORE_TENANT_ID"], os.environ["MSSTORE_CLIENT_ID"], os.environ["MSSTORE_CLIENT_SECRET"])
    app = store.call("GET")
    pending = app.get("pendingApplicationSubmission")

    files: dict[str, bytes] = {}
    shots = screenshot_files(args.screenshots) if args.screenshots else []

    if args.dry_run:
        submission = store.call("GET", f"/submissions/{app['lastPublishedApplicationSubmission']['id']}")
    else:
        if pending:
            print(f"error: submission {pending['id']} is already in progress in Partner Center; "
                  "finish or delete it first", file=sys.stderr)
            return 1
        submission = store.call("POST", "/submissions")
        print(f"created submission {submission['id']}")

    if args.msix:
        replace_package(submission, args.msix.name)
        files[args.msix.name] = args.msix.read_bytes() if not args.dry_run else b""
    if args.release_notes:
        set_release_notes(submission, args.release_notes.read_text(encoding="utf-8").strip())
    if shots:
        names = [f"screenshots/{p.stem}.png" for p in shots]
        replace_screenshots(submission, names)
        if not args.dry_run:
            files.update({name: png_bytes(p) for name, p in zip(names, shots)})

    for line in summary(submission):
        print(line)
    if args.dry_run:
        print(f"dry run: nothing created (pending submission: {pending['id'] if pending else 'none'})")
        return 0

    submission_id = submission["id"]
    try:
        if files:
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as z:
                for name, data in files.items():
                    z.writestr(name, data)
            upload_zip(submission["fileUploadUrl"], buffer.getvalue())
            print(f"uploaded {len(files)} file(s), {buffer.tell() // 1024} KB")
        store.call("PUT", f"/submissions/{submission_id}", update_body(submission))
        saved = store.call("GET", f"/submissions/{submission_id}")
        if not same_pricing(submission, saved):
            raise RuntimeError(f"pricing changed by the update: {submission.get('pricing')} -> {saved.get('pricing')}")
        store.call("POST", f"/submissions/{submission_id}/commit")
    except Exception:
        print(f"failed; deleting submission {submission_id} so the next run can start clean", file=sys.stderr)
        try:
            store.call("DELETE", f"/submissions/{submission_id}")
        except Exception as e:  # keep the original error
            print(f"could not delete it: {e}", file=sys.stderr)
        raise

    deadline = time.time() + args.wait_minutes * 60
    while True:
        status = store.call("GET", f"/submissions/{submission_id}/status")
        state = status.get("status")
        if state not in COMMIT_PENDING or time.time() > deadline:
            break
        time.sleep(30)
    print(f"submission {submission_id}: {state}")
    if state == "CommitFailed":
        print(json.dumps(status.get("statusDetails"), indent=2), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
