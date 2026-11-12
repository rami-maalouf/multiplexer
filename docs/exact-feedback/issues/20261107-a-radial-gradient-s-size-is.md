# A radial gradient's size is refused as a stop's colour

**Status:** Open
**Systems:** contract, web
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

`background-image="radial-gradient(960px 576px at 78% 0%, #519AFF38, transparent 70%)"` is
refused with `[lower-attr-value] ... a stop's colour is a CSS colour (hex, rgb(), hsl(),
hwb(), a named colour, transparent) or light-dark(a, b)`. The colours are valid; the cause is
the explicit size (`960px 576px`, or `60rem 36rem`): only extent keywords (`closest-side`,
`farthest-corner`, ...) are taken. `contract vocab gradients` lists what is refused, but not
an explicit radial size, so the message sent the search to the colours.

Cost: about 5 minutes (three wrong edits, then the kernel's gradient source).

## What would help

A message that names the size: "an explicit radial size is not taken; use an extent keyword
(`closest-side`, `closest-corner`, `farthest-side`, `farthest-corner`)", and the same line in
`contract vocab gradients`.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb`, building a website's background glow.
