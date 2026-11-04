# A horizontal drag inside a list row activates its link on release

**Status:** Fixed on isolated local framework branch; not published
**Systems:** iOS host, list row presses
**Severity:** P2
**Date:** 2026-11-04
**Finding:** 124

## What happens

A vertical list contains full-width links. Dragging 220 pt horizontally inside a row
opens its destination on release. The resulting noninteractive navigation push moves
the source screen, which looks like an inbox sliding sideways. It is not horizontal
overflow: the list's horizontal range and offset stay zero, and no node exceeds the
402 pt viewport width.

Native controls on iOS 26.5, exact2 `ed43ad09a0`:

- Left and right 220 pt row drags over 1.4 seconds both activate the link.
- A five-second left drag stays on the source through 5448 ms after launcher start;
  a noninteractive push first appears at 5550 ms and settles at 6040 ms.
- An equal 220 pt vertical drag scrolls 208.67 pt without navigation.
- Horizontal drags over a gap outside the links do not navigate or shift content.
- An ordinary tap opens the destination. Largest accessibility text reproduces the
  erroneous left-drag activation with the same zero horizontal scroll range.

The source route reaches x=-121 pt during the push, approximately 30% of its width.
These are native model coordinates sampled every 50-70 ms, not pixel motion or exact
touch timestamps. Real Simulator recordings and native touches corroborate the result.

## Cause under test

`PointerIOS.swift`'s `touchesMoved` follows whether the contact remains inside the
press target. `touchesEnded` activates an inside, uncancelled contact. A horizontal
drag can remain inside a wide row without a scroller taking the gesture and cancelling
that press. The collection contact observer deliberately does not cancel touches or
prevent other recognizers. The vertical control does receive scroll cancellation.

A focused `RowCellsIOSTests` regression covers both horizontal directions,
reversal before release, and a later tap with slight finger movement. On unchanged
production framework code it failed in 3.233 seconds: the three drags activated
`[11, 11, 11]` instead of `[]`. The subsequent slight-movement tap added one activation.
The result is retained in `/tmp/mx-row-red-embedded.log` and the matching `.xcresult`.

The isolated candidate captures an origin only for the row's own press target and
cancels that contact beyond the existing `Gesture.slop`, including on release.
Embedded buttons keep their normal tracking; no recognizer prevents another.
The four focused host classes ran 83 tests: 77 passed, six scene-dependent cases
were skipped, and none failed. The original regression and embedded-button
drag-out/back control passed. These tests invoke touch callbacks and do not
establish real recognizer arbitration. Partial native replay now passes both
horizontal directions, vertical scrolling, ordinary tap, reply/cancel and one
keyboard-visible edge Back. A named-store retry proves reversal cancellation with 81 native moves, net travel
zero and no navigation push; a subsequent 2 pt gesture produces exactly one push.
A native menu button still opens its menu after 64 moves out and back. Earlier
attempts that landed on Sign In remain invalid, and the first named-store attempt
failed touch delivery before a row touch arrived. Neither is counted as a pass.
The initial manually linked test bundle failed during setup before assertions;
that archive mismatch is not the regression's red result.

## Expected behavior and scope

Dragging a row cancels its tap activation. Preserve ordinary button drag-out-and-back,
controls inside rows, scrolling taps, row swipe actions, reply gestures and edge Back.
Do not clip the app or swallow its horizontal gestures to conceal the navigation.

This finding covers row-link cancellation only. Intermittent corruption during an
interactive Back transition is a separate investigation.

## Local evidence

The inbox lane's `.exact/inbox-horizontal/report.md` records all native commands,
the auth-free fixture structure, measurements and cleanup. Its neighboring
`measurements.json`, `*-samples.jsonl` and `controlled-left-slow-nav-samples.jsonl`
retain the measured controls. Recordings: `/tmp/mx-inbox-before.mp4` and
`/tmp/mx-inbox-controlled.mp4`; largest screenshot: `/tmp/mx-inbox-largest-before.png`.
The green result is `/tmp/mx-row-green.log` and `/tmp/mx-row-green.xcresult`.
Tested patch sha256: `e796f50be2acd78b54a63d9855b6db8dd54c7c07075f775aadee2a03d0639266`.
Test executable sha256: `fcf41a9265707760a17d88a3405ceb4a2f62f4e8561c26c109cf43d09d01882f`.

No feedback or framework change has been published.

## Fixed native receipt

Framework commit `7529006ab992ff021f790291fedd05b189250e81` in isolated
`exact2-navigation` has exactly the tested patch hash above. No production app
workaround is required. Native receipt `.exact/row-native/remaining-retry.log`
records the landed views, touch counts, paths and route states. Reversal and
small-movement screenshots are display captures; the menu screenshot is an app
fallback because the display changed during capture, so it proves menu contents
only, not material rendering. Native sign-out and its confirmation completed in
the same named store, with empty local session afterward. No exact server device
identity was captured. The host suite retains its six scene-dependent skips.
