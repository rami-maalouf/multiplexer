# Multiplexer: instructions for agents

Multiplexer is Rami's own replacement for Beeper: one app (iPhone first, Mac later)
that shows all his chats (WhatsApp, Signal, Telegram, Instagram, ...). Messages go
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
- Each edit to a Swift file in `modules/apple/` compiles the SDK's 2 MB of bindings
  again (about 30 to 40 s).
- Exact's only required reading: `/Users/rami/Documents/code/exact/exact2/docs/start-here.md`.
  For a chat screen, see its `chat-thread` recipe.
- Exact asks apps to keep a local diary (`bun exact.mjs feedback status` says `ask`).
  Write it in `apps/multiplexer/.exact/diary/`. Never send it without Rami's yes.

## MatrixCore API (today)

- `MatrixAccount.signIn(homeserver:user:password:deviceName:storeDirectory:)`
- `MatrixAccount.restore(_:storeDirectory:)` with a `SavedSession` from `savedSession()`
- `rooms()`, `messages(roomId:limit:)`, `send(roomId:text:)`, `createRoom(name:)`, `signOut()`
- `MatrixCore.sdkCommit()`

`messages` waits until the timeline stops changing (at most 5 s). The app needs live
updates instead (Phase 2).

## Status (2026-10-27)

Done:
- T1.1 the Exact app exists (`com.ramimaalouf.multiplexer`, no Linux).
- T1.2 the app calls matrix-rust-sdk through the native module.
- T1.3 MatrixCore signs in, lists rooms, sends and reads messages against matrix.org
  (the WhatsApp part waits for the server).

Next:
- **T1.4 sign-in screen:** server, user name and password. On success, show the room
  list. On a wrong password, show an alert. Keep the `SavedSession` in the Keychain, so
  that a relaunch stays signed in. MatrixCore calls are async, so the native module must
  answer with `later`, not `call` (`call` must answer within 100 ms on the main thread).
- **T1.5 room list and read-only chat**, with the `chat-thread` recipe.
- Phase 0 (the server) waits for Rami: Q1, the domain. Rami's recommended option is a
  subdomain only for chat, such as `chat.<domain>`.

Accounts:
- Practice: `@rami-m-test:matrix.org` (password in the Keychain). Its room "Multiplexer test" is for tests.
- `@rami-m:matrix.org` is Rami's own account. It has no password (social sign-in). Do not test with it.
- `@ramimaalouf:beeper.com` is his Beeper account. Do not use it.
