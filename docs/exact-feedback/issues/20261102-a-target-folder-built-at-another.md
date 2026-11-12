# A target folder built at another path fails the build with an unclear dep-info error

**Status:** Open
**Systems:** build, cargo dep-info check
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

An app was checked out a second time (a git worktree, so that two agents can work on two
branches at once). To keep builds incremental, the app's `target/` folder was copied from the
first checkout into the second. Then, in the second checkout:

1. `bun exact.mjs ios --sim <udid>` compiled for 26 s and ended with:
   `no matching rustc unit dep-info for unicode_ident; searched target directory <app>/target; rebuild the stale Cargo unit or use a private target directory`.
2. Cargo itself took the copied units as fresh. Exact's check in
   `scripts/cargo-dep-info.mjs` did not: 1140 of the 1626 `.d` files in the copied folder
   name the first checkout's absolute path, so no candidate `.d` file "names" the reported
   output.
3. The message does not say which command rebuilds "the stale Cargo unit", or that the
   folder was built at another path. Deleting `target/` and building from nothing worked
   (2 min 23 s).

Cost: about 10 minutes to find the cause in the script's source, then a full first build.

## What would help

- The message saying that the target folder was built at another path, with the fix:
  "this target/ was built at <path>; delete it (or `cargo clean`) and build again".
- Or the check accepting a unit whose `.d` file names the same relative path under another
  root, as Cargo does.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, with `bun exact.mjs ios` for the iOS Simulator.

## Seen again: a second failure after the first is fixed (2026-11-02, `ed43ad09a0`)

A second agent hit the same copy in its own worktree, and after the dep-info error a second one
followed from Swift's module cache. Its notes, as written:

### What happens

Two agents work on one app at the same time, each in its own git worktree. To skip the
first build, the second checkout's `target/` was copied from the first one. Then
`bun exact.mjs ios` failed twice:

1. After cargo finished: "no matching rustc unit dep-info for unicode_ident; searched
   target directory <second checkout>/target; rebuild the stale Cargo unit or use a
   private target directory". The `.d` files hold the first checkout's absolute paths, so
   `scripts/cargo-dep-info.mjs` matches none of them. The message does not say how to
   rebuild that unit.
2. After those paths were rewritten: Swift refused "precompiled file
   '.../target/apple-swift/ios-simulator-17.0/webarm-module-cache/.../SwiftShims-....pcm'
   was compiled with module cache path '<first checkout>/...', but the path is currently
   '<second checkout>/...'". Deleting the four `*-module-cache` folders under
   `target/apple-swift/` fixed it.

Cost: about 8 minutes. (Deleting the whole `target/` also works, at about 2.5 minutes of
build.)

### What would help

- The build noticing a `target/` that moved (its dep-info or module caches name another
  folder) and rebuilding those parts by itself, or
- the first message naming what to delete (`target/host-dev`, the module caches), or that
  deleting `target/` fixes it.

### Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1355 fixes it: the build error names the path the `target/` folder was built at, and says to delete it and build again.

## Further evidence: cloned native target, 2026-11-12

Reusing an app target through filesystem clones still rejected compilation with
`no matching rustc unit dep-info for unicode_ident`. The diagnostic now correctly
names the old target path and requests a rebuild, acknowledging the earlier fix.
The copied target was moved aside and the official fresh cache seeding used instead.
This cost one rejected build plus a fresh native build; no source workaround was needed.
