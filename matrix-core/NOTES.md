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

## Where the session lives

- **The Keychain** holds the session (`SessionKeychain`, one generic-password item:
  the access token, the device and the store folder's name). Readable on this device
  only, after the first unlock, so a notification extension can read it while the
  phone is locked. The app uses the service `com.ramimaalouf.multiplexer.session`;
  under Exact's agent it adds `.agent`, because the agent's data is a fresh scratch
  tree.
- **The SDK's store** (state, crypto, event cache, media) is a folder in the app's
  data: `<Exact's context.data>/matrix/<uuid>/`. A Keychain session whose folder is
  gone (a reinstall keeps the Keychain) counts as signed out, and the item moves to the
  `sign-out` slot below: a session without its crypto store has lost its encryption keys.
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
- Spaces are not chats: `rooms()` leaves them out (`isSpace()`), and the list service's
  filter is `joined` and `nonSpace`.
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
- **A new message brings a chat back** (Rami: an archived chat comes back unless it is muted;
  a deleted one comes back too). Nothing is written then: a chat is archived while it is muted or
  its newest message (`RoomSummary.lastTimestamp`: a message, a call, a poll, a sticker or our own
  join, never someone else's join or a reaction) is not newer than its mark. Unmuting an archived
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
- **Limit: another device's archive or delete** shows at the next change of the room list (a new
  message in any chat) or launch: the sdk tells no listener of a custom global account data event,
  and that change alone moves nothing in the room list. A timer reading `Client.accountData` would
  close the gap.
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
- **Mac.** The release has no macOS slice. The Mac app (M5) needs our own build of the
  bindings.
- **Swift package.** For T1.3's tests and the Expo fallback, MatrixCore also builds as a
  Swift package that depends on `MatrixRustSDK`. Its files import it behind
  `#if canImport(MatrixRustSDK)`, so the same files compile in both places.
