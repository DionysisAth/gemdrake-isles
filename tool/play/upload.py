#!/usr/bin/env python3
"""Uploads the store listing and/or an app bundle to Google Play Console.

Needs a Google Cloud service account with access to the app in Play Console
(Users and permissions), and `pip install google-auth requests`.

    # Store listing text (tool/play/listing/<lang>/) and graphics
    python3 tool/play/upload.py --key play-key.json --listing \\
        --graphics build/store

    # A signed app bundle to a testing track, as a draft release
    python3 tool/play/upload.py --key play-key.json \\
        --bundle gemdrake-isles.aab --track internal

A new app stays in draft until it's published, so releases are created as
drafts: roll them out from Play Console once the app's setup is complete.
"""

import argparse
import pathlib
import sys

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

ROOT = pathlib.Path(__file__).resolve().parent
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
PACKAGE = "com.gemdrake.gemdrake_isles"


def check(r, what):
    if not r.ok:
        sys.exit(f"{what} failed ({r.status_code}): {r.text}")
    return r.json() if r.text else {}


def upload_listing(s, pkg, edit, graphics):
    for lang_dir in sorted((ROOT / "listing").iterdir()):
        lang = lang_dir.name
        body = {
            "language": lang,
            "title": (lang_dir / "title.txt").read_text().strip(),
            "shortDescription": (lang_dir / "short_description.txt").read_text().strip(),
            "fullDescription": (lang_dir / "full_description.txt").read_text().strip(),
        }
        check(s.put(f"{API}/{pkg}/edits/{edit}/listings/{lang}", json=body), f"listing {lang}")
        print(f"Listing text set ({lang})")
        if not graphics:
            continue
        g = pathlib.Path(graphics)
        images = [
            ("icon", [g / "icon_512.png"]),
            ("featureGraphic", [g / "feature_graphic.png"]),
            ("phoneScreenshots", sorted(g.glob("screenshot_*.png"))),
        ]
        for kind, files in images:
            files = [f for f in files if f.exists()]
            if not files:
                continue
            base = f"{API}/{pkg}/edits/{edit}/listings/{lang}/{kind}"
            check(s.delete(base), f"clear {kind}")
            for f in files:
                r = s.post(
                    f"{UPLOAD}/{pkg}/edits/{edit}/listings/{lang}/{kind}",
                    params={"uploadType": "media"},
                    data=f.read_bytes(),
                    headers={"Content-Type": "image/png"},
                )
                check(r, f"upload {f.name}")
            print(f"Uploaded {len(files)} {kind} ({lang})")


def upload_bundle(s, pkg, edit, bundle, track, notes):
    r = s.post(
        f"{UPLOAD}/{pkg}/edits/{edit}/bundles",
        params={"uploadType": "media"},
        data=pathlib.Path(bundle).read_bytes(),
        headers={"Content-Type": "application/octet-stream"},
        timeout=600,
    )
    version = check(r, "bundle upload")["versionCode"]
    print(f"Uploaded bundle, version code {version}")
    release = {"versionCodes": [str(version)], "status": "draft"}
    if notes:
        release["releaseNotes"] = [{"language": "en-US", "text": notes}]
    check(
        s.put(f"{API}/{pkg}/edits/{edit}/tracks/{track}", json={"track": track, "releases": [release]}),
        f"{track} track",
    )
    print(f"Draft release on the {track} track")


def main():
    p = argparse.ArgumentParser(description="Upload to Google Play Console")
    p.add_argument("--key", required=True, help="service account JSON key")
    p.add_argument("--package", default=PACKAGE)
    p.add_argument("--listing", action="store_true", help="upload listing text")
    p.add_argument("--graphics", help="folder with icon, feature graphic, screenshots")
    p.add_argument("--bundle", help="signed .aab to upload")
    p.add_argument("--track", default="internal")
    p.add_argument("--notes", default="", help="release notes (en-US)")
    a = p.parse_args()
    if not (a.listing or a.bundle):
        p.error("nothing to do: pass --listing and/or --bundle")

    creds = service_account.Credentials.from_service_account_file(
        a.key, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    s = AuthorizedSession(creds)
    edit = check(s.post(f"{API}/{a.package}/edits", json={}), "open edit")["id"]
    try:
        if a.listing:
            upload_listing(s, a.package, edit, a.graphics)
        if a.bundle:
            upload_bundle(s, a.package, edit, a.bundle, a.track, a.notes)
        check(s.post(f"{API}/{a.package}/edits/{edit}:commit"), "commit")
        print("Saved to Play Console.")
    except SystemExit:
        s.delete(f"{API}/{a.package}/edits/{edit}")
        raise


if __name__ == "__main__":
    main()
