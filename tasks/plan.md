# Switchboard: plan

"Switchboard" is a working name. Q2 decides the final name.

## Status

| | |
|---|---|
| Current phase | Phase 0: prove the server |
| Next task | T0.1 Inventory the server |
| Blocked on Rami | Q1 (domain), Q2 (app name and bundle id) |
| Project | `/Users/rami/Documents/code/switchboard` (own git repo, own T3 project) |
| Exact | `/Users/rami/Documents/code/exact/exact2` at `65577096ed` (2026-10-27) |
| Last updated | 2026-10-27 |

Update this table at the end of every work session.

## Goal

Own my messaging. One app on my iPhone (later my Mac) shows all my chats:
WhatsApp, Signal, Telegram, Instagram and others. Messages go through a server
that I control. No company can lock features behind a plan or close the code.

- **User now:** Rami only.
- **User later:** other people who run their own server (Phase 6).

### Non-goals (for now)

- Voice and video calls.
- iMessage (it needs a Mac connected to the server).
- Android, Windows, Linux clients.
- An installer for other people.
- Bridges that run on the phone (Beeper's "On-Device Connections").

## How to use this plan

1. Read **Status**, then the current phase in `tasks/todo.md`.
2. Work only on the current phase. Later phases are rough on purpose. We detail
   a phase at the checkpoint before it, with what we learned.
3. Before you choose work, check it against the **Decision rules**.
4. At each checkpoint: answer its questions, update **Status**, add to the
   **Decision log**, and get Rami's review. If a checkpoint fails, stop and
   change the plan before more work.
5. When a fact below is wrong or old, fix it here and say so in the log.

## Milestones

Each milestone is a thing Rami can see work. Each one is small and can fail.

| | Milestone | Proof |
|---|---|---|
| M0 | **Server proof** | A WhatsApp message sent to me shows in Element X on my iPhone, through my Oracle server. My reply from Element X arrives in WhatsApp. No code of ours. |
| M1 | **First own screen** | Our iOS app (Exact) in the Simulator lists my rooms and shows the last messages of the WhatsApp chat. Read only. |
| M2 | **Daily reading and sending** | On my physical iPhone: live updates, send text, unread counts. I use it for one week. |
| M3 | **Push notifications** | A WhatsApp message wakes my locked iPhone with the sender and the text. |
| M4 | **More networks** | Signal, Telegram and Instagram work. I connect a network from inside the app. |
| M5 | **Mac app** | The same app runs on my Mac. |
| M6 | **Others can install it** | A person can go from a new VPS to a working server with one guided setup. |

## Architecture

```
 Chat networks             Oracle server (aarch64)                    iPhone
 ─────────────             ───────────────────────                    ──────
 WhatsApp     ◄──────►     mautrix bridges (one per network)
 Signal, ...                     │
                                 ▼
                           Synapse + PostgreSQL   ◄── Matrix ──►      App (Exact UI)
                                 │                                      │ native module
                                 ▼                                      ▼
                           Sygnal (push gateway) ──► APNs ──►         MatrixCore (Swift)
                                                                        │ wraps
                           Traefik (TLS: 80, 443, 8448)                 matrix-rust-sdk
                                                                      Notification
                                                                      Service Extension
                                                                      (Phase 3, uses MatrixCore)
```

### Parts and their limits

| Part | Folder | Knows | Does not know |
|---|---|---|---|
| Server config | `server/` | The matrix-docker-ansible-deploy inventory: Synapse, PostgreSQL, Traefik, bridges, later Sygnal. | Anything about our client. |
| MatrixCore | `matrix-core/` | Matrix, through matrix-rust-sdk: sign in, sync, rooms, messages, send, encryption. | UI, Exact, Expo. |
| App | `apps/switchboard/` (name set by Q2) | Screens (Contract), data (`app.ts`), one Swift native module that calls MatrixCore. | Matrix protocol details. It sees only MatrixCore's API. |
| Notification extension | later | Uses MatrixCore to fetch and decrypt one event. | UI. |

### Invariants

These must always be true. A change that breaks one needs a decision log entry.

1. The client talks only to our homeserver, with Matrix. It never talks to WhatsApp or another network.
2. Only MatrixCore calls matrix-rust-sdk. The app and the extension call MatrixCore. This keeps the UI framework choice reversible (Expo is the fallback).
3. MatrixCore's public API uses plain types (strings, numbers, records). No SDK type leaks out.
4. No secret goes into git: passwords, access tokens, the APNs key, `vars.yml`.
5. We can rebuild the server from `server/` plus the secrets on a new VPS.
6. Every server change goes through the playbook. Manual commands on the server only read.
7. The agent works on the Mac. It reaches the server only over SSH (`Host oracle`).

## Decision rules

Use these to check that we work on the right thing.

1. **Prove before build.** Start each milestone with the smallest test that can fail.
2. **Biggest unknown first.** If two tasks are ready, do the one that can kill the plan.
3. **Use what exists.** The playbook, Element X and matrix-rust-sdk come before our own code.
4. **Thin slices.** Each task leaves something that works and that we can see.
5. **When Exact lacks something:** look in Exact's docs and LLPs first. Then use a native module in the app. Propose a change to Exact only if the app cannot do it.
6. **Three tries, then stop.** After three failed fix rounds on one problem, stop and write down the blocker.
7. **Rami decides** domain, names, deletions on the server, and anything that costs money.

## Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Bridges run on the server, not on the phone. | The server is always online. The client speaks only Matrix. On-device bridges need a Go runtime on iOS and special push work. |
| D2 | Homeserver: Synapse, installed by matrix-docker-ansible-deploy. | The playbook's default. Native sliding sync since Synapse 1.114, which matrix-rust-sdk and Element X use. |
| D3 | Client core: matrix-rust-sdk through `element-hq/matrix-rust-components-swift`, inside our own MatrixCore package. | The SDK that Element X uses. Apache-2.0. Has sync, encryption and a notification client. |
| D4 | iOS UI: Exact. Fallback: Expo, reusing MatrixCore. | Native Mac app later from the same code. Chat UI work exists in Exact (`chat-thread` recipe, `apps/messages`, Excord). Revisit at the M1 checkpoint. |
| D5 | Element X is the client until our app is usable. | It works with our server from the first day. |
| D6 | First network: WhatsApp. | QR login (`login qr`). Simple to test. Confirm with Q3. |
| D7 | Work from the Mac. Manage the server over SSH and Ansible. | The iOS build needs Xcode. The playbook runs from the local computer. Safer than an agent with sudo on the server. |

## Facts we rely on

Checked on 2026-10-27. Recheck a fact before a task depends on it.

**Server (`ssh oracle`):** Ubuntu 24.04.5, aarch64, 4 CPUs, 23 GiB memory, 96 GB disk with 30 GB used, Docker installed. We do not know yet what uses the 30 GB.

**Mac:** arm64, Xcode, Docker, uv, Homebrew, gh. Ansible and `just` are not installed.

**Oracle Always Free** ([docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)):
- The page lists 2 OCPUs and 12 GB of A1 as free. Our instance is larger, so check billing (Q5).
- Oracle can reclaim an instance if, over 7 days, CPU (95th percentile), network and memory use all stay below 20%.

**Playbook** ([matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy)):
- It runs from the local computer. It supports Ubuntu 18.04 or newer.
- It "somewhat supports" ARM. Only amd64 is fully supported. A component without an arm64 image is built on the server, if that component supports self-building.
- Ports: 80/tcp, 443/tcp and udp, 8448/tcp and udp.
- DNS: an A record for `matrix.<domain>`. The base domain delegates to it with `/.well-known/matrix/server`.
- Install: `ansible-playbook -i inventory/hosts setup.yml --tags=install-all,ensure-matrix-users-created,start`.
- Check: `ansible-playbook -i inventory/hosts setup.yml --tags=self-check`.
- Add a user: `--extra-vars='username=… password=… admin=yes' --tags=register-user`.
- WhatsApp: `matrix_bridge_mautrix_whatsapp_enabled: true`. Double puppeting needs the Appservice Double Puppet service.

**Matrix homeserver domain:** you cannot change it after install.

**WhatsApp bridge** ([docs](https://docs.mau.fi/bridges/go/whatsapp/authentication.html)): send `login qr` to `@whatsappbot:<base domain>`. If the phone is offline for more than 2 weeks, linked devices disconnect.

**matrix-rust-components-swift** ([repo](https://github.com/element-hq/matrix-rust-components-swift)):
- Swift 5.9, iOS 16 minimum, Apache-2.0, iOS and the iOS Simulator only.
- Product `MatrixRustSDK` (a dynamic library). The binary target `MatrixSDKFFI` is an XCFramework downloaded from GitHub. Version 26.10.27.
- New releases are frequent, so pin the version.

**Exact** (`/Users/rami/Documents/code/exact/exact2`):
- New app: `bun scripts/exact.mjs new <path> --name <Name> --bundle-id <id>`. Set the name and the id before the first build.
- Only `docs/start-here.md` is required reading.
- A native module is `modules/apple/*.swift` or `*.xcframework`.
  - An `ExactModule` subclass answers `call` (on main, within 100 ms) and `later` (from any thread).
  - `context.changed("key")` asks every answer that called `native.watch("key")` again.
- Rust data sources hand all I/O to the host, so matrix-rust-sdk cannot run in one.
- Local notifications are built. Remote push is designed (`subscribePush()`, LLP 1133.004 §9) but not built.
- There is no notification extension target. The WidgetKit `.appex` build is a pattern for one.
- A general web view is out for v1.
- `docs/recipes/chat-thread.md` is the transcript and composer pattern.
- An app made by `exact new` runs `bun exact.mjs feedback status` at the start and keeps a diary in `.exact/diary/` (`docs/diary.md`). Nothing is sent without Rami's yes.

## Risks

| Risk | Impact | Mitigation | Found by |
|---|---|---|---|
| Something on the server already uses Docker or ports 80/443. | High | Inventory first. Rami decides what stays. | T0.1 |
| A component has no arm64 image and cannot self-build. | High | Note each image. Change the component, or move to an amd64 VPS. | T0.5, T0.6 |
| Exact cannot link matrix-rust-sdk. | High | A spike before any UI. Stop after 3 rounds. Fallback: Expo with the same MatrixCore. | T1.2 |
| Oracle reclaims an idle instance. | Medium | The server rebuilds from `server/`. Back up PostgreSQL. Check usage at the M0 checkpoint. | M0 checkpoint |
| Unexpected Oracle charges for 4 CPUs and 23 GiB. | Medium | Rami checks billing. | Q5 |
| A network blocks logins from cloud IP addresses (not verified). | Medium | Test each network before we depend on it. | Phase 4 |
| The notification extension runs out of memory or fails to decrypt. | High for M3 | Test early in Phase 3. | Phase 3 |
| matrix-rust-components-swift is iOS only. | High for M5 | Build the SDK's Swift bindings for macOS ourselves. | Phase 5 |
| SDK API changes often. | Medium | Pin the version. Only MatrixCore touches the SDK. | Always |
| The bridges see message text, so a server breach exposes chats. | High | SSH keys only, few services, updates. End-to-bridge encryption is optional. | Phase 2 |

## Open questions

| # | Question | Blocks |
|---|---|---|
| Q1 | Which domain? User IDs become `@rami:<base domain>`. Does the base domain already host a website? (That decides how we serve `/.well-known/matrix/server`.) | T0.4 |
| Q2 | App name and bundle id (for example `com.<you>.switchboard`)? | T1.1 |
| Q3 | Is WhatsApp the right first network? | T0.6 |
| Q4 | Which Apple Developer team signs device builds and owns the APNs key? | Phase 2, Phase 3 |
| Q5 | Is the Oracle account Always Free or Pay As You Go? Is the 4 CPU / 23 GiB instance free on it? | Cost |

## Decision log

| Date | Entry |
|---|---|
| 2026-10-27 | Plan created. D1 to D7 recorded. Rami is the only user for now. |
| 2026-10-27 | Project moved out of the `exact` folder to `/Users/rami/Documents/code/switchboard` and registered as its own T3 project. The Exact framework is only a dependency, used by path. |
| 2026-10-27 | Pulled the latest Exact. Its `main` history was rewritten on the remote, so local `main` now matches `origin/main` (`65577096ed`). The old local `main` is kept in exact2 as `backup/main-before-2026-10-27-rewrite`. The facts above still hold. |
