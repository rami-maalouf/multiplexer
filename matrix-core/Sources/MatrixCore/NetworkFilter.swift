import Foundation

/// A network the account has chats on, as the filter sheet lists it.
public struct NetworkCount: Equatable, Sendable {
    /// `whatsapp`, `instagram`, ..., or `matrix` (`RoomSummary.network`).
    public var network: String
    /// Its chats with unread messages, or marked unread by hand.
    public var unread: Int
}

extension Inbox {
    /// The inbox narrowed to one network: the list shows only its chats, under the same
    /// filter, and only its pinned chats show above the list. nil keeps every network.
    /// Every chat stays in `chats`, so an open chat keeps its name.
    public func on(network: String?) -> Inbox {
        guard let network else { return self }
        let theirs = Set(chats.filter { $0.network == network }.map(\.id))
        return Inbox(chats: chats, listed: listed.intersection(theirs), pinned: pinned.filter { $0.network == network })
    }

    /// Each network the account has chats on, in `RoomNetwork.all`'s order (Matrix first),
    /// with its unread chats. Whatever the filter: the sheet counts every chat.
    public var networks: [NetworkCount] {
        var unread: [String: Int] = [:]
        for chat in chats { unread[chat.network, default: 0] += chat.isUnread ? 1 : 0 }
        let order = RoomNetwork.all
        return unread.keys.sorted { (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1) ?? order.count, $1) }
            .map { NetworkCount(network: $0, unread: unread[$0] ?? 0) }
    }

    /// The chats with unread messages, or marked unread by hand, on every network.
    public var unreadChats: Int { chats.filter(\.isUnread).count }
}

extension MatrixAccount {
    /// The inbox after the first sync, its list filtered by `filter` and narrowed to one
    /// `network` (nil: every network).
    public func inbox(filter: RoomFilter, network: String?, timeout: TimeInterval = 30) async throws -> Inbox {
        try await inbox(filter: filter, timeout: timeout).on(network: network)
    }
}
