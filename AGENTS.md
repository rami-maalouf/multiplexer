# Multiplexer: instructions for agents

Multiplexer is Rami's own replacement for Beeper: one app (iPhone first, Mac later)
that shows all of Rami's chats (WhatsApp, Signal, Telegram, Instagram, ...). Messages go
through a Matrix server that Rami controls. Rami is the only user for now.

**Read `tasks/plan.md` first** (Status, decisions D1 to D8, invariants, facts, risks,
open questions, decision log). The tasks with acceptance criteria are in
`tasks/todo.md`. Update both at the end of a work session.

## Architecture

```
WhatsApp, Signal, ...  <->  mautrix bridges  ->  Synapse (Matrix server)  <->  iOS app
                            (on Rami's Oracle server, not set up yet)          Exact UI -> native module -> MatrixCore -> matrix-rust-sdk
```

| Folder | What it is |
|---|---|
| `apps/multiplexer/` | The Exact app (iOS; Mac later). `app.contract` is the view, `app.ts` the data, `modules/apple/Matrix.swift` the native module. Its own `AGENTS.md` is Exact's generated guide. |
| `matrix-core/` | The only code that calls matrix-rust-sdk. A Swift package with its own tests. Its public API uses plain types only. `NOTES.md` explains how it links. |
| `scripts/setup-matrix-sdk.sh` | Downloads the pinned SDK (`26.10.27`), checks its checksum, and copies the SDK and `matrix-core` into `apps/multiplexer/modules/apple/`. |
| `scripts/test-matrix-core.sh` | Runs MatrixCore's end-to-end test on the iOS Simulator against matrix.org. |
| `vendor/` | The downloaded SDK. Not in git. |
| `tasks/` | The plan and the task list. |
| `docs/exact-feedback/` | Every place where Exact was hard, for Rami and the Exact team: one issue file each, and an index. |

The Exact framework is a separate checkout at `/Users/rami/Documents/code/exact/exact2`.
The app uses it by path. Do not put this project inside it.

## Rules

1. Only MatrixCore calls the SDK. The native module calls MatrixCore. This keeps Expo
   possible as a fallback UI.
2. No secrets in git or in chat. The practice account's password is in the Mac's
   Keychain (service `multiplexer-test-account`, account `@rami-m-test:matrix.org`).
3. Prove each step with a test or a screenshot before the next step. Start small.
4. Work from the Mac. Reach the Oracle server only with `ssh oracle`. Do not run an
   agent on the server. The server is not set up yet: Phase 0 waits for Rami's domain.
5. Commit after each task: conventional prefix, lowercase, one line, no co-author line.
6. Ask Rami before deleting anything on the server, and before anything that costs money.

## How to work

After a fresh clone, or after any edit in `matrix-core/`:

```sh
./scripts/setup-matrix-sdk.sh
```

Exact refuses symlinks inside the app folder, so the script copies the files (APFS
clones). The copies are gitignored. **If you edit `matrix-core/`, run the script again,
or the app builds the old copy.**

Test MatrixCore (about 10 s after the first build):

```sh
./scripts/test-matrix-core.sh
```

Build, run and drive the app (from `apps/multiplexer/`):

```sh
bun exact.mjs ios --run
bun exact.mjs agent ios "clock data" "state" "screenshot .exact/shot.png"
bun exact.mjs test ios
bun exact.mjs contract build app.contract --json --errors-only
```

- `prefer` takes a full key: `"prefer prefers-color-scheme dark"`.
- **The app's tests run on iOS only** (`test ios`, `verify ios`). The web has no Matrix
  SDK, so `verify` on the web fails the sign-in tests. Two tests reach matrix.org and DNS
  (no real account): they need the network.
- **Sign in to the practice account in a drive** without the password in chat or logs:
  `pw="$(security find-generic-password -s multiplexer-test-account -a @rami-m-test:matrix.org -w)"`,
  then `"type password $pw"`. The drive masks a password field. Do not run `state` before
  the sign-in ends: it shows the `password` state. Sign out at the end of the drive, so
  matrix.org does not collect old devices.
- Each drive is a new launch. The agent keeps its own session (Keychain service
  `com.ramimaalouf.multiplexer.session.agent`) and data, so a drive after a sign-in opens
  signed in. Each authored test starts signed out.
- `prefer root-font-size 53` scales only Exact's text. To see the real largest text size,
  `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`, then set
  it back (`large`).
- Each edit to a Swift file in `modules/apple/` compiles the SDK's 2 MB of bindings
  again (about 30 to 40 s).
- Exact's only required reading: `/Users/rami/Documents/code/exact/exact2/docs/start-here.md`.
  For a chat screen, see its `chat-thread` recipe.

## Exact feedback: always record it

Rami and the Exact team use this app to improve Exact. Every place where Exact slowed
you down is feedback, and recording it is part of each task, not optional. Start at
**`docs/exact-feedback/README.md`**: the list of findings, and how to add one.

- Keep one diary entry per task: `apps/multiplexer/.exact/diary/<YYYY-MM-DD>-<topic>.md`,
  in the format of `<exact2>/docs/diary.md` (Rough, Lean in, Needed, Checkpoints). The
  diary is in git.
- **Write a Rough entry when the struggle happens**, not from memory at the end. Record
  what you tried, the error text, about how long it cost, what you did instead, and what
  would have helped (a message, a doc line, a feature).
- Count as Rough: a compile or build error that was not clear, a doc you had to grep
  for, a `contract vocab` lookup that gave nothing useful, Exact source you had to read,
  a drive or `verify` result that misled you, a slow Exact build or drive, editor errors
  that Exact's project setup causes, and **every workaround for Exact that you write into
  this file**.
- **Only the framework.** Record only costs that came from Exact (its compiler, runtime,
  hosts, tools, docs and recipes) or from the process of building an app with it. The
  test: a change to Exact would remove the cost. A cost from Xcode, the Simulator, a
  third-party library, a server, the network, git or the editor is not feedback, even
  when it slowed the task down. Note it in `tasks/todo.md` instead.
- Keep it generic: no app name, no product purpose, no server names, no account names,
  no secrets. Write "a chat app", "a public server", "a third-party library".
- At the end of each task, turn each new Rough entry into a finding in
  `docs/exact-feedback/issues/` (or add evidence to a known one), and add its row to the
  README's table. The README gives the steps.
- Then run `bun exact.mjs feedback status`. The answer is `ask`, so ask Rami once whether
  to send, quoting 2 to 4 lines. Send nothing, and open no pull request to exact2,
  without Rami's yes: exact2 is public.

## Test accounts

**Safety rule.** `@rami:ramimaalouf.com` is Rami's real account: it holds his real
WhatsApp, so a message sent in one of its rooms reaches a real person. Tests and drives
send, react, delete and mark as read only as `@test1:ramimaalouf.com` or
`@test2:ramimaalouf.com` (Keychain service `multiplexer-test-account`). On `@rami`: read-only
drives, and only with Rami's OK; sign out at the end. A read receipt there also marks the
chat read in WhatsApp (double puppeting).


- Practice: `@rami-m-test:matrix.org`. Its password is in the Keychain. Its room "Multiplexer test" is for tests.
  It holds more than 20 messages, so the chat shows only its last 20. To add numbered
  messages: `MATRIX_TEST_FILL=24 ./scripts/test-matrix-core.sh -only-testing:MatrixCoreTests/MatrixCoreTests/testFillTheTestRoom`.
- A drive's clock starts at 2026-01-01, so today's messages show as dates. Add
  `--epoch now --time-zone America/New_York` to `agent ios` to see real times.
- `./scripts/send-test-message.sh "<text>"` sends a message to the test room from a
  short-lived second device; `--image <photo.jpg> ["<caption>"]` sends a photo. To see it arrive in a drive, start it in the background with
  a delay, then wait with `"clock until state thread.messages.20.body == \"<text>\" within 45000"`
  (no space after the index here, unlike `expect state`).
- A drive with `screenshot … compare` starts with an empty store, so it starts signed out.
- `./scripts/list-test-devices.sh` lists the practice account's devices. Tests and drives
  should leave none behind. matrix.org refuses device deletion through the API, so a
  leftover device must be removed in Element or at account.matrix.org.
- Do not test with `@rami-m:matrix.org` or `@ramimaalouf:beeper.com`: they are Rami's real accounts.
