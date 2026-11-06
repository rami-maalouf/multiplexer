# A swiped row's line runs from the cell's margin after it closes

**Status:** Open
**Systems:** Apple host (lists, swipe actions)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-05

## What happens

In a plain list whose rows are cells, each row's line starts at the row's first text
(`RowCellsIOS.swift`, `firstText`). While a swipe row is open, its content is in UIKit's
projection cell (`SwipeActionsIOS.swift`), so the row has no text and its line is drawn from the
cell's margin. `restore()` puts the content back but draws no lines, so after the row closes its
line runs the full width (from 16 points) while every other row's starts under its text.

Fixed locally in the integration checkout (`cc75ef11d0`): `restore()` ends with
`owner.presenter?.rowCells.sync(changed: [list.id])` for the row's list. Screenshots before and
after show the line back under the text.

Cost: about 15 minutes.

## What would help

- That change upstream, or the line drawn again whenever a row's content moves home.

## Evidence

Seen on 2026-11-05 at exact2 `d0d66b107e`, iOS Simulator (iOS 26.5); fixed locally at `cc75ef11d0`.
