# Exact feedback

This folder records each place where building Multiplexer with Exact was hard. Its
purpose: Rami and the Exact team can improve the framework. Read this page first.

| What | Where |
|---|---|
| Findings, one file each, in exact2's issue format | [`issues/`](issues/) |
| Raw notes, one file per task, in Exact's diary format | [`apps/multiplexer/.exact/diary/`](../../apps/multiplexer/.exact/diary/); entries already sent are in `sent/` |
| What was sent to the Exact team, and when | "Sent to the Exact team", below |
| The rule that every agent follows | `AGENTS.md`, "Exact feedback: always record it" |

The findings use no app name, server name or account name, so they can go to the
Exact team as they are.

## Findings

Findings 1 to 22 were rechecked against exact2 `cee509ac82` (2026-10-27); 23 to 27 were seen at `1bc4c36cb7` (2026-10-31), where 12 and 15 were seen again (their files have the evidence). On 2026-11-02, 28 was seen at `1bc4c36cb7` 29 at `ed43ad09a0`, and 33 and 34 at `d165f8959f`, with new evidence for 13, 26 and 27; at `ed43ad09a0`, 15 was seen again and 21 is fixed; 30 to 32 and 35 to 41 were seen at `ed43ad09a0`, 17 was seen again, and 13 and 30 have new evidence.

| # | Finding | Cost | Severity | File |
|---|---|---|---|---|
| 1 | Each Swift edit compiles all of `modules/apple` again, including a vendor's 2 MB of bindings. | 31 to 42 s for each edit | P2 | [module-swift-recompiles-vendor-bindings](issues/20261027-module-swift-recompiles-vendor-bindings.md) |
| 2 | An authored test cannot read a secret, so `verify` never reaches the screens behind a sign-in. | A text-size bug that `verify` missed | P2 | [authored-tests-cannot-read-a-secret](issues/20261027-authored-tests-cannot-read-a-secret.md) |
| 3 | A native module can use only real files in `modules/apple`: no links, no local Swift package. | About 20 min, then a copy step after each edit | P3 | [module-swift-only-from-modules-apple](issues/20261027-module-swift-only-from-modules-apple.md) |
| 4 | A native module cannot keep a secret in Exact's store, so its Keychain items outlive a fresh drive. | A test device left signed in on the server | P3 | [native-module-has-no-secret-store](issues/20261027-native-module-has-no-secret-store.md) |
| 5 | The editor cannot resolve native module Swift, so every line shows an error. | No quick feedback while editing | P3 | [editor-cannot-resolve-module-swift](issues/20261027-editor-cannot-resolve-module-swift.md) |
| 6 | `state` prints the value that a password field is bound to. | A password can reach the agent's output | P3 | [agent-state-prints-a-password](issues/20261027-agent-state-prints-a-password.md) |
| 7 | A `role="status"` readout holding a `progress` is hidden from the iOS bar, with no warning. | About 5 min | P3 | [ios-bar-hides-a-status-readout-with-progress](issues/20261027-ios-bar-hides-a-status-readout-with-progress.md) |
| 8 | An app cannot say that it runs on iOS only. | Web tests fail | P3 | [an-app-cannot-say-it-runs-on-ios-only](issues/20261027-an-app-cannot-say-it-runs-on-ios-only.md) |
| 9 | The native-module recipe leaves out the module's folders, its Swift mode, how `clock data` treats `later`, and how to hand the view a file the module wrote. | About 20 min | P3 | [native-module-recipe-gaps](issues/20261027-native-module-recipe-gaps.md) |
| 10 | `contract vocab` names a tag or property but not its attributes or values. | About 5 min | P3 | [vocab-gives-no-attributes-or-values](issues/20261027-vocab-gives-no-attributes-or-values.md) |
| 11 | `prefer root-font-size` enlarges Exact's text but not native fields. | About 3 min | P3 | [prefer-root-font-size-leaves-native-text](issues/20261027-prefer-root-font-size-leaves-native-text.md) |
| 12 | The `chat-thread` recipe fails Exact's own checks as written: `overflow-wrap="anywhere"` (`verify ios`), and a composer field under 44 points (`check`). Fixed in PR #1323 (open). | About 7 min | P3 | [chat-thread-recipe-breaks-inside-words](issues/20261027-chat-thread-recipe-breaks-inside-words.md) |
| 13 | Eight agent messages could say what to do next. | 1 or 2 min each | P3 | [small-agent-drive-messages](issues/20261027-small-agent-drive-messages.md) |
| 14 | Withdrawn: "an app that uses exact2 by path cannot safely follow a rewritten `main`". The cost came from a one-time purge of exact2's git history, not from the framework or from building an app with it. | | | (file removed) |
| 15 | After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` rewrote. | About 2 min | P3 | [update-and-lock-disagree-about-cargo-lock](issues/20261027-update-and-lock-disagree-about-cargo-lock.md) |
| 16 | A drive cannot wait for work that a native module starts by itself or pushes after a mutation, so it needs a fixed real-time wait. | About 6 min, and slow drives | P3 | [a-drive-cannot-wait-for-a](issues/20261027-a-drive-cannot-wait-for-a.md) |
| 17 | `clock until state` and `expect state` take different path forms, and the refusal shows only the grammar. | About 3 min and a wasted drive | P3 | [clock-until-state-and-expect-state](issues/20261027-clock-until-state-and-expect-state.md) |
| 18 | A `compare` step empties the store for the whole drive, and nothing says so. | About 5 min | P3 | [a-compare-step-empties-the-store](issues/20261027-a-compare-step-empties-the-store.md) |
| 19 | A transcript moved by one row when an update removed its first row above the view (seen once, not isolated). | About 10 min to measure | P3 | [a-transcript-moved-by-one-row](issues/20261027-a-transcript-moved-by-one-row.md) |
| 20 | A virtualized list has no place for a row outside its `for`, so a chat cannot show that it is loading older messages, or that it has reached the start. | About 3 min, and a gap in the chat | P3 | [a-virtualized-list-has-no-place](issues/20261027-a-virtualized-list-has-no-place.md) |
| 21 | Closed: fixed in exact2 (`rem` inside `min()` compiles at `ed43ad09a0`). Was: a size could not both scale with the text and stop at a cap. | About 2 min, and a fixed-size picture | P3 | [rem-cannot-go-inside-min-so](issues/closed/20261027-rem-cannot-go-inside-min-so.md) |
| 22 | `ios --device` does not check the pinned toolchain's iPhone Rust target before building; it fails a minute in. | About 3 min | P3 | [ios-device-does-not-check-the](issues/20261028-ios-device-does-not-check-the.md) |
| 23 | `exact update` appends `/.exact/` to `.gitignore` on every run, so an app that keeps its diary in git loses new diary files. | About 10 min | P3 | [exact-update-re-adds-a-gitignore](issues/20261031-exact-update-re-adds-a-gitignore.md) |
| 24 | The theme recipe says `contract vocab -exact-label` answers a role; it does not, and no page lists the roles. | About 10 min | P3 | [the-theme-recipe-says-contract-vocab](issues/20261031-the-theme-recipe-says-contract-vocab.md) |
| 25 | `check` misses the accent fill under a bubble that a sibling paints, so the sample chat app's tailed bubble fails contrast. | About 15 min | P3 | [check-misses-the-accent-fill-under](issues/20261031-check-misses-the-accent-fill-under.md) |
| 26 | A drive cannot fire `swiperight`, and under a real touch a tap on a `link` row misses. | About 10 min | P3 | [a-drive-cannot-fire-swiperight-and](issues/20261031-a-drive-cannot-fire-swiperight-and.md) |
| 27 | A long-press menu has no row of reactions, so a chat app draws its message menu by hand. | About 40 lines | P3 | [a-long-press-menu-has-no](issues/20261031-a-long-press-menu-has-no.md) |
| 28 | Swipe to reply has no recipe: the `transition` gives the spring back (agent-pitfalls says it gives the follow), and `swipeIndicator` and the host's threshold haptic are undocumented. Fixed in PR #1323 (open). | A wrong conclusion in one session, about 40 min in the next | P3 | [swipe-to-reply-has-no-recipe](issues/20261102-swipe-to-reply-has-no-recipe.md) |
| 29 | A drive cannot film a navigation's zoom: `screenshot over` starts after the transition ends (known in exact2's `QUEUE.md`; this adds evidence). | About 10 min | P3 | [a-drive-cannot-film-a-navigation](issues/20261102-a-drive-cannot-film-a-navigation.md) |
| 30 | A `target/` folder built at another path (copied from another checkout) fails the build with `no matching rustc unit dep-info`, and the message does not say to delete it. | About 10 min, then a full build | P3 | [a-target-folder-built-at-another](issues/20261102-a-target-folder-built-at-another.md) |
| 31 | A plain list's separator starts at the initials inside a row's round picture, so the lines jump from row to row (known in exact2's `QUEUE.md`; this adds evidence). | About 15 min | P3 | [a-list-row-s-separator-starts](issues/20261102-a-list-row-s-separator-starts.md) |
| 32 | A labelled image inside a `link` row is left out of the row's VoiceOver label, unlike the web. | About 10 min | P3 | [a-labelled-image-inside-a-link](issues/20261102-a-labelled-image-inside-a-link.md) |
| 33 | `verify` says "tests: did not compile" when it could not pick a simulator. Fixed in PR #1325 (open). | About 3 min | P3 | [verify-says-the-tests-did-not](issues/20261102-verify-says-the-tests-did-not.md) |
| 34 | `verify`'s largest-text pass keeps no screenshots, so a finding there cannot be seen. | About 25 min, not isolated | P3 | [verify-s-largest-text-pass-keeps](issues/20261102-verify-s-largest-text-pass-keeps.md) |
| 35 | A floating bottom bar over a large-title list gets no scroll edge effect, and a route has no bottom toolbar. | About 25 min | P3 | [a-floating-bottom-bar-gets-no-edge-effect](issues/20261102-a-floating-bottom-bar-gets-no-edge-effect.md) |
| 36 | `match` on a string is refused as "expected `some`, found a string". | About 3 min | P3 | [match-on-a-string-is-refused](issues/20261102-match-on-a-string-is-refused.md) |
| 37 | A native button's symbol: the hint says "sized by font-size", `font-size` on the button is ignored without a warning, and an image's `font-size` cannot grow to a cap. | About 16 min | P3 | [a-native-buttons-symbol-size](issues/20261102-a-native-buttons-symbol-size.md) |
| 38 | A picked HEIC photo over 256 KB shows as an empty image, with no log line. | About 10 min and two drives | P2 | [a-picked-heic-photo-over-256](issues/20261102-a-picked-heic-photo-over-256.md) |
| 39 | The docs do not say that a picked file's copy has another name than `Picked.name`. | One wrong send, about 10 min | P3 | [the-docs-do-not-say-that](issues/20261102-the-docs-do-not-say-that.md) |
| 40 | After `check both`, nodes made later in the drive drew in the other color scheme (seen once). | About 8 min and a wrong fix | P3 | [after-check-both-nodes-made-later](issues/20261102-after-check-both-nodes-made-later.md) |
| 41 | `font-size` still refuses `rem` inside `min()`, which `width` now takes (follows closed finding 21). | About 3 min | P3 | [font-size-still-refuses-rem-inside](issues/20261102-font-size-still-refuses-rem-inside.md) |
| 42 | Running a framework script's tests with a newer Bun fails: `ensureBun` drops the `test` verb. | About 3 min | P3 | [running-a-framework-script-s-tests](issues/20261102-running-a-framework-script-s-tests.md) |
| 43 | Parallel sessions on one machine share the default Simulator: an `ios --run` replaced another session's app in the middle of its drive. | About 15 min | P3 | [parallel-sessions-on-one-machine-share](issues/20261102-parallel-sessions-on-one-machine-share.md) |
| 44 | A virtualized list draws rows past its frame, under the bar that follows it, and refuses `overflow`. | About 25 min | P3 | [a-virtualized-list-draws-rows-past](issues/20261102-a-virtualized-list-draws-rows-past.md) |
| 45 | No keyboard fact: a chat cannot keep a message in view as the keyboard comes up. | About 15 min | P3 | [no-keyboard-fact-a-chat-cannot](issues/20261102-no-keyboard-fact-a-chat-cannot.md) |

## What worked well

- Compiler errors name the fix (`lower-grouped-list`, `lower-empty-state-in-list`, symbol aliases).
- `clock data` waits for slow native replies, so tests and drives need no waits.
- Drives mask password fields, and the command log keeps no arguments.
- A `list` with no `appearance` looks like the Messages app with no extra code.
- `formatDay(…, "list")` and `"day-time"` give a chat list's and a transcript's times.
- `modules/apple/*.xcframework` links a vendor's static library with no linker flags.
- `verify ios` rebuilds on its own after exact2 moves.

## What counts as a finding

Only Exact: its compiler, runtime, hosts, tools (`exact.mjs`, the agent, `verify`), docs
and recipes, and the process of building an app with them. The test: the cost came from
Exact, and a change to Exact would remove it.

Not a finding: a cost that came from somewhere else, such as Xcode, the Simulator, a
third-party library, a server, the network, git or the editor, even when it slowed the
task down. Record that in the task's notes (`tasks/todo.md`), not here.

## How to add a finding

1. When Exact costs you time, write it in the task's diary entry at once:
   `apps/multiplexer/.exact/diary/<YYYY-MM-DD>-<topic>.md` (format: `<exact2>/docs/diary.md`).
2. At the end of the task, search exact2's `issues/`, `issues/closed/` and `QUEUE.md`
   for the same problem. Also search the files here.
3. For a new problem, add an issue file here. Run this from this folder:
   `bun <exact2>/scripts/issue.mjs new "<title>" --systems "<a, b>" --severity P3 --author "Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)"`.
   Then write what happened, what would help, and where you saw it (the exact2 commit).
   For a known problem, add your evidence to its file.
4. Run `bun <exact2>/scripts/issue.mjs check` from this folder.
5. Add a row to the table above.
6. Keep each file generic: no app name, product purpose, server name, account name or secret.

If a new diary file does not show in `git status`, check `apps/multiplexer/.gitignore`:
it must keep `!/.exact/diary/`.

## Sent to the Exact team

Findings go to the team through Exact's private feedback tool. Run it from
`apps/multiplexer/`: `bun exact.mjs feedback preview` shows what would go, and
`bun exact.mjs feedback send` sends it. The tool sends only the entries at the top of
`.exact/diary/` and the new command-log lines. It then moves those entries into
`.exact/diary/sent/`, so commit that move.

| Date | Receipt | What | Sent by |
|---|---|---|---|
| 2026-10-27 | `4c8a0a07-60a8-466e-ae9a-bef9a0b29f82` | 4 diary entries (findings 1 to 15, in their Rough sections) and 77 command-log lines | Rami |
| 2026-10-27 | `ac63ff5c-08e3-461b-ae7f-5f1598b2125b` | Findings 1 to 15 as issue files, rechecked at exact2 `cee509ac82`, in the entry `2026-10-27-findings-for-the-team.md` | Claude, at Rami's request |
| 2026-10-27 | `cea3ed9a-11b2-4359-9849-7cab26e44f59` | 2 diary entries (findings 16 to 19, and new evidence for finding 4) and 20 command-log lines | Claude, with Rami's yes |
| 2026-10-27 | `a3326479-5a74-4d5f-8ac3-1351e418d588` | 3 diary entries (finding 20, and new evidence for findings 9, 12 and 16) and 39 command-log lines | Claude, with Rami's yes |
| 2026-11-02 | `f63c011a-dedb-4c1e-ae6b-4bee50181ae4` | 7 diary entries (findings 21 to 29, 33 and 34, and new evidence for findings 13 and 15; from the B1 and inbox entries, findings 30 to 32 and 35 to 37, and new evidence for findings 13 and 17) and 287 command-log lines | Claude, with Rami's yes |

The first two sends include finding 14, which was withdrawn after they were sent.

To take a send back: `bun exact.mjs feedback delete <receipt>`.

To send a new finding: write it as an issue file here and in the task's diary entry, add
its row above, then send. Each send needs Rami's yes.

## Pull requests to exact2

Rami prefers a pull request to sending feedback (2026-11-02): when a finding is a problem
in Exact's docs or recipes that we can fix, fix it in a pull request to exact2
(`ccheever/exact2`; `ccheever/exact47` redirects there). Send feedback only for problems
that are hard to fix ourselves or need the Exact team's view first. Rami's GitHub account
can only read exact2, so a pull request comes from the fork `rami-maalouf/exact2`. Work in
a separate exact2 worktree at `origin/main`, never in the checkout the app uses. exact2's
own rules bind there (`AGENTS.md`, `rules/RULES.md`): its "Writing" section, the six checks,
and a 3,072-byte cap on each recipe (`bun scripts/caps.mjs`).

| Date | Pull request | Findings | State |
|---|---|---|---|
| 2026-11-02 | [#1323](https://github.com/ccheever/exact2/pull/1323): the chat-thread recipe passes `check`, and swipe to reply has a section in `contract-for-agents.md` | 12, 28 | Open |
| 2026-11-02 | [#1325](https://github.com/ccheever/exact2/pull/1325): `verify` says the tests could not run, not that they did not compile | 33 | Open |
