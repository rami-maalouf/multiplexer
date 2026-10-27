surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: a native module finishes a network call in the background after launch (no request from the view), and a drive checks it

### Rough
- A drive could not wait for the module's background work: `clock data` waits for requests the data module made, and this work had none. Used `"clock +4000 real"` and then `logs` to see the module's `print`. ~3 min, and the drive now has a fixed real-time wait, which the docs say never to write. What would have helped: a way for a module to say it is busy (`context.busy { … }`, or a ticket), which `clock data` waits for and its reply names.

- The module keeps a secret in the Keychain that must live and die with the app's data; under the agent, a test's fresh storage clears the data but not the Keychain (already in an earlier diary). The fix in the module was to treat "a Keychain item whose data folder is gone" as stale and clean it up at the next launch. ~0 min this time, but every module with a Keychain item needs the same logic. What would have helped: `context` saying the storage was reset, or a `context.keychainService` that the agent clears with the data.

### Lean in
- `logs` showed the module's `print` from a drive, so the background work was visible without a debugger.
- `call` on the main thread is the right place to read the Keychain at launch; the 100 ms budget pushed the network work into a background task, which is the better design anyway.

### Needed
- none

### Checkpoints
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): rough (no wait for module background work; see Rough)
- `verify ios`: smooth (clean)
