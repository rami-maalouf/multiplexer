# A floating bottom bar over a large-title list gets no scroll edge effect, and a route has no bottom toolbar

**Status:** Open
**Systems:** Apple host (iOS), LLP 1131, glass docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat list (a route with a large title, `text ... role="heading" aria-level=1`, over a
`list`) needs a floating bar at the bottom, as iOS 26's own bottom toolbars and the
original app have: a round glass filter button on the left and a glass capsule in the
middle. Exact has no bottom toolbar a route can ask for (UIKit's `toolbarItems`), so the
app draws the bar.

- As a `row position="absolute" left=0 right=0 bottom=0` (glass buttons, `glassGroup`),
  with `padding-bottom` on the list so its last row clears the bar: the rows pass under
  the glass, but with no scroll edge effect. An absolutely placed box is never a control
  bar (LLP 1131 D1), and a large-title route takes no band at all (LLP 1131 D2).
- As the same bar in flow after the list, with the title made inline (`aria-level=2`), the
  shape LLP 1131 describes: the list did run under the bar (it took a band), but a capture
  of the simulator's display (iOS 26.5, dark; also with `-exact-scroll-edge-effect="soft"`
  on the list) showed no edge effect either: the rows under the bar stayed sharp.

The app kept the large title and the absolute bar. Cost: about 25 minutes, mostly reading
`ControlBarsIOS.swift` and `PageEdgesIOS.swift` to learn why.

## What would help

- A bottom toolbar a route can name, drawn by UIKit (`toolbarItems`, or SwiftUI's
  `.toolbar(.bottomBar)`): it keeps the large title and gives the edge effect.
- Or the edge effect for a floating bar under a large title, as a hand-built iOS 26 screen
  gets with `safeAreaBar(edge: .bottom)`.
- A line in the glass docs (`contract vocab glass`) saying which floating bars get the
  edge effect and which do not.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
