import MatrixCore
import XCTest

/// Talks to a real homeserver. `scripts/test-matrix-core.sh` passes the account
/// (its password from the Mac's Keychain); without it the test is skipped.
final class MatrixCoreTests: XCTestCase {
    private let roomName = "Multiplexer test"

    func testSignInSendAndReadBackOnANewDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let text = "Multiplexer test \(UUID().uuidString)"

        // the first device finds or makes the test room, sends, and signs out.
        let first = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                   deviceName: "Multiplexer test", storeDirectory: freshDirectory())
        let rooms = try await first.rooms()
        let existing = rooms.first { $0.name == roomName }?.id
        let roomId: String
        if let existing { roomId = existing } else { roomId = try await first.createRoom(name: roomName) }
        try await first.send(roomId: roomId, text: text)
        try await first.signOut()

        // a second device with an empty store must get both from the server.
        let second = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                    deviceName: "Multiplexer test", storeDirectory: freshDirectory())
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
        let account = try await MatrixAccount.signIn(homeserver: env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user: user,
                                                     password: password, deviceName: "Multiplexer test", storeDirectory: freshDirectory())
        let rooms = try await account.rooms()
        let roomId = try XCTUnwrap(rooms.first { $0.name == roomName }?.id)
        for n in 1...count {
            try await account.send(roomId: roomId, text: "Fill \(n) of \(count)", timeout: 120)
        }
        try await account.signOut()
    }

    func testSignOutOnServerWithoutTheStore() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await MatrixAccount.signIn(homeserver: env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user: user,
                                                     password: password, deviceName: "Multiplexer test", storeDirectory: freshDirectory())
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

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
    }
}
