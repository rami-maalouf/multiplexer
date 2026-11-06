#!/usr/bin/env bash
# lists the test users' devices on our own server and deletes the ones nobody uses any more: those
# last seen longer ago than the given age, or never seen. a dry run by default: it only lists.
# it signs in as each test user with the password from the mac's keychain (service
# multiplexer-test-account), deletes through the client api (the password answers its check), and
# signs its own device out at the end. it works only on @test1 and @test2, never on @rami.
#   clean-test-devices.sh [--delete] [--older-than <hours>]   (default 24 hours)
#   USERS="@test1:ramimaalouf.com" clean-test-devices.sh      (default both test users)
set -euo pipefail
usage="usage: clean-test-devices.sh [--delete] [--older-than <hours>]"
delete=""; hours=24
while [ $# -gt 0 ]; do
  case "$1" in
    --delete) delete=1; shift;;
    --older-than) hours="${2:?$usage}"; shift 2;;
    *) echo "$usage" >&2; exit 2;;
  esac
done
case "$hours" in ''|*[!0-9]*) echo "$usage: hours is a whole number" >&2; exit 2;; esac
users="${USERS:-@test1:ramimaalouf.com @test2:ramimaalouf.com}"
cutoff=$(( ($(date +%s) - hours * 3600) * 1000 ))

for user in $users; do
  case "$user" in
    @test1:ramimaalouf.com|@test2:ramimaalouf.com) ;;
    *) echo "refused: $user is not a test user" >&2; exit 1;;
  esac
  server="${user#*:}"; localpart="${user%%:*}"; localpart="${localpart#@}"
  base="$(curl -sfL "https://$server/.well-known/matrix/client" | jq -r '."m.homeserver".base_url' | sed 's|/*$||')/_matrix"
  pw="$(security find-generic-password -s multiplexer-test-account -a "$user" -w)"
  login="$(jq -n --arg pw "$pw" --arg user "$localpart" '{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw,initial_device_display_name:"test device cleaner"}')"
  reply="$(curl -sf -X POST "$base/client/v3/login" -H 'Content-Type: application/json' --data-binary @- <<<"$login")"
  tok="$(jq -r .access_token <<<"$reply")"; mine="$(jq -r .device_id <<<"$reply")"
  auth="Authorization: Bearer $tok"
  # this script's own device is left out: it signs out at the end.
  devices="$(curl -sf "$base/client/v3/devices" -H "$auth" | jq -c --arg mine "$mine" '[.devices[] | select(.device_id != $mine)]')"
  old="$(jq -c --argjson cut "$cutoff" '[.[] | select((.last_seen_ts // 0) < $cut)]' <<<"$devices")"
  echo "$user: $(jq length <<<"$devices") devices besides this one; $(jq length <<<"$old") last seen more than $hours h ago"
  jq -r '.[] | "  \(.device_id)  \(.display_name // "-")  last seen \(if .last_seen_ts then (.last_seen_ts / 1000 | floor | todate) else "never" end)"' <<<"$old"
  if [ -n "$delete" ] && [ "$(jq length <<<"$old")" -gt 0 ]; then
    ids="$(jq -c '[.[].device_id]' <<<"$old")"
    body="$(jq -n --argjson ids "$ids" --arg pw "$pw" --arg user "$localpart" '{devices:$ids,auth:{type:"m.login.password",identifier:{type:"m.id.user",user:$user},password:$pw}}')"
    if curl -sf -X POST "$base/client/v3/delete_devices" -H "$auth" -H 'Content-Type: application/json' --data-binary @- <<<"$body" >/dev/null; then
      echo "  deleted $(jq length <<<"$old")"
    else
      echo "  the server refused the deletion" >&2
    fi
  fi
  curl -sf -X POST "$base/client/v3/logout" -H "$auth" -H 'Content-Type: application/json' -d '{}' >/dev/null || true
  unset pw
done
[ -n "$delete" ] || echo "dry run: nothing deleted (--delete deletes the devices listed)"
