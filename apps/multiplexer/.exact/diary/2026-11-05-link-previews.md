surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: show a preview card (picture, title, site) for a link in a chat message, fetched and cached on the phone

### Rough
- A `resource` declaration that is too long cannot wrap onto a second line: `resource x = load(a, b)` then `as shape X else empty()` on the next line answered "expected `as`, found end of line". Moving the arguments into two `derive`s fixed it. Cost about 1 minute. What would have helped: continuation lines for a `resource` as for a component call, or the message saying "a resource is one line".
- The framework has no link preview (no package or recipe for Apple's LinkPresentation, and no `docs` hit for "link preview"), so the native module fetches and caches previews itself. Cost about 10 minutes of design. What would have helped: a link-metadata capability, as the in-app browser has its own package.

### Lean in
- `firstVisibleKey` on the transcript's `ScrollEvent` was enough to fetch previews only for the rows on screen, with no measuring.

### Needed
- link metadata (title and picture of a web page): by hand (Apple's LinkPresentation in the native module)

### Checkpoints
- editing app.contract / app.ts: smooth but for the resource line (see Rough)
