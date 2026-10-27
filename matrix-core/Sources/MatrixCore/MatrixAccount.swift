import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// One signed-in Matrix account and its local store.
public final class MatrixAccount: @unchecked Sendable {
    private let client: Client
    private var syncService: SyncService?

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

    /// The last `limit` messages of a room, oldest first.
    public func messages(roomId: String, limit: Int, timeout: TimeInterval = 30) async throws -> [Message] {
        let timeline = try await room(roomId, timeout: timeout).timeline()
        let items = TimelineItems()
        let handle = await timeline.addListener(listener: items)
        defer { handle.cancel() }
        // a page holds state events too (joins, names), so page back until there are
        // enough messages or the room's start; at most 5 pages.
        for _ in 0..<5 {
            // the timeline delivers its diffs on the sdk's own task; wait until they stop arriving.
            await items.settle()
            if items.messages().count >= limit { break }
            if try await timeline.paginateBackwards(numEvents: UInt16(clamping: limit)) { break }
        }
        await items.settle()
        return Array(items.messages().suffix(limit))
    }

    /// Sends a text message and returns once the server has accepted it.
    public func send(roomId: String, text: String, timeout: TimeInterval = 30) async throws {
        let timeline = try await room(roomId, timeout: timeout).timeline()
        let items = TimelineItems()
        let handle = await timeline.addListener(listener: items)
        defer { handle.cancel() }
        _ = try await timeline.send(msg: messageEventContentFromMarkdown(md: text))
        try await poll(timeout: timeout, what: "sending the message") {
            switch items.sendState(ofOwnMessage: text) {
            case .sent?: return true
            case .sendingFailed?: throw MatrixCoreError.sendFailed(text)
            default: return false
            }
        }
    }

    /// Creates a private, unencrypted room and returns its id.
    public func createRoom(name: String) async throws -> String {
        try await client.createRoom(request: CreateRoomParameters(name: name, isEncrypted: false, visibility: .private, preset: .privateChat))
    }

    /// Signs out, which removes this device from the account.
    public func signOut() async throws {
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

/// A timeline's items, kept current by applying the sdk's diffs in order.
private final class TimelineItems: TimelineListener, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TimelineItem] = []
    private var lastUpdate = Date()

    func onUpdate(diff: [TimelineDiff]) {
        lock.withLock {
            for d in diff { apply(d) }
            lastUpdate = Date()
        }
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
        lock.withLock { items.compactMap { $0.asEvent() }.compactMap(Message.init) }
    }

    func sendState(ofOwnMessage body: String) -> EventSendState? {
        lock.withLock {
            for item in items.reversed() {
                guard let event = item.asEvent(), event.isOwn, Message(event)?.body == body else { continue }
                // a remote echo has no local send state: the server has it.
                return event.localSendState ?? .sent(eventId: "")
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
    init?(_ event: EventTimelineItem) {
        guard case .msgLike(let content) = event.content, case .message(let message) = content.kind else { return nil }
        let id: String
        switch event.eventOrTransactionId {
        case .eventId(let eventId): id = eventId
        case .transactionId(let transactionId): id = transactionId
        }
        var name = event.sender
        if case .ready(let displayName, _, _, _, _) = event.senderProfile, let displayName { name = displayName }
        self.init(id: id, sender: event.sender, senderName: name, body: message.body, timestamp: event.timestamp, isOwn: event.isOwn)
    }
}
