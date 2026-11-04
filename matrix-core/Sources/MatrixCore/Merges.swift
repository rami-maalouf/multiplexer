import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// One person's chats on several networks shown as one chat (Merge Chats): its name, its rooms in
/// the order they were picked, and the room a new message goes to when no other is meant.
public struct ChatMerge: Equatable, Sendable {
    public var id: String
    public var name: String
    public var rooms: [String]
    public var defaultRoom: String

    public init(id: String, name: String, rooms: [String], defaultRoom: String) {
        self.id = id
        self.name = name
        self.rooms = rooms
        self.defaultRoom = defaultRoom
    }

    /// The list's id for the merged chat.
    public var chatId: String { MergeStore.prefix + id }
}

/// The account's merges: one global account data event, so its other devices show the same merged
/// chats, default included; no bridge reads it. Each network chat stays its own room.
enum MergeStore {
    static let type = "com.ramimaalouf.multiplexer.merges"
    static let prefix = "merge:"

    /// From `{"merges": [{"id", "name", "rooms": [...], "default"}]}`; one with fewer than two rooms
    /// is none.
    static func merges(json: String?) -> [ChatMerge] {
        guard let data = json?.data(using: .utf8),
              let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let all = content["merges"] as? [[String: Any]] else { return [] }
        return all.compactMap { m in
            guard let id = m["id"] as? String, let rooms = m["rooms"] as? [String], rooms.count >= 2 else { return nil }
            let fallback = rooms[0], chosen = m["default"] as? String ?? fallback
            return ChatMerge(id: id, name: m["name"] as? String ?? "", rooms: rooms, defaultRoom: rooms.contains(chosen) ? chosen : fallback)
        }
    }

    static func json(_ merges: [ChatMerge]) -> String {
        let all = merges.map { ["id": $0.id, "name": $0.name, "rooms": $0.rooms, "default": $0.defaultRoom] as [String: Any] }
        let data = (try? JSONSerialization.data(withJSONObject: ["merges": all], options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// The chats with each merge's rooms folded into one chat (`ChatMerge.chatId`) where at least
    /// two of them are there: the merge's name, the newest message of its rooms, their unread counts
    /// added, every network in the merge's order, the soonest reminder. Its lists and marks are
    /// those of the room with the newest message (a new message brings an archived room back). It
    /// opens that room when its newest message is someone else's, else the default room. The
    /// folded rooms stay, in no list, so an open one keeps its name.
    static func fold(_ rooms: [RoomSummary], _ merges: [ChatMerge]) -> [RoomSummary] {
        var out = rooms
        for merge in merges {
            let members = merge.rooms.compactMap { id in out.firstIndex { $0.id == id } }
            guard members.count >= 2 else { continue }
            let chats = members.map { out[$0] }
            guard let lead = chats.max(by: { $0.lastTimestamp < $1.lastTimestamp }) else { continue }
            var row = lead
            row.id = merge.chatId
            row.name = merge.name.isEmpty ? lead.name : merge.name
            row.roomName = row.name
            row.unreadCount = chats.reduce(0) { $0 + $1.unreadCount }
            row.unreadMentions = chats.reduce(0) { $0 + $1.unreadMentions }
            row.isMarkedUnread = chats.contains { $0.isMarkedUnread }
            row.isMuted = chats.allSatisfy(\.isMuted)
            row.isPinned = chats.contains(where: \.isPinned)
            row.pinOrder = chats.compactMap(\.pinOrder).min()
            row.reminderAt = chats.compactMap(\.reminderAt).min()
            row.isOneToOne = true
            row.mergeId = merge.id
            row.mergeRooms = chats.map { MergedRoom(id: $0.id, network: $0.network) }
            let present = chats.map(\.id)
            row.opens = !lead.lastIsOwn && lead.lastTimestamp > 0 ? lead.id : (present.contains(merge.defaultRoom) ? merge.defaultRoom : lead.id)
            for i in members { out[i].foldedInto = merge.id }
            out.insert(row, at: members.min()!)
        }
        return out
    }
}

/// A room of a merged chat, and its network.
public struct MergedRoom: Equatable, Sendable {
    public var id: String
    public var network: String
}

extension RoomSummary {
    /// Every network the chat is on: a merged chat's, else its own.
    public var networks: [String] { mergeRooms.isEmpty ? [network] : mergeRooms.map(\.network) }
    /// The room the chat opens: a merged chat's choice (`MergeStore.fold`), else itself.
    public var opensRoom: String { opens ?? id }
}

/// The merges this device wrote and the server has not confirmed, and one change at a time.
final class MergeStates: @unchecked Sendable {
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var written: (merges: [ChatMerge], since: Date)?
    private var changing: Task<Void, Error>?

    func merges(stored: [ChatMerge]) -> [ChatMerge] {
        lock.withLock {
            guard let written else { return stored }
            if written.merges == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.merges
        }
    }

    func wrote(_ merges: [ChatMerge]?) { lock.withLock { written = merges.map { ($0, Date()) } } }

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

extension MatrixAccount {
    /// The account's merged chats: those this device just wrote until the store has them.
    public func merges() async -> [ChatMerge] {
        let stored = MergeStore.merges(json: (try? await client.accountData(eventType: MergeStore.type)) ?? nil)
        return mergeStates.merges(stored: stored)
    }

    /// Merges `rooms` (two or more) into one chat named `name`, sending to `defaultRoom` when no
    /// other is meant. A room already in another merge leaves it. Returns the merged chat's id.
    @discardableResult
    public func merge(rooms: [String], name: String, defaultRoom: String) async throws -> String {
        let unique = rooms.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        guard unique.count >= 2 else { throw MatrixCoreError.mergeNeedsTwo }
        for roomId in unique { _ = try await room(roomId, timeout: 30) }
        let made = ChatMerge(id: UUID().uuidString.lowercased(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                             rooms: unique, defaultRoom: unique.contains(defaultRoom) ? defaultRoom : unique[0])
        try await changeMerges { all in
            all = all.map { var m = $0; m.rooms.removeAll { unique.contains($0) }; return m }.filter { $0.rooms.count >= 2 }
            for i in all.indices where !all[i].rooms.contains(all[i].defaultRoom) { all[i].defaultRoom = all[i].rooms[0] }
            all.append(made)
        }
        return made.chatId
    }

    /// Takes a merge apart: its rooms show as their own chats again. `id` is the merge's id or its chat's.
    public func unmerge(_ id: String) async throws {
        let key = id.hasPrefix(MergeStore.prefix) ? String(id.dropFirst(MergeStore.prefix.count)) : id
        try await changeMerges { all in all.removeAll { $0.id == key } }
    }

    /// The rooms a chat id stands for: a merged chat's rooms, else the room itself.
    public func roomsOf(_ chatId: String) async -> [String] {
        guard chatId.hasPrefix(MergeStore.prefix) else { return [chatId] }
        let key = String(chatId.dropFirst(MergeStore.prefix.count))
        return await merges().first { $0.id == key }?.rooms ?? []
    }

    /// Each merge's rooms folded into one chat (`MergeStore.fold`).
    func fillMerges(_ rooms: inout [RoomSummary]) async {
        let merges = await merges()
        guard !merges.isEmpty else { return }
        rooms = MergeStore.fold(rooms, merges)
    }

    private func changeMerges(_ change: @escaping @Sendable (inout [ChatMerge]) -> Void) async throws {
        try await mergeStates.serially {
            // the store's merges, else the server's: a new device must not start from none.
            var all = self.mergeStates.merges(stored: MergeStore.merges(json: try await self.accountDataForChange(MergeStore.type)))
            let before = all
            change(&all)
            guard all != before else { return }
            self.mergeStates.wrote(all)
            self.notify(.rooms)
            do {
                try await self.client.setAccountData(eventType: MergeStore.type, content: MergeStore.json(all))
            } catch {
                self.mergeStates.wrote(nil)
                self.notify(.rooms)
                throw error
            }
        }
    }
}
