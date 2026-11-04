import Foundation

/// A network the account has chats on, as the filter sheet lists it.
public struct NetworkCount: Equatable, Sendable {
    /// `whatsapp`, `instagram`, ..., or `matrix` (`RoomSummary.network`).
    public var network: String
    /// Its chats in the inbox with an unread mark in the accent (`RoomSummary.isLoudlyUnread`).
    public var unread: Int
}

extension Inbox {
    /// The inbox narrowed to one network: the list shows only its chats, under the same
    /// filter, and only its pinned chats show above the list. nil keeps every network.
    /// Every chat stays in `chats`, so an open chat keeps its name.
    public func on(network: String?) -> Inbox {
        guard let network else { return self }
        let theirs = Set(chats.filter { $0.networks.contains(network) }.map(\.id))
        return Inbox(chats: chats, listed: listed.intersection(theirs), pinned: pinned.filter { $0.networks.contains(network) })
    }

    /// Each network the account has chats on, in `RoomNetwork.all`'s order (Matrix first),
    /// with its unread chats in the inbox. Whatever the filter and the list shown.
    public var networks: [NetworkCount] {
        var unread: [String: Int] = [:]
        // a merged chat counts under each of its networks; its folded rooms count nowhere.
        for chat in chats where chat.foldedInto == nil {
            for network in chat.networks { unread[network, default: 0] += chat.isInInbox && chat.isLoudlyUnread ? 1 : 0 }
        }
        let order = RoomNetwork.all
        return unread.keys.sorted { (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1) ?? order.count, $1) }
            .map { NetworkCount(network: $0, unread: unread[$0] ?? 0) }
    }

    /// The inbox's unread chats on every network.
    public var unreadChats: Int { unreadChats(in: .inbox) }

    /// A list's chats with an unread mark in the accent, on every network: a muted chat counts
    /// only with a mention.
    public func unreadChats(in list: ChatList) -> Int { chats.filter { $0.list == list && $0.isLoudlyUnread }.count }
}

extension MatrixAccount {
    /// The chats after the first sync, the list showing `list` under `filter`, narrowed to one
    /// `network` (nil: every network).
    public func inbox(filter: RoomFilter, list: ChatList = .inbox, network: String?, timeout: TimeInterval = 30) async throws -> Inbox {
        try await inbox(filter: filter, list: list, timeout: timeout).on(network: network)
    }
}
