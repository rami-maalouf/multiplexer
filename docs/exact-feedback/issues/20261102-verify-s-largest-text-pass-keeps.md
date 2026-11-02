# verify's largest-text pass keeps no screenshots, so a finding there cannot be seen

**Status:** Open
**Systems:** verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

`verify ios` counted 2 "overlap" findings at the largest text size (a transcript row under a
chat's composer) on the last screen of a test that ends with the keyboard up and the list
scrolled to its end. A drive with the same steps, with the simulator's text size raised after
them, showed the row in place, and `check` was clean. `--shots <dir>` copies only the
normal-size screenshots, so the screen that the finding names could not be seen. Not isolated
after three tries, about 25 minutes.

## What would help

The largest-text pass saving a screenshot of each screen it checks, as the normal pass does.

## Evidence

Seen on 2026-11-02 at exact2 `d165f8959f` (iOS 27.0 simulator). The test that showed it is not
in the app; it was a longer version of a recipe's test.
