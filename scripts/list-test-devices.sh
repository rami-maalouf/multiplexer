#!/usr/bin/env bash
# lists the practice account's devices (id, name, last seen), not counting the one this
# script signs in with and signs out again. the password comes from the mac's keychain.
# use it to check that tests and drives leave no devices behind.
set -euo pipefail
base="https://matrix-client.matrix.org/_matrix/client/v3"
pw="$(security find-generic-password -s multiplexer-test-account -a @rami-m-test:matrix.org -w)"
body="$(jq -n --arg pw "$pw" '{type:"m.login.password",identifier:{type:"m.id.user",user:"rami-m-test"},password:$pw,initial_device_display_name:"device list check"}')"
tok="$(curl -sf -X POST "$base/login" -H 'Content-Type: application/json' --data-binary @- <<<"$body" | jq -r .access_token)"
curl -sf "$base/devices" -H "Authorization: Bearer $tok" | jq -r '.devices[] | select(.display_name != "device list check") | "\(.device_id) \(.display_name // "") last seen \((.last_seen_ts // 0) / 1000 | todate)"' | sort
curl -sf -X POST "$base/logout" -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' -d '{}' >/dev/null
