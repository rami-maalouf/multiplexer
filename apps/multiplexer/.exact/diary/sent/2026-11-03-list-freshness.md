surfaces: ios
agent: Claude Opus 5.5
task: a chat app's chat list: its preview says "Message deleted" when the newest message was deleted, with the chat never opened, and another device's archive or delete reaches an open list at once

### Rough
- `state <path>` on a large list answered "over the 8.0 KB printed whole ... all of it: `state <path> --full`, or --json". `state <path> --json` printed the same summary again, not the value; `--full` worked. About 2 minutes and one more drive. What would have helped: `--json` printing the value, or the hint naming where `--json` goes.
- `clock until state` compares one path with one literal, so a drive cannot wait for "the row whose id is X says Y" or for a list to grow (`roomList.rooms.length > 0` was refused with the grammar). I waited on `rooms.length == 40` and on `rooms.0.lastMessage`; both misled me, because other writers of the shared test account changed the list's length and order during the drive. I then dumped `state <list> --full` and searched it with a script. About 15 minutes and four drives. What would have helped: a path that finds a list item by a key (`rooms[id=!abc].lastMessage`), or `contains` and `>` in `clock until state`.

### Lean in
- `clock +N real` with a background script that changes the server made a "while the list is open" check simple: one drive, two `state` reads, before and after.
- The drive's appearance switch (`prefer prefers-color-scheme dark`) at the start of each drive made dark-first screenshots cost nothing.

### Needed
- telling the view that the app's core library's data changed without a server event: by hand (the native module's existing change topics)

### Checkpoints
- Reproduced first, in the app: another device unarchived a chat while the list was open; 45 s later the list still lacked it (old build). With the fix, the chat was back within the next read.
- In the app (dark): a test user's newest message, then its delete, with the chat never opened: the row said "Message deleted", and still after a relaunch.
- Core tests: the delete test fails without the fix ("Before …" is not "Message deleted") and passes with it; the watch test passes. The full core suite: see the task's commit.
