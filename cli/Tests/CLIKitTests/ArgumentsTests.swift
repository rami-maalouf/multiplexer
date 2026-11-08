import XCTest
@testable import CLIKit

final class ArgumentsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let future = "2023-11-14T23:13:20Z"
    private var valid: [[String]] {
        [[], ["help"], ["-h"], ["--help"], ["login", "@u:host", "--password-stdin"],
         ["whoami"], ["chats"], ["logout"], ["read", "room"], ["search", "needle"],
         ["watch"], ["recover", "--key-stdin"], ["send", "room", "text"],
         ["react", "room", "$event", "reaction"], ["mark-read", "room"],
         ["later", "room", "text", "--at", future]]
    }
    func testEveryCommandValidMinimalArguments() throws {
        for args in valid { _ = try Command(args, now: now) }
        XCTAssertEqual(try Command([]).name, "help")
    }
    func testEveryCommandRejectsExtraPositional() {
        for args in valid { XCTAssertThrowsError(try Command(args.isEmpty ? ["help", "extra"] : args + ["extra"], now: now), "\(args)") }
    }
    func testEveryRequiredPositionalRejectsMissingAndBlank() {
        for args in valid where ["login", "read", "search", "send", "react", "mark-read", "later"].contains(args.first ?? "") {
            let positionalCount = ["send": 2, "react": 3, "later": 2][args[0]] ?? 1
            for index in 1...positionalCount {
                var missing = args; missing.remove(at: index)
                XCTAssertThrowsError(try Command(missing, now: now), "\(missing)")
                for blank in ["", " \n\t"] {
                    var empty = args; empty[index] = blank
                    XCTAssertThrowsError(try Command(empty, now: now), "\(empty)")
                }
            }
        }
    }
    func testEveryCommandRejectsUnknownOption() {
        for args in valid { XCTAssertThrowsError(try Command((args.isEmpty ? ["help"] : args) + ["--unknown"], now: now)) }
        XCTAssertThrowsError(try Command(["unknown"]))
    }
    func testEveryOptionIsRestrictedToItsCommands() {
        let allowed: [String: Set<String>] = ["--password-stdin": ["login"], "--key-stdin": ["recover"],
            "--json": ["chats"], "--dry-run": ["send", "react", "mark-read", "later"],
            "--limit": ["chats", "read", "search", "watch"], "--chat": ["search", "watch"], "--at": ["later"]]
        for args in valid where !args.isEmpty {
            for (option, commands) in allowed where !commands.contains(args[0]) {
                XCTAssertThrowsError(try Command(args + [option, "2"], now: now), "\(args) \(option)")
            }
        }
    }
    func testAllSupportedSwitchesAndDuplicates() throws {
        let cases = [("chats", ["chats"], "--json"), ("send", ["send", "r", "t"], "--dry-run"),
                     ("react", ["react", "r", "$e", "x"], "--dry-run"), ("mark-read", ["mark-read", "r"], "--dry-run"),
                     ("later", ["later", "r", "t", "--at", future], "--dry-run")]
        for (_, args, flag) in cases {
            XCTAssertTrue(try Command(args + [flag], now: now).flags.contains(flag))
            XCTAssertThrowsError(try Command(args + [flag, flag], now: now))
        }
        for args in [["login", "@u:h", "--password-stdin", "--password-stdin"], ["recover", "--key-stdin", "--key-stdin"]] {
            XCTAssertThrowsError(try Command(args))
        }
    }
    func testAllValuedOptionsMissingAndDuplicateValues() {
        for (args, flag, value) in [(["chats"], "--limit", "2"), (["read", "r"], "--limit", "2"),
            (["search", "q"], "--limit", "2"), (["watch"], "--limit", "2"),
            (["search", "q"], "--chat", "r"), (["watch"], "--chat", "r"), (["later", "r", "t"], "--at", future)] {
            XCTAssertNoThrow(try Command(args + [flag, value], now: now))
            XCTAssertThrowsError(try Command(args + [flag], now: now))
            XCTAssertThrowsError(try Command(args + [flag, "--oops"], now: now))
            XCTAssertThrowsError(try Command(args + [flag, value, flag, value], now: now))
        }
    }
    func testLimitBoundsAndDefault() throws {
        for args in [["chats"], ["read", "r"], ["search", "q"], ["watch"]] {
            XCTAssertEqual(try Command(args).limit, 20)
            for value in ["1", "1000"] { XCTAssertEqual(try Command(args + ["--limit", value]).limit, Int(value)) }
            for value in ["0", "-1", "1001", "1.5", "all", "", "999999999999999999999999"] {
                XCTAssertThrowsError(try Command(args + ["--limit", value]))
            }
        }
    }
    func testFutureTimestampIsDeterministicAndRequiresTimezone() throws {
        XCTAssertEqual(try Command(["later", "r", "t", "--at", future], now: now).date, now.addingTimeInterval(3600))
        XCTAssertEqual(try Command(["later", "r", "t", "--at", "2023-11-14T23:13:20.125Z"], now: now).date, now.addingTimeInterval(3600.125))
        for value in ["2023-11-14T22:13:20Z", "2023-11-14T21:13:20Z", "2023-11-14T23:13:20", "tomorrow", ""] {
            XCTAssertThrowsError(try Command(["later", "r", "t", "--at", value], now: now))
        }
        XCTAssertThrowsError(try Command(["later", "r", "t"], now: now))
    }
    func testStdinFlagsRequiredAndFullUserIdentity() {
        XCTAssertThrowsError(try Command(["recover"]))
        XCTAssertThrowsError(try Command(["login", "@u:h"]))
        for user in ["u:h", "@:h", "@u:", "@u", ""] {
            XCTAssertThrowsError(try Command(["login", user, "--password-stdin"]))
        }
        XCTAssertNoThrow(try Command(["login", "@u:host:8448", "--password-stdin"]))
    }
    func testReactionRequiresEventId() {
        XCTAssertThrowsError(try Command(["react", "r", "event", "x"]))
        XCTAssertNoThrow(try Command(["react", "r", "$event", "x"]))
    }
    func testLiteralSeparatorAndTextArePreserved() throws {
        for text in ["--message", "-h", "quotes \" and \n newlines", "  surrounding  ", "--"] {
            XCTAssertEqual(try Command(["send", "room", "--", text]).positionals, ["room", text])
        }
        XCTAssertThrowsError(try Command(["send", "room", "--message"]))
        XCTAssertThrowsError(try Command(["watch", "--", "--chat", "room"]))
        XCTAssertEqual(try Command(["search", "--chat", "room", "query", "--limit", "3"]).options["--chat"], "room")
    }
    func testPolicyExactIdentityAndDefaultDeny() throws {
        let policy = try decode(#"{"version":1,"accounts":{"@u:h":["!r:h"]}}"#)
        XCTAssertTrue(policy.isWellFormed)
        XCTAssertTrue(policy.allows(user: "@u:h", room: "!r:h"))
        for (user, room) in [("@U:h", "!r:h"), ("@u:H", "!r:h"), ("@u:h", "!R:h"), ("@u:h", "r"), ("*", "!r:h"), ("@u:h", "!r:h ")] {
            XCTAssertFalse(policy.allows(user: user, room: room))
        }
        for text in [#"{"version":0,"accounts":{"@u:h":["!r:h"]}}"#, #"{"version":2,"accounts":{"@u:h":["!r:h"]}}"#,
                     #"{"version":1,"accounts":{}}"#, #"{"version":1,"accounts":{"*":["*"]}}"#] {
            XCTAssertFalse(try decode(text).allows(user: "@u:h", room: "!r:h"))
        }
        // a merged or name-like entry corrupts the whole policy: no write can be authorized.
        let bad = try decode(#"{"version":1,"accounts":{"@u:h":["!r:h","merge:x"]}}"#)
        XCTAssertFalse(bad.isWellFormed)
        XCTAssertFalse(bad.allows(user: "@u:h", room: "!r:h"))
        XCTAssertFalse(bad.allows(user: "@u:h", room: "merge:x"))
    }
    func testMalformedPolicyCannotDecode() {
        for text in ["", "{", "null", "[]", "{}", #"{"accounts":{}}"#, #"{"version":"1","accounts":{}}"#,
                     #"{"version":true,"accounts":{}}"#, #"{"version":1,"accounts":[]}"#, #"{"version":1,"accounts":{"@u:h":"!r:h"}}"#] {
            XCTAssertThrowsError(try decode(text), text)
        }
    }
    private func decode(_ text: String) throws -> WritePolicy { try JSONDecoder().decode(WritePolicy.self, from: Data(text.utf8)) }
}
