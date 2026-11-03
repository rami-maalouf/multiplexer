import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A message this account saved (B14's Bookmark), with what the list shows of it as it was then.
public struct Bookmark: Equatable, Sendable {
    public enum Kind: String, Sendable { case text, image, video, voice, audio, file, sticker, other }

    public var roomId: String
    /// The message's event: the chat opens at it (`showMessage`).
    public var eventId: String
    public var sender: String
    /// The sender's name when it was saved.
    public var senderName: String
    public var isOwn: Bool
    /// Its text, or a photo's, video's, voice message's or file's caption ("" for none), at most
    /// `Bookmarks.bodyLimit` characters.
    public var body: String
    public var kind: Kind
    /// A file's or an audio file's name; "" for others.
    public var fileName: String
    /// When the message was sent, in milliseconds since 1970.
    public var timestamp: UInt64
    /// When it was saved, in milliseconds since 1970.
    public var savedAt: UInt64
}

/// Bookmarks: one global account data event, so they follow the account to its other devices.
/// No bridge reads account data (`NOTES.md`, "Bookmarks"), so nothing of it reaches a network.
extension MatrixAccount {
    /// The saved messages, the last saved first (empty when neither the store nor the server can
    /// say).
    public func bookmarks() async -> [Bookmark] {
        let me = (try? client.userId()) ?? ""
        return ((try? await currentBookmarks()) ?? Bookmarks()).items.map { $0.bookmark(me: me) }
    }

    /// Saves a message of an open chat (`messageId`, the chat's id for it). A message the server
    /// does not have yet cannot be saved: it has no event to open the chat at.
    @discardableResult
    public func bookmark(roomId: String, messageId: String, timeout: TimeInterval = 30) async throws -> Bookmark {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .eventId(let eventId) = event.eventOrTransactionId,
              let saved = SavedBookmark(event, roomId: roomId, eventId: eventId, savedAt: Self.now()) else {
            throw MatrixCoreError.notBookmarkable(messageId)
        }
        try await changeBookmarks { list in
            list.items.removeAll { $0.roomId == roomId && $0.eventId == eventId }
            list.items.insert(saved, at: 0)
        }
        return saved.bookmark(me: (try? client.userId()) ?? "")
    }

    /// Forgets a saved message, on every device.
    public func removeBookmark(roomId: String, eventId: String) async throws {
        try await changeBookmarks { $0.items.removeAll { $0.roomId == roomId && $0.eventId == eventId } }
    }

    /// The bookmarks this device just wrote until the store has them, else the store's. A store
    /// that has no bookmarks event yet (a device just signed in: the sync brings account data after
    /// its first sync) asks the server, so a first change does not start from an empty list.
    private func currentBookmarks() async throws -> Bookmarks {
        if let stored = try? await client.accountData(eventType: Bookmarks.type) {
            return bookmarkStates.value(stored: Bookmarks(json: stored))
        }
        let session = try savedSession()
        let onServer = try await bookmarkStates.server { try await accountDataOnServer(Bookmarks.type, session: session) }
        return bookmarkStates.value(stored: Bookmarks(json: onServer))
    }

    /// Changes the bookmarks one change at a time, from the newest this device knows, so two
    /// changes in a row both stay. The list shows a change at once.
    private func changeBookmarks(_ change: @escaping @Sendable (inout Bookmarks) -> Void) async throws {
        try await bookmarkStates.serially {
            let before = try await self.currentBookmarks()
            var list = before
            change(&list)
            if list == before { return }
            self.bookmarkStates.wrote(list)
            self.notify(.bookmarks)
            do {
                try await self.client.setAccountData(eventType: Bookmarks.type, content: list.json())
            } catch {
                self.bookmarkStates.wrote(nil)
                self.notify(.bookmarks)
                throw error
            }
        }
    }

    private static func now() -> UInt64 { UInt64((Date().timeIntervalSince1970 * 1000).rounded()) }
}

/// The event's content: `{"bookmarks": [{"room": "!…", "event": "$…", "sender": "@…", "senderName":
/// "…", "body": "…", "kind": "text", "fileName": "", "ts": <ms>, "savedAt": <ms>}]}`, the last saved
/// first. Other keys are kept as they are.
struct Bookmarks: Equatable, Sendable {
    static let type = "com.ramimaalouf.multiplexer.bookmarks"
    /// A long text is kept to its start: the list shows three lines, and the chat the rest.
    static let bodyLimit = 500

    var items: [SavedBookmark] = []
    /// The content's other keys, as JSON, so a later version's do not get lost.
    var other: String = "{}"

    init() {}

    init(json: String?) {
        guard let data = json?.data(using: .utf8),
              var content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        items = ((content["bookmarks"] as? [Any]) ?? []).compactMap { ($0 as? [String: Any]).flatMap(SavedBookmark.init(json:)) }
        content["bookmarks"] = nil
        other = String(decoding: (try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])) ?? Data("{}".utf8), as: UTF8.self)
    }

    func json() -> String {
        var content = ((try? JSONSerialization.jsonObject(with: Data(other.utf8))) as? [String: Any]) ?? [:]
        content["bookmarks"] = items.map(\.json)
        let data = (try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])) ?? Data(#"{"bookmarks":[]}"#.utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

struct SavedBookmark: Equatable, Sendable {
    var roomId: String
    var eventId: String
    var sender: String
    var senderName: String
    var body: String
    var kind: Bookmark.Kind
    var fileName: String
    var timestamp: UInt64
    var savedAt: UInt64

    init(roomId: String, eventId: String, sender: String, senderName: String, body: String, kind: Bookmark.Kind,
         fileName: String, timestamp: UInt64, savedAt: UInt64) {
        self.roomId = roomId
        self.eventId = eventId
        self.sender = sender
        self.senderName = senderName
        self.body = String(body.prefix(Bookmarks.bodyLimit))
        self.kind = kind
        self.fileName = fileName
        self.timestamp = timestamp
        self.savedAt = savedAt
    }

    /// What the list shows of a message; nil for an event that is no message (a state change, a
    /// deleted message, one this device cannot read).
    init?(_ event: EventTimelineItem, roomId: String, eventId: String, savedAt: UInt64) {
        guard case .msgLike(let like) = event.content else { return nil }
        var name = event.sender
        if case .ready(let shown?, _, _, _, _) = event.senderProfile, !shown.isEmpty { name = shown }
        var body = "", kind = Bookmark.Kind.other, fileName = ""
        switch like.kind {
        case .message(let message):
            switch message.msgType {
            case .image(let content): (kind, body) = (.image, content.caption ?? "")
            case .video(let content): (kind, body) = (.video, content.caption ?? "")
            case .file(let content): (kind, body, fileName) = (.file, content.caption ?? "", content.filename)
            case .audio(let content):
                (kind, body) = (content.voice == nil ? .audio : .voice, content.caption ?? "")
                if content.voice == nil { fileName = content.filename }
            case .text, .notice, .emote: (kind, body) = (.text, message.body)
            default: (kind, body) = (.other, message.body)
            }
        case .sticker:
            kind = .sticker
        default:
            return nil
        }
        self.init(roomId: roomId, eventId: eventId, sender: event.sender, senderName: name, body: body, kind: kind,
                  fileName: fileName, timestamp: event.timestamp, savedAt: savedAt)
    }

    init?(json: [String: Any]) {
        guard let roomId = json["room"] as? String, let eventId = json["event"] as? String, !roomId.isEmpty, !eventId.isEmpty else { return nil }
        self.init(roomId: roomId, eventId: eventId, sender: json["sender"] as? String ?? "",
                  senderName: json["senderName"] as? String ?? "", body: json["body"] as? String ?? "",
                  kind: Bookmark.Kind(rawValue: json["kind"] as? String ?? "") ?? .other, fileName: json["fileName"] as? String ?? "",
                  timestamp: (json["ts"] as? NSNumber)?.uint64Value ?? 0, savedAt: (json["savedAt"] as? NSNumber)?.uint64Value ?? 0)
    }

    var json: [String: Any] {
        ["room": roomId, "event": eventId, "sender": sender, "senderName": senderName, "body": body, "kind": kind.rawValue,
         "fileName": fileName, "ts": timestamp, "savedAt": savedAt]
    }

    func bookmark(me: String) -> Bookmark {
        Bookmark(roomId: roomId, eventId: eventId, sender: sender, senderName: senderName.isEmpty ? sender : senderName,
                 isOwn: sender == me, body: body, kind: kind, fileName: fileName, timestamp: timestamp, savedAt: savedAt)
    }
}

/// The bookmarks this device wrote, until the store has them, and the change under way.
final class BookmarkStates: @unchecked Sendable {
    /// A list the server never confirms (another device changed it) is forgotten after this.
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var written: (list: Bookmarks, since: Date)?
    private var changing: Task<Void, Error>?
    /// The server's event, read while the store has none, and when.
    private var fetched: (content: String?, at: Date)?

    /// The server's content (`fetch`), read again once it is older than `patience`; a failed read
    /// throws, so no change starts from a list this device does not know.
    func server(_ fetch: () async throws -> String?) async throws -> String? {
        if let fetched = lock.withLock({ fetched }), Date().timeIntervalSince(fetched.at) < Self.patience { return fetched.content }
        let content = try await fetch()
        lock.withLock { fetched = (content, Date()) }
        return content
    }

    func value(stored: Bookmarks) -> Bookmarks {
        lock.withLock {
            guard let written else { return stored }
            if written.list == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.list
        }
    }

    func wrote(_ list: Bookmarks?) {
        lock.withLock { written = list.map { ($0, Date()) } }
    }

    func serially(_ work: @escaping @Sendable () async throws -> Void) async throws {
        let task: Task<Void, Error> = lock.withLock {
            let before = changing
            let next = Task {
                _ = try? await before?.value
                try await work()
            }
            changing = next
            return next
        }
        try await task.value
    }
}

/// A global account data event's content on the server (`GET /user/{userId}/account_data/{type}`),
/// as JSON; nil when the account has none.
func accountDataOnServer(_ type: String, session: SavedSession) async throws -> String? {
    guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
    let url = base.appendingPathComponent("_matrix/client/v3/user").appendingPathComponent(session.userId)
        .appendingPathComponent("account_data").appendingPathComponent(type)
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    switch (response as? HTTPURLResponse)?.statusCode {
    case 200: return String(decoding: data, as: UTF8.self)
    case 404: return nil
    default: throw URLError(.badServerResponse)
    }
}
