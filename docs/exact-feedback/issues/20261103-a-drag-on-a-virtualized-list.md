# A drag on a virtualized list in a half-height sheet aims under the row after the list

**Status:** Open
**Systems:** agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

In a half-height sheet (`navigationDetent="medium large"`), a column holds a `list virtualized=true`
(a grid of rows) and a row of tabs under it. `tap <list> drag 0 -400` (to pull the sheet up) was
refused: "drag #… at (201.0, 855.28): node #… covers its middle", the node being the tab row.
`layout <list>` in the same drive put the list on screen at y 522 to 782 (its middle at about
652), and the sheet is drawn at 0.96 of its laid-out size. The agent aimed below the list, under
the row that follows it.

A drag that starts on a button inside the list is refused without `--touch platform` ("starts on
nothing the agent scrolls"); with `--touch platform` it pulled the sheet up as a finger does.

Cost: about 6 minutes and three drives.

## What would help

Aiming a drag at the visible part of the list's frame (its laid-out frame scaled as the sheet
is drawn), or the refusal naming the point it used and the list's frame.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
