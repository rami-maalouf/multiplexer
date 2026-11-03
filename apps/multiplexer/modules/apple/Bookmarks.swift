import Foundation

/// Bookmarks (B14, B20): what app.ts's bookmark sources ask, answered with MatrixCore's Bookmarks.swift.
extension Matrix {
    @MainActor func bookmarks(_ request: [String: Any]) async throws -> [String: Any] {
        let account = try await signedIn()
        let roomId = request["roomId"] as? String ?? ""
        switch request["op"] as? String {
        case "bookmarks":
            // the last saved first, each with its chat as the list shows it; a chat the account
            // left is not shown.
            let saved = await account.bookmarks()
            let byId = Dictionary(try await account.rooms().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return ["bookmarks": saved.compactMap { b -> [String: Any]? in
                guard let chat = byId[b.roomId] else { return nil }
                return ["room": b.roomId, "event": b.eventId, "chatName": chat.name, "network": chat.network,
                        "avatar": cached(chat.avatarName, topic: "bookmarks") { _ = try await account.avatarFile(roomId: chat.id, directory: self.media) },
                        "senderName": b.senderName, "isOwn": b.isOwn, "body": b.body, "kind": b.kind.rawValue,
                        "fileName": b.fileName, "time": Double(b.timestamp)]
            }]
        default:
            // the writes: a drive makes them only as a test user, as it reacts. Nothing of a
            // bookmark reaches the chat or its network.
            guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's bookmarks") }
            switch request["op"] as? String {
            case "bookmark": try await account.bookmark(roomId: roomId, messageId: request["messageId"] as? String ?? "")
            case "removeBookmark": try await account.removeBookmark(roomId: roomId, eventId: request["eventId"] as? String ?? "")
            default: throw ExactNativeRefusal("bookmarks answers bookmarks, bookmark and removeBookmark")
            }
            return ["ok": true]
        }
    }
}
