surfaces: ios
agent: Codex GPT-6.1 Sol
task: move an existing native session store into a shared container without losing its keys

### Rough
- `verify ios` announced about 85 seconds, then needed a native rebuild for a Swift module edit. The build took 83.0 seconds (63.8 seconds in host arms) and the whole verify took 155.0 seconds. During the rebuild the public log stayed at "the app's Swift modules compile as they are now" until compilation ended. Kept the build running and inspected its log. Existing finding "module Swift recompiles vendor bindings" applies; cached vendor compilation and stage progress would help.

### Lean in
- the native module can keep the container policy in a small Swift package helper, independent of the view and data module.
- `verify ios` passed six tests, checked light and dark, and found no overflow at the largest text size.

### Needed
- app group storage: by hand (native module and shared Swift package; actual group entitlement still gated on signing setup)
- secure session persistence: by hand (existing keychain wrapper, updated in place)

### Checkpoints
- iOS build: rough (see Rough), successful in 83.0 seconds
- driving the app: smooth; a test user's session restored on relaunch, and sign-out deleted only its own store
- `verify ios`: smooth; six tests passed, no findings, clean in 155.0 seconds
- notification extension source check: smooth; shared core and the extension type-check together
