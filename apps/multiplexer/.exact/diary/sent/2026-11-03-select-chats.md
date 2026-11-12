surfaces: ios
agent: Claude Opus 5.5
task: a chat app's select mode: the title menu or a chat's long press starts it, a tap chooses chats (rows and pinned pictures), and a bar under the list archives, marks read, mutes, moves, pins or deletes all of them

### Rough
- The integrated iOS verify needed a native rebuild after another feature's native changes: 76.8 s before its tests, 144.2 s total. The build reported 59.5 s in arms. Kept verification sequential to avoid loading the test device. What would help: narrower native rebuild dependencies and cached host arms (more evidence for the native build-cost finding).
- On resuming the task, reading the local `.exact/runs.jsonl` exposed a password argument from an earlier drive: terminal output masks the password field, but the local run's `what` text retained it. No value is included here. Stopped reading that file and redacted password steps in the ignored local run logs; keep those files out of feedback. What would help: masking password-field type arguments before recording drive steps, not only when displaying them or sending feedback. Found in under a minute at `ed43ad09a0`.
- A `button` as a plain list's row (the select mode's row, in place of the usual `link` row) sized to its content, not to the cell: at the largest text size one row was 600 pt wide and ran 198 pt past the screen (`check`: "overflow ... nothing scrolls it"). The `link` row beside it fills the cell. `width="100%"` on the button fixed it. About 5 minutes. What would have helped: a list row filling its cell whatever its tag, or the vocab's list entry saying a `button` row needs `width="100%"`.
- A members file's `state chosen` broke another members file's `let chosen` ("`chosen` is already a state here: a `let` never shadows a name in scope"). The message is clear, but the cause is that all members files of a root share one scope, so a new feature's state name can break an older feature's local. About 3 minutes; I renamed the state. What would have helped: the message naming the members file that declares the state.
- `press=(selecting ? toggle(r.id) : open(r.id))` was refused ("`press=` needs an action name or `action(args)`"). Evidence for the known finding: I wrote one action that chooses (`tapPinned`). About 2 minutes.
- `check` found the select mode's floating bar overlapping the rows under it at the top of the list, and found nothing for the inbox's own floating bar in the same place, built the same way (a `glassGroup` row, `pointer-events="none"`, a glass capsule of buttons). Scrolled, the inbox's bar gets the same findings. I could not tell from `scripts/agent-check.mjs` why the unscrolled inbox is clean, and left both as they are. About 10 minutes.
- `none` as a derive name was refused ("reserved in Contract (it is a literal)"). Clear; renamed. Under a minute.

### Lean in
- `--touch platform` with `tap <row> down`, a real wait and `screenshot window` showed the real long-press menu, with Select Chat first, and the bar's More menu as UIKit's.
- `layout <testId>` and `check` at the largest text size named the overflowing row and the squeezed title exactly.

### Needed
- a check mark on a list row in a select mode: by hand (`symbol:circle` and `symbol:select-fill`); the docs name no list editing mode with selection circles (UIKit's)
- a bottom toolbar of actions for a select mode: by hand (a floating glass row, as the inbox's bar)

### Checkpoints
- Both ways in, choosing rows, the long-press menu and the More menu seen in dark; light; the largest text size after the fixes (the title wraps under Done; the mark takes the picture's place).
- Drives as a test user on two chats of their own: Mark as Read, Archive, Unarchive from the Archive, Mute, Pin (then chosen by their pinned pictures), Unpin, Unmute, and Delete through its alert (real touches), each on both chats, then the mode ended.
- `verify ios` found the mark's fixed 24 pt size ("stays 24 pt as Dynamic Type grows"); with `min(-exact-title2, 28px)` it is clean (6 tests, both schemes, the largest text size).
- Resumed verification: an injected data-source failure showed that the old selection mode closed before the server replied. The fixed mode keeps selection and shows an inline retry message; a successful reply ends it. The temporary fault was removed. The heading now has an opaque background so scrolled rows cannot show through its words.
- Final real-server drive: the pending spinner appeared, Mute succeeded and closed the mode, then Unmute succeeded. Display screenshots checked in light, dark and the real largest accessibility text size. Final `verify ios`: 6 tests pass, no check findings, no text-size overflow, 65.5 s.
- After integrating the latest main: the two-device bulk-action test passed again (88 s), and the rebuilt iOS app passed all 6 tests, both schemes and largest-text checks (144.2 s including 76.8 s build). Smooth checks after the rebuild cost above.
