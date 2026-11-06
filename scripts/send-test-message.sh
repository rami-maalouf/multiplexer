#!/usr/bin/env bash
# sends one message to a test room from a short-lived device of a test user: it signs in
# with the password from the mac's keychain (service multiplexer-test-account) and signs out
# after. use it to see a message arrive in the app while a drive has it open. it sends only
# as a test user, never as @rami (AGENTS.md, the safety rule).
#   send-test-message.sh "<text>"
#   send-test-message.sh --image <photo.jpg> ["<caption>"]
#   send-test-message.sh --video <clip.mp4> ["<caption>"]: with its size, length and a poster (ffmpeg)
#   send-test-message.sh --sticker <picture.png>: an m.sticker event
#   send-test-message.sh --voice <sound file>: a voice note as the whatsapp bridge brings one (ffmpeg):
#   ogg opus, its length, a waveform of 64 values from 0 to 100, and the voice mark
#   send-test-message.sh --delete-last: deletes the sender's newest message in the room for everyone
#   send-test-message.sh --read: the sender reads the room: a read receipt on its newest message
#   SENDER=@test2:ramimaalouf.com ROOM="Multiplexer two-person test" (the defaults)
#   REPLY_TO=<event id> or REPLY_TO=first: the text answers that message, or the room's first
#   text message (older than what a chat loads when it opens)
#   MENTION=<user id>: the text mentions that user, as a client's pill does (m.mentions)
set -euo pipefail
usage="usage: send-test-message.sh <text> | --image <file> [caption] | --video <file> [caption] | --sticker <file> | --voice <file> | --delete-last | --read"
image=""; video=""; sticker=""; voice=""; caption=""; deletelast=""; readlast=""
if [ "${1:-}" = "--read" ]; then
  readlast=1
elif [ "${1:-}" = "--delete-last" ]; then
  deletelast=1
elif [ "${1:-}" = "--image" ]; then
  image="${2:?$usage}"; caption="${3:-}"
elif [ "${1:-}" = "--video" ]; then
  video="${2:?$usage}"; caption="${3:-}"
elif [ "${1:-}" = "--sticker" ]; then
  sticker="${2:?$usage}"
elif [ "${1:-}" = "--voice" ]; then
  voice="${2:?$usage}"
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

if [ -n "$readlast" ]; then
  newest="$(curl -sf "$base/client/v3/rooms/$room/messages?dir=b&limit=20" -H "$auth" \
    | jq -r '[.chunk[] | select(.type == "m.room.message" or .type == "m.sticker")][0].event_id // empty')"
  [ -n "$newest" ] || { echo "no message to read in $roomname" >&2; exit 1; }
  newenc="$(jq -rn --arg r "$newest" '$r|@uri')"
  curl -sf -X POST "$base/client/v3/rooms/$room/receipt/m.read/$newenc" -H "$auth" -H 'Content-Type: application/json' -d '{}' >/dev/null
  echo "read $newest as $sender"
  exit 0
fi

if [ -n "$deletelast" ]; then
  last="$(curl -sf "$base/client/v3/rooms/$room/messages?dir=b&limit=50" -H "$auth" \
    | jq -r --arg me "$sender" '[.chunk[] | select(.sender == $me and (.type == "m.room.message" or .type == "m.sticker") and (.content | length) > 0)][0].event_id // empty')"
  [ -n "$last" ] || { echo "$sender has no message to delete in the last 50 events of $roomname" >&2; exit 1; }
  lastenc="$(jq -rn --arg r "$last" '$r|@uri')"
  curl -sf -X PUT "$base/client/v3/rooms/$room/redact/$lastenc/multiplexer-$(uuidgen)" -H "$auth" \
    -H 'Content-Type: application/json' -d '{}' | jq -r '"deleted '"$last"' with " + .event_id'
  exit 0
fi

eventtype="m.room.message"
if [ -n "$video" ]; then
  file="$(basename "$video")"
  w="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video")"
  h="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video")"
  ms="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video" | awk '{printf "%d", $1 * 1000}')"
  size="$(stat -f %z "$video")"
  # the poster: the frame at one second, at most 640 points wide, as a client makes one.
  poster="$(mktemp -t poster).jpg"
  ffmpeg -loglevel error -y -ss 1 -i "$video" -frames:v 1 -vf "scale='min(640,iw)':-2" "$poster"
  pw="$(sips -g pixelWidth "$poster" | awk '/pixelWidth/{print $2}')"
  ph="$(sips -g pixelHeight "$poster" | awk '/pixelHeight/{print $2}')"
  psize="$(stat -f %z "$poster")"
  uri="$(curl -sf -X POST "$base/media/v3/upload?filename=$file" -H "$auth" -H "Content-Type: video/mp4" \
    --data-binary @"$video" | jq -r .content_uri)"
  puri="$(curl -sf -X POST "$base/media/v3/upload?filename=poster.jpg" -H "$auth" -H "Content-Type: image/jpeg" \
    --data-binary @"$poster" | jq -r .content_uri)"
  rm -f "$poster"
  body="$(jq -n --arg uri "$uri" --arg puri "$puri" --arg file "$file" --arg caption "$caption" \
    --argjson w "$w" --argjson h "$h" --argjson ms "$ms" --argjson size "$size" \
    --argjson pw "$pw" --argjson ph "$ph" --argjson psize "$psize" \
    '{msgtype:"m.video",url:$uri,body:(if $caption == "" then $file else $caption end),
      info:{w:$w,h:$h,duration:$ms,mimetype:"video/mp4",size:$size,thumbnail_url:$puri,
            thumbnail_info:{w:$pw,h:$ph,mimetype:"image/jpeg",size:$psize}}}
     + (if $caption == "" then {} else {filename:$file} end)')"
elif [ -n "$sticker" ]; then
  eventtype="m.sticker"
  file="$(basename "$sticker")"
  w="$(sips -g pixelWidth "$sticker" | awk '/pixelWidth/{print $2}')"
  h="$(sips -g pixelHeight "$sticker" | awk '/pixelHeight/{print $2}')"
  size="$(stat -f %z "$sticker")"
  uri="$(curl -sf -X POST "$base/media/v3/upload?filename=$file" -H "$auth" -H "Content-Type: image/png" \
    --data-binary @"$sticker" | jq -r .content_uri)"
  body="$(jq -n --arg uri "$uri" --argjson w "$w" --argjson h "$h" --argjson size "$size" \
    '{body:"Sticker",url:$uri,info:{w:$w,h:$h,mimetype:"image/png",size:$size}}')"
elif [ -n "$voice" ]; then
  ogg="$(mktemp -t voice).ogg"
  ffmpeg -loglevel error -y -i "$voice" -ac 1 -ar 48000 -c:a libopus -b:a 32k "$ogg"
  ms="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$ogg" | awk '{printf "%d", $1 * 1000}')"
  size="$(stat -f %z "$ogg")"
  # the loudness of each of 64 parts, the loudest 100, as whatsapp's own waveform.
  waveform="$(ffmpeg -loglevel error -i "$voice" -ac 1 -ar 8000 -f s16le - | python3 -I -c '
import math, struct, sys
data = sys.stdin.buffer.read()
s = struct.unpack("<%dh" % (len(data) // 2), data[: len(data) // 2 * 2]) or (0,)
parts = [s[i * len(s) // 64:(i + 1) * len(s) // 64] or (0,) for i in range(64)]
rms = [math.sqrt(sum(x * x for x in p) / len(p)) for p in parts]
print("[" + ",".join(str(round(r / (max(rms) or 1) * 100)) for r in rms) + "]")')"
  uri="$(curl -sf -X POST "$base/media/v3/upload?filename=Voice%20message.ogg" -H "$auth" -H "Content-Type: audio/ogg" \
    --data-binary @"$ogg" | jq -r .content_uri)"
  rm -f "$ogg"
  body="$(jq -n --arg uri "$uri" --argjson ms "$ms" --argjson size "$size" --argjson waveform "$waveform" \
    '{msgtype:"m.audio",body:"Voice message.ogg",filename:"Voice message.ogg",url:$uri,
      info:{mimetype:"audio/ogg; codecs=opus",size:$size,duration:$ms},
      "org.matrix.msc1767.audio":{duration:$ms,waveform:$waveform},"org.matrix.msc3245.voice":{}}')"
elif [ -n "$image" ]; then
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
  replyto="${REPLY_TO:-}"
  if [ "$replyto" = "first" ]; then
    replyto="$(curl -sf "$base/client/v3/rooms/$room/messages?dir=f&limit=100" -H "$auth" \
      | jq -r '[.chunk[] | select(.type == "m.room.message" and .content.msgtype == "m.text")][0].event_id // empty')"
    [ -n "$replyto" ] || { echo "no text message at the start of $roomname" >&2; exit 1; }
  fi
  if [ -n "$replyto" ]; then
    body="$(jq --arg id "$replyto" '. + {"m.relates_to":{"m.in_reply_to":{event_id:$id}}}' <<<"$body")"
  fi
  if [ -n "${MENTION:-}" ]; then
    body="$(jq --arg u "$MENTION" '. + {"m.mentions":{user_ids:[$u]}}' <<<"$body")"
  fi
fi
curl -sf -X PUT "$base/client/v3/rooms/$room/send/$eventtype/multiplexer-$(uuidgen)" -H "$auth" \
  -H 'Content-Type: application/json' --data-binary @- <<<"$body" | jq -r '"sent " + .event_id'
