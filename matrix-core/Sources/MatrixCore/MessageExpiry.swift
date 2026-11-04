import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A chat's message expiry (WhatsApp's disappearing messages, B20): how long a message stays
/// after it is sent. The bridge says in the room which timers its network takes
/// (`com.beeper.room_features`, `disappearing_timer`), and keeps the chat's timer in a room
/// state event (`com.beeper.disappearing_timer`); a new one from here goes to the network.
public struct MessageExpiry: Equatable, Sendable {
    /// In milliseconds; 0 when messages stay.
    public var timer: Int
    /// The timers the network takes, in milliseconds, shortest first.
    public var choices: [Int]
}

/// Why a timer was not set.
public enum MessageExpiryError: Error, Equatable {
    /// The chat's network takes no such timer (or none at all).
    case notOffered
}

extension MatrixAccount {
    static let expiryFeatures = "com.beeper.room_features"
    static let expiryTimer = "com.beeper.disappearing_timer"

    /// The chat's message expiry; nil when its network has none (a plain Matrix chat, or a
    /// network the bridge gives no timers).
    public func messageExpiry(roomId: String) async throws -> MessageExpiry? {
        let session = try client.session()
        guard let features = try await roomState(roomId: roomId, type: Self.expiryFeatures, session: session),
              let offered = features["disappearing_timer"] as? [String: Any],
              (offered["types"] as? [String] ?? []).contains("after_send") else { return nil }
        let choices = (offered["timers"] as? [NSNumber] ?? []).map(\.intValue).filter { $0 > 0 }.sorted()
        guard !choices.isEmpty else { return nil }
        let current = try await roomState(roomId: roomId, type: Self.expiryTimer, session: session)
        let timer = current?["type"] as? String == "after_send" ? ((current?["timer"] as? NSNumber)?.intValue ?? 0) : 0
        return MessageExpiry(timer: timer, choices: choices)
    }

    /// Sets the chat's message expiry: one of its choices, or 0 to keep messages. The bridge
    /// sets the same timer on the network.
    public func setMessageExpiry(roomId: String, timer: Int, timeout: TimeInterval = 30) async throws {
        if timer != 0 {
            guard let expiry = try await messageExpiry(roomId: roomId), expiry.choices.contains(timer) else {
                throw MessageExpiryError.notOffered
            }
        }
        let content = timer == 0 ? "{}" : "{\"type\":\"after_send\",\"timer\":\(timer)}"
        _ = try await room(roomId, timeout: timeout).sendStateEventRaw(eventType: Self.expiryTimer, stateKey: "", content: content)
    }
}

/// A room state event's content (`GET .../rooms/{roomId}/state/{type}`); nil when the room has none.
private func roomState(roomId: String, type: String, session: Session) async throws -> [String: Any]? {
    guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
    let url = base.appendingPathComponent("_matrix/client/v3/rooms").appendingPathComponent(roomId)
        .appendingPathComponent("state").appendingPathComponent(type)
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    switch (response as? HTTPURLResponse)?.statusCode {
    case 200: return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    case 404: return nil
    default: throw URLError(.badServerResponse)
    }
}
