#!/usr/bin/env bash
# archives a chat, or brings it back, from a short-lived device of a test user, as another
# device of the account would: it changes the account data the app keeps its archived chats in
# (com.ramimaalouf.multiplexer.chats, ChatActions.swift). use it to see another device's archive
# reach the app while a drive shows the list. it acts only as a test user, never as @rami.
#   mark-chat-as-test-user.sh archive|unarchive ["<room name>"]
#   ACCOUNT=@test1:ramimaalouf.com ROOM="Multiplexer two-person test" (the defaults)
set -euo pipefail
action="${1:?usage: mark-chat-as-test-user.sh archive|unarchive [room name]}"
case "$action" in archive|unarchive) ;; *) echo "usage: mark-chat-as-test-user.sh archive|unarchive [room name]" >&2; exit 1;; esac
account="${ACCOUNT:-@test1:ramimaalouf.com}"
roomname="${2:-${ROOM:-Multiplexer two-person test}}"
case "$account" in @rami:*) echo "refused: tests never act as $account" >&2; exit 1;; esac
server="${account#*:}"
localpart="${account%%:*}"; localpart="${localpart#@}"
base="$(curl -sfL "https://$server/.well-known/matrix/client" | jq -r '."m.homeserver".base_url' | sed 's|/*$||')/_matrix"
pw="$(security find-generic-password -s multiplexer-test-account -a "$account" -w)"
login="$(jq -n --arg pw "$pw" --arg user "$localpart" '{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw,initial_device_display_name:"test chat marker"}')"
session="$(curl -sf -X POST "$base/client/v3/login" -H 'Content-Type: application/json' --data-binary @- <<<"$login")"
tok="$(jq -r .access_token <<<"$session")"
auth="Authorization: Bearer $tok"
trap 'curl -sf -X POST "$base/client/v3/logout" -H "$auth" -H "Content-Type: application/json" -d "{}" >/dev/null' EXIT

room=""
for id in $(curl -sf "$base/client/v3/joined_rooms" -H "$auth" | jq -r '.joined_rooms[]'); do
  enc="$(jq -rn --arg r "$id" '$r|@uri')"
  name="$(curl -s "$base/client/v3/rooms/$enc/state/m.room.name" -H "$auth" | jq -r '.name // empty')"
  if [ "$name" = "$roomname" ]; then room="$id"; break; fi
done
[ -n "$room" ] || { echo "$account is in no room named $roomname" >&2; exit 1; }

user="$(jq -rn --arg u "$account" '$u|@uri')"
url="$base/client/v3/user/$user/account_data/com.ramimaalouf.multiplexer.chats"
marks="$(curl -s "$url" -H "$auth")"
jq -e 'has("errcode")' <<<"$marks" >/dev/null && marks="{}"
# archived until a newer message: the time is now, so the chat's newest message is older.
now="$(($(date +%s) * 1000))"
if [ "$action" = "archive" ]; then
  marks="$(jq --arg r "$room" --argjson ts "$now" '.archived = ((.archived // {}) + {($r): {ts: $ts}})' <<<"$marks")"
else
  marks="$(jq --arg r "$room" '.archived = ((.archived // {}) | del(.[$r]))' <<<"$marks")"
fi
curl -sf -X PUT "$url" -H "$auth" -H 'Content-Type: application/json' --data-binary @- <<<"$marks" >/dev/null
echo "${action}d $roomname ($room) as $account"
