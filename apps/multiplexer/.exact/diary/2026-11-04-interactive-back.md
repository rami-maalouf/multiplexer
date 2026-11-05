surfaces: ios
agent: Codex GPT-6 Astra
task: reproduce interactive back layout corruption

### Rough
- A native tap on a list row failed with "the screen rotated or moved since aim" while live data settled. Bringing the row into view by key and waiting before the tap worked (about 2 minutes).
- A compound drag with an embedded state read was parsed as a target and refused. Removing the embedded read let the same native reversed path run; state was read after release instead (about 2 minutes).
- The updated native module build took several minutes; the drive correctly waited for it.
- Tracing a sideways row drag required reading the native press responder, scroll delegate and collection contact observer. The row keeps its press while the touch remains inside; cancellation currently depends on another recognizer taking the contact. The collection observer deliberately never cancels. Native left/right drags activate on lift while the vertical control scrolls. A responder regression is prepared; production code remains unchanged pending its failing run and recognizer evidence.
- The isolated framework build stopped at `failed to download accesskit v0.25.2` because its metadata command uses `--offline`. Fetching the locked dependencies allowed the build to proceed. A cold-worktree prerequisite message naming the fetch command would help.

### Lean in
- Multi-leg native drags support reversing a single finger before release.
- Navigation logs distinguish an edge swipe, cancellation return, and completed pop.

### Needed
- interactive navigation: provided, under investigation

### Checkpoints
- baseline: one reversed/cancelled swipe retains the room; one completed swipe returns home. Settled screenshots show no corruption. Transition recording retained for inspection.
- feedback: local only
- framework work is isolated in `exact2-navigation`, branch `local/interactive-navigation`, based on `ed43ad09a0`; the normal checkout and earlier separator experiment remain unchanged.
- the lane is signed out, its simulator is shut down, and it holds no authentication lock. Further native runs wait for the coordinator's explicit slot.
- first focused host execution did not reach the regression assertion: the manually linked archive was the standalone bake and panicked with `no __TEXT,__exact_compat`. This was test setup, not a defect failure. `/tmp/mx-row-red.log` and `.xcresult` retain it. The direct Cargo staticlib rebuild now emits `include_bytes!` for the plan and `include_str!` for compatibility data; test relinking is pending. The simulator was shut down and the owned lock released before rebuilding.
- corrected baseline execution reached the assertion and failed in 3.233 seconds: left/right/reversal produced three row activations instead of none; the subsequent small-movement tap activated once. `/tmp/mx-row-red-embedded.log` and `.xcresult` preserve this true red result. Embedded archive sha256: `c8b8a05b8fa0846ece4895e0d27142bef29331cff408821def5937002941360a`.
- the isolated candidate cancels only a row's own press after travel exceeds the existing gesture slop. An embedded-button drag-out/back control was added. Build-for-testing passed; candidate test executable sha256: `fcf41a9265707760a17d88a3405ceb4a2f62f4e8561c26c109cf43d09d01882f`. Fresh scoped review found no concrete defects. Green runtime and native gestures remain pending; the slot was released and the simulator shut down for rebuilding.
- green runtime: 83 tests ran, 77 passed, six scene-dependent tests skipped, zero failures (8.882 seconds). Both new row tests passed. The skips concern keyboard-preserving focus, sheet/autofocus handoff, selected-row frame appearance and a reorder ghost; callback tests do not replace native gesture proof. `/tmp/mx-row-green.log` and `.xcresult` retain the exact run. No login occurred; size large restored, simulator shut down, owned auth lock released.
- the app refused the isolated framework until generated dependency paths matched. `exact update` changed only the lane's generated paths and schema reference; this build-only churn is separate from authored fixes. App build is running with `--no-install`, without holding an auth slot.
