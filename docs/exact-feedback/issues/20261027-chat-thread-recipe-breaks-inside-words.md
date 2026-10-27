# The `chat-thread` recipe's bubble uses `overflow-wrap="anywhere"`, which `verify ios` reports

**Status:** Open
**Systems:** docs (`docs/recipes/chat-thread.md`), `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A transcript copied from the recipe (`text m.body … overflow-wrap="anywhere"`) gave one
`verify ios` finding: `breaks app.contract:<line> text overflow-wrap="anywhere": breaks
inside words (Octo/ber); wrap between words (the default) or give the row room`. With
`overflow-wrap="break-word"`, `verify ios` was clean. The recipe's note says that
`anywhere` breaks a long word (a URL) whichever box bounds the bubble, as UIKit does.
Cost: about 2 minutes.

## What would help

The recipe and `verify` agreeing: `break-word` in the recipe, or `verify` accepting
`anywhere` in a bubble with a `max-width`.

## Evidence

Seen on 2026-10-27. The recipe still has `overflow-wrap="anywhere"` at `cee509ac82`.

## A second place: the composer's touch target

The recipe's composer, copied as written (a one-line `textarea` with `field-sizing="content"`
inside a row with `padding="4px 4px 4px 12px"`), failed `check` on iOS: "composer
[25,809 325×20]: 325×20 pt, under the 44×44 minimum". The fix in the app: the row's
vertical padding moved into the field (`padding="12px 0"` on the `textarea`, `margin="4px 0"`
on Send), so the field is 44 points tall and the composer keeps its height. `check` is
then clean in light and dark, and at the largest text size. Seen on 2026-10-27 at
`cee509ac82`. Cost: about 5 minutes.
