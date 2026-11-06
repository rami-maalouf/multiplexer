@testable import MatrixCore
import XCTest

/// Merge Chats: one person's chats on several networks as one chat, kept in the account's data, as
/// two test users (`scripts/test-matrix-core.sh` passes them). The rooms are the test's own, made on
/// the first run.
final class MergesTests: XCTestCase {
    private let names = ["Multiplexer merge test one", "Multiplexer merge test two"]

    private func chat(_ id: String, _ network: String, last: UInt64, own: Bool, unread: Int) -> RoomSummary {
        var c = RoomSummary(id: id, name: "Ana \(network)", isDirect: true, lastMessage: "hi", lastSenderName: own ? "You" : "Ana",
                            lastIsOwn: own, lastTimestamp: last)
        c.network = network
        c.unreadCount = unread
        c.isOneToOne = true
        return c
    }

    /// The account data's shape, both ways; one with fewer than two rooms is none.
    func testAMergeIsKept() {
        let kept = [ChatMerge(id: "m", name: "Ana", rooms: ["!a", "!b"], defaultRoom: "!b")]
        XCTAssertEqual(MergeStore.merges(json: MergeStore.json(kept)), kept)
        XCTAssertEqual(MergeStore.merges(json: #"{"merges": [{"id": "x", "rooms": ["!a"]}]}"#), [])
        XCTAssertEqual(MergeStore.merges(json: #"{"merges": [{"id": "x", "rooms": ["!a", "!b"], "default": "!c"}]}"#).first?.defaultRoom, "!a",
                       "a default not in the merge is its first room")
    }

    /// The list folds a merge's rooms into one chat: the newest message, the unread counts added,
    /// both networks; it opens the room of the other person's newest message, else the default. The
    /// folded rooms are in no list; the merged chat shows under each of its networks.
    func testTheListShowsAMergeAsOneChat() {
        let merge = ChatMerge(id: "m", name: "Ana", rooms: ["w", "i"], defaultRoom: "w")
        let rooms = [chat("x", "matrix", last: 5, own: false, unread: 0), chat("w", "whatsapp", last: 10, own: false, unread: 2),
                     chat("i", "instagram", last: 20, own: false, unread: 1)]
        let folded = MergeStore.fold(rooms, [merge])
        let row = folded.first { $0.id == "merge:m" }!
        XCTAssertEqual(row.name, "Ana")
        XCTAssertEqual(row.unreadCount, 3)
        XCTAssertEqual(row.networks, ["whatsapp", "instagram"])
        XCTAssertEqual(row.lastTimestamp, 20)
        XCTAssertEqual(row.opensRoom, "i", "the other person wrote last on Instagram")
        XCTAssertEqual(folded.filter { $0.foldedInto == "m" }.map(\.id), ["w", "i"])
        XCTAssertNil(folded.first { $0.id == "w" }!.list, "a folded room is in no list")
        let inbox = Inbox(chats: folded, listed: Set(folded.filter { $0.matches(.all) }.map(\.id)), pinned: [])
        XCTAssertEqual(inbox.rooms.map(\.id).sorted(), ["merge:m", "x"])
        XCTAssertEqual(inbox.on(network: "whatsapp").rooms.map(\.id), ["merge:m"])
        XCTAssertEqual(inbox.on(network: "instagram").rooms.map(\.id), ["merge:m"])
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: inbox.networks.map { ($0.network, $0.unread) }), ["matrix": 0, "whatsapp": 1, "instagram": 1])

        // your own newest message: it opens the default room.
        let answered = MergeStore.fold([chat("w", "whatsapp", last: 10, own: false, unread: 0), chat("i", "instagram", last: 20, own: true, unread: 0)], [merge])
        XCTAssertEqual(answered.first { $0.id == "merge:m" }!.opensRoom, "w")
        // one room missing (left, or not synced yet): no merge.
        XCTAssertNil(MergeStore.fold([chat("w", "whatsapp", last: 10, own: false, unread: 0)], [merge]).first { $0.id == "merge:m" })
    }

    /// A merge shows as one chat on this device at once and on another device of the account, never to
    /// the other person; a chat action reaches each room; Unmerge shows the rooms again.
    func testAMergeReachesYourOtherDeviceAndUnmergeEndsIt() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        var ids: [String] = []
        for name in names { ids.append(try await testRoom(owner, other, user2: user2, name: name)) }
        for merge in await owner.merges() where merge.rooms.contains(where: ids.contains) { try await owner.unmerge(merge.id) }

        let chatId = try await owner.merge(rooms: ids, name: "  Merged test  ", defaultRoom: ids[1])
        let rooms = try await owner.rooms()
        let row = try XCTUnwrap(rooms.first { $0.id == chatId }, "this device shows the merged chat at once")
        XCTAssertEqual(row.name, "Merged test")
        XCTAssertEqual(Set(row.mergeRooms.map(\.id)), Set(ids))
        let listed = try await owner.inbox(filter: .all, list: .inbox, network: nil).listed
        XCTAssertTrue(listed.contains(chatId))
        XCTAssertFalse(listed.contains(ids[0]) || listed.contains(ids[1]), "its rooms are not listed on their own")
        let both = await owner.roomsOf(chatId)
        XCTAssertEqual(Set(both), Set(ids), "a chat action on it reaches each room")
        let kept = await owner.merges()
        XCTAssertEqual(kept.first { $0.chatId == chatId }?.defaultRoom, ids[1], "the default is kept with the merge")

        let second = try await signIn(homeserver, user, password)
        // a new device's first sync can take longer than the default 30 s on a busy machine.
        _ = try await second.rooms(timeout: 90)
        try await waitFor("another device of the account to show it") { try await second.rooms().contains { $0.id == chatId } }
        let theirs = try await other.rooms()
        XCTAssertFalse(theirs.contains { $0.id == chatId }, "the other person has no merge")

        try await owner.unmerge(chatId)
        let after = try await owner.rooms()
        XCTAssertFalse(after.contains { $0.id == chatId })
        XCTAssertTrue(ids.allSatisfy { id in after.contains { $0.id == id && $0.foldedInto == nil } }, "its rooms show again")
        try await waitFor("the unmerge to reach the other device") {
            let shown = try await second.rooms()
            return !shown.contains { $0.id == chatId }
        }
    }

    /// The test's room by name, made by the first user on the first run, with the second user in it.
    private func testRoom(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String, name: String) async throws -> String {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        var roomId = try await owner.rooms().first { $0.roomName == name || $0.name == name }?.id
        if roomId == nil {
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            roomId = id
        }
        let id = try XCTUnwrap(roomId)
        try await waitFor("the test room to reach both users' lists") {
            let ours = try await owner.rooms().contains { $0.id == id }
            let theirs = try await other.rooms().contains { $0.id == id }
            return ours && theirs
        }
        return id
    }

    private func waitFor(_ what: String, _ seconds: TimeInterval = 20, _ done: () async throws -> Bool) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if try await done() { return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("waited \(Int(seconds)) s for \(what)")
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

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)", isDirectory: true)
    }

    /// Signs in as a new device that the test signs out at its end, even when it fails. The server
    /// limits sign-ins, and other tests sign in as the same users: a refusal waits and tries again.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await testAccount(homeserver, user, password)
    }
}
