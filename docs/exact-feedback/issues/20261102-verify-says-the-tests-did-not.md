# verify says the tests did not compile when it could not pick a simulator

**Status:** Open
**Systems:** verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

In a new app on a Mac with 4 iPhone simulators booted, `bun exact.mjs verify ios` printed:

```
tests: did not compile
  4 iPhone simulators are booted (...), none with <bundle id> installed: name one with --sim <udid|name> (or EXACT_SIM)
```

The tests compiled; only the choice of simulator failed. `scripts/verify.mjs` prints
`tests: did not compile` for any `tested.error`, whatever its cause. Cost: a second run, about
3 minutes.

## What would help

`tests: did not run` (true for a compile error too), or the cause on the same line.

## Evidence

Seen on 2026-11-02 at exact2 `d165f8959f` (`scripts/verify.mjs`, the `tested?.error` branch).

## A fix (2026-11-02)

Pull request https://github.com/ccheever/exact2/pull/1325: the label is `tests: could not run`
(the tests may have run in part when the app fails to open at a later test), with the cause
on the lines under it as before, and a test for this case.
