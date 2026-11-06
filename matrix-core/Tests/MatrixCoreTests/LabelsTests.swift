@testable import MatrixCore
import XCTest

final class LabelsTests: XCTestCase {
    // both devices finish their reads before either may write, reproducing the lost-update window.
    // the same mutation engine as the public account methods writes real account data through the sdk.
    func testOverlappingDeviceWritesKeepIndependentLabelsAndFields() async throws {
        let (server, user, password, user2, password2) = try twoUsers()
        let first = try await signIn(server, user, password)
        let second = try await signIn(server, user, password)
        let person = try await signIn(server, user2, password2)
        let room = try await testRoom(first, person, user2: user2, roomName: "Multiplexer labels overlap test")
        _ = try await second.rooms()
        let watcher = try await signIn(server, user, password)
        _ = try await watcher.labels()
        watcher.accountDataWatch.stop()
        let initial = await AccountDataWatch.values(watcher.client)
        let changes = LabelChanges()
        let markers = LabelChanges()
        watcher.onChange { if $0 == .rooms { changes.count() } }
        let a = ChatLabel(id: UUID().uuidString, name: "Overlap a \(UUID().uuidString)", roomIds: [])
        let b = ChatLabel(id: UUID().uuidString, name: "Overlap b \(UUID().uuidString)", roomIds: [])
        addTeardownBlock {
            try? await first.deleteLabel(id: a.id)
            try? await first.deleteLabel(id: b.id)
        }

        let creates = LabelReadBarrier()
        async let createA: Void = overlappingChange(first, .create(a), barrier: creates)
        async let createB: Void = overlappingChange(second, .create(b), barrier: creates)
        _ = try await (createA, createB)
        // start only after both markers were acknowledged. even if only the last is delivered,
        // it must announce both independent fields, without polling the server for discoveries.
        watcher.accountDataWatch.start(watcher.client, interval: 0.1, initial: initial) { [weak watcher] types in
            if types.contains(LabelStore.markerType) { markers.count() }
            watcher?.accountDataChanged(types)
        }
        try await waitFor("both overlapping creates and their observer delivery", 30) {
            let labels = try await watcher.labels()
            return markers.seen > 0 && changes.seen > 0 && labels.contains { $0.id == a.id } && labels.contains { $0.id == b.id }
        }

        let fields = LabelReadBarrier()
        let renamed = "Renamed \(a.name)"
        let before = changes.seen
        async let rename: Void = overlappingChange(first, .rename(a.id, renamed), barrier: fields)
        async let membership: Void = overlappingChange(second, .membership(a.id, [room], true), barrier: fields)
        _ = try await (rename, membership)
        try await waitFor("overlapping rename and membership and their observer delivery", 30) {
            let label = try await watcher.labels().first { $0.id == a.id }
            return changes.seen > before && label?.name == renamed && label?.roomIds == [room]
        }

        // a new device has no local override or list of record keys: discovery must find both.
        let fresh = try await signIn(server, user, password)
        let restored = try await fresh.labels()
        XCTAssertEqual(restored.first { $0.id == a.id }?.name, renamed)
        XCTAssertEqual(restored.first { $0.id == a.id }?.roomIds, [room])
        XCTAssertTrue(restored.contains { $0.id == b.id })

        // opposite writes to the same field use the server's put order, with no fake cas promise.
        let renames = LabelReadBarrier(), order = LabelWriteOrder()
        async let earlier: Void = overlappingChange(first, .rename(a.id, "Earlier \(a.name)"), barrier: renames,
                                                    afterWrite: { await order.didWrite() })
        async let later: Void = overlappingChange(second, .rename(a.id, "Later \(a.name)"), barrier: renames,
                                                  beforeWrite: { try await order.wait() })
        _ = try await (earlier, later)
        try await waitFor("the last server write to the same name field", 30) {
            let label = try await watcher.labels().first { $0.id == a.id }
            return label?.name == "Later \(a.name)" && label?.roomIds == [room]
        }

        // the later include agrees with its old snapshot, but must still be written after the
        // earlier remove. skipping that apparent no-op would lose the later user's intent.
        let memberships = LabelReadBarrier(), memberOrder = LabelWriteOrder()
        async let exclude: Void = overlappingChange(first, .membership(a.id, [room], false), barrier: memberships,
                                                    afterWrite: { await memberOrder.didWrite() })
        async let include: Void = overlappingChange(second, .membership(a.id, [room], true), barrier: memberships,
                                                    beforeWrite: { try await memberOrder.wait() })
        _ = try await (exclude, include)
        let membershipOnServer = try await labelSnapshotOnServer(session: first.savedSession()).labels
        XCTAssertEqual(membershipOnServer.first { $0.id == a.id }?.roomIds, [room])

        // atomic name reservation is unavailable. preserve both ids instead of silently dropping
        // a label (and, later, its membership) when simultaneous validation sees the same snapshot.
        let duplicateName = "Concurrent name \(UUID().uuidString)"
        let c = ChatLabel(id: UUID().uuidString, name: duplicateName, roomIds: [])
        let d = ChatLabel(id: UUID().uuidString, name: duplicateName.uppercased(), roomIds: [])
        addTeardownBlock {
            try? await first.deleteLabel(id: c.id)
            try? await first.deleteLabel(id: d.id)
        }
        let duplicateReads = LabelReadBarrier()
        async let duplicateA: Void = overlappingChange(first, .create(c), barrier: duplicateReads)
        async let duplicateB: Void = overlappingChange(second, .create(d), barrier: duplicateReads)
        _ = try await (duplicateA, duplicateB)
        let duplicates = try await labelSnapshotOnServer(session: first.savedSession()).labels
        XCTAssertEqual(Set(duplicates.filter { $0.name.caseInsensitiveCompare(duplicateName) == .orderedSame }.map(\.id)), [c.id, d.id])

        let deletion = LabelReadBarrier(parties: 3)
        async let remove: Void = overlappingChange(first, .delete(a.id), barrier: deletion)
        async let staleRename: Void = overlappingChange(second, .rename(a.id, "Stale \(a.name)"), barrier: deletion)
        async let staleMembership: Void = overlappingChange(fresh, .membership(a.id, [room], false), barrier: deletion)
        _ = try await (remove, staleRename, staleMembership)
        try await waitFor("deletion to win over overlapping stale name and membership writes", 30) {
            try await !watcher.labels().contains { $0.id == a.id }
        }
        let onServer = try await labelSnapshotOnServer(session: first.savedSession()).labels
        XCTAssertFalse(onServer.contains { $0.id == a.id })
        XCTAssertTrue(onServer.contains { $0.id == b.id }, "deletion must not replace an unrelated label")
    }

    func testLegacyServerDocumentStaysIntactWhileNewDevicesReadFieldOverrides() async throws {
        let (server, user, password, _, _) = try twoUsers()
        let first = try await signIn(server, user, password)
        let session = try first.savedSession()
        let legacyLabel = ChatLabel(id: UUID().uuidString, name: "Legacy \(UUID().uuidString)", roomIds: ["!legacy:example.org"])
        var original = try LabelStore.read(try await accountDataOnServer(LabelStore.type, session: session))
        original.labels.append(legacyLabel)
        try await first.client.setAccountData(eventType: LabelStore.type, content: LabelStore.json(original))
        addTeardownBlock {
            try? await first.deleteLabel(id: legacyLabel.id)
            if var latest = try? LabelStore.read(try await accountDataOnServer(LabelStore.type, session: session)) {
                latest.labels.removeAll { $0.id == legacyLabel.id }
                try? await first.client.setAccountData(eventType: LabelStore.type, content: LabelStore.json(latest))
            }
        }
        let second = try await signIn(server, user, password)
        let before = try await second.labels()
        XCTAssertEqual(before.first { $0.id == legacyLabel.id }, legacyLabel)
        try await second.renameLabel(id: legacyLabel.id, name: "Renamed \(legacyLabel.name)")
        let unchanged = try LabelStore.read(try await accountDataOnServer(LabelStore.type, session: session))
        XCTAssertEqual(unchanged, original, "new writes must not rewrite the legacy document")
        let fresh = try await signIn(server, user, password)
        let restored = try await fresh.labels().first { $0.id == legacyLabel.id }
        XCTAssertEqual(restored?.name, "Renamed \(legacyLabel.name)")
        XCTAssertEqual(restored?.roomIds, legacyLabel.roomIds)
        try await second.deleteLabel(id: legacyLabel.id)
        try await waitFor("a tombstone to hide the unchanged legacy record", 30) {
            try await !fresh.labels().contains { $0.id == legacyLabel.id }
        }
    }

    func testCleanReadsAndCoalescedInvalidationsDoNotPollTheServer() async throws {
        let state = LabelStates(), server = LabelTestServer()
        let field = LabelStore.Field(id: "one", name: "One")
        await server.write(field)
        _ = try await state.labels(fetch: { await server.read() })
        _ = try await state.labels(fetch: { await server.read() })
        let initialReads = await server.reads
        XCTAssertEqual(initialReads, 1, "a fresh device discovers once; clean reads use its cache")
        await server.write(LabelStore.Field(id: "one", roomId: "room", included: true))
        state.invalidate()
        state.invalidate()
        async let a = state.labels(fetch: { await server.read() })
        async let b = state.labels(fetch: { await server.read() })
        let (first, second) = try await (a, b)
        let after = await server.reads
        XCTAssertEqual(after, 2, "concurrent reloads for several markers share one discovery")
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.first?.roomIds, ["room"])

        state.invalidate()
        do {
            _ = try await state.labels(fetch: { throw URLError(.notConnectedToInternet) })
            XCTFail("a failed discovery must remain retryable")
        } catch let error as URLError { XCTAssertEqual(error.code, .notConnectedToInternet) }
        _ = try await state.labels(fetch: { await server.read() })
        let afterRetry = await server.reads
        XCTAssertEqual(afterRetry, 3, "a failure must not acknowledge an invalidation")
    }

    func testMarkerArrivingDuringDiscoveryIsNotSwallowedByThatRead() async throws {
        let state = LabelStates(), changes = LabelChanges()
        let old = LabelStore.Snapshot(legacy: .init(labels: [ChatLabel(id: "one", name: "Old", roomIds: [])], revision: nil))
        let new = LabelStore.Snapshot(legacy: .init(labels: [ChatLabel(id: "one", name: "New", roomIds: [])], revision: nil))
        let stale = try await state.labels(fetch: {
            state.invalidate()
            return old
        }, changed: { changes.count() })
        XCTAssertEqual(stale.first?.name, "Old")
        XCTAssertEqual(changes.seen, 1, "reannounce an invalidation coalesced into a pending read")
        let fresh = try await state.labels(fetch: { new })
        XCTAssertEqual(fresh.first?.name, "New", "the in-flight snapshot cannot clear a newer invalidation")
    }

    func testFailedMarkerThrowsAndRetryDiscoversAlreadyWrittenFields() async throws {
        let state = LabelStates(), server = LabelTestServer(), changes = LabelChanges()
        let label = ChatLabel(id: "one", name: "One", roomIds: [])
        do {
            try await state.change(.create(label), fetch: { await server.read() },
                                   write: { await server.write($0) }, mark: { try await server.mark(fail: true) },
                                   changed: { changes.count() })
            XCTFail("field success without marker success must not acknowledge the mutation")
        } catch let error as URLError { XCTAssertEqual(error.code, .networkConnectionLost) }
        let events = await server.events
        XCTAssertEqual(events, ["read", "field", "marker failed"], "the marker must follow all fields")
        let read = try await state.labels(fetch: { await server.read() })
        XCTAssertEqual(read, [label], "a retry discovers an unacknowledged field instead of inventing a rollback")
        let fresh = LabelStates()
        let restored = try await fresh.labels(fetch: { await server.read() })
        XCTAssertEqual(restored, [label], "a new device also discovers fields without a marker")
        try await state.change(.rename(label.id, "Renamed"), fetch: { await server.read() },
                               write: { await server.write($0) }, mark: { try await server.mark() },
                               changed: { changes.count() })
        let retryEvents = await server.events
        XCTAssertEqual(Array(retryEvents.suffix(3)), ["read", "field", "marker"])
        XCTAssertGreaterThan(changes.seen, 0, "observers must be told to reload after failure or success")
    }

    func testPartialMembershipFailureIsDiscoverableAndTheWholeIntentCanBeRetried() async throws {
        let state = LabelStates(), server = LabelTestServer()
        await server.write(LabelStore.Field(id: "one", name: "One"))
        do {
            try await state.change(.membership("one", ["a", "b"], true), fetch: { await server.read() }, write: { field in
                if field.roomId == "b" { throw URLError(.networkConnectionLost) }
                await server.write(field)
            }, mark: { try await server.mark() }, changed: {})
            XCTFail("a partial assignment cannot report success")
        } catch let error as URLError { XCTAssertEqual(error.code, .networkConnectionLost) }
        let failedEvents = await server.events
        XCTAssertFalse(failedEvents.contains("marker"), "a failed field write must not publish a success marker")
        let partial = try await state.labels(fetch: { await server.read() })
        XCTAssertEqual(partial.first?.roomIds, ["a"], "acknowledged fields are not rolled back on the server")
        try await state.change(.membership("one", ["a", "b"], true), fetch: { await server.read() },
                               write: { await server.write($0) }, mark: { try await server.mark() }, changed: {})
        let retried = try await state.labels(fetch: { await server.read() })
        XCTAssertEqual(retried.first?.roomIds, ["a", "b"])
    }

    func testSnapshotRequestsAreFreshAndDoNotAdvanceTheSDKDeviceCursor() throws {
        let session = SavedSession(userId: "@test:example.org", deviceId: "TEST", homeserverUrl: "https://example.org",
                                   accessToken: "test-only", refreshToken: nil, oauthData: nil, nativeSlidingSync: true)
        let first = try labelSnapshotRequest(session: session), second = try labelSnapshotRequest(session: session)
        XCTAssertNotEqual(first.url, second.url, "identical initial syncs can return cached, old account data on synapse")
        let url = try XCTUnwrap(URLComponents(url: try XCTUnwrap(first.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (url.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertNil(query["since"], "a second cursor could acknowledge encryption messages before the sdk")
        XCTAssertNil(query["access_token"])
        XCTAssertEqual(query["timeout"], "0")
        let filter = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(query["filter"]).utf8)) as? [String: Any])
        XCTAssertEqual((filter["room"] as? [String: Any])?["rooms"] as? [String], [])
        let types = try XCTUnwrap((filter["account_data"] as? [String: Any])?["types"] as? [String])
        XCTAssertTrue(types.contains(LabelStore.type))
        XCTAssertTrue(types.contains(LabelStore.prefix + "*"), "all current records must be discoverable without an index")
    }

    func testLegacyLabelsRemainReadableAndFieldRecordsOverrideOnlyTheirField() throws {
        let old = ChatLabel(id: "existing-label", name: "Existing", roomIds: ["one", "two"])
        let untouched = ChatLabel(id: "untouched", name: "Untouched", roomIds: ["three"])
        let legacy = try LabelStore.read("{\"labels\":[{\"id\":\"existing-label\",\"name\":\"Existing\",\"roomIds\":[\"one\",\"two\"]},{\"id\":\"untouched\",\"name\":\"Untouched\",\"roomIds\":[\"three\"]}],\"revision\":\"old\"}")
        var snapshot = LabelStore.Snapshot(legacy: legacy)
        XCTAssertEqual(snapshot.labels, [old, untouched])
        for field in [LabelStore.Field(id: old.id, name: "Renamed"),
                      LabelStore.Field(id: old.id, roomId: "one", included: false),
                      LabelStore.Field(id: old.id, roomId: "four", included: true)] {
            snapshot.fields[field.type] = field
        }
        XCTAssertEqual(snapshot.labels, [ChatLabel(id: old.id, name: "Renamed", roomIds: ["four", "two"]), untouched])
        let deleted = LabelStore.Field(id: old.id, deleted: true)
        snapshot.fields[deleted.type] = deleted
        XCTAssertEqual(snapshot.labels, [untouched], "legacy membership and a stale rename cannot resurrect a tombstone")
    }

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
        try await owner.pin(roomId: one)
        addTeardownBlock { try? await owner.unpin(roomId: one) }
        let pinned = try await owner.labelInbox(id: label.id)
        XCTAssertTrue(pinned.listed.contains(one), "a pinned chat still appears as a row in a label")
        XCTAssertTrue(pinned.pinned.contains { $0.id == one }, "pin metadata must remain available for unpin actions")
        try await owner.unpin(roomId: one)
        try await waitFor("labels on another device", 30) {
            try await second.labels().first { $0.id == label.id }?.roomIds.count == 2
        }
        let theirs = try await other.labels()
        XCTAssertFalse(theirs.contains { $0.id == label.id }, "labels must stay private to this account")
        try await owner.renameLabel(id: label.id, name: "Renamed \(name)")
        try await waitFor("a renamed label", 30) {
            try await second.labels().first { $0.id == label.id }?.name == "Renamed \(name)"
        }
        try await owner.archive(roomId: one)
        try await owner.setLowPriority(roomId: two, true)
        try await owner.markRead(roomId: one)
        try await owner.setMarkedUnread(roomId: two, true)
        let all = try await owner.labelInbox(id: label.id)
        XCTAssertEqual(all.listed, Set([one, two]), "labels include archived and low-priority chats")
        XCTAssertEqual(all.chats.first { $0.id == one }?.isArchived, true)
        XCTAssertEqual(all.chats.first { $0.id == two }?.isLowPriority, true)
        try await waitFor("the read receipt to clear the unread count", 30) {
            try await owner.labelInbox(id: label.id, filter: .unread).listed == Set([two])
        }
        let unread = try await owner.labelInbox(id: label.id, filter: .unread)
        XCTAssertEqual(unread.listed, Set([two]))
        let wrongNetwork = try await owner.labelInbox(id: label.id, network: "whatsapp")
        XCTAssertTrue(wrongNetwork.listed.isEmpty)
        try await owner.hide(roomId: one)
        let hidden = try await owner.labelInbox(id: label.id)
        XCTAssertEqual(hidden.listed, Set([two]), "a deleted chat must not show in a label")
        try await second.renameLabel(id: label.id, name: "Other device \(name)")
        try await owner.setLabel(id: label.id, roomIds: [two], included: false)
        let keptName = try await owner.labels().first { $0.id == label.id }?.name
        XCTAssertEqual(keptName, "Other device \(name)", "a membership write must preserve the other device's rename")
        try await waitFor("removed membership", 30) {
            try await second.labels().first { $0.id == label.id }?.roomIds == [one]
        }
        try await other.sendAndWait(roomId: one, text: "Back for merge \(UUID().uuidString)")
        try await waitFor("the deleted chat to come back", 30) {
            try await owner.rooms().first { $0.id == one }?.isHidden == false
        }
        try await owner.unarchive(roomId: one)
        let merged = try await owner.merge(rooms: [one, two], name: "Label group", defaultRoom: one)
        addTeardownBlock { try? await owner.unmerge(merged) }
        let grouped = try await owner.labelInbox(id: label.id)
        XCTAssertEqual(grouped.listed, Set([merged]), "a labelled member appears once as its merged chat")
        try await owner.setLabel(id: label.id, roomIds: [merged], included: true)
        let allMembers = try await owner.labels().first { $0.id == label.id }?.roomIds
        XCTAssertEqual(Set(allMembers ?? []), Set([one, two]), "labelling a merge applies to all its rooms")
        try await owner.setLabel(id: label.id, roomIds: [merged], included: false)
        let removed = try await owner.labelInbox(id: label.id)
        XCTAssertTrue(removed.listed.isEmpty)
        try await owner.unmerge(merged)
        try await owner.deleteLabel(id: label.id)
        try await waitFor("deleted label", 30) { try await !second.labels().contains { $0.id == label.id } }
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

    private func overlappingChange(_ account: MatrixAccount, _ mutation: LabelStore.Mutation, barrier: LabelReadBarrier,
                                   beforeWrite: @escaping @Sendable () async throws -> Void = {},
                                   afterWrite: @escaping @Sendable () async -> Void = {}) async throws {
        try await account.labelStates.change(mutation, fetch: {
            let snapshot = try await labelSnapshotOnServer(session: account.savedSession())
            try await barrier.arrive()
            return snapshot
        }, write: { field in
            try await beforeWrite()
            try await account.client.setAccountData(eventType: field.type, content: LabelStore.json(field))
            await afterWrite()
        }, mark: { try await account.publishLabelChange() }, changed: { account.notify(.rooms) })
    }

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
        try await testAccount(homeserver, user, password)
    }
}

private actor LabelReadBarrier {
    private let parties: Int
    private var arrived = 0
    init(parties: Int = 2) { self.parties = parties }
    func arrive() async throws {
        arrived += 1
        let deadline = Date().addingTimeInterval(15)
        while arrived < parties {
            if Date() > deadline { throw MatrixCoreError.timedOut("overlapping label reads") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor LabelWriteOrder {
    private var written = false
    func didWrite() { written = true }
    func wait() async throws {
        let deadline = Date().addingTimeInterval(15)
        while !written {
            if Date() > deadline { throw MatrixCoreError.timedOut("the earlier label field write") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private actor LabelTestServer {
    private var snapshot = LabelStore.Snapshot()
    private(set) var reads = 0
    private(set) var events: [String] = []

    func read() -> LabelStore.Snapshot {
        reads += 1
        events.append("read")
        return snapshot
    }

    func write(_ field: LabelStore.Field) {
        events.append("field")
        snapshot.fields[field.type] = field
    }

    func mark(fail: Bool = false) throws {
        events.append(fail ? "marker failed" : "marker")
        if fail { throw URLError(.networkConnectionLost) }
    }
}

private final class LabelChanges: @unchecked Sendable {
    private let lock = NSLock()
    private var number = 0
    func count() { lock.withLock { number += 1 } }
    var seen: Int { lock.withLock { number } }
}
