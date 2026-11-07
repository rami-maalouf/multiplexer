# /// script
# requires-python = ">=3.11"
# dependencies = ["requests>=2.32"]
# ///
"""stages a demo inbox for @test-demo:ramimaalouf.com: made-up chats that look bridged.

  uv run scripts/stage-demo.py
  uv run scripts/stage-demo.py --redo maya     # leaves and forgets that chat, then makes it again

each chat is a room between @test-demo and a demo contact (@demo-a, and @demo-b in a group). the
contact gets a made-up name for that room only. the app reads a chat's network from the bridge
bot in `io.element.functional_members` (matrix-core/NOTES.md, "a chat's network"), so each room
names a bot there, for example @whatsappbot:ramimaalouf.com. no bridge is involved: the bot is
not a member, and nothing reaches a real network.

passwords come from the keychain (service multiplexer-test-account) and are never printed.
safe to run again: a room already made (found by its tag) is left as it is. every session the
script opens is signed out at the end. never use this for @rami.
"""
import subprocess
import sys
import time
import uuid

import requests

HOMESERVER = "https://matrix.ramimaalouf.com"
DOMAIN = "ramimaalouf.com"
SERVICE = "multiplexer-test-account"
TAG = "com.ramimaalouf.multiplexer.demo_tag"

# the demo user's id starts with @test, so a drive may send as it (the app's test-user rule,
# Matrix.swift `sendsReadReceipts`).
DEMO, FRIEND_A, FRIEND_B = (f"@{u}:{DOMAIN}" for u in ("test-demo", "demo-a", "demo-b"))

# (slug, network bot word, room name for a group or None, [(sender, text)], contact names)
# sender: "me" is the demo user, "a" is @demo-a, "b" is @demo-b. the first chat here ends up at the
# bottom of the inbox and the last one at the top.
CHATS = [
    ("chris", "discord", None, ["Chris Walker"], [
        ("a", "gg"), ("me", "one more?"), ("a", "tomorrow, I'm cooked")]),
    ("elena", "linkedin", None, ["Elena Petrova"], [
        ("a", "Thanks for connecting! Loved your talk on local-first apps."),
        ("me", "Thank you, glad it was useful"),
        ("a", "Would you be open to a quick call next week?")]),
    ("nadia", "instagram", None, ["Nadia Haddad"], [
        ("a", "where is this??"), ("me", "Lisbon, last summer"), ("a", "ok I'm going")]),
    ("leo", "messenger", None, ["Leo Martins"], [
        ("me", "found the board game you wanted"), ("a", "no way"), ("a", "are we still on for saturday?")]),
    ("sam", "telegram", None, ["Sam Okafor"], [
        ("me", "what time do you land?"), ("a", "flight lands at 6:40"), ("me", "I'll pick you up")]),
    ("hike", "whatsapp", "Weekend hike", ["Noah Fischer", "Ava Brooks"], [
        ("a", "trail opens at 8"), ("b", "I'll bring snacks"), ("me", "I'll drive"), ("b", "perfect, see you all there")]),
    ("priya", "signal", None, ["Priya Nair"], [
        ("a", "can you send me the doc before the call?"), ("me", "sending now"), ("a", "got it, thanks!")]),
    ("hannah", "whatsapp", None, ["Hannah Lee"], [
        ("a", "happy birthday!!"), ("me", "thank you!"), ("a", "dinner on me next week")]),
    ("jordan", "instagram", None, ["Jordan Reyes"], [
        ("me", "did you see the new cafe on 5th?"), ("a", "sent you the reel"), ("a", "you have to try it")]),
    ("maya", "whatsapp", None, ["Maya Chen"], [
        ("a", "are you coming tonight?"), ("me", "yes! what time?"), ("a", "7 at the usual place"),
        ("a", "bring the speaker")]),
]


def password(user: str) -> str:
    out = subprocess.run(["security", "find-generic-password", "-s", SERVICE, "-a", user, "-w"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"no keychain password for {user} (service {SERVICE})")
    return out.stdout.strip()


class Session:
    def __init__(self, user: str):
        self.user = user
        r = requests.post(f"{HOMESERVER}/_matrix/client/v3/login", timeout=30, json={
            "type": "m.login.password", "identifier": {"type": "m.id.user", "user": user},
            "password": password(user), "initial_device_display_name": "stage-demo"})
        if r.status_code != 200:
            sys.exit(f"login {user}: {r.status_code}")
        self.token = r.json()["access_token"]

    def call(self, method: str, path: str, **kwargs) -> dict:
        r = requests.request(method, f"{HOMESERVER}/_matrix/client/v3{path}", timeout=30,
                             headers={"Authorization": f"Bearer {self.token}"}, **kwargs)
        if r.status_code >= 400:
            sys.exit(f"{self.user} {method} {path.split('?')[0]}: {r.status_code} {r.text[:300]}")
        return r.json() if r.text else {}

    def send(self, room: str, text: str) -> None:
        self.call("PUT", f"/rooms/{room}/send/m.room.message/{uuid.uuid4().hex}",
                  json={"msgtype": "m.text", "body": text})

    def logout(self) -> None:
        requests.post(f"{HOMESERVER}/_matrix/client/v3/logout", timeout=30,
                      headers={"Authorization": f"Bearer {self.token}"})


def tagged_rooms(me: Session) -> dict[str, str]:
    found = {}
    for room in me.call("GET", "/joined_rooms")["joined_rooms"]:
        r = requests.get(f"{HOMESERVER}/_matrix/client/v3/rooms/{room}/state/{TAG}", timeout=30,
                         headers={"Authorization": f"Bearer {me.token}"})
        if r.status_code == 200 and r.json().get("slug"):
            found[r.json()["slug"]] = room
    return found


def stage(redo: list[str]) -> None:
    me, a, b = Session(DEMO), Session(FRIEND_A), Session(FRIEND_B)
    try:
        existing = tagged_rooms(me)
        for slug in redo:
            if (room := existing.pop(slug, None)) is not None:
                for s in (me, a, b):
                    requests.post(f"{HOMESERVER}/_matrix/client/v3/rooms/{room}/leave", timeout=30,
                                  headers={"Authorization": f"Bearer {s.token}"}, json={})
                    requests.post(f"{HOMESERVER}/_matrix/client/v3/rooms/{room}/forget", timeout=30,
                                  headers={"Authorization": f"Bearer {s.token}"}, json={})
                print(f"{slug}: left {room}, making it again")
        direct: dict[str, list[str]] = {}
        for slug, network, group_name, names, lines in CHATS:
            contacts = [a] if group_name is None else [a, b]
            if slug in existing:
                room = existing[slug]
                print(f"{slug}: already staged ({room})")
            else:
                body = {"preset": "trusted_private_chat" if group_name is None else "private_chat",
                        "invite": [c.user for c in contacts], "is_direct": group_name is None,
                        "initial_state": [
                            {"type": TAG, "state_key": "", "content": {"slug": slug}},
                            {"type": "io.element.functional_members", "state_key": "",
                             "content": {"service_members": [f"@{network}bot:{DOMAIN}"]}},
                        ]}
                if group_name:
                    body["name"] = group_name
                room = me.call("POST", "/createRoom", json=body)["room_id"]
                for contact, name in zip(contacts, names):
                    contact.call("POST", f"/rooms/{room}/join", json={})
                    contact.call("PUT", f"/rooms/{room}/state/m.room.member/{contact.user}",
                                 json={"membership": "join", "displayname": name})
                senders = {"me": me, "a": a, "b": b}
                for sender, text in lines:
                    senders[sender].send(room, text)
                    time.sleep(0.4)
                print(f"{slug}: staged as {network}, {len(lines)} messages ({room})")
                time.sleep(1.5)
            if group_name is None:
                direct.setdefault(FRIEND_A, []).append(room)
        # the inbox's one-to-one chats: the sdk reads m.direct.
        me.call("PUT", f"/user/{DEMO}/account_data/m.direct", json=direct)
    finally:
        for s in (me, a, b):
            s.logout()


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and (args[0] != "--redo" or len(args) < 2):
        sys.exit("usage: uv run scripts/stage-demo.py [--redo <slug>...]")
    stage(args[1:])
