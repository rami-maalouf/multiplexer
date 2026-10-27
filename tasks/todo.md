# Multiplexer: tasks

The plan, decisions and facts are in `tasks/plan.md`. Phases 0 and 1 are in
detail. Later phases are rough. We detail each one at the checkpoint before it.

T1.1 and T1.2 do not need the server. They can run while Phase 0 waits for DNS.

## Phase 0: prove the server (M0)

### T0.1 Inventory the server (read only)

**Description:** Find out what already runs on `oracle`. The playbook takes over
Docker and ports 80, 443 and 8448, so we must know what is there first.

**Acceptance criteria:**
- [x] A list of containers, services that listen on ports, and the largest disk users. (2026-10-27: `server/notes/inventory.md`.)
- [x] We know if ports 80, 443 and 8448 are free, or what uses them. (Free. Docker is installed but disabled; old n8n and Postiz images and volumes remain.)
- [x] Rami decides what stays. The decision is in the plan's decision log. (2026-10-27: keep all old Docker data; the playbook may turn Docker on and keep it on at boot.)

**Verification:**
- [x] The containers, the listening ports and the disk use, saved in `server/notes/inventory.md`. (The Docker daemon is stopped, so the old images and volumes were read from `/var/lib/docker` without starting it.)

**Dependencies:** None
**Files:** `server/notes/inventory.md`
**Scope:** XS

### T0.2 Choose the Matrix domain (Rami)

**Description:** Choose the base domain. User IDs become `@rami:<base domain>`.
The server lives at `matrix.<base domain>`. This cannot change after install.

**Acceptance criteria:**
- [ ] Base domain chosen (Q1). (Proposed: `ramimaalouf.com`, server at `matrix.ramimaalouf.com`. Waits for Rami's explicit yes.)
- [x] We know if the base domain already hosts a website, and how it serves `/.well-known/matrix/server`. (2026-10-27: an Astro site on Vercel, repo `~/Documents/code/web/portfolio`. Static files in `public/.well-known/matrix/`, with `Content-Type` and CORS headers in `vercel.json`: branch `matrix-well-known`, commit `80e243a`, not pushed. `ramimaalouf.com` answers 301 to `www`; Synapse and matrix-rust-sdk follow it.)
- [ ] Recorded in the decision log.

**Dependencies:** None
**Scope:** XS (a decision)

### T0.3 Set up the playbook on the Mac

**Description:** Install Ansible (and `just`) on the Mac. Clone the playbook at a
pinned commit. Write our inventory for `oracle`, with Synapse as the homeserver
and no bridges yet.

**Acceptance criteria:**
- [x] `ansible --version` is a version that the playbook's `docs/ansible.md` supports. (2026-10-27: Ansible 14.5.0, ansible-core 2.21.5, with `uv tool`. The docs ask for ansible-core 2.15.1 or newer.)
- [x] `ansible -i inventory/hosts all -m ping` answers `pong` from the server. (`ansible -i server/inventory/hosts all -m ping`.)
- [x] `vars.yml` and other secrets are gitignored. A redacted example is in git. (`vars.yml` holds only the two secrets; `server/setup.sh` writes it from the Keychain, service `multiplexer-server`. The settings are in `config.yml`, in git. Example: `server/vars.example.yml`.)

**Verification:**
- [x] The ping command above.
- [x] `git status` shows no secret files.

**Found on the way:**
- The playbook has no release tags. `server/setup.sh` pins commit `e3929968b8` (master on 2026-10-27) and fetches only that commit: a full clone stalled at 25 MB.
- `just` is not needed: `setup.sh` calls `ansible-galaxy` for the roles, and `playbook.sh` runs `ansible-playbook`.
- The inventory reaches the server as `ansible_host=oracle`, so the SSH key path stays in `~/.ssh/config`.

**Dependencies:** T0.2
**Files:** `.gitignore`, `server/README.md`, `server/setup.sh`, `server/playbook.sh`, `server/inventory/hosts`, `server/inventory/host_vars/matrix.ramimaalouf.com/config.yml`, `.../vars.yml` (ignored), `server/vars.example.yml`
**Scope:** S

### T0.4 DNS and firewall

**Description:** Point `matrix.<domain>` at the server. Open the ports in Oracle's
security list and on the server.

**Acceptance criteria:**
- [ ] `dig +short matrix.<domain>` returns the server's public IP. (Rami: Cloudflare `A matrix -> 192.18.154.172`, proxy off.)
- [ ] From the Mac, TCP ports 80, 443 and 8448 reach the server. (2026-10-27: 80 and 443 yes, 8448 no. Rami: Oracle security list ingress for TCP 8448 and UDP 443, 8448.)
- [ ] The base domain can serve `/.well-known/matrix/server` (the choice from T0.2). (Ready on the website's branch `matrix-well-known`; Rami reviews and pushes.)

**Verification:**
- [ ] On the Mac, `nc -vz matrix.<domain> <port>`. "Connection refused" proves that the packet reached the host (nothing listens yet), so no listener on the server is needed. A timeout means the security list drops it.

**Found on the way:**
- The host firewall blocks nothing, so the server needs no change (details: `server/README.md`, Network). `/etc/iptables/rules.v4` is not loaded: `iptables-persistent` was removed on 2025-08-11.

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

**Before the first run:** Rami's explicit yes to the domain (the server name can never change).
The install also replaces `/etc/apt/sources.list.d/docker.list` with an equal `docker.sources`
(the playbook's Docker role), and turns Docker on at boot.

**Dependencies:** T0.3, T0.4
**Files:** `server/inventory/host_vars/.../config.yml`, `server/register-user.sh`, `server/notes/install.md`
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

- [ ] I can read my WhatsApp chat in our app on the Simulator. (Waits for Phase 0, which waits for Q1.)
- [x] Framework decision: continue with Exact, or move to Expo with the same MatrixCore. Record why. (2026-10-27, Rami: Exact. See the decision log.)
- [x] Rami reviews. (2026-10-27)
- [x] Write Phase 2 in detail here, with what we learned.

## Phase 2: daily reading and sending (M2)

Written at the M1 checkpoint (2026-10-27). The client work runs on the practice account
until the server is ready (D8). What we learned in Phase 1:

- Exact's `clock data` waits for slow native replies, so drives and tests need no waits.
- The authored tests cannot sign in (no password in git). Screens behind sign-in are
  checked by drives that type the password from the Keychain (`AGENTS.md`).
- `verify ios` resets the agent's data but not the Keychain. The module then drops the
  session, and its device stays on the server.
- Each Swift edit takes 30 to 40 s to build. Batch Swift edits; iterate on `app.contract`
  and `app.ts` (seconds).
- The SDK delivers timeline changes on its own task. Read them only after they settle.

### T2.1 Sign out a stale session on the server

**Description:** When the Keychain has a session but its store folder is gone (a
reinstall, or `verify ios`), sign that device out on the server before the app forgets
it. Use a temporary store folder for the sign-out, then delete it.

**Acceptance criteria:**
- [x] After a drive signs in and `verify ios` runs, the next launch is signed out, and the account's device list does not keep the old device. (2026-10-27: device `KZqwpyN8n8` gone after `verify ios`.)
- [x] If the server cannot be reached, the app still opens signed out. It does not wait more than 10 s. (The app does not wait at all: the session moves to a second Keychain slot, `sign-out`, and a background task signs it out. If the server cannot be reached, the next launch tries again. Sign Out uses the same slot when the server cannot be reached.)

**Verification:**
- [x] `scripts/list-test-devices.sh` lists the account's devices (the SDK has no call for it, so it uses the HTTP API). A drive signs in, `verify ios` runs, a drive launches; the drive's device is gone.
- [x] MatrixCore test `testSignOutOnServerWithoutTheStore`: the old token is refused 0.1 to 0.9 s after the sign-out (matrix.org drops it within a second, not at once); an unreachable server returns false.

**Found on the way:**
- matrix.org signs in through its account service (`account.matrix.org`), so the HTTP API refuses device deletion (`M_UNRECOGNIZED`). The older leftover device `B7E9i45YI2` must be removed by hand, in Element or at account.matrix.org.
- A failed `xcodebuild test` waited 10 minutes for `simctl diagnose`. `scripts/test-matrix-core.sh` now passes `-collect-test-diagnostics never`.

**Dependencies:** None
**Files:** `matrix-core/Sources/MatrixCore/*.swift`, `modules/apple/Matrix.swift`
**Scope:** S

### T2.2 Live updates

**Description:** The biggest unknown of Phase 2. MatrixCore keeps the sync running and
tells the app when the room list or the open chat changes. The module calls
`context.changed("rooms")` and `context.changed("thread")`; `app.ts` calls `native.watch`
for each. The open chat keeps one live timeline, so a change costs no new pagination.

**Acceptance criteria:**
- [x] A message that another device sends shows in the open chat within 3 s, with no pull to refresh. (2026-10-27: 1 to 2 s in the app; the MatrixCore test sees it within 1.4 s.)
- [x] The same message moves its room to the top of the list and updates the preview and the time. (The preview and the time update. The list sorts by the last message's time; the test room was already at the top, so a move was not seen.)
- [x] Scrolled up in a long chat, a new message does not move what I read. (`tree --ax` frames are the same before and after.)
- [x] Opening a chat a second time does not page back again (the timeline is kept). (The MatrixCore test: a second `messages()` returns in under 0.3 s.)

**Verification:**
- [x] A drive opens the test room while `scripts/send-test-message.sh` sends from another device. `clock until state thread.messages.20.body == "…"` sees the new message.
- [x] Screenshots before and after (`apps/multiplexer/.exact/t2.2-*.png`, not in git).

**Found on the way:**
- The chat showed only the last 20 messages, so each new message pushed the oldest one out, and the rows the reader saw moved up. Now a chat keeps every message from the first one it showed at open.
- The room list listener needs `setFilter(kind: .joined)` on its controller before it reports changes.

**Dependencies:** T2.1
**Files:** `matrix-core/Sources/MatrixCore/*.swift`, `modules/apple/Matrix.swift`, `app.ts`, `app.contract`
**Scope:** M

### T2.3 Send text

**Description:** The composer from the `chat-thread` recipe. A sent message shows at
once (the SDK's local echo), then shows as delivered. A failure shows "Not Delivered"
and a way to try again.

**Acceptance criteria:**
- [x] I type and tap Send. The message shows at once and the composer clears. The keyboard stays up. (2026-10-27: dimmed while sending, sent in about 1 s; the caret stays in the composer.)
- [x] Another device receives it. (A separate device read "Composer check 160246" from the server.)
- [ ] With the network off, the message shows "Not Delivered". Try Again sends it when the network is back. (Partly: "Not Delivered", Try Again and Delete work with a message the server refuses (over the 65,536-byte limit). The Simulator shares the Mac's network, so the offline case waits for T2.7, in airplane mode.)
- [x] Added: Delete on a failed message. The sdk keeps a refused message in its queue across launches, so without Delete it stays forever.

**Verification:**
- [x] MatrixCore test `testASentMessageShowsAtOnceThenSentAndARefusedOneFails`: sending, then sent under the same id; a refused message fails; retry and discard.
- [x] A drive sends from the composer; another device reads it back. A drive shows the failed state, Try Again and Delete.
- [x] `check` is clean on the chat in light, dark and at the largest text size (after the composer's field was made 44 points tall).

**Dependencies:** T2.2
**Files:** `matrix-core/`, `modules/apple/Matrix.swift`, `app.ts`, `app.contract`
**Scope:** M

### T2.4 Unread counts and read markers

**Description:** The room list shows how many messages I have not read. Opening a chat
marks it read on the server, so Element and my other devices agree.

**Acceptance criteria:**
- [ ] A message from another device shows a count on its room, and the room title is bold.
- [ ] Opening the chat clears the count here and in Element.

**Verification:**
- [ ] A drive with a send from another device, before and after opening the chat.

**Dependencies:** T2.2
**Scope:** S

### T2.5 Show images

**Description:** A photo message shows as a thumbnail in its bubble. MatrixCore downloads
the thumbnail into the app's cache; the view shows the file. A tap opens it full screen.

**Acceptance criteria:**
- [x] A photo sent from another client (later, from WhatsApp) shows as a thumbnail with the right aspect ratio. (2026-10-27: photos sent through the client-server API, 1200×800, 800×1200 and 600×900, show at their ratio in a box at most 15 rem wide and 18 rem tall; the box keeps its shape while the thumbnail downloads; a caption shows as a bubble below.)
- [x] The room list preview says "Photo".
- [x] A tap shows the full image; Back returns to the chat. (A full-screen viewer that zooms out of the thumbnail, with the sender and the time in its bar; the full picture replaces the thumbnail when it is here.)

**Verification:**
- [x] MatrixCore test `testAPhotoMessageHasItsSizeAndDownloads`: the size and caption; the thumbnail and the full picture decode, at the right size and ratio; a second call downloads nothing.
- [x] `check` is clean on the chat and the viewer in light, dark and at the largest text size.

**Found on the way:**
- A test that failed before its last line left its device on the account. Every test sign-in now signs out in a teardown, even when the test fails (checked with a forced early stop: no device left).

**Dependencies:** T2.2
**Scope:** M

### T2.6 Encryption

**Description:** Decide, then build, what encryption we need. Bridged rooms are not
encrypted unless the bridge's end-to-bridge encryption is on (decide in Phase 0). Rooms
with other Matrix users usually are.

**Acceptance criteria:**
- [ ] A decision in the log: end-to-bridge encryption on or off, and why. (Waits for T0.6.)
- [x] In an encrypted room, messages sent after this device signed in show as text. (2026-10-27: the room "Multiplexer encrypted test", made by MatrixCore; another device's message shows as text at once; a message sent from the app is encrypted and shows as text.)
- [x] Added: a message this device has no key for shows as "Waiting for this message", not nothing. Before, MatrixCore dropped it from the chat.
- [ ] Older messages show after I enter the recovery key (key backup). (Waits for T0.5: the practice account has no recovery, and turning it on would add an encryption identity to an account Rami also uses in Element. Test it with a test user on our own server.)

**Found on the way:**
- A room whose newest message this device cannot read has no preview and no time in the chat list, so it sorts last.

**Dependencies:** T2.2, T0.6 (for the bridge decision)
**Scope:** M

### T2.7 Run on my iPhone

**Description:** Build, sign and install on Rami's physical iPhone. Check the Keychain,
the build size and the start time on a real device.

**Acceptance criteria:**
- [ ] `bun exact.mjs ios --device --run` installs and opens the app on my iPhone.
- [ ] Sign in, relaunch, chats and sending work as on the Simulator.

**Dependencies:** Q4 (the Apple team). It can move earlier as soon as Q4 is answered.
**Also check here:** T2.3's offline case (airplane mode: "Not Delivered", then Try Again sends it).
**Scope:** S

### T2.8 Load older messages

**Description:** Added at the end of T2.5: a chat showed only its last 20 messages, with
no way to read older ones. Scrolling up loads 20 more each time, up to the room's first
message, and keeps the reader's place.

**Acceptance criteria:**
- [x] Scrolling up near the top of a chat loads 20 older messages. (2026-10-27: the count goes from 20 to 40.)
- [x] The rows I read do not move when older ones are added above. (`tree --ax`: 9 visible rows at the same place before and after.)
- [x] At the room's first message, loading stops. (The test room's 58 messages, from "Multiplexer test 48643855…".)
- [ ] A sign that older messages are loading, and that the chat has reached its start. (Not possible yet in Exact's virtualized list: finding 20.)

**Verification:**
- [x] MatrixCore test `testOlderMessagesLoadUntilTheStart`.
- [x] A drive that scrolls to the top of the test room.

**Dependencies:** T2.2
**Scope:** S

### Checkpoint M2: daily reading and sending

- [ ] On my iPhone, against our server: live updates, sending, unread counts.
- [ ] I use it for one week. Then list what is missing, and write Phase 3 in detail.
- [ ] Rami reviews.

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
