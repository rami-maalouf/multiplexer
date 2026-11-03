import Foundation

/// A chat's info page (B20): what app.ts's info sources ask, answered with MatrixCore's ChatInfo.swift.
extension Matrix {
    @MainActor func info(_ request: [String: Any]) async throws -> [String: Any] {
        let account = try await signedIn()
        let roomId = request["roomId"] as? String ?? ""
        func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
        switch request["op"] as? String {
        case "chatInfo":
            let info = try await account.chatInfo(roomId: roomId)
            return ["id": info.id, "name": info.name, "roomName": info.roomName, "customName": info.customName,
                    "topic": info.topic, "network": info.network, "isOneToOne": info.isOneToOne,
                    "memberCount": info.memberCount, "canRename": info.canRename,
                    "canChangePicture": info.canChangePicture, "canInvite": info.canInvite,
                    "picture": cached(MatrixAccount.largePictureName(info.pictureUrl), then: .info(roomId)) {
                        _ = try await account.chatPicture(roomId: roomId, directory: self.media) }]
        case "chatMembers":
            // the first `limit` by name, each with their picture, and how many there are.
            let all = try await account.chatMembers(roomId: roomId)
            return ["total": all.count, "members": all.prefix(int(request["limit"])).map { member in
                ["id": member.userId, "name": member.name, "isOwn": member.isOwn,
                 "picture": cached(member.pictureName, then: .info(roomId)) {
                     _ = try await account.pictureFile(url: member.pictureUrl, directory: self.media) }]
            }]
        case "chatMedia":
            let media = try await account.recentMedia(roomId: roomId, limit: int(request["limit"]))
            return ["media": media.map { item in
                ["id": item.id, "isVideo": item.isVideo, "time": Double(item.timestamp), "senderName": item.senderName,
                 "isOwn": item.isOwn, "caption": item.caption, "width": item.width, "height": item.height,
                 "duration": item.duration,
                 "image": cached(item.thumbnailName, then: .info(roomId)) {
                     if item.isVideo {
                         _ = try await account.videoPoster(roomId: roomId, messageId: item.id, directory: self.media)
                     } else {
                         _ = try await account.imageFile(roomId: roomId, messageId: item.id, full: false, directory: self.media)
                     }
                 }]
            }]
        default:
            // the writes: a drive makes them only as a test user, as it reacts. A new name and a
            // new picture reach the chat's network through its bridge; a name only you see does not.
            guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's chats") }
            switch request["op"] as? String {
            case "rename": try await account.setRoomName(roomId: roomId, name: request["name"] as? String ?? "")
            case "customName": try await account.setCustomName(roomId: roomId, name: request["name"] as? String ?? "")
            case "invite": try await account.invite(roomId: roomId, userId: request["userId"] as? String ?? "")
            case "setPicture":
                guard let file = appFile(request["path"] as? String ?? "") else { throw ExactNativeRefusal("setPicture takes an app:/tmp path") }
                try await account.setRoomPicture(roomId: roomId, file: file, mimetype: request["mimetype"] as? String ?? "image/jpeg",
                                                 width: int(request["width"]), height: int(request["height"]))
            default: throw ExactNativeRefusal("info answers chatInfo, chatMembers, chatMedia, rename, customName, invite and setPicture")
            }
            return ["ok": true]
        }
    }
}
