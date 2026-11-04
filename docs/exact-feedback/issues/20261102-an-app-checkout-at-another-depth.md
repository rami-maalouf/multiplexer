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

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1346 (fixes part of it): the patch check compares paths through symlinks. A checkout at another depth still needs its own Cargo paths: a design question.

## More evidence (2026-11-03)

Seen again in a new worktree of the app: `exact.mjs` stopped at "no exact2 at …", and with
`EXACT2` set the build stopped on the workspace's patches, then on `apple/Cargo.toml`. A symlink at
the expected place passed the patch check but failed later: "compiler input has no captured source
identity: <symlinked path>/packages/child-process/exact.json". The app's `package.json` names the
framework's packages by the same relative path, so `bun install` cannot install them there either.
Absolute paths in the three `Cargo.toml` files, kept out of git, worked. About 10 minutes and
three builds. Seen at exact2 `ed43ad09a0`.

A git worktree made by a desktop tool under `~/.t3/worktrees/<project>/<name>/` (not a sibling
of the main checkout) failed before the Cargo check: `bun install --frozen-lockfile` cannot find
the four `file:../../../exact/exact2/packages/...` packages in `package.json`, so `contract
build` refuses `use … from "@exact/clipboard"` as not installed. `EXACT2` does not change those
paths. A symlink to the framework's parent folder beside the worktrees fixed the install, then
`ios` refused the app: the patch check wants the path from the real folder
(`../../../../../../Documents/code/...`), with `EXACT2` set to the symlinked path too (PR #1346,
open, is not in `ed43ad09a0`). The branch moved to a worktree beside the main checkout and built
there from scratch. About 15 minutes and a cold build. The `package.json` paths are not covered
by PR #1346.

At `ed43ad09a0`, in a second worktree at another depth, `bun exact.mjs update` rewrote the paths
in `Cargo.toml`, `apple/Cargo.toml` and `web/Cargo.toml`, but not `package.json`'s `file:` paths
to the framework's packages: `bun install --frozen-lockfile` then failed with `Could not find
folder "file:../../../exact/exact2/packages/clipboard"`. The paths were edited by hand and kept out
of git (`git update-index --skip-worktree`), with `bun.lock`. About 5 minutes.
