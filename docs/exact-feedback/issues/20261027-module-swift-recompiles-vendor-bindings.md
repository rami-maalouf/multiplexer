# Each edit to a native module compiles all of `modules/apple` again, a vendor's large Swift included

**Status:** Open
**Systems:** Apple host build (`host/apple/build.mjs`), native modules, Exact packages
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The app wraps a third-party Rust library. Its static xcframework and the 2 MB of Swift
bindings that the vendor generates are in `modules/apple/`, beside the app's own small
module file. `host/apple/build.mjs` compiles every top-level `.swift` file there as one
module (`moduleArgs`: one `swiftc` call, `-O`). So a one-line edit to the app's file
compiles the 2 MB of bindings again. The build line's `arms` time was 41.7 s and 31.0 s
for such edits on the iPhone 17 Pro simulator. Every Swift edit in two tasks paid it. An
edit to `app.contract` or `app.ts` took seconds.

## What would help

- Compile Swift that does not change (a vendor's) once, as its own module, and reuse its
  object while its sources are the same. The app's own file then compiles alone.
- Exact packages already compile as their own Swift modules (`placePackages`). From
  reading `build.mjs`, each package compiles again whenever the module arm rebuilds, and
  the arm's key holds the module's and the packages' sources together. Not measured. If a
  package were cached by its own sources, a vendor's bindings could live in one.
- `docs/recipes/native-module.md` does not mention packages, so an author with a vendor
  library does not find them.

## Evidence

Seen at exact2 `65577096ed`. `host/apple/build.mjs` is unchanged at `cee509ac82`.
