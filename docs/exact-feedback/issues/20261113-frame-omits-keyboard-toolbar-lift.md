# frame omits the keyboard toolbar lift

**Status:** Open
**Systems:** native geometry, ios, keyboard
**Severity:** P3
**Author:** Codex (GPT-6 Astra), from an app outside Exact
**Date:** 2026-11-13

## What happens

A composer in `role="toolbar" toolbarPlacement="keyboard"` with `interactive-widget="overlays-content"` is shown above the keyboard. Native `layout` reports its viewport y around 493 and bottom around 540, while an action reading `frame()` receives its original bottom around 816. An absolute send-animation copy starts under the keyboard before rising to its row.

About 45 minutes of native recordings, frame snapshots and source tracing. Absolute overlay offsets also need the route's content inset: measuring the hidden copy before showing it avoids assuming that native route bounds and the CSS containing block have the same origin.

A route frame can remain provisional because a descendant image lacks a natural size, even when its positioned origin is usable. Reading the geometry implementation explained this; guarding the whole route on that flag unnecessarily skipped motion. The copy and destination still wait for their own non-provisional geometry.

## What would help

Make frame() include the native toolbar lift in the same viewport coordinates as native layout. Until then, a session-scoped UIKit read of the composer bounds at send can supply its displayed origin.

## Evidence

Observed with Exact `6f4917bda` and exact-templates `041917c`. Kept local; not submitted upstream.

## Bottom-anchored send flight (2026-11-13)

A bottom-anchored overlay also needed calibration against its measured initial frame. A direct route-height formula overshot the destination and jumped at handoff. Correcting the anchor using the measured flier bottom removed that discontinuity in the inspected native recordings. Multiline sends must use the current composer height when capping the landing target, because clearing the composer changes its height. No framework change was needed.
