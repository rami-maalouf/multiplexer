@testable import MatrixCore
import XCTest

/// Send Later: messages that wait on the server (delayed events, MSC4140) and go at their time,
/// as two test users (`scripts/test-matrix-core.sh` passes them). The rooms are this test's own,
/// made on the first run.
final class ScheduledMessagesTests: XCTestCase {
    private let roomName = "Multiplexer schedule test"
    private let encryptedName = "Multiplexer schedule test encrypted"

    /// A scheduled message waits in the list, then reaches the other person at its time, as an
    /// answer when it answers one; it leaves the list once it went.
    func testAScheduledMessageGoesAtItsTime() async throws {
        let (sender, reader, roomId) = try await twoPeopleInARoom()
        let start = try await sender.canSendLater(roomId: roomId)
        XCTAssertTrue(start, "a plain chat has no Send Later")

        let first = "First \(token())"
        try await sender.send(roomId: roomId, text: first)
        let answered = try await message(reader, roomId, within: 30) { $0.body == first }
        let found = try await eventId(of: first, in: roomId, account: sender)
        let quoted = try XCTUnwrap(found, "the message to answer has no event id")

        let text = "Later \(token())"
        let at = Date().addingTimeInterval(6)
        let id = try await sender.sendLater(roomId: roomId, text: text, replyTo: quoted, at: at)
        let waiting = try await sender.scheduledMessages()
        let mine = try XCTUnwrap(waiting.first { $0.id == id }, "it is not in the list")
        XCTAssertEqual(mine.body, text)
        XCTAssertEqual(mine.roomId, roomId)
        XCTAssertEqual(mine.replyTo, quoted)
        XCTAssertEqual(Double(mine.sendAt), at.timeIntervalSince1970 * 1000, accuracy: 2000)
        let early = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertFalse(early.contains { $0.body == text }, "it went before its time")

        let arrived = try await message(reader, roomId, within: 40) { $0.body == text }
        XCTAssertGreaterThanOrEqual(Double(arrived.timestamp), at.timeIntervalSince1970 * 1000 - 1000, "it went early")
        XCTAssertEqual(arrived.reply?.body, first, "it does not answer the message")
        XCTAssertFalse(answered.isOwn)
        let after = try await sender.scheduledMessages()
        XCTAssertFalse(after.contains { $0.id == id }, "it stays in the list after it went")
    }

    /// Change Time moves it (a new id, the old one gone), Send Now sends it at once, and Cancel
    /// keeps it from going. A time past or further than a year is refused.
    func testChangeSendNowAndCancel() async throws {
        let (sender, reader, roomId) = try await twoPeopleInARoom()
        let hour = Date().addingTimeInterval(3600)

        let moved = "Moved \(token())"
        let old = try await sender.sendLater(roomId: roomId, text: moved, at: hour)
        let new = try await sender.reschedule(id: old, at: hour.addingTimeInterval(3600))
        XCTAssertNotEqual(new, old)
        var list = try await sender.scheduledMessages()
        XCTAssertFalse(list.contains { $0.id == old }, "the old one still waits")
        let kept = try XCTUnwrap(list.first { $0.id == new })
        XCTAssertEqual(kept.body, moved)
        XCTAssertEqual(Double(kept.sendAt), hour.addingTimeInterval(3600).timeIntervalSince1970 * 1000, accuracy: 3000)

        try await sender.sendScheduledNow(id: new)
        _ = try await message(reader, roomId, within: 30) { $0.body == moved }

        let cancelled = "Cancelled \(token())"
        let gone = try await sender.sendLater(roomId: roomId, text: cancelled, at: Date().addingTimeInterval(5))
        try await sender.cancelScheduled(id: gone)
        list = try await sender.scheduledMessages()
        XCTAssertFalse(list.contains { $0.id == gone })
        try await Task.sleep(nanoseconds: 9_000_000_000)
        let shown = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertFalse(shown.contains { $0.body == cancelled }, "a cancelled message went")
        do {
            try await sender.reschedule(id: gone, at: hour)
            XCTFail("a cancelled message was moved")
        } catch MatrixCoreError.scheduleGone {}

        do {
            try await sender.sendLater(roomId: roomId, text: "Past", at: Date().addingTimeInterval(-60))
            XCTFail("a past time was taken")
        } catch MatrixCoreError.scheduleRefused {}
        do {
            try await sender.sendLater(roomId: roomId, text: "Too far", at: Date().addingTimeInterval(400 * 86400))
            XCTFail("the server took a delay over its maximum")
        } catch MatrixCoreError.scheduleRefused {}
    }

    /// An end-to-end encrypted chat has no Send Later: the server would send it unencrypted.
    func testAnEncryptedChatHasNoSendLater() async throws {
        let (homeserver, user, password, _, _) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let roomId: String
        if let id = try await owner.rooms().first(where: { $0.name == encryptedName })?.id {
            roomId = id
        } else {
            roomId = try await owner.createRoom(name: encryptedName, encrypted: true)
        }
        let can = try await owner.canSendLater(roomId: roomId)
        XCTAssertFalse(can)
        do {
            try await owner.sendLater(roomId: roomId, text: "Secret", at: Date().addingTimeInterval(3600))
            XCTFail("an encrypted chat took a scheduled message")
        } catch MatrixCoreError.scheduleEncrypted {}
    }

    /// The menu's choices in the reader's zone: tomorrow and Monday at 9:00, and a picked time.
    func testTheChoicesAreTimesInTheReadersZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // Saturday 2026-10-31, 22:15 in New York; the clocks go back on Sunday 2026-11-01.
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 22, minute: 15)))
        let parts: (Date?) -> DateComponents? = { $0.map { calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: $0) } }
        XCTAssertEqual(parts(ScheduledMessage.date(for: "tomorrow", now: now, calendar: calendar)),
                       DateComponents(year: 2026, month: 11, day: 1, hour: 9, minute: 0, weekday: 1))
        XCTAssertEqual(parts(ScheduledMessage.date(for: "monday", now: now, calendar: calendar)),
                       DateComponents(year: 2026, month: 11, day: 2, hour: 9, minute: 0, weekday: 2))
        let picked = try XCTUnwrap(ScheduledMessage.date(for: "2026-11-04T18:30", now: now, calendar: calendar))
        XCTAssertEqual(picked.timeIntervalSince1970, 1_793_835_000, "18:30 in New York after the change is 23:30 UTC")
        XCTAssertNil(ScheduledMessage.date(for: "next week", now: now, calendar: calendar))
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

    /// The second user sends, the first reads, in the test's room (made on the first run).
    private func twoPeopleInARoom() async throws -> (sender: MatrixAccount, reader: MatrixAccount, roomId: String) {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let roomId: String
        if let id = try await reader.rooms().first(where: { $0.name == roomName })?.id {
            roomId = id
        } else {
            let created = try await api("POST", ["createRoom"], ["name": roomName, "preset": "private_chat", "invite": [user2]],
                                        session: try reader.savedSession())
            roomId = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        _ = try await api("POST", ["join", roomId], [:], session: try sender.savedSession())
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            if try await sender.rooms().contains(where: { $0.id == roomId }) { return (sender, reader, roomId) }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("\(roomName) did not reach the second user's list")
        throw CancellationError()
    }

    /// A word of letters and digits no other run has.
    private func token() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12).description }

    /// The newest message in the chat that matches `found`, within `seconds`.
    private func message(_ account: MatrixAccount, _ roomId: String, within seconds: TimeInterval, _ found: (Message) -> Bool) async throws -> Message {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if let match = try await account.messages(roomId: roomId, limit: 20).last(where: found) { return match }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("no matching message within \(Int(seconds)) s")
        throw CancellationError()
    }

    /// The event id of the account's message with this text, once the server has it.
    private func eventId(of text: String, in roomId: String, account: MatrixAccount) async throws -> String? {
        let start = Date()
        while Date().timeIntervalSince(start) < 30 {
            let shown = try await account.messages(roomId: roomId, limit: 20)
            if let m = shown.last(where: { $0.body == text && $0.sendState == .sent }),
               let live = account.readyTimeline(roomId), let id = live.items.replyEventId(m.id) { return id }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
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

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await testAccount(homeserver, user, password)
    }
}
