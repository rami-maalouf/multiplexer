import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The newest message each chat's preview showed, kept in the account's store folder, so the list
/// says "Message deleted" when the newest message was deleted, as the chat does. The sdk's latest
/// event leaves deleted messages out: after a delete it goes back to the message before. So a
/// latest event older than the message shown before means that message was deleted. Kept across
/// launches, this also catches a delete made while the app was closed, once the list showed the
/// message.
final class LatestMessages: @unchecked Sendable {
    struct Shown: Codable, Equatable {
        var timestamp: UInt64
        var senderName: String
        var isOwn: Bool
    }

    private let file: URL?
    private let lock = NSLock()
    private var shown: [String: Shown]
    private var changed = false

    /// `file`: where they are kept; nil keeps them in memory only.
    init(file: URL?) {
        self.file = file
        let data = file.flatMap { try? Data(contentsOf: $0) }
        shown = data.flatMap { try? JSONDecoder().decode([String: Shown].self, from: $0) } ?? [:]
    }

    /// Fills a summary whose newest message is on the server: "Message deleted" when the newest
    /// message shown before is newer than it, else that message is the one shown. The time stays
    /// the latest event's, as for a delete seen in an open chat (`fillDeleted`).
    func fill(_ summary: inout RoomSummary) {
        lock.withLock {
            guard summary.lastTimestamp > 0, !summary.lastMessage.isEmpty else { return }
            if let before = shown[summary.id], summary.lastTimestamp < before.timestamp {
                summary.lastMessage = "Message deleted"
                summary.lastSenderName = before.senderName
                summary.lastIsOwn = before.isOwn
                return
            }
            let now = Shown(timestamp: summary.lastTimestamp, senderName: summary.lastSenderName, isOwn: summary.lastIsOwn)
            if shown[summary.id] != now {
                shown[summary.id] = now
                changed = true
            }
        }
    }

    /// Writes them, if one changed since the last write.
    func save() {
        let data: Data? = lock.withLock {
            guard changed else { return nil }
            changed = false
            return try? JSONEncoder().encode(shown)
        }
        if let data, let file { try? data.write(to: file, options: .atomic) }
    }
}

/// Watches the account data that another device of the account changes and the room list does
/// not show: the archived and deleted chats (`ChatMarks`) and the own names (`CustomNames`). The
/// sdk observes only its own types, so this reads them from the store (no request) every
/// `interval` seconds while the account syncs, and calls `changed` when one differs.
final class AccountDataWatch: @unchecked Sendable {
    static let types = [ChatMarks.type, CustomNames.type]
    private var task: Task<Void, Never>?
    private let lock = NSLock()

    func start(_ client: Client, interval: TimeInterval = 2, changed: @escaping @Sendable () -> Void) {
        let task = Task {
            var last: [String: String] = [:]
            for type in Self.types { last[type] = (try? await client.accountData(eventType: type)) ?? "" }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                var now: [String: String] = [:]
                for type in Self.types { now[type] = (try? await client.accountData(eventType: type)) ?? "" }
                if now != last, !Task.isCancelled {
                    last = now
                    changed()
                }
            }
        }
        lock.withLock {
            self.task?.cancel()
            self.task = task
        }
    }

    func stop() {
        lock.withLock {
            task?.cancel()
            task = nil
        }
    }

    deinit { task?.cancel() }
}
