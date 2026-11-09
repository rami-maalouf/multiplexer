surfaces: macos
agent: codex gpt-6.1-sol
task: reduce a native glass crash and prepare upstream tooling fixes

### Rough

- a small glass composer with a conditional send button did not reproduce a crash seen in a larger app. Added a second probe for the animation and grouping conditions; source tracing remains necessary. About 10 minutes reducing the view. A hosted dynamic glass replacement fixture would help isolate platform failures.
- changing a scratch app to another framework worktree rebuilt the Rust graph and Swift host, despite a warm build with the other checkout. Several minutes waiting; existing build-cost feedback applies.

### Lean in

- the standalone app generator made an account-free composer probe possible.
- a carrier-level regression detects stdout pollution, including JSON-shaped module logs.

### Needed

- none

### Checkpoints

- macOS minimal static replacement: smooth, no crash
- carrier regression: smooth, failed before the change and passed after it
- upstream host build: smooth, complete; live state drive passes
- driver suite: 49 passed, 1 browser-dependent test skipped (missing Chromium)
- original full-app send: rough, SIGTRAP reproduced; test account signed out
- reduced glass examples: manual drives pass; authored test SIGTRAP in 1 of 2 consecutive runs. Root cause and reduced stack unproved.
- upstream PRs: opened for docs and stdio isolation; caps passes
