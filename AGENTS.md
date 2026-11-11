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

The Exact framework is a separate checkout at `/Users/rami/Documents/code/exact/expo-exact`.
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

GIFs (B12) need KLIPY's app key at build. Once per checkout, and after the key changes:

```sh
./scripts/setup-klipy-key.sh   # Keychain -> apps/multiplexer/.env.local (gitignored)
```

Without it the app builds, and the GIF sheet says it could not load GIFs.

Test MatrixCore (about 10 s after the first build):

Two MatrixCore runs at once (two conversations, the same test users) time out on "the first
sync". Hold the shared lock around every run, on your own simulator. Take every shared lock
(`matrixcore` for MatrixCore runs, `auth-drive` for signed-in drives, `integrate` for merges into
the shared branch) only through the helper, which waits, removes a lock whose process is gone, and
always releases its own lock, never another's:
`scripts/mx-lock.sh matrixcore <your-lane> -- ./scripts/test-matrix-core.sh ...`.
Never `rmdir` a lock by hand.
The app builds with [expo/exact](https://github.com/expo/exact) at
`/Users/rami/Documents/code/exact/expo-exact` (migration baseline
`94b8671f70fe2e25b307a40e7fce66dc27c9f802`). `EXACT2` overrides the launcher checkout.
Keep framework experiments in a separate worktree; the shared upstream checkout stays clean.
After moving it, regenerate the app integration with its `exact new <app-path> --update` command.
The SDK's start on a new device is CPU-bound: with many Simulators and builds at once, a test's first
sync misses its limit. Keep at most one Simulator booted per conversation, and shut it down
(`xcrun simctl shutdown <udid>`) whenever you are not driving or testing. Shut down only your own Simulator, by its
udid: never `xcrun simctl shutdown all`, which stops other conversations' test runs.

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
  the sign-in ends: it shows the `password` state. On matrix.org, sign out at the end of the
  drive, so it does not collect old devices. As `@test1`/`@test2` on our own server, stay signed
  in across drives on your own Simulator (the agent keeps its session), and sign out only when
  your task ends: our server can delete leftover devices. On any real account, always sign out at the end.
- Each drive is a new launch. The agent keeps its own session (Keychain service
  `com.ramimaalouf.multiplexer.session.agent`) and data, so a drive after a sign-in opens
  signed in. Each authored test starts signed out.
- `prefer root-font-size 53` scales only Exact's text. To see the real largest text size,
  `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`, then set
  it back (`large`).
- Each edit to a Swift file in `modules/apple/` compiles the SDK's 2 MB of bindings
  again (about 30 to 40 s).
- Exact's only required reading: `/Users/rami/Documents/code/exact/expo-exact/docs/start-here.md`.
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

**Safety rule.** Only the explicitly listed test accounts may be used for automated
tests or actions that modify data: `@test1:ramimaalouf.com`,
`@test2:ramimaalouf.com` (Keychain service `multiplexer-test-account`), and the
practice account below in its test room. Treat every other account as a real account:
read-only access requires Rami's explicit approval, and sign out afterward. Sending,
reacting, deleting or marking a chat read can affect real people on connected networks.

Read `.local/accounts.md` if it exists for private account identities and Keychain
lookup details. This file is local only and ignored by git. Do not copy its contents
into tracked files, feedback, issues, pull requests or chat. If it is absent, keep the
same test-account-only rule; request private account details only when needed for an
explicitly authorized real-account drive.

- Practice: `@rami-m-test:matrix.org`. Its password is in the Keychain. Its room "Multiplexer test" is for tests.
  It holds more than 20 messages, so the chat shows only its last 20. To add numbered
  messages: `MATRIX_TEST_FILL=24 ./scripts/test-matrix-core.sh -only-testing:MatrixCoreTests/MatrixCoreTests/testFillTheTestRoom`.
- A drive's clock starts at 2026-01-01, so today's messages show as dates. Add
  `--epoch now --time-zone America/New_York` to `agent ios` to see real times.
- `./scripts/send-test-message.sh "<text>"` sends a message from a short-lived device of a
  test user (default `SENDER=@test2:ramimaalouf.com`, `ROOM="Multiplexer two-person test"`);
  `--image <photo.jpg> ["<caption>"]` sends a photo. Run it only with the listed test users.
- In a drive, the app sends read receipts only for `@test` users (`Matrix.swift`,
  `sendsReadReceipts`). To see it arrive in a drive, start it in the background with
  a delay, then wait with `"clock until state thread.messages.20.body == \"<text>\" within 45000"`
  (no space after the index here, unlike `expect state`).
- A drive with `screenshot … compare` starts with an empty store, so it starts signed out.
- `./scripts/list-test-devices.sh` lists the practice account's devices. Tests and drives
  should leave none behind. matrix.org refuses device deletion through the API, so a
  leftover device must be removed in Element or at account.matrix.org.
- `./scripts/clean-test-devices.sh [--older-than <hours>] [--delete]` lists `@test1`'s and `@test2`'s
  devices on our server not seen for that long (default 24 h); a dry run unless `--delete`. It never
  touches real accounts. Ask Rami before the first `--delete` (deleting on the server).
- MatrixCore tests share one signed-in device per test user for a whole run (`testAccount` in
  `TestDevices.swift`); it signs out when the run ends. Use `signInTestDevice` (a fresh device, marked
  `FRESH DEVICE`) only when a new device is the point of the test.
- Do not test with any account outside the explicit test-account list above.
