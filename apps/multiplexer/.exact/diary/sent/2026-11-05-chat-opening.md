surfaces: ios
agent: Claude Opus 5.5
task: a chat app's conversation opens on its messages in the first frame (a kept copy, then the live answer), instead of a spinner while its history loads

### Rough
- `agent ios` always builds and installs the checkout's current sources, so a baseline of the older build could only be measured by moving the code aside (a commit, then switching the checkout to the old commit and back), with a full rebuild each way. About 15 minutes. What would have helped: a drive of an already built app (`agent ios --app <path>` or `--no-build`).
- A real return from the background cannot be driven: bringing another app to the front ends the drive's ops ("the app left the foreground (a share extension or another app took the screen), so it is suspended and every op fails until it is back"), and nothing in the drive brings it back; launching the app from outside starts it under the non-drive session. `prefer visibility-state hidden` then `visible` covers only the page's side. About 10 minutes and two drives. What would have helped: an op that sends the app to the background for a time and brings it back.
- The data module's file API cannot set iOS file protection or keep a file out of backups, so a cache of message text went through the native module instead (two calls). About 10 minutes. What would have helped: `storage.fs.writeFile` options for both, or a doc line naming which folder is excluded from backups.
- Again a drive ended with "the app hung up (exit code 0)" with no crash report written, right after a screenshot, at a load average of 16; the same steps passed in the run before. Not isolated.

### Lean in
- A data source may answer synchronously: a kept copy then shows in the first frame of the route, with no pending state.
- `Date.now()` in a data source is refused at compile time with a clear message ("pass time or a random seed as an argument").
- Screen recordings cut into frames at 15 per second, scored for a blank body, gave tap-to-content times per opening.

### Needed
- none

### Checkpoints
- Before: a blank body with a spinner for 3.0 s and 0.7 s on two chats' first open after a launch.
- After: newest message at once, full first screen by 0.7 s; after a relaunch, full content in the first frame; reopening shows no blank frame.
- New device: newest message after one frame; history fills behind a small top spinner.
