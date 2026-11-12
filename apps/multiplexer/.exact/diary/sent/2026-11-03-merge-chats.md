surfaces: ios
agent: Claude Opus 5.5
task: a chat app's Merge Chats: one person's chats on two networks as one row with both logos and the unread counts added, a chat bar with network tabs, a sheet to merge and Unmerge, kept in the account's data

### Rough
- A `derive` whose expression went on to a second line (`.map(r => …)` indented under it) was refused with "expected a section, found an indented block", at the second line. It did not say that a derive's expression must stay on one line. I joined it into one long line. About 2 minutes. What would have helped: the message naming the derive and the one-line rule, or continuation lines allowed as in a view's attributes.

### Lean in
- A component's existing props carried the change: the merged chat's row is one more row of the same list, and every chat action takes the merged chat's id, so the long-press menu, the pinned grid and the info page needed only a derive (`openChatId`) in place of the open room.

### Needed
- one person's chats on several networks as one chat: by hand (account data in the core library, folded into the list)

- `check both` on the merged chat reported overlaps of the bar's title and tabs with the messages fading under it, and dark contrast on the bar's glass. A second drive of the same chat without tabs showed the same kinds of finding, so the new ones could be told apart. About 10 minutes (finding "check flags rows that scroll under an app-drawn floating bar").

### Checkpoints
- As a test user: two chats (a WhatsApp and an Instagram test chat) merged from the title menu and from Select Chats; one row with both logos; it opened the WhatsApp chat, and the Instagram tab showed the other chat in place, Back to the list; Unmerge brought both rows back.
- `check` caught tabs under 44 points, the fade ending above the tabs, the tabs' words growing past the screen at the largest text size, and a row wider than its parent; each fixed and checked again.
- MatrixCore: MergesTests 3 passed; NetworkFilterTests, InboxTests, RemindersTests and ChatActionsTests pass with it. `verify ios` clean.
