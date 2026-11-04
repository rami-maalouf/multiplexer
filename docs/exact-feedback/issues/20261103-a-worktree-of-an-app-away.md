# A worktree of an app away from the framework checkout cannot build its framework packages

**Status:** Open
**Systems:** exact new, packages
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An app made by `exact new` reaches the framework by relative paths: `exact.mjs` defaults to
`../../../exact/exact2` (`EXACT2` overrides it), and `package.json` names the framework's packages
as `file:../../../exact/exact2/packages/clipboard` and so on. A git worktree of the app's repository
in another folder (one an agent tool made under its own directory) could not build:

- `contract build` said "no exact2 at …/exact/exact2 (no scripts/app-cli.mjs): EXACT2 names the checkout";
- with `EXACT2` set, it said the package `@exact/clipboard` "is declared in … package.json but not
  installed: run `bun install --frozen-lockfile`";
- `bun install --frozen-lockfile` failed: "Could not find folder "file:../../../exact/exact2/packages/clipboard"".

I made a new worktree next to the main checkout, where the relative paths hold.

Cost: about 5 minutes.

## What would help

- The packages' paths following `EXACT2` too, or the "not installed" message saying that the
  package's folder does not exist at that relative path.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.

Seen again on 2026-11-03 at `ed43ad09a0`, in another agent tool's worktree: `bun install` failed
with the same "Could not find folder" for six framework packages. The same fix (a worktree next
to the main checkout). About 3 minutes.
