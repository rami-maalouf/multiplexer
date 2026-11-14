import XCTest
@testable import MatrixCore

final class AddressBookTests: XCTestCase {
    func testBridgeContactWithoutMatrixGhostOrPhoneKeepsItsIdentity() throws {
        let source = ConversationSource(base: URL(string: "https://example.org/bridge")!, login: "test", account: ConversationAccount(id: "account", name: "Test", network: "whatsapp"))
        let resolved = try JSONDecoder().decode(ConversationResolved.self, from: Data(#"{"id":"lid-123","name":"Alex"}"#.utf8))
        let person = try XCTUnwrap(resolved.person(source: source))
        let result = ContactBook.find("Alex", book: [], people: [person], chats: []).people
        XCTAssertEqual(result.first?.accountId, "account")
        XCTAssertEqual(result.first?.identifier, "lid-123")
    }
    func testPartialBridgeRefreshKeepsFailedSourcesAndSurvivesBookChange() {
        let cache = ContactBook()
        let first = BridgePerson(userId: "a", name: "Alex", network: "whatsapp", accountId: "a", phones: [], room: "")
        let second = BridgePerson(userId: "b", name: "Blair", network: "signal", accountId: "b", phones: [], room: "")
        XCTAssertTrue(cache.startFetch(force: true))
        cache.set([])
        cache.finishFetch(BridgePeople(people: [first, second], refreshed: ["a", "b"], known: ["a", "b"], complete: true))
        XCTAssertEqual(cache.snapshot()?.people.count, 2)
        XCTAssertTrue(cache.startFetch(force: true))
        cache.finishFetch(BridgePeople(people: [], refreshed: ["a"], known: ["a", "b"], complete: true))
        XCTAssertEqual(cache.snapshot()?.people, [second])
        XCTAssertTrue(cache.startFetch(force: true))
        cache.finishFetch(BridgePeople(people: [], refreshed: [], known: [], complete: true))
        XCTAssertEqual(cache.snapshot()?.people, [])
    }
    func testNumbersDoNotMergeDifferentCountriesOrShortSuffixes() {
        XCTAssertTrue(PhoneNumber.same("+1 (415) 555-0101", "4155550101"))
        XCTAssertTrue(PhoneNumber.same("00441555550101", "+441555550101"))
        XCTAssertFalse(PhoneNumber.same("+14155550101", "+444155550101"))
        XCTAssertFalse(PhoneNumber.same("5550101", "+14155550101"))
        XCTAssertFalse(PhoneNumber.same("+9613123456", "+13123456"))
    }
    func testSearchOfSecondNumberKeepsThatNumber() {
        let book = [BookContact(id: "a", name: "Alex", phones: ["+14155550101", "+14155550202"])]
        let found = ContactBook.find("5550202", book: book, people: [], chats: []).people
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.phones, ["+14155550202"])
    }
    func testAmbiguousContactsDoNotRenameAChat() {
        let book = BookIndex([BookContact(id: "a", name: "Alex", phones: ["+14155550101"]),
                              BookContact(id: "b", name: "Blair", phones: ["+14155550101"])])
        XCTAssertNil(book.contact("+14155550101"))
    }
    func testFindsContactsWithoutChatsByNameOrFormattedNumber() {
        let book = [BookContact(id: "a", name: "Amélie Test", phones: ["+1 (415) 555-0101"])]
        XCTAssertEqual(ContactBook.find("amelie", book: book, people: [], chats: []).people.first?.name, "Amélie Test")
        XCTAssertEqual(ContactBook.find("415 555", book: book, people: [], chats: []).people.count, 1)
    }
    func testExistingChatKeepsBridgeAliasAndUnsavedNumberSearchable() {
        var room = RoomSummary(id: "!test", name: "Saved Name", isDirect: true, lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
        room.roomName = "Profile Name"
        room.phones = ["+14155550101"]
        XCTAssertEqual(MatrixAccount.chatsNamed("profile", in: [room]).map(\.id), ["!test"])
        XCTAssertEqual(MatrixAccount.chatsNamed("(415) 555", in: [room]).map(\.id), ["!test"])
        room.isHidden = true
        XCTAssertTrue(MatrixAccount.chatsNamed("profile", in: [room]).isEmpty)
    }
    func testBridgeLinksLidChatAndDeduplicatesPeopleResult() {
        var room = RoomSummary(id: "!test", name: "Profile Name", isDirect: true, lastMessage: "", lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
        room.isOneToOne = true
        room.counterpart = "@whatsapp_lid-123:example.org"
        let person = BridgePerson(userId: room.counterpart, name: "Profile Name", network: "whatsapp", accountId: "test", phones: ["+14155550101"], room: room.id)
        let book = [BookContact(id: "a", name: "Saved Name", phones: ["+14155550101"])]
        XCTAssertEqual(ContactBook.link([room], book: book, people: [person])[room.id]?.name, "Saved Name")
        let found = ContactBook.find("Saved", book: book, people: [person], chats: [room])
        XCTAssertEqual(found.chatIds, [room.id])
        XCTAssertTrue(found.people.isEmpty)
        let multiple = [BookContact(id: "a", name: "Saved Name", phones: ["+14155550101", "+14155550202"])]
        let choices = ContactBook.find("Saved", book: multiple, people: [person], chats: [room])
        XCTAssertEqual(choices.chatIds, [room.id])
        XCTAssertEqual(choices.people.flatMap(\.phones), ["+14155550202"])
        XCTAssertEqual(ContactBook.find("Profile", book: [], people: [person], chats: [room]).chatIds, [room.id])
    }
}
