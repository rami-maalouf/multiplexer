surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: move an app outside the exact2 repo to the latest exact2

### Rough
- `git pull --ff-only` in exact2 failed: local `main` and `origin/main` had diverged (183 local, 209 remote commits), the second history rewrite in one day. A check of commit subjects showed 177 of the 183 on the remote under new hashes; the other 6 were a purged transcript and two housekeeping commits. Made a backup branch, then `reset --hard origin/main`. ~8 min. An app that uses exact2 by path has no safe way to follow a rewritten `main`. What would have helped: `bun exact.mjs update` (or a note in its help) saying "exact2's history was rewritten; back up and reset", or a stable tag to follow.

- After `bun exact.mjs update`: "Cargo.lock: does not match the app manifests; run `bun exact.mjs lock`". `bun exact.mjs lock` then said "current; no changes", yet git showed Cargo.lock changed (2 lines). ~2 min to work out that `update` had written it already. What would have helped: `update` saying it rewrote the lock, or `lock` not reporting "no changes" for a file that `update` just changed.

### Lean in
- `verify ios` rebuilt on its own ("the build is older than its sources … 44 more changed") and was clean in 105 s, so moving 209 commits needed no app change.
- The command log (`.exact/commands.jsonl`) keeps no arguments, so a drive that typed a password from a shell variable left no secret in it.

### Needed
- none

### Checkpoints
- updating exact2: rough (rewritten history; see Rough)
- `update` / `lock`: rough (a misleading lock message), then smooth
- iOS build: smooth (62 s after the update)
- `verify ios`: smooth (clean)
