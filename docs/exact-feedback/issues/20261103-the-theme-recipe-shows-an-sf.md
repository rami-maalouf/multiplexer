# The theme recipe shows an SF-only icon token, which the build refuses

**Status:** Open
**Systems:** tamber, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

The theme recipe (`docs/recipes/theme.md`) shows an icon token with an SF Symbol only:

```
icons
  icon.play = icon(sf "play.fill")
```

In an app that also ships the web, the same line is an error, `tamber-icon-missing`: "icon.… has
no source for web, which draws an icon only from an `svg` source: add `svg "icons/….svg"` … With
no SVG for it, declare no icon and write `symbol:emoji`, the role Apple draws as `face.smiling`
…". The message itself was excellent (it named the role that draws the same symbol on every
host, or `symbol:sf/<name>` with one warning). Only the recipe is misleading.

Cost: about 2 minutes.

## What would help

The recipe's example with an `svg` source, or a line saying that an SF-only token builds only
for apps without the web.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1362 (fixes it): the token has both sources, `icon(sf "play.fill", svg "icons/play.svg")`, and exact2's docs test writes a one-colour SVG for it.
