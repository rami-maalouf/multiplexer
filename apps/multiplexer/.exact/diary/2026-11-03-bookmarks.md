surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: save messages from a chat's long-press menu, and show them in one list, in each chat's info page and in the in-chat search

### Rough
- A git worktree that is not a sibling of the app's main checkout cannot build: `package.json` names the framework's packages as `file:../../../exact/exact2/packages/...`, so `bun install --frozen-lockfile` failed with "Could not find folder" for all four, and `contract build` then refused `use ... from "@exact/clipboard"` (not installed). `EXACT2=<path>` fixed `contract vocab`, whose message named it, but not the install, as the `file:` paths are fixed in `package.json`. A symlink to the framework's parent folder beside the worktrees fixed the install and `contract build`, but `ios` then refused the app: `Cargo.toml`'s `[patch.crates-io]` must name the framework's vendored crates by the path from the real folder (`../../../../../../Documents/code/...`), and `EXACT2` set to the symlinked path made no difference. I moved the branch to a new worktree beside the main checkout and built there from scratch. Cost about 15 minutes, and a cold build. What would have helped: the generated paths (package.json, Cargo.toml) following `EXACT2`, or the Cargo check accepting a path that resolves to the same folder (evidence for finding 46).
- `bun exact.mjs check` is not a verb; the start-here line that names `check both` shows it as a drive step (`agent web ... "check both"`). I read the docs table to find it. Cost about 1 minute. What would have helped: the unknown-verb message saying "check is a drive step: agent ios ... \"check both\"" (evidence for finding 13).
- A list page opened from a sheet's row with `nav = go(nav, path("<page>"))` stayed in the sheet (the stack kept the sheet's entry: home, sheet, page), and a chat opened from that page with `go` opened inside the half-height sheet too. Nothing said so; only a screenshot showed it. `nav = push(back(nav), path("<page>"))` closed the sheet and pushed the page. Cost about 5 minutes. What would have helped: `go` to a route that is not under the sheet's route closing the sheet, or `check` naming a full-screen route drawn inside a sheet (finding 96).
- One page with a `header` heading at `aria-level=1` over an inset-grouped list showed its title inline when the list had rows and large over the empty state (the same route, reached the same way). I made it `aria-level=2`, inline always. Cost about 3 minutes. What would have helped: the title starting large in both, or the docs saying when it starts collapsed (finding 98; maybe the cause of "a large title comes back inline").
- A data source answered one field more than its shape (`savedAt`). The drive's `state` showed the old value (an empty list) with no word; only `logs` said "answered outside its shape: field `savedAt` is not in the shape". Cost about 3 minutes. What would have helped: a failed resource request named in the drive's output (as a tap names what covers it), not only in `logs` (finding 97).
- Under `--touch platform`, `tap <row> contextmenu` delivered the long press as an event and UIKit showed no menu; `tap <menu row>` then said "not the menu UIKit shows: tap its invoker first". `tap <row> down`, `clock +1500 real`, `tap up` showed the real menu (as an earlier diary found). Cost about 3 minutes. What would have helped: `tap <row> contextmenu` under `--touch platform` doing that long press itself (known: exact2 `QUEUE.md`, "Under `--touch platform`, context menus are still painted").

### Lean in
- `.every(...)` in a contract `fn` was refused with the exact rewrite to use (`not xs.map(x => ...).includes(false)`) and the LLP number: fixed in one edit.
- `row delete=...` gave a UIKit swipe to delete on a list row in one attribute; the list-rows recipe (`docs large title` found it) shows it beside a long-press menu.
- `check both` after each screen, in light and dark, caught nothing to fix and said so in one line each.
- A drive's `--touch platform` with `tap <row> drag -120 0` showed UIKit's own swipe action.

### Needed
- account-wide app data (bookmarks on every device): by hand (the server's account data, through the native module)

### Checkpoints
- install / first build: rough (a worktree outside the sibling layout, see Rough)
- editing app.contract / app.ts: smooth
- iOS build: smooth after the first (about 2.5 min cold; about 40 s for a Swift edit)
- driving the app (`exact.mjs agent`): rough (a page in a sheet, the shape refusal only in logs, a real long press; see Rough)
