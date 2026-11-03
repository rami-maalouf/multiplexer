@testable import MatrixCore
import XCTest

/// Bookmarks (B14, B20): messages the account saves, kept in its global account data, as two test
/// users (`scripts/test-matrix-core.sh` passes them). The room is this test's own, made on the
/// first run.
final class BookmarksTests: XCTestCase {
    private let roomName = "Multiplexer bookmark test"

    /// A saved message keeps its chat, event, sender, text and kind, the last saved first; the
    /// account's other device has the same list and opens the chat at it; the other person gets no
    /// bookmark and no event in the chat. Removing one removes it on every device.
    func testABookmarkFollowsTheAccountAndReachesNoOne() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let (owner, other, roomId) = try await twoPeopleInARoom(homeserver, user, password, user2, password2)
        // a failed run may have left some of this room's.
        for old in await owner.bookmarks() where old.roomId == roomId {
            try await owner.removeBookmark(roomId: roomId, eventId: old.eventId)
        }

        let theirs = "Save this \(token())"
        try await other.send(roomId: roomId, text: theirs)
        let received = try await message(owner, roomId, within: 30) { $0.body == theirs }
        XCTAssertFalse(received.eventId.isEmpty, "a message from the server has its event id")
        let mine = "Mine too \(token())"
        try await owner.send(roomId: roomId, text: mine)
        let sent = try await message(owner, roomId, within: 30) { $0.body == mine && $0.sendState == .sent && !$0.eventId.isEmpty }

        // two changes in a row both stay.
        async let first = owner.bookmark(roomId: roomId, messageId: received.id)
        async let second = owner.bookmark(roomId: roomId, messageId: sent.id)
        let (saved, savedOwn) = try await (first, second)
        XCTAssertEqual(saved.eventId, received.eventId)
        XCTAssertEqual(saved.sender, user2)
        XCTAssertFalse(saved.isOwn)
        XCTAssertEqual(saved.body, theirs)
        XCTAssertEqual(saved.kind, .text)
        XCTAssertEqual(saved.timestamp, received.timestamp)
        XCTAssertTrue(savedOwn.isOwn)

        let here = await owner.bookmarks().filter { $0.roomId == roomId }
        XCTAssertEqual(Set(here.map(\.eventId)), [received.eventId, sent.eventId], "this device shows both at once")
        XCTAssertGreaterThanOrEqual(here[0].savedAt, here[1].savedAt, "the last saved first")

        let second2 = try await signIn(homeserver, user, password)
        _ = try await second2.rooms()
        let start = Date()
        var there = await second2.bookmarks().filter { $0.roomId == roomId }
        while there.count < 2, Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            there = await second2.bookmarks().filter { $0.roomId == roomId }
        }
        XCTAssertEqual(Set(there.map(\.eventId)), [received.eventId, sent.eventId], "the account's other device has them")
        let shown = try await second2.showMessage(roomId: roomId, eventId: received.eventId)
        XCTAssertNotNil(shown, "the other device opens the chat at the saved message")

        let othersList = await other.bookmarks().filter { $0.roomId == roomId }
        XCTAssertTrue(othersList.isEmpty, "the other person has no bookmark")
        _ = try await message(other, roomId, within: 30) { $0.body == mine }
        let newest = try await other.messages(roomId: roomId, limit: 20).last
        XCTAssertEqual(newest?.body, mine, "a bookmark adds no event to the chat")

        try await owner.removeBookmark(roomId: roomId, eventId: received.eventId)
        let left = await owner.bookmarks().filter { $0.roomId == roomId }
        XCTAssertEqual(left.map(\.eventId), [sent.eventId], "this device forgets it at once")
        let gone = Date()
        var thereAfter = await second2.bookmarks().filter { $0.roomId == roomId }
        while thereAfter.count != 1, Date().timeIntervalSince(gone) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            thereAfter = await second2.bookmarks().filter { $0.roomId == roomId }
        }
        XCTAssertEqual(thereAfter.map(\.eventId), [sent.eventId], "the other device forgets it too")
        try await owner.removeBookmark(roomId: roomId, eventId: sent.eventId)
    }

    /// A device just signed in lists the bookmarks saved before at once (its store is empty until
    /// its first sync), then saves one more: both stay, here and on the first device.
    func testANewDeviceKeepsTheBookmarksSavedBefore() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let (owner, other, roomId) = try await twoPeopleInARoom(homeserver, user, password, user2, password2)
        for old in await owner.bookmarks() where old.roomId == roomId {
            try await owner.removeBookmark(roomId: roomId, eventId: old.eventId)
        }
        let first = "Kept \(token())", second = "Added \(token())"
        try await other.send(roomId: roomId, text: first)
        try await other.send(roomId: roomId, text: second)
        let kept = try await message(owner, roomId, within: 30) { $0.body == first }
        _ = try await message(owner, roomId, within: 30) { $0.body == second }
        try await owner.bookmark(roomId: roomId, messageId: kept.id)

        // the list first, as an app asks for it at launch, before anything has synced.
        let fresh = try await signIn(homeserver, user, password)
        let before = await fresh.bookmarks().filter { $0.roomId == roomId }.map(\.eventId)
        XCTAssertTrue(before.contains(kept.eventId), "a new device lists the bookmarks saved before: \(before)")
        // the list starts the sync, as an app's chat list does; then the chat opens at once.
        _ = try await fresh.rooms()
        let shown = try await fresh.messages(roomId: roomId, limit: 20)
        let added = try XCTUnwrap(shown.last { $0.body == second }, "the new device has the message")
        try await fresh.bookmark(roomId: roomId, messageId: added.id)

        let here = await fresh.bookmarks().filter { $0.roomId == roomId }.map(\.eventId)
        XCTAssertEqual(Set(here), [kept.eventId, added.eventId], "the new device keeps the one saved before")
        let start = Date()
        var there = await owner.bookmarks().filter { $0.roomId == roomId }.map(\.eventId)
        while Set(there) != [kept.eventId, added.eventId], Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            there = await owner.bookmarks().filter { $0.roomId == roomId }.map(\.eventId)
        }
        XCTAssertEqual(Set(there), [kept.eventId, added.eventId], "the first device has both")
        for b in await owner.bookmarks() where b.roomId == roomId {
            try await owner.removeBookmark(roomId: roomId, eventId: b.eventId)
        }
    }

    /// The event's content keeps what the list shows, cuts a long text, and keeps keys it does not know.
    func testTheContentKeepsOtherKeysAndCutsLongTexts() throws {
        let json = #"{"bookmarks":[{"room":"!a:x","event":"$b","sender":"@c:x","senderName":"C","body":"hi","kind":"voice","fileName":"","ts":5,"savedAt":9}],"labels":{"k":1}}"#
        let list = Bookmarks(json: json)
        XCTAssertEqual(list.items.count, 1)
        XCTAssertEqual(list.items[0].kind, .voice)
        XCTAssertEqual(list.items[0].timestamp, 5)
        XCTAssertEqual(list.items[0].savedAt, 9)
        let again = Bookmarks(json: list.json())
        XCTAssertEqual(again, list)
        XCTAssertTrue(list.json().contains(#""labels":{"k":1}"#), "another key stays: \(list.json())")
        let long = SavedBookmark(roomId: "!a:x", eventId: "$b", sender: "@c:x", senderName: "C", body: String(repeating: "a", count: 900),
                                 kind: .text, fileName: "", timestamp: 1, savedAt: 2)
        XCTAssertEqual(long.body.count, Bookmarks.bodyLimit)
        XCTAssertTrue(Bookmarks(json: "not json").items.isEmpty)
        XCTAssertTrue(Bookmarks(json: #"{"bookmarks":[{"room":"","event":"$b"}]}"#).items.isEmpty, "an entry with no room is dropped")
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

    /// The first user saves, the second sends, in the test's room (made on the first run).
    private func twoPeopleInARoom(_ homeserver: String, _ user: String, _ password: String, _ user2: String, _ password2: String)
        async throws -> (owner: MatrixAccount, other: MatrixAccount, roomId: String) {
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId: String
        if let id = try await owner.rooms().first(where: { $0.name == roomName })?.id {
            roomId = id
        } else {
            let created = try await api("POST", ["createRoom"], ["name": roomName, "preset": "private_chat", "invite": [user2]],
                                        session: try owner.savedSession())
            roomId = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        _ = try await api("POST", ["join", roomId], [:], session: try other.savedSession())
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            if try await other.rooms().contains(where: { $0.id == roomId }) { return (owner, other, roomId) }
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
