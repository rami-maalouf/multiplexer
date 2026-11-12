surfaces: ios
agent: Claude Opus 5.5
task: a chat app's transcript shows a small spinner above the oldest loaded message while older ones load, and says where the chat starts; and an edge swipe back over the messages, driven with real touches

### Rough
- A git worktree of the app outside the folder next to the framework checkout could not build: `exact.mjs` and `package.json` reach the framework by a relative path (`../../../exact/exact2`, `file:../../../exact/exact2/packages/clipboard`). `contract build` said "no exact2 at …/exact/exact2"; with `EXACT2` set, it then said the `@exact/clipboard` package was not installed, and `bun install` failed with "Could not find folder". I made a new worktree next to the main checkout instead. About 5 minutes. What would have helped: `package.json`'s framework packages following `EXACT2` too, or the first message naming both paths.
- A chat that opens at its "New" line never loaded older messages: `reachstart` fired once, at the list's first frame, while the app held loads back until the line was placed, and the list never fired again, because its top row stayed within reach. The logs showed the one `reachstart`. No doc says that the list asks once until its top leaves the reach margin. I kept a "wanted" flag and made the load when the line was placed. About 15 minutes and three builds. What would have helped: a line in the reference ("Intersection visibility") saying when `reachstart` fires again.
- My first fix called `loadOlder()` from `donePlacing`, after `placing = false`; the call read `placing` as true and held the load back again. `contract-for-agents.md` says so ("the callee reads the state the action started with"); I had not read it. About 5 minutes and one build.
- `screenshot … over … every …` is refused under `--timing platform` ("film is the agent clock's"), so the frames after a real edge swipe could not be filmed; I read the navigation log instead. About 2 minutes.

### Lean in
- `[Message(f, id="~older")].concat(thread.messages)` gave the transcript a marker row with no change to the data module: the shape's copy-with-replacement call made a full row from the first message.

### Needed
- a request a virtualized list made while the app could not serve it: by hand (a flag, served later)

### Checkpoints
- As a test user, in a chat with 50 messages that opens at its "New" line: before, it stayed at 20 messages; after, the spinner row showed at the top, the chat loaded to 50, and "Start of the chat" showed above the first message; the line stayed in view. `check` clean in light, dark and the largest text size.
- A real edge swipe from x 2 at a bubble's height went back, with no reply started (four runs).
