@testable import MatrixCore
import XCTest

final class ConversationsAuthenticatedTests: XCTestCase {
    // the parent supplies credentials privately and holds the matrixcore lock.
    // no messages are sent. a new direct room is created only when none exists.
    func testMatrixDirectConversationCreationOrReuseAndAccountData() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let home = env["MATRIX_TEST_HOMESERVER"],
              let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let other = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("requires two test users and the test homeserver")
        }
        let allowed = Set(["@test1:ramimaalouf.com", "@test2:ramimaalouf.com"])
        guard allowed.contains(user), allowed.contains(other), user != other else {
            throw XCTSkip("conversation integration accepts only the two dedicated test users")
        }
        let store = FileManager.default.temporaryDirectory.appendingPathComponent("conversation-test-\(UUID().uuidString)")
        let account = try await MatrixAccount.signIn(homeserver: home, user: user, password: password,
                                                    deviceName: "conversation core test", storeDirectory: store)
        addTeardownBlock { try await account.signOut() }
        let recipient = try await MatrixAccount.signIn(homeserver: home, user: other, password: password2,
                                                      deviceName: "conversation core recipient test", storeDirectory: store.appendingPathComponent("recipient"))
        addTeardownBlock { try await recipient.signOut() }
        _ = try await account.rooms(timeout: 120)
        _ = try await recipient.rooms(timeout: 120)
        let accounts = try await account.conversationAccounts()
        XCTAssertTrue(accounts.items.contains { $0.id == "matrix" }, "unauthorized bridges must not block matrix")
        let http = ConversationHTTP(saved: try account.savedSession())
        let before = try await http.directRooms()
        let selected = try await account.conversationContacts(accountId: "matrix", query: other)
        XCTAssertEqual(selected.items.map(\.identifier), [other], "full ids can be selected without directory visibility")
        let room = try await account.startConversation(accountId: "matrix", identifier: other)
        XCTAssertFalse(room.isEmpty)
        let indexed = try await http.directRooms()
        XCTAssertTrue(indexed[other, default: []].contains(room), "new direct rooms must be in m.direct")
        for (person, rooms) in before {
            XCTAssertTrue(Set(rooms).isSubset(of: Set(indexed[person, default: []])), "existing direct mappings must survive")
        }
        let second = try await account.startConversation(accountId: "matrix", identifier: other)
        XCTAssertEqual(second, room, "immediately starting again reuses the same dm")
        if before[other, default: []].contains(room) {
            print("conversation integration: existing dm reuse verified; new creation requires a pair without an existing joined dm")
        } else {
            print("conversation integration: new dm creation and immediate reuse verified")
        }
        // a second fresh client must also find the mapping written by the first.
        let restored = try await MatrixAccount.restore(account.savedSession(), storeDirectory: store.appendingPathComponent("restored"))
        let restoredRoom = try await restored.startConversation(accountId: "matrix", identifier: other)
        XCTAssertEqual(restoredRoom, room)
        let selfRoom = try await account.startConversation(accountId: "matrix", identifier: user)
        XCTAssertFalse(selfRoom.isEmpty)
        let sameSelfRoom = try await account.startConversation(accountId: "matrix", identifier: user)
        XCTAssertEqual(sameSelfRoom, selfRoom, "self conversations must create without inviting their creator and immediately reuse")
        let selfMapping = try await http.directRooms()
        XCTAssertTrue(selfMapping[user, default: []].contains(selfRoom))
        print("conversation integration: self dm creation or reuse and mapping verified")
    }
}
