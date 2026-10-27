# A transcript moved by one row when its first row was removed above the view

**Status:** Open
**Systems:** iOS host (list scroll anchoring), virtualized list
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A transcript: `list appearance="none" virtualized=true scroll-start="end"
scrollFollowEnd=true`, its rows keyed by message id. The reader scrolled up about 200
points from the end. Then one data update removed the list's first row (far above the
view) and appended one row at its end.

Every visible row moved up by one row's height, 40 points (`tree --ax` frames: a row at
y 271 moved to y 231). `docs/contract-for-agents.md` says rows "inserted, removed or
resized above what the reader sees keep the reader's place".

After the app changed to stop removing rows, an append alone kept every row in place
(the same row stayed at y 191).

## What would help

- Check whether a removal above the view, in the same update as an append at the end,
  keeps the reader's place in a virtualized list.

## Evidence

Seen once, on 2026-10-27 at exact2 `cee509ac82`, on the iOS Simulator. Not isolated
further: the update that moved the rows both removed and appended.
