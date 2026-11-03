surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: save messages from a chat's long-press menu, and show them in one list, in each chat's info page and in the in-chat search

### Rough
- A git worktree that is not a sibling of the app's main checkout cannot build: `package.json` names the framework's packages as `file:../../../exact/exact2/packages/...`, so `bun install --frozen-lockfile` failed with "Could not find folder" for all four, and `contract build` then refused `use ... from "@exact/clipboard"` (not installed). `EXACT2=<path>` fixed `contract vocab`, whose message named it, but not the install, as the `file:` paths are fixed in `package.json`. I put a symlink to the framework's parent folder beside the worktrees. Cost about 5 minutes. What would have helped: the install step (or `exact.mjs` itself) taking the framework from `EXACT2` too, or `setup --check` naming the broken relative path and the one-line fix.
- `bun exact.mjs check` is not a verb; the start-here line that names `check both` shows it as a drive step (`agent web ... "check both"`). I read the docs table to find it. Cost about 1 minute. What would have helped: the unknown-verb message saying "check is a drive step: agent ios ... \"check both\"".

### Lean in
- `.every(...)` in a contract `fn` was refused with the exact rewrite to use (`not xs.map(x => ...).includes(false)`) and the LLP number: fixed in one edit.

### Needed
- account-wide app data (bookmarks on every device): by hand (the server's account data, through the native module)

### Checkpoints
- editing app.contract / app.ts: rough (the worktree's package paths, see Rough), then smooth
