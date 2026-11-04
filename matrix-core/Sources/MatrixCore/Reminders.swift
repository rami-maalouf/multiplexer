import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A reminder to answer a chat: when it is due, and when it was asked for. Both in
/// milliseconds since 1970.
public struct Reminder: Equatable, Sendable {
    public var roomId: String
    public var at: UInt64
    public var setAt: UInt64

    public init(roomId: String, at: UInt64, setAt: UInt64) {
        self.roomId = roomId
        self.at = at
        self.setAt = setAt
    }

    /// Answered: the chat's newest message is the account's own, sent after the reminder was asked for.
    public func isAnswered(by chat: RoomSummary) -> Bool { chat.lastIsOwn && chat.lastTimestamp > setAt }
}

/// The account's reminders: one global account data event, so its other devices have them too,
/// and no bridge reads it.
enum ReminderStore {
    static let type = "com.ramimaalouf.multiplexer.reminders"

    /// From the event's content, `{"reminders": {"<room id>": {"at": <ms>, "set": <ms>}}}`.
    static func reminders(json: String?) -> [String: Reminder] {
        guard let data = json?.data(using: .utf8),
              let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let all = content["reminders"] as? [String: Any] else { return [:] }
        var out: [String: Reminder] = [:]
        for (roomId, value) in all {
            guard let entry = value as? [String: Any], let at = (entry["at"] as? NSNumber)?.uint64Value else { continue }
            out[roomId] = Reminder(roomId: roomId, at: at, setAt: (entry["set"] as? NSNumber)?.uint64Value ?? 0)
        }
        return out
    }

    static func json(_ reminders: [String: Reminder]) -> String {
        let all = reminders.mapValues { ["at": $0.at, "set": $0.setAt] }
        let data = (try? JSONSerialization.data(withJSONObject: ["reminders": all], options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// The reminders this device wrote and the server has not confirmed, and one change at a time.
final class ReminderStates: @unchecked Sendable {
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var written: (reminders: [String: Reminder], since: Date)?
    private var changing: Task<Void, Error>?

    func reminders(stored: [String: Reminder]) -> [String: Reminder] {
        lock.withLock {
            guard let written else { return stored }
            if written.reminders == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.reminders
        }
    }

    func wrote(_ reminders: [String: Reminder]?) {
        lock.withLock { written = reminders.map { ($0, Date()) } }
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

extension MatrixAccount {
    /// Reminds the account to answer the chat at `at`; a chat has one reminder, so this moves an
    /// earlier one. Other devices of the account see it in its account data.
    public func setReminder(roomId: String, at: Date, timeout: TimeInterval = 30) async throws {
        _ = try await room(roomId, timeout: timeout)
        let now = UInt64((Date().timeIntervalSince1970 * 1000).rounded())
        try await changeReminders {
            $0[roomId] = Reminder(roomId: roomId, at: UInt64((at.timeIntervalSince1970 * 1000).rounded()), setAt: now)
        }
    }

    /// Takes the chat's reminder away.
    public func clearReminder(roomId: String) async throws {
        try await changeReminders { $0[roomId] = nil }
    }

    /// The account's reminders, by room: those this device just wrote until the store has them,
    /// else the store's.
    public func reminders() async -> [String: Reminder] {
        let stored = ReminderStore.reminders(json: (try? await client.accountData(eventType: ReminderStore.type)) ?? nil)
        return reminderStates.reminders(stored: stored)
    }

    /// The chats with a reminder, under the filter menu's choice, whatever their list; a chat
    /// deleted from this app shows nowhere. Narrowed to one `network` (nil: every network).
    public func reminderList(filter: RoomFilter = .all, network: String? = nil, timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        let listed = all.filter { !$0.isHidden && $0.foldedInto == nil && $0.reminderAt != nil && $0.passes(filter) }
        return Inbox(chats: all, listed: Set(listed.map(\.id)), pinned: Self.inPinOrder(all).filter(\.isInInbox)).on(network: network)
    }

    /// Each chat says when its reminder is due. One answered since it was asked for has none,
    /// and is taken from the account's reminders.
    func fillReminders(_ rooms: inout [RoomSummary]) async {
        let reminders = await reminders()
        guard !reminders.isEmpty else { return }
        var answered: [String] = []
        for i in rooms.indices {
            guard let reminder = reminders[rooms[i].id] else { continue }
            if reminder.isAnswered(by: rooms[i]) { answered.append(rooms[i].id) } else { rooms[i].reminderAt = reminder.at }
        }
        guard !answered.isEmpty else { return }
        let ended = answered
        Task { try? await self.changeReminders { all in for id in ended { all[id] = nil } } }
    }

    private func changeReminders(_ change: @escaping @Sendable (inout [String: Reminder]) -> Void) async throws {
        try await reminderStates.serially {
            var all = await self.reminders()
            let before = all
            change(&all)
            guard all != before else { return }
            self.reminderStates.wrote(all)
            self.notify(.rooms)
            do {
                try await self.client.setAccountData(eventType: ReminderStore.type, content: ReminderStore.json(all))
            } catch {
                self.reminderStates.wrote(nil)
                self.notify(.rooms)
                throw error
            }
        }
    }
}
