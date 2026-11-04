@testable import MatrixCore
import UIKit
import XCTest

/// A chat's details (B15) and the message kinds of T2.11 that came with it, as two test users
/// (`scripts/test-matrix-core.sh` passes them). The rooms are the test's own, made on the first run.
final class ChatDetailsTests: XCTestCase {
    private let seenName = "Multiplexer details test"
    private let mediaName = "Multiplexer details test media"
    private let quoteName = "Multiplexer details test quote"

    /// Under one's own message: nobody has read it, then the other person reads the chat and
    /// shows as its reader, by name, with the time. The first unread message follows the read
    /// receipt, and reading the chat clears it.
    func testSeenByAfterTheOtherReadsAndTheFirstUnreadMessage() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[seenName]!
        let otherName = try await displayName(user2, session: try owner.savedSession())

        // one's own message: nobody else has read it yet.
        let mine = "Mine \(UUID().uuidString)"
        try await owner.sendAndWait(roomId: roomId, text: mine)
        let sent = try await message(owner, roomId, within: 30) { $0.body == mine && $0.sendState == .sent }
        XCTAssertEqual(sent.readBy, [], "nobody has read it yet")

        // the other person reads the chat: their receipt is on it, with their name and the time.
        _ = try await message(other, roomId, within: 30) { $0.body == mine }
        let before = UInt64(Date().timeIntervalSince1970 * 1000) - 60_000
        try await other.markRead(roomId: roomId)
        let seen = try await message(owner, roomId, within: 20) { $0.body == mine && !$0.readBy.isEmpty && !$0.readBy[0].name.isEmpty }
        XCTAssertEqual(seen.readBy.map(\.userId), [user2])
        XCTAssertEqual(seen.readBy.first?.name, otherName, "the reader shows by their name")
        XCTAssertGreaterThan(seen.readBy.first?.timestamp ?? 0, before, "the receipt has its time")

        // read up to here; the other person writes twice: the first of the two is the first unread.
        let read = "Read \(UUID().uuidString)"
        try await say(read, in: roomId, as: other)
        _ = try await message(owner, roomId, within: 30) { $0.body == read }
        try await owner.markRead(roomId: roomId)
        _ = try await unread(owner, roomId) { $0 == 0 }
        let first = "Unread one \(UUID().uuidString)", second = "Unread two \(UUID().uuidString)"
        try await say(first, in: roomId, as: other)
        try await say(second, in: roomId, as: other)
        let firstMessage = try await message(owner, roomId, within: 30) { $0.body == first }
        _ = try await message(owner, roomId, within: 30) { $0.body == second }
        _ = try await unread(owner, roomId) { $0 >= 2 }
        let marked = try await owner.firstUnread(roomId: roomId)
        XCTAssertEqual(marked, firstMessage.id, "the line goes above the first message after the read receipt")

        // read, nothing is unread.
        try await owner.markRead(roomId: roomId)
        _ = try await unread(owner, roomId) { $0 == 0 }
        let none = try await owner.firstUnread(roomId: roomId)
        XCTAssertNil(none)
    }

    /// More unread messages than a chat loads at first (20): a device that opens the chat after
    /// them still finds the first one, as the chat pages back to the read receipt, and shows it.
    func testANewLineFurtherBackThanTheChatLoads() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[seenName]!

        // read up to here, then 25 messages from the other person.
        let read = "Read \(UUID().uuidString)"
        try await say(read, in: roomId, as: other)
        _ = try await message(owner, roomId, within: 15) { $0.body == read }
        try await owner.markRead(roomId: roomId)
        _ = try await unread(owner, roomId) { $0 == 0 }
        let run = UUID().uuidString.prefix(8)
        for n in 1...25 { try await say("Many \(run) \(n)", in: roomId, as: other) }
        _ = try await unread(owner, roomId) { $0 >= 25 }

        // another device of the reader opens the chat with its 20 newest: the first unread is older.
        let later = try await signIn(homeserver, user, password)
        _ = try await later.rooms()
        _ = try await unread(later, roomId) { $0 >= 25 }
        let opened = try await later.messages(roomId: roomId, limit: 20)
        XCTAssertFalse(opened.contains { $0.body == "Many \(run) 1" }, "the chat opens with the first unread message: the test needs it further back")
        let found = try await later.firstUnread(roomId: roomId)
        let marked = try XCTUnwrap(found, "no first unread message")
        let shown = try await later.messages(roomId: roomId, limit: 20)
        let first = try XCTUnwrap(shown.first { $0.id == marked })
        XCTAssertEqual(first.body, "Many \(run) 1", "the line goes above the first of the 25")
        XCTAssertTrue(shown.contains { $0.body == read }, "the chat shows the read message before the line")
        // asked again, it finds the same message without paging again.
        let again = try await later.firstUnread(roomId: roomId)
        XCTAssertEqual(again, marked)
        try await later.markRead(roomId: roomId)
        _ = try await unread(owner, roomId) { $0 == 0 }
    }

    /// A video message reaches the other person with its size, length and caption; its poster and
    /// its video download as the sender's bytes.
    func testAVideoReachesTheOtherWithItsSizeLengthAndPoster() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[mediaName]!
        _ = try await owner.messages(roomId: roomId, limit: 20)

        // sent as another client sends one: the video and its poster uploaded, then an m.video event.
        let session = try other.savedSession()
        let video = Data((0..<60_000).map { UInt8($0 % 251) })
        let poster = jpeg(width: 320, height: 180, .systemIndigo)
        let videoUri = try await upload(video, type: "video/mp4", session: session)
        let posterUri = try await upload(poster, type: "image/jpeg", session: session)
        let caption = "Video \(UUID().uuidString)"
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], [
            "msgtype": "m.video", "body": caption, "filename": "clip.mp4", "url": videoUri,
            "info": ["w": 640, "h": 360, "duration": 4200, "mimetype": "video/mp4", "size": video.count,
                     "thumbnail_url": posterUri, "thumbnail_info": ["w": 320, "h": 180, "mimetype": "image/jpeg", "size": poster.count]],
        ], session: session)
        XCTAssertNotNil(sent["event_id"], "send: \(sent)")

        let found = try await message(owner, roomId, within: 20) { $0.video != nil && $0.body == caption }
        let shown = try XCTUnwrap(found.video)
        XCTAssertEqual(shown.width, 640)
        XCTAssertEqual(shown.height, 360)
        XCTAssertEqual(shown.duration, 4200, "the length in milliseconds")
        XCTAssertEqual(shown.size, video.count)
        XCTAssertEqual(shown.mimetype, "video/mp4")
        XCTAssertNil(found.image)
        XCTAssertNil(found.file)

        let directory = freshDirectory()
        let posterFile = try await owner.videoPoster(roomId: roomId, messageId: found.id, directory: directory)
        let picture = try XCTUnwrap(UIImage(contentsOfFile: posterFile.path), "the poster is not a picture")
        XCTAssertEqual(picture.size, CGSize(width: 320, height: 180))
        let file = try await owner.videoFile(roomId: roomId, messageId: found.id, directory: directory)
        XCTAssertEqual(try Data(contentsOf: file), video, "the video is the sender's bytes")
        XCTAssertEqual(file.pathExtension, "mp4")
        // a second call finds the file and downloads nothing.
        let written = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        _ = try await owner.videoFile(roomId: roomId, messageId: found.id, directory: directory)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date, written)
    }

    /// A sticker (an m.sticker event, not a message) shows as a picture, and downloads whole: a
    /// server's thumbnail would lose its transparency. Until 2026-11-03 it was dropped.
    func testAStickerIsShownNotDropped() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[mediaName]!
        _ = try await owner.messages(roomId: roomId, limit: 20)

        let session = try other.savedSession()
        let png = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false; return f }()).pngData { c in
            UIColor.systemPink.setFill(); c.cgContext.fillEllipse(in: CGRect(x: 28, y: 28, width: 200, height: 200))
        }
        let uri = try await upload(png, type: "image/png", session: session)
        let name = "Sticker \(UUID().uuidString)"
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.sticker", UUID().uuidString], [
            "body": name, "url": uri, "info": ["w": 256, "h": 256, "mimetype": "image/png", "size": png.count],
        ], session: session)
        XCTAssertNotNil(sent["event_id"], "send: \(sent)")

        let start = Date()
        var sticker: Message?
        while sticker == nil, Date().timeIntervalSince(start) < 20 {
            sticker = try await owner.messages(roomId: roomId, limit: 20).last { $0.isSticker && $0.sender == user2 && $0.timestamp > UInt64(start.timeIntervalSince1970 * 1000) - 60_000 }
            if sticker == nil { try await Task.sleep(nanoseconds: 300_000_000) }
        }
        let found = try XCTUnwrap(sticker, "the sticker did not show")
        XCTAssertEqual(found.body, "", "a sticker shows no text")
        XCTAssertEqual(found.image?.width, 256)
        XCTAssertEqual(found.image?.height, 256)
        XCTAssertEqual(found.image?.isSticker, true)
        let file = try await owner.imageFile(roomId: roomId, messageId: found.id, full: false, directory: freshDirectory())
        XCTAssertEqual(try Data(contentsOf: file), png, "the sticker is the sender's picture, not a server's thumbnail")
    }

    /// A reply's quote names who wrote the quoted message, as the sender run's name does. A new
    /// device loads the chat's last messages before the room's members, so the quoted message's
    /// sender has no profile yet when the sdk copies it into the reply's quote, and the members'
    /// names reach the message but not the copy: before 2026-11-03 the quote showed a raw id.
    func testAReplysQuoteNamesItsSender() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[quoteName]!
        let ownerSession = try owner.savedSession(), otherSession = try other.savedSession()
        let otherName = try await displayName(user2, session: ownerSession)
        XCTAssertNotEqual(otherName, user2, "the other test user needs a name")

        // the other person writes; the reader writes three messages, the last one answering it.
        let quoted = "Quoted \(UUID().uuidString)"
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                                 ["msgtype": "m.text", "body": quoted], session: otherSession)
        let quotedId = try XCTUnwrap(sent["event_id"] as? String, "send: \(sent)")
        for n in 1...2 {
            _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                              ["msgtype": "m.text", "body": "Between \(n)"], session: ownerSession)
        }
        let answer = "Answer \(UUID().uuidString)"
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                          ["msgtype": "m.text", "body": answer, "m.relates_to": ["m.in_reply_to": ["event_id": quotedId]]],
                          session: ownerSession)

        // a new device opens the chat; once the members' names reach the quoted message, the quote names its sender too.
        let reader = try await signIn(homeserver, user, password)
        _ = try await reader.rooms()
        let named = try await message(reader, roomId, within: 20) { $0.body == quoted && $0.senderName != user2 }
        XCTAssertEqual(named.senderName, otherName)
        let start = Date()
        var reply = try await message(reader, roomId, within: 20) { $0.body == answer && $0.reply?.body == quoted }
        while reply.reply?.senderName != otherName, Date().timeIntervalSince(start) < 10 {
            try await Task.sleep(nanoseconds: 300_000_000)
            reply = try await message(reader, roomId, within: 20) { $0.body == answer && $0.reply?.body == quoted }
        }
        XCTAssertEqual(reply.reply?.senderName, otherName, "the quote names its sender, as their message does")
        XCTAssertEqual(reply.reply?.isOwn, false)
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
        for name in [seenName, mediaName, quoteName] {
            if let id = known.first(where: { $0.name == name })?.id {
                ids[name] = id
                continue
            }
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        // the other user's sync runs from here, so they can read and write in the rooms.
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

    /// A text message from `account`, which the server has.
    private func say(_ text: String, in roomId: String, as account: MatrixAccount) async throws {
        let sent = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                                 ["msgtype": "m.text", "body": text], session: try account.savedSession())
        XCTAssertNotNil(sent["event_id"], "send: \(sent)")
    }

    /// The first message the open chat shows that matches `match`, within `seconds`.
    private func message(_ account: MatrixAccount, _ roomId: String, within seconds: TimeInterval,
                         _ match: (Message) -> Bool) async throws -> Message {
        let start = Date()
        while true {
            if let found = try await account.messages(roomId: roomId, limit: 20).last(where: match) { return found }
            if Date().timeIntervalSince(start) > seconds {
                let last = try await account.messages(roomId: roomId, limit: 20).suffix(3)
                XCTFail("no such message within \(Int(seconds)) s; the last ones: \(last)")
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// The room's unread count once it matches `done`, within 20 s.
    private func unread(_ account: MatrixAccount, _ roomId: String, _ done: (Int) -> Bool) async throws -> Int {
        let start = Date()
        while true {
            let count = try await account.rooms().first { $0.id == roomId }?.unreadCount ?? -1
            if done(count) { return count }
            if Date().timeIntervalSince(start) > 20 {
                XCTFail("the unread count stayed \(count)")
                return count
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// A user's display name on the server (the localpart when they never set one).
    private func displayName(_ userId: String, session: SavedSession) async throws -> String {
        let profile = try await api("GET", ["profile", userId], session: session)
        return profile["displayname"] as? String ?? userId
    }

    private func upload(_ data: Data, type: String, session: SavedSession) async throws -> String {
        var request = URLRequest(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/media/v3/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        let (uploaded, _) = try await URLSession.shared.upload(for: request, from: data)
        return try XCTUnwrap((try JSONSerialization.jsonObject(with: uploaded) as? [String: Any])?["content_uri"] as? String)
    }

    private func jpeg(width: Int, height: Int, _ color: UIColor) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).jpegData(withCompressionQuality: 0.8) { c in
            color.setFill(); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
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

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)", isDirectory: true)
    }

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await signInTestDevice(homeserver, user, password)
    }
}
