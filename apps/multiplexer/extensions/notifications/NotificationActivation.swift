import Foundation

enum NotificationActivation {
    // pinned exact host contract; scripts/notification-activation.test.ts exercises its receiver.
    static func userInfo(_ payload: [AnyHashable: Any], userId: String?) -> [AnyHashable: Any] {
        var info = payload
        info.removeValue(forKey: "exact")
        info.removeValue(forKey: "navigate")
        guard let userId, !userId.isEmpty,
              let room = info["room_id"] as? String, !room.isEmpty,
              let event = info["event_id"] as? String, !event.isEmpty else { return info }
        let tag = "chat:\(userId):\(room)"
        let args: [Any] = [tag, ["tag": tag, "data": room, "title": "", "body": NSNull()]]
        guard let data = try? JSONSerialization.data(withJSONObject: args),
              let encoded = String(data: data, encoding: .utf8) else { return info }
        info["exact"] = ["session": "main", "owner": "mux-notification-service",
                         "process": UUID().uuidString, "extension": "notifications",
                         "event": "notificationclick", "args": encoded]
        return info
    }
}
