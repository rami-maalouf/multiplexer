# A virtualized list draws rows past its frame, under the next sibling, and refuses overflow

**Status:** Open
**Systems:** Contract lists, Apple host, check
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat screen is a column: a virtualized `list` (the transcript, `flex=1 min-height=0`), then a
reply bar and the composer, which have no background. Scrolled up, the list's rows below its
bottom edge still draw, and they show through the reply bar and the composer text (the layout
says the list ends at y=782; a message's text was drawn at y=789 to 817, under the composer).
`check` reports each such text as "overlaps".

`overflow="hidden"` on the list is refused: "`overflow` is not supported on this virtual
collection flow root; absolute/overlapping rows and alternate container layouts are not
windowed". Wrapping the list in a clipping column might break the navigation bar's link to it
(`navigationScroll`), so I did not try that.

What worked: one column that holds the reply bar and the composer, with
`background-color="-exact-background"`. The rows are then hidden under it, `check` is clean, and
the screen at rest looks the same. The sample chat app hides them with
`backgroundMaterial="ultra-thin"` on its composer bar; in light mode that material shows as a grey
band even at rest.

Cost: about 25 minutes.

## What would help

- The list clipping at its bottom edge, as a `UIScrollView` does (its top can stay under the
  navigation bar).
- Or a line in the chat-thread recipe: the bar under a transcript needs a background or a
  material, because rows draw past the list's frame.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5). Related: finding 35 (a
floating bottom bar gets no scroll edge effect).

## A fix (2026-11-02)

Pull request https://github.com/ccheever/exact2/pull/1327 adds this to the lists section of
`docs/agent-pitfalls.md` (the chat-thread recipe is at its byte cap): give the bar after a
virtualized list a background or a material. Whether the list should clip at its bottom edge is
a question for the Exact team.

## More evidence (2026-11-03, `ed43ad09a0`)

It happens at the top edge too. A chat screen with `navigationBar="none"` draws its own floating
bar; with the system bar gone, the transcript's row above its frame showed in the status bar's
area (a blue bubble's edge above y 62, where the list starts). The app covers it with its bar's
fade: a box that starts at `top=-120` and is the page colour down to the route's top.
