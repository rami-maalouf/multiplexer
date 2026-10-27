surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: live updates from a native module (the module calls `context.changed`, the data module's sources `native.watch` per topic) and a drive that waits for a pushed change

### Rough
- `"clock until state thread.messages.19 .body == \"x\" within 45000"` was refused with only the grammar: "clock until state <path> == <literal> within <ms> (the literal is JSON …), not `…`". The path form `expect state` needs, a space after a list index (`lib.notes.0 .title`, as `docs/start-here.md` teaches), is wrong here: `clock until` takes `thread.messages.19.body`. ~3 min and one wasted drive with a real sign-in. What would have helped: both steps accepting the same path form, or the refusal saying "write the path without spaces: thread.messages.19.body".

- A drive that ended with `"screenshot after.png compare before.png"` failed at its second step, `tap <a row>`: "no view matches … targets here: sign-in, server, user, password". The app was signed out, because a drive that compares starts its store empty (`docs/recipes/ios-driving.md` says so in one line). So a step at the end of a drive changed how the drive began, and the refusal did not say why the screen was different. ~5 min, and the module saw its data reset. What would have helped: the drive printing at its start "store started empty: this drive compares", or `compare` not emptying the store when `--keep-storage` is given.

- A transcript (`list appearance="none" virtualized=true scroll-start="end" scrollFollowEnd=true`, rows keyed by message id), scrolled up about 200 points from its end. One data update removed its first row (far above the view) and appended a row at its end. Every visible row moved up by one row's height (40 points; `tree --ax` frames before and after). `docs/contract-for-agents.md` says rows "inserted, removed or resized above what the reader sees keep the reader's place". After the app stopped removing rows, an append alone kept every row in place. Not isolated further: seen once, in an update that both removed and appended. ~10 min to measure.

### Lean in
- `context.changed(topic)` from the module and `native.watch(topic)` in the source were all the wiring a live list needed; per-chat topics (`thread:<id>`) worked as plain strings.
- `clock until state … within` waited in real time for a change another device pushed, with the clock frozen.

### Needed
- none

### Checkpoints
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): rough (`clock until` path form; see Rough)
