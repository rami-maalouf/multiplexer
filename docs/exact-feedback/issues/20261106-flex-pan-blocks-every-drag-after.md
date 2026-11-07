# A liquid-glass flex pan stays `.changed` after a return and blocks every drag

**Status:** Open (local host workaround shipped in the app's integration checkout)
**Systems:** Apple host (iOS)
**Severity:** P1
**Author:** Auto (Composer), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

After the app returns from the background on a physical iPhone, vertical scrolling, row
swipes and the interactive back swipe all stop working; taps still work. Switching tab or
screen remounts the tree and recovers. Simulator returns never reproduced it.

A host log written to `Library/Caches/scroll-return.log` on a freeze showed, after the
finger lifted, `_UIFlexInteractionPanGestureRecognizer` on the Exact window still in
`state=2` (`.changed`), with `delegate=_UIFlexInteraction`. Later dead drags also left
`_UIParallaxTransitionPanGestureRecognizer` in `.changed`. List pans stayed
`enabled=true` / `pan=0`; the freeze was other recognizers waiting on the stuck one.

Cost: prior diagnostic work plus about 20 minutes to pull and read the phone log once a
freeze was captured.

## What would help

- On `didBecomeActive`, and when a drag ends with no scroll motion while a recognizer is
  still began/changed, force-end those recognizers (toggling `isEnabled` cancels them).
- A durable fix: liquid-glass `_UIFlexInteraction` must not leave its pan in `.changed`
  across suspension or after a cancelled touch; Exact's glass surfaces should not attach a
  flex pan that outranks scroll and interactive-back without ending cleanly.
- Keep (or thin) the scroll-return file log until phones stop freezing.

## Evidence

Physical iPhone, app with Exact integration at `584858860a` (scroll-return file log).
Freeze after return=2; first five ≥30pt drags `moved=false` with
`_UIFlexInteractionPanGestureRecognizer[state=2 … view=ExactWindow]`; `stuck` lines for
the transcript and the inbox list; drags 7–8 moved once the flex pan was gone.
Local workaround: Exact `e2b58b6992` / `072cbd1f60` releases began/changed recognizers on
return and after a dead drag.
