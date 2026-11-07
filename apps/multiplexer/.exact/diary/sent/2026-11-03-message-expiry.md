surfaces: ios
agent: Claude Opus 5.5
task: a chat app's info page gets a "Message Expiry" row (disappearing messages): the timers a bridged network offers, the chat's current one, and a menu to change it for everyone

### Rough
- A drive without real touches drew the row's popover menu as bare rows over the page, as finding 94 says; `--touch platform` with `screenshot … window` showed the system menu. About 2 minutes, knowing the finding.

### Lean in
- `lower-count-plural` in `verify ios` caught "1 Days" in a timer's name and named the fix (`${n} ${n == 1 ? "Day" : "Days"}`).
- A popover menu outside the list, opened by a row's `popovertarget`, gave the system's menu with a check on the current choice and no extra code.

### Needed
- a choice menu from a list row: provided (popover menu)

### Checkpoints
- The app's core library: a new test reads a chat's timers from the bridge's room features, sets one in the bridge's own form, refuses a timer the network does not take, and clears it.
- Drives as a test user, in a room where the test posts the bridge's features: Off, the menu, 7 Days with its footer, back to Off; `check both` clean, and clean at the largest text size.
- A real WhatsApp chat (an allowed test chat of the account): the timer was set and reset through the server's API; the bridge posted no failure notice.
- `verify ios`: clean (6 tests). `bun test`: 7 passed.
