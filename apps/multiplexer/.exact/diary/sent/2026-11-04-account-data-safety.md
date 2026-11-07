surfaces: ios
agent: Claude Opus 5.5
task: in a chat app's core library, changes of the account's own data start from the server's copy on a new device; another device's saved item reaches the list without a timer; what the server would notify, checked from its push rules

### Rough
- Nothing from the framework. The work was in the app's core library and its server tests.

### Lean in
- A data source that lists by a module's topic (`native.watch`) let the app drop its once-a-minute reload: one argument fewer in the resource, and the list follows the module's change.

### Needed
- none (no new platform capability)

### Checkpoints
- editing app.contract / app.ts: smooth
- iOS build: smooth
- driving the app (`verify ios`): smooth; clean (6 tests)
