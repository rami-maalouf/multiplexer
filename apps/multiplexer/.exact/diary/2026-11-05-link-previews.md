surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: show a preview card (picture, title, site) for a link in a chat message, fetched and cached on the phone

### Rough
- A `resource` declaration that is too long cannot wrap onto a second line: `resource x = load(a, b)` then `as shape X else empty()` on the next line answered "expected `as`, found end of line". Moving the arguments into two `derive`s fixed it. Cost about 1 minute. What would have helped: continuation lines for a `resource` as for a component call, or the message saying "a resource is one line".
- The framework has no link preview (no package or recipe for Apple's LinkPresentation, and no `docs` hit for "link preview"), so the native module fetches and caches previews itself. Cost about 10 minutes of design. What would have helped: a link-metadata capability, as the in-app browser has its own package.
- A `press` on a `column` inside the chat bubble (a `box` that has `swiperight` and `contextmenu`) did nothing on iOS: the real tap landed on the card, no press ran, and neither `contract build` nor `check` said why. `press` on the `box` itself did not fire on a tap either (only at the end of a drag). Making the bubble a `button` (as the photo bubble's swipe component is) gave the tap, the swipe and the long press together. Cost about 25 minutes and five drives. What would have helped: a compiler or `check` line "press on a box/column inside a swipe target never runs; use a button that holds all three" (related to the known finding on a press inside `swiperight`).
- In a drive, a tap that opens the in-app browser shows nothing in `screenshot … window`, for a card and a plain link alike; only the log's continuation showed the request went out. Cost about 10 minutes. What would have helped: the drive naming the presented browser (as it names a presented sheet), or a `state` for it.
- `firstVisibleKey` named the transcript's synthetic first row (a key that is no message), so the window of rows on screen fell back to the wrong end until I handled that key. Cost about 5 minutes. This one is the app's (its own synthetic row), noted for context.
- `check` (and so `verify ios`) holds white text on the platform's own blue (`#007aff`, 4.0:1) to 4.5:1 when the blue is a chosen hex, though it accepted the same pair as `AccentColorText` on `AccentColor`; a bubble's paragraph with no colour of its own was measured in the default label while its runs drew another ink. No way to mark a deliberate pair, so `verify` now reports 4 findings the app means. Cost about 10 minutes. What would have helped: the same platform-pair rule for a chosen fill and its 3:1 large-surface ink, or a way to accept a pair with a reason; and `check` measuring the runs' ink.

### Lean in
- `verify`'s `lower-row-lookup` warning named the cost (rows times items) and the fix (join in the data module).
- `firstVisibleKey` on the transcript's `ScrollEvent` was enough to fetch previews only for the rows on screen, with no measuring.

### Needed
- link metadata (title and picture of a web page): by hand (Apple's LinkPresentation in the native module)

### Checkpoints
- editing app.contract / app.ts: smooth but for the resource line (see Rough)
- iOS build: smooth (cold about 4 minutes after the disk was cleared; a passing code-signing error once)
- driving the app (`exact.mjs agent`): rough (a press inside the bubble, the browser not in screenshots; see Rough)
- properties (`verify ios`): smooth, clean after the row-lookup fix
