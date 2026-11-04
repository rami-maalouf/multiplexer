import Foundation

extension Matrix {
    @MainActor func labelRequest(_ request: [String: Any]) async throws -> [String: Any] {
        let account = try await signedIn()
        if request["op"] as? String == "labels" {
            let rooms = try await account.rooms()
            let labels = await account.labels().sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return ["labels": labels.map { label in
                ["id": label.id, "name": label.name, "rooms": label.roomIds,
                 "unread": rooms.filter { label.roomIds.contains($0.id) && !$0.isHidden && $0.isLoudlyUnread }.count] as [String: Any]
            }]
        }
        guard try sendsReadReceipts(account) else { throw ExactNativeRefusal("a drive changes only a test user's labels") }
        do {
            let id = request["id"] as? String ?? ""
            switch request["action"] as? String {
            case "create": _ = try await account.createLabel(name: request["name"] as? String ?? "")
            case "rename": try await account.renameLabel(id: id, name: request["name"] as? String ?? "")
            case "delete": try await account.deleteLabel(id: id)
            case "assign":
                try await account.setLabel(id: id, roomIds: request["rooms"] as? [String] ?? [], included: request["included"] as? Bool ?? false)
            default: throw ExactNativeRefusal("a label action is create, rename, delete or assign")
            }
            return ["ok": true, "error": ""]
        } catch let error as LabelError {
            return ["ok": false, "error": error.localizedDescription]
        }
    }
}
