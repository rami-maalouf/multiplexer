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

Each finding was rechecked against exact2 `cee509ac82` (2026-10-27).

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
| 9 | The native-module recipe leaves out the module's folders, its Swift mode and how `clock data` treats `later`. | About 15 min | P3 | [native-module-recipe-gaps](issues/20261027-native-module-recipe-gaps.md) |
| 10 | `contract vocab` names a tag or property but not its attributes or values. | About 5 min | P3 | [vocab-gives-no-attributes-or-values](issues/20261027-vocab-gives-no-attributes-or-values.md) |
| 11 | `prefer root-font-size` enlarges Exact's text but not native fields. | About 3 min | P3 | [prefer-root-font-size-leaves-native-text](issues/20261027-prefer-root-font-size-leaves-native-text.md) |
| 12 | The `chat-thread` recipe uses `overflow-wrap="anywhere"`, which `verify ios` reports. | About 2 min | P3 | [chat-thread-recipe-breaks-inside-words](issues/20261027-chat-thread-recipe-breaks-inside-words.md) |
| 13 | Four agent messages could say what to do next. | 1 or 2 min each | P3 | [small-agent-drive-messages](issues/20261027-small-agent-drive-messages.md) |
| 14 | Withdrawn: "an app that uses exact2 by path cannot safely follow a rewritten `main`". The cost came from a one-time purge of exact2's git history, not from the framework or from building an app with it. | | | (file removed) |
| 15 | After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` rewrote. | About 2 min | P3 | [update-and-lock-disagree-about-cargo-lock](issues/20261027-update-and-lock-disagree-about-cargo-lock.md) |
| 16 | A drive cannot wait for work that a native module starts by itself, so it needs a fixed real-time wait. | About 3 min, and a slow drive | P3 | [a-drive-cannot-wait-for-a](issues/20261027-a-drive-cannot-wait-for-a.md) |
| 17 | `clock until state` and `expect state` take different path forms, and the refusal shows only the grammar. | About 3 min and a wasted drive | P3 | [clock-until-state-and-expect-state](issues/20261027-clock-until-state-and-expect-state.md) |
| 18 | A `compare` step empties the store for the whole drive, and nothing says so. | About 5 min | P3 | [a-compare-step-empties-the-store](issues/20261027-a-compare-step-empties-the-store.md) |
| 19 | A transcript moved by one row when an update removed its first row above the view (seen once, not isolated). | About 10 min to measure | P3 | [a-transcript-moved-by-one-row](issues/20261027-a-transcript-moved-by-one-row.md) |

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

Both sends above include finding 14, which was withdrawn after they were sent.

To take a send back: `bun exact.mjs feedback delete <receipt>`.

To send a new finding: write it as an issue file here and in the task's diary entry, add
its row above, then send. Each send needs Rami's yes.

A public pull request to exact2 (`ccheever/exact47`) is the other way: the files in
`issues/` go into exact2's `issues/` folder, from a fork, because Rami's GitHub account can
only read the repo. Not done; it needs Rami's yes. After a finding is in exact2, exact2's
copy is the one to update: delete the file here and link the row to exact2's file.
