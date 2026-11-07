surfaces: ios
agent: Claude Opus 5.5
task: a chat screen whose transcript jumped when the keyboard rose, on send, and when a voice recording started: reproduce it, find the cause, fix it in the right layer

### Rough
- The cause was in the framework: under `interactive-widget="overlays-content"`, a keyboard toolbar gives the scroller under it a bottom content inset, but the host keeps a scroller's content size at least its box (`scrollFloor`). A transcript shorter than its port then counted as "at its end" at the full keyboard's height, so the keyboard moved every row up by the whole keyboard (317 points) and the newest rows went behind the top bar; the next append moved them back. About 40 minutes from the first recording to the cause. Fixed in the host: the floor leaves the keyboard's inset out, set before the inset changes, so UIKit's own inset callback keeps the content's own end. What would have helped: a host test with a short scroller under a keyboard toolbar (the existing ones all used content taller than the port).
- After a drag that lowered the keyboard, the chat's "jump to the newest" button stayed up with the newest message in view. The host sends a `scroll` event only when the offset or the top inset changes, but its `clientHeight` leaves out the keyboard's inset; the inset went away without the offset moving, so the app kept the last event's smaller port and read its end as far away. About 25 minutes, found by copying the event's numbers into a debug state and reading it in a drive. Fixed in the host: the event is compared whole, and a scroller whose insets change queues one. What would have helped: a drive op that shows the last `scroll` event a scroller sent.
- `agent ios ... "layout <list>"` printed `scroll viewport 0,0 of 0,0` for a windowed list: no content offset, no content size, no insets. I could not see what the keyboard did to the list from a drive, so I added temporary `NSLog` lines to the host, rebuilt (a few minutes for each Swift edit) and read them with `xcrun simctl spawn <udid> log stream`. About 20 minutes. What would have helped: `layout` naming a scroller's offset, content size, and content and adjusted insets.
- A drive's `screenshot` leaves the keyboard out (a dark band where it is), so a keyboard bug cannot be judged from drive screenshots; I recorded the Simulator with `simctl io recordVideo` and cut frames with ffmpeg. About 5 minutes. What would have helped: a drive screenshot option that includes the keyboard, or a note in the agent help.
- The contract cannot read whether the keyboard is up or which field has focus. A button that must keep a raised keyboard up without raising a lowered one needs the app to keep its own focus state from the field's `focus` and `blur` events. About 10 minutes. What would have helped: a viewport value for the keyboard (up, height) or the focused field's id.
- `scroll-behavior="smooth"` on a followed list would animate the follow of the end when a row is appended (as a messaging app does), but it also animates every other programmatic scroll of that list (an open at the first unread, a jump to a found message). So the append stays a one-frame shift of one row. What would have helped: a way to animate only the follow of the end.

### Lean in
- `bun host/apple/build.mjs --test --ios --only <classes>` named the wrong class at once and listed what it accepts.
- The agent's `--timing platform --touch platform` drive, recorded with `simctl io recordVideo`, showed the real keyboard animation frame by frame; the bug and the fix were both clear in the frames.

### Needed
- keyboard state (up, height, focused field): missing (by hand: focus and blur state)
- animated append in a followed list: missing (left as a one-frame shift)

### Checkpoints
- iOS build: smooth (each host Swift edit a few minutes)
- driving the app (`exact.mjs agent`): rough (see Rough: layout shows no scroll state, screenshots leave the keyboard out)
- editing app.contract: smooth (a contract-only change ran on the existing build in about a second)
