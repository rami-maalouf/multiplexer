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
    /// The room list's listener, kept so that it keeps listening.
    private var roomEntries: RoomListEntriesWithDynamicAdaptersResult?
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

    /// The rooms this account has joined, after the first sync.
    public func rooms(timeout: TimeInterval = 30) async throws -> [RoomSummary] {
        try await startSync(timeout: timeout)
        var rooms: [RoomSummary] = []
        for room in client.rooms() where room.membership() == .joined {
            var summary = RoomSummary(id: room.id(), name: room.displayName() ?? room.id(), isDirect: await room.isDirect(),
                                      lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
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
        // a page holds state events too (joins, names), so page back until there are
        // enough messages or the room's start; at most 5 pages.
        for _ in 0..<5 {
            // the timeline delivers its diffs on the sdk's own task; wait until they stop arriving.
            await items.settle()
            if items.messages().count >= limit { break }
            if try await timeline.paginateBackwards(numEvents: UInt16(clamping: limit)) { break }
        }
        await items.settle()
        // from here on, a change is news: a message came, or one was sent, edited or removed.
        items.onChange = { [weak self] in self?.notify(.room(roomId)) }
        return LiveTimeline(timeline: timeline, items: items, handle: handle,
                            firstShown: items.messages().suffix(limit).first?.id)
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

    /// Removes a message that the server does not have (it failed, or still waits in the
    /// queue). A sent message is left alone.
    public func discard(roomId: String, messageId: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let itemId = live.items.eventOrTransactionId(of: messageId), case .transactionId = itemId else { return }
        try await live.timeline.redactEvent(eventOrTransactionId: itemId, reason: nil)
    }

    /// Creates a private, unencrypted room and returns its id.
    public func createRoom(name: String) async throws -> String {
        try await client.createRoom(request: CreateRoomParameters(name: name, isEncrypted: false, visibility: .private, preset: .privateChat))
    }

    /// Signs out, which removes this device from the account.
    public func signOut() async throws {
        lock.withLock {
            changeHandler = nil
            roomEntries = nil
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
        let entries = try await service.roomListService().allRooms()
            .entriesWithDynamicAdapters(pageSize: 1000, listener: RoomEntries { [weak self] in self?.notify(.rooms) })
        _ = entries.controller().setFilter(kind: .joined)
        lock.withLock { roomEntries = entries }
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

/// Any change to the room list (its order, a room's name or last message) is a change.
private final class RoomEntries: RoomListEntriesListener, @unchecked Sendable {
    private let changed: @Sendable () -> Void
    init(_ changed: @escaping @Sendable () -> Void) { self.changed = changed }
    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) { changed() }
}

/// An open chat's timeline and its listener; closing it stops the listener.
private final class LiveTimeline: @unchecked Sendable {
    let timeline: Timeline
    let items: TimelineItems
    private let handle: TaskHandle
    /// The oldest message the chat showed when it opened.
    private let firstShown: String?

    init(timeline: Timeline, items: TimelineItems, handle: TaskHandle, firstShown: String?) {
        self.timeline = timeline
        self.items = items
        self.handle = handle
        self.firstShown = firstShown
    }

    /// The messages from the first one shown at open to the newest; the last `limit` if
    /// that one is gone (the timeline was reset).
    func shown(limit: Int) -> [Message] {
        let all = items.messages()
        guard let firstShown, let start = all.firstIndex(where: { $0.id == firstShown }) else { return Array(all.suffix(limit)) }
        return Array(all[start...])
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
        lastTimestamp = timestamp
    }
}

extension Message {
    init?(_ event: EventTimelineItem, id: String) {
        guard case .msgLike(let content) = event.content, case .message(let message) = content.kind else { return nil }
        var name = event.sender
        if case .ready(let displayName, _, _, _, _) = event.senderProfile, let displayName { name = displayName }
        let sendState: SendState
        switch event.localSendState {
        case .notSentYet?: sendState = .sending
        case .sendingFailed?: sendState = .failed
        // a remote echo has no local send state: the server has it.
        case .sent?, nil: sendState = .sent
        }
        self.init(id: id, sender: event.sender, senderName: name, body: message.body, timestamp: event.timestamp,
                  isOwn: event.isOwn, sendState: sendState)
    }
}
