import XCTest
@testable import CLIKit

final class ArgumentsTests: XCTestCase {
    func testRejectsUnknownDuplicateMissingAndUnexpectedArguments() {
        for args in [["send", "room", "hello", "--oops"], ["read", "room", "--limit", "2", "--limit", "3"],
                     ["read", "room", "--limit"], ["logout", "extra"], ["send", "room", ""],
                     ["later", "room", "hello", "--at", "yesterday"], ["read", "room", "--limit", "0"], ["login", "@user:", "--password-stdin"]] {
            XCTAssertThrowsError(try Command(args))
        }
    }
    func testQuotedTextAndEndOfOptionsArePreserved() throws {
        let command = try Command(["send", "room", "--", "--a message"])
        XCTAssertEqual(command.positionals, ["room", "--a message"])
    }
    func testPolicyIsExactAndDefaultDeny() throws {
        let data = Data(#"{"version":1,"accounts":{"@test:example.org":["!test:example.org"]}}"#.utf8)
        let policy = try JSONDecoder().decode(WritePolicy.self, from: data)
        XCTAssertTrue(policy.allows(user: "@test:example.org", room: "!test:example.org"))
        XCTAssertFalse(policy.allows(user: "@other:example.org", room: "!test:example.org"))
        XCTAssertFalse(policy.allows(user: "@test:example.org", room: "!other:example.org"))
    }
}
