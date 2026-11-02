@testable import MatrixCore
import XCTest

/// The inbox's filters and pins, as two test users (`scripts/test-matrix-core.sh` passes them).
/// Its rooms are its own, made on the first run, so other tests' messages do not reach them.
final class InboxTests: XCTestCase {
    private let directName = "Multiplexer inbox test DM"
    private let groupName = "Multiplexer inbox test group"
    /// A chat where the second user plays a bridge's bot: a service member
    /// (`io.element.functional_members`), as a bridge marks its bot.
    private let bridgedName = "Multiplexer inbox test bridged DM"

    func testFiltersFindUnreadUnansweredDirectAndGroupChats() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let (direct, group, bridged) = try await inboxRooms(reader, sender, user2: user2)
        let readerSession = try reader.savedSession()
        for id in [direct, group, bridged] {
            try await setMarkedUnread(false, roomId: id, session: readerSession)
            try await reader.unpin(roomId: id)
        }

        // a chat marked direct and a bridged chat with one other person are DMs; the rest are groups.
        let people = try await inbox(reader, .people) { ids in ids.contains(direct) && ids.contains(bridged) }
        XCTAssertFalse(people.contains(group), "the group shows under DMs")
        let groups = try await inbox(reader, .groups) { $0.contains(group) }
        XCTAssertFalse(groups.contains(direct), "the DM shows under Groups")
        XCTAssertFalse(groups.contains(bridged), "the bridged DM shows under Groups")

        // the other person writes in the group; the reader wrote last in the DM.
        try await reader.sendAndWait(roomId: direct, text: "Mine \(UUID().uuidString)")
        for id in [direct, group, bridged] { try await reader.markRead(roomId: id) }
        _ = try await inbox(reader, .unread) { ids in [direct, group, bridged].allSatisfy { !ids.contains($0) } }
        try await sender.sendAndWait(roomId: group, text: "Theirs \(UUID().uuidString)")
        let unread = try await inbox(reader, .unread) { $0.contains(group) }
        XCTAssertFalse(unread.contains(direct), "a read DM shows under Unread")
        let unanswered = try await inbox(reader, .unanswered) { $0.contains(group) }
        XCTAssertFalse(unanswered.contains(direct), "a chat whose newest message is the reader's shows under Unanswered")
        // every chat shows under All while none is pinned.
        let all = try await inbox(reader, .all) { ids in [direct, group, bridged].allSatisfy(ids.contains) }
        XCTAssertEqual(all.count, Set(all).count)

        // a chat marked unread by hand counts as unread, whatever its count says.
        try await setMarkedUnread(true, roomId: direct, session: readerSession)
        let marked = try await inbox(reader, .unread) { $0.contains(direct) }
        XCTAssertTrue(marked.contains(group))
        try await setMarkedUnread(false, roomId: direct, session: readerSession)
        try await reader.markRead(roomId: group)
        _ = try await inbox(reader, .unread) { ids in !ids.contains(direct) && !ids.contains(group) }
    }

    func testAPinShowsOnAnotherDeviceInItsOrder() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let first = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let (direct, group, bridged) = try await inboxRooms(first, sender, user2: user2)
        for id in [direct, group, bridged] { try await first.unpin(roomId: id) }

        // a pin shows at once on its own device, and leaves the list.
        try await first.pin(roomId: direct)
        try await first.pin(roomId: group)
        let here = try await first.inbox()
        XCTAssertEqual(here.pinned.map(\.id).filter([direct, group, bridged].contains), [direct, group])
        XCTAssertFalse(here.rooms.contains { $0.id == direct || $0.id == group }, "a pinned chat is still in the list")
        XCTAssertTrue(here.rooms.contains { $0.id == bridged })

        // a new device gets the pins from the server, in the same order.
        let second = try await signIn(homeserver, user, password)
        let seen = try await pinned(second, among: [direct, group, bridged]) { $0 == [direct, group] }
        XCTAssertEqual(seen, [direct, group])
        let orders = try await second.inbox().pinned.filter { [direct, group].contains($0.id) }.map(\.pinOrder)
        XCTAssertEqual(orders.count, 2)
        XCTAssertLessThan(orders[0] ?? 1, orders[1] ?? 0, "the orders are not in pin order: \(orders)")
        // with a filter on, a pinned chat shows in the list.
        let people = try await second.inbox(filter: .people).rooms.map(\.id)
        XCTAssertTrue(people.contains(direct), "a pinned DM is missing under DMs")

        // unpinned, it comes back to the list; pinned again, it goes after the pins before it.
        try await first.unpin(roomId: direct)
        _ = try await pinned(second, among: [direct, group, bridged]) { $0 == [group] }
        let back = try await second.inbox().rooms.map(\.id)
        XCTAssertTrue(back.contains(direct), "an unpinned chat is not back in the list")
        try await first.pin(roomId: direct)
        let again = try await pinned(second, among: [direct, group, bridged]) { $0 == [group, direct] }
        XCTAssertEqual(again, [group, direct])

        for id in [direct, group] { try await first.unpin(roomId: id) }
        _ = try await pinned(second, among: [direct, group, bridged]) { $0.isEmpty }
    }

    /// The rules without a server: what each filter takes, the pin order, and a new pin's order.
    func testFilterAndPinRules() {
        func chat(_ id: String, unread: Int = 0, marked: Bool = false, own: Bool = false, oneToOne: Bool = false,
                  pinned: Bool = false, order: Double? = nil) -> RoomSummary {
            var r = RoomSummary(id: id, name: id, isDirect: oneToOne, lastMessage: "Hi", lastSenderName: "A", lastIsOwn: own,
                                lastTimestamp: 1, unreadCount: unread)
            r.isMarkedUnread = marked
            r.isOneToOne = oneToOne
            r.isPinned = pinned
            r.pinOrder = order
            return r
        }
        let rooms = [chat("a", unread: 2), chat("b", marked: true, own: true), chat("c", own: true, oneToOne: true, pinned: true, order: 0.75),
                     chat("d", oneToOne: true, pinned: true, order: 0.5), chat("e", pinned: true)]
        func ids(_ filter: RoomFilter) -> [String] { rooms.filter { $0.matches(filter) }.map(\.id) }
        XCTAssertEqual(ids(.all), ["a", "b"])
        XCTAssertEqual(ids(.unread), ["a", "b"])
        XCTAssertEqual(ids(.unanswered), ["a", "d", "e"])
        XCTAssertEqual(ids(.people), ["c", "d"])
        XCTAssertEqual(ids(.groups), ["a", "b", "e"])
        // by order; a pin with none after, in the list's order.
        XCTAssertEqual(MatrixAccount.inPinOrder(rooms).map(\.id), ["d", "c", "e"])
        XCTAssertEqual(Pins.next(after: []), 0.5)
        XCTAssertEqual(Pins.next(after: MatrixAccount.inPinOrder(rooms)), 0.875)
        // once the gaps are used up, there is no next order: the pins are spread out first.
        XCTAssertNil(Pins.next(after: [chat("f", pinned: true, order: 1 - 1e-10)]))
        XCTAssertNil(Pins.next(after: [chat("g", pinned: true, order: 3)]))
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

    /// The test's three rooms, made by the first user on the first run, with the second user in them.
    private func inboxRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> (String, String, String) {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        func room(_ name: String, _ options: [String: Any]) async throws -> String {
            if let id = known.first(where: { $0.name == name })?.id { return id }
            var body: [String: Any] = ["name": name, "preset": "private_chat", "invite": [user2]]
            body.merge(options) { _, new in new }
            let created = try await api("POST", ["createRoom"], body, session: session)
            return try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        let direct = try await room(directName, ["is_direct": true, "preset": "trusted_private_chat"])
        let group = try await room(groupName, [:])
        let bridged = try await room(bridgedName, ["initial_state": [[
            "type": "io.element.functional_members", "state_key": "", "content": ["service_members": [user2]],
        ]]])
        for id in [direct, group, bridged] {
            _ = try? await api("POST", ["rooms", id, "invite"], ["user_id": user2], session: session)
            _ = try await api("POST", ["join", id], [:], session: otherSession)
        }
        // a client marks a chat direct in its account's `m.direct`, as a bridge does with double puppeting.
        var directs = (try? await api("GET", ["user", session.userId, "account_data", "m.direct"], session: session)) ?? [:]
        directs.removeValue(forKey: "errcode")
        directs.removeValue(forKey: "error")
        if !((directs[user2] as? [String]) ?? []).contains(direct) {
            directs[user2] = ((directs[user2] as? [String]) ?? []) + [direct]
            _ = try await api("PUT", ["user", session.userId, "account_data", "m.direct"], directs, session: session)
        }
        // the other user's sync runs from here, so they can write in the rooms.
        _ = try await other.rooms()
        // the owner's list has all three once its sync brings them.
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let ids = try await owner.rooms().map(\.id)
            if [direct, group, bridged].allSatisfy(ids.contains) { return (direct, group, bridged) }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach the first user's list")
        throw CancellationError()
    }

    /// The ids in the inbox's list under `filter` once they match `done`, or the last ones after 15 s.
    private func inbox(_ account: MatrixAccount, _ filter: RoomFilter, until done: ([String]) -> Bool) async throws -> [String] {
        let start = Date()
        var ids = try await account.inbox(filter: filter).rooms.map(\.id)
        while !done(ids), Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            ids = try await account.inbox(filter: filter).rooms.map(\.id)
        }
        XCTAssertTrue(done(ids), "\(filter): the list did not change as expected")
        return ids
    }

    /// The pinned chats among `ids`, in pin order, once they match `done`, or the last ones after 15 s.
    private func pinned(_ account: MatrixAccount, among ids: [String], until done: ([String]) -> Bool) async throws -> [String] {
        let start = Date()
        var seen = try await account.inbox().pinned.map(\.id).filter(ids.contains)
        while !done(seen), Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            seen = try await account.inbox().pinned.map(\.id).filter(ids.contains)
        }
        XCTAssertTrue(done(seen), "the pins did not change as expected: \(seen)")
        return seen
    }

    /// Marks a chat unread by hand (`m.marked_unread`), as another client does.
    private func setMarkedUnread(_ unread: Bool, roomId: String, session: SavedSession) async throws {
        _ = try await api("PUT", ["user", session.userId, "rooms", roomId, "account_data", "m.marked_unread"],
                          ["unread": unread], session: session)
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
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                                                     storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"))
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}
