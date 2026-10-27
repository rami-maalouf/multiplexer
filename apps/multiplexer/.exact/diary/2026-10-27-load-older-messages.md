surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: load older chat messages when the reader scrolls up a transcript (`reachstart` on a virtualized list), keeping the reader's place

### Rough
- A virtualized list takes exactly one direct keyed `for` (`contract vocab reachstart`: "only on `list virtualized=true` with one direct `each`"). So a transcript has no place for a row above its messages: a spinner while older messages load, or "This is the beginning of the chat" once there are none. The app shows neither. ~3 min to decide. The workaround would be fake rows in the data module's list. What would have helped: a header or footer slot on a virtualized list, outside its `for`, or a recipe line saying how a chat shows that it is loading older messages.

### Lean in
- `reachstart=loadOlder` on the existing transcript was the whole wiring, and `contract vocab reachstart` said exactly what the list needs.
- Twenty rows inserted above the view kept every visible row where it was (`tree --ax` frames of 9 rows, the same before and after the load).

### Needed
- none

### Checkpoints
- editing app.contract / app.ts: smooth
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): smooth
