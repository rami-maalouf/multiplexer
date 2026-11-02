# An app checkout at another depth cannot build: EXACT2 does not cover the Cargo paths

**Status:** Open
**Systems:** exact.mjs, Cargo patches
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

An app made with `exact new` names the framework checkout by relative paths in three places:
the workspace's `[patch.crates-io]` in `Cargo.toml`, and the `apple/` and `web/` crates'
dependencies. A second git worktree of the app at another folder depth (a tool made it in its
own folder) cannot build. `exact.mjs` said "no exact2 at <path>: EXACT2 names the checkout",
which was clear, but with `EXACT2` set the build still failed on the workspace's patches, then
on `apple/Cargo.toml`. A symlink at the path the relative paths expect did not pass either: the
patch check compares paths without following symlinks (`outsideWorkspaceProblems` uses
`resolve`, while `pathFrom` uses `realpathSync`), so it printed the same "must name exact2's
vendored ..." refusal. The paths were edited by hand and kept out of git. Cost about 10
minutes and four builds. A worktree next to the first checkout (the same depth) builds.

## What would help

`EXACT2` covering the Cargo paths too (for example written into a generated, ignored file),
or the patch check following symlinks as `pathFrom` does, or the refusal naming the other two
files that need the same change.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`.
