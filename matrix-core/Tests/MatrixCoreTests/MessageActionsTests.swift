@testable import MatrixCore
import UIKit
import XCTest

/// A message's long-press actions, as two test users (`scripts/test-matrix-core.sh` passes them).
/// Its rooms are its own, made on the first run, so other tests' messages do not reach them.
final class MessageActionsTests: XCTestCase {
    private let menuName = "Multiplexer menu test"
    private let forwardName = "Multiplexer menu test forward"

    func testAnEditAndADeleteReachTheOtherPerson() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let sender = try await signIn(homeserver, user, password)
        let reader = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(sender, reader, user2: user2)[menuName]!
        _ = try await sender.messages(roomId: roomId, limit: 20)
        _ = try await reader.messages(roomId: roomId, limit: 20)

        // your own text message can be edited; the other person sees the new text, marked edited.
        let text = "Edit me \(UUID().uuidString)"
        try await sender.sendAndWait(roomId: roomId, text: text)
        let mine = try await message(sender, roomId) { $0.body == text && $0.sendState == .sent }
        XCTAssertTrue(mine.isEditable, "your own sent text is not editable")
        let theirs = try await message(reader, roomId) { $0.body == text }
        XCTAssertFalse(theirs.isEditable, "another person's message is editable")
        let edited = "Edited \(UUID().uuidString)"
        try await sender.edit(roomId: roomId, messageId: mine.id, text: edited)
        let seen = try await message(reader, roomId) { $0.id == theirs.id && $0.body == edited }
        XCTAssertTrue(seen.isEdited, "the other person does not see it as edited")
        let own = try await message(sender, roomId) { $0.id == mine.id && $0.body == edited }
        XCTAssertTrue(own.isEdited)
        let editedPreview = try await summary(reader, roomId) { $0.lastMessage == edited }
        print("the list's preview after an edit: \(editedPreview.lastMessage)")
        // another's message cannot be edited.
        do {
            try await reader.edit(roomId: roomId, messageId: theirs.id, text: "Not mine")
            XCTFail("another person's message was edited")
        } catch MatrixCoreError.notEditable {}

        // deleted, it shows as deleted for both, with no text, and in the list's preview.
        try await sender.delete(roomId: roomId, messageId: mine.id)
        _ = try await message(sender, roomId) { $0.id == mine.id && $0.isDeleted }
        let gone = try await message(reader, roomId) { $0.id == theirs.id && $0.isDeleted }
        XCTAssertEqual(gone.body, "")
        XCTAssertFalse(gone.isEditable)
        XCTAssertFalse(gone.isOwn)
        _ = try await summary(reader, roomId) { $0.lastMessage == "Message deleted" }
        _ = try await summary(sender, roomId) { $0.lastMessage == "Message deleted" }
    }

    /// The list says "Message deleted" when the newest message is deleted, with the chat never
    /// opened (the sdk's latest event leaves deleted messages out), and still after a relaunch.
    func testTheListSaysMessageDeletedWithTheChatNotOpened() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let sender = try await signIn(homeserver, user, password)
        let reader = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(sender, reader, user2: user2)[menuName]!
        _ = try await sender.messages(roomId: roomId, limit: 20)

        let before = "Before \(UUID().uuidString)", text = "Delete me \(UUID().uuidString)"
        try await sender.sendAndWait(roomId: roomId, text: before)
        try await sender.sendAndWait(roomId: roomId, text: text)
        let shown = try await summary(reader, roomId) { $0.lastMessage == text }
        let mine = try await message(sender, roomId) { $0.body == text && $0.sendState == .sent }
        try await sender.delete(roomId: roomId, messageId: mine.id)

        let deleted = try await summary(reader, roomId) { $0.lastMessage != text }
        XCTAssertEqual(deleted.lastMessage, "Message deleted", "the list shows the message before the deleted one")
        XCTAssertEqual(deleted.lastSenderName, shown.lastSenderName)
        XCTAssertFalse(deleted.lastIsOwn)
        XCTAssertNil(reader.readyTimeline(roomId), "the reader opened the chat")

        // a relaunch reads what the list showed from the store folder.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("latest-\(UUID().uuidString).json")
        let kept = LatestMessages(file: file)
        var first = shown
        kept.fill(&first)
        kept.save()
        var after = deleted
        after.lastMessage = before
        LatestMessages(file: file).fill(&after)
        XCTAssertEqual(after.lastMessage, "Message deleted", "a relaunch forgets the deleted message")

        // a newer message shows again.
        let next = "After \(UUID().uuidString)"
        try await sender.sendAndWait(roomId: roomId, text: next)
        _ = try await summary(reader, roomId) { $0.lastMessage == next }
    }

    /// The list's preview of an own message: "sent" once the server has it, "seen" after the other
    /// person reads it (their read receipt), and nothing once their answer is the newest message.
    func testThePreviewSaysSentThenSeen() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let sender = try await signIn(homeserver, user, password)
        let reader = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(sender, reader, user2: user2)[menuName]!
        _ = try await reader.messages(roomId: roomId, limit: 20)

        let text = "Receipt \(UUID().uuidString)"
        try await sender.sendAndWait(roomId: roomId, text: text)
        let sent = try await summary(sender, roomId) { $0.lastMessage == text && $0.lastStatus != "" }
        XCTAssertEqual(sent.lastStatus, "sent", "unread by the other person, it says seen")
        XCTAssertTrue(sent.lastIsOwn)

        _ = try await message(reader, roomId) { $0.body == text }
        try await reader.markRead(roomId: roomId)
        let seen = try await summary(sender, roomId) { $0.lastMessage == text && $0.lastStatus == "seen" }
        XCTAssertEqual(seen.lastStatus, "seen")

        let answer = "Answer \(UUID().uuidString)"
        try await reader.sendAndWait(roomId: roomId, text: answer)
        let theirs = try await summary(sender, roomId) { $0.lastMessage == answer }
        XCTAssertEqual(theirs.lastStatus, "", "another person's message has a receipt status")
    }

    func testAForwardedTextPhotoAndFileArriveInAnotherChat() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let sender = try await signIn(homeserver, user, password)
        let reader = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(sender, reader, user2: user2)
        let from = rooms[menuName]!, to = rooms[forwardName]!
        for account in [sender, reader] {
            _ = try await account.messages(roomId: from, limit: 20)
            _ = try await account.messages(roomId: to, limit: 20)
        }

        // the other person's text, forwarded: it arrives as yours, answering nothing.
        let text = "Forward me \(UUID().uuidString)"
        try await reader.sendAndWait(roomId: from, text: text)
        let original = try await message(sender, from) { $0.body == text }
        try await sender.forward(roomId: from, messageId: original.id, to: to)
        let copy = try await message(reader, to) { $0.body == text }
        XCTAssertEqual(copy.sender, user)
        XCTAssertNil(copy.reply)

        // a photo with its caption: the same picture on the server (its file names come from its
        // media url), at its size.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let photo = folder.appendingPathComponent("Forward.jpg"), small = folder.appendingPathComponent("Forward-thumbnail.jpg")
        try jpeg(width: 600, height: 400, .systemOrange).write(to: photo)
        try jpeg(width: 300, height: 200, .systemOrange).write(to: small)
        let caption = "Forwarded photo \(UUID().uuidString)"
        try await reader.sendAttachment(roomId: from, attachment: Attachment(
            file: photo, mimetype: "image/jpeg", size: try size(photo), kind: .photo(width: 600, height: 400),
            thumbnail: .init(file: small, mimetype: "image/jpeg", size: try size(small), width: 300, height: 200)), caption: caption)
        let picture = try await message(sender, from) { $0.body == caption && $0.image != nil }
        try await sender.forward(roomId: from, messageId: picture.id, to: to)
        let forwarded = try await message(reader, to) { $0.body == caption && $0.image != nil }
        XCTAssertEqual(forwarded.sender, user)
        XCTAssertEqual(forwarded.image, picture.image, "the forwarded photo is another picture")
        let full = try await reader.imageFile(roomId: to, messageId: forwarded.id, full: true, directory: folder.appendingPathComponent("full"))
        XCTAssertEqual(UIImage(contentsOfFile: full.path)?.size, CGSize(width: 600, height: 400))
        // the photo's original, to share, keeps its name.
        let shared = try await sender.mediaFile(roomId: from, messageId: picture.id, directory: folder.appendingPathComponent("shared"))
        XCTAssertEqual(shared.lastPathComponent, "Forward.jpg")
        XCTAssertEqual(UIImage(contentsOfFile: shared.path)?.size, CGSize(width: 600, height: 400))

        // a file: the same name, size and bytes.
        let notes = "Notes \(UUID().uuidString)\n", name = "Forward \(UUID().uuidString.prefix(8)).txt"
        let file = folder.appendingPathComponent(name)
        try Data(notes.utf8).write(to: file)
        try await reader.sendAttachment(roomId: from, attachment: Attachment(file: file, mimetype: "text/plain",
                                                                             size: notes.utf8.count, kind: .file))
        let attached = try await message(sender, from) { $0.file?.name == name }
        try await sender.forward(roomId: from, messageId: attached.id, to: to)
        let got = try await message(reader, to) { $0.file?.name == name }
        XCTAssertEqual(got.sender, user)
        XCTAssertEqual(got.file, attached.file)
        let downloaded = try await reader.fileContent(roomId: to, messageId: got.id, directory: folder.appendingPathComponent("file"))
        XCTAssertEqual(try String(contentsOf: downloaded, encoding: .utf8), notes)

        // a deleted message has nothing to forward.
        try await sender.delete(roomId: to, messageId: try await message(sender, to) { $0.body == text }.id)
        let deleted = try await message(sender, to) { $0.isDeleted }
        do {
            try await sender.forward(roomId: to, messageId: deleted.id, to: from)
            XCTFail("a deleted message was forwarded")
        } catch MatrixCoreError.notForwardable {}
    }

    func testFrequentEmojisCountReactionsAndReset() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[menuName]!
        _ = try await owner.messages(roomId: roomId, limit: 20)
        try await owner.resetFrequentEmojis()
        _ = try await frequent(owner) { $0.isEmpty }

        let text = "React to me \(UUID().uuidString)"
        try await other.sendAndWait(roomId: roomId, text: text)
        let target = try await message(owner, roomId) { $0.body == text }
        // a reaction counts at once, and once; taking it back counts nothing.
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🦄")
        let shown = try await owner.frequentEmojis()
        XCTAssertEqual(shown, ["🦄"], "a reaction does not count at once")
        try await ownReactions(owner, roomId, target.id, are: ["🦄"])
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🦄")
        try await ownReactions(owner, roomId, target.id, are: [])
        // two reactions in a row both count, before the sync brings the first back.
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🔥")
        try await ownReactions(owner, roomId, target.id, are: ["🎉", "🔥"])
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🔥")
        try await ownReactions(owner, roomId, target.id, are: [])
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        // the most used first, the latest among equals; the server has the same counts.
        let ordered = try await owner.frequentEmojis()
        XCTAssertEqual(ordered, ["🎉", "🔥", "🦄"])
        let stored = try await storedUses(owner) { $0.uses.map(\.count) == [2, 1, 1] }
        print("recent emojis on the server: \(stored.json())")
        XCTAssertEqual(stored.uses.map(\.count), [2, 1, 1], "the server's counts: \(stored.json())")
        // another device of the account has the same list, and Element's reader too. A change of
        // account data reaches another device with its next sync, which can take half a minute.
        let second = try await signIn(homeserver, user, password)
        _ = try await second.rooms()
        _ = try await frequent(second, within: 45) { $0 == ["🎉", "🔥", "🦄"] }
        let sdk = try await second.client.getRecentEmojis()
        XCTAssertEqual(sdk.map(\.emoji), ["🎉", "🔥", "🦄"])

        try await ownReactions(owner, roomId, target.id, are: ["🎉"])
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        try await ownReactions(owner, roomId, target.id, are: [])

        // reset, on every device; a new reaction counts again.
        try await owner.resetFrequentEmojis()
        _ = try await frequent(owner) { $0.isEmpty }
        _ = try await frequent(second, within: 45) { $0.isEmpty }
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        _ = try await frequent(owner) { $0 == ["🎉"] }
        try await ownReactions(owner, roomId, target.id, are: ["🎉"])
        try await owner.toggleReaction(roomId: roomId, messageId: target.id, key: "🎉")
        try await ownReactions(owner, roomId, target.id, are: [])
        try await owner.resetFrequentEmojis()
    }

    /// The counts without a server: Element's content, read and written; the order.
    func testEmojiUses() {
        var uses = EmojiUses(json: #"{"recent_emoji":[["👍",3],["😂",1],["❤️",3],"bad",["x"]]}"#)
        XCTAssertEqual(uses.uses.map(\.emoji), ["👍", "😂", "❤️"])
        XCTAssertEqual(uses.frequent(limit: 18), ["👍", "❤️", "😂"])
        uses.add("😂")
        uses.add("🦄")
        XCTAssertEqual(uses.uses.map(\.emoji), ["🦄", "😂", "👍", "❤️"])
        XCTAssertEqual(uses.frequent(limit: 2), ["👍", "❤️"])
        XCTAssertEqual(EmojiUses(json: uses.json()), uses)
        XCTAssertEqual(EmojiUses(json: nil), EmojiUses())
        XCTAssertEqual(EmojiUses().json(), #"{"recent_emoji":[]}"#)
        for i in 0..<150 { uses.add("\(i)") }
        XCTAssertEqual(uses.uses.count, EmojiUses.limit)
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
        for name in [menuName, forwardName] {
            if let id = known.first(where: { $0.name == name })?.id {
                ids[name] = id
                continue
            }
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        // the other user's sync runs from here, so they can write in the rooms.
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id), theirs = try await other.rooms().map(\.id)
            if ids.values.allSatisfy({ joined.contains($0) && theirs.contains($0) }) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach both users' lists")
        throw CancellationError()
    }

    /// The newest message in the room's chat that matches `found`, once it does, within 30 s.
    private func message(_ account: MatrixAccount, _ roomId: String, _ found: (Message) -> Bool) async throws -> Message {
        let start = Date()
        while Date().timeIntervalSince(start) < 30 {
            if let match = try await account.messages(roomId: roomId, limit: 20).last(where: found) { return match }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("no matching message within 30 s")
        throw CancellationError()
    }

    /// Waits until this account's reactions on a message are exactly `keys`, each one on the server.
    /// A reaction taken back while it is still being sent comes back from the server for about a
    /// second, until the sdk's redaction lands; a toggle then takes it back again instead of
    /// adding it. So a test takes back only a sent reaction, and toggles again once it is gone.
    private func ownReactions(_ account: MatrixAccount, _ roomId: String, _ messageId: String, are keys: Set<String>) async throws {
        let live = try await account.liveTimeline(roomId, limit: 20, timeout: 30)
        let me = try account.client.userId()
        let start = Date()
        var mine: [String: Bool] = [:]
        while Date().timeIntervalSince(start) < 30 {
            // each of this account's reactions, and whether the server has it (no send state).
            mine = [:]
            for reaction in live.items.event(of: messageId)?.reactions ?? [] {
                if let sender = reaction.senders.first(where: { $0.senderId == me }) { mine[reaction.key] = sender.sendState == nil }
            }
            if Set(mine.keys) == keys, !mine.values.contains(false) { return }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        // what the chat holds now: whether the message's id still finds it, and the newest messages.
        let found = live.items.event(of: messageId) != nil
        let newest = live.items.messages().suffix(3).map { "\($0.id) \($0.body.prefix(24))" }
        XCTFail("this account's reactions are \(mine) (true: on the server), not \(keys.sorted()); the id \(messageId) finds the message: \(found); newest: \(newest)")
        throw CancellationError()
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

    /// The account's frequent emojis once they match `done`, or the last ones after `within` seconds.
    private func frequent(_ account: MatrixAccount, within: TimeInterval = 20, _ done: ([String]) -> Bool) async throws -> [String] {
        let start = Date()
        while true {
            let emojis = try await account.frequentEmojis()
            if done(emojis) { return emojis }
            if Date().timeIntervalSince(start) > within {
                XCTFail("the frequent emojis did not change as expected: \(emojis)")
                return emojis
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// The counts in the account's store once they match `done`, or the last ones after 40 s.
    private func storedUses(_ account: MatrixAccount, _ done: (EmojiUses) -> Bool) async throws -> EmojiUses {
        let start = Date()
        while true {
            let uses = EmojiUses(json: try await account.client.accountData(eventType: MatrixAccount.recentEmojiType))
            if done(uses) { return uses }
            if Date().timeIntervalSince(start) > 40 {
                XCTFail("the stored emojis did not change as expected: \(uses.json())")
                return uses
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private func jpeg(width: Int, height: Int, _ color: UIColor) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).jpegData(withCompressionQuality: 0.8) { c in
            color.setFill(); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func size(_ file: URL) throws -> Int {
        try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
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
