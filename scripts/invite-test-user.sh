#!/usr/bin/env bash
# a test user invites another to a test room, from a short-lived device (the password from the
# mac's keychain, service multiplexer-test-account; signed out after), so a drive can see a
# request (L3) arrive. it makes the room the first time, and takes out an invitee who accepted
# an earlier invite, so it can invite them again. never as @rami, and never invites @rami
# (AGENTS.md, the safety rule).
#   invite-test-user.sh            @test2 invites @test1 to "Multiplexer request drive"
#   SENDER=@test2:ramimaalouf.com INVITEE=@test1:ramimaalouf.com ROOM="Multiplexer request drive" (the defaults)
set -euo pipefail
sender="${SENDER:-@test2:ramimaalouf.com}"
invitee="${INVITEE:-@test1:ramimaalouf.com}"
roomname="${ROOM:-Multiplexer request drive}"
case "$sender $invitee" in *@rami:*) echo "refused: tests never use @rami" >&2; exit 1;; esac
server="${sender#*:}"
localpart="${sender%%:*}"; localpart="${localpart#@}"
base="$(curl -sfL "https://$server/.well-known/matrix/client" | jq -r '."m.homeserver".base_url' | sed 's|/*$||')/_matrix"
pw="$(security find-generic-password -s multiplexer-test-account -a "$sender" -w)"
login="$(jq -n --arg pw "$pw" --arg user "$localpart" '{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw,initial_device_display_name:"test invite sender"}')"
tok="$(curl -sf -X POST "$base/client/v3/login" -H 'Content-Type: application/json' --data-binary @- <<<"$login" | jq -r .access_token)"
auth="Authorization: Bearer $tok"
trap 'curl -sf -X POST "$base/client/v3/logout" -H "$auth" -H "Content-Type: application/json" -d "{}" >/dev/null' EXIT

room=""
for id in $(curl -sf "$base/client/v3/joined_rooms" -H "$auth" | jq -r '.joined_rooms[]'); do
  enc="$(jq -rn --arg r "$id" '$r|@uri')"
  name="$(curl -s "$base/client/v3/rooms/$enc/state/m.room.name" -H "$auth" | jq -r '.name // empty')"
  if [ "$name" = "$roomname" ]; then room="$enc"; break; fi
done
if [ -z "$room" ]; then
  id="$(jq -n --arg name "$roomname" '{name:$name,preset:"private_chat"}' \
    | curl -sf -X POST "$base/client/v3/createRoom" -H "$auth" -H 'Content-Type: application/json' --data-binary @- | jq -r .room_id)"
  room="$(jq -rn --arg r "$id" '$r|@uri')"
  echo "made $roomname ($id)"
fi
# an invitee who accepted before is in the room: the room's owner removes them first.
uenc="$(jq -rn --arg u "$invitee" '$u|@uri')"
if [ "$(curl -s "$base/client/v3/rooms/$room/state/m.room.member/$uenc" -H "$auth" | jq -r '.membership // empty')" = "join" ]; then
  jq -n --arg u "$invitee" '{user_id:$u,reason:"the test invites again"}' \
    | curl -sf -X POST "$base/client/v3/rooms/$room/kick" -H "$auth" -H 'Content-Type: application/json' --data-binary @- >/dev/null
fi
jq -n --arg u "$invitee" '{user_id:$u}' \
  | curl -s -X POST "$base/client/v3/rooms/$room/invite" -H "$auth" -H 'Content-Type: application/json' --data-binary @- \
  | jq -c --arg u "$invitee" --arg r "$roomname" 'if .errcode then "not invited: " + .error else "invited " + $u + " to " + $r end'
