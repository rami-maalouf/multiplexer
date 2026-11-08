surfaces: ios
agent: Claude Opus 5.5
task: a chat app's read-only pass with a real account's data: the inbox, filters, archive, search and five chats, then small layout fixes (one-line names, row lines from the name, search rows, the search field's size, a dark bottom edge)

### Rough
- A drive's tap on the filter button (a `popovertarget` menu), then `screenshot ... window`, showed the menu as bare blue words over the rows. I took it for a fault and spent about 6 minutes on a check with real touches (a second sign-in) before I saw that the system's menu is drawn right. `--touch platform` would have shown it at once; the drive's output did not say so. Known as finding 94.
- `state roomList.rooms` answered "93.9 KB, over the 8.0 KB printed whole ... all of it: \"state roomList.rooms --full\", or --json". I put `--json` in the step: it printed the same notice. The agent's own `--json` flag gave JSON lines, the third being the bare list. About 4 minutes.
- `verify ios` between two drives left the drives' kept session signed out: the next drive, which expected the signed-in account, met the sign-in screen. I signed in again (about 3 minutes) and checked that no device was left on the server.

### Lean in
- A row's line starts at its first text in written order: writing the text first and showing the row with `flex-direction="row-reverse"` put every line at the name, with no host change.
- The room list's state as JSON gave the chats to open by kind (a right-to-left name, a large group, a link, a voice note) without reading names on screen.

### Needed
- A drive note when a screenshot follows a tap that opened a menu without real touches.
- The size notice naming the agent flag (`agent ios --json`), not a step suffix.

### Checkpoints
- Real data: long names and previews, right-to-left names, emoji, filters, archive, search and five chats checked in dark; fixes checked at the largest text size and in light with a test account. `verify ios` clean (12 tests). Exact `dd9343b324`.
