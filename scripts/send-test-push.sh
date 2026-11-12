#!/usr/bin/env bash
# sends one push to a device through APNs' sandbox, as our gateway (Sygnal, event_id_only) will:
# "New message" with mutable-content, the room and event ids, and the unread count. the
# notification extension then shows the chat, the sender and the text.
#
#   scripts/send-test-push.sh <device token in hex> [--room <room id> --event <event id>] [--unread <n>]
#   scripts/send-test-push.sh <device token in hex> --dry-run
#
# supply the token privately from an approved test account's pusher (base64 decoded to hex).
# normal builds do not log device tokens; never paste one into chat. an apple silicon simulator
# can receive real sandbox pushes too. the APNs key (P3.0) comes from the mac's keychain: the .p8 in base64
# (service multiplexer-apns, account key) and its key id (account key-id). it is never printed and
# never written to disk. --dry-run signs with a throwaway key instead, checks the signature, and
# prints the request without sending it.
set -euo pipefail

team="3V2UU7RRK9"
topic="com.ramimaalouf.multiplexer"
host="https://api.sandbox.push.apple.com"

token="${1:-}"; shift || true
room=""; event=""; unread=1; dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --room) room="$2"; shift 2 ;;
    --event) event="$2"; shift 2 ;;
    --unread) unread="$2"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ "$token" =~ ^[0-9a-fA-F]{64,200}$ ]] || { echo "usage: $0 <device token in hex> [--room <id> --event <id>] [--unread <n>] [--dry-run]" >&2; exit 2; }

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

if $dry; then
  key="$(openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null | openssl pkcs8 -topk8 -nocrypt)"
  key_id="DRYRUN0000"
else
  key="$(security find-generic-password -s multiplexer-apns -a key -w 2>/dev/null | openssl base64 -d -A)" \
    || { echo "no APNs key in the keychain (service multiplexer-apns, account key): P3.0" >&2; exit 1; }
  key_id="$(security find-generic-password -s multiplexer-apns -a key-id -w 2>/dev/null)" \
    || { echo "no APNs key id in the keychain (service multiplexer-apns, account key-id): P3.0" >&2; exit 1; }
fi

# the provider token: an ES256 JWT. openssl signs in DER; a JWT carries r and s, 32 bytes each.
header="$(printf '{"alg":"ES256","kid":"%s"}' "$key_id" | b64url)"
claims="$(printf '{"iss":"%s","iat":%d}' "$team" "$(date +%s)" | b64url)"
der_hex="$(printf '%s' "$header.$claims" | openssl dgst -sha256 -sign <(printf '%s\n' "$key") -binary | xxd -p | tr -d '\n')"
raw_hex="$(printf '%s' "$der_hex" | xxd -r -p | openssl asn1parse -inform DER 2>/dev/null \
  | awk -F: '/INTEGER/ {v=$NF; while (length(v) > 64 && substr(v,1,2) == "00") v = substr(v,3); while (length(v) < 64) v = "0" v; printf "%s", v}')"
[ "${#raw_hex}" -eq 128 ] || { echo "could not read the signature" >&2; exit 1; }
signature="$(printf '%s' "$raw_hex" | xxd -r -p | b64url)"
jwt="$header.$claims.$signature"

payload="$(jq -cn --arg room "$room" --arg event "$event" --argjson unread "$unread" \
  '{aps:{alert:{body:"New message"},"mutable-content":1}, unread_count:$unread}
   + (if $room != "" then {room_id:$room} else {} end) + (if $event != "" then {event_id:$event} else {} end)')"

if $dry; then
  # the signature checks against the throwaway key's public half, as APNs checks the real one.
  pub="$(openssl ec -pubout 2>/dev/null <<<"$key")"
  if printf '%s' "$header.$claims" | openssl dgst -sha256 -verify <(printf '%s\n' "$pub") -signature <(printf '%s' "$der_hex" | xxd -r -p) >/dev/null; then
    echo "dry run: the provider token is signed and checks ($(printf '%s' "$jwt" | wc -c | tr -d ' ') bytes, not shown)"
  else
    echo "dry run: the signature does not check" >&2; exit 1
  fi
  echo "POST $host/3/device/${token:0:8}... (HTTP/2)"
  echo "apns-topic: $topic"
  echo "apns-push-type: alert"
  echo "apns-priority: 10"
  echo "authorization: bearer <the provider token>"
  echo "$payload"
  exit 0
fi

status="$(curl -s --http2 -o /tmp/send-test-push-answer.json -w '%{http_code}' -X POST "$host/3/device/$token" \
  -H "apns-topic: $topic" -H "apns-push-type: alert" -H "apns-priority: 10" \
  -H "authorization: bearer $jwt" --data-binary "$payload")"
echo "APNs answered $status $(cat /tmp/send-test-push-answer.json 2>/dev/null)"
rm -f /tmp/send-test-push-answer.json
[ "$status" = "200" ]
