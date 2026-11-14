import Foundation
import UserNotifications

enum ChatNotifications {
    static func identifiers(_ requests: [UNNotificationRequest], userId: String, roomId: String) -> [String] {
        guard !userId.isEmpty, !roomId.isEmpty else { return [] }
        let tag = "chat:\(userId):\(roomId)"
        return requests.compactMap { request in
            let info = request.content.userInfo
            // a room alone cannot establish which account received an older notification.
            guard info["room_id"] as? String == roomId,
                  let entry = info["exact"] as? [String: Any],
                  entry["extension"] as? String == "notifications",
                  entry["event"] as? String == "notificationclick",
                  let encoded = entry["args"] as? String,
                  let args = try? JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [Any],
                  args.count == 2, args[0] as? String == tag,
                  let event = args[1] as? [String: Any],
                  event["tag"] as? String == tag, event["data"] as? String == roomId else { return nil }
            return request.identifier
        }
    }

    @MainActor static func clear(userId: String, roomId: String, currentUser: () throws -> String?) async throws -> Int {
        guard !userId.isEmpty, !roomId.isEmpty, try currentUser() == userId else { return 0 }
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        guard try currentUser() == userId else { return 0 }
        let ids = identifiers(delivered.map(\.request), userId: userId, roomId: roomId)
        if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
        return ids.count
    }
}
