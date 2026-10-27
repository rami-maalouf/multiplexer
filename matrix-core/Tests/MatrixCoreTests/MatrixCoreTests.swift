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
        let messages = try await second.messages(roomId: roomId, limit: 20)
        XCTAssertEqual(messages.last?.body, text, "messages: \(messages.map(\.body))")
        XCTAssertEqual(messages.last?.isOwn, true)
        try await second.signOut()
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
