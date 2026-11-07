surfaces: ios
agent: Claude Opus 5.5
task: a chat screen showed its older-messages spinner for about half a second on each open, even for a short chat already loaded: reproduce it, find the cause, fix it in the right layer

### Rough
- `agent ios ... "state <list>"` on a large value said "all of it: `state <path> --full`, or --json". `--json` printed the same summary again (38 KB, "over the 8.0 KB printed whole"), not the JSON; `--full` worked. About 3 minutes and one more drive. What would have helped: `--json` doing what the hint says, or the hint naming only `--full`.
- `expect tree has "<testId>"` is a test step only: in a drive it fails with `unknown op: expect`. To learn whether a row was in the tree I dumped the whole `tree` and searched it with grep. About 3 minutes. What would have helped: a drive op that answers "is this testId in the tree" (or `expect` allowed in drives), or the error naming the drive op to use instead.
- To show that the spinner still shows during a real fetch of older messages, I scrolled a long chat to its top with `tap <list> drag 0 600` steps and a screenshot after each. The list's `reachstart` fired well before its top row came into view, and the fetch ended before that row could be seen, so the spinner never showed in a frame. The row is virtualized out of `tree` while it is far away, so the drive could not show it either. About 15 minutes. I showed the real fetch another way (a first open with nothing kept, which pages back with the spinner up). What would have helped: a drive op that holds a source's answer (a slow network for one call), so a loading state stays up long enough to see it.

### Lean in
- `state thread.atStart` straight after `tap <row>`, then after `clock +100 real` and later, showed what the screen got on each step: false then true before the fix, true from the first step after it. That pointed at the data module at once, before any frame was read.
- A contract or data-module change runs on the existing iOS build ("running the new plan on the existing build"): the after drive needed no native rebuild.

### Needed
- a held or slowed source answer in a drive, to see loading states: missing (by hand: a case that is slow by nature)

### Checkpoints
- driving the app (`exact.mjs agent`): mostly smooth (see Rough: `--json` hint, `expect` refused in drives)
- editing app.ts: smooth (no rebuild)
- `test ios`: smooth (12 passed)
