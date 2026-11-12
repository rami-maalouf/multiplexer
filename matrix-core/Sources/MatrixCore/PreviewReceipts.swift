import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The receipt of the list's preview when the chat's newest message is this account's own:
/// "sent" when the server has it, "seen" when another member's public read receipt is at or after
/// it, and "" when the newest message is not this account's or its state is unknown (still being
/// sent, or failed). From what the SDK already gives: the latest event has no id, so a receipt is
/// placed by its event's time against the message's time. That time can be this device's clock (the
/// SDK keeps a message's local time after it is sent, until a sync brings the server's copy), and a
/// receipt's event has the server's: a device clock a few milliseconds ahead left a read message
/// "sent". So a receipt on this account's own message with the same text, less than a minute before
/// the message's time, also counts: it is the same message. The members looked at are the room's
/// joined members other than this account and the bridge's service members, at most 25: in a larger
/// group a reader beyond them leaves "sent", never a "seen" without evidence.
extension MatrixAccount {
    /// Whether the list's receipt watch reads: off while the app is in the background or the chat
    /// list is not on screen.
    public func watchPreviewReceipts(_ on: Bool) { receiptWatch.setActive(on) }

    func previewStatus(_ room: Room, info: RoomInfo?, timestamp: UInt64, text: String) async -> String {
        guard let info else { return "sent" }
        let me = (try? client.userId()) ?? ""
        let others = await receipts.others(of: room, info: info, me: me)
        for user in others {
            guard let receipt = try? await room.loadUserReceipt(receiptType: .read, thread: .unthreaded, userId: user),
                  let read = await receipts.event(receipt.eventId, in: room) else { continue }
            if read.at >= timestamp { return "seen" }
            if read.sender == me, !text.isEmpty, read.text == text, timestamp - read.at < 60_000 { return "seen" }
        }
        return "sent"
    }
}

/// The events receipts point at (their time, sender and text never change), and the chats whose
/// preview says "sent", which `PreviewReceiptWatch` reads again for a "seen".
final class PreviewReceipts: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String: ReadEvent] = [:]
    private var sent: [String: (timestamp: UInt64, text: String)] = [:]
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

    struct ReadEvent { let at: UInt64; let sender: String; let text: String? }

    func event(_ eventId: String, in room: Room) async -> ReadEvent? {
        if let known = lock.withLock({ events[eventId] }) { return known }
        guard let event = try? await room.loadOrFetchEvent(eventId: eventId) else { return nil }
        let read = ReadEvent(at: UInt64(event.timestamp()), sender: event.senderId(), text: Self.text(of: event))
        lock.withLock {
            if events.count > 2000 { events.removeAll() }
            events[eventId] = read
        }
        return read
    }

    /// A text, notice or emote message's words, as the list shows them; nil for anything else.
    static func text(of event: TimelineEvent) -> String? {
        guard case .messageLike(let content)? = try? event.content(), case .roomMessage(let type, _) = content else { return nil }
        switch type {
        case .text(let c): return FormattedText.plain(c.body, c.formatted)
        case .notice(let c): return FormattedText.plain(c.body, c.formatted)
        case .emote(let c): return FormattedText.plain(c.body, c.formatted)
        default: return nil
        }
    }

    /// After a list read: the chats whose own newest message is still only "sent", by its time.
    func remember(_ rooms: [RoomSummary]) {
        let pending = rooms.filter { $0.lastStatus == "sent" && $0.mergeId == nil }
        lock.withLock { sent = Dictionary(pending.prefix(30).map { ($0.id, (timestamp: $0.lastTimestamp, text: $0.lastMessage)) }, uniquingKeysWith: { a, _ in a }) }
    }

    var waiting: [String: (timestamp: UInt64, text: String)] { lock.withLock { sent } }
    /// Seen now: the watch stops reading it, until a list read finds it "sent" again.
    func seen(_ roomId: String) { _ = lock.withLock { sent.removeValue(forKey: roomId) } }
}

/// Reads again, every `interval` seconds while the account syncs, the receipts of the chats whose
/// preview says "sent": another member's receipt changes no room in the room list, so nothing else
/// tells the list. Local reads only (the store), at most 30 chats; `changed` when one is now seen.
/// It reads nothing while the app says the list is hidden or the app is in the background
/// (`MatrixAccount.watchPreviewReceipts`).
final class PreviewReceiptWatch: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private let lock = NSLock()
    /// Off while the app is in the background or the list is not on screen: no reads then.
    private var active = true
    func setActive(_ on: Bool) { lock.withLock { active = on } }

    func start(_ account: MatrixAccount, interval: TimeInterval = 2, changed: @escaping @Sendable () -> Void) {
        let task = Task { [weak account, unowned self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let account, !Task.isCancelled else { return }
                guard self.lock.withLock({ self.active }) else { continue }
                for (id, last) in account.receipts.waiting {
                    guard let room = try? account.client.getRoom(roomId: id) else { continue }
                    let info = try? await room.roomInfo()
                    if await account.previewStatus(room, info: info, timestamp: last.timestamp, text: last.text) == "seen" {
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
