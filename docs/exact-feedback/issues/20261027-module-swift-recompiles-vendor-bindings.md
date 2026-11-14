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

## seen again (2026-11-03)

Adding two small operations to a native module triggered a roughly 90-second build, including
the unchanged vendor bindings. Subsequent view-only updates used the new plan in seconds.

## Further build-cost evidence (2026-11-03)

At exact2 `ed43ad09a0`, integrating another feature with native changes required 76.8 s of iOS
build time before verification tests could run; the build reported 59.5 s in host arms. Total
verify time was 144.2 s with six tests. This is an overall rebuild measurement, not a separate
measurement of vendor-binding compilation. Narrower invalidation and cached arms would reduce
the edit-and-verify cost.

## Further build-cost evidence (2026-11-04)

At exact2 `ed43ad09a0`, a native session-storage change rebuilt iOS in 83.0 s, with 63.8 s
reported in host arms. The complete six-test verify took 155.0 s, versus the initial estimate
of about 85 s. The build log gave no intermediate stage progress after "the app's Swift modules
compile as they are now" until compilation ended. This measures the overall native rebuild,
not vendor compilation separately. The existing cached-vendor proposal still applies.

## Integration evidence (2026-11-04)

A combined native-module rebuild took 102.4 seconds before verification on the normal
framework checkout. The full verification took 186.9 seconds, versus the initial 65-second
estimate based on its previous run. Including invalidated native modules in the estimate
would make that waiting time clearer. No additional workaround was needed.

## display-string rebuild (2026-11-06)

At integration checkout `31063d7dbb`, a branding-only change to display strings in
two small native module files and a media vendor string rebuilt the full module
including unchanged third-party bindings. The successful simulator build reported
95.8 s for arms, versus 12.3 s for Swift host work and 9.9 s for packaging. Broad
silent intervals made progress hard to assess; per-file reporting and a separate
cache for vendor bindings would help.


## Further evidence: desktop lifecycle, 2026-11-08

At Exact `afac7b1370`, a small lifecycle-observer edit again recompiles all native
module sources, including a third-party generated binding file. The parent build
finishes its host packages quickly, then spends minutes in `swift-frontend` on
those bindings. Keeping the vendor binding compilation separate would remove
this iteration cost. No new timing claim is made from this busy machine.

## Further evidence: address-book module (2026-11-12)

A native module change rebuilt the full copied third-party binding set. One observed
build reported 96.8 seconds in `arms`, in addition to 13.2 seconds of Swift work.
Each review correction needed another build before the native test runner accepted
its receipt. A clearer estimate and isolation of unchanged bindings would shorten
this edit/verify loop.

2026-11-12 self-hosting follow-up: a small native configuration edit rebuilt the complete native module, including vendor bindings; the production module step took 79.7 seconds. a separately cached vendor module would avoid recompiling these unchanged bindings.

### Additional evidence, 2026-11-12

A small native profile-selection change rebuilt all copied module sources, including vendor bindings. The focused native test took about two minutes to become available. Incremental compilation remains desirable.

### temporary diagnostics, 2026-11-13

At Exact `6f4917bda`, adding a small frame-trace writer to an existing native module again rebuilt the vendor bindings, with quiet intervals over a minute. Contract-only probe changes reused the module. A built-in target/presentation trace would avoid this rebuild solely for animation diagnosis.

## Further evidence: integration verification (2026-11-12)

A native integration change at Exact `8536d208c40f97be3f132ea266d5029e2e3c10ba`
rebuilt unchanged copied vendor bindings. Total build time was 110.4 seconds:
91.2 seconds in arms and 13.3 seconds of Swift work. Subsequent view-only edits
used the fast plan path, which avoided repeating that compilation.
