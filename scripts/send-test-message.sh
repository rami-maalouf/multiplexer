#!/usr/bin/env bash
# sends one text message to the practice account's room "Multiplexer test" from a
# short-lived device: it signs in with the password from the mac's keychain and signs
# out after. use it to see a message arrive in the app while a drive has it open.
set -euo pipefail
text="${1:?usage: send-test-message.sh <text>}"
base="https://matrix-client.matrix.org/_matrix/client/v3"
pw="$(security find-generic-password -s multiplexer-test-account -a @rami-m-test:matrix.org -w)"
login="$(jq -n --arg pw "$pw" '{type:"m.login.password",identifier:{type:"m.id.user",user:"rami-m-test"},password:$pw,initial_device_display_name:"test message sender"}')"
tok="$(curl -sf -X POST "$base/login" -H 'Content-Type: application/json' --data-binary @- <<<"$login" | jq -r .access_token)"
auth="Authorization: Bearer $tok"
trap 'curl -sf -X POST "$base/logout" -H "$auth" -H "Content-Type: application/json" -d "{}" >/dev/null' EXIT

room=""
for id in $(curl -sf "$base/joined_rooms" -H "$auth" | jq -r '.joined_rooms[]'); do
  enc="$(jq -rn --arg r "$id" '$r|@uri')"
  name="$(curl -s "$base/rooms/$enc/state/m.room.name" -H "$auth" | jq -r '.name // empty')"
  if [ "$name" = "Multiplexer test" ]; then room="$enc"; break; fi
done
[ -n "$room" ] || { echo "no room named Multiplexer test" >&2; exit 1; }

body="$(jq -n --arg t "$text" '{msgtype:"m.text",body:$t}')"
curl -sf -X PUT "$base/rooms/$room/send/m.room.message/multiplexer-$(uuidgen)" -H "$auth" \
  -H 'Content-Type: application/json' --data-binary @- <<<"$body" | jq -r '"sent " + .event_id'
