# /// script
# requires-python = ">=3.11"
# dependencies = ["pyjwt[crypto]>=2.8", "requests>=2.32"]
# ///
"""app store connect steps for a testflight build, with a team api key.

the key file stays in ~/.appstoreconnect/private_keys/AuthKey_<key id>.p8 (where altool
also looks). the key id and the issuer id come from the environment: ASC_KEY_ID, ASC_ISSUER_ID.

  uv run scripts/asc.py bundle-id               # registers com.ramimaalouf.multiplexer
  uv run scripts/asc.py profile                 # app store profile -> ~/Library/MobileDevice/Provisioning Profiles
  uv run scripts/asc.py status                  # the app record, its builds, its testflight groups
  uv run scripts/asc.py group                   # an internal group "Teammates" with access to every build
"""
import base64
import os
import sys
import time
from pathlib import Path

import jwt
import requests

BUNDLE = "com.ramimaalouf.multiplexer"
API = "https://api.appstoreconnect.apple.com/v1"
PROFILES = Path.home() / "Library/MobileDevice/Provisioning Profiles"


def token() -> str:
    key_id, issuer = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer:
        sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID")
    key = (Path.home() / f".appstoreconnect/private_keys/AuthKey_{key_id}.p8").read_text()
    now = int(time.time())
    claims = {"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(claims, key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})


def call(method: str, path: str, **kwargs) -> dict:
    r = requests.request(method, f"{API}{path}", headers={"Authorization": f"Bearer {token()}"}, timeout=60, **kwargs)
    if r.status_code >= 400:
        # apple's error answers hold no secret: titles and details only.
        sys.exit(f"{method} {path}: {r.status_code} {r.text}")
    return r.json() if r.text else {}


def bundle_id() -> dict | None:
    found = call("GET", "/bundleIds", params={"filter[identifier]": BUNDLE})["data"]
    return next((b for b in found if b["attributes"]["identifier"] == BUNDLE), None)


def app() -> dict | None:
    found = call("GET", "/apps", params={"filter[bundleId]": BUNDLE})["data"]
    return found[0] if found else None


def register() -> None:
    if (b := bundle_id()) is not None:
        print(f"bundle id {BUNDLE} already registered ({b['id']})")
        return
    data = {"type": "bundleIds", "attributes": {"identifier": BUNDLE, "name": "Multiplexer", "platform": "IOS"}}
    b = call("POST", "/bundleIds", json={"data": data})["data"]
    print(f"registered bundle id {BUNDLE} ({b['id']})")


def profile() -> None:
    b = bundle_id()
    if b is None:
        sys.exit(f"register {BUNDLE} first: uv run scripts/asc.py bundle-id")
    certs = [c for c in call("GET", "/certificates", params={"limit": 200})["data"]
             if c["attributes"]["certificateType"] in ("DISTRIBUTION", "IOS_DISTRIBUTION")]
    if not certs:
        sys.exit("no apple distribution certificate on the team: make one in xcode (settings > accounts > manage certificates)")
    newest = max(certs, key=lambda c: c["attributes"]["expirationDate"])
    name = f"Multiplexer App Store {time.strftime('%Y%m%d%H%M')}"
    data = {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": b["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": newest["id"]}]},
        },
    }
    p = call("POST", "/profiles", json={"data": data})["data"]
    PROFILES.mkdir(parents=True, exist_ok=True)
    out = PROFILES / f"{p['attributes']['uuid']}.mobileprovision"
    out.write_bytes(base64.b64decode(p["attributes"]["profileContent"]))
    print(f"profile '{name}' -> {out}")
    print(f"certificate serial {newest['attributes']['serialNumber']}, expires {newest['attributes']['expirationDate']}")


def status() -> None:
    a = app()
    if a is None:
        print(f"no app record for {BUNDLE} yet: make it in app store connect (apps > + > new app)")
        return
    print(f"app '{a['attributes']['name']}' ({a['id']})")
    builds = call("GET", "/builds", params={"filter[app]": a["id"], "sort": "-uploadedDate", "limit": 5})["data"]
    for b in builds:
        at = b["attributes"]
        print(f"  build {at['version']}: {at['processingState']}, uploaded {at['uploadedDate']}")
    groups = call("GET", f"/apps/{a['id']}/betaGroups")["data"]
    for g in groups:
        print(f"  group '{g['attributes']['name']}' internal={g['attributes']['isInternalGroup']}")


def group() -> None:
    a = app()
    if a is None:
        sys.exit("no app record yet")
    groups = call("GET", f"/apps/{a['id']}/betaGroups")["data"]
    if any(g["attributes"]["name"] == "Teammates" for g in groups):
        print("group 'Teammates' already exists")
        return
    data = {
        "type": "betaGroups",
        "attributes": {"name": "Teammates", "isInternalGroup": True, "hasAccessToAllBuilds": True},
        "relationships": {"app": {"data": {"type": "apps", "id": a["id"]}}},
    }
    g = call("POST", "/betaGroups", json={"data": data})["data"]
    print(f"internal group 'Teammates' ({g['id']}): add teammates in app store connect, testflight > Teammates")


if __name__ == "__main__":
    steps = {"bundle-id": register, "profile": profile, "status": status, "group": group}
    if len(sys.argv) != 2 or sys.argv[1] not in steps:
        sys.exit(f"usage: uv run scripts/asc.py {{{'|'.join(steps)}}}")
    steps[sys.argv[1]]()
