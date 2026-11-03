# A real-touch tap at a point does not scroll, and a tap that opened nothing still says tapped

**Status:** Open
**Systems:** agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

At the largest text size, under `agent ios --touch platform`, a list row lay below the screen.

1. `tap avatar-<id> at 22 6` (a point inside a picture in a `link` row, which worked at the
   normal size) refused with "a press at is outside the viewport": the point is missing from
   the sentence, and a tap at a point does not scroll its target into view first, as a plain
   tap does.
2. A plain `tap avatar-<id>` then printed "tapped", but no route opened: the list had scrolled
   to other rows, and the touch's mark was on another row's picture.
3. `tap room-<id>` (the `link` itself) printed "tapped" and opened nothing right after a launch;
   with `clock +1000 real` before it, it opened the route every time.

Cost about 8 minutes and five drives.

## What would help

The refusal naming the point and saying to scroll first (or a tap at a point scrolling too),
and a tap that printed "tapped" while nothing happened saying so (the drive can see that the
route did not change).

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, on an iOS 27.0 simulator. Related: finding 26
(a real touch on a `link` row misses).

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1340 (fixes part of it): a tap at a point scrolls its view in before it refuses the point, and the refusal names where the point lands. "tapped" for a tap that opened nothing is a design question.
