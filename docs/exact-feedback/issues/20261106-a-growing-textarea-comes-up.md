# A growing textarea comes up a line short on iOS, so its first line scrolls under its top

**Status:** Open
**Systems:** Apple host, text measurement
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

A chat composer is a one-line `textarea` with `field-sizing="content"`, `padding="13px 0"`, the
body font and `max-height=140`. As the text wraps, the field grows, but it comes up short: the
iOS text view then scrolls its text up and the first line shows cut at the field's top edge.

`layout composer` on an iPhone Simulator (iOS 26.5, 402 points wide, field 238 or 260 wide):

| Text | Lines drawn | Field height | Fits? |
|---|---|---|---|
| 2 lines | 2 | 62 | yes |
| 3 lines | 3 | 80 | no, about 7 points short |
| 4 lines | 4 | 98 (238 wide) / 80 (260 wide) | no |

Two parts. Each line is measured at about 18 points where the text view draws a 17-point body line
about 20 points tall; an authored `line-height=1.25` made three lines fit (86). And the measured
line count can be one lower than the text view's own wrapping: four drawn lines measured as three
(86 again). `lineFragmentPadding` is already zero, so the wrap width is the same; the text
measurement and UIKit's layout break the same words differently.

Cost: about 15 minutes, while moving the composer's Send into the field.

## What would help

- Size a native `textarea`'s content height from the text view's own layout (its
  `sizeThatFits` at the box's width), as `field-sizing: content` means the drawn content.
- Until then, a note in the chat recipe that a growing composer needs an authored `line-height`.

## Evidence

Seen on 2026-11-06 at exact2 `584858860a` (iOS Simulator, iOS 26.5, a 402x874 iPhone). Before the
app's change (Send beside the field) and after it (Send inside), the same shortfall.
