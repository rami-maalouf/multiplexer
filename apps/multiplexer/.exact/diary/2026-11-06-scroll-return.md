surfaces: ios
agent: Claude Opus 5.5
task: a chat app's list that a reader found frozen after returning to the app: reproduce it, then log each list's scroll state on every return and clear what a return can leave in flight

### Rough
- The agent drive cannot cross the app leaving the foreground: an op running when the app went to the Home Screen failed with "the app left the foreground ..., so it is suspended and every op fails until it is back", and the drive ended, though the app was back 6 s later. Each drive is a new launch, so a return to a running app cannot be driven. I used exact2's `bench/bakeoff/drive.mjs` (the same touch runner, on the running app, with Home) instead; it needs `launch` first or the app's accessibility tree is off (`kAXErrorAPIDisabled`). About 30 minutes. What would have helped: drive ops for Home, the app switcher and lock, and a drive that waits for the app to come back.
- Building the app against my own worktree of the framework needed `EXACT2` plus the framework's path rewritten in four app files (`Cargo.toml`, `apple/Cargo.toml`, `web/Cargo.toml`, `app.json`); with fewer, the build refused or mixed the two checkouts ("multiple different versions of crate"), and switching back needed a cold build (9.6 GB of build output). About 25 minutes. Evidence for the known finding on building against another framework checkout.
- A list in the chat app is not one of the host's windowed lists, so the host's list tracking (`startTracking`) never started for it, and a watcher hooked there never ran; the view's own setup was the right place. About 10 minutes reading the host.

### Lean in
- `os.Logger` lines with a fixed category, read back with `xcrun simctl spawn <udid> log collect` and `/usr/bin/log show <archive> --predicate ...`, worked the same way a phone's collect will.

### Checkpoints
- 11 return scenarios on a simulator, two accounts, two builds: none froze. With the watcher: an open swipe and the scroll offset survived a return unchanged (recorded), the log counted the open swipe and released nothing, and a drag that moved nothing gave one "stuck" line. `verify ios` clean.

### Rough (2026-11-06 evening)
- Pulled `Library/Caches/scroll-return.log` from the paired phone after a real freeze. Return itself logged `active … count=0`, but the next drags left `_UIFlexInteractionPanGestureRecognizer` on the Exact window in `.changed` with no finger down; row swipe and interactive-back pans died the same way. About 15 minutes. What would have helped: the host releasing began/changed recognizers on return and after a dead drag (shipped locally as Exact `e2b58b6992`).
- Capsule Inbox↔Archive still re-keyed `roomList` on `chatList`, so each press awaited a full native `rooms` answer. Client-side list pick from a scoped answer removes that wait.
