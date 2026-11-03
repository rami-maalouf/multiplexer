# check flags rows that scroll under an app-drawn floating bar as overlaps

**Status:** Open
**Systems:** check, verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An app draws two floating glass bars of its own, as iOS 26 apps do: a bottom bar over a chat
list (a filter button, a capsule, a search slot), and a top bar over a chat's transcript (Back,
a picture over a name, a "..." menu). Content scrolls under both by design; under the top bar a
gradient fades it out, as iOS's scroll edge effect does under a system bar.

At rest, a long transcript has rows under the top bar, and `check` reports each as an overlap:

```
overlap  back [16,62 58×44]: overlaps Text "<a sender's name>"#405 by 12×15; give them room (a gap, or let the row wrap)
overlap  Text "Will do tonight"#417 [62,107 110×20]: overlaps chat-name by 40.6×19; give them room ...
```

The same happened with the bottom bar over a long chat list. A system navigation bar or tab
bar over the same rows is not reported. Nothing in the app can tell `check` that the box is a
bar: so `check both` on these screens never reads "no findings", and a real overlap would hide
among these.

Cost: about 5 minutes each time, to read the findings and decide they are the design.

## What would help

A way to mark a floating bar that `check` treats as it treats the system bars (content under it
is not an overlap, and content that cannot scroll clear of it is still "covered"): for example
`role="toolbar"` on a `position="absolute"` box at a screen's edge, or a documented attribute.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5): the top bar in dark and
light, and at the largest text size. The bottom bar: seen on 2026-11-02 at `ed43ad09a0` on a long
list. Related: finding "A floating bottom bar gets no scroll edge effect, and a
route has no bottom toolbar".
