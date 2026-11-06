@testable import MatrixCore
import XCTest

/// A chat the sdk has no latest event for shows its newest message and that message's time, read from
/// the server (NewestMessages.swift). On a real account a new device had no latest event for 132 of 187
/// chats, whose newest events were no messages; one small test room does not reproduce that (the sdk
/// has its latest event), so this test asks the server's newest message directly, under a newer
/// reaction, and checks the row too.
final class NewestMessagesTests: XCTestCase {
    private let roomName = "Multiplexer newest message test"

    func testTheNewestMessageUnderAReactionIsFoundAndShown() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let sender = try await signInTestDevice(homeserver, user2, password2)
        let senderSession = try sender.savedSession()
        let roomId = try await testRoom(homeserver, user, password, sender: senderSession, user2: user2)

        // a message, then a reaction to it: the room's newest event is no message.
        let text = "Newest \(UUID().uuidString.prefix(8))"
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                                 ["msgtype": "m.text", "body": text], session: senderSession)
        let messageId = try XCTUnwrap(sent["event_id"] as? String, "send: \(sent)")
        let reacted = try await api("PUT", ["rooms", roomId, "send", "m.reaction", UUID().uuidString],
                                    ["m.relates_to": ["rel_type": "m.annotation", "event_id": messageId, "key": "👍"]], session: senderSession)
        XCTAssertNotNil(reacted["event_id"], "react: \(reacted)")

        // a new device: the server's newest message is the message, not the newer reaction.
        let reader = try await signInTestDevice(homeserver, user, password)
        let found = await reader.newestMessage(roomId: roomId)
        XCTAssertEqual(found?.eventId, messageId, "the newest message is not the message under the reaction")
        XCTAssertEqual(found?.preview, text)
        XCTAssertEqual(found?.sender, senderSession.userId)
        XCTAssertEqual(found?.isOwn, false)
        XCTAssertGreaterThan(found?.timestamp ?? 0, 0)

        // and the row shows it.
        let start = Date()
        var row = try await reader.rooms().first { $0.id == roomId }
        while row?.lastMessage != text, Date().timeIntervalSince(start) < 30 {
            try await Task.sleep(nanoseconds: 500_000_000)
            row = try await reader.rooms().first { $0.id == roomId }
        }
        let shown = try XCTUnwrap(row, "the room is not in the new device's list")
        XCTAssertEqual(shown.lastMessage, text, "the row does not show the newest message")
        XCTAssertGreaterThan(shown.lastTimestamp, 0, "the row has no time")
        XCTAssertFalse(shown.lastIsOwn)
        print("the newest message showed after \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
    }

    /// The ids a `/messages` answer gives, in order: no edit and no deleted event.
    func testTheServersAnswerLeavesOutEditsAndDeletedMessages() {
        let json = #"""
        {"chunk": [
          {"event_id": "$edit", "content": {"msgtype": "m.text", "body": "* new", "m.relates_to": {"rel_type": "m.replace", "event_id": "$a"}}},
          {"event_id": "$deleted", "content": {}},
          {"event_id": "$a", "content": {"msgtype": "m.text", "body": "old"}},
          {"event_id": "$b", "content": {"algorithm": "m.megolm.v1.aes-sha2", "ciphertext": "x"}}
        ]}
        """#
        XCTAssertEqual(newestMessageIds(json: Data(json.utf8)), ["$a", "$b"])
        XCTAssertEqual(newestMessageIds(json: Data("{}".utf8)), [])
    }

    // MARK: helpers

    /// The test room, made by the first user on the first run with the second in it; not encrypted.
    private func testRoom(_ homeserver: String, _ user: String, _ password: String, sender: SavedSession, user2: String) async throws -> String {
        let joined = try await api("GET", ["joined_rooms"], session: sender)["joined_rooms"] as? [String] ?? []
        for id in joined {
            let name = try await api("GET", ["rooms", id, "state", "m.room.name", ""], session: sender)["name"] as? String
            if name == roomName { return id }
        }
        let owner = try await signInTestDevice(homeserver, user, password)
        let ownerSession = try owner.savedSession()
        let created = try await api("POST", ["createRoom"], ["name": roomName, "preset": "private_chat", "invite": [user2]], session: ownerSession)
        let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        _ = try await api("POST", ["join", id], [:], session: sender)
        return id
    }

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    /// A client-server api call (`/_matrix/client/v3/...`); its JSON answer, an error's included.
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
