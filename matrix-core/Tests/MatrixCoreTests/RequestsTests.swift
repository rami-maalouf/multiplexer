@testable import MatrixCore
import XCTest

/// Requests (L3): a chat this account is invited to. `@test2` owns "Multiplexer request test" and
/// invites `@test1`, who declines it, then accepts it, then leaves it at the end, so the next run
/// starts the same way.
final class RequestsTests: XCTestCase {
    private let roomName = "Multiplexer request test"

    func testAnInviteIsARequestThatCanBeDeclinedOrAccepted() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let owner = try await signIn(homeserver, user2, password2)
        let roomId: String
        if let id = try await owner.rooms().first(where: { $0.name == roomName })?.id { roomId = id } else { roomId = try await owner.createRoom(name: roomName) }

        let me = try await signIn(homeserver, user, password)
        // a run that stopped half way left this account in the room, or invited.
        let joined = try await me.rooms().contains { $0.id == roomId }
        let invited = try await me.requests().contains { $0.id == roomId }
        if joined || invited {
            try await me.decline(request: roomId)
            try await until("the room is left") { try await !me.rooms().contains { $0.id == roomId } }
        }
        addTeardownBlock { try? await me.decline(request: roomId) }

        // invited: a request, with who invited, and not a chat in the list.
        try await owner.invite(roomId: roomId, userId: user)
        try await until("the invite is a request") { try await me.requests().contains { $0.id == roomId } }
        let found = try await me.requests().first { $0.id == roomId }
        let request = try XCTUnwrap(found)
        XCTAssertEqual(request.name, roomName)
        XCTAssertEqual(request.inviterId, user2)
        XCTAssertFalse(request.isDirect)
        let listed = try await me.rooms().contains { $0.id == roomId }
        XCTAssertFalse(listed)

        // declined: no request, no chat.
        try await me.decline(request: roomId)
        try await until("the declined request goes") { try await !me.requests().contains { $0.id == roomId } }
        let afterDecline = try await me.rooms().contains { $0.id == roomId }
        XCTAssertFalse(afterDecline)

        // invited again and accepted: a chat in the list, no request.
        try await owner.invite(roomId: roomId, userId: user)
        try await until("the second invite is a request") { try await me.requests().contains { $0.id == roomId } }
        try await me.accept(request: roomId)
        try await until("the accepted request is a chat") { try await me.rooms().contains { $0.id == roomId } }
        let afterAccept = try await me.requests().contains { $0.id == roomId }
        XCTAssertFalse(afterAccept)
    }

    /// The list, the requests and the communities asked at once on a new device, as the app asks
    /// them at launch, share one sync: each starting its own crashed in the sdk's room list.
    func testSourcesAskedAtOnceShareOneSync() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        async let rooms = account.rooms()
        async let requests = account.requests()
        async let communities = account.communities()
        let (listed, _, _) = try await (rooms, requests, communities)
        XCTAssertFalse(listed.isEmpty)
    }

    /// Waits up to 20 s for `done`.
    private func until(_ what: String, _ done: () async throws -> Bool) async throws {
        let start = Date()
        while try await !done() {
            if Date().timeIntervalSince(start) > 20 { XCTFail("timed out: \(what)"); return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// Signs in as a new device that the test signs out at its end, even when the test fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password,
                                                     deviceName: "Multiplexer test", storeDirectory: directory)
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}
