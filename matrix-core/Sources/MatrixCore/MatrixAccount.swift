import CryptoKit
import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// One signed-in Matrix account and its local store.
public final class MatrixAccount: @unchecked Sendable {
    private let client: Client
    private var syncService: SyncService?
    private let lock = NSLock()
    private var changeHandler: (@Sendable (MatrixChange) -> Void)?
    /// The room list's listener, kept so that it keeps listening, and the rooms in its order.
    private var roomEntries: RoomListEntriesWithDynamicAdaptersResult?
    private var roomOrder: RoomEntries?
    /// One live timeline for each chat that was opened, so a chat opened again does not page back.
    private var timelines: [String: Task<LiveTimeline, Error>] = [:]

    private init(client: Client) {
        self.client = client
    }

    /// Signs in with a user name and password. `homeserver` is a server name
    /// (`matrix.org`) or a URL; the store lives in `storeDirectory`. Throws a `SignInError`.
    public static func signIn(homeserver: String, user: String, password: String, deviceName: String, storeDirectory: URL) async throws -> MatrixAccount {
        do {
            let client = try await builder(storeDirectory).serverNameOrHomeserverUrl(serverNameOrUrl: homeserver).build()
            try await client.login(username: user, password: password, initialDeviceName: deviceName, deviceId: nil)
            return MatrixAccount(client: client)
        } catch {
            throw SignInError(error)
        }
    }

    /// Signs in again with a session that `savedSession()` returned.
    public static func restore(_ saved: SavedSession, storeDirectory: URL) async throws -> MatrixAccount {
        let client = try await builder(storeDirectory).homeserverUrl(url: saved.homeserverUrl).build()
        try await client.restoreSession(session: Session(
            accessToken: saved.accessToken,
            refreshToken: saved.refreshToken,
            userId: saved.userId,
            deviceId: saved.deviceId,
            homeserverUrl: saved.homeserverUrl,
            oauthData: saved.oauthData,
            slidingSyncVersion: saved.nativeSlidingSync ? .native : .none))
        return MatrixAccount(client: client)
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

    private static func builder(_ storeDirectory: URL) throws -> ClientBuilder {
        let data = storeDirectory.appendingPathComponent("data"), cache = storeDirectory.appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        return ClientBuilder()
            .sessionPaths(dataPath: data.path, cachePath: cache.path)
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
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

    private func notify(_ change: MatrixChange) {
        lock.withLock { changeHandler }?(change)
    }

    /// The rooms this account has joined, after the first sync: the most recent activity first.
    public func rooms(timeout: TimeInterval = 30) async throws -> [RoomSummary] {
        try await startSync(timeout: timeout)
        var rooms: [RoomSummary] = []
        // the room list service's order: the most recent activity first, as the server ranks
        // it, so a room whose newest event this device cannot show still sits in its place.
        let ordered = lock.withLock { roomOrder }?.ids() ?? []
        let rank = Dictionary(ordered.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        // a room the service has not ranked yet keeps the client's order, after the ranked ones.
        let joined = client.rooms().filter { $0.membership() == .joined }.enumerated()
            .sorted { (rank[$0.element.id()] ?? Int.max, $0.offset) < (rank[$1.element.id()] ?? Int.max, $1.offset) }
            .map(\.element)
        for room in joined {
            var summary = RoomSummary(id: room.id(), name: room.displayName() ?? room.id(), isDirect: await room.isDirect(),
                                      lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0,
                                      avatarName: room.avatarUrl().map(avatarFileName) ?? "")
            switch await room.latestEvent() {
            case .remote(let timestamp, let sender, let isOwn, let profile, let content):
                summary.fillLast(timestamp: timestamp, sender: sender, isOwn: isOwn, profile: profile, content: content)
            case .local(let timestamp, let sender, let profile, let content, _):
                summary.fillLast(timestamp: timestamp, sender: sender, isOwn: true, profile: profile, content: content)
            case .none, .remoteInvite:
                break
            }
            rooms.append(summary)
        }
        return rooms
    }

    /// A room's messages, oldest first. The first call opens the chat's live timeline with
    /// its last `limit` messages; later calls return those and every message since, so a
    /// new message never pushes one the reader has loaded out of the chat.
    public func messages(roomId: String, limit: Int, timeout: TimeInterval = 30) async throws -> [Message] {
        try await liveTimeline(roomId, limit: limit, timeout: timeout).shown(limit: limit)
    }

    /// The chat's live timeline, opened the first time with its last `limit` messages.
    private func liveTimeline(_ roomId: String, limit: Int, timeout: TimeInterval) async throws -> LiveTimeline {
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
        let items = TimelineItems()
        let handle = await timeline.addListener(listener: items)
        let live = LiveTimeline(timeline: timeline, items: items, handle: handle)
        try await live.pageBack(until: limit)
        live.show(last: limit)
        // from here on, a change is news: a message came, or one was sent, edited or removed.
        items.onChange = { [weak self] in self?.notify(.room(roomId)) }
        return live
    }

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
    /// it at once as `sending`, then `sent`, or `failed`.
    public func send(roomId: String, text: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        _ = try await live.timeline.send(msg: messageEventContentFromMarkdown(md: text))
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
        guard let (content, image) = live.items.image(of: messageId) else { throw MatrixCoreError.noImage(messageId) }
        let file = directory.appendingPathComponent(full ? image.fullName : image.thumbnailName)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data: Data
        if full {
            data = try await client.getMediaContent(mediaSource: content.source)
        } else {
            // a server may have no thumbnail for a small picture: then the picture itself.
            do {
                data = try await client.getMediaThumbnail(mediaSource: content.source, width: thumbnailSide, height: thumbnailSide)
            } catch {
                data = try await client.getMediaContent(mediaSource: content.source)
            }
        }
        try data.write(to: file, options: .atomic)
        return file
    }

    /// A room's picture as a file in `directory`, at most `side` pixels a side; nil when the
    /// room has none. Downloaded once; later calls return the same file.
    public func avatarFile(roomId: String, directory: URL, side: UInt64 = 160) async throws -> URL? {
        guard let url = try client.getRoom(roomId: roomId)?.avatarUrl() else { return nil }
        let file = directory.appendingPathComponent(avatarFileName(url))
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
        case .incomplete: return .incomplete
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
        }
        await syncService?.stop()
        syncService = nil
        try await client.logout()
    }

    private func startSync(timeout: TimeInterval) async throws {
        guard syncService == nil else { return }
        let service = try await client.syncService().finish()
        syncService = service
        let state = RoomListState()
        let handle = service.roomListService().state(listener: state)
        defer { handle.cancel() }
        await service.start()
        try await poll(timeout: timeout, what: "the first sync") { state.current == .running }
        let order = RoomEntries { [weak self] in self?.notify(.rooms) }
        let entries = try await service.roomListService().allRooms().entriesWithDynamicAdapters(pageSize: 1000, listener: order)
        _ = entries.controller().setFilter(kind: .joined)
        lock.withLock {
            roomEntries = entries
            roomOrder = order
        }
    }

    /// A room the client knows; a room created a moment ago appears once its sync has run.
    private func room(_ roomId: String, timeout: TimeInterval) async throws -> Room {
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
private final class LiveTimeline: @unchecked Sendable {
    let timeline: Timeline
    let items: TimelineItems
    private let handle: TaskHandle
    private let lock = NSLock()
    /// The oldest message the chat shows; older ones are loaded but not shown yet.
    private var firstShown: String?
    /// The server has no older events: the timeline holds the room's first one.
    private var reachedStart = false

    init(timeline: Timeline, items: TimelineItems, handle: TaskHandle) {
        self.timeline = timeline
        self.items = items
        self.handle = handle
    }

    /// The messages from the first one shown to the newest; the last `limit` if that one
    /// is gone (the timeline was reset).
    func shown(limit: Int) -> [Message] {
        let all = items.messages(), first = lock.withLock { firstShown }
        guard let first, let start = all.firstIndex(where: { $0.id == first }) else { return Array(all.suffix(limit)) }
        return Array(all[start...])
    }

    var atStart: Bool {
        let all = items.messages()
        return lock.withLock { reachedStart && (all.first == nil || all.first?.id == firstShown) }
    }

    func show(last count: Int) {
        let first = items.messages().suffix(count).first?.id
        lock.withLock { firstShown = first }
    }

    /// Pages back until the timeline holds at least `count` messages before the first one
    /// shown (all of them when none is shown yet), or the room's start; at most 5 pages,
    /// since a page holds state events too (joins, names).
    func pageBack(until count: Int) async throws {
        for _ in 0..<5 {
            // the timeline delivers its diffs on the sdk's own task; wait until they stop arriving.
            await items.settle()
            if lock.withLock({ reachedStart }) || olderThanShown() >= count { return }
            let start = try await timeline.paginateBackwards(numEvents: UInt16(clamping: count))
            lock.withLock { reachedStart = start }
        }
        await items.settle()
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
private final class TimelineItems: TimelineListener, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TimelineItem] = []
    private var lastUpdate = Date()
    private var changed: (@Sendable () -> Void)?

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
        case .clear: items = []
        case .pushFront(let value): items.insert(value, at: 0)
        case .pushBack(let value): items.append(value)
        case .popFront: if !items.isEmpty { items.removeFirst() }
        case .popBack: if !items.isEmpty { items.removeLast() }
        case .insert(let index, let value): items.insert(value, at: Int(index))
        case .set(let index, let value): items[Int(index)] = value
        case .remove(let index): items.remove(at: Int(index))
        case .truncate(let length): items = Array(items.prefix(Int(length)))
        case .reset(let values): items = values
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

    func messages() -> [Message] {
        lock.withLock { items.compactMap { item in item.asEvent().flatMap { Message($0, id: item.uniqueId().id) } } }
    }

    func image(of messageId: String) -> (ImageMessageContent, MessageImage)? {
        lock.withLock {
            guard let event = items.first(where: { $0.uniqueId().id == messageId })?.asEvent(),
                  case .msgLike(let like) = event.content, case .message(let message) = like.kind,
                  case .image(let content) = message.msgType else { return nil }
            return (content, MessageImage(content))
        }
    }

    func eventOrTransactionId(of messageId: String) -> EventOrTransactionId? {
        lock.withLock { items.first { $0.uniqueId().id == messageId }?.asEvent()?.eventOrTransactionId }
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
        guard case .msgLike(let like) = content else { return }
        switch like.kind {
        case .message(let message):
            switch message.msgType {
            case .image: lastMessage = "Photo"
            case .gallery: lastMessage = "Photos"
            case .video: lastMessage = "Video"
            case .audio: lastMessage = "Audio"
            case .file: lastMessage = "File"
            case .location: lastMessage = "Location"
            default: lastMessage = message.body
            }
        case .sticker: lastMessage = "Sticker"
        case .poll(let question, _, _, _, _, _, _): lastMessage = question
        case .redacted: lastMessage = "Message deleted"
        case .unableToDecrypt: lastMessage = "Encrypted message"
        case .liveLocation: lastMessage = "Live location"
        case .other: lastMessage = "Message"
        }
        lastSenderName = sender
        if case .ready(let displayName, _, _, _, _) = profile, let displayName { lastSenderName = displayName }
        lastIsOwn = isOwn
    }
}

extension Message {
    init?(_ event: EventTimelineItem, id: String) {
        guard case .msgLike(let content) = event.content else { return nil }
        if case .unableToDecrypt = content.kind {
            var name = event.sender
            if case .ready(let displayName, _, _, _, _) = event.senderProfile, let displayName { name = displayName }
            self.init(id: id, sender: event.sender, senderName: name, body: "", timestamp: event.timestamp,
                      isOwn: event.isOwn, sendState: .sent, image: nil, waitingForKey: true)
            return
        }
        guard case .message(let message) = content.kind else { return nil }
        var name = event.sender
        if case .ready(let displayName, _, _, _, _) = event.senderProfile, let displayName { name = displayName }
        let sendState: SendState
        switch event.localSendState {
        case .notSentYet?: sendState = .sending
        case .sendingFailed?: sendState = .failed
        // a remote echo has no local send state: the server has it.
        case .sent?, nil: sendState = .sent
        }
        var body = message.body, image: MessageImage?
        if case .image(let content) = message.msgType {
            body = content.caption ?? ""
            image = MessageImage(content)
        }
        self.init(id: id, sender: event.sender, senderName: name, body: body, timestamp: event.timestamp,
                  isOwn: event.isOwn, sendState: sendState, image: image)
    }
}

/// A media url names its picture for good; its hash makes a safe file name.
private func mediaKey(_ url: String) -> String {
    SHA256.hash(data: Data(url.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
}

private func avatarFileName(_ url: String) -> String { "\(mediaKey(url))-avatar.jpg" }

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
        self.init(width: Int(content.info?.width ?? 0), height: Int(content.info?.height ?? 0),
                  thumbnailName: "\(key)-thumbnail.\(ext)", fullName: "\(key).\(ext)")
    }
}
