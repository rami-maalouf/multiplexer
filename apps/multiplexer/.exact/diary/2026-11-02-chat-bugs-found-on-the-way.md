surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: fix a chat screen's bugs found in the previous task: an empty reply quote, a reply hidden by the keyboard, scrolled messages showing through the composer, and drafts lost when the app quits

### Rough
- Several agent sessions worked on the same app at once, each in its own git worktree, and `exact.mjs ios --run` and `agent ios` with no `--sim` all went to the same default Simulator. My `ios --run` reinstalled the app (same bundle id) while another session was in the middle of a drive on that Simulator, and its drive had left the app signed in to another account. Then `agent ios --sim "MX main"` refused: "another drive of this store is open on simulator ... (stream is locked by another publisher)", which was clear and saved me, but that Simulator was in use by a third session. Fix: I made a Simulator of my own (`xcrun simctl create`) and set `EXACT_SIM` for every build, test, verify and drive. Cost about 15 minutes, and possibly a broken drive in another session. What would have helped: a default Simulator per app folder (or per worktree), or `ios --run` warning that an agent drive is open on the Simulator it is about to install on.
- A virtualized `list` draws its rows past its own frame: in a chat scrolled up, the rows below the list's bottom edge show through the reply bar and the composer that follow it (they have no background), and `check` reports each one as "overlaps". `overflow="hidden"` on the list is refused: "`overflow` is not supported on this virtual collection flow root". Wrapping the list could have broken the navigation bar's link to it (`navigationScroll`), so I did not try. What worked: a background colour (`-exact-background`) on one column that holds the reply bar and the composer; `check` is then clean, and the look at rest is unchanged. The sample chat app hides the same thing with `backgroundMaterial="ultra-thin"` on its composer bar, but in light mode that material shows as a grey band at rest. Cost about 25 minutes. What would have helped: the list clipping at its frame on its bottom edge (as a `UIScrollView` does), or the chat recipe saying that the bar under a transcript needs a background or a material, and why.
- A reply started with a swipe on a message low on the screen, while the chat is scrolled up, ended under the keyboard. There is no fact for the keyboard: `exactViewport().height` stays the same when it comes up (874 before and after), so nothing can react to it. What worked: on starting the reply, a task `after(300, revealNow, wait=idle, max=1000)` that calls `scrollIntoView("transcript", id, block="nearest")`. It works in a drive, but it is a guess at when the keyboard is up. Cost about 15 minutes. What would have helped: a keyboard fact (its height, or whether it is up), or a list that keeps its bottom rows in view when it gets shorter, as a chat needs.

### Lean in
- `scrollIntoView("transcript", <key>, block="nearest", behavior="smooth")` on a virtualized list scrolled a row into view just above the reply bar, with no frame math.
- `wait=idle` on a timer let the reveal wait for the layout to settle after the keyboard came up.
- `prefer visibility-state hidden` in a drive tested "the app goes to the background right after typing", which is the case that loses a draft.
- `screenshot <png> over 400 every 25 window` showed, frame by frame, that one bar holding both the reply bar and the composer removed a one-frame overlap while the keyboard rises.

### Needed
- keyboard (its height or visibility): missing (a timer with `wait=idle` instead)
- app visibility (foreground or background): provided (`exactPage().visibilityState`)

### Checkpoints
- editing app.contract / app.ts: smooth
- iOS build: rough as before for modules/apple Swift edits (the vendor's bindings again)
- driving the app (`exact.mjs agent`, `exact.mjs test`): rough (a shared default Simulator; see Rough), otherwise smooth
- `verify ios`: smooth (clean)
