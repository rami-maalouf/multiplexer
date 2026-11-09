surfaces: macos
agent: codex gpt-6.1-sol
task: add a contact picker that starts a direct conversation

### Rough

- determining how a new detail route stays beside the sidebar required reading the Mac split host source; the responsive-columns guide points to a pattern rather than a matching recipe file. A guide stating the route/split invariant would avoid this source lookup. Time not measured.

### Lean in

- native keycapture already provides separate application shortcuts.

### Needed

- keyboard shortcuts: provided
- native contact and chat data: by hand in the existing native module and shared core

### Checkpoints

- editing contract and data module: smooth; Contract/TypeScript gate passes after removing explicit styling from a native list action.
- shared native core: 15 focused protocol fixtures pass, plus authenticated direct-room creation or reuse and mapping preservation.
- macOS build: smooth after available disk capacity was restored; dependency rebuilds remained slow.
- driving the app: native authored tests pass 13/13; actual contact-picker selection, composer send, separate shortcuts and cancellation inspected in light/dark at two widths. A drive requires `tree`/`state`, not authored-test `expect` steps.
- feedback: retained locally; no new diary was sent.
