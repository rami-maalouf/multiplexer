@testable import MatrixCore
import XCTest

final class SendPresentationTests: XCTestCase {
    func testIdenticalSendsKeepTheirPresentationIdentityThroughDelivery() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("test credentials are not set")
        }
        let account = try await testAccount(env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password)
        let rooms = try await account.rooms()
        let room = try XCTUnwrap(rooms.first { $0.name == "Multiplexer test" })
        let text = "Presentation identity \(UUID().uuidString)"
        let firstToken = UUID().uuidString, secondToken = UUID().uuidString
        async let first = account.send(roomId: room.id, text: text, presentationId: firstToken)
        async let second = account.send(roomId: room.id, text: text, presentationId: secondToken)
        let (a, b) = try await (first, second)
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a, b)
        var messages = try await account.messages(roomId: room.id, limit: 20)
        XCTAssertEqual(messages.first { $0.id == a }?.presentationId, firstToken)
        XCTAssertEqual(messages.first { $0.id == b }?.presentationId, secondToken)
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline && messages.filter({ $0.body == text && $0.sendState == .sent }).count != 2 {
            try await Task.sleep(nanoseconds: 100_000_000)
            messages = try await account.messages(roomId: room.id, limit: 20)
        }
        XCTAssertEqual(messages.filter { $0.body == text && $0.sendState == .sent }.count, 2)
        XCTAssertEqual(Set(messages.filter { $0.body == text }.map(\.presentationId)), Set([firstToken, secondToken]))
        try await account.signOut()
    }
}
