surfaces: macos
agent: codex gpt-6.1-sol
task: diagnose a toolbar action that ignores a physical click

### Rough

- a filled sign-in toolbar button ignored clicks; Return from the password field worked. About 10 minutes tracing the native toolbar. AppKit forwards an item's action assignment into its custom button; a later sync overwrites the custom button handler. Agent activation sends the toolbar item directly, bypassing the physical-button sender and hiding this failure. Testing real custom-button clicks after a sync would catch it.

### Lean in

- shared submit and press actions made a keyboard workaround available.

### Needed

- none

### Checkpoints

- actual app: click ignored; keyboard submission succeeded
- native regression: failed before the fix (no press dispatched); all 24 HeaderMacTests pass afterward
- caps: pass
- local integration: tested commit applied; corrected app build completed
