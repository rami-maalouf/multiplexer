# /// script
# requires-python = ">=3.12"
# ///
"""signs out the sessions of a matrix user on our server that nobody has used: no
name and never seen. the playbook's registration leaves one such session per user.
the password comes from the mac's keychain and is never printed.

    uv run server/remove-unused-sessions.py test1 multiplexer-test-account
"""

import json
import subprocess
import sys
import urllib.error
import urllib.request

HOMESERVER = "https://matrix.ramimaalouf.com"
DOMAIN = "ramimaalouf.com"


def call(method, path, token=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(HOMESERVER + path, method=method, data=data)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: remove-unused-sessions.py <user> <keychain service>")
    user, service = sys.argv[1], sys.argv[2]
    user_id = f"@{user}:{DOMAIN}"
    password = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-a", user_id, "-w"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    identifier = {"type": "m.id.user", "user": user}

    status, login = call("POST", "/_matrix/client/v3/login", body={
        "type": "m.login.password",
        "identifier": identifier,
        "password": password,
        "initial_device_display_name": "multiplexer session cleanup",
    })
    if status != 200:
        sys.exit(f"{user_id}: sign-in failed ({status} {login.get('errcode')})")
    token = login["access_token"]
    try:
        _, devices = call("GET", "/_matrix/client/v3/devices", token)
        unused = [
            d["device_id"] for d in devices["devices"]
            if d["device_id"] != login["device_id"]
            and not d.get("display_name") and not d.get("last_seen_ts")
        ]
        if not unused:
            print(f"{user_id}: no unused sessions")
            return
        body = {"devices": unused}
        status, reply = call("POST", "/_matrix/client/v3/delete_devices", token, body)
        # the server asks to confirm with the password (user-interactive auth).
        if status == 401:
            body["auth"] = {
                "type": "m.login.password",
                "identifier": identifier,
                "password": password,
                "session": reply.get("session"),
            }
            status, reply = call("POST", "/_matrix/client/v3/delete_devices", token, body)
        if status != 200:
            sys.exit(f"{user_id}: sign-out failed ({status} {reply.get('errcode')})")
        print(f"{user_id}: signed out {', '.join(unused)}")
    finally:
        # also ends this script's own session.
        call("POST", "/_matrix/client/v3/logout", token, {})


main()
