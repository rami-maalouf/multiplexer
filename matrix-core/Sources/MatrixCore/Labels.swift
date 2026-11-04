import CryptoKit
import Foundation

// a private group of chats. ids stay stable when a label is renamed.
public struct ChatLabel: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var roomIds: [String]

    public func contains(_ chat: RoomSummary) -> Bool {
        roomIds.contains(chat.id) || chat.mergeRooms.contains { roomIds.contains($0.id) }
    }
}

public enum LabelError: Error, LocalizedError, Equatable {
    case emptyName, duplicateName, notFound

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a name for the label."
        case .duplicateName: return "A label with that name already exists."
        case .notFound: return "That label was deleted on another device."
        }
    }
}

enum LabelStore {
    static let type = "com.ramimaalouf.multiplexer.labels"
    static let prefix = type + ".v2."
    static let markerType = type + ".changed"

    struct Marker: Codable, Sendable {
        var revision = UUID().uuidString
    }

    // the original document is a read-only baseline. no migration rewrites another device's data.
    // old builds cannot read the new overrides; upgrade them before editing labels there.
    struct Content: Codable, Equatable, Sendable {
        var labels: [ChatLabel]
        var revision: String?
    }

    static func read(_ json: String?) throws -> Content {
        guard let json else { return Content(labels: [], revision: nil) }
        return try JSONDecoder().decode(Content.self, from: Data(json.utf8))
    }

    static func json<T: Encodable>(_ content: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(content), as: UTF8.self)
    }

    // each name, deletion and room membership has its own key. a rename cannot replace members,
    // and two additions to different rooms cannot replace each other. the server orders writes
    // to the same field (last write wins); this is not compare-and-swap.
    struct Field: Codable, Equatable, Sendable {
        var id: String
        var name: String? = nil
        var roomId: String? = nil
        var included: Bool? = nil
        var deleted: Bool? = nil

        var type: String {
            if name != nil { return prefix + "name." + Self.digest([id]) }
            if deleted != nil { return prefix + "deleted." + Self.digest([id]) }
            return prefix + "room." + Self.digest([id, roomId ?? ""])
        }

        var isValid: Bool {
            !id.isEmpty && ((name != nil && roomId == nil && included == nil && deleted == nil) ||
                (name == nil && roomId != nil && included != nil && deleted == nil) ||
                (name == nil && roomId == nil && included == nil && deleted == true))
        }

        private static func digest(_ parts: [String]) -> String {
            // length framing avoids ambiguous pairs, and hashing bounds event types even for long ids.
            let framed = parts.map { "\($0.utf8.count):\($0)" }.joined()
            return SHA256.hash(data: Data(framed.utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    struct Snapshot: Equatable, Sendable {
        var legacy = Content(labels: [], revision: nil)
        var fields: [String: Field] = [:]

        var labels: [ChatLabel] {
            var byId: [String: ChatLabel] = [:]
            var order: [String] = []
            for label in legacy.labels {
                if byId[label.id] == nil { order.append(label.id) }
                byId[label.id] = label
            }
            for field in fields.values {
                guard let name = field.name else { continue }
                var label = byId[field.id] ?? ChatLabel(id: field.id, name: "", roomIds: [])
                label.name = name
                byId[field.id] = label
            }
            for field in fields.values where field.roomId != nil {
                guard var label = byId[field.id], let room = field.roomId else { continue }
                var members = Set(label.roomIds)
                if field.included == true { members.insert(room) } else { members.remove(room) }
                label.roomIds = members.sorted()
                byId[field.id] = label
            }
            // deletion has a separate permanent key, so stale names or membership never resurrect it.
            for field in fields.values where field.deleted == true { byId[field.id] = nil }
            let existing = Set(order)
            order += byId.keys.filter { !existing.contains($0) }.sorted()
            return order.compactMap { byId[$0] }
        }

        static func readSync(_ data: Data) throws -> Snapshot {
            guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  response["next_batch"] is String else { throw URLError(.badServerResponse) }
            var snapshot = Snapshot()
            guard let accountData = response["account_data"] else { return snapshot }
            guard let accountData = accountData as? [String: Any],
                  let events = accountData["events"] as? [[String: Any]] else { throw URLError(.badServerResponse) }
            for event in events {
                guard let eventType = event["type"] as? String else { throw URLError(.badServerResponse) }
                let isField = ["name.", "deleted.", "room."].contains { eventType.hasPrefix(prefix + $0) }
                guard eventType == type || isField else { continue }
                guard let content = event["content"] as? [String: Any] else { throw URLError(.badServerResponse) }
                let contentData = try JSONSerialization.data(withJSONObject: content)
                if eventType == type {
                    snapshot.legacy = try JSONDecoder().decode(Content.self, from: contentData)
                } else {
                    let field = try JSONDecoder().decode(Field.self, from: contentData)
                    guard field.isValid, field.type == eventType else { throw URLError(.badServerResponse) }
                    snapshot.fields[eventType] = field
                }
            }
            return snapshot
        }
    }

    enum Mutation: Sendable {
        case create(ChatLabel), rename(String, String), delete(String), membership(String, [String], Bool)

        func fields(in snapshot: Snapshot) throws -> [Field] {
            let labels = snapshot.labels
            switch self {
            case .create(let label):
                try Self.checkName(label.name, among: labels)
                return [Field(id: label.id, name: label.name)]
            case .rename(let id, let name):
                guard labels.contains(where: { $0.id == id }) else { throw LabelError.notFound }
                try Self.checkName(name, among: labels.filter { $0.id != id })
                return [Field(id: id, name: name)]
            case .delete(let id):
                return [Field(id: id, deleted: true)]
            case .membership(let id, let rooms, let included):
                guard labels.contains(where: { $0.id == id }) else { throw LabelError.notFound }
                // write intent even if the snapshot already agrees: a concurrent opposite edit
                // must still be ordered against this explicit assignment by the server.
                return Set(rooms).sorted().map { Field(id: id, roomId: $0, included: included) }
            }
        }

        private static func checkName(_ name: String, among labels: [ChatLabel]) throws {
            guard !name.isEmpty else { throw LabelError.emptyName }
            guard !labels.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw LabelError.duplicateName }
        }
    }
}

// serialize discoveries and writes locally so a slow read cannot overwrite an acknowledged edit.
// cross-device safety comes from independent server keys, not this queue or a local override.
final class LabelStates: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: LabelStore.Snapshot?
    private var changing: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var loadedGeneration: UInt64?

    func invalidate() {
        lock.withLock { generation &+= 1 }
    }

    func labels(fetch: @escaping @Sendable () async throws -> LabelStore.Snapshot,
                changed: @escaping @Sendable () -> Void = {}) async throws -> [ChatLabel] {
        try await serially {
            let (cached, generation, loaded) = self.lock.withLock { (self.snapshot, self.generation, self.loadedGeneration) }
            if let cached, loaded == generation { return cached.labels }
            let snapshot = try await fetch()
            let invalidatedDuringRead = self.lock.withLock {
                self.snapshot = snapshot
                self.loadedGeneration = generation
                return self.generation != generation
            }
            // a consumer may have coalesced the marker's notification into its pending read.
            // deliver it again after this read, and leave the cache dirty for its next read.
            if invalidatedDuringRead { changed() }
            return snapshot.labels
        }
    }

    func change(_ mutation: LabelStore.Mutation,
                fetch: @escaping @Sendable () async throws -> LabelStore.Snapshot,
                write: @escaping @Sendable (LabelStore.Field) async throws -> Void,
                mark: @escaping @Sendable () async throws -> Void,
                changed: @escaping @Sendable () -> Void) async throws {
        try await serially {
            let generation = self.lock.withLock { self.generation }
            var snapshot = try await fetch()
            self.publish(snapshot, generation: generation, changed: changed)
            let fields = try mutation.fields(in: snapshot)
            do {
                for field in fields {
                    try await write(field)
                    snapshot.fields[field.type] = field
                }
                // the marker is an invalidation, not an index. the last of overlapping markers
                // follows every successful writer's fields, so one discovery sees all of them.
                // return success only after it is accepted; a crash or failure before it leaves
                // an unacknowledged write that a retry or new device's snapshot discovers.
                try await mark()
                self.publish(snapshot, generation: generation, changed: changed)
            } catch {
                // no optimistic success. multi-room assignment may have written some fields;
                // invalidate so the caller's next read discovers what the server accepted.
                self.invalidate()
                changed()
                throw error
            }
        }
    }

    private func publish(_ snapshot: LabelStore.Snapshot, generation: UInt64, changed: @Sendable () -> Void) {
        let differs = lock.withLock {
            let differs = self.snapshot?.labels != snapshot.labels
            self.snapshot = snapshot
            self.loadedGeneration = generation
            return differs
        }
        if differs { changed() }
    }

    private func serially<T: Sendable>(_ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = lock.withLock {
            let before = changing
            let next = Task { await before?.value; return try await work() }
            changing = Task { _ = try? await next.value }
            return next
        }
        return try await task.value
    }
}

extension MatrixAccount {
    public func labels() async throws -> [ChatLabel] {
        try await startSync(timeout: 30)
        return try await labelStates.labels(fetch: { try await labelSnapshotOnServer(session: self.savedSession()) },
                                            changed: { self.notify(.rooms) })
    }

    // names are trimmed and checked against the observed snapshot. matrix has no atomic name
    // reservation: simultaneous same-name creates on different ids both survive. keep both so
    // no label or membership disappears; the user can rename or delete either one afterwards.
    public func createLabel(name: String) async throws -> ChatLabel {
        let label = ChatLabel(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines), roomIds: [])
        try await changeLabels(.create(label))
        return label
    }

    // like creation, duplicate-name validation covers the observed snapshot, not concurrent edits.
    public func renameLabel(id: String, name: String) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try await changeLabels(.rename(id, name))
    }

    // deleting a label never changes its chats, messages or list placement.
    public func deleteLabel(id: String) async throws {
        try await changeLabels(.delete(id))
    }

    public func setLabel(id: String, roomIds: [String], included: Bool) async throws {
        var expanded = Set<String>()
        for chatId in roomIds {
            let rooms = await roomsOf(chatId)
            guard !rooms.isEmpty else { throw MatrixCoreError.noRoom(chatId) }
            expanded.formUnion(rooms)
        }
        for roomId in expanded { _ = try await room(roomId, timeout: 30) }
        try await changeLabels(.membership(id, expanded.sorted(), included))
    }

    public func labelInbox(id: String, filter: RoomFilter = .all, network: String? = nil,
                           timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        let label = try await labels().first { $0.id == id }
        return Inbox(chats: all, listed: Set(all.filter { !$0.isHidden && $0.foldedInto == nil && label?.contains($0) == true && $0.passes(filter) }.map(\.id)),
                     pinned: Self.inPinOrder(all).filter(\.isInInbox)).on(network: network)
    }

    private func changeLabels(_ mutation: LabelStore.Mutation) async throws {
        try await startSync(timeout: 30)
        try await labelStates.change(mutation, fetch: { try await labelSnapshotOnServer(session: self.savedSession()) },
            write: { try await self.client.setAccountData(eventType: $0.type, content: LabelStore.json($0)) },
            mark: { try await self.publishLabelChange() },
            changed: { self.notify(.rooms) })
    }

    func publishLabelChange() async throws {
        try await client.setAccountData(eventType: LabelStore.markerType, content: LabelStore.json(LabelStore.Marker()))
    }
}

// the sdk exposes account data only by a known type. a filtered initial sync discovers all
// label fields, including records made while this device was offline. never pass `since` or
// consume `next_batch`: a second sync cursor on this device could acknowledge to-device messages
// before the sdk handles them. only account data is used; the sdk owns rooms and encryption.
// one snapshot at first read, on an observed marker/legacy change, or to validate a mutation.
// clean reads use the cache; the existing watch polls only sdk-local values, never this endpoint.
// tombstones are retained for the account's life.
func labelSnapshotOnServer(session: SavedSession) async throws -> LabelStore.Snapshot {
    let request = try labelSnapshotRequest(session: session)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    return try LabelStore.Snapshot.readSync(data)
}

func labelSnapshotRequest(session: SavedSession) throws -> URLRequest {
    guard let base = URL(string: session.homeserverUrl),
          var url = URLComponents(url: base.appendingPathComponent("_matrix/client/v3/sync"), resolvingAgainstBaseURL: false)
    else { throw URLError(.badURL) }
    // synapse caches identical initial syncs, including their old account data. a request-scoped,
    // unused type makes this filter fresh without advancing a second device cursor. it adds no
    // stored record and does not change which label fields match the wildcard.
    let discovery = LabelStore.type + ".discovery." + UUID().uuidString
    let filter: [String: Any] = ["account_data": ["types": [LabelStore.type, LabelStore.prefix + "*", discovery]],
                                "presence": ["types": []], "room": ["rooms": []]]
    let encoded = String(decoding: try JSONSerialization.data(withJSONObject: filter, options: [.sortedKeys]), as: UTF8.self)
    url.queryItems = [URLQueryItem(name: "filter", value: encoded), URLQueryItem(name: "timeout", value: "0")]
    guard let endpoint = url.url else { throw URLError(.badURL) }
    var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    return request
}
