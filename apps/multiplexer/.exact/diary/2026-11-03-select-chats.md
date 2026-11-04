surfaces: ios
agent: Claude Opus 5.5
task: a chat app's select mode: the title menu or a chat's long press starts it, a tap chooses chats (rows and pinned pictures), and a bar under the list archives, marks read, mutes, moves, pins or deletes all of them

### Rough
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
