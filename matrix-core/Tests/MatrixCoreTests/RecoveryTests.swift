@testable import MatrixCore
import XCTest

/// The account's recovery, as a test user (`scripts/test-matrix-core.sh` passes it): a device
/// that signs in after an encrypted message has no key for it, and reads it once it enters the
/// account's recovery key. The test turns recovery on, and off again at its end.
final class RecoveryTests: XCTestCase {
    private let roomName = "Multiplexer recovery test"

    func testAnOlderEncryptedMessageShowsAfterTheRecoveryKey() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        guard user.hasPrefix("@test") else { throw XCTSkip("recovery is changed only on a test user") }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"

        // the first device: recovery on (a run that failed may have left it on), then an
        // encrypted message, whose key goes into the backup.
        let first = try await signIn(homeserver, user, password)
        _ = try await first.rooms()
        try await resetRecovery(first)
        let key = try await first.enableRecovery()
        addTeardownBlock { [self] in try? await resetRecovery(first) }
        XCTAssertFalse(key.isEmpty)
        let existing = try await first.rooms().first { $0.name == roomName }?.id
        let roomId: String
        if let existing { roomId = existing } else { roomId = try await first.createRoom(name: roomName, encrypted: true) }
        _ = try await first.messages(roomId: roomId, limit: 20)
        let text = "Recovered \(UUID().uuidString)"
        try await first.sendAndWait(roomId: roomId, text: text)
        try await first.waitForBackup()

        // a device that signs in after it has no key for it: the message waits.
        let later = try await signIn(homeserver, user, password)
        _ = try await later.rooms()
        let waiting = try await newest(later, roomId) { $0.isOwn && $0.waitingForKey }
        XCTAssertTrue(waiting.body.isEmpty || waiting.body != text, "the new device read the message without the key")
        let status = await later.recoveryStatus()
        XCTAssertEqual(status, .incomplete, "the account has recovery, which this device cannot read yet")

        // a wrong key is refused, and the message still waits.
        do {
            try await later.recover(recoveryKey: "EsTj 3yST y93F SLpB jJsz eAXc 2XzA ygD3 w69H fGaN TKBj jXEd")
            XCTFail("a wrong recovery key opened the backup")
        } catch let error as RecoveryKeyError {
            print("a wrong recovery key: \(error)")
        }

        // the right key: the message shows as its text.
        try await later.recover(recoveryKey: key)
        let shown = try await newest(later, roomId, within: 40) { $0.isOwn && $0.body == text }
        XCTAssertFalse(shown.waitingForKey)
        let after = await later.recoveryStatus()
        XCTAssertEqual(after, .enabled)
    }

    /// For a drive of Settings' Encryption: leaves recovery on for the test user, and writes its
    /// key to `MATRIX_TEST_RECOVERY_FILE` (readable only by its owner). Skipped without it; the
    /// next run of the test above turns recovery off again.
    func testLeaveRecoveryOnForADrive() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["MATRIX_TEST_RECOVERY_FILE"], !path.isEmpty else { throw XCTSkip("MATRIX_TEST_RECOVERY_FILE is not set") }
        guard let user = env["MATRIX_TEST_USER"], user.hasPrefix("@test"), let password = env["MATRIX_TEST_PASSWORD"] else {
            throw XCTSkip("recovery is changed only on a test user")
        }
        let account = try await signIn(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        _ = try await account.rooms()
        try await resetRecovery(account)
        let key = try await account.enableRecovery()
        FileManager.default.createFile(atPath: path, contents: Data(key.utf8), attributes: [.posixPermissions: 0o600])
    }

    // MARK: helpers

    /// The newest message of the chat that matches `match`, once there is one.
    private func newest(_ account: MatrixAccount, _ roomId: String, within seconds: TimeInterval = 20,
                        _ match: (Message) -> Bool) async throws -> Message {
        let start = Date()
        while true {
            if let found = try await account.messages(roomId: roomId, limit: 20).last(where: match) { return found }
            if Date().timeIntervalSince(start) > seconds {
                let last = try await account.messages(roomId: roomId, limit: 20).last
                XCTFail("no matching message within \(Int(seconds)) s; the newest: \(String(describing: last))")
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// Turns the account's recovery off from any device, also one without the backup (a run that
    /// failed, or the drive helper, may have left it on): the backup's versions are deleted and
    /// the key's storage is emptied, through the client-server api.
    private func resetRecovery(_ account: MatrixAccount) async throws {
        if await account.recoveryStatus() == .disabled { return }
        let session = try account.savedSession()
        while let version = try await api("GET", ["room_keys", "version"], session: session)["version"] as? String {
            _ = try await api("DELETE", ["room_keys", "version", version], session: session)
        }
        _ = try await api("PUT", ["user", session.userId, "account_data", "m.secret_storage.default_key"], [:], session: session)
        // this device keeps its own view of recovery until its next start; turning recovery on
        // again asks the server, which has no backup now. Devices that sign in later see it off.
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
        try await signInTestDevice(homeserver, user, password)
    }
}
