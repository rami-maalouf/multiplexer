surfaces: ios
agent: Claude Opus 5.5
task: fix, in pull requests to exact2, the framework gaps that a chat app's open criteria wait on (an edge swipe in a drive, a link's spoken name, a large title after a sign-out, a loading line in a virtualized list), each reproduced in a minimal app first

### Rough
- `bun test ./scripts/agent-keys.test.mjs` in exact2 failed with "Cannot use test outside of the test runner": a newer Bun on PATH, and `ensureBun` ran the file again with the pinned Bun but without `test`. Running `~/.bun-<pin>/bin/bun test` worked. About 3 minutes. Known: an open pull request already fixes it.
- `build.mjs --test --ios` needs Xcode's Metal toolchain, and said so with the install command. The first run stopped only after its Rust build. About 2 minutes and a 1 GB download. What would have helped: the check before the build.
- `build.mjs --test --ios` printed "Test case '…' failed" with no assertion message. I read it from the `.xcresult` with `xcrun xcresulttool get test-results tests`, and the first `.xcresult` I opened was the other pass's (the bare and the hosted runs each write one). About 10 minutes. What would have helped: the failing assertion's message in the build's output.
- A test that needs a window scene runs in the hosted pass only when it says `missing("scene", …)`; mine said nothing, so it ran bare and failed at `XCTUnwrap(scene)`. Found by reading `xctest.mjs`. About 5 minutes. What would have helped: the refusal naming `missing("scene")`, or `docs/testing.md` saying it.
- On this machine (iOS 26.5 simulator, region `en_CA`), exact2's own tests fail on `origin/main`: five or six in `NavigationCollapseIOSTests`, `PushedTitleIOSTests.testATabSwitchAContentSwapAndAReplaceKeepIt`, and `AccessibilityClientMacTests.testAnAlertDialogLandsVoiceOverOnTheButtonItsCommitFocused` (AppKit says "dialogue" in Canadian English). Each run needed a second run on `origin/main` to tell them from my change. About 20 minutes.
- A unit test of a large title that comes back after a route with no bar did not reproduce what a drive shows (it passed on `origin/main`, bare and hosted, booted before its window). Three tries, then I kept the drive as the evidence. About 25 minutes.
- In the `messages` sample, an edge swipe that starts over the transcript went to the transcript's `pan` handler, not to the edge swipe; a `swiperight` node waits for the edge swipe. A hand-built screen goes back there.

### Lean in
- `exact new` outside the repository gave a minimal app in a minute; each repro (a link row, a route that loses its bar, a transcript with a marker row) was one contract and one drive.
- `tree --ax` gave the spoken name and the title's frame as text, so before and after were two lines to compare.
- `tap <target> drag … from <x> <y>` under `--touch platform` is a real edge swipe, and the log says "by the edge swipe".

### Needed
- a line in a virtualized list that is not an item: by hand (a marker item put first with `concat`)

### Checkpoints
- Edge swipe: the refusal of `at … drag` reproduced, then `drag 320 0 from 2 100 over 400` popped the screen in the `messages` sample.
- Link name: `link "AL Ada Lovelace You: see you soon"` before, with "WhatsApp" after; 70 iOS and 72 of 73 Mac accessibility tests pass (the one fails on `origin/main` too).
- Large title: "Welcome" 73.67 x 20.67 before, 147 x 40.67 after, in place and after a pop.
- Marker row: `reachstart` loaded every older row with the marker first; the marker then said where the chat starts.
- Rows added above a row placed by `scrollIntoView` stayed in place (not reproduced).
