surfaces: ios
agent: Claude Opus 5.5
task: a read-only drive of a chat app on a real account, to see that contact names lost a suffix the server added

### Rough
- A worktree made by an agent tool, at another folder depth than the main checkout: `bun install` failed with "Could not find folder "file:../../../exact/exact2/packages/camera"" and five more. I made a worktree next to the main checkout. About 3 minutes. Known: finding 106.
- `tap room-<id>` on a list row that a new message had moved under the floating bottom bar answered "its middle is outside the viewport; scroll it into view first", though `agent`'s help says tap scrolls a target into view first. `type root /room/<id>` opened the chat. About 2 minutes. Known: finding 13, item 13.

### Lean in
- `state --full` held every row's name, network and last sender, so one drive counted names across 189 chats without screenshots.
- `type root <path>` opens a route by its path in a drive.

### Needed
- opening a route in a drive: provided (`type root <path>`)

### Checkpoints
- Inbox, 189 chats loaded: 0 names with the WhatsApp suffix; 7 Instagram senders in previews keep theirs (expected until each contact's next update).
- 2 direct chats and 1 group: the bar shows the name without a suffix. The group shows "No Messages Yet" after 20 s (an app issue, recorded in the task list).
- Signed out at the end; the account has no session left from the drive.
