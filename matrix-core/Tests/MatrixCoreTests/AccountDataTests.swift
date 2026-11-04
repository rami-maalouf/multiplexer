@testable import MatrixCore
import XCTest

/// The account data only this account sees (its own names, archive and delete marks, reminders,
/// frequent emojis, bookmarks), as `@test1` on two devices (`scripts/test-matrix-core.sh`).
final class AccountDataTests: XCTestCase {
    /// A device just signed in has no account data in its store for some seconds after its first
    /// sync. A change made then must start from the server's event, not an empty one, or it would
    /// replace what the other devices saved.
    func testANewDeviceKeepsTheAccountDataSavedBefore() async throws {
        let (homeserver, user, password) = try oneUser()
        let first = try await signIn(homeserver, user, password)
        let (kept, added) = try await twoRooms(first)
        let keptName = "Kept \(token())", addedName = "Added \(token())"
        let keptEmoji = "🦊", addedEmoji = "🦉"
        let later = Date().addingTimeInterval(86_400)
        addTeardownBlock {
            for id in [kept, added] {
                try? await first.setCustomName(roomId: id, name: "")
                try? await first.unarchive(roomId: id)
                try? await first.clearReminder(roomId: id)
            }
        }
        try await first.setCustomName(roomId: kept, name: keptName)
        try await first.archive(roomId: kept)
        try await first.setReminder(roomId: kept, at: later)
        await first.countReaction(keptEmoji)

        // a new device changes before its store has any of the account's data: an emoji count
        // needs no room, so it can come before the first sync. Before the fix this wrote the new
        // count alone, and the one counted before was gone.
        let fresh = try await signIn(homeserver, user, password)
        await fresh.countReaction(addedEmoji)
        // then the others, as soon as its first sync has run.
        try await fresh.startSync(timeout: 60)
        async let name: Void = fresh.setCustomName(roomId: added, name: addedName)
        async let archive: Void = fresh.archive(roomId: added)
        async let reminder: Void = fresh.setReminder(roomId: added, at: later)
        _ = try await (name, archive, reminder)

        // the server has both of each.
        let session = try first.savedSession()
        let names = CustomNames.names(json: try await accountDataOnServer(CustomNames.type, session: session))
        XCTAssertEqual(names[kept], keptName, "the name saved before is gone: \(names)")
        XCTAssertEqual(names[added], addedName)
        let marks = ChatMarks(json: try await accountDataOnServer(ChatMarks.type, session: session))
        XCTAssertNotNil(marks.archived[kept], "the archive saved before is gone")
        XCTAssertNotNil(marks.archived[added])
        let reminders = ReminderStore.reminders(json: try await accountDataOnServer(ReminderStore.type, session: session))
        XCTAssertNotNil(reminders[kept], "the reminder saved before is gone")
        XCTAssertNotNil(reminders[added])
        let emojis = EmojiUses(json: try await accountDataOnServer(MatrixAccount.recentEmojiType, session: session)).frequent(limit: 100)
        XCTAssertTrue(emojis.contains(keptEmoji), "the emoji counted before is gone: \(emojis)")
        XCTAssertTrue(emojis.contains(addedEmoji), "the new device's emoji is missing: \(emojis)")
    }

    /// Another device's bookmark tells this one's list within seconds (`MatrixChange.bookmarks`),
    /// with no reload on a timer.
    func testAnotherDevicesBookmarkShowsWithinSeconds() async throws {
        let (homeserver, user, password) = try oneUser()
        let watcher = try await signIn(homeserver, user, password)
        let changes = BookmarkChanges()
        watcher.onChange { if $0 == .bookmarks { changes.count() } }
        let (roomId, _) = try await twoRooms(watcher)
        _ = await watcher.bookmarks()

        let other = try await signIn(homeserver, user, password)
        _ = try await other.rooms()
        let text = "Saved elsewhere \(token())"
        try await other.sendAndWait(roomId: roomId, text: text)
        let sent = try await other.messages(roomId: roomId, limit: 20).last { $0.body == text }
        let saved = try await other.bookmark(roomId: roomId, messageId: try XCTUnwrap(sent?.id))
        addTeardownBlock { try? await other.removeBookmark(roomId: roomId, eventId: saved.eventId) }

        let start = Date()
        while changes.seen == 0, Date().timeIntervalSince(start) < 15 { try await Task.sleep(nanoseconds: 200_000_000) }
        let after = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(changes.seen, 0, "the list was not told of the other device's bookmark")
        print("the other device's bookmark was announced after \(String(format: "%.1f", after)) s")
        let listed = await watcher.bookmarks().map(\.eventId)
        XCTAssertTrue(listed.contains(saved.eventId), "the list does not have it")
    }

    // MARK: helpers

    /// Two of the account's chats, the same on every run: its test rooms by name.
    private func twoRooms(_ account: MatrixAccount) async throws -> (String, String) {
        let rooms = try await account.rooms()
        let names = ["Multiplexer test", "Multiplexer media test"]
        let ids = names.compactMap { name in rooms.first { $0.roomName == name || $0.name == name }?.id }
        guard ids.count == 2 else { throw XCTSkip("the test rooms \(names) are missing: \(rooms.map(\.name))") }
        return (ids[0], ids[1])
    }

    private func oneUser() throws -> (String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
    }

    private func token() -> String { String(UUID().uuidString.prefix(8)) }

    /// Signs in as a new device that the test signs out at its end, even when it fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                                                     storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"))
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}

private final class BookmarkChanges: @unchecked Sendable {
    private let lock = NSLock()
    private var number = 0
    func count() { lock.withLock { number += 1 } }
    var seen: Int { lock.withLock { number } }
}
