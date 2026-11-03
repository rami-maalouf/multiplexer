@testable import MatrixCore
import UIKit
import XCTest

/// A chat's info page (B20), as two test users (`scripts/test-matrix-core.sh` passes them). The
/// rooms are the test's own, made on the first run.
final class ChatInfoTests: XCTestCase {
    private let infoName = "Multiplexer info test"
    private let mediaName = "Multiplexer info test media"
    /// Renamed by the test, so it is found by this start of its name.
    private let renameName = "Multiplexer info test rename"
    private let inviteName = "Multiplexer info test invite"

    /// The info page's header and members: the network, the member count, both people by name, and
    /// what this account may change.
    func testInfoNamesItsMembersAndWhatYouMayChange() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[infoName]!
        let otherName = try await displayName(user2, session: try owner.savedSession())

        let info = try await owner.chatInfo(roomId: roomId)
        XCTAssertEqual(info.name, infoName)
        XCTAssertEqual(info.roomName, infoName)
        XCTAssertEqual(info.customName, "")
        XCTAssertEqual(info.network, "matrix")
        XCTAssertEqual(info.memberCount, 2)
        XCTAssertTrue(info.canRename, "the room's creator may rename it")
        XCTAssertTrue(info.canChangePicture)
        XCTAssertTrue(info.canInvite)

        let members = try await owner.chatMembers(roomId: roomId)
        XCTAssertEqual(Set(members.map(\.userId)), [user, user2])
        XCTAssertEqual(members.first { $0.userId == user2 }?.name, otherName)
        XCTAssertEqual(members.first { $0.userId == user }?.isOwn, true)
        XCTAssertEqual(members.first { $0.userId == user2 }?.isOwn, false)

        // the other person joined it: a private chat's power levels let only its creator rename it.
        let theirs = try await other.chatInfo(roomId: roomId)
        XCTAssertEqual(theirs.memberCount, 2)
        XCTAssertFalse(theirs.canRename)
    }

    /// A new name and a new picture reach the other person.
    func testANewNameAndPictureReachTheOther() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[renameName]!

        // the room may have a picture from an earlier run: the new one is another.
        let before = try await other.chatInfo(roomId: roomId).pictureUrl
        let name = "\(renameName) \(UUID().uuidString.prefix(8))"
        try await owner.setRoomName(roomId: roomId, name: name)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("picture-\(UUID().uuidString).jpg")
        try jpeg(width: 300, height: 300, .systemTeal).write(to: file)
        try await owner.setRoomPicture(roomId: roomId, file: file, mimetype: "image/jpeg", width: 300, height: 300)

        let start = Date()
        var seen = try await other.chatInfo(roomId: roomId)
        while (seen.roomName != name || seen.pictureUrl.isEmpty || seen.pictureUrl == before), Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            seen = try await other.chatInfo(roomId: roomId)
        }
        XCTAssertEqual(seen.roomName, name, "the other sees the new name")
        XCTAssertEqual(seen.name, name)
        XCTAssertFalse(seen.pictureUrl.isEmpty, "the other sees a picture")
        XCTAssertNotEqual(seen.pictureUrl, before, "the other sees the new picture")
        let picture = try await other.chatPicture(roomId: roomId, directory: freshDirectory())
        let downloaded = try XCTUnwrap(picture.flatMap { UIImage(contentsOfFile: $0.path) }, "the picture did not download")
        XCTAssertEqual(downloaded.size.width, 300, accuracy: 1)
        XCTAssertEqual(picture?.lastPathComponent, MatrixAccount.largePictureName(seen.pictureUrl))
    }

    /// A name only you see: it shows in your list on another of your devices, with the room's own
    /// name beside it, and not to the other person; taking it away shows the room's name again.
    func testANameOnlyYouSeeShowsOnYourOtherDeviceNotTheOthers() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[infoName]!

        let mine = "Only mine \(UUID().uuidString.prefix(8))"
        try await owner.setCustomName(roomId: roomId, name: "  \(mine) ")
        let shown = try await owner.rooms().first { $0.id == roomId }
        XCTAssertEqual(shown?.name, mine, "this device shows it at once, trimmed")
        XCTAssertEqual(shown?.roomName, infoName)

        let second = try await signIn(homeserver, user, password)
        let start = Date()
        var there = try await second.rooms().first { $0.id == roomId }
        while there?.name != mine, Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            there = try await second.rooms().first { $0.id == roomId }
        }
        XCTAssertEqual(there?.name, mine, "another device of the account shows it")
        let info = try await second.chatInfo(roomId: roomId)
        XCTAssertEqual(info.customName, mine)
        XCTAssertEqual(info.roomName, infoName)
        let theirs = try await other.rooms().first { $0.id == roomId }
        XCTAssertEqual(theirs?.name, infoName, "the other person sees the room's name")

        try await owner.setCustomName(roomId: roomId, name: "")
        let back = try await owner.rooms().first { $0.id == roomId }
        XCTAssertEqual(back?.name, infoName)
        let cleared = try await owner.chatInfo(roomId: roomId)
        XCTAssertEqual(cleared.customName, "")
    }

    /// The grid: the newest photos and videos, newest first, with no text message among them; a
    /// photo's thumbnail and a video's poster download by the grid's ids.
    func testRecentMediaIsTheNewestPhotosAndVideos() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let roomId = try await testRooms(owner, other, user2: user2)[mediaName]!
        let session = try other.savedSession()

        let tag = UUID().uuidString.prefix(8)
        let photo = jpeg(width: 400, height: 300, .systemOrange)
        let photoUri = try await upload(photo, type: "image/jpeg", session: session)
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], [
            "msgtype": "m.image", "body": "first.jpg", "filename": "first.jpg", "url": photoUri,
            "info": ["w": 400, "h": 300, "mimetype": "image/jpeg", "size": photo.count]], session: session)
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString],
                          ["msgtype": "m.text", "body": "Between \(tag)"], session: session)
        let video = Data((0..<20_000).map { UInt8($0 % 251) })
        let poster = jpeg(width: 320, height: 180, .systemIndigo)
        let videoUri = try await upload(video, type: "video/mp4", session: session)
        let posterUri = try await upload(poster, type: "image/jpeg", session: session)
        _ = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], [
            "msgtype": "m.video", "body": "Clip \(tag)", "filename": "clip.mp4", "url": videoUri,
            "info": ["w": 640, "h": 360, "duration": 3000, "mimetype": "video/mp4", "size": video.count,
                     "thumbnail_url": posterUri, "thumbnail_info": ["w": 320, "h": 180, "mimetype": "image/jpeg", "size": poster.count]],
        ], session: session)

        let start = Date()
        var media = try await owner.recentMedia(roomId: roomId, limit: 2)
        while media.first?.caption != "Clip \(tag)", Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 300_000_000)
            media = try await owner.recentMedia(roomId: roomId, limit: 2)
        }
        XCTAssertEqual(media.count, 2)
        let clip = try XCTUnwrap(media.first)
        XCTAssertEqual(clip.caption, "Clip \(tag)", "the newest first")
        XCTAssertTrue(clip.isVideo)
        XCTAssertEqual(clip.duration, 3000)
        XCTAssertEqual(clip.width, 640)
        XCTAssertFalse(clip.isOwn)
        let picture = media[1]
        XCTAssertFalse(picture.isVideo, "the text between is left out")
        XCTAssertEqual(picture.width, 400)
        XCTAssertEqual(picture.height, 300)
        XCTAssertTrue(picture.id.hasPrefix(MediaTimeline.prefix))

        let directory = freshDirectory()
        let thumbnail = try await owner.imageFile(roomId: roomId, messageId: picture.id, full: false, directory: directory)
        XCTAssertEqual(thumbnail.lastPathComponent, picture.thumbnailName)
        XCTAssertNotNil(UIImage(contentsOfFile: thumbnail.path), "the photo's thumbnail is a picture")
        let full = try await owner.imageFile(roomId: roomId, messageId: picture.id, full: true, directory: directory)
        XCTAssertEqual(try Data(contentsOf: full), photo, "the photo is the sender's bytes")
        let posterFile = try await owner.videoPoster(roomId: roomId, messageId: clip.id, directory: directory)
        XCTAssertEqual(posterFile.lastPathComponent, clip.thumbnailName)
        let videoFile = try await owner.videoFile(roomId: roomId, messageId: clip.id, directory: directory)
        XCTAssertEqual(try Data(contentsOf: videoFile), video)
    }

    /// Add member: the invited person gets the invite (and declines it, so the next run invites again).
    func testAnInviteReachesThePerson() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let owner = try await signIn(homeserver, user, password)
        let other = try await signIn(homeserver, user2, password2)
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        let roomId: String
        if let id = known.first(where: { $0.name == inviteName })?.id {
            roomId = id
        } else {
            let created = try await api("POST", ["createRoom"], ["name": inviteName, "preset": "private_chat"], session: session)
            roomId = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
        }
        try await owner.invite(roomId: roomId, userId: user2)
        let state = try await api("GET", ["rooms", roomId, "state", "m.room.member", user2], session: session)
        XCTAssertEqual(state["membership"] as? String, "invite")
        _ = try await api("POST", ["rooms", roomId, "leave"], [:], session: otherSession)
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

    /// The test's rooms by name, made by the first user on the first run, with the second user in
    /// them. The renamed room is found by the start of its name, among those the first user has.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        for name in [infoName, mediaName, renameName] {
            let found = name == renameName ? known.first { $0.roomName.hasPrefix(renameName) } : known.first { $0.roomName == name }
            if let id = found?.id {
                ids[name] = id
                continue
            }
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        _ = try await other.rooms()
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id), theirs = try await other.rooms().map(\.id)
            if ids.values.allSatisfy({ joined.contains($0) && theirs.contains($0) }) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the test rooms did not reach both users' lists")
        throw CancellationError()
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

    /// Signs in as a new device that the test signs out at its end, even when it fails. The server
    /// limits sign-ins, and other tests sign in as the same users: a refusal waits and tries again.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        for attempt in 1... {
            do {
                let account = try await MatrixAccount.signIn(
                    homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                    storeDirectory: freshDirectory())
                addTeardownBlock { try? await account.signOut() }
                return account
            } catch SignInError.rateLimited where attempt < 4 {
                try await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        fatalError("unreachable")
    }
}
