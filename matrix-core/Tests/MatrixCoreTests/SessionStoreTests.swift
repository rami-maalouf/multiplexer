@testable import MatrixCore
import XCTest

final class SessionStoreTests: XCTestCase {
    private func fixture() -> StoredSession {
        StoredSession(session: SavedSession(userId: "@test:example.invalid", deviceId: "test-device",
                                           homeserverUrl: "https://example.invalid", accessToken: "fixture",
                                           nativeSlidingSync: true),
                      store: "test-store", searchKey: "search-key", pusherAppId: "test-app", pushkey: "test-pushkey")
    }

    func testTheStoreLocationSurvivesSessionPersistence() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture())) as? [String: Any])
        json["storeLocation"] = "group"
        let stored = try JSONDecoder().decode(StoredSession.self, from: JSONSerialization.data(withJSONObject: json))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        XCTAssertEqual(saved["storeLocation"] as? String, "group")
    }

    func testALegacySessionUsesDataWithoutChangingItsMetadata() throws {
        let old = fixture()
        let json = try JSONEncoder().encode(old)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("storeLocation"))
        let decoded = try JSONDecoder().decode(StoredSession.self, from: json)
        XCTAssertNil(decoded.storeLocation)
        let (data, _) = try directories()
        let source = try populate(data, store: old.store)
        XCTAssertEqual(try SessionStore(dataDirectory: data, groupContainer: nil, agent: false).prepare(decoded) { _ in
            XCTFail("no migration without an app group")
        }, .available(old, source))
    }

    func testMovingPreservesCryptoSearchAndSessionMetadata() throws {
        let (data, group) = try directories(), old = fixture()
        let source = try populate(data, store: old.store)
        let stores = SessionStore(dataDirectory: data, groupContainer: group, agent: false)
        var saved = old
        let resolved = try stores.prepare(old) { saved = $0 }
        let destination = MatrixPush.sharedStore(in: group, store: old.store)
        var expected = old
        expected.storeLocation = .group
        XCTAssertEqual(saved, expected)
        XCTAssertEqual(resolved, .available(expected, destination))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        try assertContents(destination)
        XCTAssertEqual(try stores.prepare(saved) { _ in XCTFail("already shared") }, resolved)
    }

    func testAFailedMetadataWriteRetriesWithoutLosingTheMovedStore() throws {
        let (data, group) = try directories(), old = fixture()
        _ = try populate(data, store: old.store)
        let stores = SessionStore(dataDirectory: data, groupContainer: group, agent: false)
        enum WriteFailed: Error { case refused }
        XCTAssertThrowsError(try stores.prepare(old) { _ in throw WriteFailed.refused })
        let destination = MatrixPush.sharedStore(in: group, store: old.store)
        try assertContents(destination)
        // a build without the entitlement cannot mistake the interrupted move for a reinstall.
        XCTAssertEqual(try SessionStore(dataDirectory: data, groupContainer: nil, agent: false).prepare(old) { _ in
            XCTFail("unavailable stores retain their metadata")
        }, .unavailable)
        var persisted = old
        let retried = try stores.prepare(old) { persisted = $0 }
        XCTAssertEqual(persisted.storeLocation, .group)
        XCTAssertEqual(retried, .available(persisted, destination))
        try assertContents(destination)
    }

    func testAProcessStoppedAfterTheMoveFinishesMetadataOnLaunch() throws {
        let (data, group) = try directories(), old = fixture()
        let source = try populate(data, store: old.store)
        let destination = MatrixPush.sharedStore(in: group, store: old.store)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: destination)
        var saved = old
        var expected = old
        expected.storeLocation = .group
        XCTAssertEqual(try SessionStore(dataDirectory: data, groupContainer: group, agent: false).prepare(old) { saved = $0 },
                       .available(expected, destination))
        XCTAssertEqual(saved.storeLocation, .group)
        try assertContents(destination)
    }

    func testAnUnavailableGroupRetainsTheSessionEvenIfDataHasAnotherStore() throws {
        let (data, _) = try directories()
        var shared = fixture()
        shared.storeLocation = .group
        let other = try populate(data, store: shared.store)
        XCTAssertEqual(try SessionStore(dataDirectory: data, groupContainer: nil, agent: false).prepare(shared) { _ in
            XCTFail("must retain the session")
        }, .unavailable)
        try assertContents(other)
    }

    func testMissingAndUnavailableStoresAreDifferent() throws {
        let (data, group) = try directories()
        let old = fixture()
        var shared = old
        shared.storeLocation = .group
        let availableGroup = SessionStore(dataDirectory: data, groupContainer: group, agent: false)
        let noGroup = SessionStore(dataDirectory: data, groupContainer: nil, agent: false)
        let noWrite: (StoredSession) -> Void = { _ in XCTFail("nothing to migrate") }
        XCTAssertEqual(try availableGroup.prepare(old, persist: noWrite), .missing)
        XCTAssertEqual(try availableGroup.prepare(shared, persist: noWrite), .missing)
        XCTAssertEqual(try noGroup.prepare(old, persist: noWrite), .unavailable)
        XCTAssertEqual(try noGroup.prepare(shared, persist: noWrite), .unavailable)
    }

    func testAnAgentNeverReadsOrMovesTheSharedStore() throws {
        let (data, group) = try directories(), old = fixture()
        let scratch = try populate(data, store: old.store)
        let shared = try populate(group, store: old.store)
        let agent = SessionStore(dataDirectory: data, groupContainer: group, agent: true)
        XCTAssertEqual(agent.newStoreLocation, .data)
        XCTAssertNil(agent.directory(store: old.store, location: .group))
        XCTAssertEqual(try agent.prepare(old) { _ in XCTFail("agent must stay in scratch") }, .available(old, scratch))
        var metadata = old
        metadata.storeLocation = .group
        XCTAssertEqual(try agent.prepare(metadata) { _ in XCTFail("must not read the group") }, .unavailable)
        try FileManager.default.removeItem(at: scratch)
        XCTAssertEqual(try agent.prepare(old) { _ in XCTFail("must not recover from the group") }, .missing)
        try assertContents(shared)
    }

    func testConflictingStoresAreNeverOverwrittenOrDeleted() throws {
        let (data, group) = try directories(), old = fixture()
        let source = try populate(data, store: old.store)
        let destination = try populate(group, store: old.store)
        XCTAssertThrowsError(try SessionStore(dataDirectory: data, groupContainer: group, agent: false).prepare(old) { _ in
            XCTFail("ambiguous store must not change metadata")
        }) { error in
            guard case SessionStore.Problem.conflictingStores = error else { return XCTFail("unexpected error: \(error)") }
        }
        try assertContents(source)
        try assertContents(destination)
    }

    func testAnInvalidStoreThrowsRatherThanClaimingItIsMissing() throws {
        let (data, group) = try directories(), old = fixture()
        let path = MatrixPush.sharedStore(in: group, store: old.store)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a directory".utf8).write(to: path)
        var shared = old
        shared.storeLocation = .group
        XCTAssertThrowsError(try SessionStore(dataDirectory: data, groupContainer: group, agent: false).prepare(shared) { _ in
            XCTFail("an unreadable store must not change metadata")
        })
    }

    func testTheResolvedDirectoryDeletesOnlyThatSessionsStore() throws {
        let (data, group) = try directories(), old = fixture()
        _ = try populate(data, store: old.store)
        let sibling = try populate(group, store: "another-session")
        let stores = SessionStore(dataDirectory: data, groupContainer: group, agent: false)
        XCTAssertEqual(stores.newStoreLocation, .group)
        guard case .available(_, let directory) = try stores.prepare(old, persist: { _ in }) else {
            return XCTFail("store unavailable")
        }
        try FileManager.default.removeItem(at: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        try assertContents(sibling)
    }

    private func directories() throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("session-store-\(UUID().uuidString)")
        let data = root.appendingPathComponent("data"), group = root.appendingPathComponent("group")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return (data, group)
    }

    private func populate(_ root: URL, store: String) throws -> URL {
        let directory = MatrixPush.sharedStore(in: root, store: store)
        for name in ["data/crypto.sqlite", "cache/events.sqlite", "search/room/index/nested.bin"] {
            let file = directory.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("fixture: \(name)".utf8).write(to: file)
        }
        return directory
    }

    private func assertContents(_ directory: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        for name in ["data/crypto.sqlite", "cache/events.sqlite", "search/room/index/nested.bin"] {
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(name)), Data("fixture: \(name)".utf8), file: file, line: line)
        }
    }
}
