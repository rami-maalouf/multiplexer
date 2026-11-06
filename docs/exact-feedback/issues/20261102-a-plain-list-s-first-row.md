# A plain list's first row has a top separator that the app cannot hide

**Status:** Open
**Systems:** Apple host, lists
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A plain `list` (no `appearance`) under a large title shows a line above its first row. When
the first row is an ordinary row (a picture, then a name), the line starts at the row's
text. When the first row is a grid of round pictures (three to a row, a name under each),
the line starts in the middle of the screen: at the first text inside the grid, the second
picture's initials. The grid row writes `border-bottom="none"`, so no line is under it; the
line above it stays.

Messages, Mail and Settings draw no line above a plain list's first row.

Reading the host (`GroupedListIOS.swift`, `itemSeparatorHandler`): a row's top separator is
hidden only when the row before it wrote its own edge (`owned(path.item - 1)`). The first
row has no row before it, so nothing the app writes on it hides UIKit's line, and
`lineStart` does not set that line's inset. I did not try `border-top="none"` on the first
row; by the code, it would change nothing.

This is close to a known item: exact2's `QUEUE.md`, "A list's rows as cells, what is owed",
(2) and (6), says where a separator starts and that a row's edge `none` is the author's "no
separator here". Neither says the first row's top line.

Cost: about 6 minutes; left as it is.

## What would help

- No top separator above a plain list's first row, as UIKit's own apps show it.
- Or `border-top="none"` on the first row hiding it, as `border-bottom="none"` hides the
  line under a row.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), dark and light; the
same line is in screenshots of the same list taken earlier that day.

## Resumed check (2026-11-04)

The local experiment hides the top separator for the first item of the first plain section.
A new build still shows the line above the pinned grid at the largest text size. The change
is therefore not a verified fix. The local framework branch and experiment remain preserved,
with before and after screenshots; no new feedback or pull request was published.

## More evidence (2026-11-06)

A sticky title as the list's second row, under a zero-height first row (so that `scrollIntoView` has a
target above the sticky row), moves the line to the screen's top edge under the status bar. The app
covers it there with a 1-point view in the page's colour, at the top of the sticky row, shown only at
rest. Cost: about 5 minutes. The same "What would help" applies.
