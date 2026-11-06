# A text that spills its box shows only in check, one screen at a time

**Status:** Open
**Systems:** agent drive, check, layout
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happened

A chat app's list (about 190 rows, real data) had content wider than the screen: one row's
preview, a link with a long run of characters and no break in its two visible lines, drew past
its box to the screen's edge, with no ellipsis. Finding which text did it cost about 60 minutes:

- `layout <list>` gives the scroller's range, but the list now has `overflow-x="hidden"`, and each
  row is a swipe `scroll`, so every range read `0,0 of 0,0`. A probe (a row made a horizontal
  `scroll`) also read `0,0 of 0,0` while a deliberately wide text drew 847 pt past its box: the
  range does not show a text's spill.
- `check` names it well ("its text is 60 pt wider than its box, and spills"), but only for what is
  on screen. Covering the list took a drive of 31 `tap <list> drag 0 -480` + `check` pairs.
- `tap <list> into <key>` on a list that is not virtualized replied `tapped ... into={key}` and
  did not scroll, with no word that it did nothing.
- `clock until state` takes only `==`; waiting for "the list has loaded" (`!= ""`) was refused.

## What would help

- `check <scroller> --all` (or `check` in `verify` on a scroller's whole content): each text
  wider than its box, with its node, across rows off screen too.
- `layout` of a text: its laid-out width beside its box.
- `into` on a list that is not virtualized: scroll the row into view, or say it cannot.

Seen with exact2 `dd9343b324` (local integration branch), iOS Simulator. The fix in the app was
`overflow-wrap="break-word"` on the clamped texts; `verify` rightly flagged `anywhere` (it breaks
ordinary words), which helped.
