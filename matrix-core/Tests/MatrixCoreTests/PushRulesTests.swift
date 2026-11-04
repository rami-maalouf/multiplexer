@testable import MatrixCore
import XCTest

/// What the server would push (P3.6), as Synapse itself decides it from the account's push rules:
/// `GET /_matrix/client/v3/notifications` lists the events whose actions notify. `@test2` writes in
/// three rooms of `@test1`'s: a normal one, one left to mentions only (the room rule with no actions
/// a mautrix bridge sets for a chat muted on its network) and one muted in our app (`MatrixAccount.mute`). The rooms
/// are not encrypted: the server cannot read a mention inside an encrypted message.
final class PushRulesTests: XCTestCase {
    private let normalName = "Multiplexer push rules normal"
    private let mentionsName = "Multiplexer push rules mentions only"
    private let mutedName = "Multiplexer push rules muted"

    func testAMutedChatNotifiesNothingAndAMentionsOnlyChatOnlyItsMentions() async throws {
        let (homeserver, user, password, user2, password2) = try twoUsers()
        let reader = try await signIn(homeserver, user, password)
        let sender = try await signIn(homeserver, user2, password2)
        let rooms = try await testRooms(reader, sender, user2: user2)
        let normal = try XCTUnwrap(rooms[normalName]), mentions = try XCTUnwrap(rooms[mentionsName]), muted = try XCTUnwrap(rooms[mutedName])
        let readerSession = try reader.savedSession(), senderSession = try sender.savedSession()

        // the rules of each room: none, the bridge's room rule, our mute. The first two are set as
        // another client or the bridge would, not with the app's unmute: the app shows what it asked
        // for until the server says the same, and the bridge's rule would come in the same sync.
        for id in [normal, mentions] {
            for path in [["override", id], ["override", MatrixAccount.mentionRule(id)], ["room", id]] {
                _ = try await api("DELETE", ["pushrules", "global"] + path, session: readerSession)
            }
        }
        // exactly what mautrix-go writes for a chat muted on its network (`ASIntent.MuteRoom`).
        _ = try await api("PUT", ["pushrules", "global", "room", mentions], ["actions": [String]()], session: readerSession)
        try await reader.mute(roomId: muted)
        addTeardownBlock {
            try? await reader.unmute(roomId: mentions)
            try? await reader.unmute(roomId: muted)
        }
        // the list learns the rules with the sync.
        let ruled = Date()
        var quiet = try await reader.rooms().filter(\.isMuted).map(\.id)
        while !(quiet.contains(muted) && quiet.contains(mentions) && !quiet.contains(normal)), Date().timeIntervalSince(ruled) < 20 {
            try await Task.sleep(nanoseconds: 500_000_000)
            quiet = try await reader.rooms().filter(\.isMuted).map(\.id)
        }
        XCTAssertTrue(quiet.contains(muted), "the list does not show the muted chat as muted")
        XCTAssertTrue(quiet.contains(mentions), "the list does not show the mentions-only chat as muted")
        XCTAssertFalse(quiet.contains(normal))

        // a plain message and a mention in each.
        var sent: [String: (plain: String, mention: String)] = [:]
        for id in [normal, mentions, muted] {
            let plain = try await send(["msgtype": "m.text", "body": "Plain \(token())"], in: id, session: senderSession)
            let mention = try await send(["msgtype": "m.text", "body": "test1: Mention \(token())",
                                          "m.mentions": ["user_ids": [readerSession.userId]]], in: id, session: senderSession)
            sent[id] = (plain, mention)
        }

        // what the server would push: it decides as each event arrives.
        let all = sent.values.flatMap { [$0.plain, $0.mention] }
        let start = Date()
        var notified = try await notifications(readerSession)
        while !notified.contains(sent[normal]!.mention), Date().timeIntervalSince(start) < 20 {
            try await Task.sleep(nanoseconds: 500_000_000)
            notified = try await notifications(readerSession)
        }
        notified.formIntersection(all)
        XCTAssertTrue(notified.contains(sent[normal]!.plain), "a normal chat's message does not notify")
        XCTAssertTrue(notified.contains(sent[normal]!.mention), "a normal chat's mention does not notify")
        XCTAssertFalse(notified.contains(sent[mentions]!.plain), "a mentions-only chat's plain message notifies")
        XCTAssertTrue(notified.contains(sent[mentions]!.mention), "a mentions-only chat's mention does not notify")
        XCTAssertFalse(notified.contains(sent[muted]!.plain), "a muted chat's message notifies")
        XCTAssertFalse(notified.contains(sent[muted]!.mention), "a muted chat's mention notifies")

        // a mention in the muted chat still counts, for the list's "@" (no push).
        let start2 = Date()
        var mentioned = try await reader.rooms().first { $0.id == muted }?.unreadMentions ?? 0
        while mentioned == 0, Date().timeIntervalSince(start2) < 20 {
            try await Task.sleep(nanoseconds: 500_000_000)
            mentioned = try await reader.rooms().first { $0.id == muted }?.unreadMentions ?? 0
        }
        XCTAssertGreaterThan(mentioned, 0, "the muted chat's mention is not counted")
        for id in [normal, mentions, muted] { try await reader.markRead(roomId: id) }
    }

    // MARK: helpers

    /// The ids of the events the server listed as notifications for this account (its newest 100).
    private func notifications(_ session: SavedSession) async throws -> Set<String> {
        var url = URLComponents(url: URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/notifications"),
                                resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "limit", value: "100")]
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let list = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["notifications"] as? [[String: Any]] ?? []
        return Set(list.compactMap { ($0["event"] as? [String: Any])?["event_id"] as? String })
    }

    /// Sends a message as it is (its `m.mentions` included); its event id.
    private func send(_ content: [String: Any], in roomId: String, session: SavedSession) async throws -> String {
        let answer = try await api("PUT", ["rooms", roomId, "send", "m.room.message", UUID().uuidString], content, session: session)
        return try XCTUnwrap(answer["event_id"] as? String, "send: \(answer)")
    }

    /// The three rooms by name, made by the first user on the first run, with the second in them.
    private func testRooms(_ owner: MatrixAccount, _ other: MatrixAccount, user2: String) async throws -> [String: String] {
        let session = try owner.savedSession(), otherSession = try other.savedSession()
        let known = try await owner.rooms()
        var ids: [String: String] = [:]
        for name in [normalName, mentionsName, mutedName] {
            if let id = known.first(where: { $0.roomName == name })?.id {
                ids[name] = id
                continue
            }
            let created = try await api("POST", ["createRoom"], ["name": name, "preset": "private_chat", "invite": [user2]], session: session)
            let id = try XCTUnwrap(created["room_id"] as? String, "createRoom: \(created)")
            _ = try await api("POST", ["join", id], [:], session: otherSession)
            ids[name] = id
        }
        let start = Date()
        while Date().timeIntervalSince(start) < 20 {
            let joined = try await owner.rooms().map(\.id)
            if ids.values.allSatisfy(joined.contains) { return ids }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("the push rules test rooms did not reach the first user's list")
        throw CancellationError()
    }

    private func twoUsers() throws -> (String, String, String, String, String) {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty,
              let user2 = env["MATRIX_TEST_USER2"], let password2 = env["MATRIX_TEST_PASSWORD2"], !password2.isEmpty else {
            throw XCTSkip("two test users are needed (MATRIX_TEST_USER2 and MATRIX_TEST_PASSWORD2)")
        }
        return (env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org", user, password, user2, password2)
    }

    private func token() -> String { String(UUID().uuidString.prefix(8)) }

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

    /// Signs in as a new device that the test signs out at its end, even when it fails.
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        let account = try await MatrixAccount.signIn(homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                                                     storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"))
        addTeardownBlock { try? await account.signOut() }
        return account
    }
}
