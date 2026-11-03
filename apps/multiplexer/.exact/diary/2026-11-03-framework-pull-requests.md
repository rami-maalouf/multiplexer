surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: fix findings from building a chat app as pull requests to the framework: three recipes, the vocab and the grammar on members files, the agent's help on video, the search card, caps' line count, and check's target finding in a scaled sheet

### Rough
- The edit-sheet recipe drew its sheet's header in the page on iOS, and nothing caught it: `lower-header-nested` gives a `for` between the route and the header the benefit, and the docs test only compiles the block. Proving it took a throwaway runner test that asked the kernel's `header_shape` of every node. Cost about 10 minutes. What would have helped: the rule following a `for` whose body is one component use, or a docs test that projects each recipe route's bar (evidence for finding 66).
- The docs test compiles each recipe block in a folder with no `app.json`, so it ships no target and an icon token with no `svg` source passes, though every app (which ships the web) is refused it. Making the recipe right also needed the test to write an SVG for a design's `svg` source. Cost about 5 minutes. What would have helped: the docs test compiling as an app that ships the web (evidence for finding 67).
- `bun test ./scripts/caps.test.mjs` with the Bun on PATH (1.4.3) failed with "Cannot use test outside of the test runner" again; `BUN=$(which bun) bun test …` ran it. Cost about 2 minutes (finding 42 again; PR #1345 is open).

### Lean in
- Each recipe's 3,072-byte cap and the vocab card's 12 KB cap are checked by `caps` and the vocab tests, so a doc change that grows a page is caught before review.
- `Kernel::header_shape` and `Runner::boot` let a test ask what iOS would make a bar of, with no simulator.

### Needed
- none

### Checkpoints
- framework checks (`cargo test -p contract --test it docs:: vocab::`, `caps`, script tests): smooth after the first build (about 3 minutes cold in a new worktree)
