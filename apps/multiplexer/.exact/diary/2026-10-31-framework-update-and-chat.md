surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: update the framework checkout by about 1,000 commits, rebuild, and bring the chat sample apps' newer parts into a chat screen

### Rough
- `exact.mjs update` appends `/.exact/` to the app's `.gitignore`, after the app's own `/.exact/*` and `!/.exact/diary/`. The new line ignores the whole folder, so a new diary file is ignored by git (`git check-ignore -v .exact/diary/x.md` names that line), although docs/diary.md and the feedback README keep the diary in git. Removing the line does not last: each `update` appends it again. Cost about 10 minutes. Workaround in the app's `.gitignore`: keep `/.exact/`, then `!/.exact/`, `/.exact/*`, `!/.exact/diary/` after it. What would have helped: `update` not adding the line when the file already ignores `/.exact/*`, or writing the diary exception itself.
- `exact.mjs update` printed `Cargo.lock: does not match the app manifests; run bun exact.mjs lock`, and `lock` then said `current; no changes` (the lock file had already changed). It also prints `app.contract: every file names what it uses`, which reads like a problem; it is the module-scope check passing. A word such as "ok" would help. Cost: a minute, and a grep of the framework's source.
- After the update, each iOS build prints 4 cargo warnings, `patch ... was not used in the crate graph` (accesskit_windows, fontique, parley, wgpu-hal), from the `[patch.crates-io]` block that `update` writes and the app must not edit. They hide a real warning among them. Cost: a minute to see they are not the app's.

### Lean in

### Needed

### Checkpoints
- updating the framework checkout (`git merge --ff-only`, `exact.mjs update`, `lock`): rough (the diary line above)
