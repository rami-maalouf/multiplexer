# A screen with its own top bar has no documented way to clear the status bar

**Status:** Open
**Systems:** docs, Apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app's pushed chat screen draws its own top bar (Back, a picture over a name in a glass
capsule, a "..." menu), so the route says `navigationBar="none"`, and the bar is a
`position="absolute" top=0` box that floats over the transcript. The transcript, a virtualized
`list` with `flex=1`, is the route's first child.

On iOS the bar drew at y 0, under the status bar and the Dynamic Island. The transcript starts at
the route's top edge, so UIKit insets that scroller and the host does not pad the route; the
app's root is `viewport-fit="auto"`, so `env(safe-area-inset-top)` is 0; and
`var(--exact-safe-area-inset-top)` (LLP 1123 D9) is not built yet.

The docs came close but did not say it. The `navigationBar="none"` row in
`contract-for-agents.md` says "a full-bleed screen that draws its own way back" and nothing about
the status bar. The pitfall "A banner at the root of a tabbed app stays under the status bar"
says that "a route whose scroller starts at its top ... is inset by UIKit instead, and a box at
its `top=0` is under the bars", and gives no way out for a route that keeps its scroller there.
The way out was in LLP 1123, case C33a: a scroller that does not span an edge makes the wrapper
pad that edge. A `view height=0 flex-shrink=0` above the transcript did it: the route then starts
at y 62, under the status bar, and the bar's `top=0` with it (`layout chat-bar`: window
`0,62 402×92`).

Cost: about 10 minutes, and three drives.

## What would help

- A line under the `navigationBar="none"` row (or in the pitfall above): "a screen that draws its
  own top bar over its scroller: put a zero-height box above the scroller, so the host pads the
  route below the status bar; the bar's `top=0` then starts under it".
- Later, `var(--exact-safe-area-inset-top)` inside a route (LLP 1123 D9), which would let the
  transcript reach under the status bar as a system bar's content does.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5, a 402×874 iPhone).
Related: exact2's `QUEUE.md`, "A box outside every route cannot clear the iPhone's status bar"
(the same cause for a box outside every route).

**2026-11-06 (same app):** with the zero-height box, a soft-edge material on the bar at
`top=-40` still left the page's colour as a hard shelf above the clock (`layout chat-bar`:
window `0,62`). The bar itself needed `top=-62` (controls padded back by 62) so its material
covers the status bar; the transcript also needed `margin-top=-62` so messages run under that
band. Docs for `navigationBar="none"` should name both the pad and the negative reach when the
bar draws its own scroll-edge fade.

**2026-11-06, later (same app, exact2 `ae8946aca0`):** with both soft edges in place, a faint dark line
stayed at the foot of the status bar (y 62) on both the list screen and the chat. It was UIKit's
own iOS 26 scroll edge effect: the scrollers keep the default `automatic`, and UIKit draws it under
the status bar on a route with no bar, ending in a line at its foot, stacked under the app's own
material. `layout <scroller> native` showed it (`_UITouchPassthroughView edge-effect of #3`);
`-exact-scroll-edge-effect="none"` on both scrollers removed it (a screenshot diff confined to rows
0 to 62; the bottom edges were pixel-identical). `contract vocab scroll-edge-effect` answered "not a
built-in tag or attribute"; the `-exact-` spelling came from grepping an example app. About 20
minutes. What would help: `contract vocab` finding the `-exact-` name from the bare one, and the
`navigationBar="none"` docs saying that a screen drawing its own top edge should set
`-exact-scroll-edge-effect="none"` on its scroller.
