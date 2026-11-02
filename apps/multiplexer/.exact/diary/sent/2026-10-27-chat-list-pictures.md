surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: round pictures (or initials) in a chat list's rows, from files a native module downloads, in the order the data module gives

### Rough
- A row's picture should grow with the text size and stop at a cap: `width="min(2.75rem, 64px)"`. Refused: "rem and em are not supported inside calc(), min(), max() or clamp(); write px". The message named the fix, but the fix is a fixed 44-point picture; only the initials scale (`font-size="min(-exact-headline, 20px)"` is accepted). ~2 min. What would have helped: `rem` and `em` inside `min()`, as CSS has them.

### Lean in
- `lower-zero-size` caught a `link` whose children I had indented as its siblings, at compile time.
- Naming the order in the source (`loadRoomsByRecency`), as `docs/start-here.md` asks, made the dropped `sortBy` obvious in review.
- `check` at the largest text size was clean with the fixed picture and capped initials.

### Needed
- none

### Checkpoints
- editing app.contract / app.ts: smooth (two compile errors, both named the fix)
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): smooth
