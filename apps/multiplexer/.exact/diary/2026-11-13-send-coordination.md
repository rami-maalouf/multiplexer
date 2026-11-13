surfaces: ios
agent: codex gpt-6-astra
task: coordinate optimistic message insertion and send motion with an existing composer layout

### Rough
- importing the data entry point directly under bun failed because native package exports resolve to exact.json manifests (about 2 minutes). boundary tests need native-package mocks; a documented data-source test harness would help.

- a resource in a members file could not name a root shape without a cycle. the compiler explicitly named the cycle and remedy; moving the resource to the root fixed the declaration (about 1 minute).

- the native rebuild seeded the registry cache but still recompiled framework and module code for several minutes. the log was quiet between phase boundaries; an elapsed phase/progress indicator would help distinguish compilation from a stall.

- a direct bottom-anchor formula using the conversation frame did not match the displayed absolute flight in a keyboard-toolbar layout. a recording exposed an overshoot and final handoff jump. calibrating from the flier's measured frame removed the final jump in the inspected recordings; a recipe explaining absolute coordinates across keyboard toolbars would help.

### Lean in
- the template demonstrates how an overlay inserts a row in the same update that begins its flight.

### Needed
- keyboard geometry: by hand, reuse a native measurement for a keyboard toolbar.
- optimistic data: provided, overlay.

### Checkpoints
- editing app.contract / app.ts: rough, native-package mocks and shape ownership above.
- iOS build: rough, long silent build stages above.
- driving the app: smooth, native regression drives covered replies, rapid sends and navigation.

- native verification: smooth, authored tests and appearance checks passed.
