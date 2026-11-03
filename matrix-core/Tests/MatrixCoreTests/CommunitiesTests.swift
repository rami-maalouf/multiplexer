@testable import MatrixCore
import XCTest

/// Communities as filters ("Later"): the spaces an account has joined, without the bridges'
/// own. The end-to-end test uses a space of its own ("Multiplexer community test") holding one
/// room ("Multiplexer community chat"); both are made once and kept.
final class CommunitiesTests: XCTestCase {
    private let spaceName = "Multiplexer community test"
    private let chatName = "Multiplexer community chat"
    private let me = "@me:example.org"

    /// The three kinds of space on a bridged account (seen on the server, read only, 2026-11-03):
    /// a bridge's own space has no service members and only its bot beside the person; a
    /// WhatsApp community's space names the bot as a service member; a Matrix space has neither.
    func testABridgesOwnSpaceIsNoCommunity() {
        XCTAssertTrue(Community.isBridgeSpace(serviceMembers: [], members: [me, "@whatsappbot:example.org"], ownUserId: me))
        XCTAssertTrue(Community.isBridgeSpace(serviceMembers: [], members: ["@instagrambot:example.org", me], ownUserId: me))
        // a community: the bridge serves its space, with the people of its groups in it.
        XCTAssertFalse(Community.isBridgeSpace(serviceMembers: ["@whatsappbot:example.org"],
                                               members: [me, "@whatsappbot:example.org", "@whatsapp_1555:example.org"], ownUserId: me))
        // a space of Matrix: alone, with a friend, or with a ghost (a person, not a bot).
        XCTAssertFalse(Community.isBridgeSpace(serviceMembers: [], members: [me], ownUserId: me))
        XCTAssertFalse(Community.isBridgeSpace(serviceMembers: [], members: [me, "@friend:example.org"], ownUserId: me))
        XCTAssertFalse(Community.isBridgeSpace(serviceMembers: [], members: [me, "@whatsapp_1555:example.org"], ownUserId: me))
        XCTAssertFalse(Community.isBridgeSpace(serviceMembers: [], members: [me, "@whatsappbot:example.org", "@friend:example.org"], ownUserId: me))
    }

    /// A chat counts for its space and every space above it: a WhatsApp community's groups are in
    /// the community, and the community is in the bridge's own space. A loop ends.
    func testASpaceHoldsTheChatsOfTheSpacesInsideIt() {
        let parents: [String: [String]] = [
            "!group1": ["!community"], "!group2": ["!community", "!other"], "!dm": ["!bridge"],
            "!community": ["!bridge"], "!other": [], "!bridge": [],
            "!loop1": ["!loopA"], "!loopA": ["!loopB"], "!loopB": ["!loopA"],
        ]
        let rooms = Community.chatsOfSpaces(parents: parents, chats: ["!group1", "!group2", "!dm", "!loop1", "!alone"])
        XCTAssertEqual(rooms["!community"], ["!group1", "!group2"])
        XCTAssertEqual(rooms["!other"], ["!group2"])
        XCTAssertEqual(rooms["!bridge"], ["!group1", "!group2", "!dm"])
        XCTAssertEqual(rooms["!loopA"], ["!loop1"])
        XCTAssertEqual(rooms["!loopB"], ["!loop1"])
        XCTAssertNil(rooms["!alone"])
    }

    /// By name, as Beeper lists them (a capital letter does not come first); a space with none
    /// of the account's chats is left out, and each keeps only the chats the account has.
    func testCommunitiesAreListedByNameWithTheirChats() {
        let spaces = [
            Community(id: "!c", name: "happy town", avatarName: "", rooms: ["!1", "!gone"]),
            Community(id: "!a", name: "Arab Run Club", avatarName: "a.jpg", rooms: ["!2"]),
            Community(id: "!e", name: "Empty", avatarName: "", rooms: ["!gone"]),
            Community(id: "!b", name: "Bahen", avatarName: "", rooms: ["!3", "!1"]),
        ]
        let listed = Community.listed(spaces, chats: ["!1", "!2", "!3"])
        XCTAssertEqual(listed.map(\.name), ["Arab Run Club", "Bahen", "happy town"])
        XCTAssertEqual(listed.last?.rooms, ["!1"])
    }

    /// A community narrows the list and the pinned chats to its chats, and counts its unread ones
    /// in the inbox, as a network does.
    func testACommunityNarrowsTheListAndCountsItsUnreadChats() {
        func chat(_ id: String, unread: Int = 0, archived: Bool = false) -> RoomSummary {
            var r = RoomSummary(id: id, name: id, isDirect: false, lastMessage: "", lastSenderName: "", lastIsOwn: false,
                                lastTimestamp: 0, avatarName: "", unreadCount: unread, network: "whatsapp")
            r.isArchived = archived
            return r
        }
        let chats = [chat("!1", unread: 2), chat("!2"), chat("!3", unread: 1, archived: true), chat("!4", unread: 5)]
        let inbox = Inbox(chats: chats, listed: ["!1", "!2", "!4"], pinned: [chat("!2"), chat("!4")])
        let community = Community(id: "!s", name: "S", avatarName: "", rooms: ["!1", "!2", "!3"])
        let narrowed = inbox.on(community: community)
        XCTAssertEqual(narrowed.listed, ["!1", "!2"])
        XCTAssertEqual(narrowed.pinned.map(\.id), ["!2"])
        XCTAssertEqual(narrowed.chats.count, 4, "every chat stays, so an open chat keeps its name")
        XCTAssertEqual(inbox.on(community: nil), inbox)
        // the archived unread chat is not in the inbox, so it does not count.
        XCTAssertEqual(inbox.counts(of: [community]), [CommunityCount(id: "!s", name: "S", avatarName: "", unread: 1)])
    }

    /// A new device lists a space of Matrix with its room, and the space narrows the list to it.
    func testASpaceIsACommunityOnANewDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let server = String(user.split(separator: ":").last ?? "")
        let writer = try await signIn(homeserver, user, password)
        let rooms = try await writer.rooms()
        let chatId: String
        if let id = rooms.first(where: { $0.name == chatName })?.id { chatId = id } else { chatId = try await writer.createRoom(name: chatName) }
        if try await writer.communities().first(where: { $0.name == spaceName }) == nil {
            let session = try writer.savedSession()
            let spaceId = try await createSpace(spaceName, session: session)
            try await putState(["via": [server]], type: "m.space.child", stateKey: chatId, roomId: spaceId, session: session)
            try await putState(["via": [server], "canonical": true], type: "m.space.parent", stateKey: spaceId, roomId: chatId, session: session)
        }

        let reader = try await signIn(homeserver, user, password)
        let community = try await communityOnceItHasItsChat(reader, chatId)
        XCTAssertEqual(community?.name, spaceName)
        XCTAssertEqual(community?.rooms, [chatId])
        let inbox = try await reader.inbox(filter: .all, network: nil).on(community: community)
        XCTAssertEqual(inbox.listed, [chatId])
        // the other test rooms are in no space.
        let all = try await reader.communities()
        let others = Set(try await reader.rooms().filter { $0.name.hasPrefix("Multiplexer") && $0.name != chatName }.map(\.id))
        XCTAssertTrue(all.allSatisfy { $0.rooms.isDisjoint(with: others) }, "\(all.map(\.name))")
    }

    /// The space once the sdk's space graph holds its room, or the last answer after 20 s: a new
    /// device builds the graph from the first sync.
    private func communityOnceItHasItsChat(_ account: MatrixAccount, _ chatId: String) async throws -> Community? {
        let start = Date()
        var found = try await account.communities().first { $0.name == spaceName }
        while found?.rooms.contains(chatId) != true, Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 500_000_000)
            found = try await account.communities().first { $0.name == spaceName }
        }
        return found
    }

    private func createSpace(_ name: String, session: SavedSession) async throws -> String {
        let url = URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/createRoom")
        let body: [String: Any] = ["name": name, "preset": "private_chat", "creation_content": ["type": "m.space"]]
        let answer = try await call("POST", url, body, session)
        return try XCTUnwrap(answer["room_id"] as? String)
    }

    private func putState(_ content: [String: Any], type: String, stateKey: String, roomId: String, session: SavedSession) async throws {
        let key = stateKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let base = URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/rooms")
            .appendingPathComponent(roomId).appendingPathComponent("state").appendingPathComponent(type)
        _ = try await call("PUT", URL(string: base.absoluteString + "/" + key)!, content, session)
    }

    private func call(_ method: String, _ url: URL, _ body: [String: Any], _ session: SavedSession) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, String(decoding: data, as: UTF8.self))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// Signs in as a new device that the test signs out at its end, even when the test fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                     deviceName: "Multiplexer test", storeDirectory: directory)
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}
