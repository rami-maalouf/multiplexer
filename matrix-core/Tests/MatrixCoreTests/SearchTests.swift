@testable import MatrixCore
import UIKit
import XCTest

/// Search across chats, as two test users (`scripts/test-matrix-core.sh` passes them). The rooms
/// are this test's own, made on the first run, with names that start "Multiplexer search test".
final class SearchTests: XCTestCase {
    private let roomName = "Multiplexer search test"
    private let historyName = "Multiplexer search test history"

    /// A word the second user sends is found by the first user's search, on a device that
    /// signed in before it came: by the whole word, and by its start while it is typed.
    func testAWordTheOtherPersonSentIsFound() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId = try await room(roomName, owner: reader, other: sender, user2: user2)

        let word = "pelican" + token()
        try await sender.sendAndWait(roomId: roomId, text: "Meet the \(word) at the harbour")
        let found = try await searched(reader, word) { $0.messages.contains { $0.body.contains(word) } }
        let message = try XCTUnwrap(found.messages.first { $0.body.contains(word) })
        XCTAssertEqual(message.chat.id, roomId)
        XCTAssertEqual(message.chat.name, roomName)
        XCTAssertEqual(message.sender, user2)
        XCTAssertFalse(message.isOwn)
        XCTAssertEqual(message.kind, .text)
        XCTAssertTrue(message.eventId.hasPrefix("$"))
        XCTAssertTrue(found.links.isEmpty, "a message without a link is under links")

        // the index matches whole words: the start of one finds nothing (the sdk's tantivy refuses
        // a one-word prefix). Two words find it only together, in any case.
        let typing = String(word.prefix(word.count - 3))
        let started = try await reader.search(typing)
        XCTAssertFalse(started.messages.contains { $0.eventId == message.eventId }, "the start of a word finds its message now: say so in the app")
        let shouted = try await reader.search(word.uppercased())
        XCTAssertTrue(shouted.messages.contains { $0.eventId == message.eventId })
        let both = try await reader.search("harbour \(word)")
        XCTAssertTrue(both.messages.contains { $0.eventId == message.eventId })
        let other = try await reader.search("\(word) lighthouse")
        XCTAssertFalse(other.messages.contains { $0.eventId == message.eventId }, "a word the message lacks found it")

        // the found message opens its chat there.
        let id = try await reader.showMessage(roomId: roomId, eventId: message.eventId)
        let shown = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertNotNil(id)
        XCTAssertTrue(shown.contains { $0.id == id && $0.body.contains(word) })
    }

    /// A chat is found by part of its name, without case or accents; one deleted from the app is not.
    func testAChatIsFoundByPartOfItsName() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId = try await room(roomName, owner: reader, other: sender, user2: user2)

        for text in ["search test", "SEARCH TÉST", "plexer sea", "multiplexer search"] {
            let found = try await reader.search(text)
            XCTAssertTrue(found.chats.contains { $0.id == roomId }, "“\(text)” did not find the chat: \(found.chats.map(\.name))")
        }
        let none = try await reader.search("search test zebra")
        XCTAssertFalse(none.chats.contains { $0.id == roomId })
    }

    /// The name ranking, without a server: the name's start first, then words' starts, then the rest.
    func testChatsNamedRanksTheBestFirst() {
        func chat(_ id: String, _ name: String, hidden: Bool = false) -> RoomSummary {
            var summary = RoomSummary(id: id, name: name, isDirect: false, lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
            summary.isHidden = hidden
            return summary
        }
        let chats = [chat("a", "Board games"), chat("b", "Anna Bergström"), chat("c", "Ånna's book club"), chat("d", "Hanna"),
                     chat("e", "Anna (old)", hidden: true)]
        XCTAssertEqual(MatrixAccount.chatsNamed("anna", in: chats).map(\.id), ["b", "c", "d"])
        XCTAssertEqual(MatrixAccount.chatsNamed("berg ann", in: chats).map(\.id), ["b"])
        XCTAssertEqual(MatrixAccount.chatsNamed("oar", in: chats).map(\.id), ["a"])
        XCTAssertEqual(MatrixAccount.chatsNamed("  ", in: chats).map(\.id), [])
    }

    /// A link message is found under Links: by the kind, and by a word of its link.
    func testALinkMessageIsFoundUnderLinks() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId = try await room(roomName, owner: reader, other: sender, user2: user2)

        let word = "atlas" + token()
        let link = "https://example.com/\(word)"
        try await sender.sendAndWait(roomId: roomId, text: "The map is at \(link).")
        let byWord = try await searched(reader, word) { $0.links.contains { $0.links == [link] } }
        XCTAssertFalse(byWord.messages.contains { $0.links == [link] }, "the link's message is under messages too")
        let linked = try XCTUnwrap(byWord.links.first { $0.links == [link] })
        XCTAssertEqual(linked.chat.id, roomId)

        let links = try await reader.search(kind: .links)
        XCTAssertTrue(links.contains { $0.eventId == linked.eventId }, "Links: \(links.map(\.body))")
        XCTAssertTrue(links.allSatisfy { !$0.links.isEmpty }, "a message without a link is under Links")
        XCTAssertEqual(links.map(\.timestamp), links.map(\.timestamp).sorted(by: >), "Links is not newest first")
        let narrowed = try await reader.search(kind: .links, word)
        XCTAssertEqual(narrowed.map(\.eventId), [linked.eventId])
    }

    /// A photo is found under Images, with its thumbnail.
    func testAPhotoIsFoundUnderImages() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId = try await room(roomName, owner: reader, other: sender, user2: user2)

        let caption = "dune" + token()
        let picture = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try jpeg().write(to: picture)
        let attachment = Attachment(file: picture, name: "image.jpg", mimetype: "image/jpeg", size: try jpeg().count, kind: .photo(width: 4, height: 3))
        _ = try await sender.sendAttachment(roomId: roomId, attachment: attachment, caption: caption, replyTo: nil)

        var images: [FoundMessage] = []
        let start = Date()
        while Date().timeIntervalSince(start) < 30 {
            images = try await reader.search(kind: .images, caption)
            if !images.isEmpty { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        let photo = try XCTUnwrap(images.first, "the photo is not under Images")
        XCTAssertEqual(photo.kind, .image)
        XCTAssertEqual(photo.body, caption)
        XCTAssertNotNil(photo.image)
        let all = try await reader.search(kind: .images)
        XCTAssertTrue(all.contains { $0.eventId == photo.eventId })
        XCTAssertTrue(all.allSatisfy { $0.kind == .image })
        let file = try await reader.searchPicture(eventId: photo.eventId, directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("matrix-core-\(UUID().uuidString)"))
        XCTAssertGreaterThan(try Data(contentsOf: file).count, 0)
    }

    /// A found message further back than the chat loads opens the chat there: its timeline pages
    /// back to it, and the chat shows from a few messages before it.
    func testAnOlderMessageOpensItsChatThere() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId = try await room(historyName, owner: reader, other: sender, user2: user2)
        // the room keeps 40 numbered messages from its first run.
        let session = try sender.savedSession()
        var events = try await textEvents(roomId: roomId, session: session)
        if events.count < 40 {
            for n in 1...(40 - events.count) { try await sendText("History \(n)", roomId: roomId, session: session) }
            events = try await textEvents(roomId: roomId, session: session)
        }
        let old = try XCTUnwrap(events.dropLast(30).last, "the room has too few messages")

        let first = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertFalse(first.contains { $0.body == old.body }, "the message is among the 20 the chat opens with")
        let jumped = try await reader.showMessage(roomId: roomId, eventId: old.eventId)
        let id = try XCTUnwrap(jumped, "the message was not found")
        let shown = try await reader.messages(roomId: roomId, limit: 20)
        let at = try XCTUnwrap(shown.firstIndex { $0.id == id })
        XCTAssertEqual(shown[at].body, old.body)
        XCTAssertLessThanOrEqual(at, 5, "the chat shows more than 5 messages before it")
        XCTAssertGreaterThan(shown.count, 25)

        // an event that is not in the room is not found, and the chat stays as it was.
        let none = try await reader.showMessage(roomId: roomId, eventId: "$notanevent\(token())", limit: 100)
        XCTAssertNil(none)
    }

    // MARK: helpers

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    /// A word of letters and digits no other run has.
    private func token() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12).description }

    /// The search's results once `done` holds, or the last ones after 30 s: a message reaches the
    /// index when the reader's sync brings it.
    private func searched(_ account: MatrixAccount, _ text: String, until done: (SearchResults) -> Bool) async throws -> SearchResults {
        let start = Date()
        var found = try await account.search(text)
        while !done(found), Date().timeIntervalSince(start) < 30 {
            try await Task.sleep(nanoseconds: 500_000_000)
            found = try await account.search(text)
        }
        XCTAssertTrue(done(found), "“\(text)” did not find what was expected: \(found.messages.map(\.body)) \(found.links.map(\.body))")
        return found
    }

    /// A room the first user made on the first run, with the second user in it.
    private func room(_ name: String, owner: MatrixAccount, other: MatrixAccount, user2: String) async throws -> String {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let roomId: String
        if let id = try await owner.rooms().first(where: { $0.name == name })?.id {
            roomId = id
        } else {
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            roomId = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        _ = try await api("POST", ["join", roomId], [:], session: otherSession)
        _ = try await other.rooms()
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            if try await owner.rooms().contains(where: { $0.id == roomId }) { return roomId }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("\(name) did not reach the first user's list")
        throw CancellationError()
    }

    /// The room's text messages, oldest first, through the client-server api.
    private func textEvents(roomId: String, session: SavedSession) async throws -> [(eventId: String, body: String)] {
        var url = URLComponents(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/rooms")
            .appendingPathComponent(roomId).appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "dir", value: "b"), URLQueryItem(name: "limit", value: "200")]
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let chunk = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["chunk"] as? [[String: Any]] ?? []
        return chunk.reversed().compactMap { event in
            guard event["type"] as? String == "m.room.message", let content = event["content"] as? [String: Any],
                  content["msgtype"] as? String == "m.text", let id = event["event_id"] as? String, let body = content["body"] as? String else { return nil }
            return (id, body)
        }
    }

    /// Sends a text through the client-server api, waiting out the server's rate limit.
    private func sendText(_ text: String, roomId: String, session: SavedSession) async throws {
        for _ in 0..<10 {
            let reply = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                                      ["msgtype": "m.text", "body": text], session: session)
            if reply["event_id"] != nil { return }
            let wait = (reply["retry_after_ms"] as? Int) ?? 1000
            try await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000)
        }
        XCTFail("the server refused “\(text)”")
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

    /// A tiny JPEG, made once.
    private func jpeg() throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }

    /// Signs in as a new device with its own search index, which the test signs out at its end,
    /// even when it fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                                                     storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"),
                                                     searchIndexKey: SearchIndex.newKey())
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}
