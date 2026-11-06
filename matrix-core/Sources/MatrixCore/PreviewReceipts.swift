import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The receipt of the list's preview when the chat's newest message is this account's own:
/// "sent" when the server has it, "seen" when another member's public read receipt is at or after
/// it, and "" when the newest message is not this account's or its state is unknown (still being
/// sent, or failed). From what the SDK already gives: the latest event has no id, so a receipt is
/// placed by its event's time against the message's time. The members looked at are the room's
/// joined members other than this account and the bridge's service members, at most 25: in a larger
/// group a reader beyond them leaves "sent", never a "seen" without evidence.
extension MatrixAccount {
    func previewStatus(_ room: Room, info: RoomInfo?, timestamp: UInt64) async -> String {
        guard let info else { return "sent" }
        let me = (try? client.userId()) ?? ""
        let others = await receipts.others(of: room, info: info, me: me)
        for user in others {
            guard let receipt = try? await room.loadUserReceipt(receiptType: .read, thread: .unthreaded, userId: user),
                  let at = await receipts.time(of: receipt.eventId, in: room) else { continue }
            if at >= timestamp { return "seen" }
        }
        return "sent"
    }
}

/// The times of the events receipts point at (an event's time never changes), and the chats whose
/// preview says "sent", which `PreviewReceiptWatch` reads again for a "seen".
final class PreviewReceipts: @unchecked Sendable {
    private let lock = NSLock()
    private var times: [String: UInt64] = [:]
    private var sent: [String: UInt64] = [:]
    /// Each room's other members, kept 10 minutes: memberships rarely change.
    private var members: [String: (ids: [String], at: Date)] = [:]
    static let memberLimit: UInt32 = 25

    /// The room's joined members other than `me` and the bridge's service members: its heroes, else
    /// the store's members, else the server's (once a room, then kept).
    func others(of room: Room, info: RoomInfo, me: String) async -> [String] {
        let id = room.id()
        if let known = lock.withLock({ members[id] }), Date().timeIntervalSince(known.at) < 600 { return known.ids }
        let keep = { (ids: [String]) in Array(ids.filter { $0 != me && !info.serviceMembers.contains($0) }.prefix(Int(Self.memberLimit))) }
        var ids = keep(info.heroes.map(\.userId))
        if ids.isEmpty, let stored = try? await room.membersNoSync() {
            ids = keep((stored.nextChunk(chunkSize: Self.memberLimit * 2) ?? []).filter { $0.membership == .join }.map(\.userId))
        }
        if ids.isEmpty, let fetched = try? await room.members() {
            ids = keep((fetched.nextChunk(chunkSize: Self.memberLimit * 2) ?? []).filter { $0.membership == .join }.map(\.userId))
        }
        let found = ids
        lock.withLock { members[id] = (found, Date()) }
        return found
    }

    func time(of eventId: String, in room: Room) async -> UInt64? {
        if let known = lock.withLock({ times[eventId] }) { return known }
        guard let event = try? await room.loadOrFetchEvent(eventId: eventId) else { return nil }
        let at = UInt64(event.timestamp())
        lock.withLock {
            if times.count > 2000 { times.removeAll() }
            times[eventId] = at
        }
        return at
    }

    /// After a list read: the chats whose own newest message is still only "sent", by its time.
    func remember(_ rooms: [RoomSummary]) {
        let pending = rooms.filter { $0.lastStatus == "sent" && $0.mergeId == nil }
        lock.withLock { sent = Dictionary(pending.prefix(30).map { ($0.id, $0.lastTimestamp) }, uniquingKeysWith: { a, _ in a }) }
    }

    var waiting: [String: UInt64] { lock.withLock { sent } }
    /// Seen now: the watch stops reading it, until a list read finds it "sent" again.
    func seen(_ roomId: String) { _ = lock.withLock { sent.removeValue(forKey: roomId) } }
}

/// Reads again, every `interval` seconds while the account syncs, the receipts of the chats whose
/// preview says "sent": another member's receipt changes no room in the room list, so nothing else
/// tells the list. Local reads only (the store), at most 30 chats; `changed` when one is now seen.
final class PreviewReceiptWatch: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let lock = NSLock()

    func start(_ account: MatrixAccount, interval: TimeInterval = 2, changed: @escaping @Sendable () -> Void) {
        let task = Task { [weak account] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let account, !Task.isCancelled else { return }
                for (id, timestamp) in account.receipts.waiting {
                    guard let room = try? account.client.getRoom(roomId: id) else { continue }
                    let info = try? await room.roomInfo()
                    if await account.previewStatus(room, info: info, timestamp: timestamp) == "seen" {
                        account.receipts.seen(id)
                        changed()
                    }
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
