# A swipe row in a plain list loses the cell's margin, with no warning

**Status:** Open
**Systems:** Apple host (lists, swipe actions), contract docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-05

## What happens

A plain `list`'s row puts its content at the cell's margin (16 points at each end on an upright
iPhone) "where you write no padding" (`docs/contract-for-agents.md`). A row written as the swipe
long form (`scroll swipeContent=… swipeLeading=… swipeTrailing=…`, its content a `link` at
`width="100%"`) wrote no padding, yet its content stood at 0: pictures touched the screen's left
edge, and trailing chevrons and badges were cut at the right edge. Nothing warned. Writing
`padding="0 16px" box-sizing="border-box"` on the swipe's content restored the row.

Cost: about 20 minutes, and one regression shipped to an integration branch.

## What would help

- The cell's margin applied to a swipe row's content, as to any other row; or
- a warning on a swipe row in a plain list whose content writes no padding, and one line in the
  swipe vocab entry.

## Evidence

Seen on 2026-11-05 at exact2 `d0d66b107e` (the app's integration checkout), iOS Simulator (iOS 26.5).
