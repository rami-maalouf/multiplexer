# A drive cannot tap a native swipe action by its id under real touches

**Status:** Open
**Systems:** agent driver, Apple host (swipe actions)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-05

## What happens

Under `--touch platform`, after a row's swipe opened UIKit's actions, `tap <action id>` is
refused: "tap #405 is a native swipe action: a finger swipes its row (`tap <row> drag
-<width> 0`; a full swipe performs the first trailing action), and without --touch platform
`tap` performs it". The message is clear, but a real tap on a shown action (not a full swipe)
has no form by id. The drive had to read the action's position off a screenshot and tap a point
in the row (`tap <row scroll> at 306 32`).

A second trap: `tap <row content> drag ... from x y` counts from the target, and the row's
content moves while the row is open, so a later drag started off the screen ("leaves the
viewport (402 × 874)"). Targeting the row's `scroll` node, which does not move, worked.

Cost: about 10 minutes and two drives.

## What would help

- Under real touches, `tap <action id>` taps where UIKit drew that action, when the row is open.
- The refusal naming the row's `scroll` as the stable target for `from x y`.

## Evidence

Seen on 2026-11-05 at exact2 `d0d66b107e` (the app's integration checkout), iOS Simulator (iOS 26.5).
