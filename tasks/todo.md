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

Run it after 48 hours of use. (2026-10-28, Rami: closed early, without the 48-hour wait. He uses WhatsApp through the server daily, so he sees a disconnect himself; the bridge also warns in its bot chat after 12 days without the phone.)

- [x] Messages flow in both directions. No bridge disconnects in 48 hours. (Both directions and double puppeting work, T0.6. No 48-hour watch, see above.)
- [x] Memory and CPU use noted. Compare them with Oracle's 20% reclaim rule. (Idle: 1.8 GiB of 23 GiB, load 0.06. History sync: 2.4 GiB, load 2.35. Below 20%, but the account is Pay As You Go, so idle reclaim should not apply. Open: the cost of 4 OCPUs and 24 GB, Q5; 2 OCPUs and 12 GB would be enough.)
- [x] PostgreSQL backup method chosen. (The playbook's `postgres-backup`: a daily dump of each database on the server, 7 daily and 2 weekly kept, no monthly; first dump 42 MB, checked intact. An off-server copy is a later step, for Rami's yes. `server/README.md`, Backups.)
- [x] Rami reviews. Decision: continue to Phase 1, or change the server plan. (Rami: check M0 off. The server plan stays.)
- [x] Update **Status** and the **Decision log** in `plan.md`.

**Recheck, 2026-11-03** (read only; the window is 2026-10-27 23:00 to 2026-11-03 19:50 UTC, 7 days;
branch `server/m0-checkpoint`). Rami's decision of 2026-10-28 stands; nothing below changes it.
- **Both directions.** WhatsApp to Matrix: 1,900 messages from WhatsApp contacts from 2026-10-28
  on; 99.6% arrived within 10 s of their WhatsApp time (median 0.7 to 0.9 s each day; Synapse's
  `received_ts` minus `origin_server_ts`). 7 arrived more than 5 minutes late, each one alone, not
  in a batch as after a reconnect; their cause is not known. Matrix to WhatsApp: 6 messages sent
  from a Matrix client in WhatsApp rooms (4 on 10-28 with a photo; on 11-03 the app's GIF at
  18:13 UTC and its Send Later message at 18:14 UTC). Each has a WhatsApp message id in the
  bridge's database within 2 s.
- **Disconnects.** No logout: the bridge's WhatsApp login dates from 2026-10-27 22:42 UTC, and the
  bot sent no message or notice in the window (only room setup events). The bridge's warn-level
  log is in journald (`sudo journalctl -u matrix-mautrix-whatsapp`; `docker logs` has nothing):
  24 websocket drops ("failed to read frame header: EOF", once "connection reset by peer"); 10 of
  them came with a "503 stream error" from WhatsApp's server in the same minute ("assuming
  automatic reconnect will handle it").
  The reconnect logs at info, so it is not in the log, but no drop shows as a gap: the 8 longest
  pauses between incoming messages (2.2 to 3.4 h) are in the night, Eastern time, except one
  (11-02, 07:30 to 09:50). The bridge restarted 5 times, each in a playbook run (10-28 backup,
  10-31 twice for Instagram, 11-02 LinkedIn, 11-03 delayed events), 5 to 15 s each; systemd
  counts no crash (`NRestarts=0`).
- **Memory and CPU** (sysstat, 977 ten-minute samples, 10-28 to 11-03): CPU p95 4.0%, median
  0.9%; memory used p95 14%, max 23%; network p95 40 kB/s (max 12 MB/s). Now: the Matrix
  containers use about 1.6 GiB (PostgreSQL 933 MiB, Synapse 360 MiB, WhatsApp bridge 96 MiB),
  load 0.2. The only peaks (94 to 99% CPU, 11-02 20:20 to 20:50 and 22:40 to 22:50 UTC) were all
  "nice" time; the Matrix containers run at nice 0, while two other services on this machine run
  niced: `flowback-engine` (nice 10, 1.6 GB) and Syncthing (nice 11). Disk: 62 of 96 GB (Docker
  22 GB, media 1.6 GB, PostgreSQL 1.1 GB, backups 379 MB).
- **Oracle's rule** (its page, read 2026-11-03): an *Always Free* instance is idle when, over 7
  days, CPU p95, network and memory (A1 shapes) are all below 20%. Ours meets all three. The page
  does not say whether the rule applies to a Pay As You Go account; the plan's reading (it does
  not) is still not confirmed (Q5).
- **Backup** (chosen 2026-10-28, local, no cost): the playbook's `postgres-backup` runs: 7 daily
  and 2 weekly dumps of the 4 databases (Synapse 50 MB gzip on 11-03). The 11-03 dumps pass
  `gzip -t` and end with "dump complete"; the Synapse dump has 174 tables. Limits: the dumps are
  on the server's only disk, and they hold no media. If Oracle reclaims the instance, they go
  with it.
- **For Rami (questions, nothing applied):** (1) an off-server copy, at no cost: a daily pull of
  the newest dumps (about 55 MB) to the Mac over `ssh oracle`, with or without the media (1.6
  GB). The dumps hold the WhatsApp, Instagram and LinkedIn sessions, so the copy stays out of git
  and synced folders. (2) The Instagram bridge still logs at debug (274 debug lines in the last
  hour, with chat data); `config.yml` says to delete that line after the login. Deleting it
  restarts the bridges for about 10 s. (3) The two unused Instagram images and Docker's build
  cache (a deletion: `server/notes/install.md`, 2026-10-31).
- **Rami's answers (2026-11-03): "do whatever you think is best".** Applied the same day
  (`server/notes/install.md`, 2026-11-03): (1) a daily pull to the Mac with the media and
  Synapse's signing key (`server/pull-backup.sh`, launchd at 21:30, `~/Backups/multiplexer-server`;
  first pull 1.9 GB, file counts equal to the server's); (2) the Instagram debug line deleted
  through the playbook (0 debug lines after); (3) the two images and our build's cache deleted
  by hand (1.17 GB), because the playbook's prune tools would also delete other projects'
  stopped containers; the other project's Caddy cache stays.

## Phase 1: first own screen (M1)

### T1.1 Create the Exact app

**Description:** Make the app with its final name and bundle id. Read
`exact2/docs/start-here.md` first.

**Acceptance criteria:**
- [x] `bun <exact2>/scripts/exact.mjs new apps/multiplexer --name Multiplexer --bundle-id com.ramimaalouf.multiplexer` is done.
- [x] `bun exact.mjs ios --prebuild` finishes. The empty app opens in the iOS Simulator. (2026-10-27: built and installed on the iPhone 17 Pro Simulator in about 2 minutes.)
- [x] `bun exact.mjs feedback status` has run, and the diary follows its answer. (Answer: `ask`. The diary is in `apps/multiplexer/.exact/diary/`. Nothing is sent without Rami's yes.)

**Verification:**
- [x] `bun exact.mjs agent ios "screenshot .exact/first.png"` shows the app. (2026-11-03: the sign-in screen, 402×874.)

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
- [x] After T0.6: the same test against our server lists the WhatsApp chat. (2026-11-03: `scripts/test-matrix-core.sh` runs
  against our server as `@test1`/`@test2` by default; a read-only drive as `@rami` listed his 185 rooms, WhatsApp ones
  with the network `whatsapp`, and a GIF reached WhatsApp through the bridge.)
- [x] It returns the last 20 messages of a room, in order, with sender, text and time. (The test checks the newest message and that it is our own.)
- [x] No matrix-rust-sdk type is in MatrixCore's public API. (Public types: `MatrixAccount`, `SavedSession`, `RoomSummary`, `Message`, `MatrixCoreError`. The same files compile in the Exact app.)

**Verification:**
- [x] `xcodebuild test` on an iOS Simulator destination passes. (2026-11-03: the whole suite, 52 tests, 1 skipped.)

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
- [x] A MatrixCore test with `@test1` and `@test2` on our server. (`testUnreadMessagesCountUntilRead`,
  `testMarkedUnreadClearsOnReadAndAMutedChatStillCountsMentions`, `testANewLineFurtherBackThanTheChatLoads`.)
- [x] A drive with a send from another person, before and after opening the chat. (2026-11-03, B15: 30 messages
  from `@test2`; the count at open, while scrolling, and 0 once the newest message is in view.)

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
  Proposed 2026-11-03 (Rami decides): keep it **off**, as it is now (`matrix_bridges_encryption_enabled: false`).
  Why: the bridge runs on the same server and must read every message to pass it to WhatsApp, so its keys sit
  on the same disk as the database: a breach of the server reads the chats either way. On, it would cost: Send
  Later refuses encrypted chats (delayed events wait on the server unencrypted; `testAnEncryptedChatHasNoSendLater`),
  the push extension would have to decrypt each message within its memory limit, and a new device would show
  older bridged messages as "Waiting for this message" until it has the recovery key. Chats with other Matrix
  people stay end-to-end encrypted, and the recovery key (below) now opens their older messages.
- [x] In an encrypted room, messages sent after this device signed in show as text. (2026-10-27: the room "Multiplexer encrypted test", made by MatrixCore; another device's message shows as text at once; a message sent from the app is encrypted and shows as text.)
- [x] Added: a message this device has no key for shows as "Waiting for this message", not nothing. Before, MatrixCore dropped it from the chat.
- [x] Older messages show after I enter the recovery key (key backup). (2026-11-03: Settings, Encryption: Off, On, or
  Needs Your Key with a field and Unlock Older Messages; a wrong key is named. MatrixCore `recover`, and the SDK now
  fetches a missing key from the backup (`afterDecryptionFailure`). Test `testAnOlderEncryptedMessageShowsAfterTheRecoveryKey`
  as `@test1`, which resets recovery through the server's API; drives in light and dark: `apps/multiplexer/.exact/recovery/`.) (Waits for T0.5: the practice account has no recovery, and turning it on would add an encryption identity to an account Rami also uses in Element. Test it with a test user on our own server.)

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
- [x] A sign that older messages are loading, and that the chat has reached its start. (2026-11-03: a row above the oldest
  loaded message, `OlderLine`: a small spinner while older ones load, then "Start of the chat" in the footnote's grey. It is
  one more row of the transcript's list, `[Message(f, id="~older")].concat(thread.messages)`, so `reachstart` still sees the
  top; Exact finding 20, PR #1411. As `@test1` in "Multiplexer search test history": 20 messages to 50, then "Start of the
  chat" above "History 1"; `check` clean in light, dark and the largest text size.)
- [x] A chat that opens at its "New" line loads older messages too. (2026-11-03: `reachstart` fired once while the chat moved
  to the line, `loadOlder` held it back, and the list never asked again: the chat stayed at its last 20 messages (seen
  before this change). Now the held load is made when the line is placed (`olderWanted`, `donePlacing`), and the line stays
  in view.)

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
- [x] Each kind shows as Messages or WhatsApp shows it, in light, dark and the largest text size. (2026-11-03: two
  test chats holding text, links, a reply, reactions, photos, an animated GIF, a video, a sticker, a large emoji, a
  file and a voice message, in light, dark and the largest size; `check` finds only text scrolled under the glass
  bar. Fixed on the way: at the largest size a file's long name ran past the screen; it wraps now.)
- [x] A voice note plays and shows its length (B16).
- [x] A video shows its poster at its ratio with a play mark and its length, and plays full screen
  in the system player (2026-11-03, B15; `testAVideoReachesTheOtherWithItsSizeLengthAndPoster`).
  Sound with the ring switch on silent (`audio_session: "playback"`) waits for a check on the iPhone.
- [x] Every kind is tested with `@test1` and `@test2` (a MatrixCore test that sends it through the API). (Text,
  photo and file, video, sticker, voice note and audio file, reply and reactions, edit and delete, forward: see
  `MatrixCoreTests`, `ChatDetailsTests`, `VoiceTests`, `MessageActionsTests`.)

**Dependencies:** T2.10 (to see real examples)
**Scope:** L (one commit per kind)

### T2.12 Send photos

**Description:** Pick a photo (the system's picker) and send it, with an optional caption.
It shows at once, dimmed while it uploads.

**Acceptance criteria:**
- [x] A photo sent from the app reaches another client at its size, with its caption.
  (2026-11-02, `testAPhotoAndAFileReachTheOtherPersonAndARefusedUploadFails`: a second session
  reads 600x900 and the caption, and downloads the photo and its thumbnail. Not checked in Element.)
- [x] A failed upload shows "Not Delivered", with Try Again and Delete (a file 1 byte over the
  server's limit; a too-large file is refused before it is sent).

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
- [x] The rest of Beeper's long-press menu: Forward, Share, Mark as Unread, Bookmark, Edit and Delete on your own, and the + for all emojis. (B14; Bookmark is built in the Bookmarks thread.)
- [x] Long press on a photo (only text bubbles have it now). (B11 and B14: photos, videos, stickers, files and voice messages.)

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
- [x] Gate: `test ios` 3 passed on exact2 `1bc4c36cb7`; after the update to `ed43ad09a0`, `test ios` 3 passed, `verify ios` clean, and drives with `check both` clean on the chat, the long-press menu, a reaction, the reply bar after a real swipe, and the photo viewer. The zoom's motion: with `--timing platform` and a Simulator recording, the photo grows from its box to full width over about 30 frames, and shrinks back on close (2026-11-02).

**Found on the way (2026-11-02):**
- [x] Fixed 2026-11-02: a reply's quote could stay empty. MatrixCore asked the sdk for it with the quoted message's id; the sdk takes the reply's own id (its source says so). A quote still loading, or one that cannot load, now shows nothing instead of an empty bar. (MatrixCore test `testAReplyToAnOldMessageShowsItsQuote`, red before; a drive: a reply to the room's first message shows its quote.)
- [x] Fixed 2026-11-02: drafts were lost when the app quit. Each chat's text and the message it answers are now kept in the account's store (the sdk's composer draft, per room): 0.6 s after typing stops, when the chat is left, and when the app goes to the background. A sent message removes it; Sign Out removes the store with them. A reply to a message the chat has not loaded is kept by its event id. Photos and files picked are not kept. (MatrixCore test `testADraftKeepsItsTextAndReplyUntilSent`; drives across relaunches: kept, restored with its reply bar, sent with the right quote, then gone; kept when the chat is left at once and when the app is hidden.)
- With a real touch, an edge swipe while the menu is open lands on the menu's Close layer: it closes the menu, and the chat stays.
- [x] Fixed 2026-11-02: a reply started on a message low on the screen, in a chat scrolled up, left that message under the keyboard; now it scrolls just into view above the reply bar (a timer that waits for the layout, as Exact has no keyboard fact: finding 45). Also: scrolled messages showed through the reply bar and the composer (a virtualized list draws past its frame: finding 44); the two now share one bar in the page's colour, so the look at rest is the same and `check` is clean. With that bar, the one frame that drew the reply bar over the bubbles while the keyboard rises is gone (frames every 25 ms).
- [x] The reply arrow (Rami's yes, 2026-11-02): a swiped bubble shows SF Symbols' `arrowshape.turn.up.left` to its left, faint at 40 points of drag and full at 64; it fades out faster than the bubble springs back. An icon token (`icon.arrowshape-turn-up-left`) gives hosts without SF Symbols a drawing. (`check both` clean after a swipe, also at the largest text size; `verify ios` clean.)

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
- [x] VoiceOver: the row's spoken label has the network (2026-11-04). On main the chat row (`RoomFace` in a `link`)
  is already read with it, so no hand-written label was needed there: `tree --ax` reads `link "Multiplexer network
  test, WhatsApp, You: A chat from whatsapp, Monday"`. Select Chats' row was not: its `aria-label` was the name alone,
  and at the accessibility sizes it draws no picture, so no logo; it now says the networks (`chooseLabel`):
  `checkbox "Multiplexer network test, WhatsApp"` in light, dark and the largest text size. Left as it is: a pinned
  picture is read by its name alone ("Bar Test Person"). Exact PR #1407 (open) is the Exact side of finding 32.

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
- [x] **Rami's OK at that time** before any server change (the plan's rule 7). (2026-11-03:
  "do whatever you think is best"; all three suffixes, so no network repeats its logo.)
- [x] The template changes through the playbook (invariant 6), and names update in the app.
  (2026-11-03: applied through the playbook, all three; `!wa sync contacts` sent. Read-only
  drive on `@rami`, new device, signed out after: of 189 chats loaded, 0 names show " (WA)";
  2 direct chats and 1 group show their names in the bar without a suffix. Instagram senders
  still show " (IG)" (7 in previews; 705 of 708 Instagram ghosts on the server) until each
  contact's next update.)

**Found in that drive (app, not B2's server change; for the app lane):**
- **A group opens empty.** A WhatsApp group with messages (its inbox row shows the last one)
  opened as "No Messages Yet", still after 20 s, on a new device. On the server, 182 of the
  room's newest 200 events are member events (167 from the rename at 22:50 UTC: each name
  change is one). So the first page holds only hidden events, and the chat does not page back
  to a message. 54 of 279 WhatsApp rooms have no message in their newest 20 events (43 none in
  50). Fix in the app: page back until a shown message or the room's start.
  Fixed 2026-11-03: a chat pages back 50 events a page, up to 1,000, until it has its messages
  (`testAChatUnderManyHiddenEventsOpensWithItsMessages`: 120 hidden events above the message).
- **A raw ID as sender.** 4 inbox previews show the sender as `@whatsapp_lid-…:ramimaalouf.com`
  on a new device, while the server has that person's name (profile and member event). The
  preview falls back to the user ID when the sender's member event is not loaded.
  Taken by the later lane (task 4), 2026-11-03.

**Prepared (2026-11-03, branch `server/b2-names`, not merged, not applied).** `config.yml` adds
three lines, the playbook's defaults at the pinned commit without the suffix:

```yaml
matrix_bridge_mautrix_whatsapp_network_displayname_template: '{% raw %}{{or .BusinessName .PushName .Phone}}{% endraw %}'
matrix_bridge_mautrix_meta_instagram_bridge_displayname_suffix: ''
matrix_bridge_mautrix_linkedin_network_displayname_template: "{% raw %}{{ with .Organization }}{{ . }}{{ else }}{{ .FirstName }} {{ .LastName }}{{ end }}{% endraw %}"
```

Today the names end in " (WA)", " (IG)" and " (LinkedIn)" (the server's bridge configs).
Rendered with Ansible on the Mac, each template comes out without its suffix.

**How names update** (from the bridges' code at the server's versions; not tested yet): a new
template changes no name at once. A contact's Matrix name changes when the bridge next updates
that contact, and each DM room's name follows (`private_chat_portal_meta: true`). Group names
have no suffix.
- WhatsApp: `!wa sync contacts` in the WhatsApp bot chat renames every contact the bridge has
  stored, at once (a message from `@rami` to the bot only; it reaches no contact). Others change
  when they change their WhatsApp name, or when they send a message and their info is more than
  7 days old (the bridge's queue runs every 4 hours).
- Instagram (mautrix-meta `4a7ebd9`): when Meta's sync sends that contact's info again.
- LinkedIn (`6cc6a89`): when that person's info comes with a message.
- The app: names come from the server through the SDK; no app change. The search index stores no
  names.

**To apply, after Rami's OK:** merge `server/b2-names` into `main`;
`./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start` (the three bridges
restart, about 10 s); `!wa sync contacts` in the WhatsApp bot chat; a read-only drive on `@rami`.

**Applied 2026-11-03** (`server/notes/install.md`). The bot does not answer `!wa sync contacts`,
but it renamed in the background (about 900 a minute): 14,529 names with " (WA)" became 2,250 by
23:03 UTC. The rest are people with no contact info (26 DM rooms of 279 keep " (WA)" for now);
each changes on that person's next update.

**Dependencies:** B1 (so each chat still shows its network). **Scope:** S (server conversation)

### B3 The bottom bar

**Description:** Topic 03. A floating glass bar over the chat list, as in Beeper: a round
filter button on the left, a capsule in the middle, a round search button on the right. Exact
has no native bottom toolbar, so the app draws it (`backgroundMaterial="glass"`,
`buttonStyle="glass"`, `glassGroup`). No dashed chat-plus slot (Rami: not needed). Each button
appears when its feature exists: the capsule's Archive with B8, search with B18.

**Acceptance criteria:**
- [x] The bar floats over the list, the list scrolls under it, and its last row can scroll above
  the bar. (2026-11-02, `inbox.contract`, `BottomBar`.)
- [x] The iOS edge effect under the bar (2026-11-04): Exact gives a floating bar none (finding 35), so the app draws
  one: behind the bottom bar (and Select Chats' bar) a solid backdrop down past the home indicator and a 32-point fade
  above it, outside the bar's glass group so its glass stays its own. Before, rows ran sharp under the bar; after,
  they fade out above it and are hidden behind it, in light, dark and the largest text size
  (`apps/multiplexer/.exact/ui/before/4-bottom-*.png`, `after/4-bottom-*.png`, gitignored). It is the app's fade,
  not UIKit's blur. `check` still flags the inbox's title row over the rows (UIKit's own soft edge at the top).
- [x] The capsule holds Inbox (selected; a tap scrolls to the top); the left button opens the
  filter menu (B5). The up-down button comes with B4.
- [x] `check both` clean in dark, light and the largest text size; VoiceOver reads "Filter" (or
  "Filter, Unread") and "Inbox, selected". On Rami's real account (292 chats, read only) `check`
  flags the bar over the rows as an overlap: that is the floating bar by design.

**Dependencies:** none. **Scope:** M

### B4 The filter sheet: filter by network

**Description:** Topics 03 and 07: "what I care about the most". The up-down button opens a
sheet from the bottom (Rami: a sheet, as in Beeper), with Beeper's list (Rami: exactly Beeper's
list). This task builds Inbox and one row per connected network, each with its unread count.
The other rows come with their tasks: Archive and Low Priority (B8), Send Later (B13),
Bookmarks (B14), labels and Create Label, Reminders, Requests, New Space and communities (all
"Later"), the gear and Edit.

**Acceptance criteria:**
- [x] The sheet opens at half height and pulls up to full (`navigationDetent="medium large"`).
  (2026-11-02, `sheet.contract`.) Rows: Inbox, then Matrix (chats no bridge serves, like Beeper's
  own row) and one row per network, each with its unread chats' count.
- [x] Choosing WhatsApp shows only WhatsApp chats; Inbox shows all. The title becomes the network's
  name and the capsule shows its logo. It combines with the filter menu, and the pinned grid shows
  only that network's pins.
- [x] The choice is kept across launches; a new sign-in starts at Inbox.
- [x] MatrixCore filters the list itself (`NetworkFilter.swift`, `NetworkFilterTests`).
- [x] After a network change in a list scrolled down, the large title stays collapsed: no longer seen (2026-11-04).
  The inbox draws its own title row (no system bar since B21's title menu), which never collapses. Driven: scrolled
  down 600 points, then WhatsApp in the filter sheet: "WhatsApp" large, the list at its top, in light, dark and the
  largest text size (`.exact/ui/before/3-network-*.png`).
- [ ] A short line shows above the pinned grid (finding 49). Seen on 2026-11-04 in light, dark and the largest text
  size, above the pinned grid in the inbox and in Select Chats (`apps/multiplexer/.exact/ui2/before/49-top-*.png`).
  Only Exact can hide it: it is UIKit's top separator above a plain list's first row, and the host hides a row's top
  line only when the row before it wrote its edge, which the first row has none of. A local exact2 change
  (`exact2-gaps`, branch `local/check-hidden-by`, not pushed: no top line above a plain list's first row) was not sufficient on resume: the largest-text screenshot still shows the line
  (`.exact/ui2/after/49-top-largest.png`). Keep this open; the local experiment is not a shipped fix.
- [x] Rami (2026-11-03): keep the Matrix row first; count unread chats; the title shows the network's name.

**Dependencies:** B1, B3. **Scope:** M

### B5 The filter menu: unread, DMs, groups

**Description:** Topic 09: "really useful for me because I have lots of unread messages". The
left button opens a menu with a check on the active choice: All, Unread, Drafts, Unanswered,
DMs, Groups. It works together with the network filter (B4).

**Acceptance criteria:**
- [x] All, Unread, DMs and Groups work. MatrixCore computes each filter itself (`RoomFilters.swift`):
  the SDK's dynamic filter is one shared filter that applies late and has no Unanswered. DMs: marked
  direct, or a bridged chat with at most 2 people besides the bridge's bot. (2026-11-02,
  `InboxTests`.) On Rami's real account, bridge bot chats show under DMs.
- [x] Unread also shows a chat marked unread by hand (`m.marked_unread`): the SDK's filter reads
  only the count, so MatrixCore adds them.
- [x] Unanswered: chats whose newest message is not yours. Drafts: drafts outlive the app since
  2026-11-02 (T2.13), in the sdk's per-room store; the room list does not report them yet, so the
  Drafts filter still needs MatrixCore to read them for the list.
- [x] With a filter on, the button fills with the accent colour and the pinned grid hides; a
  filter with no chats offers "Show All Chats". The choice persists across launches.

**Dependencies:** B3. **Scope:** S

### B6 Pinned people

**Description:** Topic 01: "most important people". Pinned chats show as large round pictures
above the list (3 per row, a short name under each), and leave the list. A chat with unread
messages shows a dot on its picture (Rami: a dot, as in Messages).

**Acceptance criteria:**
- [x] Pin and Unpin from a row's native long-press menu, with a preview of the last messages; a
  tap on the preview opens the chat. The preview does not mark read (held 5.5 s, still unread).
- [x] The pin is stored on the server with its order; a second device sees the pins in order
  (`testAPinShowsOnAnotherDeviceInItsOrder`). The SDK hides a tag's order, so MatrixCore reads it
  from the server once per pinned chat.
- [x] The grid is the list's first row and scrolls away with it.
- [x] An unread pinned chat shows a dot, which clears when the chat is read.
- [x] Rami (2026-11-03): a pin stays in our app, never in WhatsApp. Check the bridge does not pass it before any pin on `@rami`: the bridge may pass a pin to WhatsApp (which allows
  3). His real account has no pinned chats today. (2026-11-03, read only, at the server's
  versions: **a pin in our app cannot reach WhatsApp.** The app pins with the room tag
  `m.favourite` (`Pinned.swift`, `setIsFavourite`), which is room account data. mautrix-whatsapp
  v0.2610.0 does have code that pins in WhatsApp when it sees that tag (`HandleRoomTag` in
  `pkg/connector/handlematrix.go`; mautrix-go v0.32.0 calls it for `m.tag`), but a bridge sees
  account data only if the homeserver puts it in an appservice transaction. Synapse v1.164.0
  sends appservices only typing, receipts, presence, to-device and device-list events
  (`synapse/handlers/appservice.py`, `notify_interested_services_ephemeral`), never account data.
  The same holds for any other room account data the app writes, such as `m.marked_unread`. The
  other direction is off too: the bridge's `pinned_tag` and `archive_tag` are not set, so a
  WhatsApp pin does not tag the Matrix room. `@rami` has no room tags today. Recheck after a
  Synapse update: this depends on what Synapse sends to appservices, not on our app.)

**Dependencies:** none (B7 adds the rest of the menu). **Scope:** M

### B7 Hold a chat: the preview and its actions

**Description:** Topic 04: "All these are features that I'd love to have as well." A long press
on a row opens the native iOS context menu with a preview of the chat's last messages, and
Beeper's actions: Select chat, Archive, Move to Low Priority, Pin, Remind Me, Mark as Unread,
Mute, Label, Delete (red).

**Acceptance criteria:**
- [x] The preview shows the chat's last messages and marks nothing read (held with an unread
  "@ 2": the count stayed). (2026-11-03.)
- [x] The menu, UIKit's own, in Beeper's order: Archive, Move to Low Priority, Pin, Mark as Unread,
  Mute, then a red Delete; each row turns into its opposite when it applies.
- [x] Mark as Unread (`setUnreadFlag`); opening the chat clears it (`markRead` now also clears the
  flag).
- [x] Mute and Unmute: a crossed bell after the name's last word, a grey count, an accent "@ N"
  for a mention. Mute is read from the push rules (the SDK's cached mode is lost at relaunch). A
  mute adds a rule that highlights a mention without a push.
- [x] Delete asks first, then hides the chat on every device of the account until a newer
  message. It never leaves the room: mautrix drops our leave while `bridge_matrix_leave` is off
  (the playbook's setting), and with it on, mautrix-whatsapp leaves the WhatsApp group.
- [x] Nothing of this reaches WhatsApp: Synapse sends a bridge no account data. Only Mark as Read
  (a read receipt) does.
- [ ] Label: "Later". Select Chat is done (B22).
- [x] Remind Me (2026-11-03, with B20's): "Remind Me…" after Pin (an alarm clock), or "Clear Reminder" when the chat has
  one. It opens Send Later's time sheet (`LaterSheet`) with Send Later's set times as rows: Tomorrow, 9:00 AM; Monday,
  9:00 AM (not on a Sunday); or a picked time, then Set. See "Remind Me" below for where it is kept.
- [x] Rami (2026-11-03), all as suggested (check what is built): a deleted chat that comes back shows only new messages (not its whole history);
  was: a deleted chat that comes back shows its whole history (or only new messages);
  your own message brings an archived chat back; a mention in a muted chat gives "@" but no push
  (WhatsApp pushes it; P3.6); WhatsApp mutes show the bell (the bridge copies them as
  mentions-only).
  Done 2026-11-03 (branch `work/choices-followup`): it showed the whole history; now Delete also
  keeps the delete's time (`cleared` in the same account data event), the chat shows only later
  messages, on every device, and older ones do not load (`testADeletedChatComesBackWithOnlyItsNewMessages`,
  drive `.exact/choices/delete-back.png`). Our own message already brought an unmuted chat back,
  from the app and from another device; now it brings a muted one back too, and the answer does
  not archive it again (`testYourOwnMessageBringsAnArchivedChatBack`, `.exact/choices/archive-back.png`).
  The "@" with no push and the bell for WhatsApp mutes were built with B7.
- [x] Another device's archive or delete shows only at the next list change. (2026-11-03, branch
  `work/list-freshness`: reproduced in the app first, an unarchive from another device not shown
  45 s later. The SDK observes only its own account data types, so MatrixCore reads the chats'
  marks and own names from its store every 2 s while it syncs (no request) and tells the list when
  one changed (`AccountDataWatch`, `testAnotherDevicesArchiveTellsTheList`). The same drive with
  the fix shows the chat back at the next read. `scripts/mark-chat-as-test-user.sh` archives or
  unarchives as a test user from a short-lived device; `send-test-message.sh --delete-last` deletes
  a test user's newest message.)
- [x] Fixed on the way (2026-11-03): `testRecentMediaIsTheNewestPhotosAndVideos` failed 1 run in 3 with
  only the newest video. A sync with a gap resets the media timeline to its newest events, and the
  "reached the start" flag from an earlier page back stopped any new one; the flag now holds only
  until the next reset (`MediaTimeline`, 5 runs of 5 pass). The chat's own timeline (`LiveTimeline`)
  had the same flag, so a reset chat could stop loading older messages; it gets the same rule.
- [x] Seen 2026-11-03 under load from parallel threads: a new device's first sync of `@test1` took
  near the 30 s limit, so `testANameOnlyYouSeeShowsOnYourOtherDeviceNotTheOthers` timed out twice
  ("the first sync") and passed alone (53 s). A failed run leaves its own name on the info test
  room, which then fails `testInfoNamesItsMembersAndWhatYouMayChange`. Fixed 2026-11-03 (branch `work/test-stability`):
  measured with prints in `startSync`, a new `@test1` device took 12.5 s to "running" and a new `@test2`
  device more than 30 s, while the server answered the same first sliding sync by curl in 0.2 s and was
  idle; the Mac had a load average of 25 on 18 cores (8 Simulators, builds of other conversations). Not
  the recovery tests' cross-signing (`@test2` never had it) nor concurrent starts (one start each). Every
  test file now signs in through `TestDevices.swift`: the sync is warmed with a 120 s limit, and the
  teardown signs the device out, through its saved session when its own client cannot (failed runs had
  left 15 devices on `@test1`). The app keeps its 30 s. Full suite: 65 passed, 2 skipped, and one wait of
  15 s raised to 30 s (`testSeenByAfterTheOtherReadsAndTheFirstUnreadMessage`, then passed alone).

**Dependencies:** B6 (the menu exists). **Scope:** M

### B8 Archive and Low Priority

**Description:** Topics 03 and 04. Archive and Low Priority are separate lists, reached from
the bottom bar and the filter sheet. The SDK can set Low Priority but cannot write custom tags,
so Archive needs another way (MatrixCore calls the Matrix tags API itself, or another mark).
Prove that way first. Labels use the same way later.

**Acceptance criteria:**
- [x] Move to Low Priority and back (`setIsLowPriority`); a Low Priority row in the filter sheet.
  (2026-11-03.)
- [x] Archive and Unarchive; the Archive button in the bottom bar's capsule, and an Archive row in
  the sheet. Stored in one account data event (`com.ramimaalouf.multiplexer.chats`), not in tags:
  the SDK cannot read a custom tag's current value.
- [x] A new message brings an archived chat back to the inbox, unless the chat is muted.
- [x] Three separate choices, each kept across launches: the filter menu, the network, and the
  list (Inbox, Archive, Low Priority); they combine ("WhatsApp Archive"). Counts leave out muted
  chats without a mention.

**Dependencies:** B4, B7. **Scope:** M

### B9 Beeper's chat top bar

**Description:** From Rami's split (D9): the chat's top bar as in Beeper. Back with the total
unread count, the chat's picture and name in a glass capsule in the middle (a tap opens the
chat info page, B20), and "..." on the right.

**Acceptance criteria:**
- [x] Back shows the inbox's other unread chats (as the sheet's Inbox row counts them), live; a
  plain glass circle at 0. (2026-11-03, `chat.contract`.)
- [x] Picture (with its network logo) and name in a glass capsule; not pressable until B20.
  "..." offers Pin, Mark as Unread (it goes back to the list) and Mute.
- [x] The app's own bar fixes T2.13's sharp bar: the long-press blur now covers it, in dark and light.
- [x] A real edge swipe back over the messages (2026-11-03, `--touch platform --timing platform`, as `@test1`):
  `tap root drag 320 0 from 2 276 over 400`, at the height of a bubble that a swipe right answers, went back to the inbox
  ("willShow 0, by the edge swipe", then the drawn Back pressed), and no reply started (`composers` empty). Four runs; in the
  first, the log also showed the chat pushed again and popped a moment later, not seen in the other three.
- [x] Messages no longer show behind the bar's name (2026-11-04; Exact finding 55); `check` is clean on it only with a local Exact change.
  Cause: the bar's fade had a fixed height, shorter than the bar with a two-line name, the merged chat's tabs or the
  largest text, so a bubble showed behind the name's glass (and in dark, that glass read under 4.5:1). Fix in the app:
  the backdrop is sized by the bar itself, solid behind it and fading 32 points below it. Before and after in light,
  dark and the largest size: `apps/multiplexer/.exact/ui/before/1-chat-*.png`, `after/1-chat-*.png` (gitignored).
  `check` still reports the messages under the bar as overlaps with the app's Exact (it cannot tell an opaque view
  covers them); a local exact2 branch (`local/check-hidden-by` in `exact2-gaps`, not pushed) makes the iOS host
  report the opaque views drawn over an item, and with it `check` read "no findings" on this chat in light, dark and
  the largest text size.
- [x] Rami (2026-11-03): Mark as Unread inside a chat goes back to the list; Back leaves out muted,
  archived and Low Priority chats.

**Dependencies:** none. B20 uses it. **Scope:** M

### B10 The composer like Beeper

**Description:** From D9: "+" on the left, the field with the network's logo and "Reply on
WhatsApp" (the chat's network), and the voice button on the right while the field is empty
(Send when there is text).

**Acceptance criteria:**
- [x] The placeholder names the chat's network ("Reply on WhatsApp"), with the network's logo at
  the field's start; a plain Matrix chat says "Message"; with photos picked, "Add a caption".
  (2026-11-03.) At the accessibility text sizes it says "Message" with no logo, so it is not cut.
- [x] "+" opens the panel (B11). (2026-11-02.) The voice button comes with B17.

**Dependencies:** B1. **Scope:** S

### B11 The + panel: photos and files

**Description:** Topic 14: "the two most important [things are] photos and GIFs". Rami: photos
from the library and files are the top priority of the panel. "+" turns into an X, and a panel
takes the keyboard's place. This task builds the panel with Photos and Send file (T2.12 is the
photo sending part); GIFs (B12) and Send later (B13) join it. Camera comes later (a built-in
camera); no Poll for now.

**Acceptance criteria:**
- [x] The panel replaces the keyboard; X brings the keyboard back. (2026-11-02, `attach.contract`.)
- [x] Photos: the system picker, several photos, a caption, upload rings, then T2.12's checks.
  The picker leaves HEIC out, so iPhone photos come as JPEG (a picked HEIC over 256 KB shows
  empty: Exact finding 38).
- [x] Send file: the Files picker; a file bubble with name, kind and size; a received file opens
  through the share sheet; the other person gets the same bytes, name and type.

**Dependencies:** T2.12, B10. **Scope:** M

### B12 GIFs (KLIPY)

**Description:** Topic 14. Search KLIPY (Rami's choice, D10), show a grid of animated GIFs, send
one. KLIPY is what Beeper uses. The phone calls KLIPY directly: KLIPY requires it, and D10 makes
it the one exception to invariant 1.

**Acceptance criteria:**
- [x] Rami makes the KLIPY account (partner panel); the key stays out of git (Keychain, like the
  other secrets). (2026-11-03: Keychain service `multiplexer-klipy`, account `test`;
  `scripts/setup-klipy-key.sh` writes it into the gitignored `apps/multiplexer/.env.local`, which the
  build reads through `app.json`'s `env`. It ships in the app, as KLIPY's app keys do.) The test key allows 100 calls an hour; then ask for a production key (KLIPY's
  form; it publishes no price: no cost without Rami's yes). Ads off.
- [x] KLIPY's required branding shows in the GIF panel: the field says "Search KLIPY" (required),
  and "Powered by KLIPY" sits under the grid (optional). Results keep KLIPY's order (2026-11-03).
- [x] Search waits for a pause in typing, so one search is one call (400 ms; trending before any word).
  A tap sends KLIPY's largest GIF under 4 MB as an animated image (`m.image`, `image/gif`,
  `is_animated`), downloaded straight to a file; animated GIFs now play in the chat (the whole file,
  not the server's still thumbnail). `gif.contract`, `gif-members.contract`, `app.ts` (2026-11-03).
- [x] A GIF sent from the app plays in WhatsApp (check how the bridge sends it: GIF or video).
  2026-11-03: sent from `@rami` (Rami's OK: his chat with himself, Mama, Dana, Osama and Ali G
  are test chats) to his WhatsApp chat with himself: "Sent", and no failure notice from the bridge
  after several minutes (the bridge logs warnings only). Rami saw it arrive in WhatsApp on his phone.

**Dependencies:** B11. **Scope:** M

### B13 Send Later

**Description:** Topic 14: "the third one". Rami: hold the Send button, as in Slack, then pick a
time. The message waits on our server (Rami, D11), so it goes even when the phone is off.
Synapse's delayed events (MSC4140) can hold it; the SDK's bindings cannot send one, so
MatrixCore calls the Matrix API itself (to check).

**Acceptance criteria:**
- [x] Holding Send opens the choices: a few set times (for example tomorrow at 9:00) and a
  custom date and time (the native picker). A tap on Send still sends at once. (2026-11-03: a
  long press on Send offers "Tomorrow, 9:00 AM", "Monday, 9:00 AM" (not on a Sunday) and "Custom
  Time…", a sheet with the system's date and time picker. The module reads a choice in the
  iPhone's calendar and zone, daylight saving included. Only in a chat that is not end-to-end
  encrypted: a message that waits on the server cannot be encrypted, and the SDK cannot send a
  delayed event, so MatrixCore calls the API itself (`ScheduledMessages.swift`). Bridged chats
  are not encrypted. The message is plain text (no Markdown) and keeps its reply. The chat shows
  "1 message scheduled · Sends …" over the composer while one waits.)
- [x] **Ask Rami** before turning on delayed events on Synapse (a server setting, through the
  playbook), with a maximum delay he chooses. (Rami, 2026-11-03: yes, 1 year. On the server
  through the playbook: `matrix_synapse_delayed_events_enabled: true`,
  `matrix_synapse_max_event_delay_duration: 365d`, commit on branch `server/phase-0`. Synapse
  keeps one timer for the next message due, so the length adds no load; at most 100 waiting
  messages a user, Synapse's default.)
- [x] A list of scheduled messages, as a row in the filter sheet: send now, change the time, or
  cancel one. (2026-11-03: the sheet's "Send Later" row, with the count; the list opens in the
  sheet, and a tap on a message offers Send Now, Change Time and Cancel Message. Change Time
  makes a new waiting message and cancels the old one, as the server cannot move one; if the
  old one already went, the new one is cancelled and the list says so. The list reads again
  each minute.)
- [x] A scheduled message reaches WhatsApp at its time with the phone off (checked with the test
  users, then on `@rami` with his OK). Test users (2026-11-03): a message scheduled for 3 minutes
  later arrived at exactly that minute while the app was not running; MatrixCore's
  `ScheduledMessagesTests`. WhatsApp (Rami's OK, 2026-11-03, to his contact "Osama"): scheduled
  in the app for 13:14, then the app signed out at 13:11:42; the message went at 13:14:00 and the
  bridge sent it to WhatsApp (its database maps the event to a WhatsApp message id at 18:14:00
  UTC). Signing a device out does not cancel its waiting messages; only deactivating the account
  does (Synapse's `cancel_all_for_user`).

**Dependencies:** B11. **Scope:** L

### B14 The full message menu, and all emojis

**Description:** Topics 17 and 18, and T2.13's open items. Our long-press overlay (built in
T2.13, drawn by the app because Exact's native menu has no reactions row) gets Beeper's full
menu: Reply, Copy, Share, Forward, Mark as Unread, Bookmark, Edit and Delete on your own
messages. The reaction bar keeps Beeper's six fixed emojis; its "+" opens a sheet with every
emoji, a search and "Frequently used".

**Acceptance criteria:**
- [x] The menu in Beeper's order: Reply, Share, Forward, Copy, Mark as Unread, then Edit and a red
  Delete on your own messages. (2026-11-03, `menu.contract`.) Bookmark comes with its list later.
- [x] Bookmark, after Mark as Unread (Beeper's place); "Remove Bookmark" on a saved message.
  (2026-11-03, branch `work/bookmarks`: `menu.contract`, `bookmarks.contract`,
  `bookmarks-members.contract`, MatrixCore `Bookmarks.swift`.) A message on its way has no Bookmark
  until the server has it. The list of all: the filter sheet's "Bookmarks" row (after Send Later,
  no count) closes the sheet and opens a page. Each row: the chat's picture and network, its name,
  the message's time, the sender and the text, or "Photo", "Video", "Voice message", a file's
  name. A tap opens the chat at the message, marked (B18's jump; Back returns to the list). A long
  press offers Copy and Remove Bookmark; a swipe removes it. Kept in the account's global account
  data (`com.ramimaalouf.multiplexer.bookmarks`; plan.md's decision log, 2026-11-03), so every
  device has them and nothing reaches the chat or WhatsApp. MatrixCore `BookmarksTests` (3 passed):
  a bookmark of each user, on the account's second device, opened there at the message; the other
  person has none and no new event; a new device lists the ones saved before at once and keeps them.
  The whole suite (60 tests, 2026-11-03, a busy hour on the Mac after a restart): 6 failed on
  waits for the server ("the first sync", a message within 15 s, reactions on the server); the 6
  run again alone all passed. `test ios` 6 passed (new: `bookmarks.test.contract`), `verify ios`
  clean, `bun test` 7 passed. Drives as `@test1` in dark, light and the largest text size,
  with real touches for the menus and the swipe; `check both` clean
  (`apps/multiplexer/.exact/bookmarks/`, gitignored).
- [ ] Bookmarks' limits: a bookmark keeps the message as it was saved (an edit or a delete later
  does not change it); another device's new bookmark shows within a minute (the sdk tells no
  listener of custom account data; follow-up: add `Bookmarks.type` to `AccountDataWatch`, which
  reads the store every 2 s, and drop the minute's reload); a message further back than 1,000 events opens the chat at its
  newest with B18's note. Each bookmark is about 0.5 KB of one event: fine for hundreds.
- [x] Fixed on the way: a new device's store has no account data in its first seconds, not even
  after the first sync. The list read then was empty (seen in a drive right after sign-in: a saved
  message offered "Bookmark" again), and a change made from it could have replaced every bookmark
  on the server. MatrixCore now reads the event from the server while the store has none, and a
  change throws if that read fails (`testANewDeviceKeepsTheBookmarksSavedBefore`, which failed
  before the fix with "a new device lists the bookmarks saved before: []").
- [x] The same risk, not fixed: Customize for Me's names, Archive and Delete
  (`com.ramimaalouf.multiplexer.chats`) and the frequent emojis read only the store, so a change in a
  new device's first seconds could replace the account's others. The same server read would fix
  them (`accountDataOnServer` in `Bookmarks.swift`). (2026-11-03: every change of the account's own
  data, the reminders and bookmarks too, starts from `accountDataForChange` (`AccountData.swift`):
  the store's event, else the server's, and a failed read throws. `testANewDeviceKeepsTheAccountDataSavedBefore`
  failed before the fix with "the emoji counted before is gone: ["🦉"]" (a new device's count
  before its first sync); names, archive and reminders made right after the first sync kept the
  others even before the fix, as the store had the account's data by then. Another device's
  bookmark now tells the list through the account's data watch, which also watches reminders; the
  minute's reload is gone (`testAnotherDevicesBookmarkShowsWithinSeconds`: 2.0 s; before, never).)
- [x] Share a text, photo, file or video (media downloaded first, under its file name).
- [x] Forward a text, photo, file or video to one or more chats from a sheet with search; media is
  not uploaded again (`testAForwardedTextPhotoAndFileArriveInAnotherChat`).
- [x] Edit your own text ("Editing" bar with Cancel; the other sees "Edited") and Delete for
  everyone ("Message deleted" for both and in the list) (`testAnEditAndADeleteReachTheOtherPerson`).
- [x] The reaction bar's "+" opens a sheet: half height to full, search, "Frequently used" from the
  account (`io.element.recent_emoji`, with Reset), all 1,906 emoji by group with 9 tabs.
- [x] Long press on photos, files, videos, stickers and large emoji too.
- [x] Swipe to reply on photos, files, videos and stickers; Copy for a photo. (2026-11-03: `details.contract`'s
  `SwipeReply` holds the tap, the long press and the swipe on one node, as Exact's iOS host keeps a touch for
  a press inside a swipe; the media components only draw. Copy writes the original photo as a PNG with
  `@exact/clipboard` (Exact's image clipboard, from data code; no native code). Drives with real touches:
  each kind swipes to a reply with its quote, and still opens and holds.)
- [x] The list says "Message deleted" only for a chat opened since launch (the SDK leaves deleted
  messages out of a room's latest event). (2026-11-03, branch `work/list-freshness`: MatrixCore keeps
  the newest message each row showed (`latest-messages.json` in the account's store folder); a
  latest event older than it means it was deleted, so the row says "Message deleted" with its
  sender, the chat never opened, and still after a relaunch (`testTheListSaysMessageDeletedWithTheChatNotOpened`,
  which fails without the fix). The time stays the message before's, as the SDK orders the list by
  it. Not caught: a message that arrived and was deleted while the app never showed it. Drive,
  dark: `.exact/fresh/delete-before-dark.png`, `delete-after-dark.png`.)
- [x] Rami (2026-11-03) ok to all; to build: hide Edit and Delete after the limits. Mark as Unread marks the whole chat; no "Forwarded" label (Matrix has none);
  hide Edit and Delete after WhatsApp's limits (about 15 minutes, about 2 days); skin tones.
  Done 2026-11-03 (branch `work/choices-followup`): in a WhatsApp chat, Edit shows for 15 minutes
  and Delete for 48 hours, from the message's time and the app's clock (`limits.ts`,
  `bun test ./limits.test.ts`; drives at +20 min and +49 h, `.exact/choices/menu-whatsapp-*.png`).
  mautrix-whatsapp v0.2610.0 declares both (`EditMaxAge` 15 min, `DeleteMaxAge` 2 days) and
  bridgev2 refuses an older edit. mautrix-meta (Instagram) declares an edit limit and 5 edits
  at most but no delete limit; other networks keep no limit until checked. No skin tones.

**Dependencies:** T2.13. **Scope:** M

### B15 The chat's details as in Beeper

**Description:** From D9: what Beeper shows inside a chat and ours does not yet.

**Acceptance criteria:**
- [x] A "New" line above the first unread message; a chat with more unread messages than fit
  opens at it, as Beeper does, without marking read. (2026-11-03, `details.contract`.)
- [x] A jump-to-latest button with the unread count ("11 ↓"), the arrow alone at 0.
- [x] "Seen by A, B" under the newest message in a group, "Seen 12:09 AM" in a DM, "Delivered"
  under your own until it is read (`testSeenByAfterTheOtherReadsAndTheFirstUnreadMessage`).
- [x] Day labels: one header per day or gap of an hour, "Today 9:41 AM", the weekday in the last
  week, then the date.
- [x] Emoji-only messages (1 to 3) large, with no bubble; stickers as pictures
  (`testAStickerIsShownNotDropped`).
- [x] Links you can tap, in Safari's in-app view.
- [x] Fixed: a reply's quote showed its sender's raw id (`testAReplysQuoteNamesItsSender`).
- [x] The jump count is the chat's whole unread count, not exactly the messages below the view;
  no "New" line when the first unread message is older than the 20 loaded. (2026-11-03: the count
  is the unread messages below the "New" line not yet in view (each row's `intersect`); it falls
  as you scroll down, reaching the newest message clears it, and new ones that come while you read
  older ones add to it. With more unread messages than the first page, MatrixCore pages back once
  to the read receipt, at most 300 events, and the chat opens at the line with 8 read messages
  above it; older messages do not load until the line is placed. Test
  `testANewLineFurtherBackThanTheChatLoads`.)
- [x] Stickers and large emoji have no swipe to reply or long press (B14's area). (2026-11-03: a sticker
  swipes and holds through `SwipeReply`; a large emoji already did, in the text bubble's box.)
- [x] Rami (2026-11-03): keep the "New" line, in-app Safari, one header per gap, typing later; to build: "Sent" instead of "Delivered". Was: open at the "New" line (built) or at the newest; "Delivered" means our server
  has it, not WhatsApp ("Sent" instead?); links in Safari's in-app view or the Safari app; one
  header per gap; the typing indicator now or later.
  Done 2026-11-03 (branch `work/choices-followup`): "Sent" (`.exact/choices/sent-now.png`).

**Dependencies:** T2.13. **Scope:** M

### B16 Play voice notes, one speed everywhere

**Description:** Topic 16 (and the voice part of T2.11). A voice note shows play, a waveform,
the length and a speed chip (1x, 1.5x, 2x). Rami: "it should be consistent everywhere ... a
user setting". Beeper keeps the speed per note; ours keeps one speed for the whole app.

**Acceptance criteria:**
- [x] A voice note plays; the waveform shows progress (the app draws the bars: Exact has no view
  for a received waveform). (2026-11-03, `voice.contract`.)
- [x] Changing the speed on any note changes it on every note, and the app remembers it. Videos
  keep their own normal speed (Rami). (`state voiceSpeed = 1 persist`.)
- [x] Transcribe (2026-11-03, from "Later"): a held voice message offers Transcribe; Apple's on-device recognizer
  (`@exact/speech-recognition`, `processLocally`, no cost, nothing leaves the iPhone) turns it into text in the
  iPhone's language, shown under it and kept across launches by its sound file's name (`transcribe-members.contract`).
  Under a drive the package hears nothing, so the app was driven to "No speech in this voice message."; on this
  Mac the same engine transcribed a spoken Ogg Opus clip correctly. Left for Rami's iPhone: one real voice note
  (and whether Arabic notes need the language chosen).

**Dependencies:** T2.13. **Scope:** M

### B17 Record a voice note

**Description:** Topic 15. Rami (2026-11-02): "do the same as most chat apps": tap to start, tap
to finish, then listen to it and send it. No pause. It goes out as a voice message, so WhatsApp
shows a voice note.

**Acceptance criteria:**
- [x] Tap the voice button to start, tap to finish (`@exact/recording`; the microphone permission).
  (2026-11-03.)
- [x] Before sending: play the draft, then send it or delete it.
- [x] A voice note sent from the app is an `m.audio` voice event (`audio/ogg` Opus, waveform), so
  WhatsApp's bridge shows a voice note (`testAVoiceNoteSentByOneReachesTheOther`).

**Dependencies:** B10, B16. **Scope:** M

### B18 Search all chats

**Description:** Topic 08: "also very powerful". The bottom bar's search button turns into a
search field at the bottom, with the keyboard up. Before typing: recent chats and recent
searches. Above: Images, Videos, Links, Files, Drafts.

**Acceptance criteria:**
- [x] Results in this order (Rami): chats by name (`.fuzzyMatchRoomName`), then messages (the
  SDK's local search index), then links. (2026-11-03, `SearchTests` and `search.contract`
  sections.)
- [x] Check where iOS 26 puts Exact's search field. If not at the bottom, draw our own.
  (2026-11-03: UIKit puts a route header field at the bottom but with no close event; the app
  draws `SearchBar` in a glass bar at the bottom.)

**Dependencies:** B3. **Scope:** L

### B19 Search in one chat

**Description:** Topic 12. From the chat info page: a search for this chat only, with Images,
Videos, Links, Files, Audio and Bookmarks.

**Acceptance criteria:**
- [x] Text search in one chat (the SDK has none per chat: filter B18's results by chat). The
  info page's Search turns the page into the search in place, as Beeper's: the bar's title names
  the chat, the field at the bottom says "Search in <chat>" with the keyboard up, and X (in the
  bar or beside the field) turns it back, the page fading in. Words find the chat's messages from
  the index (it reads 30 pages of every chat's results, as the SDK has no search per chat), each
  row with its sender's picture and name, then its links. A found message closes the page and
  opens the chat at it, marked (B18's jump). (2026-11-03, `chat-search-members.contract`,
  `search.contract`'s `ChatSearchResults`, `info.contract`'s slot, MatrixCore `Search.swift`.)
- [x] Pages per kind (a timeline filtered by message type; links found in the text): Images,
  Videos, Links, Files and Audio (voice messages and audio files, with their length). Photos
  and videos come from the info page's media timeline; files, links and audio from a timeline
  of their own message types, kept for one chat at a time, paged back once (at most 20 pages of
  50 events, from this device's cache and then the server). So a photo or file is found by its
  type, not by its file name as across chats, and a voice message too, which the index does not
  know. Words typed on a kind's page narrow it by the start of a word (text, file name, link).
- [x] Bookmarks: a sixth kind, the chat's saved messages (B14's list, the same rows without the
  chat's picture); words narrow them by the start of a word (text, file name, sender). The six
  kinds' names are a size smaller, and three to a row at the accessibility text sizes. A tap
  closes the page and opens the chat at the message. (2026-11-03, `search.contract`.)
- [x] Gate: MatrixCore `SearchTests` 7 passed (new: `testOneChatsMessagesAndKinds`), `ChatInfoTests` 5 passed, the
  whole suite passed but for `testFrequentEmojisCountReactionsAndReset`, which failed on `main` too (see
  "Known failing test" below, now fixed); `bun test` 7
  passed (new: `search.test.ts`); drives as `@test1` in light, dark and the largest text size,
  `check both` clean; `verify ios` clean (2026-11-03). Screenshots in `apps/multiplexer/.exact/b19/`.
- Fixed on the way, in the all-chats search too: a link row's time wrapped under the chat's name
  (the name's basis left no room beside the link's button), and the bar's, kinds' and file rows'
  symbols grew past their circles at the largest text size (now a text style with a cap).

**Dependencies:** B18, B20. **Scope:** M

**Known failing test (found 2026-11-03, during B19; fixed 2026-11-03, branch `fix/frequent-emoji-test`):**
`MessageActionsTests.testFrequentEmojisCountReactionsAndReset` failed on `main` about one run in two. The
counting was right; the test raced the sdk. It took a reaction back while it was still being sent: the
sdk then shows the server's copy again for about a second, until its redaction lands (seen: gone at
0.5 s, back at 1.1 s, gone at 1.8 s). A toggle in that second takes the reaction back again instead of
adding it, so the second 🎉 did not count. Now the test takes back only a reaction the server has, and
toggles again once it is gone; MatrixCore counts a reaction from the sdk's answer (`toggleReaction`
returns true when it added one), not from its own copy of the timeline. 8 runs in a row passed (before:
a failure in the second); `MessageActionsTests` 4 passed; every other MatrixCore test passed once (a full
run during a short server outage, then its failed tests again under the lock: 21 passed). Not fixed, as it is the sdk's: in the app, a reaction taken back within
about half a second shows again for about a second. Also: two MatrixCore runs at the same time as the
same test users time out on "the first sync"; run one suite at a time. Every conversation
holds a lock around each run (agreed 2026-11-03): `until mkdir /tmp/mx-matrixcore.lock 2>/dev/null; do sleep
10; done; <the run>; rmdir /tmp/mx-matrixcore.lock`. Do not wait with `pgrep`: two waiters see a quiet moment
at once, and `pgrep -f "xcodebuild test -scheme MatrixCore"` in a shell loop matches the loop's own command line.
**It came back (2026-11-04), with another cause, now fixed (branch `work/emoji-test`):** it failed again,
also on `main`, with "this account's reactions are [:]". A diagnostic showed the test's message id no longer
found the message: the sdk had replaced its timeline item under a new id (40 became 47) while the event
stayed the same, and `toggleReaction` returned silently for an id it could not find, so every later toggle
did nothing. The app had the same bug (a reaction tap could do nothing). MatrixCore now remembers each
item's event and finds a replaced item by it; a message truly gone throws `MatrixCoreError.noMessage`. Before the fix: 3 failures in 3 runs; after: 3 passes in a row under one hold of the lock, a fourth in
`MessageActionsTests` (5 passed), and `AccountDataTests` 2 passed.

**Fixed on the way (2026-11-03, during Bookmarks): a crash at launch.** A relaunch, signed in,
crashed in the sdk's room list (`RoomList.entriesWithDynamicAdapters`, `EXC_BAD_ACCESS`) two
launches of two: `startSync` checked `syncService == nil` and then awaited, so the list, Send
Later and Bookmarks, which all ask for the rooms at launch, could each start a sync service and a
room list. The start is now one shared task (`MatrixAccount.syncStart`). Three launches after the
fix, no crash in any drive since.

### B20 The chat info page

**Description:** Topic 11: "I love the animation of it opening and I love all the things that
you can see in here". Opened from the top bar's picture and name (B9) with the zoom transition
(`navigationSource`).

**Acceptance criteria:**
- [x] It zooms out of the top bar's capsule and shrinks back on close. (A Simulator recording
  under `--timing platform`: `apps/multiplexer/.exact/b20/zoom-open.png` and `zoom-close.png`.)
- [x] Picture, name, "WhatsApp Group · 7 members" (Rami, 2026-11-03: "·") (or the network for a DM); Search, Archive,
  Low Priority (or Unpin) and More; Media; Members with Add member. (`info.contract`,
  `info-members.contract`, `info.ts`, `modules/apple/Info.swift`, MatrixCore `ChatInfo.swift`.
  The member count leaves out the bridge's bot. Media: the chat's newest photos and videos from
  a timeline of its own, four, then up to 40 at "See More"; a tile opens the photo or video
  viewer, zoomed out of it. Members: six by name, "See All" for the rest. Search opens the
  search in this chat (B19). Add Member shows only in plain Matrix groups where you may invite; a
  bridged group says "People join this group on WhatsApp", as Matrix cannot add someone there.
  A DM shows no members' list.)
- [x] Edit: Edit Group Info (name and picture, for groups you may change); Customize for Me (a
  name only you see, in the account's data `com.ramimaalouf.multiplexer.names`, so it follows the
  account to its other devices; the list, the chat bar and the forward sheet show it, and the page
  says what everyone else sees; "Use the Chat's Own Name" takes it away).
- [x] More: Pin, Mark as Read (or Unread, which leaves the chat as the chat bar's does), Mute,
  Delete (with the list's alert). Jump to Date: the SDK has none (jump to a message works), so it
  is left out. Remind Me: in More, "Remind Me…", or "Clear Reminder" with the reminder's time under it (2026-11-03).
- [x] Bookmarks: a row under the four buttons with this chat's count; it opens the chat's own list
  (B14's), where a tap closes both pages and opens the chat at the message. (2026-11-03,
  `info.contract`.)
- [x] Message expiry: last of all (Rami: keep it, "not urgent"); see "Later". (2026-11-03: the info page's
  "Disappearing Messages" section shows the chat's timer and a menu of the timers its network takes (WhatsApp:
  24 hours, 7 days, 90 days), read from the bridge's `com.beeper.room_features` and set as
  `com.beeper.disappearing_timer`, which the bridge passes on; no row for a plain Matrix chat. MatrixCore
  `MessageExpiry.swift`, `testAMessageExpiryIsReadSetAndCleared`. In Rami's WhatsApp chat with himself (a test
  chat) the timer was set to 24 hours and back to Off at about 19:25 local time: Rami checks that WhatsApp showed
  both changes.)
- [x] Gate: MatrixCore `ChatInfoTests` 5 passed and the whole suite 43 passed (1 skipped);
  drives as `@test1` in dark, light and the largest text size, `check both` clean on the page and
  its sheets; `verify ios` clean (2026-11-03). Screenshots in `apps/multiplexer/.exact/b20/`.

**Dependencies:** B9. **Scope:** L

### B21 The "Inbox" title menu, and Settings

**Description:** Topic 02. The title "Inbox" opens a menu: Select Chats, Merge Chats, Settings.
Settings holds Sign Out (it leaves the chat list's top bar) and the voice note speed.

**Acceptance criteria:**
- [x] The title "Inbox" (with a chevron, at the top left, as Beeper's) opens UIKit's pull-down
  menu: Select Chats, Merge Chats, Settings. (2026-11-03, `inbox.contract`, `TitleMenu`.) The
  system bar's large title cannot open a menu in Exact (finding "a large title cannot open a
  menu"), so the inbox draws its own title row (`navigationBar="none"`): it no longer collapses
  on scroll. The inbox's title says "Inbox" instead of "Chats" (a network's name when the sheet
  chose one, as before).
- [x] Settings (`settings.contract`), in the grouped style: the account (picture or initials,
  name, Matrix ID), Voice Messages' Playback Speed (1x, 1.5x, 2x: the same `voiceSpeed` as the
  chip on a voice message), Sign Out in red with the existing confirmation, and the app's
  version under it. Sign Out left the inbox's top bar. MatrixCore's `ownProfile()` reads the
  name and picture (`Profile.swift`).
- [x] Select Chats opens the selection mode (B22). Merge Chats stays greyed pending its design decision.
- [x] `settings.test.contract`: Settings opened by its path (a test cannot sign in) changes the
  speed and keeps it across a reload. Drives as `@test1`: the menu, Settings, the speed shown on
  every voice message in a chat after a relaunch, Sign Out back to the sign-in screen; `check`
  clean in dark, light and the largest text size (`apps/multiplexer/.exact/b21/`, gitignored).
  `verify ios` clean.
- [ ] After Sign Out, the sign-in screen's title shows small until the next launch (Exact
  finding "a large title comes back inline"). Still seen on 2026-11-04 in light, dark and the largest text size
  (`.exact/ui/before/2-signout-*.png`). Exact PR #1410 fixes a minimal app's path (a pop, then the change in place),
  not this app's: with it and a second local Exact change (the stack rebuilt), the title still came back inline. A trace
  showed the bar already shown, 54 points tall, when the signed-out route arrives, with none of Exact's bar-showing
  steps run. Stopped after three tries; it needs the Exact team or a closer look at how the route is rebuilt.
- [x] A picture on the account: `@test1` has none, so only the initials were seen. (2026-11-03: `@test1` has a
  picture now; Settings shows it in its circle, `check both` clean: `apps/multiplexer/.exact/b21/account-picture.png`.)

**Dependencies:** none. **Scope:** S

### B22 Select Chats

**Description:** From "Later" (B7, B21), started 2026-11-03 at the coordinator's hand-off ("continue
until everything is done"). Act on several chats at once, as Messages' and Beeper's select mode.

**Design (assumptions; no Beeper video of this mode exists, so Messages and Mail lead):**
1. Two ways in: the title menu's Select Chats (no chat chosen), and a chat's long-press "Select Chat",
   first in its menu as Beeper's "Select chat" (that chat chosen).
2. The mode: the title says "Select Chats", then "N Selected", with Done at the right. Each row shows a
   circle at its leading edge, the accent's filled check when chosen; a tap chooses or lets go, and
   the long press is off. Pinned pictures get the same mark at their corner. At the accessibility
   text sizes the mark takes the picture's place, so names keep their width.
3. The floating bar becomes the actions' bar: Archive (Unarchive in the Archive), Mark as Read (when
   any chosen chat is unread, else Mark as Unread), Mute (Unmute when all are muted), More (Move to
   Low Priority or to Inbox, Pin or Unpin), and Delete in red with an alert ("Delete 2 Chats?").
   With nothing chosen they are off. While an action waits, selection and its buttons are disabled
   and a spinner says "Updating chats". Success ends the mode; failure keeps the selection and
   shows a retry message, including that some chats may already have changed.
4. MatrixCore `change(roomIds:_:)`: Archive, Unarchive and Delete write the account's marks once
   for all; the others go chat by chat in the chosen order (so pins keep it); every chat is tried.

**Acceptance criteria:**
- [x] `testSelectedChatsChangeTogether`: each action reaches every chosen chat, here and on another device.
  Passed in 90 s on 2026-11-03 (`~/.mx-logs/select-core.log`).
  Rechecked after merging the latest main (including message expiry): passed in 88 s
  (`~/.mx-logs/select-core-integrated.log`).
- [x] Drives as `@test1`, dark, light and the largest text size: both ways in, choosing, each action,
  Delete's alert; real menus with `--touch platform`; `check both` clean but for the floating bars
  over a scrolled list (as the inbox's own bar). `verify ios` clean.
  The final integrated `verify ios` also passed all 6 tests, both schemes and the largest text
  checks, including its fresh native build (144 s; `~/.mx-logs/select-verify-integrated.txt`).
- [x] A simulated server refusal reproduced the old mode closing without a visible error. The fixed
  drive kept its selected chat and showed the retry message. The fault was removed afterward.
- [x] The selection title has an opaque background: scrolled chat text no longer shows through it.
- [x] Merged timeline verification finished successfully: 22 tests, 1 intentional fill-room skip,
  0 failures, in 903 s (`~/.mx-logs/merged-timeline2.log`). The interrupted earlier run is not
  verification evidence. Do not shut down another conversation's simulator.

**Dependencies:** B7, B21. **Scope:** M

### UI review as `@test1` (2026-11-04)

The inbox, a chat, its info page, Settings, the filter sheet, Select Chats and a merged chat, each in light, dark
and the largest text size, with `check` (`apps/multiplexer/.exact/ui2/survey/`, gitignored).
- [x] Fixed in the app: Settings' "Notifications" broke into syllables at the largest size beside "Turn On" (the row
  now wraps; `check` clean on Settings in all three); Select Chats' row said only the name (now its networks too).
  Integrated into main from `7e05b02` and `c56f5a2` on 2026-11-04.
- [ ] A preview whose sender is a bare Matrix id spilled at the largest size. The wrapping patch was transferred
  to the Later lane on resume, which owns its commit and integrated verification; it is not included in this merge.
- [ ] Only Exact can fix (feedback files): the line above a plain list's first row (finding 49); Select Chats' lines
  start under the pictures, not at the names as the inbox's do (the host decides where a row's line starts; moving
  the mark into the row's picture slot changed nothing); `check` calls the rows under the app's bars overlaps
  (finding 55; the inbox's title over the rows under iOS's own soft edge too), and once read a bubble inside the
  bar's fade as a card that does not show.
- Otherwise clean: the info page, Settings and the filter sheet read "no findings" in all three; the inbox too.

### Later

Coordination (2026-11-04): Rami resumed feature work using GPT-6 Astra and GPT-6.1 Sol.
The `work/labels` conversation alone owns finishing Labels, including useful changes from
the preserved `work/labels-finish` branch. `work/later-camera` finishes Communities, Requests,
New Space and the preview sender fix. The Exact lane completes its UI/accessibility review.
The push lane returns to work possible before P3.0. Each lane reports tested commits for
serialized integration into `main`; no duplicate Labels implementation continues.

Rami wants these, after the tasks above (2026-11-02):
- Labels: a named group of chats, shown as a filter in the sheet, with Create Label (the same
  tag way as Archive, B8). "Not a requirement."
- Camera in the + panel: a built-in camera. Done 2026-11-03 for photos ("L1" below).
- Remind Me: a reminder to answer a chat later (B7, B20; a Reminders row in the sheet). Done 2026-11-03:
  - Kept in the account's data (one global event, `com.ramimaalouf.multiplexer.reminders`, as Customize for Me's
    names), so the account's other devices see the reminder and the Reminders row; no bridge reads it. MatrixCore's
    `Reminders.swift`: `setReminder`, `clearReminder`, `reminderList`, and `RoomSummary.reminderAt`.
  - The notification is this iPhone's (`@exact/notifications`): "Reply to <chat>" at the time, tag `reminder-<room>`;
    a tap opens the chat (checked with a relaunch that hands the app the tap). The first Set asks for the permission.
    On each list load, `app.ts` (`syncReminders`) posts the reminders this iPhone has not scheduled (when the
    permission is given) and takes away the notifications of reminders that ended, even on another device; what it
    scheduled is kept in `app:/data/reminders/scheduled.json`.
  - Done: your own message in the chat, newer than the reminder (sent from any of the account's devices), takes the
    reminder away; another person's message does not. Clear Reminder too.
  - The filter sheet's Reminders row (after Archive, an alarm clock, the number of chats) shows the chats with a
    reminder from every list; each row says "Reminder Tomorrow at 9:00 AM", in the accent once it is due.
  - Driven as `@test1` (2026-11-03): set from the long-press menu and from More (Tomorrow, and a picked time: Nov 5,
    2:30 PM gave `showTrigger` 1793907000000); the Reminders list held the chat; an answer in the chat emptied it
    ("No Reminders"); Clear took the notification away. `check both` clean on the sheet, the filter sheet and the
    list, at the default and the largest text sizes. `verify ios` clean.
  - MatrixCore `RemindersTests` (as `@test1` and `@test2`, under the lock): 3 passed. A reminder shows at once, reaches
    a second device of the account and not the other person; their message leaves it; your answer ends it on both
    devices and in the account's data; Clear takes it away.
- Merge Chats: one person on two networks as one chat (B21). Built 2026-11-03 as Way A, the switchable chat (the
  coordinator's choice under Rami's "continue as you see fit"; plan.md's log). What is built:
  - Merge: the title menu's Merge Chats, or Select Chats' More > Merge Chats with two or more chosen. A sheet: the
    name (the first chat's at first), the chats (search by name; a chat in a merge is not offered), and the default
    network (a radio among those picked). Merge needs two chats and a name.
  - Kept in the account's data (`com.ramimaalouf.multiplexer.merges`), the default with it, so the account's other
    devices show the same merged chat; MatrixCore's `Merges.swift` (`merge`, `unmerge`, `roomsOf`, the list's fold).
  - The list: one row, `merge:<id>`, with the merge's name, every network's logo on the picture, the newest message,
    the unread counts added; it shows under each of its networks, and its rooms are in no list of their own. Every
    chat action on it (Archive, Low Priority, Pin, Mute, Mark as Read or Unread, Delete, Select Chats' actions) acts on
    each of its rooms; Remind Me is on the room it opens.
  - Opening it: the room of the other person's newest message, else the default. The chat bar shows the networks as
    tabs under the name; a tap shows that network's chat. Each network's chat is the room it was, so every chat
    feature works as before.
  - Unmerge: the info page's More > Unmerge; the rooms show as their own chats again.
  - Checked (2026-11-03, as `@test1`): merged the "Multiplexer bar test" WhatsApp and Instagram chats from the title
    menu and from Select Chats; the row showed both logos; the chat opened the WhatsApp room and the Instagram tab
    showed the other in place, Back to the list; Unmerge in More brought both rows back. `check both` on the sheet clean;
    on the chat at the default and largest sizes no overflow, size or clipping finding; the overlaps and dark contrast
    it reports there are the floating bar's own (the same chat unmerged shows the same kinds; Exact finding 55). At
    the accessibility sizes the tabs show the logos only. `verify ios` clean (6 tests).
  - MatrixCore: `MergesTests` 3 passed (two offline; one end to end with a second device of `@test1`, whose first
    sync took 27 s, so that test waits up to 90 s for it); `NetworkFilterTests`, `InboxTests`, `RemindersTests` and
    `ChatActionsTests` passed with the change (one ChatActions test failed once and passed on its rerun).
  - Not done: Beeper's suggestions (same phone number or name), and renaming a merge (unmerge and merge again).
  - The design notes below were written before the choice.
  - What Beeper does (its help page, "Merge chats getting started guide"; our recording shows only the greyed menu
    row): Inbox menu > Merge Chats > pick the chats > a name and a default network. The merged chat replaces its chats
    in the list as one row; its unread count is their sum; Mark as Read, pins and labels act on the whole. Inside, one
    timeline of all their messages by time, with a network mark between messages, one "New" line and one combined
    receipt. A reply goes on the network of the newest incoming message (else the default chat after 30 minutes), and
    the composer can pick a network. It suggests merges by the same phone number, email or two-word name. Unmerge:
    the chat's info > Manage > Unmerge. Merges follow the account to its other devices; the default network does not.
  - Sound with Matrix: yes. Matrix has no link between rooms, so the merge is the app's: one global account data
    event, `com.ramimaalouf.multiplexer.merges` (`{"merges": [{"id", "name", "rooms": [...], "default"}]}`), as
    reminders and names are kept; the account's other devices have it, and no bridge reads it. Each network chat stays
    its own room with its bridge; sending to a room is unchanged. A chat is in at most one merge.
  - Shared by both ways below (MatrixCore `Merges.swift`, about a day): the list folds a merge's rooms into one row
    (the newest message, every network's logo, the unread sum, the merge's name), and the filters and the network
    rows count it once (it shows under each of its networks). Each chat action (Archive, Low Priority, Pin, Mute,
    Mark as Read or Unread, Delete, Remind Me) acts on every room of the merge. The title menu's Merge Chats opens
    a sheet that picks two or more DMs (search by name), then a name and a default network; the info page gets
    "Manage" with Unmerge. No suggestions at first.
  - Way A, a switchable chat (recommended first): the merged row opens the room of the newest incoming message (else
    the default), and the chat bar shows the networks as a small segmented control to switch rooms. Every chat
    feature keeps working as it is, since the open chat is still one room (`openRoom` is in about 115 places in 11
    files). About a day more.
  - Way B, Beeper's combined timeline: MatrixCore merges two live timelines by time and pages each back; every
    message carries its room, and a reply, reaction, edit, delete, swipe to reply, read receipt, "Seen" line, search
    in the chat, media grid, Send Later and the "New" line each act on the message's own room; replying to a message
    switches the sending network to its own. Several days, and a risk to the chat's tested features.
- Select chat: act on several chats at once (B7, B21). Built 2026-11-03, see "B22 Select Chats".
- Transcribe voice notes (B16): check whether the iPhone can do it on the phone, at no cost.
- Communities as filters ("whatever is easiest"): after B4.
- Requests and New Space in the filter sheet: look at what Beeper does first.
- Message expiry (B20): the very last.

Not wanted for now: Poll.

### L1 Camera in the + panel

**Description:** Beeper's + panel has "Camera" (report, topic 14). The panel's second row opens
the camera full screen over the chat (`camera.contract`, `camera-members.contract`), with
`@exact/camera`'s viewfinder over `@exact/media-capture`'s track. The shutter's photo joins the
composer's tray as a photo from the library does (the same `attachPhotos` path: made smaller and
upright while the caption is typed, sent with Send). Photos only: Exact's camera takes stills,
and `@exact/recording` records sound only, so a video needs a native module of our own (not
built; ask Rami if wanted).

**Acceptance criteria:**
- [x] The panel shows Camera where the device has a camera (`cameraStatus().available`).
- [x] The camera opens on the back camera; Switch Camera (where there is a front one) and Flash
  (where the camera has a torch; hidden on the front camera); a tap focuses, a pinch zooms.
- [x] The shutter adds "Photo N.jpg" to the tray, stops the camera, and brings the keyboard back;
  Close stops it too. The camera screen is dark in both appearances, as the phone's.
- [x] Camera refused in Settings: "Camera Access Is Off" with Open Settings, and no request.
- [x] The app's own shape `Chosen` holds a picked file or a camera photo (a `Picked` cannot be
  built in Contract; Exact finding 103).

**Verification (2026-11-03, Simulator "MX media", the agent's camera, `@test1`):**
- [x] A drive in "Multiplexer two-person test": + panel, Camera, flip, shutter, a caption, Send:
  the message is a photo (1280×960) with its caption, state "sent".
- [x] Dark, light, and the largest text size: `check` clean on the panel and the camera screens
  (the chat's own overlap findings under the floating bars are known); the refused screen
  scrolls at the largest size.
- [x] `verify ios` clean. No MatrixCore change (sending uses B11's `sendMedia`).
- [ ] **On Rami's iPhone** (the Simulator has no camera; the agent's camera is a still card): the
  permission dialog shows "Takes the photos you send."; the back camera's preview is upright in
  portrait and fills the space between the bars; the front camera is mirrored in the preview and
  not in the photo; the flash fires; tap to focus and pinch to zoom work; the shutter sound
  plays; the green dot goes out after Close and after the shutter; a photo from the camera sends
  to WhatsApp as a photo.

**Dependencies:** B10, B11. **Scope:** S

## Phase 3: push notifications (M3)

Detailed 2026-11-02 from a read-only research (Exact at `ed43ad09a0`, the SDK bindings 26.10.27,
the playbook at `e3929968b8`). Order (Rami): after the inbox tasks B1 to B8, before the chat
details. M3: a WhatsApp message wakes Rami's locked iPhone with the sender and the text.

What the research found:
- **Exact has no remote push yet** (LLP 1133.004 section 9: "Nothing of it is built here"). The
  app's module can register for push, but Exact's app delegate has no token callback, so the module
  adds it at run time (`class_addMethod`; a guess until P3.1 proves it). Permission and the badge
  are built (`@exact/notifications`: `requestNotificationPermission`, `setAppBadge`).
- **Exact cannot build our notification extension, and cannot sign the app for push or an App
  Group** (it adds those entitlements only for its own widgets and Live Activities). A script of
  ours adds the extension after Exact's device build and signs both. The biggest unknown: P3.1.
- **The SDK has what we need:** `Client.notificationClient(processSetup: .multipleProcesses)`,
  `getNotification(roomId:eventId:)`, memory-constrained stores, a cross-process lock, `setPusher`
  with `PushFormat.eventIdOnly`. The SDK store must move into an App Group so the extension can open it.
- **The server:** the playbook installs Sygnal (v0.17.0, arm64 image). It needs Rami's APNs key and
  its own name, `sygnal.ramimaalouf.com` (Synapse accepts only the path `/_matrix/push/v1/notify`).
- **TestFlight stays blocked** (Exact's archive check refuses `registerForRemoteNotifications`);
  development builds on Rami's iPhone are not checked, so M3 is not blocked.
- WhatsApp chats are not encrypted, so M3 needs no decryption; Matrix encrypted rooms need the
  shared crypto store and the lock.

### P3.0 The Apple setup (Rami)

**Description:** push and an App Group need explicit App IDs and profiles; the team wildcard
profile grants neither. Rami can do this now, while the inbox tasks run.

**Acceptance criteria:**
- [ ] App Group `group.com.ramimaalouf.multiplexer` exists.
- [ ] App ID `com.ramimaalouf.multiplexer` has Push Notifications and App Groups; App ID
  `com.ramimaalouf.multiplexer.notifications` has App Groups (the same group).
- [ ] An APNs key (`.p8`) is in the Mac's Keychain as base64 (service `multiplexer-apns`, account
  `key`), with its Key ID (account `key-id`). Never in chat or git.
- [ ] A development profile for each App ID, with the iPhone `00008140-0002155C01F3001C`, is
  installed on the Mac.
- [ ] Cloudflare: `CNAME sygnal -> matrix.ramimaalouf.com`, DNS only.

**Verification:** `security cms -D -i` on each profile shows `aps-environment development`, the
group and the phone; `security find-generic-password -s multiplexer-apns` finds the key.

**Dependencies:** none. **Scope:** XS (Rami)

### P3.1 Spike: a notification extension inside the Exact app

**Description:** the biggest unknown. Prove that the app ships a notification service extension,
signed for push, on Rami's iPhone. No Matrix code yet: the extension only changes the text. The
push goes from the Mac straight to APNs, so no server is needed.

**Acceptance criteria:**
- [ ] `scripts/build-ios-device.sh`: Exact's device build with `--no-install` and `EXACT_PROFILE`;
  compile `apps/multiplexer/extensions/notifications/NotificationService.swift` into
  `PlugIns/MultiplexerNotifications.appex` (Exact's share extension is the pattern:
  `host/apple/extensions.mjs`); sign it; sign the app again with `aps-environment development`, the
  App Group and the Keychain group; install with `devicectl`. (2026-11-03: written as
  `scripts/add-notification-extension.sh --sim|--device <udid> <app>`, run after Exact's build.
  `--sim` done on the Simulator: the extension (MatrixCore and the sdk compiled in, 36 s, cached;
  73 MB) is in `PlugIns/`, the system registers it, and the app's simulated entitlements get
  `aps-environment` and the App Group. `--device` is written, not run: it waits for P3.0's profiles.)
- [x] The app asks for permission (`@exact/notifications`, grant `device.notifications`), then
  registers; the module adds the token callbacks to Exact's app delegate; a development build logs
  the token. (2026-11-03, the Simulator: it asks after sign-in; Settings has a Notifications row
  with "Turn On" when not asked yet; the token arrives through the callbacks added at run time,
  `modules/apple/PushRegistration.swift`.)
- [ ] `scripts/send-test-push.sh` sends a push to APNs sandbox, signed with the `.p8` from the Keychain.
  (2026-11-03: written; `--dry-run` signs with a throwaway key and checks the signature. The real
  send waits for P3.0's key. It works for the Simulator too: the Simulator has a real sandbox token,
  so the extension can be proved on the Simulator before the iPhone.)
- [ ] The locked iPhone shows the text the extension wrote (Rami confirms once).
- [ ] A phone drive after the script still runs the app with the extension, or the gap is written down.
  (2026-11-03, the Simulator: a drive keeps it, as the script patches Exact's build in place; an
  Exact rebuild drops it until the script runs again.)
- [ ] After 3 failed rounds: stop, write down the blocker, and decide whether to wait for Exact.

**Verification:** `codesign -d --entitlements -` on the app and the extension; the extension logs
one line per push into the App Group.

**Dependencies:** P3.0. **Scope:** M

### P3.2 Spike: MatrixCore in the extension, with the sender and the text

**Description:** the plan's high risk. The extension restores the session from the shared
Keychain, opens the store in the App Group, fetches one event, and shows the chat, the sender and
the text. Memory and time are measured on the iPhone.

**Acceptance criteria:**
- [x] A public `PushContent` in MatrixCore, plain types only: roomId, chatName, senderName, body,
  network, isDirect, isNoisy, hasMention, threadId. (`matrix-core/Sources/MatrixCore/Push.swift`, with eventId.)
- [x] The fetch builds a memory-constrained client (`systemIsMemoryConstrained`, `.multiProcess(holderName:
  "notifications")`, `.one(roomId:)`, `.multipleProcesses`), then `getNotification`. The body uses
  the chat list's word for each message kind. (`MatrixPush.content`. A multi-process lock needs
  session delegates: `SessionStorage`, backed by the Keychain item in the app and the extension.)
- [ ] The app's store moves once into the App Group (Rami does not sign in again); the app's
  client takes the lock as `"app"`; `SessionKeychain` uses the access group
  `3V2UU7RRK9.com.ramimaalouf.multiplexer`; the agent keeps its own folder. (2026-11-03: the lock
  as `"app"` and `SessionKeychain.accessGroup` done; the app's items are already in that group, its
  default. The move is implemented in `0939ebc` (preparation below); proving it on an entitled
  device still waits for P3.0's App Group.)
- [ ] The extension sets `threadIdentifier` to the room id and the badge from `unread_count`.
- [ ] On an error, a timeout, or before the first unlock after a reboot, it shows "New message";
  never an empty or raw payload. (Both written in `extensions/notifications/NotificationService.swift`;
  they need a real push to run: `send-test-push.sh` with P3.0's key.)
- [ ] `@test1` on the locked phone, `@test2` sends: chat, sender and text within 5 s, in a plain
  and in an encrypted room. The app open on a chat at the same time keeps working.
- [ ] Peak memory and the time from push to banner are written in `matrix-core/NOTES.md`.

**Verification:** a MatrixCore test (`testAPushShowsTheSenderAndTheText`): a second client built as
the extension builds it reads `@test2`'s message in a plain and an encrypted room; then the phone test.

**Dependencies:** P3.1. **Scope:** M (L if the store move is hard)

**Preparation, 2026-11-04:** shared-store code is implemented in `0939ebc`, with
`SessionStoreTests` (11 passing filesystem tests) and push/search/sign-out regression checks
(15 passing tests). Legacy metadata defaults to data; an interrupted move finishes its metadata
write on retry; an unavailable group retains the session and refuses replacement sign-in;
agent sessions never use the group. Sign-out removes only its resolved store. Keychain writes
update existing items in place. The extension opens only a published group store.
Integrated into main from `86d3a80`. Conservative limitation: when both the group is
unavailable and legacy data is absent, the app retains the session and refuses replacement
login. This also affects a genuinely deleted legacy store, because it cannot distinguish that
case from a move completed before its metadata was saved.
The acceptance criterion above stays unchecked until P3.0 permits a real entitled migration
without signing in again. Phone delivery, memory and timing also remain unproved.
After incorporating main cebda48, `verify ios` passed all 6 tests, light/dark checks and
8 largest-text screens (75.2 s; `/tmp/mx-store-migration-logs/integrated-verify.log`).
Settings matches cebda48. Test sessions signed out; MX main shut down.
P3.6 badge semantics and WhatsApp mute policy still need decisions; P3.7 still needs
the documented Exact notification activation/presentation integration. Neither is claimed done.

### P3.3 Server: Sygnal (server conversation)

**Acceptance criteria:**
- [ ] Rami's OK, and the DNS record from P3.0. (Rami's OK, 2026-11-03: install it when P3.0's
  APNs key is in the Keychain and the DNS record exists. Neither exists yet.)
- [ ] Through the playbook (invariant 6): `matrix_sygnal_enabled: true`; two APNs apps,
  `com.ramimaalouf.multiplexer.ios.dev` (`platform: sandbox`) and `com.ramimaalouf.multiplexer.ios`
  (production), both with team `3V2UU7RRK9` and topic `com.ramimaalouf.multiplexer`; the key from
  the Keychain into the gitignored `vars.yml`, then to the server with mode 0600
  (`aux_file_definitions`). Keep the default host name; no path prefix.
- [ ] Sygnal answers from the Mac, and a test POST with the phone's pushkey reaches the phone.
- [ ] No key in git; `server/README.md` names the Keychain item, never the key.

**Prepared (2026-11-03, branch `server/p3.3-sygnal`, not merged, not applied).** `config.yml`
turns Sygnal on with the two APNs apps above (`keyfile: /data/apns-key.p8`, the Key ID from
`vars.yml`) and `aux_file_definitions_custom` writes the key to `/matrix/sygnal/data/apns-key.p8`
(mode 0600, user `matrix`). `server/setup.sh` copies the key and its Key ID from the Keychain
(`multiplexer-apns`, accounts `key` and `key-id`) into `vars.yml` when they are there; without
them the playbook stops on an undefined variable, so it cannot install a Sygnal with no key.
`server/README.md` has a "Push (Sygnal)" section and the Keychain row. Checked on the Mac with a
throwaway key (not Apple's): the apps render as above, and the key file comes out identical.
Note: the playbook keeps a copy of `vars.yml` on the server (`/matrix/vars.yml`, mode 0660, user
`matrix`), so the key is there too, as the other secrets are.

**To apply, after P3.0 and Rami's OK:** `./server/setup.sh` (the note about a missing key must not
show); merge `server/p3.3-sygnal` into `main`; install; then
`curl -s https://sygnal.ramimaalouf.com/health` from the Mac. The last check needs the phone's
token from P3.1.

**Dependencies:** P3.0; the phone's token from P3.1 for the last check. Can run beside P3.1 and P3.2.
**Scope:** S

### P3.4 The pusher

**Acceptance criteria:**
- [x] After sign-in and at each launch (permission given, token known), the app calls `setPusher`:
  app id `com.ramimaalouf.multiplexer.ios.dev` for a development build, `.ios` later; pushkey the
  token in base64; URL `https://sygnal.ramimaalouf.com/_matrix/push/v1/notify`; format event id
  only; a default payload with `mutable-content` and "New message"; `append: false`. (2026-11-03,
  the Simulator as `@test1`: `scripts/list-pushers.sh` showed exactly that pusher. Our server takes
  it with no gateway running.)
- [x] A new token replaces the old one; Sign Out calls `deletePusher` first. (The pusher is kept in
  the Keychain item; after Sign Out, `list-pushers.sh` showed 0. `testAPusherIsSetReplacedAndDeleted`.)
- [x] A drive sets a pusher only for `@test` users, never on `@rami`. (`registerPush` checks
  `sendsReadReceipts` first; `list-pushers.sh` refuses any account but a test user.)

**Verification:** `scripts/list-pushers.sh` (like `list-test-devices.sh`) shows one pusher with
the right values, and none after Sign Out.

**Dependencies:** P3.1, P3.3. **Scope:** S

### P3.5 End to end: a message wakes the locked iPhone (M3)

**Acceptance criteria:**
- [ ] `@test1` on the iPhone, `@test2` sends: chat, sender and text within 5 s with the app swiped
  away, in the background, and after a reboot and one unlock; also in an encrypted room.
- [ ] M3: on Rami's iPhone, signed in as `@rami` for his own use, a WhatsApp message from another
  person shows its sender and text. Rami confirms. Agents send nothing as `@rami`.
- [ ] The delay from send to banner over 10 tries goes into `tasks/plan.md`.

**Dependencies:** P3.2, P3.3, P3.4. **Scope:** S

### P3.6 Muted chats, mentions and the badge

**Acceptance criteria:**
- [x] A chat muted in our app (B7) gets no push; a mentions-only chat gets only mentions
  (`@test1`, `@test2`). (2026-11-04, without APNs: `PushRulesTests` reads what Synapse itself
  decides, `GET /notifications`, after a plain message and a mention from `@test2` in three rooms
  of `@test1`'s. Normal: both notify. Mentions only (the room rule with no actions that
  mautrix-go's `MuteRoom` writes): only the mention. Muted in our app: neither, and the mention
  still counts for the list's "@". Our mute's rules already do this; nothing to fix.)
- [ ] **Ask Rami:** WhatsApp mutes copy only when the bridge makes a chat's room
  (`mute_only_on_create: true`, the playbook's default): keep that, or follow WhatsApp's mute.
- [ ] **Ask Rami:** the badge counts chats (the server's default) or messages. The extension and
  the app show the same number.
- [ ] A chat read on another device lowers the badge with no banner.
- [ ] Opening a chat removes its delivered notifications.

**Dependencies:** P3.5, B7. **Scope:** S

### P3.7 A tap opens its chat; no banner for the open chat

**Acceptance criteria:**
- [ ] A tap on a notification opens its chat. Exact drops a tap on a notification it did not post
  (`Notify.swift` reads only `userInfo["exact"]`); ask the Exact team before relying on that key.
- [ ] With the app in front on a chat, its messages show no banner (needs Exact's `willPresent`).

**Dependencies:** P3.5, and Exact. **Scope:** S, plus Exact's part

### Later (not in M3)

- Sender pictures in notifications (communication notifications).
- Reply from a notification.
- Apple's filtering entitlement, to hide a push the extension cannot show.
- TestFlight (blocked by Exact's archive check).
- Ask Rami: turn off Element X's and Beeper's notifications, to avoid double notifications.

Exact feedback to record when P3.1 runs (framework design questions, not doc PRs): no push
registration or token callback; the archive check refuses `registerForRemoteNotifications`; no way
to declare `aps-environment`, an App Group or a Keychain group; no app-defined extension; remote
notifications reach no app code (no `willPresent` / `didReceive` hatch).

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
