#!/usr/bin/env python3
"""Sets up the app's products and contact details in Google Play Console.

Creates (or updates) every product in assets/config/store.json with the
price from its "priceHint" (in US dollars, converted by Google to every
country), activates them, and sets the store contact details. Safe to run
again after changing prices or texts.

    pip install google-auth requests
    python3 tool/play/setup_store.py --key play-key.json --products \\
        --email you@example.com --website https://example.com/

Play only allows products once a build that uses Google Play Billing has
been uploaded, and the developer account needs a payments profile.
"""

import argparse
import json
import pathlib
import re
import sys

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

ROOT = pathlib.Path(__file__).resolve().parents[2]
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
PACKAGE = "com.gemdrake.gemdrake_isles"
LANG = "en-US"


def check(r, what):
    if not r.ok:
        sys.exit(f"{what} failed ({r.status_code}): {r.text}")
    return r.json() if r.text else {}


def usd(hint):
    m = re.search(r"\$(\d+)\.(\d\d)", hint)
    if not m:
        sys.exit(f"can't read a price from {hint!r}")
    return {"currencyCode": "USD", "units": m[1], "nanos": int(m[2]) * 10_000_000}


def describe(p):
    if p.get("desc"):
        return p["desc"]
    parts = [f"{p[k]:,} {k}" for k in ("gems", "coins", "energy") if p.get(k)]
    return ", ".join(parts) + "."


def convert(s, pkg, price):
    """Prices for every Play country from one US price."""
    r = check(
        s.post(f"{API}/{pkg}/pricing:convertRegionPrices", json={"price": price}),
        "price conversion",
    )
    regions = [
        (code, v["price"]) for code, v in sorted(r["convertedRegionPrices"].items())
    ]
    return regions, r["convertedOtherRegionsPrice"], r["regionVersion"]["version"]


def one_time(s, pkg, p):
    regions, other, version = convert(s, pkg, usd(p["priceHint"]))
    body = {
        "packageName": pkg,
        "productId": p["id"],
        "listings": [{"languageCode": LANG, "title": p["name"], "description": describe(p)}],
        "purchaseOptions": [
            {
                "purchaseOptionId": "buy",
                # Works with every version of Google Play Billing.
                "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
                "regionalPricingAndAvailabilityConfigs": [
                    {"regionCode": code, "price": price, "availability": "AVAILABLE"}
                    for code, price in regions
                ],
                "newRegionsConfig": {
                    "usdPrice": other["usdPrice"],
                    "eurPrice": other["eurPrice"],
                    "availability": "AVAILABLE",
                },
            }
        ],
    }
    check(
        s.patch(
            f"{API}/{pkg}/onetimeproducts/{p['id']}",
            params={
                "allowMissing": "true",
                "updateMask": "listings,purchaseOptions",
                "regionsVersion.version": version,
            },
            json=body,
        ),
        p["id"],
    )
    check(
        s.post(
            f"{API}/{pkg}/oneTimeProducts/{p['id']}/purchaseOptions:batchUpdateStates",
            json={
                "requests": [
                    {
                        "activatePurchaseOptionRequest": {
                            "packageName": pkg,
                            "productId": p["id"],
                            "purchaseOptionId": "buy",
                        }
                    }
                ]
            },
        ),
        f"activate {p['id']}",
    )
    print(f"{p['id']}: {p['name']}, {p['priceHint']}, active")


def subscription(s, pkg, p, vip):
    regions, other, version = convert(s, pkg, usd(p["priceHint"]))
    plan = {
        "basePlanId": "monthly",
        "autoRenewingBasePlanType": {
            "billingPeriodDuration": "P1M",
            "legacyCompatible": True,
            "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE",
        },
        "regionalConfigs": [
            {"regionCode": code, "price": price, "newSubscriberAvailability": True}
            for code, price in regions
        ],
        "otherRegionsConfig": {
            "usdPrice": other["usdPrice"],
            "eurPrice": other["eurPrice"],
            "newSubscriberAvailability": True,
        },
    }
    body = {
        "packageName": pkg,
        "productId": p["id"],
        "listings": [
            {
                "languageCode": LANG,
                "title": p["name"],
                "description": p["desc"][:80],
                "benefits": [
                    f"{vip['dailyGems']} gems every day",
                    f"+{vip['energyMax']} max energy",
                    f"+{vip['offlineHours']}h dragon hoard",
                ],
            }
        ],
        "basePlans": [plan],
    }
    exists = s.get(f"{API}/{pkg}/subscriptions/{p['id']}").ok
    if exists:
        check(
            s.patch(
                f"{API}/{pkg}/subscriptions/{p['id']}",
                params={"updateMask": "listings,basePlans", "regionsVersion.version": version},
                json=body,
            ),
            p["id"],
        )
    else:
        check(
            s.post(
                f"{API}/{pkg}/subscriptions",
                params={"productId": p["id"], "regionsVersion.version": version},
                json=body,
            ),
            p["id"],
        )
    sub = check(s.get(f"{API}/{pkg}/subscriptions/{p['id']}"), p["id"])
    if any(b["basePlanId"] == "monthly" and b.get("state") != "ACTIVE" for b in sub["basePlans"]):
        check(
            s.post(f"{API}/{pkg}/subscriptions/{p['id']}/basePlans/monthly:activate", json={}),
            f"activate {p['id']}",
        )
    print(f"{p['id']}: {p['name']}, {p['priceHint']}, active")


def set_details(s, pkg, email, website):
    edit = check(s.post(f"{API}/{pkg}/edits", json={}), "open edit")["id"]
    details = {"defaultLanguage": LANG}
    if email:
        details["contactEmail"] = email
    if website:
        details["contactWebsite"] = website
    check(s.put(f"{API}/{pkg}/edits/{edit}/details", json=details), "details")
    check(s.post(f"{API}/{pkg}/edits/{edit}:commit"), "commit")
    print(f"Contact details set: {details}")


def main():
    p = argparse.ArgumentParser(description="Set up products in Google Play Console")
    p.add_argument("--key", required=True, help="service account JSON key")
    p.add_argument("--package", default=PACKAGE)
    p.add_argument("--products", action="store_true", help="create/update store.json products")
    p.add_argument("--only", nargs="*", help="limit --products to these ids")
    p.add_argument("--email", help="store listing contact email")
    p.add_argument("--website", help="store listing website")
    p.add_argument("--data-safety", help="Data safety CSV exported from Play Console")
    a = p.parse_args()

    creds = service_account.Credentials.from_service_account_file(
        a.key, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    s = AuthorizedSession(creds)
    if a.email or a.website:
        set_details(s, a.package, a.email, a.website)
    if a.data_safety:
        csv = pathlib.Path(a.data_safety).read_text()
        check(s.post(f"{API}/{a.package}/dataSafety", json={"safetyLabels": csv}), "data safety")
        print("Data safety form saved")
    if a.products:
        store = json.loads((ROOT / "assets/config/store.json").read_text())
        for prod in store["products"]:
            if a.only and prod["id"] not in a.only:
                continue
            if prod["kind"] == "subscription":
                subscription(s, a.package, prod, store["vip"])
            else:
                one_time(s, a.package, prod)


if __name__ == "__main__":
    main()
