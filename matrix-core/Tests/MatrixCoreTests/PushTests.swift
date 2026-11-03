@testable import MatrixCore
import XCTest

/// Push, as two test users (`scripts/test-matrix-core.sh` passes them): what the notification
/// extension shows, read with its own client on the app's store, and the pushers the app sets.
/// The rooms are this file's own, made on the first run.
final class PushTests: XCTestCase {
    private let plainName = "Multiplexer push test"
    private let encryptedName = "Multiplexer push encrypted test"

    /// The extension builds its client as `MatrixPush.content` does, on the store of an app client
    /// that keeps running, and reads the other person's message: in a plain and an encrypted room.
    func testAPushShowsTheSenderAndTheText() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let store = freshDirectory()
        let app = try await signIn(homeserver, user, password, store: store)
        let sender = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(app, sender, user2: user2)
        let senderName = try await sender.ownProfile().displayName

        for (name, roomId) in rooms.sorted(by: { $0.key < $1.key }) {
            let text = "Push \(UUID().uuidString)"
            try await sender.sendAndWait(roomId: roomId, text: text)
            let eventId = try await eventId(sender, roomId: roomId, text: text)

            let start = Date()
            let content = try await MatrixPush.content(session: try app.savedSession(), storeDirectory: store,
                                                       roomId: roomId, eventId: eventId)
            print("\(name): the extension's client read the message in \(String(format: "%.2f", Date().timeIntervalSince(start))) s")
            let shown = try XCTUnwrap(content, "\(name): nothing to show")
            XCTAssertEqual(shown.body, text, name)
            // the profile's name falls back to the id's local part; a push's to the whole id.
            XCTAssertTrue([senderName, user2].contains(shown.senderName), "\(name): sender \(shown.senderName)")
            XCTAssertEqual(shown.chatName, name)
            XCTAssertEqual(shown.roomId, roomId)
            XCTAssertEqual(shown.eventId, eventId)
            XCTAssertEqual(shown.network, "matrix")
            // a room with two members, not marked direct, is a group; the server's rules make a
            // message in a two-member room noisy (`.m.rule.room_one_to_one`).
            XCTAssertFalse(shown.isDirect, name)
            XCTAssertTrue(shown.isNoisy, name)
            XCTAssertFalse(shown.hasMention, name)
            XCTAssertNil(shown.threadId)

            // the app's client on the same store keeps working: it shows the message and sends,
            // encrypting with the crypto store the extension used too.
            let messages = try await poll { try await app.messages(roomId: roomId, limit: 20).contains { $0.body == text } }
            XCTAssertTrue(messages, "\(name): the app's chat lost the message")
            try await app.sendAndWait(roomId: roomId, text: "Answer \(UUID().uuidString)")
        }

        // a message deleted before the push is read shows nothing.
        let plain = try XCTUnwrap(rooms[plainName])
        let text = "Deleted \(UUID().uuidString)"
        try await sender.sendAndWait(roomId: plain, text: text)
        let deleted = try await eventId(sender, roomId: plain, text: text)
        let sent = try await sender.messages(roomId: plain, limit: 20).last { $0.body == text }
        let messageId = try XCTUnwrap(sent?.id)
        try await sender.delete(roomId: plain, messageId: messageId)
        let gone = try await poll {
            try await MatrixPush.content(session: try app.savedSession(), storeDirectory: store, roomId: plain, eventId: deleted) == nil
        }
        XCTAssertTrue(gone, "a deleted message still shows")
    }

    /// The app's pusher: set with the values the gateway needs, replaced by a new token, and gone
    /// once deleted.
    func testAPusherIsSetReplacedAndDeleted() async throws {
        let (homeserver, user, password, _, _) = try twoUsers()
        let account = try await signIn(homeserver, user, password)
        let appId = "com.ramimaalouf.multiplexer.ios.test"
        let url = "https://sygnal.ramimaalouf.com/_matrix/push/v1/notify"
        func pusher(_ token: Data) -> Pusher {
            Pusher(appId: appId, pushkey: Pusher.pushkey(apnsToken: token), url: url,
                   appDisplayName: "Multiplexer", deviceDisplayName: "Multiplexer test")
        }
        let first = pusher(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        try await account.setPusher(first)
        addTeardownBlock { try? await account.deletePusher(appId: appId, pushkey: first.pushkey) }
        var mine = try await account.pushers().filter { $0.appId == appId }
        XCTAssertEqual(mine.count, 1)
        let set = try XCTUnwrap(mine.first)
        XCTAssertEqual(set.pushkey, first.pushkey)
        XCTAssertEqual(set.url, url)
        XCTAssertTrue(set.eventIdOnly)
        XCTAssertEqual(set.appDisplayName, "Multiplexer")
        XCTAssertEqual(set.deviceDisplayName, "Multiplexer test")
        // the server keeps the payload as JSON; its keys may come in another order.
        let payload = try JSONSerialization.jsonObject(with: Data(set.defaultPayload.utf8)) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Data(Pusher.apnsPayload.utf8)) as? NSDictionary
        XCTAssertEqual(payload, expected)

        // a new token: the old pusher goes, the new one comes.
        let second = pusher(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        try await account.deletePusher(appId: appId, pushkey: first.pushkey)
        try await account.setPusher(second)
        addTeardownBlock { try? await account.deletePusher(appId: appId, pushkey: second.pushkey) }
        mine = try await account.pushers().filter { $0.appId == appId }
        XCTAssertEqual(mine.map(\.pushkey), [second.pushkey])

        // deleted, it is gone; deleting it again is no error.
        try await account.deletePusher(appId: appId, pushkey: second.pushkey)
        try await account.deletePusher(appId: appId, pushkey: second.pushkey)
        mine = try await account.pushers().filter { $0.appId == appId }
        XCTAssertEqual(mine, [])
    }

    // MARK: helpers

    /// The server's id for `text`, the newest own message of that text in the sender's chat.
    private func eventId(_ account: MatrixAccount, roomId: String, text: String) async throws -> String {
        let live = try await account.liveTimeline(roomId, limit: 20, timeout: 30)
        let start = Date()
        while Date().timeIntervalSince(start) < 15 {
            if let message = live.items.messages().last(where: { $0.isOwn && $0.body == text }),
               case .eventId(let id)? = live.items.eventOrTransactionId(of: message.id) { return id }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("no event id for the sent message")
        throw CancellationError()
    }

    /// True once `done` is, or false after 20 s.
    private func poll(_ done: () async throws -> Bool) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            if try await done() { return true }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    /// The plain and the encrypted test room by name, made by the first user on the first run,
    /// with the second user in them, once both lists have them.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        for name in [plainName, encryptedName] {
            if let id = known.first(where: { $0.roomName == name })?.id {
                ids[name] = id
                continue
            }
            var body: [String: Any] = ["name": name, "preset": "private_chat", "invite": [user2]]
            if name == encryptedName {
                body["initial_state"] = [["type": "m.room.encryption", "state_key": "", "content": ["algorithm": "m.megolm.v1.aes-sha2"]]]
            }
            let created = try await api("POST", ["createRoom"], body, session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        _ = try await other.rooms()
        let both = try await poll {
            let joined = try await owner.rooms().map(\.id), theirs = try await other.rooms().map(\.id)
            return ids.values.allSatisfy { joined.contains($0) && theirs.contains($0) }
        }
        XCTAssertTrue(both, "the push test rooms did not reach both lists")
        return ids
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

    /// Signs in as a new device that the test signs out at its end, even when it fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String, store: URL? = nil) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                     deviceName: "Multiplexer test", storeDirectory: store ?? freshDirectory())
        addTeardownBlock { try? await account.signOut() }
        return account
    }

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
    }
}
