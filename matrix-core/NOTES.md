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
- Spaces are not chats: `rooms()` leaves them out (`isSpace()`), and the list service's
  filter is `joined` and `nonSpace`.
- `RoomSummary.avatarName` names the room's picture; `avatarFile(roomId:directory:)`
  downloads a thumbnail of at most 160 pixels a side once.

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
