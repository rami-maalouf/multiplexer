surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: update the framework checkout by about 1,000 commits, rebuild, and bring the chat sample apps' newer parts into a chat screen

### Rough
- `exact.mjs update` appends `/.exact/` to the app's `.gitignore`, after the app's own `/.exact/*` and `!/.exact/diary/`. The new line ignores the whole folder, so a new diary file is ignored by git (`git check-ignore -v .exact/diary/x.md` names that line), although docs/diary.md and the feedback README keep the diary in git. Removing the line does not last: each `update` appends it again. Cost about 10 minutes. Workaround in the app's `.gitignore`: keep `/.exact/`, then `!/.exact/`, `/.exact/*`, `!/.exact/diary/` after it. What would have helped: `update` not adding the line when the file already ignores `/.exact/*`, or writing the diary exception itself.
- `exact.mjs update` printed `Cargo.lock: does not match the app manifests; run bun exact.mjs lock`, and `lock` then said `current; no changes` (the lock file had already changed). It also prints `app.contract: every file names what it uses`, which reads like a problem; it is the module-scope check passing. A word such as "ok" would help. Cost: a minute, and a grep of the framework's source.
- After the update, each iOS build prints 4 cargo warnings, `patch ... was not used in the crate graph` (accesskit_windows, fontique, parley, wgpu-hal), from the `[patch.crates-io]` block that `update` writes and the app must not edit. They hide a real warning among them. Cost: a minute to see they are not the app's.
- `recipes/theme.md` says "`contract vocab -exact-label` answers a role", but `contract vocab -exact-label` and `contract vocab -exact-fill` answer "is not a tag, an attribute, a standard function, a recipe or a pattern". I wanted the list of colour roles, to find an opaque grey for a bubble; I found it only by grepping the framework's Linux host (`presenter/contrast.rs`). There is no opaque grey near Messages' bubble grey, so the app has a tamber token. Cost about 10 minutes. What would have helped: `contract vocab` answering a role, and a page that lists every role with its iOS colour.
- `check` allows white on the accent at 3:1 only when the accent is painted by a box that holds the text (`AgentCheckIOS.swift` walks the text's superviews). The framework's own sample chat app draws a tailed bubble with the fill on sibling boxes behind the text, so copying its `Balloon` gave 3 contrast findings per scheme (3.2 to 3.5:1) for the same white on the same blue that passed before. Cost about 15 minutes. Instead: one rounded box that paints the fill and holds the text, and the tail drawn over its corner (the fill is opaque, so the two join). What would have helped: the sample app's bubble written the way `check` judges it, or `check` finding the accent fill under a text when a sibling paints it.

### Lean in
- An SVG `path`'s `fill` takes a tamber token (`fill="bubble.incoming"`) and `AccentColor`, and follows light and dark with nothing else written: the tail from the sample app took one prop to move to the app's colours.
- Copying the sample's `Tail` and the run logic (last bubble of a sender's run, the picture beside it) took minutes; `check both` and the largest text size were clean after the change above.
- The recipe's newer send (clear at once, `scrollIntoView` in the mutation's `then`) was a 6-line change.

### Needed

### Checkpoints
- updating the framework checkout (`git merge --ff-only`, `exact.mjs update`, `lock`): rough (the diary lines above)
- copying the sample chat app's bubble into the app: rough (the `check` finding above), then smooth
- driving the app (`exact.mjs agent`): smooth
