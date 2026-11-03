# A list cell's row brings a gap and padding from its tag, which the list docs do not say

**Status:** Open
**Systems:** docs, apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

In a `list appearance="auto" listStyle="plain"`, a section's `row` is a cell, and its tag gives it
`column_gap = 8`, `row_gap = 8` and `padding_left/right = 16` (`layout` shows them as "authored,
tag"). A grid of three tiles at `width="33.333%"` in such a row wrapped to two a line. The list
docs and `contract vocab section` do not say that a cell's row brings these.

`layout found-grid` showed the cause at once; `gap=0` and the row's own padding fixed it. Cost:
about 5 minutes.

## What would help

A line in the list docs (and `contract vocab section`): a cell's `row` has the platform's
insets and an 8-point gap; say `gap` and `padding` on it for a grid.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
