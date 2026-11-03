# A header in a route forced dark draws its iOS bar title in the light ink

**Status:** Open
**Systems:** apple host, agent check
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A full-screen camera route is dark in both schemes: `color-scheme="dark"`, a fixed black
background and fixed white ink (theme tokens with `scheme=fixed`). Its `header` holds a Close
button and a title text. In dark mode the title shows. In light mode the title is missing: the
header became the iOS bar, which drew the text in the light scheme's black on the route's black.
`check light` answered "no findings", and `tree` still listed `Text "Camera"`, so only a
screenshot showed it. A first guess (the bar needs a right-hand item) cost one more drive.

The fix in the app: a plain `row` instead of `header`, drawn by the app in its own ink.

Cost: about 10 minutes and four drives.

## What would help

- The iOS bar of a route following that route's `color-scheme` (its title, its glass buttons).
- Or `check` finding text drawn in the colour of what is behind it, as it does for low contrast.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), the route presented with
`navigationPresentation="fullscreen"`.
