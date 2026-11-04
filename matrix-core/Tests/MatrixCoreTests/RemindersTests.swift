@testable import MatrixCore
import XCTest

/// Remind Me: a reminder to answer a chat, kept in the account's data, as two test users
/// (`scripts/test-matrix-core.sh` passes them). The room is the test's own, made on the first run.
final class RemindersTests: XCTestCase {
    private let roomName = "Multiplexer reminder test"

    /// The account data's shape, both ways, and what answers a reminder.
    func testAReminderIsKeptAndAnsweredByYourOwnNewerMessage() {
        let kept = ["!a:x": Reminder(roomId: "!a:x", at: 1_800_000_000_000, setAt: 1_790_000_000_000)]
        XCTAssertEqual(ReminderStore.reminders(json: ReminderStore.json(kept)), kept)
        XCTAssertEqual(ReminderStore.reminders(json: nil), [:])
        XCTAssertEqual(ReminderStore.reminders(json: #"{"reminders": {"!b:x": {"set": 5}}}"#), [:], "one with no time is none")

        let reminder = kept["!a:x"]!
        var chat = RoomSummary(id: "!a:x", name: "A", isDirect: true, lastMessage: "hi", lastSenderName: "A",
                               lastIsOwn: false, lastTimestamp: reminder.setAt + 1)
        XCTAssertFalse(reminder.isAnswered(by: chat), "their newer message does not answer it")
        chat.lastIsOwn = true
        XCTAssertTrue(reminder.isAnswered(by: chat), "your own newer message does")
        chat.lastTimestamp = reminder.setAt - 1
        XCTAssertFalse(reminder.isAnswered(by: chat), "your message from before you asked does not")
    }

    /// Only the chats with a reminder are in the Reminders list, whatever their list, under the filter.
    func testTheRemindersListIsTheChatsWithAReminder() {
        var due = RoomSummary(id: "d", name: "D", isDirect: true, lastMessage: "x", lastSenderName: "D", lastIsOwn: false, lastTimestamp: 1)
        due.reminderAt = 5
        var archived = due
        archived.id = "a"
        archived.isArchived = true
        var deleted = due
        deleted.id = "h"
        deleted.isHidden = true
        var none = due
        none.id = "n"
        none.reminderAt = nil
        let listed = [due, archived, deleted, none].filter { !$0.isHidden && $0.reminderAt != nil && $0.passes(.all) }.map(\.id)
        XCTAssertEqual(listed, ["d", "a"])
        XCTAssertTrue(due.passes(.unanswered))
        XCTAssertFalse(due.passes(.unread))
    }

    /// A reminder shows on this device at once and on another device of the account, never to the
    /// other person; the Reminders list holds the chat; your answer in the chat takes it away;
    /// Clear takes away one not answered.
    func testAReminderReachesYourOtherDeviceAndYourAnswerEndsIt() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRoom(owner, other, user2: user2)
        try await owner.clearReminder(roomId: roomId)

        let at = Date().addingTimeInterval(3600)
        try await owner.setReminder(roomId: roomId, at: at)
        let ms = UInt64((at.timeIntervalSince1970 * 1000).rounded())
        let mine = try await owner.rooms().first { $0.id == roomId }?.reminderAt
        XCTAssertEqual(mine, ms, "this device shows it at once")
        let listed = try await owner.reminderList().listed
        XCTAssertTrue(listed.contains(roomId), "the Reminders list holds the chat")

        let second = try await signIn(homeserver, user, password)
        try await waitFor("another device of the account to have it") { try await second.rooms().first { $0.id == roomId }?.reminderAt == ms }
        let theirs = try await other.rooms().first { $0.id == roomId }
        XCTAssertNil(theirs?.reminderAt, "the other person has none")

        // their message does not answer it; yours does, on both devices.
        try await other.sendAndWait(roomId: roomId, text: "Theirs \(UUID().uuidString.prefix(8))")
        try await waitFor("their message to reach the list") { try await owner.rooms().first { $0.id == roomId }?.lastIsOwn == false }
        let still = try await owner.rooms().first { $0.id == roomId }?.reminderAt
        XCTAssertEqual(still, ms, "their message does not answer it")
        try await owner.sendAndWait(roomId: roomId, text: "Answer \(UUID().uuidString.prefix(8))")
        try await waitFor("your answer to end it") { try await owner.rooms().first { $0.id == roomId }?.reminderAt == nil }
        try await waitFor("the answer to end it on the other device") { try await second.rooms().first { $0.id == roomId }?.reminderAt == nil }
        let kept = await owner.reminders()
        XCTAssertNil(kept[roomId], "it is gone from the account's data")

        // Clear takes away one not answered.
        try await owner.setReminder(roomId: roomId, at: at)
        let again = try await owner.rooms().first { $0.id == roomId }?.reminderAt
        XCTAssertNotNil(again)
        try await owner.clearReminder(roomId: roomId)
        let cleared = try await owner.rooms().first { $0.id == roomId }?.reminderAt
        XCTAssertNil(cleared)
        let after = try await owner.reminderList().listed
        XCTAssertFalse(after.contains(roomId))
    }

    // MARK: helpers

    private func waitFor(_ what: String, _ seconds: TimeInterval = 20, _ done: () async throws -> Bool) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if try await done() { return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("waited \(Int(seconds)) s for \(what)")
    }

    /// The test's room, made by the first user on the first run, with the second user in it.
    private func testRoom(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> String {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        var roomId = try await owner.rooms().first { $0.roomName == roomName }?.id
        if roomId == nil {
            let created = try await api("POST", ["createRoom"], ["name": roomName, "preset": "private_chat", "invite": [user2]], session: session)
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

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await signInTestDevice(homeserver, user, password)
    }
}
