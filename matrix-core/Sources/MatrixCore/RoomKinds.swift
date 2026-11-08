import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// What a bridged chat is on its network, as its bridge says in the room's `m.bridge` state
/// (`com.beeper.room_type`, mautrix-go bridgev2; Beeper reads the same). The member count cannot
/// tell a group with one other person from a chat with one person: both have that person and the
/// bridge's bot. The sync does not bring `m.bridge` (`matrix-core/NOTES.md`, "A chat's network"),
/// so it is read from the server, only for a chat the count and `m.direct` leave open.
public enum BridgedKind: String, Codable, Sendable {
    /// A chat with one person on its network (`dm`).
    case direct
    /// A group (no room type, `group_dm`, or a space's).
    case group
    /// The room has no bridge state: the member count decides.
    case unknown

    /// From a `GET /rooms/{id}/state` answer; nil when it is not a list of events.
    static func of(state data: Data) -> BridgedKind? {
        guard let events = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        let bridges = events.filter { ["m.bridge", "uk.half-shot.bridge"].contains($0["type"] as? String) }
            .compactMap { $0["content"] as? [String: Any] }
        guard !bridges.isEmpty else { return .unknown }
        let direct = bridges.contains { content in
            ["com.beeper.room_type", "com.beeper.room_type.v2"].contains { content[$0] as? String == "dm" }
        }
        return direct ? .direct : .group
    }
}

extension RoomSummary {
    /// The filter menu's rule (`isOneToOne`): `people` are the room's members but the bridge's
    /// service members. More than 2 is a group. Marked direct (`m.direct`, which a bridge sets for
    /// its chats with one person) is a chat with one person. A bridged room not marked direct is
    /// what its bridge says it is (`kind`), else, with no bridge state or not asked yet, a chat
    /// with one person, as the count says. Any other room is a group.
    static func isOneToOne(people: UInt64, isDirect: Bool, bridged: Bool, kind: BridgedKind?) -> Bool {
        guard people <= 2 else { return false }
        if isDirect { return true }
        return bridged && kind != .group
    }

    /// Whether the rule above waits on the bridge's word for this room.
    static func needsKind(people: UInt64, isDirect: Bool, bridged: Bool) -> Bool {
        people <= 2 && !isDirect && bridged
    }
}

/// The bridged kinds read from the server, kept in the account's store folder: a chat's kind does
/// not change, so each successful lookup is cached, and the next launch (and the notification extension,
/// which opens the same folder) has it at once.
final class RoomKinds: @unchecked Sendable {
    static let fileName = "room-kinds.json"
    private let file: URL?
    private let lock = NSLock()
    private var kinds: [String: BridgedKind]
    private var inFlight: Set<String> = []
    /// The asks under way, which a sign-out stops and waits for (as `NewestMessages`).
    private var running: [Task<Void, Never>] = []
    private var stopped = false

    /// `file`: where they are kept; nil keeps them in memory only.
    init(file: URL?) {
        self.file = file
        let data = file.flatMap { try? Data(contentsOf: $0) }
        kinds = data.flatMap { try? JSONDecoder().decode([String: BridgedKind].self, from: $0) } ?? [:]
    }

    /// The kept kinds of a store folder, for the notification extension.
    static func stored(in storeDirectory: URL) -> RoomKinds {
        RoomKinds(file: storeDirectory.appendingPathComponent(fileName))
    }

    func kind(_ roomId: String) -> BridgedKind? { lock.withLock { kinds[roomId] } }

    /// Keeps a kind read now (the info page reads one at once).
    func remember(_ roomId: String, _ kind: BridgedKind) {
        let changed = lock.withLock { () -> Bool in
            guard kinds[roomId] != kind else { return false }
            kinds[roomId] = kind
            return true
        }
        if changed { save() }
    }

    /// Asks the server for each room's kind not known yet, one request per room at a time.
    /// Failed lookups can be retried by a later ask; `done` runs once when one is found.
    func ask(_ roomIds: [String], fetch: @escaping @Sendable (String) async -> BridgedKind?, done: @escaping @Sendable () -> Void) {
        lock.withLock {
            guard !stopped else { return }
            let todo = roomIds.filter { kinds[$0] == nil && inFlight.insert($0).inserted }
            guard !todo.isEmpty else { return }
            let task = Task.detached(priority: .utility) { [weak self] in
                var found = false
                for id in todo {
                    let kind = Task.isCancelled ? nil : await fetch(id)
                    if let self {
                        self.lock.withLock {
                            if let kind { self.kinds[id] = kind }
                            self.inFlight.remove(id)
                        }
                    }
                    if kind != nil { found = true }
                }
                if found, let self, !Task.isCancelled {
                    self.save()
                    done()
                }
            }
            // stop must see the task before it can return, even if this ask has just begun.
            running.append(task)
        }
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

    private func save() {
        lock.withLock {
            if let file, let data = try? JSONEncoder().encode(kinds) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }
}

extension MatrixAccount {
    /// The room's bridged kind, read from the server's state of the room; nil when it cannot be
    /// asked. Asked only for a room of at most two people besides its bridge's bot, so the state
    /// is small.
    func bridgedKind(roomId: String) async -> BridgedKind? {
        guard let session = try? savedSession(), let base = URL(string: session.homeserverUrl) else { return nil }
        let url = base.appendingPathComponent("_matrix/client/v3/rooms").appendingPathComponent(roomId).appendingPathComponent("state")
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return BridgedKind.of(state: data)
    }
}
