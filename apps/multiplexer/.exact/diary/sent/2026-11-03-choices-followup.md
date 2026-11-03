surfaces: ios
agent: Cursor, Claude Opus 5.5
task: five small follow-ups to the owner's choices: "Sent" instead of "Delivered", a message menu that hides Edit and Delete after a network's time limits, a middle dot in a subtitle, a deleted chat that comes back with only its new messages, and our own message bringing an archived chat back

### Rough
- A time rule (Edit shows for 15 minutes on one network) wanted a pure function with unit tests. A contract `fn` has no unit test: `docs "unit test"` answered with the toolchain's own `bun test ./scripts/` line, `docs "test a fn"` found nothing, and `contract vocab test` pointed to the tests recipe, whose tests all drive the UI from a fresh launch. A UI test cannot reach the rule here (it needs a signed-in account and a chat on that network). Workaround: the limits went into a TypeScript module (`limits.ts`, tested with `bun test`), the data module adds each message's "until" times, and the contract keeps a one-line `fn within(until, now)` that repeats the module's rule, because a contract cannot call a TypeScript function. About 6 minutes. What would have helped: `test` blocks for a contract's `fn`s (inputs, expected value), or a doc line saying where a pure rule should live to be unit tested.

- Holding a list row in a drive: `tap "<row name>" contextmenu` scrolled the row into view near the bottom of the window (`scrolled={"from":[190,2586],"to":[190,645]}`), and the menu that opened under it was cut off: `tap menu-archive` answered "its middle is outside the viewport; scroll it into view first", with no way named to scroll the menu. Known finding (a menu row below the fold), new evidence at the default text size. Workaround: a new message made the row the list's first, then the hold worked. About 2 minutes.

### Lean in
- `--epoch <ISO>` on `agent ios` set the app's clock to 20 minutes and 49 hours after a real message, so one drive each showed the menu with Edit gone, then Edit and Delete gone, without waiting.
- `clock until state roomList.rooms.0.name == "…" within 45000` waited for a message sent from a script in the background, and the chat came back in the same drive.
- `state roomList.rooms` over 8 KB said how to read one item or `--full`, instead of cutting the JSON.
- `verify ios` rebuilt only what changed (5.8 s) and was clean on the first run.

### Needed
- Unit tests for a contract `fn` (see Rough).

### Checkpoints
- `bun test ./limits.test.ts`: 3 passed.
- The app's core library: the whole suite 45 run, 1 skipped, 0 failed (two new tests: a deleted chat comes back with only its new messages; our own message brings an archived chat back, a muted one too).
- Drives as a test user: "Sent" under our own message; the menu in a chat on the limited network at the real time (Edit and Delete), 20 minutes later (Delete only) and 49 hours later (neither); a plain chat at 49 hours (both); a chat deleted and brought back by a new message shows only it; an archived chat came back after our own message; the info page's subtitle with "·". Signed out at the end.
- `verify ios`: clean (5 tests, light and dark, the largest text size).
