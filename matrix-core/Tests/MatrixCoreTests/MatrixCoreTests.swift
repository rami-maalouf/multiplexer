import MatrixCore
import UIKit
import XCTest

/// Talks to a real homeserver. `scripts/test-matrix-core.sh` passes the account
/// (its password from the Mac's Keychain); without it the test is skipped.
final class MatrixCoreTests: XCTestCase {
    private let roomName = "Multiplexer test"
    private let encryptedRoomName = "Multiplexer encrypted test"

    func testSignInSendAndReadBackOnANewDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let text = "Multiplexer test \(UUID().uuidString)"

        // the first device finds or makes the test room, sends, and signs out.
        let first = try await signIn(homeserver, user, password)
        let rooms = try await first.rooms()
        let existing = rooms.first { $0.name == roomName }?.id
        let roomId: String
        if let existing { roomId = existing } else { roomId = try await first.createRoom(name: roomName) }
        try await first.sendAndWait(roomId: roomId, text: text)
        try await first.signOut()

        // a second device with an empty store must get both from the server.
        let second = try await signIn(homeserver, user, password)
        let seen = try await second.rooms()
        XCTAssertTrue(seen.contains { $0.id == roomId && $0.name == roomName }, "rooms: \(seen.map(\.name))")
        let summary = seen.first { $0.id == roomId }
        XCTAssertEqual(summary?.lastMessage, text)
        XCTAssertEqual(summary?.lastIsOwn, true)
        XCTAssertGreaterThan(summary?.lastTimestamp ?? 0, 0)
        let messages = try await second.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(messages.last?.body, text, "messages: \(messages.map(\.body))")
        XCTAssertEqual(messages.last?.isOwn, true)
        try await second.signOut()
    }

    /// Sends MATRIX_TEST_FILL numbered messages to the test room, so the app has a long chat
    /// to show (only its last 20, opened at the newest). Runs only when that variable is set.
    func testFillTheTestRoom() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let count = Int(env["MATRIX_TEST_FILL"] ?? ""), count > 0,
              let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_FILL is not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        for n in 1...count {
            try await account.sendAndWait(roomId: roomId, text: "Fill \(n) of \(count)", timeout: 120)
        }
        try await account.signOut()
    }

    func testAnOpenChatSeesAMessageFromAnotherDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let reader = try await signIn(homeserver, user, password)
        let changes = Changes()
        reader.onChange { changes.add($0) }
        let rooms = try await reader.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        let opened = try await reader.messages(roomId: roomId, limit: 20)
        // a chat opened again reads its live timeline: no paging back, no wait.
        let again = Date()
        _ = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertLessThan(Date().timeIntervalSince(again), 0.3)

        let writer = try await signIn(homeserver, user, password)
        let text = "Live \(UUID().uuidString)"
        _ = try await writer.rooms()
        try await writer.sendAndWait(roomId: roomId, text: text)
        try await writer.signOut()

        // the reader asks again, as the app does when told; it must not page back.
        let start = Date()
        var last = try await reader.messages(roomId: roomId, limit: 20).last?.body
        while last != text, Date().timeIntervalSince(start) < 10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            last = try await reader.messages(roomId: roomId, limit: 20).last?.body
        }
        XCTAssertEqual(last, text)
        // the new message is added; none that the chat showed is dropped.
        let now = try await reader.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(Array(now.prefix(opened.count)).map(\.id), opened.map(\.id))
        XCTAssertEqual(now.count, opened.count + 1)
        print("the open chat had the new message after \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        // the room with the newest message comes first in the list.
        var first = try await reader.rooms().first?.id
        while first != roomId, Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            first = try await reader.rooms().first?.id
        }
        XCTAssertEqual(first, roomId, "the room with the newest message is not first")
        XCTAssertTrue(changes.seen(.room(roomId)), "no change event for the open chat")
        XCTAssertTrue(changes.seen(.rooms), "no change event for the room list")
        let summary = try await reader.rooms().first { $0.id == roomId }
        XCTAssertEqual(summary?.lastMessage, text)
        try await reader.signOut()
    }

    func testASentMessageShowsAtOnceThenSentAndARefusedOneFails() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        _ = try await account.messages(roomId: roomId, limit: 20)

        // a message shows at once, then as sent, under the same id.
        let text = "Send state \(UUID().uuidString)"
        try await account.send(roomId: roomId, text: text)
        let queued = try await mine(account, roomId, text, within: 5)
        let sent = try await mine(account, roomId, text, within: 15) { $0.sendState == .sent }
        XCTAssertEqual(sent.id, queued.id, "the message changed its id when it was sent")

        // a message over the spec's 65,536-byte event limit is refused, and shows as failed.
        let tooLarge = String(repeating: "x", count: 70_000)
        try await account.send(roomId: roomId, text: tooLarge)
        let failed = try await mine(account, roomId, tooLarge, within: 20) { $0.sendState == .failed }
        // retrying it does not throw; the server refuses it again.
        try await account.retry(roomId: roomId, messageId: failed.id)
        let again = try await mine(account, roomId, tooLarge, within: 20) { $0.sendState == .failed }
        XCTAssertEqual(again.id, failed.id)
        // discarding it removes it from the chat; discarding a sent message does nothing.
        try await account.discard(roomId: roomId, messageId: failed.id)
        try await account.discard(roomId: roomId, messageId: sent.id)
        let start = Date()
        var left = try await account.messages(roomId: roomId, limit: 20)
        while left.contains(where: { $0.id == failed.id }), Date().timeIntervalSince(start) < 10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            left = try await account.messages(roomId: roomId, limit: 20)
        }
        XCTAssertFalse(left.contains { $0.id == failed.id }, "the failed message is still in the chat")
        XCTAssertTrue(left.contains { $0.id == sent.id && $0.sendState == .sent }, "the sent message was touched")
        try await account.signOut()
    }

    /// The newest own message with this text, once it matches `done`.
    private func mine(_ account: MatrixAccount, _ roomId: String, _ text: String, within seconds: TimeInterval,
                      _ done: (Message) -> Bool = { _ in true }) async throws -> Message {
        let start = Date()
        while true {
            let found = try await account.messages(roomId: roomId, limit: 20).last { $0.isOwn && $0.body == text }
            if let found, done(found) { return found }
            if Date().timeIntervalSince(start) > seconds {
                throw MatrixCoreError.timedOut("message \(text.prefix(20)): \(found.map { "\($0.sendState)" } ?? "none")")
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func testAPhotoMessageHasItsSizeAndDownloads() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        _ = try await account.messages(roomId: roomId, limit: 20)

        // a portrait photo, sent as another client would: uploaded, then an m.image event.
        let caption = "Photo \(UUID().uuidString)"
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 900), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).jpegData(withCompressionQuality: 0.8) { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 600, height: 900))
        }
        try await sendPhoto(jpeg, width: 600, height: 900, caption: caption, roomId: roomId, session: try account.savedSession())

        let start = Date()
        var photo = try await account.messages(roomId: roomId, limit: 20).last { $0.body == caption }
        while photo == nil, Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 200_000_000)
            photo = try await account.messages(roomId: roomId, limit: 20).last { $0.body == caption }
        }
        let found = try XCTUnwrap(photo, "the photo message did not arrive")
        XCTAssertEqual(found.image?.width, 600)
        XCTAssertEqual(found.image?.height, 900)

        let directory = freshDirectory()
        let thumbnail = try await account.imageFile(roomId: roomId, messageId: found.id, full: false, directory: directory)
        let full = try await account.imageFile(roomId: roomId, messageId: found.id, full: true, directory: directory)
        let small = try XCTUnwrap(UIImage(contentsOfFile: thumbnail.path), "the thumbnail is not a picture")
        let large = try XCTUnwrap(UIImage(contentsOfFile: full.path), "the full file is not a picture")
        XCTAssertEqual(large.size, CGSize(width: 600, height: 900))
        XCTAssertLessThanOrEqual(max(small.size.width, small.size.height), 900)
        XCTAssertEqual(small.size.width / small.size.height, 600.0 / 900.0, accuracy: 0.02)
        // a second call finds the file and downloads nothing.
        let written = try FileManager.default.attributesOfItem(atPath: full.path)[.modificationDate] as? Date
        _ = try await account.imageFile(roomId: roomId, messageId: found.id, full: true, directory: directory)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: full.path)[.modificationDate] as? Date, written)
        try await account.signOut()
    }

    func testARoomPictureShowsInTheListAndDownloads() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        let before = rooms.first { $0.id == roomId }?.avatarName ?? ""

        // a new picture for the test room, set as another client would.
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).jpegData(withCompressionQuality: 0.8) { c in
            UIColor.systemOrange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        let session = try account.savedSession()
        let uri = try await upload(jpeg, session: session)
        try await putState(["url": uri], type: "m.room.avatar", roomId: roomId, session: session)

        let start = Date()
        var name = before
        while name == before, Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            name = try await account.rooms().first { $0.id == roomId }?.avatarName ?? ""
        }
        XCTAssertNotEqual(name, before, "the room's summary did not get the new picture")
        XCTAssertFalse(name.isEmpty)
        let downloaded = try await account.avatarFile(roomId: roomId, directory: freshDirectory())
        let file = try XCTUnwrap(downloaded)
        XCTAssertEqual(file.lastPathComponent, name)
        let picture = try XCTUnwrap(UIImage(contentsOfFile: file.path), "the room picture is not a picture")
        XCTAssertLessThanOrEqual(max(picture.size.width, picture.size.height), 400)
    }

    private func upload(_ jpeg: Data, session: SavedSession) async throws -> String {
        var upload = URLRequest(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/media/v3/upload"))
        upload.httpMethod = "POST"
        upload.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (uploaded, _) = try await URLSession.shared.upload(for: upload, from: jpeg)
        return try XCTUnwrap((try JSONSerialization.jsonObject(with: uploaded) as? [String: Any])?["content_uri"] as? String)
    }

    private func putState(_ content: [String: Any], type: String, roomId: String, session: SavedSession) async throws {
        var put = URLRequest(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/rooms")
            .appendingPathComponent(roomId).appendingPathComponent("state").appendingPathComponent(type))
        put.httpMethod = "PUT"
        put.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        put.setValue("application/json", forHTTPHeaderField: "Content-Type")
        put.httpBody = try JSONSerialization.data(withJSONObject: content)
        let (_, response) = try await URLSession.shared.data(for: put)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    /// Uploads a jpeg and sends it as an m.image event, through the client-server api.
    private func sendPhoto(_ jpeg: Data, width: Int, height: Int, caption: String, roomId: String, session: SavedSession) async throws {
        let base = URL(string: session.homeserverUrl)!
        var upload = URLRequest(url: base.appendingPathComponent("_matrix/media/v3/upload"))
        upload.httpMethod = "POST"
        upload.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (uploaded, _) = try await URLSession.shared.upload(for: upload, from: jpeg)
        let uri = try XCTUnwrap((try JSONSerialization.jsonObject(with: uploaded) as? [String: Any])?["content_uri"] as? String)
        var send = URLRequest(url: base.appendingPathComponent("_matrix/client/v3/rooms").appendingPathComponent(roomId)
            .appendingPathComponent("send/m.room.message").appendingPathComponent(UUID().uuidString))
        send.httpMethod = "PUT"
        send.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        send.setValue("application/json", forHTTPHeaderField: "Content-Type")
        send.httpBody = try JSONSerialization.data(withJSONObject: [
            "msgtype": "m.image", "url": uri, "body": caption, "filename": "photo.jpg",
            "info": ["w": width, "h": height, "mimetype": "image/jpeg", "size": jpeg.count],
        ])
        let (_, response) = try await URLSession.shared.data(for: send)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    func testAnEncryptedRoomShowsANewMessageAsText() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let reader = try await signIn(homeserver, user, password)
        print("recovery on this account: \(await reader.recoveryStatus())")
        let rooms = try await reader.rooms()
        let roomId: String
        if let existing = rooms.first(where: { $0.name == encryptedRoomName })?.id {
            roomId = existing
        } else {
            roomId = try await reader.createRoom(name: encryptedRoomName, encrypted: true)
        }
        _ = try await reader.messages(roomId: roomId, limit: 20)

        // another device sends after the reader signed in, so it shares the key with the reader.
        let writer = try await signIn(homeserver, user, password)
        _ = try await writer.rooms()
        let text = "Encrypted \(UUID().uuidString)"
        try await writer.sendAndWait(roomId: roomId, text: text)

        let start = Date()
        var seen = try await reader.messages(roomId: roomId, limit: 20).last { $0.isOwn }
        while seen?.body != text, Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            seen = try await reader.messages(roomId: roomId, limit: 20).last { $0.isOwn }
        }
        XCTAssertEqual(seen?.body, text, "the reader shows \(seen?.waitingForKey == true ? "a message waiting for its key" : "nothing")")
        XCTAssertEqual(seen?.waitingForKey, false)
        print("the reader showed the encrypted message after \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
    }

    func testOlderMessagesLoadUntilTheStart() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        let opened = try await account.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(opened.count, 20)
        let openedAtStart = try await account.isAtStart(roomId: roomId)
        XCTAssertFalse(openedAtStart, "the test room has more than 20 messages")

        // 20 more, before the ones shown; those stay as they were.
        try await account.loadOlder(roomId: roomId, count: 20)
        let more = try await account.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(more.count, 40)
        XCTAssertEqual(Array(more.suffix(20)).map(\.id), opened.map(\.id))

        // on to the room's first message; there, a load changes nothing.
        for _ in 0..<20 {
            if try await account.isAtStart(roomId: roomId) { break }
            try await account.loadOlder(roomId: roomId, count: 20)
        }
        let atStart = try await account.isAtStart(roomId: roomId)
        XCTAssertTrue(atStart)
        let all = try await account.messages(roomId: roomId, limit: 20)
        try await account.loadOlder(roomId: roomId, count: 20)
        let again = try await account.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(again.count, all.count)
        print("the test room has \(all.count) messages")
    }

    func testSignOutOnServerWithoutTheStore() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let saved = try account.savedSession()
        let before = try await whoamiStatus(saved)
        XCTAssertEqual(before, 200)

        // the store is gone (a reinstall): only the saved session is left.
        let signedOut = await MatrixAccount.signOutOnServer(saved, scratchDirectory: freshDirectory())
        XCTAssertTrue(signedOut)
        // the server may accept the old token for a moment after the sign-out.
        let start = Date()
        var after = try await whoamiStatus(saved)
        while after != 401, Date().timeIntervalSince(start) < 10 {
            try await Task.sleep(nanoseconds: 500_000_000)
            after = try await whoamiStatus(saved)
        }
        XCTAssertEqual(after, 401, "the server still accepts the old token")
        print("the old token was refused after \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        // a second try finds the session gone, which also counts as done.
        let again = await MatrixAccount.signOutOnServer(saved, scratchDirectory: freshDirectory())
        XCTAssertTrue(again)
        // a server that cannot be reached is not done: the app keeps the session to try again.
        var unreachable = saved
        unreachable.homeserverUrl = "https://multiplexer.invalid"
        let offline = await MatrixAccount.signOutOnServer(unreachable, scratchDirectory: freshDirectory())
        XCTAssertFalse(offline)
    }

    /// The http status of the server's whoami for this session's token.
    private func whoamiStatus(_ saved: SavedSession) async throws -> Int {
        var request = URLRequest(url: URL(string: saved.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/account/whoami"))
        request.setValue("Bearer \(saved.accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    func testSignInNamesWhyItFailed() async throws {
        let homeserver = ProcessInfo.processInfo.environment["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        // synapse answers an unknown user as it answers a wrong password, so no real account is tried.
        await assertSignIn(homeserver: homeserver, user: "multiplexer-no-such-user-\(UUID().uuidString.prefix(8))",
                           fails: .wrongPassword)
        // .invalid never resolves (rfc 6761).
        await assertSignIn(homeserver: "multiplexer.invalid", user: "nobody", fails: .serverNotFound)
    }

    private func assertSignIn(homeserver: String, user: String, fails expected: SignInError, line: UInt = #line) async {
        do {
            _ = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: "not the password",
                                               deviceName: "Multiplexer test", storeDirectory: freshDirectory())
            XCTFail("signed in to \(homeserver)", line: line)
        } catch {
            XCTAssertEqual(error as? SignInError, expected, "\(error)", line: line)
        }
    }

    /// Signs in as a new device that the test signs out at its end, even when the test
    /// fails, so a failed run leaves no device on the account.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                     deviceName: "Multiplexer test", storeDirectory: freshDirectory())
        addTeardownBlock { try? await account.signOut() }
        return account
    }

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
    }
}

/// The change events an account sent, from any thread.
private final class Changes: @unchecked Sendable {
    private let lock = NSLock()
    private var all: Set<MatrixChange> = []
    func add(_ change: MatrixChange) { lock.withLock { _ = all.insert(change) } }
    func seen(_ change: MatrixChange) -> Bool { lock.withLock { all.contains(change) } }
}
