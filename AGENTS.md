# Mux: instructions for agents

Mux (formerly Multiplexer) is Rami's own replacement for Beeper: one app for iPhone
and an experimental Mac build that shows his chats across messaging networks.
Messages go through a Matrix server that Rami controls. The live deployment is
Rami's; public contributors use their own servers and test accounts.
[CONTRIBUTING.md](CONTRIBUTING.md) is the public build guide; [docs/install.md](docs/install.md)
tracks platform and preview limitations.

The approved name, paper-plane logo, and palette are in `docs/brand.md`. Use Mux in
visible copy. Keep existing bundle IDs, Keychain services, App Group, push topics,
storage paths, package names, and test-room names stable across the rename.

**Read `tasks/plan.md` first** (Status, decisions D1 to D8, invariants, facts, risks,
open questions, decision log). The tasks with acceptance criteria are in
`tasks/todo.md`. Update both at the end of a work session.

## Architecture

```
WhatsApp, Signal, ...  <->  mautrix bridges  ->  Synapse (Matrix server)  <->  iOS app
                            (running on Rami's Oracle server)          Exact UI -> native module -> MatrixCore -> matrix-rust-sdk
```

| Folder | What it is |
|---|---|
| `apps/multiplexer/` | The Exact app (iOS and macOS). `app.contract` is the view, `app.ts` the data, `modules/apple/Matrix.swift` the native module. Its own `AGENTS.md` is Exact's generated guide. |
| `matrix-core/` | The only code that calls matrix-rust-sdk. A Swift package with its own tests. Its public API uses plain types only. `NOTES.md` explains how it links. |
| `scripts/setup-matrix-sdk.sh` | Downloads the pinned SDK (`26.10.27`), checks its checksum, and copies the SDK and `matrix-core` into `apps/multiplexer/modules/apple/`. |
| `cli/` | `mx`, the command line for agents (Swift). It links the same MatrixCore (`cli/Sources/MatrixCore` is a link) and a macOS build of the SDK. `cli/README.md` explains it. |
| `scripts/setup-cli-sdk.sh` | Builds the SDK for macOS from the commit of the app's release (about 5 min the first time) and copies it into `cli/.sdk`. |
| `scripts/test-matrix-core.sh` | Runs MatrixCore's live iOS suite; defaults to the designated test users on our server. |
| `vendor/` | The downloaded SDK. Not in git. |
| `tasks/` | The plan and the task list. |
| `docs/exact-feedback/` | Every place where Exact was hard, for Rami and the Exact team: one issue file each, and an index. |

The Exact framework is a separate checkout at `/Users/rami/Documents/code/exact/expo-exact`.
The app uses it by path. Do not put this project inside it. The validated local
integration and its public-reproduction limit are documented in CONTRIBUTING.md.

## Rules

1. Only MatrixCore calls the SDK. The native module calls MatrixCore. This keeps Expo
   possible as a fallback UI.
2. No secrets in git or in chat. The practice account's password is in the Mac's
   Keychain (service `multiplexer-test-account`, account `@rami-m-test:matrix.org`).
3. Prove each step with a test or a screenshot before the next step. Start small.
4. Work from the Mac. Reach the Oracle server only with `ssh oracle`. Do not run an
   agent on the server. Phase 0 is complete; the live inventory is maintainer-specific.
   Contributors must adapt a separate inventory before running any server command.
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

MatrixCore live tests require configured Keychain test credentials and network access.
The full suite can take many minutes; timings from early focused runs do not
estimate the full suite. Use the shared lock:

Two MatrixCore runs at once (two conversations, the same test users) time out on "the first
sync". Hold the shared lock around every run, on your own simulator. Take every shared lock
(`matrixcore` for MatrixCore runs, `auth-drive` for signed-in drives, `integrate` for merges into
the shared branch) only through the helper, which waits, removes a lock whose process is gone, and
always releases its own lock, never another's:
`scripts/mx-lock.sh matrixcore <your-lane> -- ./scripts/test-matrix-core.sh ...`.
Never `rmdir` a lock by hand.
The app builds with a shared local Exact checkout (`expo-exact`, branch
`local/mux-integration`). Never leave uncommitted edits in it: work on Exact in your own
worktree of it, point your build at that, and commit to the shared branch only compiled, tested
changes.
The SDK's start on a new device is CPU-bound: with many Simulators and builds at once, a test's first
sync misses its limit. Keep at most one Simulator booted per conversation, and shut it down
(`xcrun simctl shutdown <udid>`) whenever you are not driving or testing. Shut down only your own Simulator, by its
udid: never `xcrun simctl shutdown all`, which stops other conversations' test runs.

```sh
scripts/mx-lock.sh matrixcore <your-lane> -- ./scripts/test-matrix-core.sh
```

Build, run and drive the app (from `apps/multiplexer/`):

```sh
# for ordinary ui work; this does not package remote push:
bun exact.mjs ios --run
# for a push-capable install, from the repository root:
# bun scripts/install-ios.ts --sim <udid>
# APP_PROFILE=<profile> EXTENSION_PROFILE=<profile> bun scripts/install-ios.ts --device <udid>
bun exact.mjs agent ios "clock data" "state" "screenshot .exact/shot.png"
bun exact.mjs test ios
bun exact.mjs contract build app.contract --json --errors-only
```

- `prefer` takes a full key: `"prefer prefers-color-scheme dark"`.
- **Use native tests:** `test ios` / `verify ios`, and `test mac` for Mac changes.
  The web has no Matrix SDK, so web verification cannot validate chat or sign-in.
  Two tests reach matrix.org and DNS
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

## Paired device demo tooling

- Test the standalone demo tools with `uv run python -m unittest discover -s demo -p 'test_*.py' -v`.
- Argent 0.25.2 controls physical iPhones but cannot record them. Keep the USB-connected
  phone unlocked with Auto-Lock disabled during capture. Compile the wired screen recorder
  with `swiftc demo/capture-phone.swift -o /tmp/mux-capture-phone`; it records video only,
  preserves source timestamps, and stops cleanly on SIGINT or its bounded duration.
- `uv run demo/take-argent.py --help` describes paired capture. It records live Argent
  flows and private timing manifests in a new output directory. Never run on a real account
  without explicit approval of the destination and possible read receipt. Refresh the runner
  if capture teardown leaves a stale USB socket; scope cleanup to the selected device.
- The saved `.devin/flows/*-demo.yaml` flows assume the approved account and inbox state.
  Beeper's fixture uses its recorded family-avatar id because its pinned button has no
  accessible name. Re-record after an avatar change; do not substitute blind tap points.
- Generate the labeled frame with `swift demo/demo-frame.swift <new-frame.png>`, then use
  `uv run demo/compose-private.py <reviewed-edit.json> <frame.png> <new-output.mp4>`.
  Review source frame zero: it must have an inbox header with no private content showing
  through it. The compositor freezes that header during masked scenes, covers the whole
  lower screen including glass toolbars, strips audio/metadata, and preserves gesture speed.
- Run `swift demo/check-redaction.swift <export.mp4> <edit.json> <new-report.json>` after
  visual review. It OCR-checks every masked frame in English and Arabic and fails on findings.
  OCR is supplementary evidence, not a privacy guarantee; inspect transitions and avatars too.
  Keep sources, edit manifests, draft exports and reports in the gitignored `research/` folder.
- Export at the compositor's native-capture target of 60 fps. A 30-fps intermediate discards
  real scroll updates even if the last encoder is told to emit 60 fps. The regression test
  alternates 60 distinct source frames and checks all 59 transitions survive the full graph.
- Approved local unredacted previews require `--unredacted` on both `demo-frame.swift` and
  `compose-private.py`. Otherwise masks and the privacy caption remain the default.
- The recorder writes `<source.mov>.capture.json`: per-sample source PTS, arrival uptime,
  written flag and callback cost, plus writer skips and reported capture drops. Zero drops
  does not prove the phone rendered smoothly or the upstream screen stream delivered 60 Hz.
- Raw capture uses short `durationMs: 300`, `momentum: true` flicks with settling time and
  a fresh accessible top-left back-button tap. Physical iOS durationMs controls drag speed,
  not elapsed time; momentum:false adds an unnatural 300-ms endpoint hold.
- Never skip a received sample just because the writer is temporarily unready. The recorder
  uses a bounded readiness wait, records writerWaits, and rejects reported loss after saving
  diagnostic statistics. Zero writer loss still does not prove smooth upstream delivery.
- `take-argent.py --current-inbox` uses an already registered, verified inbox and approved
  contact, avoiding unnecessary cold restarts. Native raw masters need no compositor.
- The privacy verifier accepts legacy 30-fps and new 60-fps exports using rational minimum
  frame duration; AVFoundation's nominal-frame-rate float can report 30.000002 for exact 30.
