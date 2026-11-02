surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: show encrypted chat messages, with a placeholder for a message the device cannot read yet

### Rough
- none

### Lean in
- One more string-free field on the message shape (`waitingForKey: bool`) and an `else if` in the transcript row gave the placeholder bubble; `check` was clean in light and dark the first time.

### Needed
- none

### Checkpoints
- editing app.contract / app.ts: smooth
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): smooth
