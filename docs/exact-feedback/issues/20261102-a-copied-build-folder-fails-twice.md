# A build folder copied to a second checkout of an app fails twice, and neither message says what to delete

**Status:** Open
**Systems:** exact.mjs ios, scripts/cargo-dep-info.mjs, Apple host build
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

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

## What would help

- The build noticing a `target/` that moved (its dep-info or module caches name another
  folder) and rebuilding those parts by itself, or
- the first message naming what to delete (`target/host-dev`, the module caches), or that
  deleting `target/` fixes it.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`.
