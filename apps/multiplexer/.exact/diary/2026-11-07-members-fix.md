surfaces: ios
agent: Claude Opus 5.5
task: fix three issues in a chat app: a group's info page counted one member fewer than its list showed; a chat's composer appeared only after its messages loaded on a first open; a bridged group with one other person was filed as a one-to-one chat. Also restage a demo group's unread state.

### Rough
- After the composer row was mounted with the screen's navigation push, its voice button stayed invisible for 0.3 to 0.5 s and then faded in when the messages arrived, though its slot was laid out from the first frame. The button has an entry `animation` (260 ms, fill `both`). I first took it for a layout pop-in. Two probe recordings told them apart: with Reduce Motion (the app sets `animation="none"`) the button shows from the push's first frames; with motion, the animation starts at the next commit (the messages), not a fixed time after the push. About 15 minutes. What would have helped: an animation that starts when its node mounts, or a note in the docs on when it starts during a push. New finding 155. Not worked around in the app.
- The run log `.exact/runs.jsonl` kept a typed password once, in clear text, after each of two drives that signed in two accounts (a masked field; the drive's own output showed `•••`). Redacted at once. Evidence for finding 116.
- To see a pop-in frame by frame I used a Simulator recording beside a `--timing platform --touch platform` drive and a small script that tiles 60 fps frames with their numbers (the local ffmpeg has no `drawtext`). About 5 minutes. Evidence for findings 29 and 147.

### Lean in
- `state listedRooms.length` gave the list's count under a filter in one op, so a real account's DMs and Groups could be compared before and after as numbers, with no names in the log.
- `state peek.messages` read a chat's newest messages through its long-press preview, which reads nothing, so a demo chat's unread badge stayed while its message statuses were checked.
- An edit to only the contract ran on the existing build; only the native module's edits needed a build (about 1 minute each).

### Needed
- An entry animation that plays when its node mounts during a navigation push.

### Checkpoints
- Info page of a staged group, same drive: before "3 members" over a list of 4; after "4 members" over 4. `check dark`: no findings.
- First open with no kept copy, 60 fps: before, no composer for about 0.6 s (frames 618 to 654) under the loading spinner; after, the composer is there from the push's first frame (458).
- A real account, read only, the same drive on the old and the new core: DMs 257 and Groups 75 before; 256 and 76 after (one bridged group moved).
- `test ios`: 12 passed. `bun test`: 13 passed. `contract build`: no errors. Core tests for the inbox, the info page and push: 15 passed.
