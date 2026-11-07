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

/// The account's lists of chats: a chat is in one of them, or deleted from this app. The
/// filter menu's choices and the filter sheet's network narrow any of them.
public enum ChatList: String, CaseIterable, Sendable {
    case inbox
    /// Archived chats (`MatrixAccount.archive`).
    case archive
    /// Chats moved to Low Priority (`MatrixAccount.setLowPriority`).
    case lowPriority
}

/// The inbox under a filter: every chat, which of them the list shows, and the pinned ones.
public struct Inbox: Equatable, Sendable {
    /// Every chat, the most recent activity first, so an open chat that leaves the list
    /// (read under Unread) still has its name.
    public var chats: [RoomSummary]
    /// The ids of the chats the list shows.
    public var listed: Set<String>
    /// The pinned chats in the inbox, in their pin order, whatever the filter.
    public var pinned: [RoomSummary]

    /// The list: the chats it shows, the most recent activity first.
    public var rooms: [RoomSummary] { chats.filter { listed.contains($0.id) } }
}

extension RoomSummary {
    /// Unread messages, or marked unread by hand.
    public var isUnread: Bool { unreadCount > 0 || isMarkedUnread }

    /// The list the chat is in; nil when it is deleted from this app, or shown inside a merged
    /// chat. An archived chat in Low Priority is in the Archive.
    public var list: ChatList? { isHidden || foldedInto != nil ? nil : (isArchived ? .archive : (isLowPriority ? .lowPriority : .inbox)) }

    /// In the inbox: not archived, in Low Priority or deleted.
    public var isInInbox: Bool { list == .inbox }

    /// Shows an unread mark in the accent: unread and not muted, or a mention. The filter
    /// sheet counts these chats; a muted chat's grey count does not count.
    public var isLoudlyUnread: Bool { (isUnread && !isMuted) || unreadMentions > 0 }

    /// Whether `list` shows this chat under `filter`. A pinned chat leaves the inbox's list only
    /// when nothing is filtered: with a filter on, the pinned chats do not show above it.
    public func matches(_ filter: RoomFilter, in list: ChatList = .inbox) -> Bool {
        guard self.list == list else { return false }
        return filter == .all ? list != .inbox || !isPinned : passes(filter)
    }

    /// Whether the filter menu's choice keeps this chat, whatever its list.
    public func passes(_ filter: RoomFilter) -> Bool {
        switch filter {
        case .all: return true
        case .unread: return isUnread
        case .unanswered: return !lastMessage.isEmpty && !lastIsOwn
        case .people: return isOneToOne
        case .groups: return !isOneToOne
        }
    }

    /// What the room list service knows of a room beside its name and last message, and the
    /// bridge's word on what the chat is (`kinds`); true when the rule waits on that word and
    /// `kinds` has none yet (`RoomKinds.ask`).
    @discardableResult
    mutating func fillKind(_ info: RoomInfo, pins: Pins, kinds: RoomKinds) -> Bool {
        isMarkedUnread = info.isMarkedUnread
        // a bridge's bot is a service member (`io.element.functional_members`): a bridged chat
        // with one person on the other network has two other members, that person and the bot.
        // a chat marked direct (`m.direct`) with a third person in it is a group. the sdk's
        // count of active service members stays 0 until the members load, so the list counts.
        let service = UInt64(info.serviceMembers.count)
        let people = info.activeMembersCount > service ? info.activeMembersCount - service : 0
        let kind = kinds.kind(id)
        isOneToOne = Self.isOneToOne(people: people, isDirect: isDirect, bridged: service > 0, kind: kind)
        isPinned = pins.isPinned(id, onServer: info.isFavourite)
        return kind == nil && Self.needsKind(people: people, isDirect: isDirect, bridged: service > 0)
    }
}

extension MatrixAccount {
    /// The chats after the first sync, the list showing `list` under `filter`. The pinned chats
    /// in the inbox come whatever the filter; the view shows them only in the inbox under `.all`.
    public func inbox(filter: RoomFilter = .all, list: ChatList = .inbox, timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        return Inbox(chats: all, listed: Set(all.filter { $0.matches(filter, in: list) }.map(\.id)),
                     pinned: Self.inPinOrder(all).filter(\.isInInbox))
    }

    /// Every non-hidden chat under `filter`, across inbox, Archive and Low Priority. The app
    /// picks the capsule list client-side so Inbox↔Archive does not wait on another rooms call.
    public func scopedInbox(filter: RoomFilter = .all, timeout: TimeInterval = 30) async throws -> Inbox {
        let all = try await rooms(timeout: timeout)
        return Inbox(chats: all,
                     listed: Set(all.filter { !$0.isHidden && $0.foldedInto == nil && $0.passes(filter) }.map(\.id)),
                     pinned: Self.inPinOrder(all).filter(\.isInInbox))
    }
}
