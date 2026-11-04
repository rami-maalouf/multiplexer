@testable import MatrixCore
import XCTest

/// A chat's message expiry, as a test user, in a room of its own where the test plays the
/// bridge: it posts the timers the network takes (`com.beeper.room_features`), as the WhatsApp
/// bridge does in each of its rooms.
final class MessageExpiryTests: XCTestCase {
    private let roomName = "Multiplexer expiry test"

    func testAMessageExpiryIsReadSetAndCleared() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let existing = try await account.rooms(timeout: 120).first { $0.name == roomName }?.id
        let roomId: String
        if let existing { roomId = existing } else { roomId = try await account.createRoom(name: roomName) }
        let session = try account.savedSession()

        // a room with no timers offered has no message expiry.
        _ = try await api("PUT", ["rooms", roomId, "state", MatrixAccount.expiryFeatures], [:], session: session)
        let none = try await account.messageExpiry(roomId: roomId)
        XCTAssertNil(none, "a room whose network takes no timer offers one")

        // the bridge's timers: 24 hours, 7 days and 90 days, after a message is sent.
        let day = 86_400_000, week = 604_800_000, quarter = 7_776_000_000
        _ = try await api("PUT", ["rooms", roomId, "state", MatrixAccount.expiryFeatures],
                          ["disappearing_timer": ["types": ["after_send"], "timers": [quarter, day, week]]], session: session)
        _ = try await api("PUT", ["rooms", roomId, "state", MatrixAccount.expiryTimer], [:], session: session)
        let off = try await account.messageExpiry(roomId: roomId)
        XCTAssertEqual(off, MessageExpiry(timer: 0, choices: [day, week, quarter]))

        try await account.setMessageExpiry(roomId: roomId, timer: week)
        let set = try await account.messageExpiry(roomId: roomId)
        XCTAssertEqual(set?.timer, week)
        let stored = try await api("GET", ["rooms", roomId, "state", MatrixAccount.expiryTimer], session: session)
        XCTAssertEqual(stored["type"] as? String, "after_send", "the bridge reads the timer in its own form")
        XCTAssertEqual((stored["timer"] as? NSNumber)?.intValue, week)

        do {
            try await account.setMessageExpiry(roomId: roomId, timer: 123_000)
            XCTFail("a timer the network does not take was set")
        } catch MessageExpiryError.notOffered {}

        try await account.setMessageExpiry(roomId: roomId, timer: 0)
        let cleared = try await account.messageExpiry(roomId: roomId)
        XCTAssertEqual(cleared?.timer, 0)
    }

    // MARK: helpers

    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                                                     storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"))
        addTeardownBlock { try? await account.signOut() }
        return account
    }

    private func api(_ method: String, _ path: [String], _ body: Any? = nil, session: SavedSession) async throws -> [String: Any] {
        var url = URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3")
        for part in path { url.appendPathComponent(part) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
