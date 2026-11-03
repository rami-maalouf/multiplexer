# check calls a view covered when its bar only lets touches through

**Status:** Open
**Systems:** check, agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat screen draws its own top bar over the transcript. The bar's root is
`position="absolute"` with `pointer-events="none"`, so a touch between its buttons reaches the
transcript under it; its buttons say `pointer-events="auto"`. In the middle of the bar, the
chat's picture (initials in a circle) sits over a glass capsule with the name. The bar is drawn
after the transcript, and the picture has `z-index=1`: on screen nothing covers it.

`check` said:

```
covered  Text "<initials>"#334 [195,74 27×21]: its middle is under View#408 at rest, and nothing
scrolls it clear; start the content below what covers it (padding or a divider), or let the
bar take its place
```

View#408 was a transcript row under the bar. `check` judged cover by a hit test at the text's
middle, and the hit test passes through `pointer-events: none` to the row below. With
`pointer-events="auto"` on the bar's title, the finding went away; nothing else changed.

Cost: about 5 minutes, and a drive to find what View#408 was.

## What would help

- `check` judging cover by drawing order (what is painted over the middle), not by where a
  touch lands; or
- the finding saying why: "under View#408 for touches: an ancestor has
  `pointer-events: none`".

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5). Related: exact2's
`QUEUE.md`, "`check` finds the grouped-form recipe's Quantity row covered on iOS" (the same
hit-test rule, with a field's box over its label).
