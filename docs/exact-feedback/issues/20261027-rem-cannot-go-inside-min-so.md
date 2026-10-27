# `rem` cannot go inside `min()`, so a size cannot both scale with the text and stop at a cap

**Status:** Open
**Systems:** Contract style values (lower-attr-value), Dynamic Type
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A chat list row has a round picture. It should grow with the reader's text size, as the
row's text does, but stop at a cap so that at the largest sizes it does not fill the row.
In CSS that is `width="min(2.75rem, 64px)"`. Contract refused it: "`width="min(2.75rem,
64px)"` is not a valid `width`: rem and em are not supported inside calc(), min(), max() or
clamp(); write px". So the picture has a fixed 44 points, and only its initials scale
(`font-size="min(-exact-headline, 20px)"`, which is accepted).

The message is clear and names the fix. The cost is the design: a fixed size, or a size
with no cap.

Cost: about 2 minutes, and a picture that does not follow the text size.

## What would help

- `rem` and `em` inside `min()`, `max()`, `clamp()` and `calc()`, as CSS has them.

## Evidence

Seen on 2026-10-27 at exact2 `cee509ac82`. Related: exact2's `QUEUE.md` entry "CSS values
builders reach for and Contract refuses" (font-size calculations).
