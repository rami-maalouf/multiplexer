@testable import MatrixCore
import XCTest

/// The filter sheet's network filter (b4), as two test users (`scripts/test-matrix-core.sh` passes
/// them). Its rooms are its own, made on the first run: one that a WhatsApp bridge serves, one
/// that an Instagram bridge serves, and a plain one, each with the second user in it.
final class NetworkFilterTests: XCTestCase {
    private let whatsAppName = "Multiplexer sheet test WhatsApp"
    private let instagramName = "Multiplexer sheet test Instagram"
    private let plainName = "Multiplexer sheet test plain"

    func testTheNetworkFilterNarrowsTheListAndThePinsAlsoUnderUnread() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let (whatsApp, instagram, plain) = try await sheetRooms(reader, sender, user2: user2)
        let ours = [whatsApp, instagram, plain]
        let session = try reader.savedSession()
        for id in ours {
            try await setMarkedUnread(false, roomId: id, session: session)
            try await reader.unpin(roomId: id)
            try await reader.markRead(roomId: id)
        }

        // a network shows its own chats and no other's; nil shows every network.
        let onWhatsApp = try await listed(reader, .all, "whatsapp") { $0.contains(whatsApp) }
        XCTAssertFalse(onWhatsApp.contains(instagram) || onWhatsApp.contains(plain), "another network's chat shows under WhatsApp")
        let onInstagram = try await listed(reader, .all, "instagram") { $0.contains(instagram) }
        XCTAssertFalse(onInstagram.contains(whatsApp) || onInstagram.contains(plain), "another network's chat shows under Instagram")
        let onMatrix = try await listed(reader, .all, "matrix") { $0.contains(plain) }
        XCTAssertFalse(onMatrix.contains(whatsApp) || onMatrix.contains(instagram), "a bridged chat shows under Matrix")
        _ = try await listed(reader, .all, nil) { ids in ours.allSatisfy(ids.contains) }
        let narrowed = try await reader.inbox(filter: .all, network: "whatsapp")
        XCTAssertEqual(Set(narrowed.rooms.map(\.network)), ["whatsapp"])
        XCTAssertTrue(narrowed.chats.contains { $0.id == plain }, "a chat the filter leaves out is gone from the chats")

        // the sheet lists each network the account has chats on, Matrix first.
        let networks = narrowed.networks.map(\.network)
        XCTAssertEqual(networks.first, "matrix")
        let w = try XCTUnwrap(networks.firstIndex(of: "whatsapp")), i = try XCTUnwrap(networks.firstIndex(of: "instagram"))
        XCTAssertLessThan(w, i, "the networks are out of order: \(networks)")
        XCTAssertEqual(networks.count, Set(networks).count)

        // with Unread: the other person writes in the WhatsApp chat and the plain chat.
        _ = try await listed(reader, .unread, nil) { ids in ours.allSatisfy { !ids.contains($0) } }
        let before = try await unread(reader, on: "whatsapp")
        try await sender.sendAndWait(roomId: whatsApp, text: "Sheet \(UUID().uuidString)")
        try await sender.sendAndWait(roomId: plain, text: "Sheet \(UUID().uuidString)")
        let unreadOnWhatsApp = try await listed(reader, .unread, "whatsapp") { $0.contains(whatsApp) }
        XCTAssertFalse(unreadOnWhatsApp.contains(plain), "an unread plain chat shows under unread WhatsApp chats")
        let unreadOnMatrix = try await listed(reader, .unread, "matrix") { $0.contains(plain) }
        XCTAssertFalse(unreadOnMatrix.contains(whatsApp), "an unread WhatsApp chat shows under unread Matrix chats")
        let unreadOnInstagram = try await reader.inbox(filter: .unread, network: "instagram").rooms.map(\.id)
        XCTAssertFalse(unreadOnInstagram.contains(instagram), "a read chat shows under unread Instagram chats")
        let after = try await unread(reader, on: "whatsapp")
        XCTAssertEqual(after, before + 1, "the WhatsApp row's count")
        let all = try await reader.inbox(filter: .all, network: nil)
        XCTAssertEqual(all.unreadChats, all.networks.map(\.unread).reduce(0, +), "the inbox's count is not the networks' sum")

        // a pinned chat shows above its own network's list only.
        try await reader.pin(roomId: whatsApp)
        let pinnedHere = try await reader.inbox(filter: .all, network: "whatsapp")
        XCTAssertTrue(pinnedHere.pinned.contains { $0.id == whatsApp }, "the pinned chat is missing above its network's list")
        XCTAssertFalse(pinnedHere.rooms.contains { $0.id == whatsApp }, "the pinned chat is still in its network's list")
        let pinnedElsewhere = try await reader.inbox(filter: .all, network: "matrix")
        XCTAssertFalse(pinnedElsewhere.pinned.contains { $0.id == whatsApp }, "a WhatsApp pin shows above the Matrix list")
        // with Unread on, the pinned chat is in the list, still only its network's.
        let pinnedUnread = try await reader.inbox(filter: .unread, network: "whatsapp").rooms.map(\.id)
        XCTAssertTrue(pinnedUnread.contains(whatsApp), "an unread pinned chat is missing under unread WhatsApp chats")

        try await reader.unpin(roomId: whatsApp)
        for id in ours { try await reader.markRead(roomId: id) }
        _ = try await listed(reader, .unread, nil) { ids in ours.allSatisfy { !ids.contains($0) } }
    }

    /// The rules without a server: what a network keeps of the list and the pins, and the
    /// sheet's rows with their counts.
    func testNetworkRules() {
        func chat(_ id: String, _ network: String, unread: Int = 0, marked: Bool = false, pinned: Bool = false) -> RoomSummary {
            var r = RoomSummary(id: id, name: id, isDirect: false, lastMessage: "Hi", lastSenderName: "A", lastIsOwn: false,
                                lastTimestamp: 1, unreadCount: unread, network: network)
            r.isMarkedUnread = marked
            r.isPinned = pinned
            return r
        }
        let chats = [chat("a", "instagram", unread: 3), chat("b", "whatsapp"), chat("c", "whatsapp", marked: true),
                     chat("d", "matrix", unread: 1, pinned: true), chat("e", "whatsapp", pinned: true), chat("f", "telegram")]
        let inbox = Inbox(chats: chats, listed: Set(chats.filter { $0.matches(.all) }.map(\.id)), pinned: MatrixAccount.inPinOrder(chats))
        XCTAssertEqual(inbox.on(network: "whatsapp").rooms.map(\.id), ["b", "c"])
        XCTAssertEqual(inbox.on(network: "whatsapp").pinned.map(\.id), ["e"])
        XCTAssertEqual(inbox.on(network: "whatsapp").chats.count, chats.count)
        XCTAssertEqual(inbox.on(network: nil), inbox)
        XCTAssertEqual(inbox.on(network: "signal").rooms, [])
        // the networks in their order, Matrix first, each with its unread chats.
        XCTAssertEqual(inbox.networks, [NetworkCount(network: "matrix", unread: 1), NetworkCount(network: "whatsapp", unread: 1),
                                        NetworkCount(network: "instagram", unread: 1), NetworkCount(network: "telegram", unread: 0)])
        XCTAssertEqual(inbox.unreadChats, 3)
        // under a filter, the network keeps the filter's chats.
        let unread = Inbox(chats: chats, listed: Set(chats.filter { $0.matches(.unread) }.map(\.id)), pinned: inbox.pinned)
        XCTAssertEqual(unread.on(network: "whatsapp").rooms.map(\.id), ["c"])
        XCTAssertEqual(unread.on(network: "matrix").rooms.map(\.id), ["d"])
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

    /// The test's three rooms, made by the first user on the first run, with the second user in
    /// them. A bridged room names the bridge's bot as a service member
    /// (`io.element.functional_members`), as a mautrix bridge does; the bot is not invited.
    private func sheetRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> (String, String, String) {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let server = String(session.userId.split(separator: ":").last ?? "")
        let known = try await owner.rooms()
        func room(_ name: String, bot: String?) async throws -> String {
            if let id = known.first(where: { $0.name == name })?.id { return id }
            var body: [String: Any] = ["name": name, "preset": "private_chat", "invite": [user2]]
            if let bot {
                body["initial_state"] = [["type": "io.element.functional_members", "state_key": "", "content": ["service_members": [bot]]]]
            }
            let created = try await api("POST", ["createRoom"], body, session: session)
            return try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        let whatsApp = try await room(whatsAppName, bot: "@whatsappbot:\(server)")
        let instagram = try await room(instagramName, bot: "@instagrambot:\(server)")
        let plain = try await room(plainName, bot: nil)
        for id in [whatsApp, instagram, plain] {
            _ = try? await api("POST", ["rooms", id, "invite"], ["user_id": user2], session: session)
            _ = try await api("POST", ["join", id], [:], session: otherSession)
        }
        // the other user's sync runs from here, so they can write in the rooms.
        _ = try await other.rooms()
        // the owner's list has all three, each with its network, once its sync brings them.
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let rooms = try await owner.rooms()
            let network = Dictionary(rooms.map { ($0.id, $0.network) }, uniquingKeysWith: { first, _ in first })
            if network[whatsApp] == "whatsapp", network[instagram] == "instagram", network[plain] == "matrix" { return (whatsApp, instagram, plain) }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach the first user's list with their networks")
        throw CancellationError()
    }

    /// The ids in the list under `filter` on `network` once they match `done`, or the last ones after 15 s.
    private func listed(_ account: MatrixAccount, _ filter: RoomFilter, _ network: String?, until done: ([String]) -> Bool) async throws -> [String] {
        let start = Date()
        var ids = try await account.inbox(filter: filter, network: network).rooms.map(\.id)
        while !done(ids), Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            ids = try await account.inbox(filter: filter, network: network).rooms.map(\.id)
        }
        XCTAssertTrue(done(ids), "\(filter) on \(network ?? "every network"): the list did not change as expected")
        return ids
    }

    /// The unread chats the sheet shows for `network`.
    private func unread(_ account: MatrixAccount, on network: String) async throws -> Int {
        try await account.inbox(filter: .all, network: nil).networks.first { $0.network == network }?.unread ?? 0
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

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await signInTestDevice(homeserver, user, password)
    }
}
