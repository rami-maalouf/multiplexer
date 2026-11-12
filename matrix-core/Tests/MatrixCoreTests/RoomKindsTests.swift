@testable import MatrixCore
import XCTest

final class RoomKindsTests: XCTestCase {
    func testFailedFetchCanBeRetriedOnTheNextAsk() async {
        let kinds = RoomKinds(file: nil)
        let firstFinished = expectation(description: "failed room processed before next room")
        let recovered = expectation(description: "healthy retry resolves the group")
        let gate = RoomKindGate()
        kinds.ask(["failed", "blocked"], fetch: { id in
            if id == "blocked" {
                firstFinished.fulfill()
                await gate.wait()
            }
            return nil
        }, done: { XCTFail("failed lookups must not notify") })
        await fulfillment(of: [firstFinished], timeout: 2)
        XCTAssertNil(kinds.kind("failed"))
        XCTAssertTrue(RoomSummary.isOneToOne(people: 2, isDirect: false, bridged: true, kind: kinds.kind("failed")))
        kinds.ask(["failed"], fetch: { _ in .group }, done: { recovered.fulfill() })
        await fulfillment(of: [recovered], timeout: 2)
        XCTAssertEqual(kinds.kind("failed"), .group)
        XCTAssertFalse(RoomSummary.isOneToOne(people: 2, isDirect: false, bridged: true, kind: kinds.kind("failed")))
        await gate.release()
        await kinds.stop()
    }

    func testOverlappingAsksFetchEachRoomOnceAndCacheSuccess() async {
        let kinds = RoomKinds(file: nil)
        let entered = expectation(description: "first fetch entered")
        let found = expectation(description: "kind cached")
        let gate = RoomKindGate()
        kinds.ask(["room", "room"], fetch: { _ in
            entered.fulfill()
            await gate.wait()
            return .group
        }, done: { found.fulfill() })
        await fulfillment(of: [entered], timeout: 2)
        kinds.ask(["room"], fetch: { _ in XCTFail("duplicate in-flight fetch"); return .direct }, done: {})
        await gate.release()
        await fulfillment(of: [found], timeout: 2)
        kinds.ask(["room"], fetch: { _ in XCTFail("successful kind fetched again"); return nil }, done: {})
        await kinds.stop()
        XCTAssertEqual(kinds.kind("room"), .group)
    }

    func testStopCancelsWorkAndNeverRestarts() async {
        let kinds = RoomKinds(file: nil)
        let entered = expectation(description: "fetch entered")
        let cancelled = expectation(description: "fetch cancelled")
        kinds.ask(["room", "queued"], fetch: { id in
            XCTAssertEqual(id, "room", "cancellation must skip queued rooms")
            entered.fulfill()
            do { try await Task.sleep(nanoseconds: 60_000_000_000) }
            catch { cancelled.fulfill() }
            return nil
        }, done: { XCTFail("cancelled fetch notified") })
        await fulfillment(of: [entered], timeout: 2)
        await kinds.stop()
        await fulfillment(of: [cancelled], timeout: 2)
        kinds.ask(["room", "new"], fetch: { _ in XCTFail("stopped cache restarted"); return .group }, done: {})
        await kinds.stop()
        XCTAssertNil(kinds.kind("room"))
        XCTAssertNil(kinds.kind("new"))
    }

    func testPersistedSuccessDoesNotFetchAgain() async {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("room-kinds-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let kinds = RoomKinds(file: file)
        let found = expectation(description: "kind persisted")
        kinds.ask(["room"], fetch: { _ in .group }, done: { found.fulfill() })
        await fulfillment(of: [found], timeout: 2)
        await kinds.stop()
        let reloaded = RoomKinds(file: file)
        XCTAssertEqual(reloaded.kind("room"), .group)
        reloaded.ask(["room"], fetch: { _ in XCTFail("persisted kind fetched again"); return nil }, done: {})
        await reloaded.stop()
    }

    func testStopRacingAnAskWaitsForEveryFetch() async {
        let observation = RoomKindStopObservation()
        for _ in 0..<1000 {
            let kinds = RoomKinds(file: nil)
            let stopped = RoomKindStopObservation()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    kinds.ask(["room"], fetch: { _ in
                        if stopped.hasStopped { observation.recordLateFetch() }
                        return nil
                    }, done: {})
                }
                group.addTask {
                    await kinds.stop()
                    stopped.recordStop()
                }
            }
            await kinds.stop()
        }
        XCTAssertEqual(observation.lateFetches, 0, "a fetch must not start after stop returned")
    }

    func testConcurrentRememberAndAskPreserveEveryKindOnReload() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("room-kinds-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        // repeated overlapping writes exercise atomic replacement ordering without a storage hook.
        for round in 0..<12 {
            let seed = Dictionary(uniqueKeysWithValues: (0..<256).map { ("seed-\($0)", BridgedKind.direct) })
            try JSONEncoder().encode(seed).write(to: file, options: .atomic)
            let kinds = RoomKinds(file: file)
            let found = expectation(description: "asked kinds persisted in round \(round)")
            let asked = (0..<32).map { "asked-\($0)" }
            kinds.ask(asked, fetch: { _ in .group }, done: { found.fulfill() })
            DispatchQueue.concurrentPerform(iterations: 32) { index in
                kinds.remember("remembered-\(index)", .group)
            }
            await fulfillment(of: [found], timeout: 2)
            await kinds.stop()
            let reloaded = RoomKinds(file: file)
            let ids = Array(seed.keys) + asked + (0..<32).map { "remembered-\($0)" }
            let missing = ids.filter { reloaded.kind($0) != kinds.kind($0) }
            XCTAssertTrue(missing.isEmpty, "round \(round) lost cached kinds on reload: \(missing)")
        }
    }
}

private final class RoomKindStopObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var late = 0
    var hasStopped: Bool { lock.withLock { stopped } }
    var lateFetches: Int { lock.withLock { late } }
    func recordStop() { lock.withLock { stopped = true } }
    func recordLateFetch() { lock.withLock { late += 1 } }
}

private actor RoomKindGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
