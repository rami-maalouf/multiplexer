# scrollIntoView cannot open a collapsed large title again

**Status:** Open
**Systems:** Apple host, scrolling
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A screen has a large title over a plain `list`. The reader scrolls down, so the title
collapses into the small bar. Then the reader picks another filter, and the list shows other
rows. The new list should start at its top with the title open, as Mail shows another
mailbox.

The action calls `scrollIntoView("<first row's id>", block="start")`. The first row then
sits at the top under the small bar, and the large title stays collapsed. A drag back to the
top opens it, as the docs say; `scrollIntoView` does not.

Reading the host (`IntoView.swift`, `elementDestination`): the target offset is aligned
against the scroller's current `adjustedContentInset.top`, which is the collapsed bar's. No
element in the list is above the first row, so no `scrollIntoView` can reach the offset that
opens the title. `scrollTop=0` moves the scroller only when its bound value changes.

What I did: kept the `scrollIntoView` to the first row (better than keeping the old list's
offset, deep in a list that has changed).

Cost: about 10 minutes.

## What would help

- A scroll to the very top that opens the large title, as a tap on the status bar does:
  `scrollIntoView` of a list's first row with `block="start"` doing it, or a command such as
  `scrollToTop(listId)`.
- A line in the `scroll` concept's docs saying what happens to a large title.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
