# A package's Swift that did not compile shows no compiler error

**Status:** Open
**Systems:** build, ios
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

The first `ios` build of a new app checkout stopped with:

```
host/apple: notifications's Swift (<app>/node_modules/@exact/notifications/apple/Notifications.swift) did not compile:

```

The line ends with a colon and nothing follows: no compiler error, no file and line, no
`error:` anywhere in the log. The cause was a mixed setup: the app's `package.json` named the
`@exact/*` packages in one framework checkout, while its Cargo paths and `exact.mjs` named
another, and the package's Swift did not match that checkout's host. Pointing the packages at
the same checkout (and `bun install`) fixed it.

Cost: about 3 minutes, found by comparing with a sibling checkout, plus a 2-minute build.

## What would help

- The compiler's own output under "did not compile".
- A check before the build that the packages and the Cargo paths name the same framework
  checkout, naming both paths when they differ.

## Evidence

Seen on 2026-11-07 at exact2 `f53339adc8`, iOS Simulator build (`bun exact.mjs ios --sim <udid>`).
Related: the finding on an app checkout at another folder depth (`EXACT2` does not cover every path).
