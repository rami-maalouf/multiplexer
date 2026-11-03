@testable import MatrixCore
import XCTest

/// A chat's long-press actions, as two test users (`scripts/test-matrix-core.sh` passes them).
/// Its rooms are its own, made on the first run, so other tests' messages do not reach them.
final class ChatActionsTests: XCTestCase {
    private let heldName = "Multiplexer hold test"
    private let archiveName = "Multiplexer hold test archive"
    private let deleteName = "Multiplexer hold test delete"
    /// A chat whose bridge bot is a service member (`io.element.functional_members`), as a mautrix
    /// bridge marks its bot: a WhatsApp chat. The bot is not invited.
    private let bridgedName = "Multiplexer hold test WhatsApp"

    func testMarkedUnreadClearsOnReadAndAMutedChatStillCountsMentions() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let held = try await testRooms(owner, sender, user2: user2)[heldName]!
        try await owner.unmute(roomId: held)
        try await owner.markRead(roomId: held)
        let second = try await signIn(homeserver, user, password)

        // marked unread, it counts as unread here at once, and on the other device from the server.
        try await owner.setMarkedUnread(roomId: held, true)
        let unread = try await owner.inbox(filter: .unread).listed
        XCTAssertTrue(unread.contains(held), "a chat marked unread is not under Unread")
        _ = try await summary(second, held) { $0.isMarkedUnread }
        // reading it takes the mark away, as opening the chat does.
        try await owner.markRead(roomId: held)
        _ = try await summary(owner, held) { !$0.isMarkedUnread }
        _ = try await summary(second, held) { !$0.isMarkedUnread }

        // muted, it shows so at once, and on the other device from the server's push rules.
        try await owner.mute(roomId: held)
        let shown = try await summary(owner, held) { _ in true }
        XCTAssertTrue(shown.isMuted, "a muted chat does not show as muted at once")
        _ = try await summary(second, held) { $0.isMuted }
        // the other person's message counts, as no mention.
        let plain = "Plain \(UUID().uuidString)"
        try await say(plain, in: held, as: sender)
        let counted = try await summary(owner, held) { $0.lastMessage == plain && $0.unreadCount > 0 }
        XCTAssertTrue(counted.isMuted, "the chat is no longer muted")
        XCTAssertEqual(counted.unreadMentions, 0, "a message with no mention counts as one")
        // a message that mentions the reader counts as a mention, though the chat is muted.
        try await say("Mention \(UUID().uuidString)", in: held, as: sender, mentioning: user)
        let mentioned = try await summary(owner, held) { $0.unreadMentions > 0 }
        XCTAssertTrue(mentioned.isMuted)
        XCTAssertGreaterThanOrEqual(mentioned.unreadCount, 2)

        // unmuted on one device, the other sees it; read, nothing counts.
        try await owner.unmute(roomId: held)
        _ = try await summary(second, held) { !$0.isMuted }
        try await owner.markRead(roomId: held)
        _ = try await summary(owner, held) { $0.unreadCount == 0 && $0.unreadMentions == 0 && !$0.isMuted }
    }

    func testLowPriorityArchiveAndDeleteLeaveTheInboxOnAnotherDevice() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(owner, sender, user2: user2)
        let archived = rooms[archiveName]!, deleted = rooms[deleteName]!, bridged = rooms[bridgedName]!
        try await reset(owner, archived)
        try await reset(owner, bridged)
        // a chat deleted by an earlier run comes back with a message.
        let before = try await summary(owner, deleted) { _ in true }
        if before.isHidden {
            try await say("Back \(UUID().uuidString)", in: deleted, as: sender)
            _ = try await summary(owner, deleted) { !$0.isHidden }
        }
        try await reset(owner, deleted)
        let second = try await signIn(homeserver, user, password)

        // Low Priority: out of the inbox, in its own list, here at once and on the other device.
        try await owner.setLowPriority(roomId: archived, true)
        try await assertListed(owner, archived, in: .lowPriority)
        try await listed(second, archived, in: .lowPriority)
        try await assertListed(second, archived, in: .lowPriority)

        // archived: out of the inbox and Low Priority, in the Archive list.
        try await owner.setLowPriority(roomId: archived, false)
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await listed(second, archived, in: .archive)
        try await assertListed(second, archived, in: .archive)

        // deleted: in no list, here and on the other device; the room stays joined.
        try await owner.hide(roomId: deleted)
        try await assertListed(owner, deleted, in: nil)
        _ = try await summary(second, deleted) { $0.isHidden }
        try await assertListed(second, deleted, in: nil)
        // a new message brings it back, on both.
        try await say("Again \(UUID().uuidString)", in: deleted, as: sender)
        try await listed(owner, deleted, in: .inbox)
        try await listed(second, deleted, in: .inbox)

        // the Archive narrowed to a network: its archived chats only.
        _ = try await summary(owner, bridged) { $0.network == "whatsapp" }
        try await owner.archive(roomId: bridged)
        let onWhatsApp = try await owner.inbox(filter: .all, list: .archive, network: "whatsapp").rooms.map(\.id)
        XCTAssertTrue(onWhatsApp.contains(bridged), "an archived WhatsApp chat is missing from WhatsApp's Archive")
        XCTAssertFalse(onWhatsApp.contains(archived), "an archived plain chat shows in WhatsApp's Archive")
        let onMatrix = try await owner.inbox(filter: .all, list: .archive, network: "matrix").rooms.map(\.id)
        XCTAssertTrue(onMatrix.contains(archived))
        XCTAssertFalse(onMatrix.contains(bridged))
        let inboxOnWhatsApp = try await owner.inbox(filter: .all, network: "whatsapp").rooms.map(\.id)
        XCTAssertFalse(inboxOnWhatsApp.contains(bridged), "an archived WhatsApp chat shows in WhatsApp's inbox")

        try await owner.unarchive(roomId: bridged)
        try await owner.unarchive(roomId: archived)
        try await listed(second, archived, in: .inbox)
        try await owner.markRead(roomId: deleted)
    }

    func testAnArchivedChatComesBackWithANewMessageUnlessItIsMuted() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let archived = try await testRooms(owner, sender, user2: user2)[archiveName]!
        try await reset(owner, archived)

        // a new message brings an archived chat back to the inbox.
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await say("Back \(UUID().uuidString)", in: archived, as: sender)
        try await listed(owner, archived, in: .inbox)
        try await assertListed(owner, archived, in: .inbox)

        // a muted one stays archived.
        try await owner.archive(roomId: archived)
        try await owner.mute(roomId: archived)
        let quiet = "Quiet \(UUID().uuidString)"
        try await say(quiet, in: archived, as: sender)
        let muted = try await summary(owner, archived) { $0.lastMessage == quiet }
        XCTAssertTrue(muted.isArchived, "a muted archived chat came back with a message")
        try await assertListed(owner, archived, in: .archive)

        // unmuted, it stays archived until its next message.
        try await owner.unmute(roomId: archived)
        _ = try await summary(owner, archived) { !$0.isMuted }
        try await assertListed(owner, archived, in: .archive)
        try await say("Next \(UUID().uuidString)", in: archived, as: sender)
        try await listed(owner, archived, in: .inbox)

        try await owner.unarchive(roomId: archived)
        try await owner.markRead(roomId: archived)
    }

    /// The rules without a server: which list each chat is in, when a mark holds, and the
    /// marks' content.
    func testListAndMarkRules() {
        func chat(_ id: String, last: UInt64 = 10, muted: Bool = false, low: Bool = false, pinned: Bool = false) -> RoomSummary {
            var r = RoomSummary(id: id, name: id, isDirect: false, lastMessage: "Hi", lastSenderName: "A", lastIsOwn: false,
                                lastTimestamp: last, unreadCount: 1)
            r.isMuted = muted
            r.isLowPriority = low
            r.isPinned = pinned
            return r
        }
        let marks = ChatMarks(archived: ["a": 10, "b": 5, "m": 5, "p": 10], hidden: ["h": 10, "g": 5])
        var rooms = [chat("a"), chat("b"), chat("m", muted: true), chat("p", pinned: true), chat("l", low: true),
                     chat("h"), chat("g"), chat("i")]
        for i in rooms.indices { rooms[i].fillMarks(marks) }
        func ids(_ filter: RoomFilter, _ list: ChatList = .inbox) -> [String] { rooms.filter { $0.matches(filter, in: list) }.map(\.id) }
        // "b" and "g" have a message newer than their marks; "m" is muted, so it stays archived.
        XCTAssertEqual(ids(.all, .archive), ["a", "m", "p"])
        XCTAssertEqual(ids(.all, .lowPriority), ["l"])
        XCTAssertEqual(ids(.all), ["b", "g", "i"])
        XCTAssertEqual(ids(.unread), ["b", "g", "i"])
        // the filter menu narrows the Archive too; a pinned archived chat shows there.
        XCTAssertEqual(ids(.groups, .archive), ["a", "m", "p"])
        XCTAssertEqual(ids(.people, .archive), [])
        // a deleted chat is in no list.
        let deleted = rooms.first { $0.id == "h" }!
        XCTAssertNil(deleted.list)
        XCTAssertFalse(ChatList.allCases.contains { list in RoomFilter.allCases.contains { deleted.matches($0, in: list) } })
        // an archived pinned chat leaves the pinned grid too.
        XCTAssertFalse(rooms.first { $0.id == "p" }!.isInInbox)

        // the sheet's counts: each list's unread chats; a muted one only with a mention.
        var mentioned = chat("n", muted: true)
        mentioned.unreadMentions = 1
        let inbox = Inbox(chats: rooms + [chat("q", muted: true), mentioned], listed: [], pinned: [])
        XCTAssertEqual(inbox.unreadChats(in: .inbox), 4)
        XCTAssertEqual(inbox.unreadChats, 4)
        XCTAssertEqual(inbox.unreadChats(in: .archive), 2)
        XCTAssertEqual(inbox.unreadChats(in: .lowPriority), 1)
        XCTAssertEqual(inbox.networks, [NetworkCount(network: "matrix", unread: 4)])

        // the content keeps another version's keys, and drops the marks of chats that came back.
        var read = ChatMarks(json: #"{"archived":{"a":{"ts":10}},"hidden":{"g":{"ts":5}},"labels":{"x":["a"]}}"#)
        XCTAssertEqual(read, ChatMarks(archived: ["a": 10], hidden: ["g": 5]))
        read.dropReturned(rooms)
        XCTAssertEqual(read, ChatMarks(archived: ["a": 10]))
        XCTAssertEqual(read.json(), #"{"archived":{"a":{"ts":10}},"hidden":{},"labels":{"x":["a"]}}"#)
        XCTAssertEqual(ChatMarks(json: nil), ChatMarks())
        XCTAssertEqual(ChatMarks(json: "not json"), ChatMarks())
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

    /// The test's rooms by name, made by the first user on the first run, with the second user in them.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        let server = String(session.userId.split(separator: ":").last ?? "")
        for name in [heldName, archiveName, deleteName, bridgedName] {
            if let id = known.first(where: { $0.name == name })?.id {
                ids[name] = id
                continue
            }
            var body: [String: Any] = ["name": name, "preset": "private_chat", "invite": [user2]]
            if name == bridgedName {
                body["initial_state"] = [["type": "io.element.functional_members", "state_key": "",
                                          "content": ["service_members": ["@whatsappbot:\(server)"]]]]
            }
            let created = try await api("POST", ["createRoom"], body, session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        // the other user's sync runs from here, so they can write in the rooms.
        _ = try await other.rooms()
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id)
            if ids.values.allSatisfy(joined.contains) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach the first user's list")
        throw CancellationError()
    }

    /// Back in the inbox: not archived, not in Low Priority, not muted.
    private func reset(_ account: MatrixAccount, _ roomId: String) async throws {
        try await account.unmute(roomId: roomId)
        try await account.setLowPriority(roomId: roomId, false)
        try await account.unarchive(roomId: roomId)
        try await listed(account, roomId, in: .inbox)
    }

    /// A message from `account`, which the server has; with `mentioning`, it mentions that user
    /// as a client does (`m.mentions`).
    private func say(_ text: String, in roomId: String, as account: MatrixAccount, mentioning: String? = nil) async throws {
        var content: [String: Any] = ["msgtype": "m.text", "body": mentioning.map { "\($0): \(text)" } ?? text]
        content["m.mentions"] = ["user_ids": mentioning.map { [$0] } ?? []]
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], content,
                                 session: try account.savedSession())
        XCTAssertNotNil(sent["event_id"], "send: \(sent)")
    }

    /// The chat's summary once it matches `done`, or the last one after 20 s.
    private func summary(_ account: MatrixAccount, _ roomId: String, _ done: (RoomSummary) -> Bool) async throws -> RoomSummary {
        let start = Date()
        while true {
            let rooms = try await account.rooms()
            let found = try XCTUnwrap(rooms.first { $0.id == roomId }, "\(roomId) is not in the list")
            if done(found) { return found }
            if Date().timeIntervalSince(start) > 20 {
                XCTFail("the chat did not change as expected: \(found)")
                return found
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// Waits until `list` shows the chat, up to 20 s.
    private func listed(_ account: MatrixAccount, _ roomId: String, in list: ChatList) async throws {
        let start = Date()
        while try await !account.inbox(list: list).listed.contains(roomId) {
            if Date().timeIntervalSince(start) > 20 { return XCTFail("\(list): the chat did not show") }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// `list` shows the chat and no other list does; with nil, no list does.
    private func assertListed(_ account: MatrixAccount, _ roomId: String, in expected: ChatList?,
                              file: StaticString = #filePath, line: UInt = #line) async throws {
        for list in ChatList.allCases {
            let shown = try await account.inbox(list: list).listed.contains(roomId)
            XCTAssertEqual(shown, list == expected, "\(list): the chat \(shown ? "shows" : "is missing")", file: file, line: line)
        }
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

    /// Signs in as a new device that the test signs out at its end, even when it fails. The server
    /// limits sign-ins, and other tests sign in as the same users: a refusal waits and tries again.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        for attempt in 1... {
            do {
                let account = try await MatrixAccount.signIn(
                    homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                    storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"))
                addTeardownBlock { try? await account.signOut() }
                return account
            } catch SignInError.rateLimited where attempt < 4 {
                try await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        fatalError("unreachable")
    }
}
