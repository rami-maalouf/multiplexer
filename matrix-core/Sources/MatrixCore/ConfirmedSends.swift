import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

extension MatrixAccount {
    /// sends plain text and returns the server's event id, without using the local send queue
    /// or clearing another client's composer draft. the sdk handles room encryption.
    public func sendTextConfirmed(roomId: String, text: String, timeout: TimeInterval = 120) async throws -> String {
        let target = try await room(roomId, timeout: timeout)
        let content = try JSONSerialization.data(withJSONObject: ["msgtype": "m.text", "body": text])
        return try await target.sendRaw(eventType: "m.room.message", content: String(decoding: content, as: UTF8.self))
    }

    /// adds a reaction, without toggling an existing one, and returns its server event id.
    /// this is deliberately not the interactive timeline's optimistic toggle operation.
    public func addReactionConfirmed(roomId: String, eventId: String, key: String, timeout: TimeInterval = 120) async throws -> String {
        let target = try await room(roomId, timeout: timeout)
        // fetching through this room refuses an event from another room.
        _ = try await target.loadOrFetchEvent(eventId: eventId)
        let content = try JSONSerialization.data(withJSONObject: ["m.relates_to": ["rel_type": "m.annotation", "event_id": eventId, "key": key]])
        return try await target.sendRaw(eventType: "m.reaction", content: String(decoding: content, as: UTF8.self))
    }
}
