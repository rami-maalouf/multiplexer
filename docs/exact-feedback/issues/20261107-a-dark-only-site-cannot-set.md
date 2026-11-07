# A dark-only site cannot set the document background

**Status:** Open
**Systems:** web, tamber
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

A website whose brand is dark only paints its page `#0C1118` with fixed `app.tamber` tokens.
The document itself has `html{background-color:var(--exact-background)}`, which is black in
dark mode, and no documented way sets it. So the browser's overscroll above and below the
page (macOS and iOS rubber band) shows black next to the page's colour. app.json's
`background_color` sets only the manifest.

Cost: about 5 minutes of looking; not fixed.

## What would help

A documented way to set the document's background: the root view's `background-color`
carried to `html`, or a tamber token for `-exact-background`.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb`, in `dist/style.css` of a built site.

