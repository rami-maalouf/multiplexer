surfaces: ios
agent: codex gpt-6.1-sol
task: integrate reviewed changes and publish an iphone preview

### Rough
none so far; git conflict resolution and third-party browser availability are outside framework feedback.

### Lean in
- the existing production archive wrapper includes a notification extension without changing the app view layer.

### Needed
- iphone archive: provided
- app extension packaging: by hand (existing post-build wrapper)

### Checkpoints
- contract and typescript check: smooth
- ios native rebuild: smooth; uses the shared framework without editing it
- native verification: smooth; 14 authored tests and light/dark plus largest text checks passed.
