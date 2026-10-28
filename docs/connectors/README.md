# Connectors

A **connector** is one chat network in Multiplexer: one mautrix bridge on the server,
plus what the app knows about that network. WhatsApp is the first connector (T0.6).
This file is the pattern for every connector. Each network has its own file here:

| Network | File | State (2026-10-28) |
|---|---|---|
| WhatsApp | (T0.6, `server/notes/install.md`) | Runs. 265 chats, double puppeting. |
| Instagram | [`instagram.md`](instagram.md) | Proposal. A spike waits for Rami's yes. |
| Signal, Telegram, Messenger | none yet | Phase 4. |

Status: proposal. Rami decides. Facts were checked on 2026-10-28 against the pinned
playbook (`e3929968b8`), mautrix-meta `v0.2610.0`, mautrix-go `v0.32.0` (the bridge
library that the bridges at that version use), and the live server (read only).

## The pattern

| Layer | What a connector needs | Where |
|---|---|---|
| Server | One `config.yml` block, one playbook run, one login. | `server/` (the server conversation) |
| MatrixCore | The network of each room, as a plain string. The bridge's login API. | `matrix-core/` |
| App | A network badge, a filter, a "Connections" screen, a "disconnected" banner. | `apps/multiplexer/` |
| Tests | Automated with `@test1` and `@test2`; real logins stay manual. | both |

Invariant 1 of the plan stays true: the app talks only to our homeserver and to the
bridges' API behind it, never to WhatsApp or Instagram.

## Server side

**Config block.** Each bridge is one variable in
`server/inventory/host_vars/matrix.ramimaalouf.com/config.yml`, with a lowercase comment
that says how to log in and what we decided:

```yaml
# the <network> bridge. a user connects by sending `login <flow>` to
# @<network>bot:ramimaalouf.com. the image is prebuilt for arm64. bridged rooms are not
# end-to-end encrypted (see the whatsapp block).
matrix_bridge_mautrix_<network>_enabled: true
```

**Install.** The same commands as T0.6:

```sh
./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start
./server/playbook.sh --tags=self-check
```

The install restarts Synapse, so the app and the other bridges see a short break. Check
in `server/notes/install.md` that the image was pulled for arm64 and not built.

**Double puppeting.** `matrix_appservice_double_puppet_enabled: true` is already on for
the whole server. Every new mautrix bridge uses it with no extra setting. What Rami sends
from the network's own app shows as sent by `@rami:ramimaalouf.com`.

**Encryption.** Keep bridged rooms unencrypted (`matrix_bridges_encryption_enabled: false`,
the playbook's default), as for WhatsApp. The bridge reads every message anyway, so
end-to-bridge encryption protects only the copy in Synapse. Plain rooms keep push
(Phase 3) and the room list simple. Revisit only if the server's risk changes.

**Permissions.** Keep the playbook's default: every user of `ramimaalouf.com` may log in
(`user`), others only `relay`. The server has 3 users: `@rami`, `@test1` and `@test2`.
This lets a test user hold a test account on any bridge.

**Backfill.** Each bridge has its own limits. Keep the defaults for a spike, and change
them only after we see the real numbers.

| Bridge | First sync | Per chat |
|---|---|---|
| WhatsApp | History sync from the phone (265 of 267 chats came). | The playbook's default. |
| Instagram | The first inbox page only (`thread_backfill.batch_count: 0`). One report (issue #374): 15 to 17 chats per account. | 50 messages; 500 after a restart. |

**Log privacy.** Bridge logs hold phone numbers, user names and chat IDs. Read only
counts, or hide the identifiers. The default log level is `warn`; raise it only for a
fault, then lower it again.

**Disconnect alerts.** Every bridgev2 bridge sends a message to the user's bot room when
a login fails (`bridge_status_notices: errors`, the default; the playbook does not change
it). It reports `BAD_CREDENTIALS` and `UNKNOWN_ERROR` at once, and a
`TRANSIENT_DISCONNECT` that lasts more than 3 minutes. The message carries the raw
state in `fi.mau.bridge_state`. Errors are `m.text`, not `m.notice` (checked in
mautrix-go), so Phase 3's push can show them. We need no other monitoring.

**Backups.** Each bridge keeps its database in our PostgreSQL (for example
`matrix_mautrix_meta_instagram`). The M0 checkpoint's PostgreSQL backup covers it. That
database holds the network's session (cookies or keys), so a backup is a secret: keep it
encrypted and out of git. If a bridge database is lost, Rami logs in again; the messages
stay in Synapse.

**Resource use.** Measured on 2026-10-28, 00:51 UTC, with the WhatsApp bridge only:
4.0 GiB of 23 GiB used, load 0.18, disk 32 of 96 GB. Synapse 1.8 GiB, PostgreSQL
669 MiB, the WhatsApp bridge 95 MiB. A bridge adds about 100 MiB at rest; the first
history sync is the peak (WhatsApp: load 2.35). Note both numbers for each new bridge.

**Names.** The playbook adds a suffix to every contact's name: " (WA)", " (IG)", " (FB)".
Remove them when the app shows a network badge (in one playbook run, for all bridges).
Until then, Element X needs them to tell networks apart. The variables:
`matrix_bridge_mautrix_whatsapp_network_displayname_template` (WhatsApp has no suffix
variable; its template ends in " (WA)"), and
`matrix_bridge_mautrix_meta_instagram_bridge_displayname_suffix`.

**The bridge's API is public.** The playbook exposes each bridge's provisioning API at
`https://matrix.ramimaalouf.com/bridges/<name>` (`matrix_bridges_exposure_enabled`,
default `true`). It needs a Matrix access token: `/bridges/whatsapp` answers 401 without
one (checked 2026-10-28). `https://matrix.ramimaalouf.com/.well-known/matrix/mautrix`
lists the bridges: today `["https://matrix.ramimaalouf.com/bridges/whatsapp"]`. This is
what the app uses to connect a network. It is not on `ramimaalouf.com` (the website), and
it does not need to be.

## App side

### The network of a room

Every bridged room has an `m.bridge` state event (and a copy as `uk.half-shot.bridge`).
Its state key is `ramimaalouf.com/<appservice id>`, for example `ramimaalouf.com/whatsapp`.
The fields that matter:

| Field | Example | Use |
|---|---|---|
| `protocol.id` | `whatsapp`, `instagramgo` (checked on the server; not the bridge's network ID `instagram`) | The network. The app's only key. |
| `protocol.displayname` | `Instagram` | The badge's label. |
| `protocol.avatar_url` | `mxc://maunium.net/…` | The badge's icon (or an icon in the app). |
| `com.beeper.room_type.v2` | `dm`, empty for groups, `space`, `personal_filtering_space` | DM or group. |
| `bridgebot` | `@whatsappbot:ramimaalouf.com` | The bot room is not a chat. |

Checked on the live server (2026-10-28, counts only): 266 rooms have `m.bridge`, all with
`protocol.id` `whatsapp`: 192 `dm`, 59 groups, 14 `space`, 1 `personal_filtering_space`.
A room without `m.bridge` is a Matrix room (for example `@rami` with `@rami-m:matrix.org`).

**How MatrixCore reads it.** The SDK (26.10.27) has `room.stateEvents(eventType:)` for a
custom type, but it stores only the state that the sliding sync asked for, and its Swift
API has no way to add `m.bridge` to the room list's required state (checked in
`matrix_sdk_ffi.swift`). So MatrixCore reads `m.bridge` once per new room with
`GET /_matrix/client/v3/rooms/{roomId}/state/m.bridge/{stateKey}` and caches the
result: a room's network never changes. About 270 reads at the first sign-in (one per
joined room), then one per new chat. The app gets a plain `network: String?` per room (invariant 3).

### Badge, filter, bot rooms

- A small network icon on the chat's picture in the list, and the network's name in the
  chat's title area. No suffix in names (see **Names** above).
- One filter row above the list: All, then one chip per connected network. It appears
  only when two or more networks are connected.
- The bot rooms (`@whatsappbot`, `@instagrambot`) leave the chat list and become the
  **Connections** screen (below). The personal spaces stay hidden (T2.10 hides spaces).

### Connect a network in the app

The app uses the bridge's provisioning API (bridgev2, `/_matrix/provision/v3`, behind
`https://matrix.ramimaalouf.com/bridges/<name>`), with the user's Matrix access token as
`Authorization: Bearer` **and** the user's ID as `?user_id=@name:ramimaalouf.com` on
every call. Without `user_id`, a valid token gets HTTP 401 `M_UNKNOWN_TOKEN` (checked
2026-10-28 as `@test1`; the bridge checks the token for that user ID). With it,
`/v3/login/flows` lists `qr` and `phone` for WhatsApp, and `android`, `instagram` and
`instagram-password` for Instagram. MatrixCore owns these calls; the app sees plain steps.

| Call | Use |
|---|---|
| `GET /v3/whoami` | The network's name and icon, the login flows, the bot, and the user's logins with their state (`CONNECTED`, `TRANSIENT_DISCONNECT`, `BAD_CREDENTIALS`, `UNKNOWN_ERROR`). |
| `POST /v3/login/start/{flowID}` | Starts a login. Returns the first step. |
| `POST /v3/login/step/{loginID}/{stepID}/{type}` | Submits a step. Returns the next step, or `complete`. |
| `POST /v3/logout/{loginID}` | Disconnects. |

The step types, and the networks that need them:

| Step type | The app shows | Needed for |
|---|---|---|
| `display_and_wait` | A QR code or a code, then waits. Or only a message: "Approve this login in the Instagram app". | WhatsApp (QR), Signal (QR), Telegram (QR), Instagram (`android`, approval on another device). |
| `user_input` | Text fields: user name, password, phone, a 2FA code, a choice. | Instagram (`android` flow), Telegram (phone and code). |
| `cookies` | A web view on a page the bridge names; the app sends back the cookies it asks for. Needs a WKWebView native view; Exact has no general web view in v1. | Instagram (`instagram` flow; also a reCAPTCHA inside the `android` flow), Messenger. |
| `client_http` | The phone makes the network's login requests for the bridge, so the login comes from the phone's IP address. | Optional. New in mautrix-go v0.32.0; see below. |
| `complete` | "Connected", then the chats arrive. | All. |

**Recommended order:** `display_and_wait` and `user_input` first. Together they cover
WhatsApp, Signal, Telegram and most of Instagram's `android` flow. Build `cookies` (a
WKWebView module) when the spike or a real login meets a reCAPTCHA, or for Messenger.
This keeps Phase 4's note ("QR first, then `user_input`, then `cookies`"), and the
spike tells us how soon `cookies` is needed.

**`client_http`** (start a login with `?client_http=1`): the bridge sends the app an HTTP
request to run, and the app posts back the answer. Instagram's password flows ask for a
browser or Android "fingerprint" (TLS signature); iOS's `URLSession` cannot copy one, and
we do not know if Instagram accepts the difference. Keep it for later: use it only if the
spike shows that logins from the cloud IP fail.

**Connection state.** On launch and on return to the foreground, the app calls
`GET /v3/whoami` for each bridge. A login that is not `CONNECTED` for more than a few
minutes shows a banner: "Instagram is disconnected. Reconnect." The banner opens the same
login flow. The bot's error message is a second signal (and a push after Phase 3).

## Tests

| What | How | Automated? |
|---|---|---|
| Reading `m.bridge` | A MatrixCore test: `@test1` makes a room, sends a fake `m.bridge` state event, and reads the network back. No bridge needed. | Yes |
| Each message kind | The T2.11 method: `@test1` sends events with the bridge's real shape (fields copied from the spike) to `@test2`, and the app shows them. | Yes |
| The bridge's API | `GET /v3/whoami` and `GET /v3/login/flows` as `@test1` against the real bridges. Read only, so safe. | Yes |
| The login screens | A fake provisioning server in the MatrixCore tests answers each step type. | Yes |
| A real login | QR scan, Instagram password and 2FA, a web view. | Manual |
| Account safety | 48 hours on a secondary account, then weeks on the real one. | Manual |
| Disconnect and reconnect | Log out on the network's side, see the banner, reconnect. | Manual, once per network |

The safety rule stays: tests send only as `@test1` or `@test2`. A test account on a
network belongs to `@test1`, never to `@rami`.

## Adding a network: the checklist

1. Read the playbook's page for the bridge and the bridge's login docs. Note the image's
   architectures, the login flows, and the known risks.
2. Spike on a test account first, connected to `@test1`: enable, install, log in, watch
   48 hours. Record the message shapes and the resource use.
3. Rami decides: go, go with changes, or stop.
4. Connect the real account to `@rami` (Rami's yes). Note the first sync's load.
5. The app: the badge needs nothing new (`protocol.id`); add the network's icon and name.
6. The app: build any message kinds that the network adds.
7. The app: the login flow, if it uses a step type the app does not support yet.
8. Update `tasks/plan.md` (facts, risks, decision log) and `tasks/todo.md`.
