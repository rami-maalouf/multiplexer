# Instagram connector: proposal

Status: proposal, 2026-10-28. Rami decides. Nothing was installed, and no Instagram
account was used. The pattern that every connector follows is in [`README.md`](README.md).

## In short

- **Recommendation:** run a small spike now, in parallel with Phases 2 and 3, on a
  **secondary** Instagram account connected to `@test1`. It is one line of server config,
  about 1 hour of Rami's time, and 48 hours of watching. It does not touch the app.
- **The biggest unknown** is whether Meta challenges or locks an account that the bridge
  uses from the Oracle cloud IP. The bridge's own docs say that it can happen. Users
  reported warnings from 2024 to 2025, from cloud servers and once from a home address.
  Others ran for months with none. We found no clear report of a permanent ban of an
  Instagram account, and no report at all for the new Instagram bridge (since July 2026).
- **Encryption is no longer a problem.** Meta ended end-to-end encrypted Instagram DMs on
  2026-05-08, and the bridge dropped encrypted Instagram chats in v26.04. The bridge
  reads every Instagram DM.
- **The app can connect Instagram mostly with text fields:** the bridge's new `android`
  flow asks for a user name, a password and a 2FA code. A web view is needed only for a
  captcha, or for the older cookie flow.
- **Not Messenger now.** It is a separate bridge, a separate Facebook account and its own
  risk. Add it later with the same spike, only if Rami uses Messenger (Q6 below).

## Assumptions

1. Rami's main Instagram account matters to him and is hard to replace. So the spike
   protects it.
2. Rami has, or can make, a secondary Instagram account and can use it on his phone for
   the spike.
3. The spike starts after the M0 checkpoint's 48 hours (2026-10-29, 23:00 UTC), because
   the install restarts Synapse.
4. Shared reels, shared posts and story replies are the most common Instagram DMs for
   Rami. Not checked; it sets the order of the app work in section 3.

## 1. Risks

| # | Question | Answer | How sure |
|---|---|---|---|
| R1 | Can Meta flag or lock Rami's real account? | Yes, it can. Most reports describe a warning ("We suspect automated behaviour") and a blocked bridge session; the account itself keeps working after a check (captcha, "confirm it's you", a password reset). 2FA lowers the risk, the docs say. | Medium that warnings happen. Low on how often, and on permanent bans. |
| R2 | Does use from the Oracle IP trigger checks or blocks? | Possibly, but the address is not the only cause. One user tied the warnings to a move to the cloud; another got one within an hour from a home address with 2FA on. | Low. Few reports, mostly the old bridge. The spike measures it. |
| R3 | How long does a session last? | From days to months in reports. The bridge stops after one "unauthorized" close from Meta and waits for a new login. | Low. |
| R4 | Is DM encryption on, and what can the bridge read? | No encryption since 2026-05-08. The bridge reads every DM. | High. |
| R5 | Does the bridge break when Meta changes Instagram? | Yes, from time to time. The fix is a bridge update (a new playbook pin). | Medium to high. |

### R1: account flags and locks

- The bridge's login docs (current): "In some cases, Meta may decide your account has
  suspicious activity and block you until you do some tasks like completing a captcha,
  adding a phone number or resetting your password. It is recommended to have two-factor
  authentication enabled to reduce the risk of such blocks."
- [Issue #44](https://github.com/mautrix/meta/issues/44) (open since 2024-03, 38
  comments, Messenger and Instagram, mostly the old bridge). What users reported:
  - 2024: several saw "We suspect automated behaviour on your account" or "We've noticed
    unusual activity from your account and have temporarily restricted certain actions".
    2FA did not prevent it for some. One user in Instagram mode wrote "my account got
    banned instantly" after an update; the thread does not say whether it was permanent.
  - 2025-02: "Still the same problem quite regularly with Instagram."
  - 2025-04 (Messenger): the warning shows when the account next logs in with a browser,
    after Meta blocked the bridge's session; a new session was blocked again within 24
    hours. Another Messenger user saw `BAD_CREDENTIALS`: "Your account is disabled,
    please review your account"; the thread does not say how it ended.
  - 2025-12 (Instagram): the warning "after nearly an hour of use", with backfill off, a
    home address and 2FA on. That user stopped.
  - 2025-08 and 2026-08 (one Messenger user): a warning about once in 1 to 2 months,
    then no logout for about 3 months with the stock bridge.
- We searched the bridge's issues on 2026-10-28 for "suspend", "ban", "checkpoint",
  "challenge", "suspicious" and "logged out". No other report of a lock or ban.
- The new Instagram bridge exists only since v26.07 (July 2026), on a new Instagram
  protocol. So nearly all reports are about older code. Nobody has reported yet for the
  new one, good or bad.
- The bridge's docs list beeper.com as a public instance of the same bridge.
- The bridge acts as an unofficial client of Instagram. Meta decides what it allows.

### R2: the cloud IP address

- The server's address `192.18.154.172` is registered to Oracle Corporation (`whois`,
  net name `ORACLE-BRM4`). Instagram sees a data-center address, not a home address.
- In issue #44 (2024-07), one user wrote: "I used to host the bridge at home, but now I
  get this warning since I've started hosting it in the cloud. For me, the bridge doesn't
  work for more than a couple hours until I get this warning." Another moved the
  bridge's traffic through a proxy at home, and reported no result.
- Against that: in 2025-12 an Instagram user got the warning within an hour from a home
  address with 2FA on. So the address is one cause at most.
- The bridge has a proxy setting (`network.proxy`: HTTP or SOCKS5, or `get_proxy_from`
  for a changing proxy). A proxy through Rami's home needs a device at home that is always
  on. A paid residential proxy costs money and sends the traffic through another company.
  Both are fallbacks only, for Rami to decide if the spike fails.
- mautrix-go v0.32.0 adds `client_http`: the app runs the login requests, so the login
  comes from the phone's address. The connection after the login still comes from the
  server. Not needed for the spike (see `README.md`).

### R3: session length

- [Issue #346](https://github.com/mautrix/meta/issues/346) (2026-09, the new Instagram
  bridge, a self-hosted server): two logins ran for 3 weeks. Each had about 93 short
  disconnects and reconnected in about 1 s. Once, Meta closed the connection as
  "unauthorized". The bridge stopped and stayed down for 37 hours, until a person sent
  the same cookies again; then it worked at once.
- The pinned bridge still stops on that close: `pkg/igconnector/handlemeta.go` at
  `v0.2610.0` sets `BAD_CREDENTIALS` and returns "connection unauthorized; stop
  reconnects". So we must expect a manual relogin from time to time. The bot's message
  (`README.md`, **Disconnect alerts**) tells us when.
- The bridge makes a full reconnect at most once per hour, and a forced refresh every 20
  hours (`min_full_reconnect_interval_seconds: 3600`,
  `force_refresh_interval_seconds: 72000`).
- Issue #44, 2026-08 (Messenger, cookies pasted from a browser): Meta ended the bridge's
  session after about 7 days each time, while the browser's session stayed. That user's
  guess: the bridge's fixed browser identity (user agent) does not match the browser that
  made the cookies. Not confirmed, and not about Instagram.
- How long Instagram keeps a session valid: we found no reliable source. The spike gives
  48 hours of data; the main account then gives weeks.

### R4: encryption

- Meta's help page, as quoted by [Engadget](https://engadget.com/social-media/meta-is-killing-end-to-end-encryption-in-instagram-dms-195207421.html)
  (2026-03-13): end-to-end encrypted Instagram DMs are "no longer supported after May 8,
  2026". The feature was opt-in, per chat, and only in some areas. Meta's reason: "Very
  few people were opting in." Also reported by [Bitdefender](https://www.bitdefender.com/en-au/blog/hotforsecurity/meta-halt-instagram-end-to-end-encryption-dms)
  and [Newsweek](https://newsweek.com/meta-confirms-major-privacy-change-on-instagram-11689800).
- The bridge's changelog, v26.04: "Removed option to use encrypted chats on Instagram."
- So Meta, and the bridge, can read every Instagram DM. On our side the bridged rooms stay
  unencrypted, as for WhatsApp (`README.md`, **Encryption**).

### R5: bridge changes

- The changelog shows fixes after Meta's changes: v26.05.1 ("Fixed connecting to Instagram
  after an app ID change broke it"), v26.06 ("Fixed connecting to Instagram again"),
  v26.07 (a new Instagram bridge, because "Instagram switched to a completely new
  protocol for DMs"), v26.08.1 (Messenger).
- The playbook at `e3929968b8` pins `v0.2610.0` (released 2026-10-16). When Instagram
  breaks, the server conversation updates the playbook pin.

### Other facts that matter for safety

- **The login secret in the bot room.** The bot redacts a message with pasted cookies or a
  password at once (mautrix-go `commands/login.go`). Synapse keeps the original content of
  a redacted event for 7 days (`matrix_synapse_redaction_retention_period: 7d`, the
  playbook's default). The bot room is not encrypted: with encryption off, the bot reads
  only plain rooms.
- **The bridge database holds the session.** It is in our PostgreSQL
  (`matrix_mautrix_meta_instagram`). A backup of it is a secret.
- **Double puppeting.** On `@rami`, a read receipt from the app also marks the Instagram
  chat read, as for WhatsApp. The safety rule in `AGENTS.md` applies to Instagram too.

## 2. The spike

**Goal:** answer R1, R2 and R3 on a secondary account, before the main account is at
risk. Record the real Matrix shape of each Instagram message kind for the app.

**Before it starts:**
- Rami's yes. The server conversation runs it.
- After 2026-10-29, 23:00 UTC (the end of M0's 48 hours).
- A secondary Instagram account, with 2FA on (an authenticator app), logged in on Rami's
  phone. We assume that a new account with no history gets more checks than an old one.
  So a pass on a new account is a strong pass, and a fail on a new account is not final.

**Who holds the login:** `@test1:ramimaalouf.com`, not `@rami`. `@rami`'s chat list
stays real. Tests may send as `@test1` (the safety rule). Later automated tests can use
these rooms.

**Steps:**

1. The server conversation adds the block from section 4 to `config.yml`, then runs:
   ```sh
   ./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start
   ./server/playbook.sh --tags=self-check
   ```
   It records the result, the image's architecture, and memory before and after in
   `server/notes/install.md`.
2. Rami signs in to Element Web (`app.element.io`, server `www.ramimaalouf.com`) as
   `@test1:ramimaalouf.com`, and keeps the tab for the 48 hours. The password, to the
   clipboard:
   ```sh
   security find-generic-password -s multiplexer-test-account -a @test1:ramimaalouf.com -w | pbcopy
   ```
   At the end of the spike, sign out, so `@test1` keeps no extra session.
3. Rami starts a chat with `@instagrambot:ramimaalouf.com`, the same way as with the
   WhatsApp bot. The bot reads only unencrypted chats; the WhatsApp bot chat is
   unencrypted (checked on the server). If the bot answers that it cannot decrypt, make
   a new room with encryption off and invite the bot. Then send `login android`.
   The bot asks for the user name, then the password (it redacts the password message),
   then maybe a 2FA code, or an approval in the Instagram app on the phone. Rami answers
   each prompt. The bot then confirms, and the chats arrive.
4. Only if step 3 cannot finish (for example a captcha that the bot cannot show): send
   `cancel`, then `login instagram`. In a second private window: `instagram.com`, open
   the developer tools, Network tab, filter `graphql`. Log in to the secondary account.
   Right-click one request, then Copy > Copy as cURL. Paste it in the bot chat; the bot
   redacts it. Close that window without Log out: that would end the session that the
   bridge now uses.
5. From Rami's **main** Instagram account, on the phone, send these to the secondary
   account: a text, a photo, a voice note, a shared reel, a shared post, a reply to a
   story of the secondary account, a reaction, a reply, an edit, an unsend, a view-once
   photo, and one message in vanish mode. From `@test1` in Element Web: a text, a photo,
   a reaction, a reply, an edit and a delete.
6. Then use the secondary account as usual on the phone, and leave the bridge running.

**Why `android` first, not cookies (the documented flow):**
- It is the flow that the app would use: text fields, no web view. One test answers two
  questions.
- The session stays where it was made: same address, same client. A pasted cookie moves
  from Rami's Mac at home to the server, and from Firefox to the bridge's own client. One
  report links that mismatch to sessions that Meta ended after about 7 days (R3).
- It is new (v26.10), so it may fail. Then step 4 gives the documented path.

This is a judgment, not a measured fact. The spike records which flow worked.

**What to watch for 48 hours:**

| Where | What | Who, when |
|---|---|---|
| The secondary account's Instagram app | "Confirm it's you", "unusual activity", "automated behaviour", a captcha, a forced password reset, a logout. | Rami, morning and evening |
| Instagram's login activity (Accounts Center) | How the bridge's session shows: device and place. | Rami, once |
| The bot chat, as `@test1` | Every "State update" message. | Rami and the agent |
| The server, read only | The bridge's memory and CPU. Counts of `TRANSIENT_DISCONNECT`, `BAD_CREDENTIALS` and `UNKNOWN_ERROR` in its log (counts only, no names). | The server conversation, at hours 1, 24 and 48 |
| `@test1`'s Instagram rooms | Each test message's event: type, `msgtype`, and extra fields. Saved with no IDs or names. | The agent |

**Pass (all must be true):**
- [ ] The login works, and the chats show in Element Web within 5 minutes.
- [ ] 48 hours with no challenge, lock, warning or forced logout on the secondary account.
- [ ] No `BAD_CREDENTIALS` or `UNKNOWN_ERROR`. Each `TRANSIENT_DISCONNECT` ends by itself.
- [ ] Every kind from step 5 arrives in Matrix, and each send from `@test1` arrives in
      Instagram. The shapes are recorded in this file, in a new section "Observed".
- [ ] The bridge uses less than 300 MiB at rest. The first sync's peak load is noted.
- [ ] The flow that worked (`android` or cookies) is recorded, with each step that the
      bot asked for. This decides the app's login screen.

**Stop at once if:** the account is locked, shows "automated behaviour", or must reset
its password. Then send `list-logins` and `logout <login ID>` in the bot chat, and write
down what happened and when. Do
not connect the main account from the cloud IP. Rami then chooses: a proxy through his
home, or no Instagram for now.

**After a pass,** and only with Rami's yes:
1. Turn on 2FA on the main account, if it is off.
2. Connect it to `@rami:ramimaalouf.com`, with the flow that worked. With `android`
   through the bot, the main password stays (redacted) in Synapse's database for 7 days.
   Rami accepts that, or waits for the app's connect screen (T4.4), which sends it to
   the bridge's API directly and not into a room.
3. Watch it for 2 weeks with the same list. M4's Instagram part depends on this.
4. Then decide how many chats to bring in: `thread_backfill.batch_count` adds 5 chats per
   batch, 2 s apart (section 4).

## Observed (the spike, from 2026-10-28)

**Setup, 2026-10-28 (Rami's yes: "please proceed with the setup and let's give it a
test").** M0 was closed and Rami skipped its 48-hour wait, so the spike started at once.
- The server conversation installed the bridge (commit `d0789a3` on `server/phase-0`):
  `ok=248 changed=13 failed=0`, self-check `ok=36 failed=0`. Image
  `dock.mau.dev/mautrix/meta:ig-v0.2610.0`, arm64, pulled. Synapse and the WhatsApp
  bridge restarted once; WhatsApp kept its login. The bridge uses 9 MiB at rest. The
  daily backup includes its database with no new setting. Details:
  `server/notes/install.md`.
- `@test1` made a direct chat with `@instagrambot:ramimaalouf.com` through the API (no
  encryption). The bot joined, and answered `list-logins` with "You're not logged in".
- The bridge's API answers `@test1` with the flows `android`, `instagram` and
  `instagram-password`, when the call has `?user_id=` (see `README.md`).

**Account choice, 2026-10-28 (Rami: "let's use @rami").** Rami chose his **main**
Instagram account on `@rami:ramimaalouf.com`, not a secondary account on `@test1`. He
accepts the risk to the main account. What changes from section 2:
- Rami starts the bot chat as `@rami` and types `login android` himself. Agents never
  send, react, delete or mark read as `@rami` (the safety rule); they only read on the
  server, and only counts and event shapes, never message text.
- The test messages come from Rami and his contacts on the phone, not from `@test1`.
- The main password stays (redacted) in Synapse for 7 days; Rami may change it after the
  48 hours.
- The `@test1` bot chat made above stays unused.

**Next:** Rami logs in; then the 48 hours of watching (section 2).

## 3. Message kinds

What the pinned bridge sends to Matrix for each Instagram kind. Source: the code at
`v0.2610.0` (`pkg/msgconv/igconv/`, `pkg/msgconv/mediadl/`, `pkg/igconnector/`). Seen in
the code only; the spike confirms each one.

| Instagram | In Matrix | App priority |
|---|---|---|
| Shared reel, post or story | New messages: the bridge downloads the reel's video (or the post's or story's picture) and sends `m.video` or `m.image`. Its caption is HTML: an optional quote line (a label from Instagram), a bold title, a subtitle, the post's caption, and a link to `instagram.com`. Extra fields: `external_url`, `com.beeper.meta.full_post_title`. In the first sync (`disable_xma_backfill: true`): only the preview picture with the same caption and link, plus `com.beeper.unresolved_media`. | 1 |
| Reply to a story, story mention | Two events: the story, as in the row above, with Instagram's label as the quote line; then the reply's text as its own `m.text`. With no story media: one `m.text` with the label as a quote above the text. | 1 |
| Voice note | `m.audio` with `org.matrix.msc3245.voice` and a duration (`org.matrix.msc1767.audio`), converted to Ogg Opus. No waveform. | 2 (same as WhatsApp, T2.11) |
| Reaction | `m.reaction`. | 2 (T2.11) |
| Reply | `m.relates_to` with `m.in_reply_to`. | 2 (T2.11) |
| Unsend | A redaction of the message. | 2 (T2.11, "Message deleted") |
| Edit | `m.replace`. | 2 (T2.11, "Edited") |
| Photo, several photos | One `m.image` per photo. | Done (T2.5) |
| Video | `m.video`. | 2 (T2.11) |
| Text with a link | `m.text` with `com.beeper.linkpreviews` (title, picture). | 3 |
| GIF | `m.video` with `fi.mau.gif`, loop and autoplay flags. | 3 |
| Sticker | An `m.sticker` event (not `m.room.message`). | 3 |
| View-once photo or video | Sent as a normal photo or video while Instagram still gives it (`disable_view_once: false`). Otherwise an `m.notice`: "This image can only be viewed once. Use the Instagram app to view." | 3 (see below) |
| Group changes, calls | `m.notice`, sometimes with links. | 3: a small centered line |
| Vanish mode | No code for it in the Instagram connector (`Disappear: nil, // TODO`). Not known if these messages arrive. | Check in the spike |
| Anything else | `m.notice`: "Unsupported message. Use the Instagram app to view." | Show as is |

**What matters most:** shared reels and posts, and story replies, because they are what
Instagram DMs are about (assumption 4). Today the app would show the picture or the
video's text only, with no link. The voice notes, reactions, replies, unsend and edits
have the same Matrix shape as WhatsApp's, so T2.11 does that work once for both.

**One privacy choice for Rami:** view-once photos and videos stay in Matrix with no time
limit, which Instagram's sender does not expect. Recommendation: set `disable_view_once: true`
(section 4) when Rami's main account is connected, so they show only the notice.

## 4. Server settings

The block for `server/inventory/host_vars/matrix.ramimaalouf.com/config.yml`, for the
spike:

```yaml
# the instagram bridge (mautrix-meta's instagram bridge). a user connects by sending
# `login instagram` (cookies from a browser) or `login android` (user name and password)
# to @instagrambot:ramimaalouf.com. the image is prebuilt for arm64. instagram dms have
# no end-to-end encryption since 2026-05-08, and the bridged rooms stay unencrypted, as
# for whatsapp. the bridge's api: https://matrix.ramimaalouf.com/bridges/meta-instagram.
matrix_bridge_mautrix_meta_instagram_enabled: true
```

For the main account, after the spike, add (values to confirm from the spike):

```yaml
# the first sync brings the first inbox page only; each batch adds 5 more chats, 2 s apart.
# view-once media shows only as a notice, as instagram's sender expects.
matrix_bridge_mautrix_meta_instagram_configuration_extension_yaml: |
  network:
    disable_view_once: true
    thread_backfill:
      batch_count: 20
```

Keep the defaults for the rest: double puppeting (already on), encryption off,
permissions (any `ramimaalouf.com` user), backfill 50 messages per chat, log level `warn`,
no proxy, and the " (IG)" name suffix until the app shows a network badge. Do not use the
old `mautrix-instagram` role (deprecated) or `mx-puppet-instagram`.

Known issue with more chats: [issue #374](https://github.com/mautrix/meta/issues/374)
(open) says that chat paging stopped after page 2. The code at `v0.2610.0` now takes the
next page's cursor from each answer, so it may be fixed; the main account's first sync
shows it.

## 5. Where it fits in the plan

- **The spike: now, in parallel.** Decision rule 2 (biggest unknown first). It needs only
  the server and Rami's phone. Its result can change the server (a home proxy) and the
  app's login design (text fields or a web view), and it can remove Instagram from M4. If
  we wait until after M3, a bad result costs weeks.
- **The app's Instagram work stays in Phase 4,** after M2 and M3: the network badge, the
  shared posts and reels, and connecting in the app. T2.11 already covers the kinds that
  Instagram shares with WhatsApp.
- **Messenger: not now.** It needs its own Facebook account, its own login (the
  `messenger` cookie flow, or `messenger-lite` with a password and a captcha), and issue
  #44 began with Facebook's warnings. If Rami uses Messenger (Q6), it gets the same spike
  after Instagram's. The playbook role is `matrix-bridge-mautrix-meta-messenger` (bot
  `@messengerbot`, suffix " (FB)").
- **The badge can come earlier** if Rami wants the " (WA)" suffix gone sooner (found in
  T2.10). It is small: MatrixCore reads `m.bridge` (`README.md`).

## 6. Proposed changes to `tasks/plan.md` and `tasks/todo.md`

Not applied: two other conversations edit those files. Rami, or one of them, pastes these.

### `tasks/plan.md`

**Status, "Next task":** add

> Server: T4.1, the Instagram spike, after Rami's yes and after 2026-10-29, 23:00 UTC.

**Facts we rely on:** add after the WhatsApp bridge

> **Instagram bridge** ([playbook page](https://github.com/spantaleev/matrix-docker-ansible-deploy/blob/master/docs/configuring-playbook-bridge-mautrix-meta-instagram.md), [login](https://docs.mau.fi/bridges/go/meta/authentication.html)), checked 2026-10-28. Details: `docs/connectors/instagram.md`.
> - Role `matrix-bridge-mautrix-meta-instagram`, `v0.2610.0`, image `dock.mau.dev/mautrix/meta:ig-v0.2610.0` (arm64). Bot `@instagrambot:ramimaalouf.com`. API at `https://matrix.ramimaalouf.com/bridges/meta-instagram`.
> - Login: `login instagram` (cookies from a browser) or `login android` (user name, password, 2FA code; may ask for an approval or a captcha).
> - Instagram ended end-to-end encrypted DMs on 2026-05-08. The bridge reads every DM.
> - The bridge stops after one "unauthorized" close from Meta and waits for a new login (issue #346).
>
> **Bridged rooms:** each has an `m.bridge` state event; `protocol.id` names the network (`whatsapp`, `instagram`). 266 rooms on 2026-10-28.

**Risks:** replace the row "A network blocks logins from cloud IP addresses (not verified)" with

> | A network challenges or blocks use from a cloud IP address. Instagram: warnings reported in 2024 and 2025 (cloud servers, and once a home address); our address is Oracle's. | Medium | Spike on a secondary account (T4.1). A proxy through home if it fails. | T4.1 |

and add

> | Meta locks Rami's Instagram account for using a bridge. | High for Instagram | A secondary account first, 2FA, 48 hours; the main account only with Rami's yes. | T4.1 |
> | Meta changes Instagram and the bridge breaks (four such fixes in 2026). | Medium | Update the playbook pin. The app shows "disconnected". | Phase 4 |

**Open questions:** add

> | Q6 | Does Rami use Messenger? If yes, it gets its own spike after Instagram's. | Phase 4 |
> | Q7 | Which Instagram account for the spike: an existing secondary account, or a new one? | T4.1 |

**Decision log:** add, with Rami's answer

> | 2026-10-28 | Connector proposal (`docs/connectors/`). Rami: <yes or no> to the Instagram spike now, on <account>, connected to `@test1`. Messenger: <later or no>. |

### `tasks/todo.md`

Replace the body of "Phase 4: more networks (M4), rough" with:

> The pattern for every network: `docs/connectors/README.md`. Instagram: `docs/connectors/instagram.md`.
>
> ### T4.1 Spike: Instagram from the cloud IP, on a secondary account
>
> Runs early, in parallel with Phases 2 and 3 (decision rule 2).
>
> **Description:** Turn on the Instagram bridge. Connect a secondary Instagram account
> to `@test1` with `login android` (cookies if that cannot finish). Watch it for 48
> hours: Meta's checks, disconnects, message kinds, resource use. Details:
> `docs/connectors/instagram.md`, section 2.
>
> **Acceptance criteria:**
> - [ ] `matrix_bridge_mautrix_meta_instagram_enabled: true`; the image is arm64 and pulled; the self-check is green.
> - [ ] The secondary account is connected to `@test1`; its chats show in Element Web within 5 minutes.
> - [ ] 48 hours with no challenge, lock, warning or forced logout; no `BAD_CREDENTIALS` or `UNKNOWN_ERROR`.
> - [ ] Each test kind arrives in Matrix, and each send from `@test1` arrives in Instagram. The shapes are recorded.
> - [ ] Memory at rest and the first sync's load are recorded.
> - [ ] The flow that worked (`android` or cookies) is recorded, with each step the bot asked for.
> - [ ] Rami decides: connect the main account, use a home proxy, or stop.
>
> **Verification:**
> - [ ] Rami's notes from the Instagram app, morning and evening.
> - [ ] Counts from the bridge log at hours 1, 24 and 48 (no names).
>
> **Dependencies:** Rami's yes, Q7, the end of M0's 48 hours (2026-10-29, 23:00 UTC)
> **Files:** `server/inventory/host_vars/matrix.ramimaalouf.com/config.yml`, `server/notes/install.md`, `docs/connectors/instagram.md`
> **Scope:** S
>
> Rough, after M3:
> - T4.2 The network of each room: MatrixCore reads `m.bridge`; a badge and a filter; remove " (WA)" and " (IG)".
> - T4.3 Instagram message kinds: shared reels and posts, story replies, view-once (after T2.11).
> - T4.4 Connect a network in the app: a Connections screen, the `display_and_wait` and `user_input` steps, a "disconnected" banner. `cookies` (a WKWebView module) when a login needs it.
> - T4.5 Rami's main Instagram account, after T4.1 passes and Rami's yes: 2 weeks of watching.
> - Signal and Telegram, with the same pattern. Messenger only if Q6 says yes.

## Sources

Checked on 2026-10-28.

- The playbook at `e3929968b8`: `docs/configuring-playbook-bridge-mautrix-meta-instagram.md`,
  `docs/configuring-playbook-bridge-mautrix-bridges.md`, the roles
  `matrix-bridge-mautrix-meta-instagram` and `matrix-bridge-mautrix-meta-messenger`, and
  `group_vars/matrix_servers`.
- The bridge's login docs: <https://docs.mau.fi/bridges/go/meta/authentication.html>.
- The bridge at `v0.2610.0`: [CHANGELOG](https://github.com/mautrix/meta/blob/v0.2610.0/CHANGELOG.md),
  [ROADMAP](https://github.com/mautrix/meta/blob/v0.2610.0/ROADMAP.md), and the code in
  `pkg/igconnector/`, `pkg/instameow/` and `pkg/msgconv/`.
- The release post for the new Instagram bridge: <https://mau.fi/blog/2026-07-mautrix-release/#new-instagram-bridge>.
- mautrix-go `v0.32.0`: `bridgev2/login.go`, `bridgev2/bridgestate.go`,
  `bridgev2/commands/login.go`, and the
  [provisioning API](https://github.com/mautrix/go/blob/v0.32.0/bridgev2/matrix/provisioning.yaml).
- Issues [#44](https://github.com/mautrix/meta/issues/44),
  [#346](https://github.com/mautrix/meta/issues/346) and
  [#374](https://github.com/mautrix/meta/issues/374).
- Instagram's encryption: [Engadget](https://engadget.com/social-media/meta-is-killing-end-to-end-encryption-in-instagram-dms-195207421.html),
  [Bitdefender](https://www.bitdefender.com/en-au/blog/hotforsecurity/meta-halt-instagram-end-to-end-encryption-dms),
  [Newsweek](https://newsweek.com/meta-confirms-major-privacy-change-on-instagram-11689800).
- The live server, read only: `/.well-known/matrix/mautrix`, the 401 from
  `/bridges/whatsapp`, counts of `m.bridge` events, `free`, `docker stats`, and `whois`
  of its address.
