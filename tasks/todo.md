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
- [x] Base domain chosen (Q1). (2026-10-27, Rami: `ramimaalouf.com`. User IDs `@name:ramimaalouf.com`; Synapse at `matrix.ramimaalouf.com`.)
- [x] We know if the base domain already hosts a website, and how it serves `/.well-known/matrix/server`. (2026-10-27: an Astro site on Vercel, repo `~/Documents/code/web/portfolio`. Static files in `public/.well-known/matrix/`, with `Content-Type` and CORS headers in `vercel.json`: branch `matrix-well-known`, commit `80e243a`, not pushed. `ramimaalouf.com` answers 301 to `www`; Synapse and matrix-rust-sdk follow it.)
- [x] Recorded in the decision log.

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
- [x] `dig +short matrix.<domain>` returns the server's public IP. (2026-10-27: Rami added Cloudflare `A matrix -> 192.18.154.172`, DNS only. 1.1.1.1, 8.8.8.8 and Cloudflare's name server return it.)
- [x] From the Mac, TCP ports 80, 443 and 8448 reach the server. (2026-10-27: Rami added TCP 8448, UDP 443 and UDP 8448 to the security list; all three TCP ports connect. UDP is not tested from the Mac.)
- [x] The base domain can serve `/.well-known/matrix/server` (the choice from T0.2). (2026-10-27: live. `ramimaalouf.com` answers 301 to `www`, which serves `server` and `client` as JSON with CORS, equal to the server's own files. The website's `main` is at `f32aad4`.)

**Verification:**
- [x] On the Mac, `nc -vz matrix.<domain> <port>`. "Connection refused" proves that the packet reached the host (nothing listens yet), so no listener on the server is needed. A timeout means the security list drops it.

**Found on the way:**
- The host firewall blocks nothing, so the server needs no change (details: `server/README.md`, Network). `/etc/iptables/rules.v4` is not loaded: `iptables-persistent` was removed on 2025-08-11.
- The website could not deploy at all: Vercel no longer builds Node 20 (`engines` in `package.json`), and the site's `@astrojs/vercel` 7 (the last for Astro 4) writes the runtime `nodejs18.x`, which Vercel refuses, for any other Node. Fixed on the website (`c35cb89`, `f32aad4`): Node 24, and `scripts/fix-vercel-runtime.mjs` sets the function's runtime after `astro build`. A preview deploy was checked first (same status codes and pages as live). The proper fix later: Astro 5 or newer with a newer adapter. The first push (`80e243a`) bypassed the repo's rule "Missing successful active Preview deployment".

**Dependencies:** T0.1, T0.2
**Files:** `server/README.md` (record the Oracle security list rules)
**Scope:** S

### T0.5 Install Synapse only

**Description:** The first playbook run, with no bridges. Prove that Synapse runs
on aarch64 and that Element X can use it.

**Acceptance criteria:**
- [x] `--tags=self-check` is all green. (2026-10-27: `ok=36 failed=0`: the client API, the federation API on 8448, and the well-known files on both names. matrix.org's federation tester: `FederationOK: True`, found through the website's 301.)
- [x] User `rami` exists (`--tags=register-user`). Element X on my iPhone signs in and sends a message to a test room. (2026-10-27: `@rami:ramimaalouf.com` exists, admin. Also `@test1` and `@test2` for the app. Rami signed in with Element Web and exchanged encrypted messages with `@rami-m:matrix.org` in a new room, both ways, over federation (the server's database shows both `m.room.encrypted` events, 22:17 UTC). Element X on the iPhone signed in, was verified, and sent an encrypted message at 22:31:54 UTC from its session `URUJZPGGRL` (in the server's database).)
- [x] We note which images were pulled for arm64 and which were built on the server. (All 7 pulled for arm64, none built: `server/notes/install.md`.)

**Verification:**
- [x] The self-check output and an Element X screenshot. (The self-check output is above. No screenshot: the server's database shows the Element X session's message instead.)
- [x] `free -h` and `sudo docker stats --no-stream` after one hour, saved in `server/notes/`. (2026-10-27: 1.8 GiB used, Synapse 126 MiB, Postgres 218 MiB, load 0.08: `server/notes/install.md`.)

**Found on the way:**
- 2026-10-27: Rami signed in with Element Web (app.element.io, Firefox) by entering `www.ramimaalouf.com`. With `ramimaalouf.com` it said "Homeserver URL does not appear to be a valid Matrix homeserver": the 301 to `www` has no CORS header (checked with curl). Element X and our app are not affected.
- Registration leaves one unused session per user (`@rami` `LCCCMXGHUT`, `@test1` `GSZAMCIGYJ`, `@test2` `LZOEOUBRAB`), each with a live token that nobody holds. With Rami's yes, `server/remove-unused-sessions.py` signed out the two test ones; `register-user.sh` now runs it after each registration. Rami signs out his own in Element Web.

**First run:** 2026-10-27, `ok=195 changed=58 failed=0`. Synapse answers at `https://matrix.ramimaalouf.com` with a Let's Encrypt certificate, and password sign-in works.

**Before the first run:** Rami's explicit yes to the domain (the server name can never change).
The install also replaces `/etc/apt/sources.list.d/docker.list` with an equal `docker.sources`
(the playbook's Docker role), and turns Docker on at boot. (2026-10-27: Rami said yes to both.)

**Dependencies:** T0.3, T0.4
**Files:** `server/inventory/host_vars/.../config.yml`, `server/register-user.sh`, `server/notes/install.md`
**Scope:** S

### T0.6 Add the WhatsApp bridge

**Description:** Turn on mautrix-whatsapp with double puppeting. Link my
WhatsApp account. Messages must flow in both directions.

**Acceptance criteria:**
- [x] `matrix_bridge_mautrix_whatsapp_enabled: true` and Appservice Double Puppet are on. Self-check is green. (2026-10-27: install `ok=218 changed=15 failed=0`; mautrix-whatsapp `v0.2610.0`, arm64 image pulled, nothing built; Synapse loads both registrations; `@whatsappbot:ramimaalouf.com` exists; self-check `ok=36 failed=0`. Bridged rooms are not end-to-end encrypted: the playbook's default.)
- [x] `login qr` to `@whatsappbot:<base domain>` links my WhatsApp. (2026-10-27: linked; the bridge holds 1 login and made rooms for Rami's chats, with history. Details: `server/notes/install.md`.)
- [x] A WhatsApp message sent to me shows in Element X. My reply from Element X arrives in WhatsApp. (2026-10-27: Rami confirmed both directions and double puppeting. The server shows 2 messages from `@rami` in bridged rooms in that hour; 265 of 267 chats have rooms; load back to 0.06 after the history sync.)

**Verification:**
- [x] A manual test with a second person or a second phone. Screenshots of both sides. (Rami's own test; no screenshots kept here.)

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
- [x] After T0.6: the same sign-in against our server. (2026-10-27, T2.10.)

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

- [x] I can read my WhatsApp chat in our app on the Simulator. (2026-10-27, T2.10: read only, with Rami's OK.)
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
- [x] A message from another person (`@test2` to `@test1`) shows a count on its room, and the room title is bold. (2026-10-27: a "1" badge, a bold name and an accent-coloured time; the count is the sdk's `numUnreadMessages`.)
- [x] Opening the chat clears the count here, and the read receipt reaches the server (another client of `@test1` shows the room read). (The MatrixCore test signs in a second `@test1` device, which sees 0.)
- [x] Never sent from a test on `@rami`: with double puppeting, a read receipt in a bridged room also marks the chat read in WhatsApp. (In a drive, the module sends receipts only for a user whose id starts with `@test`.)

**Verification:**
- [ ] A MatrixCore test with `@test1` and `@test2` on our server.
- [ ] A drive with a send from another person, before and after opening the chat.

**Dependencies:** T2.2, the test users (done in T0.5)
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
- [x] `bun exact.mjs ios --device --run` installs and opens the app on my iPhone. (2026-10-27: `--device --phone 00008140-0002155C01F3001C`, signed with the team wildcard development profile `3V2UU7RRK9.*`; the first build 1.5 min. It needed the Rust target `aarch64-apple-ios` for toolchain 1.97.0, now installed. One install failed when the Wi-Fi connection to the phone dropped; the next worked.)
- [x] Sign in, relaunch, chats and sending work as on the Simulator. (A drive on the phone as `@test1`: sign-in, the chat list with pictures, a relaunch that opens signed in, a message sent and read back from the server; signed out after.)
- [ ] The offline case from T2.3: airplane mode, "Not Delivered", then Try Again sends it. (Needs Rami's hands.)

**Facts (2026-10-27):** Q4 answered: team `3V2UU7RRK9` ("Rami Maalouf"; the Mac's one
signing certificate, "Apple Development: Rami Maalouf", belongs to it). The phone: "Rami
Maalouf's iPhone", iPhone 16 Pro, UDID `00008140-0002155C01F3001C`, paired. The App ID
`com.ramimaalouf.multiplexer` may need registering, and the phone needs Developer Mode.

**Dependencies:** Q4 (answered).
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

### T2.9 Pictures in the chat list

**Description:** Added after T2.8: a list of names with no faces is hard to scan, and
bridged chats bring each contact's picture. Each row gets the room's picture, or its
initials.

**Acceptance criteria:**
- [x] A room with a picture shows it, round, at the start of its row. (2026-10-27: the test room's picture, set through the API; Matrix.org's logo.)
- [x] A room without one shows its initials. ("ME" for "Multiplexer encrypted test".)
- [x] `check` is clean in light, dark and at the largest text size. (The picture stays 44 points; the initials scale to a cap: finding 21.)

**Found on the way:**
- A room whose newest event is no message (a new picture) lost its time and sorted low. The list now takes the room list service's order (the server's recency ranking), and a room's time counts any newest event.
- The sdk ranks the encrypted test room, whose newest message this device cannot read, below an older room. That is the sdk's order; unchanged.

**Verification:**
- [x] MatrixCore tests: `testARoomPictureShowsInTheListAndDownloads`; in `testAnOpenChatSeesAMessageFromAnotherDevice`, the room with the newest message comes first.

**Dependencies:** T2.2
**Scope:** S

### T2.10 Your real account, read only

**Description:** From the server conversation's review (2026-10-27): the app was built
against 2 to 5 rooms; Rami's account `@rami:ramimaalouf.com` has 269 (265 WhatsApp chats,
the bridge bot, a "WhatsApp" space, an encrypted DM). Sign in on the Simulator, read only
(Rami's OK, 2026-10-27), and fix what the real size shows. Spaces are not chats: hide them.

**Acceptance criteria:**
- [x] The list is usable (rows with names) within 10 s of signing in; the time is recorded. (2026-10-27: the first answer 0.7 s after sign-in with 93 chats, all 254 within seconds as the sync went on; after a relaunch, 254 chats in 0.24 s.)
- [x] Spaces do not show as chats. (269 joined rooms, 15 of them spaces: 254 chats.)
- [x] One WhatsApp chat opens and shows its last messages with senders, text and photos. (A group chat. Senders first showed as raw ids; now the chat loads its members on open, and the names come in.)
- [x] Nothing is sent, reacted to, deleted or marked as read; the drive signs out at the end. (The app sends no read receipts yet.)
- [x] Memory and the picture downloads at first load are measured and recorded. (Footprint 59 MB with 254 chats and their pictures; the 410 to 490 MB resident size on the Simulator counts shared and reclaimable pages.)

**Found on the way:**
- Every WhatsApp contact's name ends in " (WA)", in the list and above messages: the bridge's name template on the server. A decision for Rami.
- Links in messages are plain text, not tappable (T2.11).

**Dependencies:** T0.6 (done)
**Scope:** S (more if the size shows problems)

### T2.11 WhatsApp message kinds

**Description:** Today a chat shows text, photos and "Waiting for this message". Voice
notes, videos and files show only their body text; stickers, polls and deleted messages
are hidden. Reactions, reply quotes and "Edited" are done in T2.13. Look at what the bridge
sends (read only, on `@rami`), then build them in this order: voice notes (play), replies
(the quote above the bubble), reactions (under the bubble), videos (a poster, then play),
files (name and size, open), stickers (as a picture), "Edited" and "Message deleted".

**Acceptance criteria:**
- [ ] Each kind shows as Messages or WhatsApp shows it, in light, dark and the largest text size.
- [ ] A voice note plays and shows its length; a video plays.
- [ ] Every kind is tested with `@test1` and `@test2` (a MatrixCore test that sends it through the API).

**Dependencies:** T2.10 (to see real examples)
**Scope:** L (one commit per kind)

### T2.12 Send photos

**Description:** Pick a photo (the system's picker) and send it, with an optional caption.
It shows at once, dimmed while it uploads.

**Acceptance criteria:**
- [ ] A photo sent from the app reaches another client at its size, with its caption.
- [ ] A failed upload shows "Not Delivered", with Try Again and Delete.

**Dependencies:** T2.3, T2.5
**Scope:** M

### T2.13 The chat like Messages: bubbles, replies, reactions

**Description:** Added 2026-10-31 (Rami: pull the latest Exact and bring its sample chat
apps' parts into our chat). Exact moved to `1bc4c36cb7`. From `apps/messages` (the bubble,
runs, the long-press overlay) and `apps/excord` (reaction pills), in system colours, plus
Beeper's wants from `research/beeper-walkthrough/report/index.html` ("The chat screen and
swipe to reply", "Hold a message").

**Acceptance criteria:**
- [x] Bubbles with iOS tails on the last bubble of a sender's run; 1-point gaps in a run, 8 between runs; others' bubbles in an opaque grey token (`app.tamber`), yours in the accent. (2026-10-31: light, dark and the largest text size; `check` clean.)
- [x] In a group chat, the sender's name above a run and their picture (or initials) beside its last bubble. (Pictures come from MatrixCore's `senderPicture`; the test users have none, so only initials were seen.)
- [x] Send clears the composer at once and scrolls to the end (the recipe's change at `8de5b7c264`).
- [x] Swipe right on a bubble to reply: a bar above the composer ("Replying to …", Cancel); the sent reply shows its quote above it, on every device. (Driven with a real touch, `--touch platform`.)
- [x] Long press: the chat blurs, the bubble lifts in place, Beeper's six quick reactions above it, Reply and Copy under it.
- [x] Reactions as pills under the bubble, with a count; yours outlined in the accent; a tap adds or takes back yours.
- [x] "Edited" under an edited message. (Not seen: no edited message in the test rooms.)
- [ ] The rest of Beeper's long-press menu: Forward, Share, Mark as Unread, Bookmark, Edit and Delete on your own, and the + for all emojis.
- [ ] Long press on a photo (only text bubbles have it now).

**Verification:**
- [x] MatrixCore test `testAReplyQuotesItsMessageAndReactionsCount` (`@test1` and `@test2`): both see the quote; a reaction counts and is marked as yours; a second tap takes it back. The whole suite passes (12, 1 skipped).
- [x] `verify ios` clean; drives with `check both` clean on the chat and the open menu.

**Found on the way:**
- A reply read back from the store can keep its quote "pending" with nothing loading it; MatrixCore now asks for the details of any quote that is not ready, once per opened chat.
- While the menu is open, UIKit's navigation bar stays sharp above the blur; in light mode its title turns white over the pale blur. Not fixable from the app (Exact finding 27).

**Fixes, 2026-11-02:** a read-only review compared the chat with Exact's sample chat apps.
Each bug was first reproduced in a drive as `@test1` (two test chats), then fixed and driven again.
- [x] Each chat keeps its own draft and its own reply. Before: a reply started in chat A showed its bar and draft in chat B, and Send there sent a reply that quoted a photo of chat B. A message's id is its timeline's own count ("9"), so it names another message in another chat. (Drive: a reply and a draft in A, another draft in B; each comes back in its chat; the reply sent in A quotes the chosen message.)
- [x] Leaving a chat closes its long-press menu. Before: the bar's Back stays live above the menu (finding 27), and the chat opened again with the menu up. (Drive: a real tap on Back with the menu open; the platform's Back.)
- [x] A chat is marked read only when its newest message has been in view for one second (Excord's rule), or when the reader leaves the chat or the end from there. A load no longer marks read: not older pages, not a new message while scrolled up, not behind the photo viewer, not while the app is hidden. `markRead` is its own request; `sendsReadReceipts` is unchanged. (Drives: scrolled up, a message from `@test2` stays unread after Back; at the end, an unread chat reads after 1 s, not at 0.5 s; hidden, a new message stays unread and reads when the app shows again.)
- [x] Swipe to reply: the bubble already followed the finger (the earlier note that it cannot was wrong); it now springs back over about 250 ms after the lift instead of snapping (the sample's `transition`), and one haptic (Exact's, at the threshold) instead of two (finding 28).
- [x] Gate: `test ios` 3 passed on exact2 `1bc4c36cb7`; after the update to `ed43ad09a0`, `test ios` 3 passed, `verify ios` clean, and drives with `check both` clean on the chat, the long-press menu, a reaction, the reply bar after a real swipe, and the photo viewer. A drive ends a navigation's zoom at once, so the zoom's motion itself was not seen.

**Found on the way (2026-11-02):**
- A reply's quote can stay empty (a thin grey mark above the bubble): the quoted message's details never load. Seen after a relaunch that keeps the store (a reply in "Multiplexer two-person test", still empty after 4 s; after a fresh sign-in it showed its quote), and after a fresh sign-in on a reply that quotes a photo ("Multiplexer test"). MatrixCore asks for them once per opened chat; they do not arrive. Not fixed here. A likely cause, not checked: `missingQuotes()` passes the quoted message's event id to `fetchDetailsForEvent`, and matrix-rust-sdk describes that call (from memory; the Swift bindings have no doc) as taking the id of the reply itself.
- Drafts last until the app quits. A saved reply would need the message's event id, not its timeline id. The SDK can store a draft per room (`saveComposerDraft`, `loadComposerDraft`): a later task (B5's Drafts filter needs it).
- With a real touch, an edge swipe while the menu is open lands on the menu's Close layer: it closes the menu, and the chat stays.
- While the keyboard rises after a reply starts, one frame draws the reply bar over the bubbles; from 50 ms on the layout is right. A reply started on a bubble low in a chat scrolled up leaves that bubble half hidden at the list's bottom edge once the keyboard is up.
- The reply arrow: `swipeIndicator` works (an experiment: an arrow child that fades in and grows as the swipe reaches the threshold). Not kept, because it changes the look: a decision for Rami.

**Dependencies:** T2.2, T2.3
**Scope:** M

### Checkpoint M2: daily reading and sending

- [ ] On my iPhone, against our server: live updates, sending, unread counts.
- [ ] I use it for one week. Then list what is missing, and write Phase 3 in detail.
- [ ] Rami reviews.

## Beeper parity

Written 2026-11-02 from Rami's Beeper walkthrough (`research/beeper-walkthrough/report/index.html`,
local only) and his answers to all its questions (`plan.md`, decision log, 2026-11-02). "Topic N"
points to the report.

**Order (Rami, 2026-11-02):**
1. B1, the network of each chat.
2. Photos and files from the library: B10 (the "+" button), then B11 with T2.12.
3. The rest of the inbox: B3 to B8 (B2 when Rami OKs the server change).
4. Push notifications (Phase 3): after the inbox, before the chat details.
5. B9, then B12 to B21 in their order.
6. Later (wanted, not now): see "Later" at the end of this section.

Rules for every task here:
- **Beeper's features, Messages' feel (D9).** Take every feature from Beeper. Keep what Messages
  already gives through the recipe (T2.13): bubble tails, sender runs, the long-press overlay,
  the "Replying to" bar, reaction pills.
- **Dark first.** The app follows the iPhone's light or dark setting. Design and check dark mode
  first, then light mode, then the largest text size.
- Every question of the report is answered. **Ask Rami** marks a choice that only shows when the
  task starts (for example a server change); do not guess.
- Drives send, react and mark read only as `@test1` or `@test2`. A bridged chat exists only on
  `@rami`: there, drives are read only and need Rami's OK.
- Push notifications (Phase 3) come after the inbox tasks (Rami, `push-order`).

### B1 Each chat's network, and its logo on the picture

**Description:** Topic 05, and the base of the whole inbox. MatrixCore tells which network a chat
comes from (WhatsApp, Instagram, ..., or Matrix). The chat list draws that network's logo on the
bottom right corner of the chat's picture, as Beeper does. The biggest unknown of this list: the
SDK may return nothing for the bridge's `m.bridge` state (its sync does not ask for custom state
types), so prove that first.

**Acceptance criteria:**
- [x] A spike answers how to read a chat's network. (2026-11-02, `matrix-core/NOTES.md`, "A chat's
  network": the SDK returns no `m.bridge` state, even though the server has it. mautrix bridges
  also set `io.element.functional_members`, which the SDK syncs: `RoomInfo.serviceMembers` names
  the bridge bot, and `<word>bot` gives the network. Fallback: a ghost or bot among the room's
  heroes. Limit: a bridge not on bridgev2 (mautrix-discord) sets neither, so its groups show no logo.)
- [x] `RoomSummary` has a `network` (plain string). A room with no bridge is `matrix`.
- [x] Each row shows the network's logo (15 pt in a 1.5 pt ring of the background colour) on the
  picture's corner, outside the picture's clipped box. No logo for plain Matrix chats.
  (`network.contract`, `NetworkBadge`.)
- [x] Logos for WhatsApp, Instagram, Messenger, Telegram, Signal, Discord and LinkedIn are in the
  app (`assets/networks/`, sources and licences in `SOURCES.md`).
- [ ] VoiceOver: the row's spoken label leaves the network out (Exact finding 32). A hand-written
  `aria-label` on the row would fix it.

**Verification:**
- [x] MatrixCore test `testABridgedRoomShowsItsNetworkOnANewDevice`: `@test1` sets the state a
  mautrix bridge sets in "Multiplexer network test"; a new device reads `whatsapp`, the plain test
  rooms read `matrix`, and a change to `telegram` and back shows live. The whole suite passes
  (16, 1 skipped); `verify ios` clean.
- [x] A read-only drive on `@rami` (Rami's OK, 2026-11-02): 292 chats: 259 WhatsApp, 30 Instagram,
  3 Matrix, each with the right logo; `check` clean in dark, light and the largest text size; no
  chat opened; signed out at the end.

**Dependencies:** none. **Scope:** M

### B2 Remove "(WA)" from names (server)

**Description:** Topic 05, question `wa-suffix`. Rami: remove it and show the logo instead (B1).
"(WA)" shows in the list, above sender runs, in quotes and in the "Replying to" bar. It comes
from the bridge's display name template on the server.

**Acceptance criteria:**
- [ ] **Rami's OK at that time** before any server change (the plan's rule 7).
- [ ] The template changes through the playbook (invariant 6), and names update in the app.

**Dependencies:** B1 (so each chat still shows its network). **Scope:** S (server conversation)

### B3 The bottom bar

**Description:** Topic 03. A floating glass bar over the chat list, as in Beeper: a round
filter button on the left, a capsule in the middle, a round search button on the right. Exact
has no native bottom toolbar, so the app draws it (`backgroundMaterial="glass"`,
`buttonStyle="glass"`, `glassGroup`). No dashed chat-plus slot (Rami: not needed). Each button
appears when its feature exists: the capsule's Archive with B8, search with B18.

**Acceptance criteria:**
- [ ] The bar floats over the list; the list scrolls under it with the iOS edge effect, and its
  last row can scroll above the bar.
- [ ] The capsule holds Inbox (selected) and the up-down button for the filter sheet (B4); the
  left button opens the filter menu (B5).
- [ ] Dark, light and the largest text size look right (`check` clean); VoiceOver names each button.

**Dependencies:** none. **Scope:** M

### B4 The filter sheet: filter by network

**Description:** Topics 03 and 07: "what I care about the most". The up-down button opens a
sheet from the bottom (Rami: a sheet, as in Beeper), with Beeper's list (Rami: exactly Beeper's
list). This task builds Inbox and one row per connected network, each with its unread count.
The other rows come with their tasks: Archive and Low Priority (B8), Send Later (B13),
Bookmarks (B14), labels and Create Label, Reminders, Requests, New Space and communities (all
"Later"), the gear and Edit.

**Acceptance criteria:**
- [ ] The sheet opens at half height and pulls up to full (`navigationDetent="medium large"`).
- [ ] Choosing WhatsApp shows only WhatsApp chats; Inbox shows all. The capsule shows the choice.
- [ ] The choice is kept across launches (`persist`).
- [ ] MatrixCore filters the list itself: today `rooms()` returns every chat and takes only its
  order from the room list service. The filter uses `.identifiers([...])` for a network.

**Dependencies:** B1, B3. **Scope:** M

### B5 The filter menu: unread, DMs, groups

**Description:** Topic 09: "really useful for me because I have lots of unread messages". The
left button opens a menu with a check on the active choice: All, Unread, Drafts, Unanswered,
DMs, Groups. It works together with the network filter (B4).

**Acceptance criteria:**
- [ ] All, Unread, DMs and Groups work (SDK filters `.readReceipts(expect: .messages)`,
  `.category(.people)`, `.category(.group)`).
- [ ] Unread also shows a chat marked unread by hand (B7). Check whether the SDK's filter counts
  that flag; if not, add those chats.
- [ ] Unanswered: chats whose newest message is not yours. Drafts: waits until the app keeps
  unsent drafts (not built yet).
- [ ] With a filter on, the button fills with the accent colour and the pinned grid (B6) hides.

**Dependencies:** B3. **Scope:** S

### B6 Pinned people

**Description:** Topic 01: "most important people". Pinned chats show as large round pictures
above the list (3 per row, a short name under each), and leave the list. A chat with unread
messages shows a dot on its picture (Rami: a dot, as in Messages).

**Acceptance criteria:**
- [ ] Pin and Unpin from a row's long-press menu (the first item of B7's menu; this task adds it).
- [ ] The pin is stored on the server (`Room.setIsFavourite`), so other devices agree; the
  pinned order is kept (`tagOrder`).
- [ ] The grid scrolls away with the list (the list's first section).
- [ ] An unread pinned chat shows a dot.

**Dependencies:** none (B7 adds the rest of the menu). **Scope:** M

### B7 Hold a chat: the preview and its actions

**Description:** Topic 04: "All these are features that I'd love to have as well." A long press
on a row opens the native iOS context menu with a preview of the chat's last messages, and
Beeper's actions: Select chat, Archive, Move to Low Priority, Pin, Remind Me, Mark as Unread,
Mute, Label, Delete (red).

**Acceptance criteria:**
- [ ] The preview shows the chat's last messages, and does not mark the chat read (Rami: only
  opening the chat marks it read). Since 2026-11-02 a message load marks nothing; only the chat
  screen's `markRead` request does (T2.13, "Fixes"), so a preview that never sends it reads nothing.
- [ ] Mark as Unread (`setUnreadFlag`); opening the chat clears that flag (the SDK's
  `markAsRead` does not).
- [ ] Mute and Unmute (`setRoomNotificationMode(.mute)`): a crossed bell after the name, a grey
  count; an "@" in the count when you are mentioned.
- [ ] Move to Low Priority and Archive: with B8. Label, Remind Me and Select chat (several chats
  at once): "Later".
- [ ] Delete asks first, then removes the chat from our app only (Rami): WhatsApp keeps it. Check
  first what the bridge does when we leave the room and the chat gets a new message; if leaving
  is not safe, hide the chat with a mark instead.

**Dependencies:** B6 (the menu exists). **Scope:** M

### B8 Archive and Low Priority

**Description:** Topics 03 and 04. Archive and Low Priority are separate lists, reached from
the bottom bar and the filter sheet. The SDK can set Low Priority but cannot write custom tags,
so Archive needs another way (MatrixCore calls the Matrix tags API itself, or another mark).
Prove that way first. Labels use the same way later.

**Acceptance criteria:**
- [ ] Move to Low Priority and back (`setIsLowPriority`); a Low Priority row in the filter sheet.
- [ ] Archive and Unarchive; the Archive button in the bottom bar's capsule.
- [ ] A new message brings an archived chat back to the inbox, unless the chat is muted (Rami).

**Dependencies:** B4, B7. **Scope:** M

### B9 Beeper's chat top bar

**Description:** From Rami's split (D9): the chat's top bar as in Beeper. Back with the total
unread count, the chat's picture and name in a glass capsule in the middle (a tap opens the
chat info page, B20), and "..." on the right.

**Acceptance criteria:**
- [ ] Back shows the unread count of all other chats, and updates live.
- [ ] Picture and name in the middle; "..." opens a menu (its items come with B20).
- [ ] While the long-press overlay is open, the bar does not stay sharp above the blur (today it
  does: Exact finding 27). Check whether the app's own bar fixes it.

**Dependencies:** none. B20 uses it. **Scope:** M

### B10 The composer like Beeper

**Description:** From D9: "+" on the left, the field with the network's logo and "Reply on
WhatsApp" (the chat's network), and the voice button on the right while the field is empty
(Send when there is text).

**Acceptance criteria:**
- [ ] The placeholder names the chat's network ("Reply on WhatsApp"); a plain Matrix chat says
  "Message".
- [ ] "+" opens the panel (B11); the voice button starts recording (B17). Until those exist, the
  buttons are not shown.

**Dependencies:** B1. **Scope:** S

### B11 The + panel: photos and files

**Description:** Topic 14: "the two most important [things are] photos and GIFs". Rami: photos
from the library and files are the top priority of the panel. "+" turns into an X, and a panel
takes the keyboard's place. This task builds the panel with Photos and Send file (T2.12 is the
photo sending part); GIFs (B12) and Send later (B13) join it. Camera comes later (a built-in
camera); no Poll for now.

**Acceptance criteria:**
- [ ] The panel replaces the keyboard (Exact cannot put a view in the keyboard; hide the keyboard
  and show the panel in its place); X brings the keyboard back.
- [ ] Photos: the system picker, several photos, a caption, upload progress, then T2.12's checks.
- [ ] Send file: the Files picker; the file shows with its name and size, and opens on another
  client (`AttachmentKind.file`).

**Dependencies:** T2.12, B10. **Scope:** M

### B12 GIFs (KLIPY)

**Description:** Topic 14. Search KLIPY (Rami's choice, D10), show a grid of animated GIFs, send
one. KLIPY is what Beeper uses. The phone calls KLIPY directly: KLIPY requires it, and D10 makes
it the one exception to invariant 1.

**Acceptance criteria:**
- [ ] Rami makes the KLIPY account (partner panel); the key stays out of git (Keychain, like the
  other secrets). The test key allows 100 calls an hour; then ask for a production key (KLIPY's
  form; it publishes no price: no cost without Rami's yes). Ads off.
- [ ] KLIPY's required branding shows in the GIF panel.
- [ ] Search waits for a pause in typing, so one search is one call.
- [ ] A GIF sent from the app plays in WhatsApp (check how the bridge sends it: GIF or video).

**Dependencies:** B11. **Scope:** M

### B13 Send Later

**Description:** Topic 14: "the third one". Rami: hold the Send button, as in Slack, then pick a
time. The message waits on our server (Rami, D11), so it goes even when the phone is off.
Synapse's delayed events (MSC4140) can hold it; the SDK's bindings cannot send one, so
MatrixCore calls the Matrix API itself (to check).

**Acceptance criteria:**
- [ ] Holding Send opens the choices: a few set times (for example tomorrow at 9:00) and a
  custom date and time (the native picker). A tap on Send still sends at once.
- [ ] **Ask Rami** before turning on delayed events on Synapse (a server setting, through the
  playbook), with a maximum delay he chooses.
- [ ] A list of scheduled messages, as a row in the filter sheet: send now, change the time, or
  cancel one.
- [ ] A scheduled message reaches WhatsApp at its time with the phone off (checked with the test
  users, then on `@rami` with his OK).

**Dependencies:** B11. **Scope:** L

### B14 The full message menu, and all emojis

**Description:** Topics 17 and 18, and T2.13's open items. Our long-press overlay (built in
T2.13, drawn by the app because Exact's native menu has no reactions row) gets Beeper's full
menu: Reply, Copy, Share, Forward, Mark as Unread, Bookmark, Edit and Delete on your own
messages. The reaction bar keeps Beeper's six fixed emojis; its "+" opens a sheet with every
emoji, a search and "Frequently used".

**Acceptance criteria:**
- [ ] Share (`share(...)`), Forward (copy the content and send it to the chosen chat: the SDK has
  no forward), Mark as Unread (the chat, from this message), Edit and Delete on your own.
- [ ] The "+" sheet: half height, pulls up to full, search, "Frequently used" (the SDK's recent
  emojis), all emojis by category. Exact has no emoji grid: the app draws one, or uses the iOS
  emoji keyboard.
- [ ] Long press on a photo too (T2.13: only text bubbles have it).
- [ ] Bookmark: saved in the account's own data; shown in each chat's info page (B20) and in one
  list of all bookmarks (a row in the filter sheet).
- [ ] Sending an edit, deleting a sent message and recent emojis are proven in a MatrixCore test.

**Dependencies:** T2.13. **Scope:** M

### B15 The chat's details as in Beeper

**Description:** From D9: what Beeper shows inside a chat and ours does not yet.

**Acceptance criteria:**
- [ ] A "New" line above the first unread message.
- [ ] A jump-to-latest button with the number of unread messages below.
- [ ] "Seen by A, B" under the newest message in a group, "Seen" in a DM (proven in a MatrixCore test).
- [ ] Day labels between days.
- [ ] Emoji-only messages large, with no bubble; stickers as pictures (T2.11).
- [ ] Links you can tap (T2.11).

**Dependencies:** T2.13. **Scope:** M

### B16 Play voice notes, one speed everywhere

**Description:** Topic 16 (and the voice part of T2.11). A voice note shows play, a waveform,
the length and a speed chip (1x, 1.5x, 2x). Rami: "it should be consistent everywhere ... a
user setting". Beeper keeps the speed per note; ours keeps one speed for the whole app.

**Acceptance criteria:**
- [ ] A voice note plays; the waveform shows progress (the app draws the bars: Exact has no view
  for a received waveform).
- [ ] Changing the speed on any note changes it on every note, and the app remembers it. Videos
  keep their own normal speed (Rami).
- [ ] Transcribe: "Later".

**Dependencies:** T2.13. **Scope:** M

### B17 Record a voice note

**Description:** Topic 15. Rami (2026-11-02): "do the same as most chat apps": tap to start, tap
to finish, then listen to it and send it. No pause. It goes out as a voice message, so WhatsApp
shows a voice note.

**Acceptance criteria:**
- [ ] Tap the voice button to start, tap to finish (`@exact/recording`; the microphone permission).
- [ ] Before sending: play the draft, then send it or delete it.
- [ ] A voice note sent from the app plays as a voice note in WhatsApp.

**Dependencies:** B10, B16. **Scope:** M

### B18 Search all chats

**Description:** Topic 08: "also very powerful". The bottom bar's search button turns into a
search field at the bottom, with the keyboard up. Before typing: recent chats and recent
searches. Above: Images, Videos, Links, Files, Drafts.

**Acceptance criteria:**
- [ ] Results in this order (Rami): chats by name (`.fuzzyMatchRoomName`), then messages (the
  SDK's local search index), then links.
- [ ] Check where iOS 26 puts Exact's search field. If not at the bottom, draw our own.

**Dependencies:** B3. **Scope:** L

### B19 Search in one chat

**Description:** Topic 12. From the chat info page: a search for this chat only, with Images,
Videos, Links, Files, Audio and Bookmarks.

**Acceptance criteria:**
- [ ] Text search in one chat (the SDK has none per chat: filter B18's results by chat).
- [ ] Pages per kind (a timeline filtered by message type; links found in the text).

**Dependencies:** B18, B20. **Scope:** M

### B20 The chat info page

**Description:** Topic 11: "I love the animation of it opening and I love all the things that
you can see in here". Opened from the top bar's picture and name (B9) with the zoom transition
(`navigationSource`).

**Acceptance criteria:**
- [ ] It zooms out of the top bar's capsule and shrinks back on close.
- [ ] Picture, name, "WhatsApp Group - 7 members" (or the network for a DM); Search, Archive,
  Low Priority (or Unpin) and More; Media; Members with Add member.
- [ ] Edit: Edit Group Info; Customize for Me (a name only you see).
- [ ] More: Pin, Mark as Read, Mute, Delete. Jump to Date: the SDK has none (jump to a message
  works). Remind Me: "Later".
- [ ] Bookmarks: this chat's saved messages (B14).
- [ ] Message expiry: last of all (Rami: keep it, "not urgent"); see "Later".

**Dependencies:** B9. **Scope:** L

### B21 The "Inbox" title menu, and Settings

**Description:** Topic 02. The title "Inbox" opens a menu: Select Chats, Merge Chats, Settings.
Settings holds Sign Out (it leaves the chat list's top bar) and the voice note speed.

**Acceptance criteria:**
- [ ] The menu and a Settings screen with Sign Out and the voice note speed.
- [ ] Merge Chats and Select Chats: "Later".

**Dependencies:** none. **Scope:** S

### Later

Rami wants these, after the tasks above (2026-11-02):
- Labels: a named group of chats, shown as a filter in the sheet, with Create Label (the same
  tag way as Archive, B8). "Not a requirement."
- Camera in the + panel: a built-in camera.
- Remind Me: a reminder to answer a chat later (B7, B20; a Reminders row in the sheet).
- Merge Chats: one person on two networks as one chat (B21).
- Select chat: act on several chats at once (B7, B21).
- Transcribe voice notes (B16): check whether the iPhone can do it on the phone, at no cost.
- Communities as filters ("whatever is easiest"): after B4.
- Requests and New Space in the filter sheet: look at what Beeper does first.
- Message expiry (B20): the very last.

Not wanted for now: Poll.

## Phase 3: push notifications (M3), rough

The biggest gap for daily use (the server conversation's review, 2026-10-27): without
push, Rami does not know a message came unless the app is open. Order (Rami, 2026-11-02):
after the Beeper inbox tasks (B1 to B8), before the chat details. Detail it before it
starts; the parts:

- The app (this side): the APNs device token. Exact has `subscribePush()` designed but not
  built (LLP 1133.004 §9): a native module, or a change to Exact.
- The app: a pusher on the homeserver (`set_pusher`) that points at Sygnal.
- The app: a notification service extension that uses MatrixCore's notification client to
  fetch the event and show the sender and the text. Exact has no extension target; the
  WidgetKit `.appex` build is a pattern.
- The server (the server conversation): Sygnal with the APNs key from team `3V2UU7RRK9`.
  Tell it when the app side and the key are ready.
- Test memory and the 30-second limit on the real iPhone. Muted WhatsApp chats: the
  bridge sets push rules for them.

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
