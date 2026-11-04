# A host test that needs a scene runs hosted only when it says missing scene

**Status:** Open
**Systems:** host tests, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A new iOS host test used a window scene (`UIApplication.shared.connectedScenes.first`) through a
test class's fixture helper. It failed with `XCTUnwrap failed: expected non-nil value of type
"UIWindowScene"`. The other tests of that class pass because each one starts with
`guard … else { throw missing("scene", …) }`: `host/apple/xctest.mjs` (`hostedTests`) reads that
call in a test's source and runs only those tests in the hosted pass, in an app with a scene.
I learned the rule by reading `xctest.mjs`.

Cost: about 5 minutes.

## What would help

- A line in `docs/testing.md`: a test that needs a scene or the accessibility runtime says
  `missing("scene")` or `missing("accessibility")`, and only then runs hosted.
- Or the bare pass's failure noting that the test touched a scene that the bare pass has none of.

## Evidence

Seen on 2026-11-03 at exact2 `574720f370`, iOS 26.5 simulator.
