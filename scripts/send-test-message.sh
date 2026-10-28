#!/usr/bin/env bash
# sends one message to a test room from a short-lived device of a test user: it signs in
# with the password from the mac's keychain (service multiplexer-test-account) and signs out
# after. use it to see a message arrive in the app while a drive has it open. it sends only
# as a test user, never as @rami (AGENTS.md, the safety rule).
#   send-test-message.sh "<text>"
#   send-test-message.sh --image <photo.jpg> ["<caption>"]
#   SENDER=@test2:ramimaalouf.com ROOM="Multiplexer two-person test" (the defaults)
set -euo pipefail
usage="usage: send-test-message.sh <text> | --image <file> [caption]"
image=""; caption=""
if [ "${1:-}" = "--image" ]; then
  image="${2:?$usage}"; caption="${3:-}"
else
  text="${1:?$usage}"
fi
sender="${SENDER:-@test2:ramimaalouf.com}"
roomname="${ROOM:-Multiplexer two-person test}"
case "$sender" in @rami:*) echo "refused: tests never send as $sender" >&2; exit 1;; esac
server="${sender#*:}"
localpart="${sender%%:*}"; localpart="${localpart#@}"
base="$(curl -sfL "https://$server/.well-known/matrix/client" | jq -r '."m.homeserver".base_url' | sed 's|/*$||')/_matrix"
pw="$(security find-generic-password -s multiplexer-test-account -a "$sender" -w)"
login="$(jq -n --arg pw "$pw" --arg user "$localpart" '{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw,initial_device_display_name:"test message sender"}')"
tok="$(curl -sf -X POST "$base/client/v3/login" -H 'Content-Type: application/json' --data-binary @- <<<"$login" | jq -r .access_token)"
auth="Authorization: Bearer $tok"
trap 'curl -sf -X POST "$base/client/v3/logout" -H "$auth" -H "Content-Type: application/json" -d "{}" >/dev/null' EXIT

room=""
for id in $(curl -sf "$base/client/v3/joined_rooms" -H "$auth" | jq -r '.joined_rooms[]'); do
  enc="$(jq -rn --arg r "$id" '$r|@uri')"
  name="$(curl -s "$base/client/v3/rooms/$enc/state/m.room.name" -H "$auth" | jq -r '.name // empty')"
  if [ "$name" = "$roomname" ]; then room="$enc"; break; fi
done
[ -n "$room" ] || { echo "$sender is in no room named $roomname" >&2; exit 1; }

if [ -n "$image" ]; then
  file="$(basename "$image")"
  mime="image/jpeg"; case "$file" in *.png) mime="image/png";; esac
  w="$(sips -g pixelWidth "$image" | awk '/pixelWidth/{print $2}')"
  h="$(sips -g pixelHeight "$image" | awk '/pixelHeight/{print $2}')"
  size="$(stat -f %z "$image")"
  uri="$(curl -sf -X POST "$base/media/v3/upload?filename=$file" -H "$auth" -H "Content-Type: $mime" \
    --data-binary @"$image" | jq -r .content_uri)"
  # a caption goes in body, with the file name in filename (the spec's media captions).
  body="$(jq -n --arg uri "$uri" --arg file "$file" --arg caption "$caption" --arg mime "$mime" \
    --argjson w "$w" --argjson h "$h" --argjson size "$size" \
    '{msgtype:"m.image",url:$uri,body:(if $caption == "" then $file else $caption end),info:{w:$w,h:$h,mimetype:$mime,size:$size}}
     + (if $caption == "" then {} else {filename:$file} end)')"
else
  body="$(jq -n --arg t "$text" '{msgtype:"m.text",body:$t}')"
fi
curl -sf -X PUT "$base/client/v3/rooms/$room/send/m.room.message/multiplexer-$(uuidgen)" -H "$auth" \
  -H 'Content-Type: application/json' --data-binary @- <<<"$body" | jq -r '"sent " + .event_id'
