surfaces: ios
agent: codex
task: move an external app to the upstream framework checkout

### Rough

The generated update refreshed the launcher and Rust paths but left file-based JavaScript package dependencies pointing at the previous checkout. Those package paths were updated and Bun regenerated the lockfile. An update report identifying remaining package references would help.

### Lean in

The upstream updater preserved authored app code and refreshed its generated integration. Contract compilation passed with no errors. The existing short-transcript keyboard and changed-scroll-port fixes and their tests are present in upstream source.

### Needed

- native modules: provided; existing Swift package integration retained

### Checkpoints

- integration regeneration and Contract compilation: smooth
- iOS simulator build: smooth
- all 12 authored signed-out iOS tests: smooth
- frozen Bun install: smooth

No account was authenticated and no messaging or production push behavior was exercised. The first test invocation correctly refused a stale build because package paths were updated during compilation; rerunning built the final inputs and passed. Physical-device delivery and signed-in visual parity remain unqualified.
