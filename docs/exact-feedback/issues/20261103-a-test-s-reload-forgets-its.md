# A test's `reload` on iOS comes back at the first screen, not where `at` opened it

**Status:** Open
**Systems:** test runner (iOS), docs (the card's test steps)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A test opens a settings screen by its path, changes a kept (`persist`) setting, reloads, and
goes on:

```contract-test
test "a setting is kept"
  at "/settings"
  tap "speed-1.5"
  reload
  clock data
  expect state voiceSpeed == 1.5
  tap "speed-2"
```

On iOS, after `reload` the app is at its first screen, so `tap "speed-2"` failed: "no view
matches speed-2 by testId, label or text", followed by the first screen's targets. The card
says that `reload` "keeps storage and fetch faults", and nothing about the location; a browser's
reload keeps it.

Cost: about 3 minutes. The test now ends at its check after the reload, and a second test
opens the screen again.

## What would help

The card saying whether `reload` keeps the location on each host, or a `reload at "<path>"`.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, `test ios` on the iOS 26.5 Simulator.
