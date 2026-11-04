@testable import MatrixCore
import XCTest

final class LabelsTests: XCTestCase {
    func testLabelsSyncAndGroupChatsWithoutChangingTheirLists() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let one = try await testRoom(owner, other, user2: user2, roomName: "Multiplexer labels test one")
        let two = try await testRoom(owner, other, user2: user2, roomName: "Multiplexer labels test two")
        try await other.sendAndWait(roomId: one, text: "Labels \(UUID().uuidString)")
        try await other.sendAndWait(roomId: two, text: "Labels \(UUID().uuidString)")
        try await owner.unarchive(roomId: one)
        try await owner.unarchive(roomId: two)
        let second = try await signIn(homeserver, user, password)
        let name = "Labels \(UUID().uuidString.prefix(8))"
        let label = try await owner.createLabel(name: "  \(name)  ")
        XCTAssertEqual(label.name, name)
        addTeardownBlock { try? await owner.deleteLabel(id: label.id) }
        try await owner.setLabel(id: label.id, roomIds: [one, two, one], included: true)
        try await waitFor("labels on another device", 30) {
            await second.labels().first { $0.id == label.id }?.roomIds.count == 2
        }
        let theirs = await other.labels()
        XCTAssertFalse(theirs.contains { $0.id == label.id }, "labels must stay private to this account")
        try await owner.renameLabel(id: label.id, name: "Renamed \(name)")
        try await waitFor("a renamed label", 30) {
            await second.labels().first { $0.id == label.id }?.name == "Renamed \(name)"
        }
        try await owner.archive(roomId: one)
        try await owner.setLowPriority(roomId: two, true)
        try await owner.markRead(roomId: one)
        try await owner.setMarkedUnread(roomId: two, true)
        let all = try await owner.labelInbox(id: label.id)
        XCTAssertEqual(all.listed, Set([one, two]), "labels include archived and low-priority chats")
        XCTAssertEqual(all.chats.first { $0.id == one }?.isArchived, true)
        XCTAssertEqual(all.chats.first { $0.id == two }?.isLowPriority, true)
        let unread = try await owner.labelInbox(id: label.id, filter: .unread)
        XCTAssertEqual(unread.listed, Set([two]))
        let wrongNetwork = try await owner.labelInbox(id: label.id, network: "whatsapp")
        XCTAssertTrue(wrongNetwork.listed.isEmpty)
        try await owner.hide(roomId: one)
        let hidden = try await owner.labelInbox(id: label.id)
        XCTAssertEqual(hidden.listed, Set([two]), "a deleted chat must not show in a label")
        try await second.renameLabel(id: label.id, name: "Other device \(name)")
        try await owner.setLabel(id: label.id, roomIds: [two], included: false)
        let keptName = await owner.labels().first { $0.id == label.id }?.name
        XCTAssertEqual(keptName, "Other device \(name)", "a membership write must preserve the other device's rename")
        try await waitFor("removed membership", 30) {
            await second.labels().first { $0.id == label.id }?.roomIds == [one]
        }
        try await owner.deleteLabel(id: label.id)
        try await waitFor("deleted label", 30) { await !second.labels().contains { $0.id == label.id } }
        let preserved = try await owner.rooms().first { $0.id == two }
        XCTAssertEqual(preserved?.isLowPriority, true, "deleting the label must not change its chats")
        try await owner.setLowPriority(roomId: two, false)
        try await owner.unarchive(roomId: one)
        try await owner.markRead(roomId: two)
    }

    func testLabelNamesRejectBlankAndCaseInsensitiveDuplicates() async throws {
        let (server, user, password, _, _) = try twoUsers()
        let owner = try await signIn(server, user, password)
        do { _ = try await owner.createLabel(name: " \n "); XCTFail("blank label accepted") }
        catch let error as LabelError { XCTAssertEqual(error, .emptyName) }
        let name = "Labels \(UUID().uuidString.prefix(8))"
        let label = try await owner.createLabel(name: name)
        addTeardownBlock { try? await owner.deleteLabel(id: label.id) }
        do { _ = try await owner.createLabel(name: name.uppercased()); XCTFail("duplicate label accepted") }
        catch let error as LabelError { XCTAssertEqual(error, .duplicateName) }
        try await owner.renameLabel(id: label.id, name: name)
        do { try await owner.renameLabel(id: "missing", name: "Missing"); XCTFail("missing label renamed") }
        catch let error as LabelError { XCTAssertEqual(error, .notFound) }
    }

    // helpers

    private func waitFor(_ what: String, _ seconds: TimeInterval = 20, _ done: () async throws -> Bool) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < seconds {
            if try await done() { return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("waited \(Int(seconds)) s for \(what)")
    }

    /// the test's room, made by the first user on the first run, with the second user in it.
    private func testRoom(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String, roomName: String) async throws -> String {
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

    /// a client-server api call (`/_matrix/client/v3/...`); its json answer, an error's included.
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

    /// a new device of a test user, signed out at the test's end (testdevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await signInTestDevice(homeserver, user, password)
    }
}
