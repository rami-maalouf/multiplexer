# font-size still refuses rem inside min(), which width now takes

**Status:** Open
**Systems:** contract style values (lower-attr-value), Dynamic Type
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

`verify ios` flagged two fixed glyph sizes in a chat app (`image "symbol:add" font-size=20` in
a 44-point round button, and an 11-point X in a 22-point disc) and said: "a role
(`font="-exact-title1"`) or a `rem` size ("1.25rem") scales". The glyphs sit in fixed
circles, so each needs a size that scales and stops at a cap.

1. `font-size="min(1.25rem, 24px)"` on the `image`: the build refused it:
   `[lower-attr-value] font-size="min(1.25rem, 24px)" is not a valid font-size: expected number`.
2. `font-size="1.25rem"` compiles, and so does `font-size="min(-exact-title3, 24px)"`.
3. In the same app, `max-width="min(14rem, 240px)"` compiles: the earlier finding "`rem`
   cannot go inside `min()`" (closed as fixed at `ed43ad09a0`) is fixed for widths but not
   for `font-size`.

Cost: about 3 minutes and two test builds. The app uses `min(<role>, <cap>)`.

## What would help

- `font-size` taking `rem` inside `min()`, as `width` does.
- Or the refusal naming the forms `font-size` takes there (a number, a `rem`, a role, or
  `min()` over a role).

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, `contract build` and `verify ios`.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1349 (fixes part of it): the refusal names the forms `font-size` takes, among them `min(<text style>, <px cap>)`. A `rem` cap inside `min()` would need a new kernel unit: a design question.

## Seen again on 2026-11-03

A chat's large emoji (one to three emoji with no bubble) were to grow with the reader's text size
to a cap: `font-size="min(2.75rem, 60px)"` was refused ("is not a valid `font-size`: expected
number"), while `font-size="min(-exact-headline, 20px)"` in the same app compiles. The app uses a
plain `font-size="2.75rem"`, with no cap. About 2 minutes. At exact2 `ed43ad09a0`.
