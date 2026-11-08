import XCTest
import Darwin
@testable import CLIKit

final class ProcessLockTests: XCTestCase {
    func testChildLockHolder() throws {
        // only the test subprocess enters this branch; production has no test switches.
        guard let path = ProcessInfo.processInfo.environment["MX_TEST_LOCK_DIRECTORY"] else { return }
        let base = URL(fileURLWithPath: path)
        let lock = try ProcessLock(base: base)
        try Data("ready".utf8).write(to: base.appendingPathComponent("ready"))
        withExtendedLifetime(lock) { while true { pause() } }
    }
    func testIndependentProcessContentionAndCrashRelease() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        child.arguments = ["xctest", "-XCTest", "CLIKitTests.ProcessLockTests/testChildLockHolder", Bundle(for: Self.self).bundleURL.path]
        child.environment = ProcessInfo.processInfo.environment.merging(["MX_TEST_LOCK_DIRECTORY": base.path]) { _, new in new }
        let output = Pipe()
        child.standardOutput = output; child.standardError = output
        try child.run()
        defer {
            if child.isRunning { kill(child.processIdentifier, SIGKILL); child.waitUntilExit() }
        }
        let deadline = Date().addingTimeInterval(15)
        while child.isRunning && !FileManager.default.fileExists(atPath: base.appendingPathComponent("ready").path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard FileManager.default.fileExists(atPath: base.appendingPathComponent("ready").path) else {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
            XCTFail("lock child did not signal readiness: \(String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))")
            return
        }
        XCTAssertThrowsError(try ProcessLock(base: base)) { error in
            XCTAssertTrue(String(describing: error).contains("another mx command owns the session"))
        }
        XCTAssertEqual(kill(child.processIdentifier, SIGKILL), 0)
        child.waitUntilExit()
        XCTAssertEqual(child.terminationReason, .uncaughtSignal)
        let acquired = try ProcessLock(base: base)
        withExtendedLifetime(acquired) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("process.lock").path))
    }
    func testNormalReleaseAndPrivatePermissions() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        var lock: ProcessLock? = try ProcessLock(base: base)
        XCTAssertNotNil(lock)
        XCTAssertThrowsError(try ProcessLock(base: base))
        lock = nil
        let next = try ProcessLock(base: base)
        withExtendedLifetime(next) {}
        let directoryMode = try FileManager.default.attributesOfItem(atPath: base.path)[.posixPermissions] as? NSNumber
        let fileMode = try FileManager.default.attributesOfItem(atPath: base.appendingPathComponent("process.lock").path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(directoryMode?.intValue, 0o700)
        XCTAssertEqual(fileMode?.intValue, 0o600)
    }
    func testSymlinkLockIsRefusedWithoutTouchingTarget() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let target = base.appendingPathComponent("target")
        try Data("original".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: base.appendingPathComponent("process.lock"), withDestinationURL: target)
        XCTAssertThrowsError(try ProcessLock(base: base))
        XCTAssertEqual(try String(contentsOf: target), "original")
    }
}
