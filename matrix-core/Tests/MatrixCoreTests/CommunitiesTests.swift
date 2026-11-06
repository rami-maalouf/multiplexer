@testable import MatrixCore
import XCTest
import UIKit

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

    /// by name, including an empty space so a newly created one can be selected.
    func testCommunitiesAreListedByNameWithTheirChats() {
        let spaces = [
            Community(id: "!c", name: "happy town", avatarName: "", rooms: ["!1", "!gone"]),
            Community(id: "!a", name: "Arab Run Club", avatarName: "a.jpg", rooms: ["!2"]),
            Community(id: "!e", name: "Empty", avatarName: "", rooms: ["!gone"]),
            Community(id: "!b", name: "Bahen", avatarName: "", rooms: ["!3", "!1"]),
        ]
        let listed = Community.listed(spaces, chats: ["!1", "!2", "!3"])
        XCTAssertEqual(listed.map(\.name), ["Arab Run Club", "Bahen", "Empty", "happy town"])
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

    func testACommunityIncludesAMergedChatWhenOneOfItsRoomsBelongs() {
        var first = RoomSummary(id: "!one", name: "One", isDirect: false, lastMessage: "Hello",
            lastSenderName: "Sender", lastIsOwn: false, lastTimestamp: 1, unreadCount: 1)
        first.isPinned = true
        let second = RoomSummary(id: "!two", name: "Two", isDirect: false, lastMessage: "Hi",
            lastSenderName: "Sender", lastIsOwn: false, lastTimestamp: 2, unreadCount: 1)
        let merge = ChatMerge(id: "pair", name: "Pair", rooms: [first.id, second.id], defaultRoom: first.id)
        let chats = MergeStore.fold([first, second], [merge])
        let community = Community(id: "!space", name: "Space", avatarName: "", rooms: [second.id])
            .includingMergedChats(chats)
        XCTAssertTrue(community.rooms.contains(merge.chatId))
        let inbox = Inbox(chats: chats, listed: [merge.chatId], pinned: [chats.first { $0.id == merge.chatId }!])
        XCTAssertEqual(inbox.on(community: community).listed, [merge.chatId])
        XCTAssertEqual(inbox.on(community: community).pinned.map(\.id), [merge.chatId])
        XCTAssertEqual(inbox.counts(of: [community]).first?.unread, 1)
    }

    /// A new device lists a space of Matrix with its room, and the space narrows the list to it.
    func testASpaceIsACommunityOnANewDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let server = String(user.split(separator: ":").last ?? "")
        let writer = try await testAccount(homeserver, user, password)
        let rooms = try await writer.rooms()
        let chatId: String
        if let id = rooms.first(where: { $0.name == chatName })?.id { chatId = id } else { chatId = try await writer.createRoom(name: chatName) }
        if try await writer.communities().first(where: { $0.name == spaceName }) == nil {
            let session = try writer.savedSession()
            let spaceId = try await createSpace(spaceName, session: session)
            try await putState(["via": [server]], type: "m.space.child", stateKey: chatId, roomId: spaceId, session: session)
            try await putState(["via": [server], "canonical": true], type: "m.space.parent", stateKey: spaceId, roomId: chatId, session: session)
        }

        let reader = try await testAccount(homeserver, user, password)
        let community = try await communityOnceItHasItsChat(reader, chatId)
        XCTAssertEqual(community?.name, spaceName)
        XCTAssertEqual(community?.rooms, [chatId])
        let inbox = try await reader.inbox(filter: .all, network: nil).on(community: community)
        XCTAssertEqual(inbox.listed, [chatId])
    }

    // a private space starts empty, accepts a chat, and keeps that chat on a fresh device.
    func testANewSpaceCanHoldAChatOnAnotherDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("a test user is needed")
        }
        let server = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let writer = try await testAccount(server, user, password)
        let name = "Multiplexer new space \(UUID().uuidString.prefix(8))"
        let picture = FileManager.default.temporaryDirectory.appendingPathComponent("space-\(UUID().uuidString).jpg")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: picture)
        defer { try? FileManager.default.removeItem(at: picture) }
        let id = try await writer.createSpace(name: name, picture: picture)
        addTeardownBlock { try? await writer.decline(request: id) }
        let emptySpaces = try await writer.communities()
        XCTAssertEqual(emptySpaces.first { $0.id == id }?.rooms, [])
        let chats = try await writer.rooms()
        let chatId: String
        if let chat = chats.first(where: { $0.name == chatName }) { chatId = chat.id }
        else { chatId = try await writer.createRoom(name: chatName) }
        // creation and power-level state can arrive in separate sync updates.
        var editable = try await writer.editableCommunities(for: chatId)
        for _ in 0..<40 where !editable.contains(where: { $0.id == id }) {
            try await Task.sleep(nanoseconds: 500_000_000)
            editable = try await writer.editableCommunities(for: chatId)
        }
        XCTAssertTrue(editable.contains { $0.id == id })
        try await writer.addToSpace(roomId: chatId, spaceId: id)
        // repeating the action is harmless.
        try await writer.addToSpace(roomId: chatId, spaceId: id)
        let reader = try await testAccount(server, user, password)
        var found: Community?
        for _ in 0..<40 {
            found = try await reader.communities().first { $0.id == id }
            if found?.rooms.contains(chatId) == true { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertEqual(found?.name, name)
        XCTAssertFalse(found?.avatarName.isEmpty ?? true)
        XCTAssertEqual(found?.rooms, [chatId])
        let inbox = try await reader.inbox(filter: .all).on(community: found)
        XCTAssertEqual(inbox.listed, [chatId])
    }

    // FRESH DEVICE: a new device builds the space graph from its first sync.
    func testAMergedChatAddsEachOfItsRoomsToTheSpace() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("a test user is needed")
        }
        let account = try await signInTestDevice(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        var ids: [String] = []
        for name in ["Multiplexer space merge first", "Multiplexer space merge second", "Multiplexer space merge third"] {
            if let found = rooms.first(where: { $0.roomName == name }) { ids.append(found.id) }
            else { ids.append(try await account.createRoom(name: name)) }
        }
        let space = try await account.createSpace(name: "Multiplexer merged space \(UUID().uuidString.prefix(8))")
        addTeardownBlock { try? await account.decline(request: space) }
        let merged = try await account.merge(rooms: ids, name: "Space pair", defaultRoom: ids[0])
        addTeardownBlock { try? await account.unmerge(merged) }
        // a partial earlier attempt: one room is already present and must survive retry.
        try await account.addToSpace(roomId: ids[0], spaceId: space)
        var partial: Community?
        for _ in 0..<40 {
            partial = try await account.editableCommunities(for: merged).first { $0.id == space }
            if partial?.rooms.contains(ids[0]) == true { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertTrue(partial?.rooms.contains(ids[0]) ?? false)
        XCTAssertFalse(Set(ids).isSubset(of: partial?.rooms ?? []))
        // a stale merge with an unavailable later child fails after its earlier child succeeds.
        let stale = ChatMerge(id: "partial-space-test", name: "Stale pair", rooms: [ids[1], "not-a-room"], defaultRoom: ids[1])
        let currentMerges = await account.merges()
        account.mergeStates.wrote([stale])
        do {
            try await account.addToSpace(roomId: stale.chatId, spaceId: space)
            XCTFail("an invalid later child should fail the addition")
        } catch {}
        account.mergeStates.wrote(currentMerges)
        var afterFailure: Community?
        for _ in 0..<40 {
            afterFailure = try await account.editableCommunities(for: merged).first { $0.id == space }
            if afterFailure?.rooms.contains(ids[1]) == true { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertTrue(afterFailure?.rooms.contains(ids[0]) ?? false)
        XCTAssertTrue(afterFailure?.rooms.contains(ids[1]) ?? false, "the successful new child survives the later failure")
        XCTAssertFalse(Set(ids).isSubset(of: afterFailure?.rooms ?? []))
        try await account.addToSpace(roomId: merged, spaceId: space)
        try await account.addToSpace(roomId: merged, spaceId: space)
        var found: Community?
        for _ in 0..<40 {
            found = try await account.communities().first { $0.id == space }
            if Set(ids + [merged]).isSubset(of: found?.rooms ?? []) { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertTrue(Set(ids + [merged]).isSubset(of: found?.rooms ?? []))
        let choices = try await account.editableCommunities(for: merged)
        XCTAssertTrue(Set(ids).isSubset(of: choices.first { $0.id == space }?.rooms ?? []))
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

}
