# The host tests refuse to run without the Metal toolchain, which a build does without

**Status:** Open
**Systems:** Apple host, tests
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`bun host/apple/build.mjs --test` (the Swift host tests) stops before it runs any test:
"host/apple: this build compiles the SVG filter kernels with Xcode's Metal toolchain, which is
not installed. Install it with `xcodebuild -downloadComponent MetalToolchain`". On the same
machine, an app's build goes on without it ("no SVG filter kernels (no Metal toolchain)").
`test()` calls `svgFilterLibrary(…, true)`, where a build passes no `required`.

Installing an Xcode component changes every other session's builds on a shared machine, so I
ran the tests with a local edit that made the kernels optional, and undid it after.

Cost: about 10 minutes.

## What would help

- The host tests run without the toolchain and report the SVG filter tests as missing a
  prerequisite, as a build skips the kernels.

## Evidence

Seen on 2026-11-02 at exact2 `880d4f8652` (Xcode 27, Metal toolchain "uninstalled").
