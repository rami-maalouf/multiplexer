# Multiplexer: tasks

The plan, decisions and facts are in `tasks/plan.md`. Phases 0 and 1 are in
detail. Later phases are rough. We detail each one at the checkpoint before it.

T1.1 and T1.2 do not need the server. They can run while Phase 0 waits for DNS.

## Phase 0: prove the server (M0)

### T0.1 Inventory the server (read only)

**Description:** Find out what already runs on `oracle`. The playbook takes over
Docker and ports 80, 443 and 8448, so we must know what is there first.

**Acceptance criteria:**
- [ ] A list of containers, services that listen on ports, and the largest disk users.
- [ ] We know if ports 80, 443 and 8448 are free, or what uses them.
- [ ] Rami decides what stays. The decision is in the plan's decision log.

**Verification:**
- [ ] Output of `sudo docker ps -a`, `sudo ss -tlnup` and `sudo du -xh -d 1 /` saved in `server/notes/inventory.md`.

**Dependencies:** None
**Files:** `server/notes/inventory.md`
**Scope:** XS

### T0.2 Choose the Matrix domain (Rami)

**Description:** Choose the base domain. User IDs become `@rami:<base domain>`.
The server lives at `matrix.<base domain>`. This cannot change after install.

**Acceptance criteria:**
- [ ] Base domain chosen (Q1).
- [ ] We know if the base domain already hosts a website, and how it serves `/.well-known/matrix/server`.
- [ ] Recorded in the decision log.

**Dependencies:** None
**Scope:** XS (a decision)

### T0.3 Set up the playbook on the Mac

**Description:** Install Ansible (and `just`) on the Mac. Clone the playbook at a
pinned commit. Write our inventory for `oracle`, with Synapse as the homeserver
and no bridges yet.

**Acceptance criteria:**
- [ ] `ansible --version` is a version that the playbook's `docs/ansible.md` supports.
- [ ] `ansible -i inventory/hosts all -m ping` answers `pong` from the server.
- [ ] `vars.yml` and other secrets are gitignored. A redacted example is in git.

**Verification:**
- [ ] The ping command above.
- [ ] `git status` shows no secret files.

**Dependencies:** T0.2
**Files:** `.gitignore`, `server/README.md`, `server/inventory/hosts`, `server/inventory/host_vars/matrix.<domain>/vars.yml` (ignored), `vars.example.yml`
**Scope:** S

### T0.4 DNS and firewall

**Description:** Point `matrix.<domain>` at the server. Open the ports in Oracle's
security list and on the server.

**Acceptance criteria:**
- [ ] `dig +short matrix.<domain>` returns the server's public IP.
- [ ] From the Mac, TCP ports 80, 443 and 8448 reach the server.
- [ ] The base domain can serve `/.well-known/matrix/server` (the choice from T0.2).

**Verification:**
- [ ] On the server, `nc -l <port>` for each port. On the Mac, `nc -vz matrix.<domain> <port>`.

**Dependencies:** T0.1, T0.2
**Files:** `server/README.md` (record the Oracle security list rules)
**Scope:** S

### T0.5 Install Synapse only

**Description:** The first playbook run, with no bridges. Prove that Synapse runs
on aarch64 and that Element X can use it.

**Acceptance criteria:**
- [ ] `--tags=self-check` is all green.
- [ ] User `rami` exists (`--tags=register-user`). Element X on my iPhone signs in and sends a message to a test room.
- [ ] We note which images were pulled for arm64 and which were built on the server.

**Verification:**
- [ ] The self-check output and an Element X screenshot.
- [ ] `free -h` and `sudo docker stats --no-stream` after one hour, saved in `server/notes/`.

**Dependencies:** T0.3, T0.4
**Files:** `server/inventory/host_vars/.../vars.yml`, `server/notes/install.md`
**Scope:** S

### T0.6 Add the WhatsApp bridge

**Description:** Turn on mautrix-whatsapp with double puppeting. Link my
WhatsApp account. Messages must flow in both directions.

**Acceptance criteria:**
- [ ] `matrix_bridge_mautrix_whatsapp_enabled: true` and Appservice Double Puppet are on. Self-check is green.
- [ ] `login qr` to `@whatsappbot:<base domain>` links my WhatsApp.
- [ ] A WhatsApp message sent to me shows in Element X. My reply from Element X arrives in WhatsApp.

**Verification:**
- [ ] A manual test with a second person or a second phone. Screenshots of both sides.

**Dependencies:** T0.5, Q3
**Files:** `vars.yml`, `server/notes/install.md`
**Scope:** S

### Checkpoint M0: server proof

Run it after 48 hours of use.

- [ ] Messages flow in both directions. No bridge disconnects in 48 hours.
- [ ] Memory and CPU use noted. Compare them with Oracle's 20% reclaim rule.
- [ ] PostgreSQL backup method chosen.
- [ ] Rami reviews. Decision: continue to Phase 1, or change the server plan.
- [ ] Update **Status** and the **Decision log** in `plan.md`.

## Phase 1: first own screen (M1)

### T1.1 Create the Exact app

**Description:** Make the app with its final name and bundle id. Read
`exact2/docs/start-here.md` first.

**Acceptance criteria:**
- [x] `bun <exact2>/scripts/exact.mjs new apps/multiplexer --name Multiplexer --bundle-id com.ramimaalouf.multiplexer` is done.
- [x] `bun exact.mjs ios --prebuild` finishes. The empty app opens in the iOS Simulator. (2026-10-27: built and installed on the iPhone 17 Pro Simulator in about 2 minutes.)
- [x] `bun exact.mjs feedback status` has run, and the diary follows its answer. (Answer: `ask`. The diary is in `apps/multiplexer/.exact/diary/`. Nothing is sent without Rami's yes.)

**Verification:**
- [ ] `bun exact.mjs agent ios "screenshot .exact/first.png"` shows the app.

**Dependencies:** None (Q2 answered)
**Files:** `apps/multiplexer/` (generated)
**Scope:** S

### T1.2 Spike: call matrix-rust-sdk from an Exact native module

**Description:** The biggest client unknown. Prove that an Exact iOS app can
link `MatrixRustSDK` (Swift bindings and the `MatrixSDKFFI` XCFramework) and
call it. No network and no UI design. Try A first, then B.

- **A:** put `MatrixSDKFFI.xcframework` and the SDK's Swift binding files in `modules/apple/`.
- **B:** build our own `MatrixCore.xcframework` that contains everything, and put it in `modules/apple/`.

**Acceptance criteria:**
- [x] In the iOS Simulator, the app shows text that a matrix-rust-sdk call returned. (2026-10-27: `sdkGitSha()` shows `14a0ada4fc`. Approach A worked.)
- [x] `matrix-core/NOTES.md` explains how it links: which files, how we build them, and the deployment target (the SDK needs iOS 16).
- [x] If neither A nor B works after 3 rounds: write down the blocker and stop for a decision (an Exact change, or Expo). (Not needed: A worked after one fix, copies instead of symlinks.)

**Verification:**
- [x] An `agent ios` screenshot with the SDK's text, in light and dark mode (`apps/multiplexer/.exact/t1.2-sdk*.png`, not in git).

**Dependencies:** T1.1
**Files:** `apps/multiplexer/modules/apple/*`, `matrix-core/NOTES.md`
**Scope:** M

### T1.3 MatrixCore: sign in, rooms, messages

**Description:** A Swift package in `matrix-core/` that depends on a pinned
`matrix-rust-components-swift`. Its public API uses plain types only:
`signIn(homeserver, user, password)`, `restoreSession()`, `rooms()`,
`messages(roomId, limit)`.

**Acceptance criteria:**
- [x] An XCTest in the iOS Simulator signs in to the practice account on matrix.org (D8) and lists its rooms. (2026-10-27: `scripts/test-matrix-core.sh`, 1 passed in 8.7 s. One device sends; a second device with an empty store sees the room and reads the message from the server. Both devices sign out.)
- [ ] After T0.6: the same test against our server lists the WhatsApp chat.
- [x] It returns the last 20 messages of a room, in order, with sender, text and time. (The test checks the newest message and that it is our own.)
- [x] No matrix-rust-sdk type is in MatrixCore's public API. (Public types: `MatrixAccount`, `SavedSession`, `RoomSummary`, `Message`, `MatrixCoreError`. The same files compile in the Exact app.)

**Verification:**
- [ ] `xcodebuild test` on an iOS Simulator destination passes.

**Dependencies:** T1.2, the practice account (D8). The WhatsApp check needs T0.6.
**Files:** `matrix-core/Package.swift`, `matrix-core/Sources/MatrixCore/*.swift`, `matrix-core/Tests/*`
**Scope:** M

### T1.4 Sign-in screen

**Description:** The first real screen. It connects MatrixCore to the app through
the native module.

**Acceptance criteria:**
- [x] I enter the homeserver, user name and password. Success opens the room list. (2026-10-27: the practice account on matrix.org shows its 2 rooms.)
- [x] A wrong password shows an alert with the reason. (Also an unknown server, a server without sliding sync, and too many tries. `SignInError` in MatrixCore names the reason; `app.ts` says it.)
- [x] The session survives a relaunch. The token is in the Keychain, not in plain files. (A new launch opens on the room list. No file in the app's container has a `syt_` token.)
- [x] Added: Sign Out, after a confirmation. It removes the device from the server, the Keychain item and the store folder.

**Verification:**
- [x] An `app.test.contract` test for the error state. (3 tests: Sign In waits for all fields; an unknown server; a wrong password. `verify ios` is clean.)
- [x] A manual sign-in on the Simulator against the practice account on matrix.org (D8).
- [ ] After T0.6: the same sign-in against our server.

**Dependencies:** T1.3
**Files:** `app.contract`, `app.ts`, `modules/apple/Matrix.swift`
**Scope:** M

### T1.5 Room list and read-only chat

**Description:** The room list, newest first, and a chat screen that uses the
`chat-thread` recipe. Read only.

**Acceptance criteria:**
- [x] The room list shows each room's name and last message, newest first. (2026-10-27: a plain list as in Messages: the name, the time in Mail's format, and a 2-line preview: "You: …" for own messages, "Name: …" in a group.)
- [x] A tap opens the chat. It shows the last 20 messages, opened at the newest one. (The test room with 29 messages shows "Fill 5 of 24" to "Fill 24 of 24", in order, scrolled to the newest. A time header shows after a gap of more than an hour; a group shows sender names.)
- [x] `bun exact.mjs verify ios` is clean.

**Verification:**
- [x] Screenshots in light mode, dark mode and the largest text size, reviewed by eye (`apps/multiplexer/.exact/t1.5-*.png`, not in git). The largest size first drew the time over the room name; the row now wraps.

**Found on the way:**
- `TimelineItems.settle()` could return before the diffs of a pagination arrived, so a chat sometimes showed 1 message, not 5 (1 of 3 launches). It now waits at least 0.5 s from the call (5 of 5 launches correct).
- The authored tests cannot sign in (no password in git), so the room list and the chat are checked by drives, not by `app.test.contract`.

**Dependencies:** T1.4
**Files:** `app.contract`, `app.ts`, `modules/apple/Matrix.swift`
**Scope:** M

### Checkpoint M1: first own screen

- [ ] I can read my WhatsApp chat in our app on the Simulator.
- [ ] Framework decision: continue with Exact, or move to Expo with the same MatrixCore. Record why.
- [ ] Rami reviews.
- [ ] Write Phase 2 in detail here, with what we learned.

## Phase 2: daily reading and sending (M2), rough

- Live updates: MatrixCore observes sync and calls `context.changed`.
- A Keychain session whose store is gone (a reinstall) is dropped without telling the server, so its device stays on the account. Sign it out on the server first.
- Room list and chat refresh by hand only (pull to refresh, reopen).
- Send text from the composer.
- Unread counts and read markers.
- Show images.
- Encryption: device verification, and whether bridges use end-to-bridge encryption.
- Build and run on my physical iPhone (Q4).
- Use it for one week, then list what is missing.

## Phase 3: push notifications (M3), rough

- Sygnal on the server with an APNs key (Q4).
- The APNs token in the app. Exact has `subscribePush()` designed but not built. Choose: an app module, or a change to Exact.
- A notification extension target that uses MatrixCore's notification client to decrypt.
- Test memory and the 30-second limit on a real iPhone.

## Phase 4: more networks (M4), rough

- Signal, Telegram, Instagram and Messenger bridges.
- Test each network from the cloud IP before we depend on it.
- Connect a network inside the app with the bridge login API. QR codes (`display_and_wait`) first, then `user_input`, then `cookies` (needs a WKWebView native view).

## Phase 5: Mac app (M5), rough

- Build matrix-rust-sdk's Swift bindings for macOS. The components package is iOS only.
- Run the Exact app on macOS.

## Phase 6: others can install it (M6), rough

- A guided setup from a new VPS and a domain to a working server.
- Oracle Always Free as one supported target among others.
