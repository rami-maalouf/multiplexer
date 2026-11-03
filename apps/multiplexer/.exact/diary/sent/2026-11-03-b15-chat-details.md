surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: a chat transcript's details: a "new" line at the first unread message, a jump-to-latest button with a count, read receipts under the newest message, day labels, large emoji-only messages, stickers, tappable links, and a video message that plays full screen

### Rough
- `font-size="min(2.75rem, 60px)"` on a `text` was refused: "is not a valid `font-size`: expected number". The same app compiles `font-size="min(-exact-headline, 20px)"`, so `min()` works with a type token and px but not with rem. Wanted: large emoji that grow with the reader's text size, to a cap. Used a plain `font-size="2.75rem"` (no cap; to check at the largest text size). About 2 minutes. What would have helped: `min()` taking rem as it takes a token, or the message naming which units `min()` takes here.
- A `members` file's rules (contract-grammar, "Components and actions") say it "holds one `members` block" and takes shapes, `fn`s and components from its own `use` lines, but not whether the same file may also declare the components and `fn`s its members use. Wrote two files (one of components, one of members) rather than try. About 2 minutes. What would have helped: one sentence saying yes or no.
- A link in a bubble broke inside its address with a hyphen added on iOS (a domain as "some-" / "site.com", a path as "Ma-" / "trix"), so the address on screen read as another one. The bubble's paragraph has `overflow-wrap="break-word"`; on iOS Exact then inserts emergency hyphens (`ParagraphGeometry.insertsHyphens`: `hyphens == manual && wrap == break-word`). The docs say `manual` breaks only at soft hyphens, so the hyphen was a surprise. `hyphens="none"` on the link's inline run changed nothing: the paragraph's `hyphens` counts, a run's is dropped without a warning. `hyphens="none"` on the paragraph fixed it. About 15 minutes (two drives, then reading Exact's source to find the rule). What would have helped: the `hyphens` docs saying that iOS hyphenates a `break-word` paragraph's overlong words, a warning when an inline run sets `hyphens`, and no emergency hyphen inside a run that is a link (a URL is never hyphenated by Safari).
- `bun exact.mjs contract vocab members` answered "`members` is not a tag, an attribute, a standard function, a recipe or a pattern". The rule came from grepping contract-grammar and an example app. About 3 minutes (part of the entry above).
- A native glass button (`buttonStyle="glass"`) refused a badge beside its symbol ("a native button shows `text`s and one `image`"). The message named the fix (`appearance="none"` and my own face); the custom face with `backgroundMaterial="glass"` worked at once. About 2 minutes; noted because the badge is a common jump-to-latest design.
- A drive could not show a video's controls: `tap <video testId>` activates the node, and AVKit's controls never showed in a screenshot. Under `--touch platform` the same tap showed them. To learn whether the video played, `state media` (renderer, paused, currentTime, muted, volume) is the answer, but it is only in the video LLP, not in `agent --help all` or the media docs. The controls' speaker showed a slash while `state media` said not muted: under the agent a video never takes the audio session (the host's `VideoModule.swift`), so a drive cannot prove a video's sound. About 10 minutes.
- `verify ios` between drives ran its tests in a fresh store; the app's native module found the drives' Keychain session without its data and signed it out (the app's own design for a secret kept outside Exact's store). The next drive waited 30 s for a chat that never loaded before `state session` showed it signed out. About 3 minutes and one more sign-in.
- `check both` called a video poster scrolled under the app's own top bar an overlap with the bar's title and Back (the known finding about app-drawn floating bars). About 2 minutes.

### Lean in
- A `members` file kept the shared root's diff small: the feature's state, resources, mutation, tasks and actions live in their own file, and the root changed only in its shapes, one route, its transcript rows and one `members` line.
- `video path controls=true autoplay=true playsinline=true` in a full-screen route gave AVKit's player with its scrubber, ±10 s, AirPlay and full screen, zoomed out of the poster's box by `navigationSource`; `state media` then reported AVKit, the time and the size.
- The in-app browser package took one `package.json` line and four lines of Contract; under the agent its request is held as a ticket, so a link tap is provable without opening Safari.
- Inline `text` runs with `press` inside a paragraph gave tappable links that wrap with the text, with their own colour and underline.
- A `slot` turned the bubble into a box with a tail around any content, so the plain bubble and the bubble with links share one drawing.
- `clock until state ... within` and `clock +60000 real` waited for a read receipt that another account sent from a script while the drive held the chat open.
- `verify ios` named the one fixed-size glyph (the play mark) and was clean after a one-line fix; its largest-text pass found nothing that spilled.

### Needed
- video playback: provided (`video` with AVKit controls; the playback audio session from `app.json`)
- in-app browser: provided (a package)
- links in text: by hand (finding addresses in the data module; inline runs are provided)
- large emoji: by hand (detecting one to three emoji in the data module)
- day labels: by hand (`formatDay` and day arithmetic)
- haptics: not needed

### Needed

### Checkpoints
- editing app.contract / app.ts: rough (`rem` in a font size's `min()`, the members file's rules, iOS hyphens in a link: see Rough)
- iOS build: smooth (each Swift edit rebuilds the vendor bindings, about 45 s, as known)
- driving the app (`exact.mjs agent`, `exact.mjs test`): rough (a video's controls and state, a session lost to `verify`: see Rough)
- `verify ios`: smooth (one finding, fixed; then clean in 47 s)
