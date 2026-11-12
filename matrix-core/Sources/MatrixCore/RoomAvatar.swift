import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

extension MatrixAccount {
    // bridges can publish the person's profile picture without publishing m.room.avatar.
    // resolve from the same state in the inbox, chat info and image downloads.
    func roomAvatar(_ room: Room, info supplied: RoomInfo? = nil, oneToOne: Bool? = nil) async -> String? {
        if let url = room.avatarUrl(), !url.isEmpty { return url }
        let resolved: RoomInfo?
        if let supplied { resolved = supplied }
        else { resolved = try? await room.roomInfo() }
        guard let info = resolved else { return nil }
        let me = (try? client.userId()) ?? ""
        let direct: Bool
        if let oneToOne { direct = oneToOne }
        else {
            var summary = RoomSummary(id: room.id(), name: "", isDirect: await room.isDirect(),
                                      lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
            summary.fillKind(info, pins: pins, kinds: roomKinds)
            direct = summary.isOneToOne
        }
        guard direct else { return nil }
        let heroes = info.heroes.filter { $0.userId != me && !info.serviceMembers.contains($0.userId) }
        if heroes.count == 1, let url = heroes[0].avatarUrl, !url.isEmpty { return url }
        // named bridge rooms may have no heroes; use their already-synced memberships.
        guard let members = try? await room.membersNoSync() else { return nil }
        var others: [RoomMember] = []
        while let chunk = members.nextChunk(chunkSize: 32) {
            others += chunk.filter { $0.membership == .join && $0.userId != me && !$0.isServiceMember
                && !info.serviceMembers.contains($0.userId) }
            if others.count > 1 { return nil }
        }
        guard others.count == 1, let url = others[0].avatarUrl, !url.isEmpty else { return nil }
        return url
    }
}
