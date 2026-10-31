# check misses the accent fill under a bubble that a sibling paints

**Status:** Open
**Systems:** check (iOS), apps/messages
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-31

## What happens

`check` allows white text on the accent at 3:1, as for a filled button's label
(LLP 1116.020 D7). On iOS it finds that fill only on a box that holds the text
(`AgentCheckIOS.swift` walks the text's superviews to the box that paints it).

The framework's own sample chat app (`apps/messages/bubble.contract`, `Balloon`) draws a
tailed bubble with the fill on sibling boxes behind the text. Copied into an app with the
fill named by role (`AccentColor` under `AccentColorText`), it gave 3 contrast findings per
scheme ("3.5:1 (#ffffff on #0088ff), needs 4.5:1"), for the same white on the same blue that
passed when the text's own box painted it. Cost: about 15 minutes.

What the app did instead: one rounded box that paints the fill and holds the text, and the
tail (an SVG path) drawn over its corner. The fill is opaque, so the two shapes join, and
`check` is clean in light and dark.

## What would help

The sample's bubble written the way `check` judges it, or `check` finding the accent fill
under a text when a sibling paints it.

## Evidence

Seen on 2026-10-31 at exact2 `1bc4c36cb7`, in a drive's `check both` on an iPhone 17 Pro
simulator.
