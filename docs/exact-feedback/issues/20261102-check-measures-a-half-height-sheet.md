# check measures a half-height sheet's rows at their drawn size and does not say why

**Status:** Open
**Systems:** agent (check), Apple host (sheets)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A route is a sheet with two heights (`navigationPresentation="modal"`,
`navigationDetent="medium large"`). Its rows are buttons with `min-height=44` and
`box-sizing="border-box"`. At the half height, `check` reports each row:

```
target   inboxes-inbox [18,428 367×42]: 367×42 pt, under the 44×44 minimum; make its box at least 44×44 (padding, or `min-height`/`min-width`)
```

The box is 44 points as authored. On iOS 26, UIKit draws a sheet that rests below `large`
at 0.96 of its laid-out size, so the drawn row is 42 points. `layout` says so ("route 1 is a
sheet the platform draws at 0.96 of its laid-out size"), and `agent-pitfalls.md` says to
leave that scale alone. The `check` finding says neither, and its fix ("make its box at
least 44×44") is what the app already wrote.

What I did: rows of 46 points, which UIKit draws at 44.

Cost: about 3 minutes, with a `layout` call to find the cause.

## What would help

- The target finding saying the scale and the size that passes: "drawn at 0.96 in a sheet
  below `large`: an authored 46 reaches 44". (A message fix.)
- A decision on what `check` should measure in a scaled sheet. UIKit's own sheets scale
  their 44-point rows the same way, so the authored size may be the fairer measure. (A
  design question.)

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), light and dark.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1368 (fixes the message): an iOS `check` with a target finding adds a note for each sheet drawn scaled, with the authored size drawn at 44 ("authored at 46 pt is drawn at 44"). What `check` should measure in a scaled sheet stays a design question.
