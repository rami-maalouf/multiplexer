surfaces: macos
agent: codex gpt-6.1-sol
task: stop an AppKit layout crash when a composer changes after sending

### Rough

- a normal Mac launch crashed when the person sent a message. Crash report records SIGTRAP on the main thread in AppKit layout. Earlier test-account sends crashed too. Native glass grouping is the leading suspect; testing the composer without its group before choosing a repair. Existing finding 157.
- `glassGroup` refuses an optional number (`lower-attr-type`), so it cannot be conditionally absent on one platform. About 3 minutes checking the slot docs; a small slot wrapper selects grouped and ungrouped rows while sharing the controls. An optional group attribute would avoid this wrapper.

### Lean in

- contract-only changes can run on an existing agent binary without rebuilding native modules.

### Needed

- none

### Checkpoints

- normal-app reproduction: user-reported closure; SIGTRAP crash report verified
- group-removal control: three sends survived
- contract/TypeScript gate: pass
- Mac authored tests: all pass; TypeScript tests: 13 pass
- final native build: five consecutive sends appeared, then test account signed out
- screenshots: light/dark inspected; previous chrome overlaps remain
- ios: original grouping retained in code; no new native runtime test this turn
