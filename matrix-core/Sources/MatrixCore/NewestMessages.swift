import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The newest message of a chat whose sdk latest event is empty, read from the server, so its row has
/// a preview and a time as its chat shows them. The sdk computes the latest event from the events this
/// device has; the room list syncs only each room's newest event, so a chat whose newest event is no
/// message (a reaction, a member's new picture, a redaction) has none until it is opened, and on a new
/// device most bridged chats have none (seen 2026-11-06: 132 of 187 chats). Each such chat is asked
/// once per launch; what is found is kept in the account's store folder, so the next launch shows it
/// at once. A newer message replaces it: the sdk has every message that comes by sync.
final class NewestMessages: @unchecked Sendable {
    struct Found: Codable, Equatable {
        var eventId: String
        var timestamp: UInt64
        var sender: String
        var senderName: String
        var isOwn: Bool
        var preview: String
    }

    /// At most this many chats are asked at once.
    static let width = 4
    private let file: URL?
    private let lock = NSLock()
    private var found: [String: Found]
    private var asked: Set<String> = []
    private var changed = false
    /// The asks under way, which a sign-out stops and waits for: a request still running when the
    /// client signs out made the sign-out fail, and the device stayed on the server (seen 2026-11-06).
    private var running: [Task<Void, Never>] = []
    private var stopped = false

    /// `file`: where they are kept; nil keeps them in memory only.
    init(file: URL?) {
        self.file = file
        let data = file.flatMap { try? Data(contentsOf: $0) }
        found = data.flatMap { try? JSONDecoder().decode([String: Found].self, from: $0) } ?? [:]
    }

    func newest(_ roomId: String) -> Found? { lock.withLock { found[roomId] } }

    /// Fills a summary from the newest message found for its chat; false when none is known yet.
    func fill(_ summary: inout RoomSummary) -> Bool {
        guard let newest = newest(summary.id) else { return false }
        summary.lastTimestamp = newest.timestamp
        summary.lastMessage = newest.preview
        summary.lastSenderName = newest.senderName
        summary.lastIsOwn = newest.isOwn
        return true
    }

    /// Asks the server for each chat's newest message, `width` at a time, each chat once per launch;
    /// `done` runs (and what is found is written) after each `batch` chats with a message, and at the end.
    func ask(_ roomIds: [String], batch: Int = 8, fetch: @escaping @Sendable (String) async -> Found?, done: @escaping @Sendable () -> Void) {
        let todo = lock.withLock { () -> [String] in
            guard !stopped else { return [] }
            let todo = roomIds.filter { !asked.contains($0) }
            asked.formUnion(todo)
            return todo
        }
        guard !todo.isEmpty else { return }
        let task = Task.detached(priority: .utility) { [weak self] in
            var unsaid = 0
            await withTaskGroup(of: (String, Found?).self) { group in
                var next = todo.makeIterator()
                for _ in 0..<Self.width { if let id = next.next() { group.addTask { (id, await fetch(id)) } } }
                for await (id, newest) in group {
                    if let newest, let self {
                        self.lock.withLock {
                            if self.found[id] != newest { self.found[id] = newest; self.changed = true }
                        }
                        unsaid += 1
                        if unsaid >= batch {
                            unsaid = 0
                            self.save()
                            done()
                        }
                    }
                    if !Task.isCancelled, let id = next.next() { group.addTask { (id, await fetch(id)) } }
                }
            }
            self?.save()
            if unsaid > 0, !Task.isCancelled { done() }
        }
        // an ask that begins as a sign-out stops is stopped at once.
        if lock.withLock({ running.append(task); return stopped }) { task.cancel() }
    }

    /// Stops the asks under way and waits for them to end; no ask starts after.
    func stop() async {
        let tasks = lock.withLock { () -> [Task<Void, Never>] in
            stopped = true
            defer { running = [] }
            return running
        }
        for task in tasks { task.cancel() }
        for task in tasks { await task.value }
    }

    /// Writes them, if one changed since the last write.
    func save() {
        let data: Data? = lock.withLock {
            guard changed else { return nil }
            changed = false
            return try? JSONEncoder().encode(found)
        }
        if let data, let file { try? data.write(to: file, options: .atomic) }
    }
}

extension MatrixAccount {
    /// The chat's newest message on the server: the newest message, sticker, poll or encrypted event
    /// that is no edit and not deleted, read through the sdk (which decrypts it), with its preview as
    /// the list shows one. Nil when there is none or the server cannot be asked.
    func newestMessage(roomId: String) async -> NewestMessages.Found? {
        guard let session = try? savedSession(), let room = try? client.getRoom(roomId: roomId),
              let ids = try? await newestMessageIds(roomId: roomId, session: session) else { return nil }
        let me = (try? client.userId()) ?? ""
        for id in ids {
            guard !Task.isCancelled else { return nil }
            guard let event = try? await room.loadOrFetchEvent(eventId: id),
                  case .messageLike(let content)? = try? event.content() else { continue }
            let text: String
            switch content {
            case .roomMessage(let type, _): text = preview(type)
            case .sticker: text = "Sticker"
            case .poll(let question): text = question
            case .roomEncrypted: text = "Encrypted message"
            default: continue
            }
            let sender = event.senderId()
            let name = (try? await room.memberDisplayName(userId: sender)) ?? nil
            return NewestMessages.Found(eventId: id, timestamp: event.timestamp(), sender: sender,
                                        senderName: name.flatMap { $0.isEmpty ? nil : $0 } ?? sender,
                                        isOwn: sender == me, preview: text)
        }
        return nil
    }
}

/// The ids of a room's newest message events on the server, newest first (`GET /rooms/{id}/messages`,
/// backwards from the room's end): no edit (its message is older), no deleted message.
func newestMessageIds(roomId: String, session: SavedSession, limit: Int = 20) async throws -> [String] {
    guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
    let filter = #"{"types":["m.room.message","m.sticker","m.room.encrypted","m.poll.start","org.matrix.msc3381.poll.start"]}"#
    var url = URLComponents(url: base.appendingPathComponent("_matrix/client/v3/rooms").appendingPathComponent(roomId)
        .appendingPathComponent("messages"), resolvingAgainstBaseURL: false)
    url?.queryItems = [URLQueryItem(name: "dir", value: "b"), URLQueryItem(name: "limit", value: String(limit)),
                       URLQueryItem(name: "filter", value: filter)]
    guard let address = url?.url else { throw URLError(.badURL) }
    var request = URLRequest(url: address, timeoutInterval: 15)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return newestMessageIds(json: data)
}

/// The usable ids of a `/messages` answer, in its order: an edit (`m.replace`) and a deleted event
/// (no content) are left out.
func newestMessageIds(json data: Data) -> [String] {
    guard let answer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let chunk = answer["chunk"] as? [[String: Any]] else { return [] }
    return chunk.compactMap { event in
        guard let id = event["event_id"] as? String, let content = event["content"] as? [String: Any], !content.isEmpty else { return nil }
        if let relation = content["m.relates_to"] as? [String: Any], relation["rel_type"] as? String == "m.replace" { return nil }
        return id
    }
}
