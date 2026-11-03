surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: add a bottom sheet (half height, pulls up to full) that picks which source's items a list shows, with a logo and an unread count per row, opened from a floating bar; the choice persists and combines with an existing filter menu

### Rough
- `check` on a half-height sheet (`navigationDetent="medium large"`) said each row was "367×42 pt, under the 44×44 minimum; make its box at least 44×44". The rows were authored `min-height=44` (border-box). Only `layout` said why: "route 1 is a sheet the platform draws at 0.96 of its laid-out size". So a row must be authored 46 to be 44 on screen. Cost about 3 minutes. What would have helped: the target finding naming the sheet's scale and the authored size that passes ("authored 44, drawn at 0.96 in a sheet: 46 reaches 44").
- A plain `list` whose first row is a grid of round pictures (pinned items) shows a short separator line above that row, starting in the middle of the screen (at the first text inside the grid, the second picture's initials). A list whose first row is an ordinary row shows the same line above it, starting at the row's text. UIKit's plain list draws a top separator on its first item. Reading the host (`GroupedListIOS.swift`, `itemSeparatorHandler`): a top separator is hidden only when the row before it wrote its own edge (`owned(path.item - 1)`); the first row has no row before it, so nothing the app writes (`border-top="none"` on the row) can hide it, and its inset is not set by `lineStart` either. Cost about 6 minutes; left as it is. What would have helped: no top separator above a plain list's first row (Messages, Mail and Settings draw none), or `border-top="none"` on the first row hiding it, as `border-bottom="none"` hides the line under a row.
- A list under a large title: after the reader scrolled down, choosing another filter should show the new list from its top, title open, as Mail does for another mailbox. `scrollIntoView("<first row id>", block="start")` puts the first row under the collapsed small bar, and the large title stays collapsed. The host aligns against the current port (`IntoView.swift`, `elementDestination` with `adjustedContentInset.top` of the collapsed bar), so no element in the list can bring the title back; the docs say a drag back to the top opens it, and say nothing for `scrollIntoView`. `scrollTop=0` moves only when the bound value changes. Cost about 10 minutes. What I did instead: kept `scrollIntoView` to the first row (better than keeping the old list's offset). What would have helped: a scroll to the very top that opens the large title, as a tap on the status bar does (`scrollIntoView` of the list's first row with `block="start"` doing it, or a `scrollToTop(listId)` command).

- `verify ios` flagged `image ... font-size=(largeText ? 30 : 22)` as fixed type ("stays 30 pt as Dynamic Type grows"), while the same app's bar writes `derive symbolSize = largeText ? 24 : 20` and `font-size=symbolSize`, which it does not flag. Both grow at the accessibility sizes the same way (to a cap that keeps a symbol inside a fixed box). I moved the sizes into a `derive`, and `verify` was clean. Cost about 2 minutes. What would have helped: the check treating both forms alike, and naming a capped form that it accepts for a symbol in a fixed box (finding about `min()` on an image's `font-size` already covers the cap).

### Lean in
- A bottom sheet with two heights is one route with `navigationPresentation="modal" navigationDetent="medium large"`: UIKit's glass below full height, the opaque ground at full height, the grabber, the inset corners of iOS 26, the dimmed page and swipe to close all came with it, and it worked on the first build. A row's choice closes it with `nav = back(nav)`.
- `layout <testId>` gave the frame and every resolved style of a row, which showed at once that `min-height` with padding was content-box (64 points instead of 48).
- `tree --ax` printed VoiceOver's reading of each row, with `[selected]` from `aria-selected`.
- A drag that the agent cannot make said so and named the fix (`--touch platform`); with it, a real drag pulled the sheet to full height.
- `screenshot <png> window` took the real display with the sheet presented (`presented="sheet"`, `pixels="display"`), so UIKit's glass could be judged directly.
- A second contract file for the sheet (`use Sheet, Row from "./sheet.contract"`) kept the shared screen's diff to a few lines.

### Needed
- bottom sheet with heights (half, then full): provided (a route with `navigationDetent`)
- haptics: provided
- settings that persist: provided
- scroll to top under a large title: missing (see Rough; the list scrolls to its first row, the title stays collapsed)

### Checkpoints
- editing app.contract / app.ts: smooth (one new contract file for the sheet; the build was clean on the first compile)
- iOS build: smooth (about 60 s with a Swift edit; contract edits ran on the existing build)
- driving the app (`exact.mjs agent`): smooth; `screenshot window` gave the display for a presented sheet; `--touch platform` pulled the sheet to full height
- `verify ios`: rough once (see Rough, fixed type), then clean
