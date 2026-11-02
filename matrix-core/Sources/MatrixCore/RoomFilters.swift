import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Which chats the inbox's list shows: the filter menu's choices.
public enum RoomFilter: String, CaseIterable, Sendable {
    /// Every chat that is not pinned: the pinned ones show above the list.
    case all
    /// Chats with unread messages, or marked unread by hand.
    case unread
    /// Chats whose newest message is not this account's.
    case unanswered
    /// Chats with one other person.
    case people
    /// Every other chat.
    case groups
}

/// The inbox under a filter: every chat, which of them the list shows, and the pinned ones.
public struct Inbox: Equatable, Sendable {
    /// Every chat, the most recent activity first, so an open chat that leaves the list
    /// (read under Unread) still has its name.
    public var chats: [RoomSummary]
    /// The ids of the chats the list shows.
    public var listed: Set<String>
    /// The pinned chats, in their pin order, whatever the filter.
    public var pinned: [RoomSummary]

    /// The list: the chats it shows, the most recent activity first.
    public var rooms: [RoomSummary] { chats.filter { listed.contains($0.id) } }
}

extension RoomSummary {
    /// Unread messages, or marked unread by hand.
    public var isUnread: Bool { unreadCount > 0 || isMarkedUnread }

    /// Whether the list shows this chat under `filter`. A pinned chat leaves the list only
    /// when nothing is filtered: with a filter on, the pinned chats do not show above it.
    public func matches(_ filter: RoomFilter) -> Bool {
        switch filter {
        case .all: return !isPinned
        case .unread: return isUnread
        case .unanswered: return !lastMessage.isEmpty && !lastIsOwn
        case .people: return isOneToOne
        case .groups: return !isOneToOne
        }
    }

    /// What the room list service knows of a room beside its name and last message.
    mutating func fillKind(_ info: RoomInfo, pins: Pins) {
        isMarkedUnread = info.isMarkedUnread
        // a bridge's bot is a service member (`io.element.functional_members`): a bridged chat
        // with one person on the other network has two other members, that person and the bot.
        // a chat marked direct (`m.direct`) with a third person in it is a group. the sdk's
        // count of active service members stays 0 until the members load, so the list counts.
        let service = UInt64(info.serviceMembers.count)
        let people = info.activeMembersCount > service ? info.activeMembersCount - service : 0
        isOneToOne = people <= 2 && (isDirect || service > 0)
        isPinned = pins.isPinned(id, onServer: info.isFavourite)
    }
}

extension MatrixAccount {
    /// The inbox after the first sync, its list filtered by `filter`. The pinned chats come
    /// whatever the filter; the view shows them only when it is `.all`.
    public func inbox(filter: RoomFilter = .all, timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        return Inbox(chats: all, listed: Set(all.filter { $0.matches(filter) }.map(\.id)), pinned: Self.inPinOrder(all))
    }
}
