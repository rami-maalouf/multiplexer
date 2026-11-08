import XCTest
import Darwin
@testable import CLIKit

private let allowedPolicy = Data(#"{"version":1,"accounts":{"@u:h":["!r:h"]}}"#.utf8)

final class WriteSafetyTests: XCTestCase {
    private func exercise(_ name: String = "send", dry: Bool = false, room: String = "!r:h",
                          policy: Data = allowedPolicy, failAudit: Set<String> = [],
                          mutationFails: Bool = false, outputFails: Bool = false,
                          result: WriteResult = .event("$accepted")) async throws -> (String?, [String], [[String: String]]) {
        let args: [String]
        switch name {
        case "react": args = [name, room, "$target", "x"]
        case "mark-read": args = [name, room]
        case "later": args = [name, room, "private text", "--at", "2099-01-01T00:00:00Z"]
        default: args = [name, room, "private text"]
        }
        let command = try Command(args + (dry ? ["--dry-run"] : []), now: Date(timeIntervalSince1970: 0))
        var trace: [String] = [], rows: [[String: String]] = []
        do {
            try await performWrite(command, user: "@u:h", room: room, loadPolicy: { trace.append("policy"); return policy }, audit: {
                trace.append($0)
                if failAudit.contains($0) { throw Failure("disk full private diagnostic") }
            }, mutate: {
                trace.append("server")
                if mutationFails { throw Failure("sensitive sdk body") }
                return result
            }, output: {
                trace.append("output")
                if outputFails { throw Failure("broken pipe") }
                rows.append($0)
            })
            return (nil, trace, rows)
        } catch { return (String(describing: error), trace, rows) }
    }
    func testEveryMutationDurablyAuditsBeforeServerThenAcceptsBeforeOutput() async throws {
        for name in ["send", "react", "mark-read", "later"] {
            let result: WriteResult = name == "later" ? .scheduled("delay") : name == "mark-read" ? .receipt : .event("$accepted")
            let (error, trace, rows) = try await exercise(name, result: result)
            XCTAssertNil(error)
            XCTAssertEqual(trace, ["policy", "started", "server", "accepted", "output"])
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["roomId"], "!r:h")
            XCTAssertEqual(rows[0]["status"], name == "later" ? "scheduled" : "accepted")
            XCTAssertEqual(rows[0]["eventId"], name == "send" || name == "react" ? "$accepted" : nil)
            XCTAssertEqual(rows[0]["delayId"], name == "later" ? "delay" : nil)
        }
    }
    func testEveryDryRunAuditsAndNeverMutates() async throws {
        for name in ["send", "react", "mark-read", "later"] {
            let (error, trace, rows) = try await exercise(name, dry: true)
            XCTAssertNil(error)
            XCTAssertEqual(trace, ["policy", "dry-run", "output"])
            XCTAssertEqual(rows, [["status": "dry-run", "action": name, "roomId": "!r:h"]])
        }
    }
    func testMissingMalformedUnknownVersionAndDeniedPolicyNeverReachServer() async throws {
        for policy in [Data(), Data("{".utf8), Data(#"{"version":2,"accounts":{"@u:h":["!r:h"]}}"#.utf8), Data(#"{"version":1,"accounts":{}}"#.utf8)] {
            for dry in [false, true] {
                let (error, trace, rows) = try await exercise(dry: dry, policy: policy)
                XCTAssertTrue(error?.contains("write refused") == true)
                XCTAssertEqual(trace, ["policy", "denied"])
                XCTAssertTrue(rows.isEmpty)
            }
        }
    }
    func testPolicyReadFailureIsAuditedDenied() async throws {
        var trace: [String] = []
        do {
            try await performWrite(Command(["send", "r", "text"]), user: "@u:h", room: "!r:h", loadPolicy: { throw Failure("missing") },
                                   audit: { trace.append($0) }, mutate: { trace.append("server"); return .receipt }, output: { _ in trace.append("output") })
            XCTFail("missing policy accepted")
        } catch { XCTAssertTrue(String(describing: error).contains("valid private write-policy")) }
        XCTAssertEqual(trace, ["denied"])
    }
    func testMergedRoomRefusedBeforePolicyOrServer() async throws {
        let (error, trace, _) = try await exercise(room: "merge:x")
        XCTAssertTrue(error?.contains("explicit underlying room id") == true)
        XCTAssertTrue(trace.isEmpty)
    }
    func testStartedAuditFailurePreventsAllServerMutations() async throws {
        for name in ["send", "react", "mark-read", "later"] {
            let (_, trace, rows) = try await exercise(name, failAudit: ["started"])
            XCTAssertEqual(trace, ["policy", "started"])
            XCTAssertTrue(rows.isEmpty)
        }
    }
    func testDeniedOrDryRunAuditFailureCannotReportSuccess() async throws {
        let (dryError, dryTrace, dryRows) = try await exercise(dry: true, failAudit: ["dry-run"])
        XCTAssertNotNil(dryError); XCTAssertEqual(dryTrace, ["policy", "dry-run"]); XCTAssertTrue(dryRows.isEmpty)
        let (deniedError, deniedTrace, deniedRows) = try await exercise(policy: Data(), failAudit: ["denied"])
        XCTAssertNotNil(deniedError); XCTAssertEqual(deniedTrace, ["policy", "denied"]); XCTAssertTrue(deniedRows.isEmpty)
    }
    func testServerFailureOrUnknownResultUsesFixedPrivateSafeOutcome() async throws {
        for failure in [Set<String>(), ["failed-or-unknown"]] {
            let (error, trace, rows) = try await exercise(failAudit: failure, mutationFails: true)
            XCTAssertEqual(error, "write failed or its result is unknown; inspect the chat before retrying")
            XCTAssertEqual(trace, ["policy", "started", "server", "failed-or-unknown"])
            XCTAssertTrue(rows.isEmpty)
        }
    }
    func testConfirmedServerThenAuditDiskFailureNeverClaimsWriteRefused() async throws {
        let (error, trace, rows) = try await exercise(failAudit: ["accepted"])
        XCTAssertEqual(error, "server accepted the write but the audit log failed; do not resend; inspect the chat and repair the audit log")
        XCTAssertEqual(trace, ["policy", "started", "server", "accepted"])
        XCTAssertTrue(rows.isEmpty)
    }
    func testOutputFailureAfterAcceptanceNeverSuggestsRetry() async throws {
        for result: WriteResult in [.event("$e"), .receipt, .scheduled("delay")] {
            let (error, trace, _) = try await exercise(outputFails: true, result: result)
            XCTAssertEqual(error, "server accepted the write but output failed; do not resend; inspect the chat")
            XCTAssertEqual(trace, ["policy", "started", "server", "accepted", "output"])
        }
    }
}

final class AuditTests: XCTestCase {
    private var base: URL!
    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: base) }
    private var file: URL { base.appendingPathComponent("audit.jsonl") }
    private func append(_ outcome: String = "started", io: AuditIO = AuditIO()) throws {
        try audit("operation", user: "@u:h", room: "!r:h", action: "send", outcome: outcome, base: base, io: io, now: Date(timeIntervalSince1970: 0))
    }
    func testRealAppendProducesPrivateCompleteRecordsWithStableFields() throws {
        try append(); try append("accepted")
        let data = try Data(contentsOf: file)
        XCTAssertEqual(data.last, 10)
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        for (line, outcome) in zip(lines, ["started", "accepted"]) {
            let row = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: String])
            XCTAssertEqual(row, ["operation": "operation", "account": "@u:h", "roomId": "!r:h", "action": "send", "outcome": outcome, "at": "1970-01-01T00:00:00Z"])
        }
        let mode = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600)
    }
    func testPartialTailRefusesAndPreservesOriginalBytes() throws {
        for bytes in [Data("{".utf8), Data("{\"outcome\":\"started\"}\n{\"outcome\":".utf8)] {
            try bytes.write(to: file)
            XCTAssertThrowsError(try append()) { XCTAssertTrue(String(describing: $0).contains("incomplete record")) }
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }
    func testShortWritesAreCompletedBeforeSync() throws {
        var calls = 0, synced = false
        try append(io: AuditIO(write: { fd, bytes, count in
            calls += 1
            return Darwin.write(fd, bytes, min(3, count))
        }, sync: { fd in synced = true; return fsync(fd) }))
        XCTAssertGreaterThan(calls, 1); XCTAssertTrue(synced)
        XCTAssertEqual(try Data(contentsOf: file).last, 10)
        XCTAssertNoThrow(try append("accepted"))
    }
    func testZeroAndNegativeWriteFailWithoutSync() throws {
        for result in [0, -1] {
            try Data().write(to: file)
            var synced = false
            XCTAssertThrowsError(try append(io: AuditIO(write: { _, _, _ in result }, sync: { _ in synced = true; return 0 })))
            XCTAssertFalse(synced)
            XCTAssertTrue(try Data(contentsOf: file).isEmpty)
        }
    }
    func testPartialWriteThenFailureBlocksNextAppend() throws {
        var calls = 0
        XCTAssertThrowsError(try append(io: AuditIO(write: { fd, bytes, _ in
            calls += 1
            return calls == 1 ? Darwin.write(fd, bytes, 5) : -1
        })))
        let partial = try Data(contentsOf: file)
        XCTAssertEqual(partial.count, 5)
        XCTAssertThrowsError(try append())
        XCTAssertEqual(try Data(contentsOf: file), partial)
    }
    func testFsyncFailureCannotClaimDurabilityEvenWithCompleteRecord() throws {
        XCTAssertThrowsError(try append(io: AuditIO(sync: { _ in -1 }))) { XCTAssertTrue(String(describing: $0).contains("cannot flush")) }
        XCTAssertEqual(try Data(contentsOf: file).last, 10)
    }
    func testSymlinkAndDirectoryAuditTargetsRefused() throws {
        let target = base.appendingPathComponent("target")
        try Data("untouched".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        XCTAssertThrowsError(try append())
        XCTAssertEqual(try String(contentsOf: target), "untouched")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertThrowsError(try append())
    }
    func testRealOutputFileFailureAfterAcceptanceKeepsAuditAndSaysDoNotResend() async throws {
        let sink = base.appendingPathComponent("read-only-output")
        try Data().write(to: sink)
        let handle = try FileHandle(forReadingFrom: sink)
        defer { try? handle.close() }
        var mutated = false
        do {
            try await performWrite(Command(["send", "!r:h", "secret"]), user: "@u:h", room: "!r:h", loadPolicy: { allowedPolicy }, audit: { try self.append($0) }, mutate: {
                mutated = true; return .event("$accepted")
            }, output: { row in try jsonLine(row, write: { try handle.write(contentsOf: $0) }) })
            XCTFail("read-only file accepted output")
        } catch {
            XCTAssertEqual(String(describing: error), "server accepted the write but output failed; do not resend; inspect the chat")
        }
        XCTAssertTrue(mutated)
        let log = try String(contentsOf: file)
        XCTAssertTrue(log.contains("started")); XCTAssertTrue(log.contains("accepted"))
        XCTAssertTrue(try Data(contentsOf: sink).isEmpty)
    }
    func testInjectedSyncFailureAfterServerAcceptancePreservesStartedRecord() async throws {
        var mutationCount = 0
        do {
            try await performWrite(Command(["send", "!r:h", "secret"]), user: "@u:h", room: "!r:h", loadPolicy: { allowedPolicy }, audit: { outcome in
                try self.append(outcome, io: AuditIO(sync: { fd in outcome == "accepted" ? -1 : fsync(fd) }))
            }, mutate: { mutationCount += 1; return .event("$accepted") }, output: { _ in XCTFail("must not print success after durability failure") })
            XCTFail("disk failure ignored")
        } catch { XCTAssertTrue(String(describing: error).contains("server accepted")) }
        XCTAssertEqual(mutationCount, 1)
        let log = try String(contentsOf: file)
        XCTAssertTrue(log.contains("started")); XCTAssertTrue(log.contains("accepted"))
        XCTAssertFalse(log.contains("secret"))
    }
}
