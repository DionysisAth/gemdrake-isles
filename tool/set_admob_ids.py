#!/usr/bin/env python3
"""Puts your AdMob IDs everywhere the game needs them.

Usage (any subset of the four IDs):

    python3 tool/set_admob_ids.py \\
        --android-app      ca-app-pub-1234567890123456~1111111111 \\
        --android-rewarded ca-app-pub-1234567890123456/2222222222 \\
        --ios-app          ca-app-pub-1234567890123456~3333333333 \\
        --ios-rewarded     ca-app-pub-1234567890123456/4444444444

It updates:
  android/app/src/main/AndroidManifest.xml  (Android app ID)
  ios/Runner/Info.plist                     (iOS app ID)
  assets/config/economy.json                (rewarded ad unit IDs)
  docs/app-ads.txt                          (from your publisher ID)

Once real unit IDs are set, the game never shows its placeholder video.
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_ID = re.compile(r"^ca-app-pub-(\d{16})~\d{10}$")
UNIT_ID = re.compile(r"^ca-app-pub-(\d{16})/\d{10}$")


def check(value, pattern, what):
    if value is None:
        return None
    m = pattern.match(value.strip())
    if not m:
        sys.exit(f"{what} doesn't look right: {value!r}")
    return m.group(1)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--android-app")
    p.add_argument("--android-rewarded")
    p.add_argument("--ios-app")
    p.add_argument("--ios-rewarded")
    a = p.parse_args()
    pubs = {
        check(a.android_app, APP_ID, "Android app ID (needs a ~)"),
        check(a.ios_app, APP_ID, "iOS app ID (needs a ~)"),
        check(a.android_rewarded, UNIT_ID, "Android rewarded unit ID (needs a /)"),
        check(a.ios_rewarded, UNIT_ID, "iOS rewarded unit ID (needs a /)"),
    } - {None}
    if not pubs:
        p.print_help()
        return
    if len(pubs) > 1:
        sys.exit("The IDs come from different AdMob accounts: " + ", ".join(pubs))

    if a.android_app:
        f = ROOT / "android/app/src/main/AndroidManifest.xml"
        s = f.read_text()
        s, n = re.subn(
            r'(android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"\s*'
            r'android:value=")[^"]*(")',
            rf"\g<1>{a.android_app}\g<2>",
            s,
        )
        assert n == 1, "AdMob meta-data not found in AndroidManifest.xml"
        f.write_text(s)
        print("Android app ID set")

    if a.ios_app:
        f = ROOT / "ios/Runner/Info.plist"
        s = f.read_text()
        s, n = re.subn(
            r"(<key>GADApplicationIdentifier</key>\s*<string>)[^<]*(</string>)",
            rf"\g<1>{a.ios_app}\g<2>",
            s,
        )
        assert n == 1, "GADApplicationIdentifier not found in Info.plist"
        f.write_text(s)
        print("iOS app ID set")

    if a.android_rewarded or a.ios_rewarded:
        f = ROOT / "assets/config/economy.json"
        d = json.loads(f.read_text())
        ids = d["ads"]["rewardedUnitIds"]
        if a.android_rewarded:
            ids["android"] = a.android_rewarded
        if a.ios_rewarded:
            ids["ios"] = a.ios_rewarded
        f.write_text(json.dumps(d, indent=2) + "\n")
        print("Rewarded unit IDs set")

    pub = pubs.pop()
    f = ROOT / "docs/app-ads.txt"
    f.parent.mkdir(exist_ok=True)
    f.write_text(f"google.com, pub-{pub}, DIRECT, f08c47fec0942fa0\n")
    print(f"docs/app-ads.txt written for pub-{pub}")


if __name__ == "__main__":
    main()
