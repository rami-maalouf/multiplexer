# A woken built page keeps the build's viewport width

**Status:** Open
**Systems:** web, render
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

A website page rendered ahead (`render=build`) is made at a phone's width. A root
component reads `resource viewport = exactViewport() as shape Viewport` and
`derive wide = viewport.width >= 720`, and shows a group of header links under `if wide`.
In a desktop browser (1280 x 800) the built page carries
`data-wake="[["(width >= 720px)",false]]"`; the capture script wakes the runtime (`app.js`
loads and `self.exact.ready` is set), but the links never appear. They appear only after the
window is resized. So a width branch on a built page shows its narrow side on every desktop.

LLP 1048.007 D2 (2026-10-31, "A woken page lays itself out for the reader's viewport, not the
render's") says the runtime asks the device's sources again as it adopts. That does not seem
to happen here. The same branch in a child component's own `exactViewport()` resource also
stayed narrow.

Reproduce: `pattern site`, a root `exactViewport()` resource, `if viewport.width >= 720` around
a `text`; `web-build --out dist`, `serve dist`, open at 1280 px in a painting browser; the text
is missing until a resize.

Cost: about 25 minutes. Workaround: no width branch; CSS alone (a clipped wrapping row).

## What would help

The woken runtime re-reads `exactViewport` on adoption (as D2 says), or the build warns that a
`render=build` page branches on the viewport and will show the build's side until a resize.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb` (the app's integration checkout), with Playwright's
headless Chromium (first paint reported) and `serve dist`.

