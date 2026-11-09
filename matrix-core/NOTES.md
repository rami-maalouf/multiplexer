# MatrixCore: how matrix-rust-sdk links into the app

## The Exact app (iOS)

`scripts/setup-matrix-sdk.sh` does all of it. Run it after a fresh clone and after
every edit in `matrix-core/`.

1. It downloads `MatrixSDKFFI.xcframework.zip` for version `26.10.27` from
   `element-hq/matrix-rust-components-swift` and checks its SHA-256 against the
   checksum in that release's `Package.swift`.
2. It clones the release's generated Swift bindings (`Sources/MatrixRustSDK`, 9 files).
3. It copies these into `apps/multiplexer/modules/apple/`:
   - `MatrixSDKFFI.xcframework`: a static library with `ios-arm64` and `ios-arm64-simulator` slices.
   - `sdk-*.swift`: the bindings.
   - `core-*.swift`: `matrix-core/Sources/MatrixCore/*.swift`.

Exact compiles every top-level `.swift` file in `modules/apple/` into one module and
links each xcframework slice with `-I`, `-L` and `-l` (`host/apple/build.mjs`,
`frameworkSlice`). The bindings import `MatrixSDKFFI` behind `#if canImport`, and the
compiler finds its module map in the slice's `Headers/MatrixSDKFFI/`.

- **Copies, not symlinks.** Exact refuses symlinks in the app folder
  (`source links are not captured`). The script makes APFS clones (`cp -c`), which use
  no extra disk space.
- **Not in git.** `.gitignore` lists the copies and `vendor/`.
- **Deployment target.** `app.json` sets iOS 17.0. The SDK needs iOS 16.
- **Linker flags.** None were needed.
- **The boundary.** All files compile into one module, so the rule "only MatrixCore
  calls the SDK" is a convention here. `Matrix.swift` (the native module) calls only
  `MatrixCore`.

## Native macOS package tests

The released SDK package has only iOS slices. Native Mac tests explicitly select
the local combined SDK instead; evaluating the manifest on a Mac alone does not
change the default iOS dependency or its test target.

After the existing SDK setup and macOS build scripts have produced
`vendor/matrix-sdk/26.10.27/combined/MatrixSDKFFI.xcframework`, run from the repo root:

```sh
scripts/mx-lock.sh matrixcore mac-core -- scripts/test-matrix-core-macos.sh
```

The runner stages `MacTestSupport/Package.swift`, the released generated Swift
bindings, and the combined XCFramework under `.build/macos-sdk` using local copies.
It sets `MATRIX_CORE_MACOS=1` to select that package, keeps Mac build products under
`.build/macos`, preserves `Package.resolved`, and limits compilation to two jobs.
It does not update the app's native-module copies. No production source changed,
so this test setup does not require rerunning the app copy script.

All production MatrixCore sources compile for macOS 14 or newer on Apple silicon.
`MatrixCoreMacTests` calls the linked SDK to check its pinned commit and reuses the
existing session-store, room-kind, and formatted-text XCTest files through relative
symlinks. These 27 tests need no credentials, homeserver, or Simulator. Additional
Swift test arguments such as `--filter SDKLinkTests` pass through the runner.

This is an auth-free Mac test target, not the network/media suite: the existing
`MatrixCoreTests` target and `scripts/test-matrix-core.sh` retain the pinned remote
SDK and iOS path. The UIKit media fixtures and authenticated network tests have not
been ported or run on Mac by this setup.

## Where the session lives

- **The Keychain** holds the session (`SessionKeychain`, one generic-password item:
  the access token, the device and the store folder's name). Readable on this device
  only, after the first unlock, so a notification extension can read it while the
  phone is locked. The app uses the service `com.ramimaalouf.multiplexer.session`;
  under Exact's agent it adds `.agent`, because the agent's data is a fresh scratch
  tree.
- **The SDK's store** (state, crypto, event cache, media, search) is
  `<App Group container>/matrix/<uuid>/` when the group is available, otherwise
  `<Exact's context.data>/matrix/<uuid>/`. `StoredSession.storeLocation` names `group` or
  `data`; an omitted location is legacy `data`. Existing stores move before the sdk opens
  them (see "The App Group store move"). A confirmed missing store counts as signed out,
  and the item moves to the `sign-out` slot below. An unavailable group keeps its session:
  lack of an entitlement does not prove the crypto store is gone.
- **A session the server must still forget** waits in a second Keychain item (slot
  `sign-out`): a session whose store is gone, or one whose Sign Out could not reach the
  server. The module signs it out with `MatrixAccount.signOutOnServer` (a scratch store,
  deleted after) in the background, and tries again at the next launch if the server
  could not be reached.
- **Sign-in errors** are `SignInError` (`wrongPassword`, `serverNotFound`,
  `serverNotSupported`, `rateLimited`, `other`). Seen on matrix.org: an unknown user
  gives `M_FORBIDDEN`, as a wrong password does; a `.invalid` server gives
  `serverNotFound`.
- **The package's tests cannot use the Keychain.** A Swift package test has no host
  app, so `SecItem` calls fail with `-34018` (`errSecMissingEntitlement`). The app's
  relaunch check covers the Keychain.

## Live updates

- `MatrixAccount.onChange` reports `MatrixChange.rooms` (from the room list service's
  entries listener, which needs `setFilter(kind: .joined)` before it reports) and
  `MatrixChange.room(id)` (from an open chat's timeline listener).
- Opening a chat also loads its members in the background (`fetchMembers`); until then a
  sender shows as their id.
- The first `messages(roomId:)` opens a live timeline and pages back to the last `limit`
  messages. It stays open; later calls read it, from the first message shown at open to
  the newest. Timelines close at sign-out.
- `loadOlder(roomId:count:)` shows `count` older messages: those the timeline holds,
  then paged back from the server. `isAtStart(roomId:)` is true once the chat shows the
  room's first message.
- The module merges the changes of 0.2 s into one `context.changed` for each topic
  (`rooms`, `thread:<room id>`).

## Sending

- `send` puts the message in the room's send queue (the open chat's live timeline) and
  returns at once; `Message.sendState` goes `sending`, then `sent` or `failed`. A message
  keeps its id (the timeline item's unique id) from sending to sent.
- **An id can change under the caller.** The sdk can replace a timeline item under a new id while
  it holds the same event (seen 2026-11-04: a message's id went from 40 to 47 within a minute of a
  test; most likely its event cache dropping a duplicate and inserting the event anew). An action
  with an id the caller read before still means that message: `TimelineItems` remembers each id's
  event, and a lookup that finds no item with the id finds the one that holds its event. Before,
  a reaction then did nothing and said nothing; a message truly gone now throws
  `MatrixCoreError.noMessage`.
- A failure the sdk can recover from (no network) stops the room's send queue; `retry`
  starts it again and also retries a message the server refused (`retrySend`).
- The sdk keeps a refused message in its queue, across launches, until it is sent or
  discarded. `discard` cancels it (`redactEvent` on its transaction id); it never touches
  a sent message.
- `sendAndWait` returns once the server has the message, for tests and scripts.

## Photos

- A photo message has `Message.image` (its size, and stable file names from a hash of
  its media url); `body` is its caption, or "".
- `imageFile(roomId:messageId:full:directory:)` downloads the thumbnail (at most 800
  pixels a side, or the picture when the server has no thumbnail) or the full picture
  once, through the signed-in client (matrix.org serves media only to signed-in
  requests), and returns the file.
- The module keeps them in `<Exact's context.cache>/matrix-media/`, which the view shows
  as `app:/cache/matrix-media/<name>`, and deletes them at sign-out.

## Sending photos and files

- `sendAttachment(roomId:attachment:caption:replyTo:)` puts a photo (`m.image`, with its size
  and an optional thumbnail the app made) or a file (`m.file`) in the room's send queue
  (`Timeline.sendAttachment`) and returns once the queue holds it. The other clients see the
  file's own name (its last path component).
- A message on its way has `uploadProgress` (0 to 1, the file and its thumbnail together):
  the account turns on `enableSendQueueUploadProgress`, and the timeline's local echo carries
  it (`EventSendState.notSentYet(progress:)`).
- A photo's thumbnail is the sender's own when it has one (`info.thumbnailSource`): for a photo
  this device sends, the send queue's cache has it at once, before and after the upload.
- A file over the server's limit (`maxUploadSize()`, 50 MB on our server) is refused by the
  sdk before any byte goes (`genericApiError`, "The provided media is too large to upload",
  not recoverable): the message shows as failed, and the room's queue goes on.
- `fileContent(roomId:messageId:directory:)` downloads a file message's file once, under the
  name its sender gave it, in a folder of its own.

## Encryption

- The sdk encrypts and decrypts by itself. A message this device has no key for is a
  `Message` with `waitingForKey` (body ""), not dropped; it turns into the message when the
  key comes.
- `recoveryStatus()` says whether the account keeps its keys in a backup that a recovery
  key opens. The practice account has none (`disabled`, 2026-10-27).
- `createRoom(name:encrypted:)` makes an encrypted room ("Multiplexer encrypted test" for
  the tests).

## The chat list

- `rooms()` returns the joined rooms in the room list service's order (the server's
  recency ranking, kept from the entries listener's diffs); a room it has not ranked yet
  comes after, in the client's order.
- `RoomSummary.unreadCount` is the sdk's `numUnreadMessages`; `markRead(roomId:)` sends a
  read receipt for the room's newest message.
- Spaces are not chats: `rooms()` leaves them out (`isSpace()`). The list service watches
  joined rooms and invites, including spaces, so a space's permissions or children can refresh
  the filter sheet even when no chat message arrives.
- `RoomSummary.avatarName` names the room's picture; `avatarFile(roomId:directory:)`
  downloads a thumbnail of at most 160 pixels a side once.

## A chat's network

`RoomSummary.network` is `whatsapp`, `instagram`, `messenger`, `telegram`, `signal`,
`discord` or `linkedin`, or `matrix` when no bridge serves the room (`RoomNetwork.swift`).

- **The sdk cannot read `m.bridge`.** A mautrix bridge puts `m.bridge` and
  `uk.half-shot.bridge` in each room it makes (mautrix-go `bridgev2/portal.go`,
  `CreateMatrixRoom`; the content is `event.BridgeEventContent`, and `protocol.id` is the
  bridge's `BeeperBridgeType`). `Room.stateEvents` reads only the local store, and the room
  list's sliding sync asks for a fixed list of state types (`DEFAULT_REQUIRED_STATE` in
  matrix-sdk-ui, `room_list_service/mod.rs`). The bindings cannot add a type to it.
- **The spike (2026-11-02, `@test1` on our server):** the server returned the room's
  `m.bridge` (HTTP 200, with its content). `stateEvents` returned 0 events for `m.bridge` and
  `uk.half-shot.bridge`: on a new device, on the device that set them, and after the chat was
  opened.
- **What works: the bridge's bot.** The same bridges also put
  `io.element.functional_members` in each room (MSC4171; `service_members` holds the bridge
  bot). The sync asks for that type (`MemberHints`), so on a new device
  `RoomInfo.serviceMembers` holds the bot (`@whatsappbot:<server>`). Its localpart
  `<word>bot` names the network.
- **The fallback: the room's heroes.** For a bridge that sets no service members
  (mautrix-discord is not on bridgev2): a hero on this account's server whose localpart is
  `<word>bot` or starts with `<word>_` (a ghost, `@discord_123:<server>`). Synapse sends heroes
  only for a room with no name, so this covers one-to-one chats and the chat with a bridge's
  bot.
- **The words** are the playbook's default bot and ghost names: `whatsapp`, `instagram`,
  `messenger` (also `facebook`), `telegram`, `signal`, `discord`, `linkedin`. A server that
  gives its bridges other names shows `matrix`.
- **Limit:** a room with no service members and a name (a group of a bridge that is not on
  bridgev2) shows `matrix`. Reading `m.bridge` through the API
  (`GET /rooms/{id}/state/m.bridge/{key}`) would cover it, at one request for each room. Not
  done.
- For reference, the `protocol.id` of each bridge (from its source, 2026-11-02): `whatsapp`,
  `instagramgo`, `facebookgo` (Messenger), `telegram`, `signal`, `discordgo`, `linkedin`.
- The test: `RoomNetworkTests` (a room of its own, "Multiplexer network test").

## A chat's kind: one person or a group

`RoomSummary.isOneToOne` (the DMs and Groups filters, the info page, a notification's title) uses
one rule (`RoomKinds.swift`, `RoomSummary.isOneToOne`). `people` are the members but the
service members.

- More than 2 people: a group. Marked direct (`m.direct`) with at most 2: one person.
- A bridged room (it has service members) not marked direct, with at most 2 people, is what its
  bridge says: `com.beeper.room_type` (or `.v2`) in its `m.bridge` or `uk.half-shot.bridge` state.
  `dm` is one person; any other value, or none, is a group (bridgev2 writes no room type for a
  group). With no bridge state at all, the count decides: one person.
- The sync does not bring `m.bridge` (above), so `GET /rooms/{id}/state` asks for it, once per room
  (the state of a room of at most two people is small). The answer is kept in the store folder
  (`room-kinds.json`), so the next launch and the notification extension have it.
- Measured on a real account (2026-11-07, read only): 349 rooms, 340 bridged. Every bridged chat
  with one person (251) is in `m.direct` with room type `dm`; no bridged group is. The bridge's bot
  had joined all 340. So `m.direct` decides nearly every room, and only a few rooms are asked.
- The info page's count leaves out a service member only when it has joined, as the members'
  list does: a room may name a bot that is not a member.

## A chat's actions

The long-press menu's actions (`ChatActions.swift`), how each is kept on the server, and what
reaches the chat's network. The bridge sees only room events and read receipts: Synapse
(1.164.0, `synapse/appservice/api.py`, `push_bulk`) sends an appservice room events, ephemeral
events (receipts, typing), to-device messages and key counts, never account data. mautrix-go's
bridgev2 (v0.32.0, under mautrix-whatsapp v0.2610.0) can turn `m.tag` into a WhatsApp pin,
`m.marked_unread` into WhatsApp's unread mark and `com.beeper.mute` into a WhatsApp mute
(`pkg/connector/handlematrix.go`), but only on a server that sends it account data (Beeper's).

| Action | Kept as | Reaches WhatsApp |
|---|---|---|
| Mark as Unread | `m.marked_unread` (`Room.setUnreadFlag`); `markRead` clears it, which the sdk's read receipt does not | no |
| Mark as Read | a read receipt (`markRead`) | yes: the chat turns read there (double puppeting) |
| Mute | push rules: the sdk's room mute (an override rule with no actions), and a rule of ours before it that highlights a mention without a notification | no |
| Low Priority | `m.lowpriority` (`Room.setIsLowPriority`); the sdk removes `m.favourite`, so a pinned chat unpins | no |
| Archive, Delete | our own global account data, `com.ramimaalouf.multiplexer.chats` | no |

- **Muted.** `RoomSummary.isMuted` is the sdk's user-defined mode `mute` or
  `mentionsAndKeywordsOnly`, read from one `NotificationSettings` per account (its push rules come
  from the store, the sync and its own writes keep them current, and its delegate tells the list of
  another device's change). Not `RoomInfo.cachedUserDefinedNotificationMode`: the sliding sync sets
  it only when `m.push_rules` comes in a response, and it is not kept across launches, so after a
  relaunch every chat read as not muted (seen 2026-11-02 in a drive; a new device, as the tests
  had, does not show it). A bridge mutes a chat muted on its network with a room rule with no
  actions (bridgev2 `ASIntent.MuteRoom`), which the sdk calls mentions only. Unmute removes the
  room's own rules (`restoreDefaultRoomNotificationMode`), or sets all messages when the account's
  default is mute.
- **The "@" of a muted chat.** A muted room's override rule matches every event before the
  server's mention rules, so a mention there counts nothing. Mute adds an override rule
  `com.ramimaalouf.multiplexer.mention.<room id>` (`event_property_contains`
  `content.m\.mentions.user_ids` = this user, in this room) with only `highlight`: the sdk counts
  a highlight as a mention without a notify (`numUnreadMentions`), and a push gateway pushes only
  `notify`. It has a `room_id` condition, so the sdk counts it among the room's rules and Unmute
  removes it. Mentions by display name only, and `@room`, do not count in a muted chat.
- **Archive and Delete.** The sdk cannot read a custom room tag (`u.archive`) as it is now:
  `Client.observeRoomAccountDataEvent` reports only the events of later syncs (`observe_room_events`
  in `bindings/matrix-sdk-ffi/src/client.rs`), and `RoomInfo` keeps only `m.favourite` and
  `m.lowpriority`. Tags would need one request per chat at each launch. One global account data
  event instead: the sdk writes it (`Client.setAccountData`) and reads it from its store
  (`Client.accountData`), which the sync fills. Its content: `{"archived": {"<room id>": {"ts":
  <ms>}}, "hidden": {...}, "cleared": {...}}`, `ts` being the time of the chat's newest message
  when it was marked. Other keys (a later version's labels) are kept as they are.
- **A new message brings a chat back** (Rami: an archived chat comes back unless it is muted,
  and our own message brings it back even then (2026-11-03); a deleted one comes back too).
  Nothing is written then: a chat is archived while its newest message (`RoomSummary.lastTimestamp`: a message, a call, a poll, a sticker or our own
  join, never someone else's join or a reaction) is not newer than its mark, or while it is muted
  and that message is someone else's. When our own message brings a muted chat back, the list
  drops its mark at once (`fillChatStates`), so the answer that follows does not archive it
  again. Unmuting an archived
  chat moves its mark to its newest message, so the messages that came while it was muted do not
  bring it back. A change of the marks drops the marks of chats that came back.
- **Delete does not leave the room.** bridgev2 drops our own leave unless `bridge_matrix_leave`
  is on (the playbook writes `false` for the WhatsApp and Instagram bridges); with it on, mautrix-
  whatsapp's `HandleMatrixMembership` leaves the WhatsApp group (`UpdateGroupParticipants`,
  remove). A deleted chat stays joined and keeps its history on the server. When it comes back it
  shows only the messages after the delete (Rami, 2026-11-03): Delete also writes the chat's
  `cleared` time, which stays after the chat comes back. The chat's timeline leaves out messages
  up to it (`TimelineItems.since`), stops paging back there and counts as at its start; the info
  page's photos and videos leave them out too. A delete on another device cuts at the next load.
- **Shown at once.** Each action shows in the list before the server confirms it (`ChatStates`,
  as `Pins` does for a pin); an answer the server never confirms is dropped after 30 s. Changes of
  the marks go one at a time from the newest content this device knows.
- **Another device's archive or delete** reaches the list through the account's data watch
  (`AccountDataWatch`, `ListFreshness.swift`): the sdk tells no listener of a custom global
  account data event, so the watch reads the store every 2 s while the account syncs, and says
  which types changed.
- **The lists.** Each chat is in one `ChatList`: the inbox, the Archive or Low Priority (an
  archived chat in Low Priority is in the Archive), or none when deleted (`RoomSummary.list`).
  `inbox(filter:list:network:)` shows one list, narrowed by the filter menu's choice and the
  filter sheet's network, so they combine: the Archive on WhatsApp, Unread in Low Priority. The
  pinned grid shows the inbox's pinned chats only.
- **The sheet's counts.** Each list's and each network's rows count the chats that show an
  unread mark in the accent (`isLoudlyUnread`: unread and not muted, or a mention), so a muted
  chat's grey count does not count. A network's row counts its chats in the inbox, whatever the
  list shown; the Archive's and Low Priority's rows count every network.
- The tests: `ChatActionsTests` (rooms "Multiplexer hold test", "... archive", "... delete", and
  "... WhatsApp", whose bridge bot is a service member and is not invited).

## Search

Search across chats (`Search.swift`, B18): chats by name, then messages, then links. The server
takes no part: matrix-rust-sdk keeps a message index on the device.

- **How the index is built.** `ClientBuilder.withSearchIndexStore(path:key:)` turns it on when
  the client is built (sign-in and restore). From then on the sdk indexes every message the event
  cache gets: from sync, from paging back, and, once per store, the events it already held
  (`reindexed-v1`). Its backfill (`Client.runSearchBackfill(strategy: .foreground)`, started with
  the sync; it needs `enableAutomaticBackPagination`) pages every joined chat back a week at a
  time, the newest week of every chat first, to 13 weeks (about 3 months), at the foreground's
  pace: one chat introduced a second, behind the sdk's other paging. It starts again at each
  launch; pages the cache already holds cost no request.
- **Where it lives.** `<store>/search/<room id>/`, one tantivy index per chat, beside the sdk's
  `data` and `cache` folders, so Sign Out removes it with the store.
- **Its key.** 32 random bytes as hex (`SearchIndex.newKey`), made at sign-in and kept only in
  the Keychain with the session (`StoredSession.searchKey`, this device only, after first
  unlock). A session kept before B18 gets a key at its next launch, and its index starts empty
  (the sdk makes the index again when the key does not open it). On disk the index is not
  readable (its `meta.json` is binary). The sdk's own stores (the event cache, which holds the
  same messages) are not encrypted: we pass them no passphrase.
- **What it holds.** Per message: its event id, body, time and sender. A photo's, video's, voice
  note's or file's body is its file name and caption. Edits replace the old text; a deletion
  removes it. Encrypted messages are indexed once this device can decrypt them.
- **What a query matches.** Whole words, every word (`+word`), newest first. The sdk's tantivy
  0.27 refuses a one-word prefix (`"wor"*` needs two terms) and has regexes off, so the start
  of a word finds nothing until the word is whole; the app says so when nothing is found.
  Case does not count; accents do (`café` is not `cafe`). Chat names are matched here, not by
  the sdk: every word anywhere in the name, case and accents aside, the name's start first
  (`chatsNamed`); the sdk's `.fuzzyMatchRoomName` filter lives on the one shared room list
  (RoomFilters.swift says why we filter ourselves).
- **Links** are messages whose text has `http://`, `https://` or `www.` (as the chat makes them
  tappable). While typing, a message goes under Links when one of its links has one of the words.
- **Kinds** (Images, Videos, Files) go by words in the file name: `image`, `jpg`, `png`, ...;
  `video`, `mp4`, `mov`, ...; `pdf`, `docx`, `zip`, ... (`SearchKind.indexWords`); the results are
  then kept by their message type. A file whose name has none of these words is not under its
  kind. The bridges name media `image.jpg`, `video.mp4` (mautrix-whatsapp `wa-media.go`).
- **Opening a found message** pages the chat's live timeline back until it holds the event (at
  most 1000 events, from the cache first), then shows from 5 messages before it, so the chat
  stays live: new messages come and sending works. Further back, the chat opens at its newest
  messages and says so. `TimelineFocus.event` would reach any message in one request, but its
  timeline is not live (no new messages, no send) and the chat would have to switch timelines.
- **One room's search** (B19): `search(_:in:)` and `search(kind:_:in:)` keep one chat's results.
  The sdk's per-room search is not in the bindings, so this pages through every chat's results.
- **Numbers, `@test1` (29 chats, simulator).** Index 0.3 to 0.9 MB for 28 chats, event cache 2 to
  6 MB; the backfill was still running after 63 s of a launch. A search of words answers in 5 to
  25 ms, a kind (up to 15 pages) in 16 to 92 ms. The app logs the index's size and the backfill's
  state each minute (`matrix: search index …`) and each search's time (`matrix: search answered …`).
- The tests: `SearchTests` (rooms "Multiplexer search test" and "... history", the second with 40
  numbered messages from its first run).

## Push (Phase 3)

`Push.swift`. What a push shows, and the pusher that makes the server send it.

- **The extension's read.** `MatrixPush.content(session:storeDirectory:roomId:eventId:)` builds
  a client as a notification extension must: `systemIsMemoryConstrained()` (no event cache, no
  latest events, no search index), the store's cross-process lock held as `notifications`, only
  the pushed room loaded (`restoreSessionWith(..., .one(roomId:))`), then
  `notificationClient(.multipleProcesses).getNotification`. It returns a `PushContent` (plain
  types) or nil when there is nothing to show (the event is gone, deleted, or filtered out by the
  push rules). The body uses the chat list's words ("Photo", "Voice message").
- **One store, two processes.** The app's client takes the same lock as `app`. With a
  multi-process lock the sdk refuses to build a client without session delegates ("missing
  session delegates with multi-process lock configuration"): `SessionStorage` is ours, a load and
  a save, so a token one process refreshes reaches the other. The app and the extension back it
  with the session's Keychain item; tests keep it in memory (`.memory()`).
- **A chat's kind in a push.** `PushContent.isDirect` follows the chat list's rule
  (`isOneToOne`: at most two people besides a bridge's bot, and marked direct or bridged); the
  network comes from the room's service members and the sender, as `RoomNetwork` does.
- **Pushers.** `setPusher(_:)` (an http pusher, `event_id_only`, `append: false`),
  `deletePusher(appId:pushkey:)` (none to delete is no error), and `pushers()` (`GET
  /_matrix/client/v3/pushers`; the bindings cannot list them). `Pusher.apnsPayload` is the
  default payload: "New message" with `mutable-content`, so the extension wakes, and that text
  shows when it cannot read the message. Our server accepts a pusher without a gateway running
  (checked 2026-11-03 with `sygnal.ramimaalouf.com`, which has no DNS record yet).
- **Measured** (`testAPushShowsTheSenderAndTheText`, `@test1` and `@test2` on our server, the
  Simulator): see the decision log in `tasks/plan.md`. Peak memory needs the phone.

- **What notifies** is the server's decision, from the account's push rules: Synapse lists the
  events whose actions notify at `GET /_matrix/client/v3/notifications`, the same ones it sends to
  the push gateway. `PushRulesTests` (2026-11-04): in a normal chat a message and a mention notify;
  in a chat a bridge muted (a room rule with no actions, mautrix-go `ASIntent.MuteRoom`) only the
  mention; in a chat muted here (`mute`: an override with no actions, and our mention rule with only
  a highlight) neither, while the mention still counts in `unreadMentions`. An encrypted room's
  mention is invisible to the server, so there it cannot notify on its own.

### The Simulator and push (iOS 26.5, Xcode at 2026-11-03)

- `xcrun simctl push` (and a dropped `.apns` file) adds the notification through
  `CoreSimulatorBridge` directly: **no service extension runs**, `mutable-content` or not, with
  or without `aps-environment`. It shows the payload's own alert.
- The Simulator gets a real APNs **sandbox** token once the app's entitlements have
  `aps-environment` (without it: "no valid aps-environment entitlement string found"). So a
  real push from `scripts/send-test-push.sh` (with P3.0's key) is the way to run the extension on
  the Simulator.
- The Simulator reads an app's entitlements from its binary's `__TEXT,__entitlements` section,
  not from the signature. `segedit -replace` refuses it ("requires relocation");
  `scripts/add-notification-extension.sh` writes a compact plist in place, padded to the
  section's size (432 of Exact's 462 bytes for this app), then signs ad hoc.
- `simctl privacy` cannot grant notifications: the app asks (`@exact/notifications`), and a
  person or `agent-device alert accept` answers.

### The App Group store move

The implementation is ready, but activation and device proof still require the App Group
`group.com.ramimaalouf.multiplexer` and profiles that grant it. No Apple setup is performed by
this change. `SessionStore` resolves the location before the app builds an sdk client:

1. Legacy sessions decode with no `storeLocation`, which means `data`. A new session chooses
   `group` only when `containerURL(forSecurityApplicationGroupIdentifier:)` answers; otherwise
   it chooses `data`.
2. If the location is `data` and the container answers, move the complete
   `<context.data>/matrix/<store>` to `MatrixPush.sharedStore(in:store:)` with one `moveItem`
   (a rename on the same volume), then persist `group`. The crypto store, event cache, nested
   search index and its existing Keychain key are retained. No password or new device is needed.
3. If the process stops after the move, or the metadata write fails, the old session still
   names the same store UUID. On retry, a missing source with that destination present finishes
   the metadata write before opening the sdk. Both paths present is a conflict: neither is
   overwritten or deleted. Filesystem errors propagate instead of becoming "store gone".
4. `SessionKeychain.write` updates an existing item with `SecItemUpdate`, adding only when no
   item exists. It never deletes the old session before a write, so a failed metadata update
   leaves enough information to recover the moved crypto store.
5. A `group` session without its container is **unavailable, not gone**. A legacy session whose
   data folder is missing while the container is unavailable is also unavailable: it may be an
   interrupted migration. Neither queues server sign-out or changes the Keychain. The app shows
   signed out for that launch and refuses replacement sign-in or Sign Out until the store is
   available. With the group available, neither source nor destination present confirms a
   missing store and uses the existing pending server sign-out flow.
6. `.agent` sessions use only Exact's scratch data, even if a group container is supplied.
   They never migrate or recover from the shared store. A missing scratch store is genuinely
   missing; a group-marked agent session is unavailable and never opens the group.
7. Sign Out removes only the resolved session directory, in either location. Sign-in failure
   removes only its new UUID directory. Neither deletes the shared `matrix` root or other stores.

The extension opens only a session whose persisted location is `group`, at
`<container>/matrix/<store>`; before publication it shows "New message" and logs `storeNotShared`.

Local proof: `SessionStoreTests` exercises real temporary directories, legacy decoding, nested
crypto/cache/search preservation, unchanged session metadata, interrupted-move retries,
metadata-write failure, unavailable versus missing stores, conflicts, and agent isolation.
An isolated macOS Keychain fixture kept the same creation date across updates; the old
delete-before-add implementation changed it. The iOS test-user drive restores the same session
on relaunch and Sign Out removes just its active scratch directory, preserving a sibling fixture
and another store. This is not proof of an entitled App Group migration, extension delivery,
locked-phone decryption, or phone memory/time limits; those device gates remain open.

## Bookmarks

A held message's Bookmark (`Bookmarks.swift`). Matrix has no bookmarks, and the sdk cannot write
custom room account data, so they are one global account data event,
`com.ramimaalouf.multiplexer.bookmarks`, as the names only you see are (`ChatInfo.swift`):
`{"bookmarks": [{"room", "event", "sender", "senderName", "body", "kind", "fileName", "ts",
"savedAt"}]}`, the last saved first. Other keys are kept as they are.

- **No one else sees them, and no network does.** Account data goes to the account's own
  devices only. Synapse sends a bridge room events, ephemeral events (receipts, typing),
  to-device messages, key counts and device list changes, never account data (checked on our
  server, Synapse 1.164.0, `synapse/appservice/api.py` `push_bulk`, 2026-11-03).
  `BookmarksTests` checks that the other person gets no bookmark and no event in the chat.
- **What a bookmark keeps.** The chat, the event (the chat opens at it with `showMessage`), the
  sender and their name, the text (at most 500 characters; a photo's, video's or file's caption),
  what it is (text, image, video, voice, audio, file, sticker), a file's name, and when it was
  sent. So the list shows without opening any chat. A later edit or delete of the message does
  not change the copy. A message on its way has no event yet and cannot be saved
  (`MatrixCoreError.notBookmarkable`). `Message.eventId` says which messages of a chat are saved.
- **Shown at once.** A change shows before the server confirms it (`BookmarkStates`, 30 s), and
  changes go one at a time from the newest list this device knows, so two in a row both stay.
- **A new device's store has no account data at first**, not even after the first sync (seen
  2026-11-03: `Client.accountData` answered nil after `startSync`, and the event came some seconds
  later). A list read then was empty, and a change made from it would have replaced every
  bookmark on the server. So while the store has no bookmarks event, MatrixCore reads it from the
  server (`GET /user/{userId}/account_data/{type}`, kept 30 s); if that read fails, a change
  throws instead of writing (`testANewDeviceKeepsTheBookmarksSavedBefore`). The bookmark calls start
  the sync first, as `rooms()` does: on a new device, a store read before the first sync made that
  sync time out (three runs of three; none with the sync started first). Every change of the
  account's own data starts the same way (`AccountData.swift`, `accountDataForChange`): the
  names (`com.ramimaalouf.multiplexer.names`), the archive and delete marks (`.chats`), the
  reminders (`.reminders`), the frequent emojis (`io.element.recent_emoji`) and the bookmarks
  (`testANewDeviceKeepsTheAccountDataSavedBefore`, 2026-11-03).
- **Another device's bookmark** reaches this one's store with the sync, and the sdk tells no
  listener of a custom global account data event. The account's data watch (`AccountDataWatch`,
  which reads the store every 2 s while the account syncs) tells the list (`MatrixChange.bookmarks`;
  `testAnotherDevicesBookmarkShowsWithinSeconds`).
- **Size.** Each bookmark is about 0.5 KB, and the whole event goes to every device at each
  change. A few hundred bookmarks are fine; thousands would want a cap or one event per chat.

## Proof (2026-10-27)

- The iPhone 17 Pro Simulator shows `14a0ada4fc`, which `sdkGitSha()` returned. The
  release's commit message names matrix-rust-sdk `14a0ada4fcb3…`.
- `bun exact.mjs test ios`: 1 passed, 0 failed.
- Build time: 49 s in total, of which 41.7 s compiles the module Swift.
- Size: the Simulator debug app is 109 MB; `libexact_modules.dylib` is 69 MB of it.

## Known costs and open questions

- **Rebuild time.** An edit to any module Swift file recompiles the 2 MB of bindings
  (about 40 s). If this slows T1.3 and later, build the bindings and MatrixCore into one
  prebuilt xcframework, so the app module compiles only `Matrix.swift`.
- **Device build.** Not tried yet. It needs signing (Q4). The `ios-arm64` slice exists.
- **Mac.** The release has no macOS slice. `scripts/build-matrix-sdk-macos.sh`
  builds the pinned native slice; setup combines it with the released iOS slices.
  Native package tests use that combined framework as described above.
- **Swift package.** For T1.3's tests and the Expo fallback, MatrixCore also builds as a
  Swift package that depends on `MatrixRustSDK`. Its files import it behind
  `#if canImport(MatrixRustSDK)`, so the same files compile in both places.
