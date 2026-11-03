import CryptoKit
import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// One signed-in Matrix account and its local store.
public final class MatrixAccount: @unchecked Sendable {
    let client: Client
    /// The pins this device knows (Pinned.swift).
    let pins = Pins()
    /// The chat actions this device asked for and the server has not confirmed (ChatActions.swift).
    let chats = ChatStates()
    /// The emojis this device counted and the server has not confirmed (MessageActions.swift).
    let emojiUses = EmojiUseStates()
    /// The message search index's backfill and the found pictures (Search.swift).
    let search = SearchState()
    /// The chats' media timelines and own names (ChatInfo.swift).
    let infoStates = ChatInfoStates()
    /// The bookmarks this device wrote and the server has not confirmed (Bookmarks.swift).
    let bookmarkStates = BookmarkStates()
    let reminderStates = ReminderStates()
    /// The newest message each chat's preview showed, and the watch on other devices' archives,
    /// deletes and names (ListFreshness.swift).
    let latest: LatestMessages
    let accountDataWatch = AccountDataWatch()
    private var syncService: SyncService?
    /// The sync's start, shared: callers at launch (the list, Send Later, Bookmarks) ask at once,
    /// and a second sync service with its own room list crashed the sdk.
    private var syncStart: Task<Void, Error>?
    private let lock = NSLock()
    private var changeHandler: (@Sendable (MatrixChange) -> Void)?
    /// The room list's listener, kept so that it keeps listening, and the rooms in its order.
    private var roomEntries: RoomListEntriesWithDynamicAdaptersResult?
    private var roomOrder: RoomEntries?
    /// One live timeline for each chat that was opened, so a chat opened again does not page back.
    private var timelines: [String: Task<LiveTimeline, Error>] = [:]
    /// The open chats' timelines once they are ready, which `rooms()` reads without waiting.
    private var readyTimelines: [String: LiveTimeline] = [:]

    private init(client: Client, storeDirectory: URL) {
        self.client = client
        latest = LatestMessages(file: storeDirectory.appendingPathComponent("latest-messages.json"))
        // a photo or file on its way tells how much of it is uploaded (`Message.uploadProgress`).
        client.enableSendQueueUploadProgress(enable: true)
    }

    /// Signs in with a user name and password. `homeserver` is a server name
    /// (`matrix.org`) or a URL; the store lives in `storeDirectory`, with the message search
    /// index, encrypted with `searchIndexKey` (`SearchIndex.newKey`; nil: not encrypted). Throws
    /// a `SignInError`.
    public static func signIn(homeserver: String, user: String, password: String, deviceName: String, storeDirectory: URL,
                              searchIndexKey: String? = nil) async throws -> MatrixAccount {
        do {
            let client = try await builder(storeDirectory, searchIndexKey: searchIndexKey).serverNameOrHomeserverUrl(serverNameOrUrl: homeserver).build()
            try await client.login(username: user, password: password, initialDeviceName: deviceName, deviceId: nil)
            return MatrixAccount(client: client, storeDirectory: storeDirectory)
        } catch {
            throw SignInError(error)
        }
    }

    /// Signs in again with a session that `savedSession()` returned, and the search index's key
    /// it signed in with (another key starts the index again, empty).
    public static func restore(_ saved: SavedSession, storeDirectory: URL, searchIndexKey: String? = nil) async throws -> MatrixAccount {
        let client = try await builder(storeDirectory, searchIndexKey: searchIndexKey).homeserverUrl(url: saved.homeserverUrl).build()
        try await client.restoreSession(session: Session(
            accessToken: saved.accessToken,
            refreshToken: saved.refreshToken,
            userId: saved.userId,
            deviceId: saved.deviceId,
            homeserverUrl: saved.homeserverUrl,
            oauthData: saved.oauthData,
            slidingSyncVersion: saved.nativeSlidingSync ? .native : .none))
        return MatrixAccount(client: client, storeDirectory: storeDirectory)
    }

    /// Signs a session out on the server without its store (a reinstall lost it), through
    /// a scratch store that is deleted after. True when the server no longer knows the
    /// session, now or before; false when it could not be reached, so try again later.
    public static func signOutOnServer(_ saved: SavedSession, scratchDirectory: URL) async -> Bool {
        defer { try? FileManager.default.removeItem(at: scratchDirectory) }
        do {
            try await restore(saved, storeDirectory: scratchDirectory).client.logout()
            return true
        } catch ClientError.MatrixApi(.unknownToken, _, _, _) {
            return true
        } catch {
            return false
        }
    }

    private static func builder(_ storeDirectory: URL, searchIndexKey: String?) throws -> ClientBuilder {
        let data = storeDirectory.appendingPathComponent("data"), cache = storeDirectory.appendingPathComponent("cache")
        let search = SearchIndex.directory(in: storeDirectory)
        for folder in [data, cache, search] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        return ClientBuilder()
            .sessionPaths(dataPath: data.path, cachePath: cache.path)
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            // the sdk indexes each message the device syncs or pages back; its backfill pages back
            // every chat (`startSearchBackfill`), which needs automatic back-pagination.
            .withSearchIndexStore(path: search.path, key: searchIndexKey)
            .enableAutomaticBackPagination(enableAutomaticBackPagination: true)
            // once the account's backup is open (`recover`), a message this device has no key
            // for fetches its key from the backup, as Element X does.
            .backupDownloadStrategy(backupDownloadStrategy: .afterDecryptionFailure)
    }

    public var userId: String {
        get throws { try client.session().userId }
    }

    public func savedSession() throws -> SavedSession {
        let s = try client.session()
        return SavedSession(userId: s.userId, deviceId: s.deviceId, homeserverUrl: s.homeserverUrl,
                            accessToken: s.accessToken, refreshToken: s.refreshToken, oauthData: s.oauthData,
                            nativeSlidingSync: s.slidingSyncVersion == .native)
    }

    /// Calls `handler`, from any thread, when the room list or an open chat changes.
    /// The room list is watched from the first `rooms()`, a chat from its first `messages()`.
    public func onChange(_ handler: @escaping @Sendable (MatrixChange) -> Void) {
        lock.withLock { changeHandler = handler }
    }

    func notify(_ change: MatrixChange) {
        lock.withLock { changeHandler }?(change)
    }

    /// The chats this account has joined (no spaces), after the first sync: the most recent
    /// activity first.
    public func rooms(timeout: TimeInterval = 30) async throws -> [RoomSummary] {
        try await startSync(timeout: timeout)
        var rooms: [RoomSummary] = []
        // the room list service's order: the most recent activity first, as the server ranks
        // it, so a room whose newest event this device cannot show still sits in its place.
        let ordered = lock.withLock { roomOrder }?.ids() ?? []
        let rank = Dictionary(ordered.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        // a room the service has not ranked yet keeps the client's order, after the ranked ones.
        // a space groups rooms; it is not a chat.
        let joined = client.rooms().filter { $0.membership() == .joined && !$0.isSpace() }.enumerated()
            .sorted { (rank[$0.element.id()] ?? Int.max, $0.offset) < (rank[$1.element.id()] ?? Int.max, $1.offset) }
            .map(\.element)
        let me = (try? client.userId()) ?? ""
        for room in joined {
            let info = try? await room.roomInfo()
            var summary = RoomSummary(id: room.id(), name: room.displayName() ?? room.id(), isDirect: await room.isDirect(),
                                      lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0,
                                      avatarName: room.avatarUrl().map(avatarFileName) ?? "",
                                      unreadCount: Int(info?.numUnreadMessages ?? 0),
                                      network: info.map { RoomNetwork.of($0, ownUserId: me) } ?? RoomNetwork.matrix)
            if let info {
                summary.fillKind(info, pins: pins)
                summary.fillActions(info, chats: chats)
            }
            switch await room.latestEvent() {
            case .remote(let timestamp, let sender, let isOwn, let profile, let content):
                summary.fillLast(timestamp: timestamp, sender: sender, isOwn: isOwn, profile: profile, content: content)
                latest.fill(&summary)
            case .local(let timestamp, let sender, let profile, let content, _):
                summary.fillLast(timestamp: timestamp, sender: sender, isOwn: true, profile: profile, content: content)
            case .none, .remoteInvite:
                break
            }
            if let live = lock.withLock({ readyTimelines[summary.id] }) { summary.fillDeleted(live.items.messages()) }
            rooms.append(summary)
        }
        latest.save()
        await fillPinOrders(&rooms)
        await fillChatStates(&rooms)
        await fillCustomNames(&rooms)
        await fillReminders(&rooms)
        return rooms
    }

    /// A room's messages, oldest first. The first call opens the chat's live timeline with
    /// its last `limit` messages; later calls return those and every message since, so a
    /// new message never pushes one the reader has loaded out of the chat.
    public func messages(roomId: String, limit: Int, timeout: TimeInterval = 30) async throws -> [Message] {
        let live = try await liveTimeline(roomId, limit: limit, timeout: timeout)
        // a chat deleted here or on another device shows only what came after.
        live.items.since = await chatMarks().cleared[roomId] ?? 0
        let shown = live.shown(limit: limit)
        // a quote's sender or a reader whose name no message carries: from the room's members.
        lookUpNames(roomId, live.items.names)
        return shown
    }

    /// The chats whose timeline is open (or opening).
    func openRoomIds() -> [String] { lock.withLock { Array(timelines.keys) } }

    /// The chat's live timeline, opened the first time with its last `limit` messages.
    func liveTimeline(_ roomId: String, limit: Int, timeout: TimeInterval) async throws -> LiveTimeline {
        let opening: Task<LiveTimeline, Error> = lock.withLock {
            if let open = timelines[roomId] { return open }
            let task = Task { try await self.openTimeline(roomId, limit: limit, timeout: timeout) }
            timelines[roomId] = task
            return task
        }
        do {
            return try await opening.value
        } catch {
            lock.withLock { timelines[roomId] = nil }
            throw error
        }
    }

    private func openTimeline(_ roomId: String, limit: Int, timeout: TimeInterval) async throws -> LiveTimeline {
        let timeline = try await room(roomId, timeout: timeout).timeline()
        let items = TimelineItems(me: (try? client.userId()) ?? "")
        items.since = await chatMarks().cleared[roomId] ?? 0
        let handle = await timeline.addListener(listener: items)
        let live = LiveTimeline(timeline: timeline, items: items, handle: handle)
        try await live.pageBack(until: limit)
        live.show(last: limit)
        // from here on, a change is news: a message came, or one was sent, edited or removed.
        items.onChange = { [weak self] in self?.notify(.room(roomId)) }
        // a sender's name comes with the room's members; until they load, a message shows the
        // sender's id. Their profiles arrive as timeline changes; a quote's and a reader's names
        // are looked up again.
        Task {
            await timeline.fetchMembers()
            items.names.membersLoaded()
            self.notify(.room(roomId))
        }
        lock.withLock { readyTimelines[roomId] = live }
        return live
    }

    /// The chat's live timeline if it is open, else nil.
    func readyTimeline(_ roomId: String) -> LiveTimeline? { lock.withLock { readyTimelines[roomId] } }

    /// Shows `count` older messages in an open chat: those the timeline has, then pages
    /// back from the server.
    public func loadOlder(roomId: String, count: Int = 20, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: count, timeout: timeout)
        try await live.showOlder(count)
    }

    /// True once an open chat shows the room's first message: there is nothing older to load.
    public func isAtStart(roomId: String, timeout: TimeInterval = 30) async throws -> Bool {
        try await liveTimeline(roomId, limit: 20, timeout: timeout).atStart
    }

    /// Puts a text message in the room's send queue and returns at once. The chat shows
    /// it at once as `sending`, then `sent`, or `failed`. With `replyTo`, a message's id (or the
    /// event id a draft keeps), it answers that message; one the server does not have yet cannot
    /// be answered. The chat's stored draft goes, so a relaunch does not offer the text again.
    public func send(roomId: String, text: String, replyTo: String? = nil, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        let content = messageEventContentFromMarkdown(md: text)
        if let eventId = live.items.replyEventId(replyTo) {
            _ = try await live.timeline.sendReply(msg: content, eventId: eventId)
        } else {
            _ = try await live.timeline.send(msg: content)
        }
        try? await room(roomId, timeout: timeout).clearComposerDraft(threadRoot: nil)
    }

    /// Adds this account's reaction `key` (an emoji) to a message, or takes it back when it
    /// is there. An added one counts among the frequent emojis (`frequentEmojis`).
    public func toggleReaction(roomId: String, messageId: String, key: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId) else { return }
        // the sdk adds or takes back from its own state at the call, and says which (true: added).
        if try await live.timeline.toggleReaction(itemId: event.eventOrTransactionId, key: key) {
            await countReaction(key)
        }
    }

    /// Sends a text message and returns once the server has accepted it.
    public func sendAndWait(roomId: String, text: String, timeout: TimeInterval = 30) async throws {
        try await send(roomId: roomId, text: text, timeout: timeout)
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        try await poll(timeout: timeout, what: "sending the message") {
            switch live.items.messages().last(where: { $0.isOwn && $0.body == text })?.sendState {
            case .sent?: return true
            case .failed?: throw MatrixCoreError.sendFailed(text)
            default: return false
            }
        }
    }

    /// Sends a failed message again. A failure the sdk can recover from (no network) stops
    /// the room's send queue, so it starts the queue again; a message the server refused
    /// waits until it is retried.
    public func retry(roomId: String, messageId: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        try await room(roomId, timeout: timeout).enableSendQueue(enable: true)
        if let itemId = live.items.eventOrTransactionId(of: messageId) {
            _ = try await live.timeline.retrySend(itemId: itemId, target: .event)
        }
    }

    /// A photo message's picture as a file in `directory`: its thumbnail (at most
    /// `thumbnailSide` pixels a side), or with `full` the original. Downloaded once; later
    /// calls return the same file.
    public func imageFile(roomId: String, messageId: String, full: Bool, directory: URL,
                          thumbnailSide: UInt64 = 800, timeout: TimeInterval = 30) async throws -> URL {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        // a photo of the info page's grid is in the chat's media timeline.
        guard let (source, thumbnailSource, image) = await (mediaItems(roomId, for: messageId) ?? live.items).image(of: messageId) else {
            throw MatrixCoreError.noImage(messageId)
        }
        let file = directory.appendingPathComponent(full ? image.fullName : image.thumbnailName)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data: Data
        if full || image.isSticker || image.isAnimated {
            // a sticker is small, and a server's thumbnail of it would lose its transparency; a
            // server's thumbnail of an animated GIF is one still frame.
            data = try await client.getMediaContent(mediaSource: source)
        } else if let thumbnail = thumbnailSource, let small = try? await client.getMediaContent(mediaSource: thumbnail) {
            // the sender's own thumbnail: a photo this device sends has it in the send queue's cache.
            data = small
        } else {
            // a server may have no thumbnail for a small picture: then the picture itself.
            do {
                data = try await client.getMediaThumbnail(mediaSource: source, width: thumbnailSide, height: thumbnailSide)
            } catch {
                data = try await client.getMediaContent(mediaSource: source)
            }
        }
        try data.write(to: file, options: .atomic)
        return file
    }

    /// A room's picture as a file in `directory`, at most `side` pixels a side; nil when the
    /// room has none. Downloaded once; later calls return the same file.
    public func avatarFile(roomId: String, directory: URL, side: UInt64 = 160) async throws -> URL? {
        guard let url = try client.getRoom(roomId: roomId)?.avatarUrl() else { return nil }
        return try await pictureFile(url: url, directory: directory, side: side)
    }

    /// A picture's media url (a sender's, `Message.senderPicture`) as a file in `directory`,
    /// at most `side` pixels a side. Downloaded once; later calls return the same file.
    public func pictureFile(url: String, directory: URL, side: UInt64 = 160, name: String? = nil) async throws -> URL {
        let file = directory.appendingPathComponent(name ?? avatarFileName(url))
        if FileManager.default.fileExists(atPath: file.path) { return file }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = try MediaSource.fromUrl(url: url)
        let data: Data
        do {
            data = try await client.getMediaThumbnail(mediaSource: source, width: side, height: side)
        } catch {
            data = try await client.getMediaContent(mediaSource: source)
        }
        try data.write(to: file, options: .atomic)
        return file
    }

    /// Sends a read receipt for the room's newest message. Others see it as read; a bridge
    /// with double puppeting passes it on (on WhatsApp, the chat turns read too). A chat marked
    /// unread by hand loses its mark: the sdk's receipt leaves it.
    public func markRead(roomId: String, timeout: TimeInterval = 30) async throws {
        try await room(roomId, timeout: timeout).markAsRead(receiptType: .read)
        try await setMarkedUnread(roomId: roomId, false, timeout: timeout)
    }

    /// Removes a message that the server does not have (it failed, or still waits in the
    /// queue). A sent message is left alone.
    public func discard(roomId: String, messageId: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let itemId = live.items.eventOrTransactionId(of: messageId), case .transactionId = itemId else { return }
        try await live.timeline.redactEvent(eventOrTransactionId: itemId, reason: nil)
    }

    /// Creates a private room and returns its id.
    public func createRoom(name: String, encrypted: Bool = false) async throws -> String {
        try await client.createRoom(request: CreateRoomParameters(name: name, isEncrypted: encrypted, visibility: .private, preset: .privateChat))
    }

    /// The account's recovery, once this device has finished setting up its encryption.
    public func recoveryStatus() async -> RecoveryStatus {
        let encryption = client.encryption()
        await encryption.waitForE2eeInitializationTasks()
        switch encryption.recoveryState() {
        case .enabled: return .enabled
        case .disabled: return .disabled
        // the sdk says incomplete while the account's cross-signing secrets are missing here,
        // even after the recovery key opened the backup: with the backup open, this device reads
        // its older messages, which is what recovery is for.
        case .incomplete: return encryption.backupState() == .enabled ? .enabled : .incomplete
        case .unknown: return .unknown
        }
    }

    /// Signs out, which removes this device from the account.
    public func signOut() async throws {
        lock.withLock {
            changeHandler = nil
            roomEntries = nil
            roomOrder = nil
            timelines = [:]
            readyTimelines = [:]
        }
        search.stop()
        accountDataWatch.stop()
        let service = lock.withLock {
            syncStart = nil
            return syncService
        }
        await service?.stop()
        lock.withLock { syncService = nil }
        try await client.logout()
    }

    /// Starts the sync once, for every caller; a start that failed is tried again at the next call.
    func startSync(timeout: TimeInterval) async throws {
        let start: Task<Void, Error> = lock.withLock {
            if let started = syncStart { return started }
            let task = Task { try await self.openSync(timeout: timeout) }
            syncStart = task
            return task
        }
        do {
            try await start.value
        } catch {
            lock.withLock { if syncStart == start { syncStart = nil } }
            throw error
        }
    }

    private func openSync(timeout: TimeInterval) async throws {
        if lock.withLock({ syncService != nil }) { return }
        let service = try await client.syncService().finish()
        lock.withLock { syncService = service }
        let state = RoomListState()
        let handle = service.roomListService().state(listener: state)
        defer { handle.cancel() }
        await service.start()
        try await poll(timeout: timeout, what: "the first sync") { state.current == .running }
        let order = RoomEntries { [weak self] in self?.notify(.rooms) }
        let entries = try await service.roomListService().allRooms().entriesWithDynamicAdapters(pageSize: 1000, listener: order)
        _ = entries.controller().setFilter(kind: .all(filters: [.joined, .nonSpace]))
        lock.withLock {
            roomEntries = entries
            roomOrder = order
        }
        startSearchBackfill()
        // another device's archive, delete or name changes no room: the list hears of it here.
        accountDataWatch.start(client) { [weak self] in self?.notify(.rooms) }
    }

    /// A room the client knows; a room created a moment ago appears once its sync has run.
    func room(_ roomId: String, timeout: TimeInterval) async throws -> Room {
        var found: Room?
        try await poll(timeout: timeout, what: "room \(roomId)") {
            found = try client.getRoom(roomId: roomId)
            return found != nil
        }
        guard let found else { throw MatrixCoreError.noRoom(roomId) }
        return found
    }
}

private func poll(timeout: TimeInterval, what: String, _ done: () async throws -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while try await !done() {
        if Date() > deadline { throw MatrixCoreError.timedOut(what) }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

private final class RoomListState: RoomListServiceStateListener, @unchecked Sendable {
    private let lock = NSLock()
    private var state: RoomListServiceState = .initial

    var current: RoomListServiceState { lock.withLock { state } }

    func onUpdate(state: RoomListServiceState) {
        lock.withLock { self.state = state }
    }
}

/// The room list in the room list service's order, kept current by applying its diffs.
/// Any change (its order, a room's name or last message) is a change for the app.
private final class RoomEntries: RoomListEntriesListener, @unchecked Sendable {
    private let changed: @Sendable () -> Void
    private let lock = NSLock()
    private var rooms: [String] = []

    init(_ changed: @escaping @Sendable () -> Void) { self.changed = changed }

    func ids() -> [String] { lock.withLock { rooms } }

    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        lock.withLock {
            for update in roomEntriesUpdate {
                switch update {
                case .append(let values): rooms += values.map { $0.id() }
                case .clear: rooms = []
                case .pushFront(let value): rooms.insert(value.id(), at: 0)
                case .pushBack(let value): rooms.append(value.id())
                case .popFront: if !rooms.isEmpty { rooms.removeFirst() }
                case .popBack: if !rooms.isEmpty { rooms.removeLast() }
                case .insert(let index, let value): rooms.insert(value.id(), at: min(Int(index), rooms.count))
                case .set(let index, let value): if Int(index) < rooms.count { rooms[Int(index)] = value.id() }
                case .remove(let index): if Int(index) < rooms.count { rooms.remove(at: Int(index)) }
                case .truncate(let length): rooms = Array(rooms.prefix(Int(length)))
                case .reset(let values): rooms = values.map { $0.id() }
                }
            }
        }
        changed()
    }
}

/// An open chat's timeline and its listener; closing it stops the listener.
final class LiveTimeline: @unchecked Sendable {
    let timeline: Timeline
    let items: TimelineItems
    private let handle: TaskHandle
    private let lock = NSLock()
    /// The oldest message the chat shows; older ones are loaded but not shown yet.
    private var firstShown: String?
    /// The server has no older events: the timeline holds the room's first one.
    private var reachedStart = false
    /// The read receipt's event the chat paged back to for its "New" line (`pageBackOnce`).
    private var pagedToReceipt: String?

    init(timeline: Timeline, items: TimelineItems, handle: TaskHandle) {
        self.timeline = timeline
        self.items = items
        self.handle = handle
    }

    /// The messages from the first one shown to the newest; the last `limit` if that one
    /// is gone (the timeline was reset).
    func shown(limit: Int) -> [Message] {
        let all = items.messages(), first = lock.withLock { firstShown }
        fetchQuoted()
        guard let first, let start = all.firstIndex(where: { $0.id == first }) else { return Array(all.suffix(limit)) }
        return Array(all[start...])
    }

    /// The timeline loads the message a reply answers only when asked; its details then
    /// arrive as a change. Each is asked for once.
    private var askedForDetails: Set<String> = []

    private func fetchQuoted() {
        let missing = items.missingQuotes()
        let asks = lock.withLock { () -> [String] in
            let new = missing.filter { !askedForDetails.contains($0) }
            askedForDetails.formUnion(new)
            return new
        }
        for eventId in asks { Task { try? await timeline.fetchDetailsForEvent(eventId: eventId) } }
    }

    /// True once the chat shows its first message, or the first after its delete.
    var atStart: Bool {
        let all = items.messages(), cut = items.reachesCut
        return lock.withLock {
            // the first one shown can be from before the delete, which hides it.
            let hidden = cut && !all.contains { $0.id == firstShown }
            return (reachedStart || cut) && (all.first == nil || all.first?.id == firstShown || hidden)
        }
    }

    func show(last count: Int) {
        let first = items.messages().suffix(count).first?.id
        lock.withLock { firstShown = first }
    }

    /// Pages back until the timeline holds at least `count` messages before the first one
    /// shown (all of them when none is shown yet), or the room's start; at most 5 pages,
    /// since a page holds state events too (joins, names).
    func pageBack(until count: Int) async throws {
        // a page is 50 events, at most 20 pages (1,000 events): a room whose newest events are
        // mostly ones the chat does not show (a bridge's members joining or renamed) needs many
        // pages for a few messages; before, 100 events of them opened the chat empty, and an
        // empty chat has no list to ask for more.
        for _ in 0..<20 {
            // the timeline delivers its diffs on the sdk's own task; wait until they stop arriving.
            await items.settle()
            if lock.withLock({ reachedStart }) || items.reachesCut || olderThanShown() >= count { return }
            let start = try await timeline.paginateBackwards(numEvents: 50)
            lock.withLock { reachedStart = start }
        }
        await items.settle()
    }

    /// Pages back until the timeline holds the event `eventId`, at most `limit` events or to the
    /// room's start, then shows from `context` messages before it (never fewer than it shows).
    /// The message's id in the chat, or nil when it is not that far back.
    func show(event eventId: String, context: Int, limit: Int) async throws -> String? {
        var paged = 0
        while true {
            if let id = items.messageId(ofEvent: eventId) {
                let all = items.messages(), first = lock.withLock { firstShown }
                let at = all.firstIndex { $0.id == id } ?? 0, shownFrom = all.firstIndex { $0.id == first } ?? all.count
                if at - context < shownFrom { lock.withLock { firstShown = all[max(0, at - context)].id } }
                return id
            }
            if lock.withLock({ reachedStart }) || paged >= limit {
                // the last page's diffs may still be on their way.
                await items.settle()
                guard items.messageId(ofEvent: eventId) != nil else { return nil }
                continue
            }
            let start = try await timeline.paginateBackwards(numEvents: 50)
            paged += 50
            lock.withLock { reachedStart = start }
            await items.settle(quiet: 0.15, limit: 2)
        }
    }

    /// `show(event:)` for the read receipt's message, once per receipt: a chat whose receipt is
    /// further back than `limit` events does not page again at each ask. False when it was done
    /// before, or the message is not that far back.
    func pageBackOnce(toEvent eventId: String, context: Int, limit: Int) async throws -> Bool {
        let first = lock.withLock { () -> Bool in
            if pagedToReceipt == eventId { return false }
            pagedToReceipt = eventId
            return true
        }
        guard first else { return false }
        return try await show(event: eventId, context: context, limit: limit) != nil
    }

    func showOlder(_ count: Int) async throws {
        try await pageBack(until: count)
        let all = items.messages(), older = olderThanShown()
        let first = all.isEmpty ? nil : all[max(0, older - count)].id
        lock.withLock { firstShown = first }
    }

    /// How many loaded messages come before the first one shown.
    private func olderThanShown() -> Int {
        let all = items.messages(), first = lock.withLock { firstShown }
        guard let first else { return all.count }
        return all.firstIndex(where: { $0.id == first }) ?? 0
    }

    deinit { handle.cancel() }
}

/// A timeline's items, kept current by applying the sdk's diffs in order.
final class TimelineItems: TimelineListener, @unchecked Sendable {
    /// This account's user id: its reactions are marked as its own.
    private let me: String
    /// Names that a quote or a read receipt needs and its event does not carry (ChatDetails.swift).
    let names = MemberNames()
    private let lock = NSLock()
    private var items: [TimelineItem] = []
    /// The time of the chat's newest message when it was deleted (`ChatMarks.cleared`): messages
    /// up to it do not show. 0 for none.
    private var cut: UInt64 = 0
    private var lastUpdate = Date()
    private var changed: (@Sendable () -> Void)?
    /// How many times the sdk cleared or reset the items: a sync with a gap can reset a timeline
    /// to its newest events, after which a page back is needed again.
    private var resets = 0

    init(me: String) { self.me = me }

    var resetCount: Int { lock.withLock { resets } }

    /// Called after each batch of diffs, from the sdk's task.
    var onChange: (@Sendable () -> Void)? {
        get { lock.withLock { changed } }
        set { lock.withLock { changed = newValue } }
    }

    func onUpdate(diff: [TimelineDiff]) {
        let changed = lock.withLock {
            for d in diff { apply(d) }
            lastUpdate = Date()
            return self.changed
        }
        changed?()
    }

    private func apply(_ d: TimelineDiff) {
        switch d {
        case .append(let values): items += values
        case .clear:
            items = []
            resets += 1
        case .pushFront(let value): items.insert(value, at: 0)
        case .pushBack(let value): items.append(value)
        case .popFront: if !items.isEmpty { items.removeFirst() }
        case .popBack: if !items.isEmpty { items.removeLast() }
        case .insert(let index, let value): items.insert(value, at: Int(index))
        case .set(let index, let value): items[Int(index)] = value
        case .remove(let index): items.remove(at: Int(index))
        case .truncate(let length): items = Array(items.prefix(Int(length)))
        case .reset(let values):
            items = values
            resets += 1
        }
    }

    /// Waits until no diff has arrived for `quiet` seconds, counted from the call at the
    /// earliest (the diffs of a call that just returned may still be on their way), at most
    /// `limit` seconds.
    func settle(quiet: TimeInterval = 0.5, limit: TimeInterval = 5) async {
        let start = Date()
        while Date().timeIntervalSince(start) < limit {
            if lock.withLock({ Date().timeIntervalSince(max(lastUpdate, start)) }) >= quiet { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    var since: UInt64 {
        get { lock.withLock { cut } }
        set { lock.withLock { cut = newValue } }
    }

    func messages() -> [Message] {
        lock.withLock { chatMessages(items, me: me, names: names).filter { $0.timestamp > cut } }
    }

    /// The timeline holds an event from before the chat's delete: nothing older shows.
    var reachesCut: Bool {
        lock.withLock { cut > 0 && items.contains { ($0.asEvent()?.timestamp ?? .max) <= cut } }
    }

    /// Reads the items as they are now.
    func read<T>(_ body: ([TimelineItem], _ me: String) -> T) -> T {
        lock.withLock { body(items, me) }
    }

    /// The event ids of replies whose quoted message is not loaded: the sdk loads a quote when
    /// asked with the reply's own id, and only for a reply the server has. A reply read back
    /// from the store can stay pending with nothing loading it, so pending counts.
    func missingQuotes() -> [String] {
        lock.withLock {
            items.compactMap { item in
                guard let event = item.asEvent(), case .msgLike(let like) = event.content, let reply = like.inReplyTo,
                      case .eventId(let replyId) = event.eventOrTransactionId else { return nil }
                if case .ready = reply.event() { return nil }
                return replyId
            }
        }
    }

    /// A photo's or a sticker's picture, its sender's thumbnail of it (nil for none), and its names.
    func image(of messageId: String) -> (MediaSource, MediaSource?, MessageImage)? {
        lock.withLock {
            guard let event = items.first(where: { $0.uniqueId().id == messageId })?.asEvent(),
                  case .msgLike(let like) = event.content else { return nil }
            switch like.kind {
            case .message(let message):
                guard case .image(let content) = message.msgType else { return nil }
                return (content.source, content.info?.thumbnailSource, MessageImage(content))
            case .sticker(_, let info, let source):
                return (source, nil, MessageImage(sticker: info, source: source))
            default:
                return nil
            }
        }
    }

    func eventOrTransactionId(of messageId: String) -> EventOrTransactionId? {
        event(of: messageId)?.eventOrTransactionId
    }

    func event(of messageId: String) -> EventTimelineItem? {
        lock.withLock { items.first { $0.uniqueId().id == messageId }?.asEvent() }
    }

    /// The event a reply answers: `replyTo` is a message's id in this chat, or an event id ("$…")
    /// as a stored draft keeps one. Nil for none, and for a message the server does not have yet.
    func replyEventId(_ replyTo: String?) -> String? {
        guard let replyTo, !replyTo.isEmpty else { return nil }
        if replyTo.hasPrefix("$") { return replyTo }
        guard case .eventId(let eventId)? = eventOrTransactionId(of: replyTo) else { return nil }
        return eventId
    }

    /// What a reply bar shows of the message with this event id, if the chat holds it.
    func draftReply(eventId: String) -> DraftReply? {
        lock.withLock {
            for item in items {
                guard let event = item.asEvent(), case .eventId(eventId) = event.eventOrTransactionId else { continue }
                guard let body = preview(event.content) else { return nil }
                return DraftReply(messageId: item.uniqueId().id, senderName: displayName(event.sender, event.senderProfile),
                                  body: body, isOwn: event.sender == me)
            }
            return nil
        }
    }
}

extension SignInError {
    init(_ error: Error) {
        switch error {
        case ClientBuildError.InvalidServerName, ClientBuildError.ServerUnreachable,
             ClientBuildError.WellKnownLookupFailed, ClientBuildError.WellKnownDeserializationError:
            self = .serverNotFound
        case ClientBuildError.SlidingSyncVersion:
            self = .serverNotSupported
        case ClientError.MatrixApi(.forbidden, _, _, _):
            self = .wrongPassword
        case ClientError.MatrixApi(.limitExceeded, _, _, _):
            self = .rateLimited
        default:
            self = .other(String(describing: error))
        }
    }
}

extension RoomSummary {
    mutating func fillLast(timestamp: Timestamp, sender: String, isOwn: Bool, profile: ProfileDetails, content: TimelineItemContent) {
        // the newest event orders the list even when it is no message (a new picture, a
        // join); then there is no preview.
        lastTimestamp = timestamp
        guard let preview = preview(content) else { return }
        lastMessage = preview
        lastSenderName = displayName(sender, profile)
        lastIsOwn = isOwn
    }
}

/// One line for a message: its text, or what it is when it has none ("Photo"). Nil for an
/// event that is no message (a join, a new name).
private func preview(_ content: TimelineItemContent) -> String? {
    guard case .msgLike(let like) = content else { return nil }
    switch like.kind {
    case .message(let message): return preview(message.msgType, body: message.body)
    case .sticker: return "Sticker"
    case .poll(let question, _, _, _, _, _, _): return question
    case .redacted: return "Message deleted"
    case .unableToDecrypt: return "Encrypted message"
    case .liveLocation: return "Live location"
    case .other: return "Message"
    }
}

/// One line for a message of this type: what it is ("Photo"), or `body` for text.
private func preview(_ type: MessageType, body: String) -> String {
    switch type {
    case .image: return "Photo"
    case .gallery: return "Photos"
    case .video: return "Video"
    case .audio(let content): return content.voice == nil ? "Audio" : "Voice message"
    case .file: return "File"
    case .location: return "Location"
    default: return body
    }
}

/// One line for a message fetched by its event id, which comes with no body of its own.
func preview(_ type: MessageType) -> String {
    switch type {
    case .text(let content): return content.body
    case .notice(let content): return content.body
    case .emote(let content): return content.body
    case .other(_, let body): return body
    default: return preview(type, body: "Message")
    }
}

/// A sender's display name, or their id until their profile loads.
private func displayName(_ sender: String, _ profile: ProfileDetails) -> String {
    if case .ready(let displayName, _, _, _, _) = profile, let displayName { return displayName }
    return sender
}

extension Message {
    init?(_ event: EventTimelineItem, id: String, me: String, names: MemberNames) {
        guard case .msgLike(let content) = event.content else { return nil }
        let name = displayName(event.sender, event.senderProfile)
        var picture = ""
        if case .ready(_, _, let avatarUrl?, _, _) = event.senderProfile { picture = avatarUrl }
        if case .unableToDecrypt = content.kind {
            self.init(id: id, sender: event.sender, senderName: name, body: "", timestamp: event.timestamp,
                      isOwn: event.isOwn, sendState: .sent, image: nil, waitingForKey: true, senderPicture: picture)
            return
        }
        if case .redacted = content.kind {
            self.init(deleted: event, id: id, senderName: name, senderPicture: picture)
            return
        }
        let reactions = event.reactions.map { reaction in
            MessageReaction(key: reaction.key, count: reaction.senders.count, isMine: reaction.senders.contains { $0.senderId == me })
        }
        if case .sticker(_, let info, let source) = content.kind {
            self.init(id: id, sender: event.sender, senderName: name, body: "", timestamp: event.timestamp,
                      isOwn: event.isOwn, sendState: .sent, image: MessageImage(sticker: info, source: source),
                      reply: content.inReplyTo.map { QuotedMessage($0, me: me, names: names) }, reactions: reactions,
                      senderPicture: picture)
            isSticker = true
            return
        }
        guard case .message(let message) = content.kind else { return nil }
        let sendState: SendState
        var uploaded: Double?
        switch event.localSendState {
        case .notSentYet(let progress)?:
            sendState = .sending
            uploaded = progress.map(uploadedFraction)
        case .sendingFailed?: sendState = .failed
        // a remote echo has no local send state: the server has it.
        case .sent?, nil: sendState = .sent
        }
        var body = message.body, image: MessageImage?, file: MessageFile?, video: MessageVideo?, audio: MessageAudio?
        if case .image(let content) = message.msgType {
            body = content.caption ?? ""
            image = MessageImage(content)
        } else if case .file(let content) = message.msgType {
            body = content.caption ?? ""
            file = MessageFile(content)
        } else if case .video(let content) = message.msgType {
            body = content.caption ?? ""
            video = MessageVideo(content)
        } else if case .audio(let content) = message.msgType {
            body = content.caption ?? ""
            audio = MessageAudio(content)
        }
        self.init(id: id, sender: event.sender, senderName: name, body: body, timestamp: event.timestamp,
                  isOwn: event.isOwn, sendState: sendState, image: image, isEdited: message.isEdited,
                  reply: content.inReplyTo.map { QuotedMessage($0, me: me, names: names) },
                  reactions: reactions, senderPicture: picture)
        self.file = file
        self.video = video
        self.audio = audio
        uploadProgress = uploaded
        isEditable = Message.isEditable(event, message)
    }
}

extension Message {
    /// The file name `MatrixAccount.pictureFile` gives the sender's picture; "" when they have none.
    public var senderPictureName: String { senderPicture.isEmpty ? "" : avatarFileName(senderPicture) }
}

extension QuotedMessage {
    /// The sdk loads a quoted message without its sender's profile, so its name comes from `names`
    /// (the room's members); "" until it is known.
    init(_ details: InReplyToDetails, me: String, names: MemberNames) {
        switch details.event() {
        case .ready(let content, let sender, let profile, _, _):
            let name: String
            if case .ready(let shown?, _, _, _, _) = profile { name = shown } else { name = names.name(sender) ?? "" }
            self.init(senderName: name, body: preview(content) ?? "Message", isOwn: sender == me)
        case .unavailable, .pending, .error:
            self.init(senderName: "", body: "", isOwn: false)
        }
    }
}

/// A media url names its picture for good; its hash makes a safe file name.
func mediaKey(_ url: String) -> String {
    SHA256.hash(data: Data(url.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
}

func avatarFileName(_ url: String) -> String { "\(mediaKey(url))-avatar.jpg" }

extension MessageImage {
    init(_ content: ImageMessageContent) {
        let key = mediaKey(content.source.url())
        let ext: String
        switch content.info?.mimetype {
        case "image/png"?: ext = "png"
        case "image/gif"?: ext = "gif"
        case "image/webp"?: ext = "webp"
        case "image/heic"?: ext = "heic"
        default: ext = "jpg"
        }
        let animated = content.info?.mimetype == "image/gif" || content.info?.isAnimated == true
        // an animated one shows its whole file in the chat too, downloaded once under one name.
        self.init(width: Int(content.info?.width ?? 0), height: Int(content.info?.height ?? 0),
                  thumbnailName: animated ? "\(key).\(ext)" : "\(key)-thumbnail.\(ext)", fullName: "\(key).\(ext)",
                  isAnimated: animated)
    }
}
