@testable import MatrixCore
import XCTest

/// A chat's long-press actions, as two test users (`scripts/test-matrix-core.sh` passes them).
/// Its rooms are its own, made on the first run, so other tests' messages do not reach them.
final class ChatActionsTests: XCTestCase {
    private let heldName = "Multiplexer hold test"
    private let archiveName = "Multiplexer hold test archive"
    private let deleteName = "Multiplexer hold test delete"
    /// A chat whose bridge bot is a service member (`io.element.functional_members`), as a mautrix
    /// bridge marks its bot: a WhatsApp chat. The bot is not invited.
    private let bridgedName = "Multiplexer hold test WhatsApp"
    /// Rami's choices of 2026-11-03: a deleted chat comes back with only its new messages, and
    /// our own message brings an archived chat back. The WhatsApp one is for the app's drives.
    private let choicesDeleteName = "Multiplexer choices test delete"
    private let choicesArchiveName = "Multiplexer choices test archive"
    private let choicesWhatsAppName = "Multiplexer choices test WhatsApp"
    /// select chats acts on these two together.
    private let selectNames = ["Multiplexer select test one", "Multiplexer select test two"]

    func testMarkedUnreadClearsOnReadAndAMutedChatStillCountsMentions() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let held = try await testRooms(owner, sender, user2: user2)[heldName]!
        try await owner.unmute(roomId: held)
        try await owner.markRead(roomId: held)
        let second = try await signIn(homeserver, user, password)

        // marked unread, it counts as unread here at once, and on the other device from the server.
        try await owner.setMarkedUnread(roomId: held, true)
        let unread = try await owner.inbox(filter: .unread).listed
        XCTAssertTrue(unread.contains(held), "a chat marked unread is not under Unread")
        _ = try await summary(second, held) { $0.isMarkedUnread }
        // reading it takes the mark away, as opening the chat does.
        try await owner.markRead(roomId: held)
        _ = try await summary(owner, held) { !$0.isMarkedUnread }
        _ = try await summary(second, held) { !$0.isMarkedUnread }

        // muted, it shows so at once, and on the other device from the server's push rules.
        try await owner.mute(roomId: held)
        let shown = try await summary(owner, held) { _ in true }
        XCTAssertTrue(shown.isMuted, "a muted chat does not show as muted at once")
        _ = try await summary(second, held) { $0.isMuted }
        // the other person's message counts, as no mention.
        let plain = "Plain \(UUID().uuidString)"
        try await say(plain, in: held, as: sender)
        let counted = try await summary(owner, held) { $0.lastMessage == plain && $0.unreadCount > 0 }
        XCTAssertTrue(counted.isMuted, "the chat is no longer muted")
        XCTAssertEqual(counted.unreadMentions, 0, "a message with no mention counts as one")
        // a message that mentions the reader counts as a mention, though the chat is muted.
        try await say("Mention \(UUID().uuidString)", in: held, as: sender, mentioning: user)
        let mentioned = try await summary(owner, held) { $0.unreadMentions > 0 }
        XCTAssertTrue(mentioned.isMuted)
        XCTAssertGreaterThanOrEqual(mentioned.unreadCount, 2)

        // unmuted on one device, the other sees it; read, nothing counts.
        try await owner.unmute(roomId: held)
        _ = try await summary(second, held) { !$0.isMuted }
        try await owner.markRead(roomId: held)
        _ = try await summary(owner, held) { $0.unreadCount == 0 && $0.unreadMentions == 0 && !$0.isMuted }
    }

    /// Another device's archive changes no room, so the room list does not tell of it: the account
    /// data watch does, within a few seconds, so the open list updates. (Other changes reach the
    /// room list now and then, so the test listens to a watch of its own; a drive checks the app.)
    func testAnotherDevicesArchiveTellsTheList() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let archived = try await testRooms(owner, sender, user2: user2)[archiveName]!
        try await reset(owner, archived)
        let second = try await signIn(homeserver, user, password)
        _ = try await summary(second, archived) { !$0.isArchived }

        let heard = Heard(), watch = AccountDataWatch()
        watch.start(second.client, interval: 0.5) { _ in heard.add() }
        defer { watch.stop() }
        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertEqual(heard.count, 0, "the watch heard a change before any")
        try await owner.archive(roomId: archived)
        let told = Date()
        while heard.count == 0, Date().timeIntervalSince(told) < 15 { try await Task.sleep(nanoseconds: 200_000_000) }
        XCTAssertEqual(heard.count, 1, "the other device was not told of the archive")
        let shown = try await second.rooms().first { $0.id == archived }
        XCTAssertEqual(shown?.isArchived, true, "told, the list still shows the chat in the inbox")
        try await owner.unarchive(roomId: archived)
    }

    /// select chats: each action reaches every selected chat, here and on another device.
    func testSelectedChatsChangeTogether() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(owner, sender, user2: user2)
        let both = selectNames.map { rooms[$0]! }
        // a chat deleted by an earlier run comes back with a message.
        for id in both {
            guard try await summary(owner, id, { _ in true }).isHidden else { continue }
            try await say("Back \(UUID().uuidString)", in: id, as: sender)
            _ = try await summary(owner, id) { !$0.isHidden }
        }
        for id in both {
            try await reset(owner, id)
            try await owner.unpin(roomId: id)
        }
        let second = try await signIn(homeserver, user, password)

        try await owner.change(roomIds: both, .archive)
        for id in both {
            try await assertListed(owner, id, in: .archive)
            try await listed(second, id, in: .archive)
        }
        try await owner.change(roomIds: both, .unarchive)
        for id in both { try await listed(second, id, in: .inbox) }

        try await owner.change(roomIds: both, .lowPriority)
        for id in both { try await listed(second, id, in: .lowPriority) }
        try await owner.change(roomIds: both, .inbox)
        for id in both { try await listed(second, id, in: .inbox) }

        try await owner.change(roomIds: both, .mute)
        for id in both { _ = try await summary(second, id) { $0.isMuted } }
        try await owner.change(roomIds: both, .unmute)
        for id in both { _ = try await summary(second, id) { !$0.isMuted } }

        try await owner.change(roomIds: both, .unread)
        for id in both { _ = try await summary(second, id) { $0.isMarkedUnread } }
        try await owner.change(roomIds: both, .read)
        for id in both { _ = try await summary(second, id) { !$0.isMarkedUnread && $0.unreadCount == 0 } }

        // pinned in the order chosen.
        try await owner.change(roomIds: both, .pin)
        let pinned = try await summary(second, both[1]) { $0.isPinned }
        let first = try await summary(second, both[0]) { $0.isPinned }
        XCTAssertLessThan(first.pinOrder ?? 0, pinned.pinOrder ?? 0, "the pins do not keep the order chosen")
        try await owner.change(roomIds: both, .unpin)
        for id in both { _ = try await summary(second, id) { !$0.isPinned } }

        // deleted: in no list on either device; a new message brings each back.
        try await owner.change(roomIds: both, .delete)
        for id in both {
            try await assertListed(owner, id, in: nil)
            _ = try await summary(second, id) { $0.isHidden }
        }
        for id in both { try await say("Again \(UUID().uuidString)", in: id, as: sender) }
        for id in both { try await listed(second, id, in: .inbox) }
        for id in both { try await owner.markRead(roomId: id) }
    }

    func testLowPriorityArchiveAndDeleteLeaveTheInboxOnAnotherDevice() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(owner, sender, user2: user2)
        let archived = rooms[archiveName]!, deleted = rooms[deleteName]!, bridged = rooms[bridgedName]!
        try await reset(owner, archived)
        try await reset(owner, bridged)
        // a chat deleted by an earlier run comes back with a message.
        let before = try await summary(owner, deleted) { _ in true }
        if before.isHidden {
            try await say("Back \(UUID().uuidString)", in: deleted, as: sender)
            _ = try await summary(owner, deleted) { !$0.isHidden }
        }
        try await reset(owner, deleted)
        let second = try await signIn(homeserver, user, password)

        // Low Priority: out of the inbox, in its own list, here at once and on the other device.
        try await owner.setLowPriority(roomId: archived, true)
        try await assertListed(owner, archived, in: .lowPriority)
        try await listed(second, archived, in: .lowPriority)
        try await assertListed(second, archived, in: .lowPriority)

        // archived: out of the inbox and Low Priority, in the Archive list.
        try await owner.setLowPriority(roomId: archived, false)
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await listed(second, archived, in: .archive)
        try await assertListed(second, archived, in: .archive)

        // deleted: in no list, here and on the other device; the room stays joined.
        try await owner.hide(roomId: deleted)
        try await assertListed(owner, deleted, in: nil)
        _ = try await summary(second, deleted) { $0.isHidden }
        try await assertListed(second, deleted, in: nil)
        // a new message brings it back, on both.
        try await say("Again \(UUID().uuidString)", in: deleted, as: sender)
        try await listed(owner, deleted, in: .inbox)
        try await listed(second, deleted, in: .inbox)

        // the Archive narrowed to a network: its archived chats only.
        _ = try await summary(owner, bridged) { $0.network == "whatsapp" }
        try await owner.archive(roomId: bridged)
        let onWhatsApp = try await owner.inbox(filter: .all, list: .archive, network: "whatsapp").rooms.map(\.id)
        XCTAssertTrue(onWhatsApp.contains(bridged), "an archived WhatsApp chat is missing from WhatsApp's Archive")
        XCTAssertFalse(onWhatsApp.contains(archived), "an archived plain chat shows in WhatsApp's Archive")
        let onMatrix = try await owner.inbox(filter: .all, list: .archive, network: "matrix").rooms.map(\.id)
        XCTAssertTrue(onMatrix.contains(archived))
        XCTAssertFalse(onMatrix.contains(bridged))
        let inboxOnWhatsApp = try await owner.inbox(filter: .all, network: "whatsapp").rooms.map(\.id)
        XCTAssertFalse(inboxOnWhatsApp.contains(bridged), "an archived WhatsApp chat shows in WhatsApp's inbox")

        try await owner.unarchive(roomId: bridged)
        try await owner.unarchive(roomId: archived)
        try await listed(second, archived, in: .inbox)
        try await owner.markRead(roomId: deleted)
    }

    func testAnArchivedChatComesBackWithANewMessageUnlessItIsMuted() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let archived = try await testRooms(owner, sender, user2: user2)[archiveName]!
        try await reset(owner, archived)

        // a new message brings an archived chat back to the inbox.
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await say("Back \(UUID().uuidString)", in: archived, as: sender)
        try await listed(owner, archived, in: .inbox)
        try await assertListed(owner, archived, in: .inbox)

        // a muted one stays archived.
        try await owner.archive(roomId: archived)
        try await owner.mute(roomId: archived)
        let quiet = "Quiet \(UUID().uuidString)"
        try await say(quiet, in: archived, as: sender)
        let muted = try await summary(owner, archived) { $0.lastMessage == quiet }
        XCTAssertTrue(muted.isArchived, "a muted archived chat came back with a message")
        try await assertListed(owner, archived, in: .archive)

        // unmuted, it stays archived until its next message.
        try await owner.unmute(roomId: archived)
        _ = try await summary(owner, archived) { !$0.isMuted }
        try await assertListed(owner, archived, in: .archive)
        try await say("Next \(UUID().uuidString)", in: archived, as: sender)
        try await listed(owner, archived, in: .inbox)

        try await owner.unarchive(roomId: archived)
        try await owner.markRead(roomId: archived)
    }

    func testADeletedChatComesBackWithOnlyItsNewMessages() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let deleted = try await testRooms(owner, sender, user2: user2)[choicesDeleteName]!
        if try await summary(owner, deleted, { _ in true }).isHidden {
            try await say("Back \(UUID().uuidString)", in: deleted, as: sender)
            _ = try await summary(owner, deleted) { !$0.isHidden }
        }
        let old = "Old \(UUID().uuidString)"
        try await say(old, in: deleted, as: sender)
        _ = try await bodies(owner, deleted) { $0.contains(old) }

        // deleted, the open chat no longer shows its messages.
        try await owner.hide(roomId: deleted)
        try await assertListed(owner, deleted, in: nil)
        let empty = try await owner.messages(roomId: deleted, limit: 20).map(\.body)
        XCTAssertFalse(empty.contains(old), "a deleted chat still shows its old messages")

        // a new message brings it back with that message only.
        let new = "New \(UUID().uuidString)"
        try await say(new, in: deleted, as: sender)
        try await listed(owner, deleted, in: .inbox)
        let back = try await bodies(owner, deleted) { $0.contains(new) }
        XCTAssertFalse(back.contains(old), "the chat that came back shows its old messages")
        let atStart = try await owner.isAtStart(roomId: deleted)
        XCTAssertTrue(atStart, "older messages can still be loaded")

        // a device that opens the chat for the first time pages back to the delete, not past it.
        let second = try await signIn(homeserver, user, password)
        try await listed(second, deleted, in: .inbox)
        let fresh = try await bodies(second, deleted) { $0.contains(new) }
        XCTAssertFalse(fresh.contains(old), "another device shows the old messages")
        XCTAssertEqual(fresh.last, new)
        try await second.loadOlder(roomId: deleted)
        let older = try await second.messages(roomId: deleted, limit: 20).map(\.body)
        XCTAssertFalse(older.contains(old), "loading older messages shows those before the delete")
        let secondAtStart = try await second.isAtStart(roomId: deleted)
        XCTAssertTrue(secondAtStart)
        try await owner.markRead(roomId: deleted)
    }

    func testYourOwnMessageBringsAnArchivedChatBack() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let archived = try await testRooms(owner, sender, user2: user2)[choicesArchiveName]!
        try await reset(owner, archived)
        let other = try await signIn(homeserver, user, password)

        // sent from this app: back at once, and on the other device.
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await owner.send(roomId: archived, text: "Mine \(UUID().uuidString)")
        try await listed(owner, archived, in: .inbox)
        try await listed(other, archived, in: .inbox)

        // sent from another device of the account.
        try await owner.archive(roomId: archived)
        try await assertListed(owner, archived, in: .archive)
        try await say("Elsewhere \(UUID().uuidString)", in: archived, as: other)
        try await listed(owner, archived, in: .inbox)
        try await assertListed(owner, archived, in: .inbox)

        // a muted one: the other person's message leaves it archived, our own brings it back, and
        // it stays back when they answer.
        try await owner.archive(roomId: archived)
        try await owner.mute(roomId: archived)
        let quiet = "Quiet \(UUID().uuidString)"
        try await say(quiet, in: archived, as: sender)
        let stayed = try await summary(owner, archived) { $0.lastMessage == quiet }
        XCTAssertTrue(stayed.isArchived, "a muted archived chat came back with someone else's message")
        try await owner.send(roomId: archived, text: "Mine too \(UUID().uuidString)")
        try await listed(owner, archived, in: .inbox)
        let answer = "Answer \(UUID().uuidString)"
        try await say(answer, in: archived, as: sender)
        let answered = try await summary(owner, archived) { $0.lastMessage == answer }
        XCTAssertFalse(answered.isArchived, "the answer archived the chat again")
        try await assertListed(owner, archived, in: .inbox)

        try await reset(owner, archived)
        try await owner.markRead(roomId: archived)
    }

    /// The rules without a server: which list each chat is in, when a mark holds, and the
    /// marks' content.
    func testListAndMarkRules() {
        func chat(_ id: String, last: UInt64 = 10, muted: Bool = false, low: Bool = false, pinned: Bool = false) -> RoomSummary {
            var r = RoomSummary(id: id, name: id, isDirect: false, lastMessage: "Hi", lastSenderName: "A", lastIsOwn: false,
                                lastTimestamp: last, unreadCount: 1)
            r.isMuted = muted
            r.isLowPriority = low
            r.isPinned = pinned
            return r
        }
        let marks = ChatMarks(archived: ["a": 10, "b": 5, "m": 5, "p": 10], hidden: ["h": 10, "g": 5])
        var rooms = [chat("a"), chat("b"), chat("m", muted: true), chat("p", pinned: true), chat("l", low: true),
                     chat("h"), chat("g"), chat("i")]
        for i in rooms.indices { rooms[i].fillMarks(marks) }
        func ids(_ filter: RoomFilter, _ list: ChatList = .inbox) -> [String] { rooms.filter { $0.matches(filter, in: list) }.map(\.id) }
        // "b" and "g" have a message newer than their marks; "m" is muted, so it stays archived.
        XCTAssertEqual(ids(.all, .archive), ["a", "m", "p"])
        XCTAssertEqual(ids(.all, .lowPriority), ["l"])
        XCTAssertEqual(ids(.all), ["b", "g", "i"])
        XCTAssertEqual(ids(.unread), ["b", "g", "i"])
        // the filter menu narrows the Archive too; a pinned archived chat shows there.
        XCTAssertEqual(ids(.groups, .archive), ["a", "m", "p"])
        XCTAssertEqual(ids(.people, .archive), [])
        // a deleted chat is in no list.
        let deleted = rooms.first { $0.id == "h" }!
        XCTAssertNil(deleted.list)
        XCTAssertFalse(ChatList.allCases.contains { list in RoomFilter.allCases.contains { deleted.matches($0, in: list) } })
        // an archived pinned chat leaves the pinned grid too.
        XCTAssertFalse(rooms.first { $0.id == "p" }!.isInInbox)

        // the sheet's counts: each list's unread chats; a muted one only with a mention.
        var mentioned = chat("n", muted: true)
        mentioned.unreadMentions = 1
        let inbox = Inbox(chats: rooms + [chat("q", muted: true), mentioned], listed: [], pinned: [])
        XCTAssertEqual(inbox.unreadChats(in: .inbox), 4)
        XCTAssertEqual(inbox.unreadChats, 4)
        XCTAssertEqual(inbox.unreadChats(in: .archive), 2)
        XCTAssertEqual(inbox.unreadChats(in: .lowPriority), 1)
        XCTAssertEqual(inbox.networks, [NetworkCount(network: "matrix", unread: 4)])

        // the content keeps another version's keys, and drops the marks of chats that came back.
        var read = ChatMarks(json: #"{"archived":{"a":{"ts":10}},"hidden":{"g":{"ts":5}},"cleared":{"g":{"ts":5}},"labels":{"x":["a"]}}"#)
        XCTAssertEqual(read, ChatMarks(archived: ["a": 10], hidden: ["g": 5], cleared: ["g": 5]))
        read.dropReturned(rooms)
        // a deleted chat that came back keeps its cut.
        XCTAssertEqual(read, ChatMarks(archived: ["a": 10], cleared: ["g": 5]))
        XCTAssertEqual(read.json(), #"{"archived":{"a":{"ts":10}},"cleared":{"g":{"ts":5}},"hidden":{},"labels":{"x":["a"]}}"#)

        // our own newer message brings a muted chat back, and drops its mark; someone else's does not.
        var own = chat("o", last: 20, muted: true)
        own.lastIsOwn = true
        own.fillMarks(ChatMarks(archived: ["o": 10]))
        XCTAssertFalse(own.isArchived)
        var olderOwn = chat("o", last: 5, muted: true)
        olderOwn.lastIsOwn = true
        olderOwn.fillMarks(ChatMarks(archived: ["o": 10]))
        XCTAssertTrue(olderOwn.isArchived)
        var dropped = ChatMarks(archived: ["o": 10, "m": 5])
        dropped.dropReturned([own, rooms.first { $0.id == "m" }!])
        XCTAssertEqual(dropped, ChatMarks(archived: ["m": 5]))
        XCTAssertEqual(ChatMarks(json: nil), ChatMarks())
        XCTAssertEqual(ChatMarks(json: "not json"), ChatMarks())
    }

    // MARK: helpers

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    /// The test's rooms by name, made by the first user on the first run, with the second user in them.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        let server = String(session.userId.split(separator: ":").last ?? "")
        for name in [heldName, archiveName, deleteName, bridgedName, choicesDeleteName, choicesArchiveName, choicesWhatsAppName] + selectNames {
            if let id = known.first(where: { $0.name == name })?.id {
                ids[name] = id
                continue
            }
            var body: [String: Any] = ["name": name, "preset": "private_chat", "invite": [user2]]
            if name == bridgedName || name == choicesWhatsAppName {
                body["initial_state"] = [["type": "io.element.functional_members", "state_key": "",
                                          "content": ["service_members": ["@whatsappbot:\(server)"]]]]
            }
            let created = try await api("POST", ["createRoom"], body, session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        // the other user's sync runs from here, so they can write in the rooms.
        _ = try await other.rooms()
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id)
            if ids.values.allSatisfy(joined.contains) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach the first user's list")
        throw CancellationError()
    }

    /// Back in the inbox: not archived, not in Low Priority, not muted.
    private func reset(_ account: MatrixAccount, _ roomId: String) async throws {
        try await account.unmute(roomId: roomId)
        try await account.setLowPriority(roomId: roomId, false)
        try await account.unarchive(roomId: roomId)
        try await listed(account, roomId, in: .inbox)
    }

    /// A message from `account`, which the server has; with `mentioning`, it mentions that user
    /// as a client does (`m.mentions`).
    private func say(_ text: String, in roomId: String, as account: MatrixAccount, mentioning: String? = nil) async throws {
        var content: [String: Any] = ["msgtype": "m.text", "body": mentioning.map { "\($0): \(text)" } ?? text]
        content["m.mentions"] = ["user_ids": mentioning.map { [$0] } ?? []]
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], content,
                                 session: try account.savedSession())
        XCTAssertNotNil(sent["event_id"], "send: \(sent)")
    }

    /// The chat's summary once it matches `done`, or the last one after 20 s.
    private func summary(_ account: MatrixAccount, _ roomId: String, _ done: (RoomSummary) -> Bool) async throws -> RoomSummary {
        let start = Date()
        while true {
            let rooms = try await account.rooms()
            let found = try XCTUnwrap(rooms.first { $0.id == roomId }, "\(roomId) is not in the list")
            if done(found) { return found }
            if Date().timeIntervalSince(start) > 20 {
                XCTFail("the chat did not change as expected: \(found)")
                return found
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// The chat's message bodies once they match `done`, or the last ones after 20 s.
    private func bodies(_ account: MatrixAccount, _ roomId: String, _ done: ([String]) -> Bool) async throws -> [String] {
        let start = Date()
        while true {
            let shown = try await account.messages(roomId: roomId, limit: 20).map(\.body)
            if done(shown) { return shown }
            if Date().timeIntervalSince(start) > 20 {
                XCTFail("the chat did not show the message: \(shown)")
                return shown
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// Waits until `list` shows the chat, up to 20 s.
    private func listed(_ account: MatrixAccount, _ roomId: String, in list: ChatList) async throws {
        let start = Date()
        while try await !account.inbox(list: list).listed.contains(roomId) {
            if Date().timeIntervalSince(start) > 20 { return XCTFail("\(list): the chat did not show") }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// `list` shows the chat and no other list does; with nil, no list does.
    private func assertListed(_ account: MatrixAccount, _ roomId: String, in expected: ChatList?,
                              file: StaticString = #filePath, line: UInt = #line) async throws {
        for list in ChatList.allCases {
            let shown = try await account.inbox(list: list).listed.contains(roomId)
            XCTAssertEqual(shown, list == expected, "\(list): the chat \(shown ? "shows" : "is missing")", file: file, line: line)
        }
    }

    /// A client-server api call (`/_matrix/client/v3/...`); its JSON answer, an error's included.
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

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await signInTestDevice(homeserver, user, password)
    }
}

/// Counts the room list changes a device was told of.
private final class Heard: @unchecked Sendable {
    private let lock = NSLock()
    private var told = 0
    var count: Int { lock.withLock { told } }
    func add() { lock.withLock { told += 1 } }
}
