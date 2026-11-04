#!/usr/bin/env bash
# lists a test user's pushers on our server (app id, the pushkey's start, the gateway, the format,
# the device name), to check what the app set (P3.4). it signs in with a short-lived device and
# signs it out again; pushers belong to the account, so that device's own absence changes nothing.
#   scripts/list-pushers.sh [@test1:ramimaalouf.com]
# the password comes from the mac's keychain; it refuses any account but a test user.
set -euo pipefail
user="${1:-@test1:ramimaalouf.com}"
case "$user" in @test*) ;; *) echo "only a test user (@test...): $user" >&2; exit 2 ;; esac
server="${user#*:}"
base="https://matrix.$server/_matrix/client/v3"
pw="$(security find-generic-password -s multiplexer-test-account -a "$user" -w)"
local_part="${user%%:*}"; local_part="${local_part#@}"
body="$(jq -n --arg pw "$pw" --arg user "$local_part" '{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw,initial_device_display_name:"pusher list check"}')"
tok="$(curl -sf -X POST "$base/login" -H 'Content-Type: application/json' --data-binary @- <<<"$body" | jq -r .access_token)"
trap 'curl -sf -X POST "$base/logout" -H "Authorization: Bearer $tok" -H "Content-Type: application/json" -d "{}" >/dev/null' EXIT
pushers="$(curl -sf "$base/pushers" -H "Authorization: Bearer $tok")"
echo "$pushers" | jq -r '.pushers | "\(length) pusher(s)"'
echo "$pushers" | jq -r '.pushers[] | "\(.app_id) \(.pushkey[0:12])... \(.data.url) format=\(.data.format // "full") device=\(.device_display_name) payload=\(.data.default_payload | tojson)"'
