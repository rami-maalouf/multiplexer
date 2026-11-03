import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A space the account has joined, as the filter sheet lists it after the networks: a WhatsApp
/// community (the bridge makes one space for each, holding its groups), or a space of Matrix.
/// A bridge's own space, which holds every chat of its network, is not one: the network's row
/// already shows those chats (`Community.isBridgeSpace`).
public struct Community: Equatable, Sendable {
    /// The space's room id.
    public var id: String
    public var name: String
    /// The space's picture, as `RoomSummary.avatarName` names a room's ("" for none).
    public var avatarName: String
    /// The chats in it: the space's rooms, and the rooms of the spaces inside it.
    public var rooms: Set<String>
}

/// A community and its unread chats in the inbox, as the filter sheet counts them.
public struct CommunityCount: Equatable, Sendable {
    public var id: String
    public var name: String
    public var avatarName: String
    public var unread: Int
}

extension Community {
    /// A bridge's own space (mautrix bridgev2's space for each login, "WhatsApp (+1 555 ...)"):
    /// the bridge does not serve it as a chat (it names no service members, which each
    /// community's space has), and its only members besides this account are the bridge's bots.
    static func isBridgeSpace(serviceMembers: [String], members: [String], ownUserId: String) -> Bool {
        let others = members.filter { $0 != ownUserId }
        return serviceMembers.isEmpty && !others.isEmpty && others.allSatisfy {
            RoomNetwork.network(ofBridgeUser: $0) != nil && $0.dropFirst().prefix { $0 != ":" }.lowercased().hasSuffix("bot")
        }
    }

    /// Each space's chats, from each room's parent spaces (`parents`: a chat's or a space's): a
    /// chat counts for its parents and for all their ancestors. A loop in the graph ends.
    static func chatsOfSpaces(parents: [String: [String]], chats: Set<String>) -> [String: Set<String>] {
        var rooms: [String: Set<String>] = [:]
        for chat in chats {
            var seen: Set<String> = [], next = parents[chat] ?? []
            while let space = next.popLast() {
                guard seen.insert(space).inserted else { continue }
                rooms[space, default: []].insert(chat)
                next += parents[space] ?? []
            }
        }
        return rooms
    }

    /// The communities in the filter sheet's order: by name, as Beeper lists them. A space whose
    /// chats this account has none of is left out: it would filter to an empty list.
    static func listed(_ spaces: [Community], chats: Set<String>) -> [Community] {
        spaces.map { Community(id: $0.id, name: $0.name, avatarName: $0.avatarName, rooms: $0.rooms.intersection(chats)) }
            .filter { !$0.rooms.isEmpty }
            .sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
    }
}

extension Inbox {
    /// The inbox narrowed to one community's chats, as `on(network:)` narrows it to a
    /// network's. nil keeps every chat.
    public func on(community: Community?) -> Inbox {
        guard let community else { return self }
        return Inbox(chats: chats, listed: listed.intersection(community.rooms), pinned: pinned.filter { community.rooms.contains($0.id) })
    }

    /// Each community with its unread chats in the inbox, whatever the filter and the list shown.
    public func counts(of communities: [Community]) -> [CommunityCount] {
        communities.map { c in
            CommunityCount(id: c.id, name: c.name, avatarName: c.avatarName,
                           unread: chats.filter { c.rooms.contains($0.id) && $0.isInInbox && $0.isLoudlyUnread }.count)
        }
    }
}

extension MatrixAccount {
    /// The spaces this account has joined, without the bridges' own, each with its chats, in the
    /// filter sheet's order.
    public func communities(timeout: TimeInterval = 30) async throws -> [Community] {
        await communities(among: try await rooms(timeout: timeout))
    }

    /// The communities, each with only the chats of `chats` (the chats an `Inbox` holds). A
    /// space's chats come from the sdk's space graph (built from the rooms' `m.space.child` and
    /// `m.space.parent` state): each chat's parent spaces, and their parents in turn, so a space
    /// holds the chats of the spaces inside it, at any depth (the sdk's space filters stop at
    /// two levels). A new device knows a space only once its first sync has brought the space's
    /// room: on a bridged account with 300 chats, after about a minute.
    public func communities(among chats: [RoomSummary]) async -> [Community] {
        let chatIds = Set(chats.map(\.id))
        let me = (try? client.userId()) ?? ""
        let service = await client.spaceService()
        // the graph is built from the joined rooms' space state; this asks for its latest.
        _ = await service.topLevelJoinedSpaces()
        let joinedSpaces = client.rooms().filter { $0.membership() == .joined && $0.isSpace() }
        var parents: [String: [String]] = [:]
        for id in chatIds.union(joinedSpaces.map { $0.id() }) {
            parents[id] = (try? await service.joinedParentIdsOfChild(childId: id)) ?? []
        }
        let rooms = Community.chatsOfSpaces(parents: parents, chats: chatIds)
        var spaces: [Community] = []
        for space in joinedSpaces {
            guard let info = try? await space.roomInfo() else { continue }
            // only a space with no service members and few members can be a bridge's own.
            if info.serviceMembers.isEmpty && space.joinedMembersCount() <= 3 {
                var members: [String] = []
                if let iterator = try? await space.members() {
                    while let chunk = iterator.nextChunk(chunkSize: 50) {
                        members += chunk.filter { $0.membership == .join }.map { $0.userId }
                    }
                }
                if Community.isBridgeSpace(serviceMembers: info.serviceMembers, members: members, ownUserId: me) { continue }
            }
            spaces.append(Community(id: space.id(), name: space.displayName() ?? space.id(),
                                    avatarName: space.avatarUrl().map(avatarFileName) ?? "", rooms: rooms[space.id()] ?? []))
        }
        return Community.listed(spaces, chats: chatIds)
    }
}
