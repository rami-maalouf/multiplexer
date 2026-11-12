# A scroller whose keyboard inset changes without moving its offset sends no scroll event

**Status:** Open
**Systems:** host/apple, ios scroll, events
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

After a drag lowered the keyboard, a chat's "jump to the newest" button stayed up while the newest message was in view. The host sends a `scroll` event only when the offset or the top inset changes, but its `clientHeight` leaves out the keyboard's inset. The inset went away without the offset moving, so the app kept the last event's smaller port and read its end as far away.

Cost: about 25 minutes. I found it by copying the event's numbers into a debug state and reading it in a drive.

## What would help

- The event compared whole, and a scroller whose insets change queues one. Done locally in exact2 `91d7b12620`.
- A drive op that shows the last `scroll` event a scroller sent.

## Evidence

Seen on 2026-11-07 at exact2 `4a187c1bbe`, iOS Simulator. Fixed at `91d7b12620`.
