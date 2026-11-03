surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: fix two problems found while building a chat app, as pull requests to the framework: a recipe that fails the framework's own checks with a gesture it does not document, and a misleading verify message

### Rough
- Running the framework's own script tests from a worktree: `bun test ./scripts/verify.test.mjs` with the Bun on PATH (1.4.3, newer than the pinned 1.4.2) failed with "Cannot use test outside of the test runner". An imported module calls `ensureBun` (`scripts/bun.mjs`), which runs the process again under the pinned Bun and drops the `test` verb. Cost about 3 minutes. Instead: `~/.bun-1.4.2/bin/bun test ./scripts/verify.test.mjs`. What would have helped: `ensureBun` keeping the verb when it re-runs, or saying which Bun to call.
- A recipe has a 3,072-byte cap (`bun scripts/caps.mjs`), and the chat recipe was already at 3,028 bytes. A swipe-to-reply example written into it (6 KB) had to move to the lookup guide. The cap is documented in the caps script's message, not where a recipe is written. Cost about 15 minutes of rework. What would have helped: the cap in `docs/recipes/`'s own guidance, or a remaining-bytes count from `caps.mjs` for each recipe.

### Lean in
- `verify ios` in a scratch app made with `exact new` against a framework worktree checked a recipe exactly as written, and showed both of its findings before the fix and none after.
- A test's `tap "id" drag 100 0` is a real touch on the simulator, so a documented gesture can carry a test that `verify ios` runs.

### Needed
- gestures (swipe to reply): provided, documented in a pull request

### Checkpoints
- iOS build: smooth (a scratch app's first build about 2.5 minutes)
- driving the app (`exact.mjs agent`, `exact.mjs test`): smooth
