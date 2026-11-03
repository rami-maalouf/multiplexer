# a drive cannot fire swiperight, and a real touch misses a link row

**Status:** Open
**Systems:** agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-31

## What happens

A chat bubble has `swiperight=startReply(...)`. To check it in a drive:

1. `tap bubble-15 swiperight` is refused: `unknown word "swiperight"`. No doc and no sample
   test shows how to fire `swiperight` (the sample chat app has the handler and no test of it).
2. `tap bubble-15 drag 160 0` explained itself well: "a gesture only a real touch makes ...
   drive with --touch platform".
3. Under `--touch platform`, the drive's first step, a tap on a chat-list row that is a
   `link`, failed: "the touch landed on node #53, not on node #20 the aim hit-tested". A tap
   on the row's preview text (`tap room-preview-<id>`) worked, and then the drag fired the swipe.

Cost: about 10 minutes.

## What would help

A `swipe right` step in drives and tests, or one line in the testing guide on driving
`swiperight`; and a real touch on a `link` row landing on the row.

## Evidence

Seen on 2026-10-31 at exact2 `1bc4c36cb7` (iOS simulator). Related: `issues/20261022-no-swipeleft.md`.

## Seen again at `1bc4c36cb7` (2026-11-02)

Under `--touch platform`, `tap room-preview-<id>` (the workaround above) missed too: "the
touch landed on node #25, not on node #32 the aim hit-tested". A tap on the row's picture
(`tap avatar-<id>`, a `view` in the same `link` row) worked. So which part of a `link` row a
real touch reaches changes from one run to the next.

## More evidence (2026-11-03, `ed43ad09a0`)

The link row's miss is still there: under `--touch platform`, `tap room-<id>` on a chat-list
`link` row failed with "the touch landed on node #210, not on node #208 the aim hit-tested".
`type root /room/<id>` (the root's `navigate`) opened the screen instead. About 2 minutes.
