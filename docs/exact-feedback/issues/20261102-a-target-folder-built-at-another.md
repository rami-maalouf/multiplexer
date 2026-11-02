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
