@testable import MatrixCore
import XCTest

/// R04: a chat opens on what the device has (a new device: its first page) and fills to its first
/// screen behind it. "Multiplexer test" holds more than 20 messages (MatrixCoreTests).
final class ChatOpeningTests: XCTestCase {
    private let roomName = "Multiplexer test"

    func testAChatOpensBeforeItsFirstScreenIsInThenSettles() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signInTestDevice(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let found = try await account.rooms().first { $0.name == roomName }?.id
        let roomId = try XCTUnwrap(found, "no room \(roomName)")

        // the first answer comes with a message, and says whether more is on its way.
        let first = try await account.opening(roomId: roomId, limit: 20)
        XCTAssertFalse(first.messages.isEmpty, "the chat opens on a message")
        XCTAssertLessThanOrEqual(first.messages.count, 20)
        if first.settling { XCTAssertFalse(first.atStart, "the start is not known while it fills") }

        // messages() waits for the fill: the full first screen, as before.
        let full = try await account.messages(roomId: roomId, limit: 20)
        XCTAssertGreaterThanOrEqual(full.count, 20, "the room holds more than 20 messages")
        XCTAssertEqual(full.last?.id, first.messages.last?.id, "the newest message stays the newest")

        // once filled, an opening is settled and shows the same screen.
        let settled = try await account.opening(roomId: roomId, limit: 20)
        XCTAssertFalse(settled.settling)
        XCTAssertEqual(settled.messages.map(\.id), full.map(\.id))

        // older messages load after the fill, never at the same time as it.
        try await account.loadOlder(roomId: roomId, count: 10)
        let older = try await account.messages(roomId: roomId, limit: 20)
        XCTAssertGreaterThan(older.count, full.count)
        XCTAssertEqual(Array(older.suffix(full.count)).map(\.id), full.map(\.id))
    }

    /// Three unread messages, opened on a new device: a "New" line given while the chat still fills is
    /// the first of the three (or none yet), never a later one; the settled line is the first.
    func testANewLineGivenEarlyIsTheFirstUnread() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let owner = try await signInTestDevice(homeserver, user, password)
        let other = try await signInTestDevice(homeserver, user2, password2)
        let name = "Multiplexer opening unread test"
        var roomId = try await owner.rooms().first { $0.name == name }?.id
        if roomId == nil {
            let made = try await owner.createRoom(name: name)
            try await owner.invite(roomId: made, userId: user2)
            try await until("the invite reaches the other") { try await other.requests().contains { $0.id == made } }
            try await other.accept(request: made)
            roomId = made
        }
        let room = try XCTUnwrap(roomId)
        try await until("the other is in the room") { try await other.rooms().contains { $0.id == room } }

        // read up to here, then three messages from the other person.
        let run = UUID().uuidString.prefix(8)
        try await other.sendAndWait(roomId: room, text: "Read \(run)")
        try await until("the read message arrives") { try await owner.messages(roomId: room, limit: 20).contains { $0.body == "Read \(run)" } }
        try await owner.markRead(roomId: room)
        try await until("the chat is read") { try await owner.rooms().first { $0.id == room }?.unreadCount == 0 }
        for n in 1...3 { try await other.sendAndWait(roomId: room, text: "Unread \(run) \(n)") }
        // the sync's unread count can lag (ChatDetailsTests' known unstable count): the messages are
        // what the test needs, and an unread count on the new device for the line to be looked for.
        try await until("the third arrives") { try await owner.messages(roomId: room, limit: 20).contains { $0.body == "Unread \(run) 3" } }

        let later = try await signInTestDevice(homeserver, user, password)
        try await until("unread on the new device") { (try await later.rooms().first { $0.id == room }?.unreadCount ?? 0) >= 1 }
        let first = try await later.opening(roomId: room, limit: 20)
        if let early = first.firstUnread {
            XCTAssertEqual(first.messages.first { $0.id == early }?.body, "Unread \(run) 1", "an early line is the first unread")
        }
        _ = try await later.messages(roomId: room, limit: 20)
        let settled = try await later.opening(roomId: room, limit: 20)
        XCTAssertFalse(settled.settling)
        let line = try XCTUnwrap(settled.firstUnread, "no line once settled")
        XCTAssertEqual(settled.messages.first { $0.id == line }?.body, "Unread \(run) 1")
        try await later.markRead(roomId: room)
    }

    /// Waits up to 30 s for `done`.
    private func until(_ what: String, _ done: () async throws -> Bool) async throws {
        let start = Date()
        while try await !done() {
            if Date().timeIntervalSince(start) > 30 { XCTFail("timed out: \(what)"); return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }
}
