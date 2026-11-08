# Running a framework script's tests with a newer Bun fails: ensureBun drops the test verb

**Status:** Open
**Systems:** scripts (bun.mjs, verify.test.mjs)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

In an exact2 worktree, `bun test ./scripts/verify.test.mjs` with the Bun on PATH (1.4.3, newer
than the pinned 1.4.2) failed with "Cannot use test outside of the test runner". A module the
test imports calls `ensureBun` (`scripts/bun.mjs`), which runs the process again under the
pinned Bun, and the new process does not get the `test` verb. Cost about 3 minutes.

## What would help

`ensureBun` keeping `bun test` (or any verb) when it runs the process again, or a message that
names the pinned Bun to call (`~/.bun-1.4.2/bin/bun test ...` worked).

## Evidence

Seen on 2026-11-02 at exact2 `880d4f8652`, while preparing pull request
https://github.com/ccheever/exact2/pull/1325.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1345 (fixes it): under `bun test`, `ensureBun` names the pinned Bun to run the test file with.

## Seen again (2026-11-03, `574720f370`)

`bun test ./scripts/agent-keys.test.mjs` in exact2 with Bun 1.4.3 on PATH: "Cannot use test outside
of the test runner". `~/.bun-1.4.2/bin/bun test …` ran it. About 3 minutes.

## More evidence, 2026-11-07

At framework commit `eddc967dc3`, `bun test scripts/agent.test.mjs` under Bun 1.4.3 re-executed under pinned Bun 1.4.2 and failed with `Cannot use test outside of the test runner`. Directly invoking the pinned binary passed all 49 tests in 2.46 s. About one minute lost.
