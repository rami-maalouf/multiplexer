@testable import MatrixCore
import XCTest

/// A chat's network (b1). The end-to-end test uses a room of its own ("Multiplexer network
/// test"), so other tests' messages never cross it.
final class RoomNetworkTests: XCTestCase {
    private let roomName = "Multiplexer network test"
    /// @test1's rooms that no bridge serves, made by the other tests.
    private let plainRooms = ["Multiplexer test", "Multiplexer encrypted test", "Multiplexer two-person test"]

    /// The room gets the state a mautrix bridge puts in each room it makes (mautrix-go,
    /// bridgev2/portal.go, `CreateMatrixRoom`): `m.bridge` and `uk.half-shot.bridge` with the
    /// network as `protocol.id`, and `io.element.functional_members` naming the bridge's bot.
    /// The sdk syncs only the last (the spike in NOTES.md), and a new device reads the network from it.
    func testABridgedRoomShowsItsNetworkOnANewDevice() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["MATRIX_TEST_USER"], let password = env["MATRIX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("MATRIX_TEST_USER and MATRIX_TEST_PASSWORD are not set")
        }
        let homeserver = env["MATRIX_TEST_HOMESERVER"] ?? "matrix.org"
        let server = String(user.split(separator: ":").last ?? "")
        let writer = try await signIn(homeserver, user, password)
        let rooms = try await writer.rooms()
        let roomId: String
        if let id = rooms.first(where: { $0.name == roomName })?.id { roomId = id } else { roomId = try await writer.createRoom(name: roomName) }
        let session = try writer.savedSession()
        try await bridge(roomId, network: "whatsapp", bot: "@whatsappbot:\(server)", session: session)

        let reader = try await signIn(homeserver, user, password)
        let seen = try await reader.rooms()
        XCTAssertEqual(seen.first { $0.id == roomId }?.network, "whatsapp")
        let plain = seen.filter { plainRooms.contains($0.name) }
        XCTAssertFalse(plain.isEmpty, "no plain test room: \(seen.map(\.name))")
        XCTAssertEqual(Set(plain.map(\.network)), ["matrix"])

        // a room the bridge changes while the list is open shows its new network.
        addTeardownBlock { try? await self.bridge(roomId, network: "whatsapp", bot: "@whatsappbot:\(server)", session: session) }
        try await bridge(roomId, network: "telegram", bot: "@telegrambot:\(server)", session: session)
        let changed = try await network(reader, roomId, becomes: "telegram")
        XCTAssertEqual(changed, "telegram")
        try await bridge(roomId, network: "whatsapp", bot: "@whatsappbot:\(server)", session: session)
        let back = try await network(reader, roomId, becomes: "whatsapp")
        XCTAssertEqual(back, "whatsapp")
    }

    func testABridgesBotNamesItsNetwork() {
        let me = "@me:example.org"
        for network in ["whatsapp", "instagram", "messenger", "telegram", "signal", "discord", "linkedin"] {
            XCTAssertEqual(RoomNetwork.of(serviceMembers: ["@\(network)bot:example.org"], heroes: [], ownUserId: me), network)
        }
        // messenger's older bridge, and a bot on another server (a room bridged elsewhere).
        XCTAssertEqual(RoomNetwork.of(serviceMembers: ["@facebookbot:example.org"], heroes: [], ownUserId: me), "messenger")
        XCTAssertEqual(RoomNetwork.of(serviceMembers: ["@signalbot:other.org"], heroes: [], ownUserId: me), "signal")
        // a service member that is no bridge's (a room's own bot) names none.
        XCTAssertEqual(RoomNetwork.of(serviceMembers: ["@helper:example.org"], heroes: [], ownUserId: me), "matrix")
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: [], ownUserId: me), "matrix")
    }

    /// A bridge that sets no service members: its ghost (a one-to-one chat with no name has
    /// the other person as its hero) or its bot, on this account's server.
    func testABridgesGhostOnThisServerNamesItsNetwork() {
        let me = "@me:example.org"
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: ["@discord_123456:example.org"], ownUserId: me), "discord")
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: ["@WhatsApp_96170:example.org"], ownUserId: me), "whatsapp")
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: ["@telegrambot:example.org"], ownUserId: me), "telegram")
        // a person elsewhere whose name merely starts like a ghost's, and people who are no ghosts.
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: ["@signal_fan:other.org"], ownUserId: me), "matrix")
        XCTAssertEqual(RoomNetwork.of(serviceMembers: [], heroes: ["@whatsappbotfan:example.org", "@test2:example.org"], ownUserId: me), "matrix")
        // the bot a room names wins over its heroes.
        XCTAssertEqual(RoomNetwork.of(serviceMembers: ["@instagrambot:example.org"], heroes: ["@whatsapp_1:example.org"], ownUserId: me), "instagram")
    }

    /// Puts a bridge's state in the room, as `testABridgedRoomShowsItsNetworkOnANewDevice` says.
    private func bridge(_ roomId: String, network: String, bot: String, session: SavedSession) async throws {
        let server = String(bot.split(separator: ":").last ?? "")
        let info: [String: Any] = [
            "bridgebot": bot, "creator": bot,
            "protocol": ["id": network, "displayname": network.capitalized],
            "channel": ["id": "multiplexer-network-test", "displayname": roomName],
            "com.beeper.room_type": "dm", "com.beeper.room_type.v2": "dm",
        ]
        // a bridge's state key is its server and appservice id.
        try await putState(info, type: "m.bridge", stateKey: "\(server)/\(network)", roomId: roomId, session: session)
        try await putState(info, type: "uk.half-shot.bridge", stateKey: "\(server)/\(network)", roomId: roomId, session: session)
        try await putState(["service_members": [bot]], type: "io.element.functional_members", stateKey: "", roomId: roomId, session: session)
    }

    /// The room's network once it is `expected`, or the last one after 15 s.
    private func network(_ account: MatrixAccount, _ roomId: String, becomes expected: String) async throws -> String {
        let start = Date()
        var network = try await account.rooms().first { $0.id == roomId }?.network ?? ""
        while network != expected, Date().timeIntervalSince(start) < 15 {
            try await Task.sleep(nanoseconds: 300_000_000)
            network = try await account.rooms().first { $0.id == roomId }?.network ?? ""
        }
        return network
    }

    private func putState(_ content: [String: Any], type: String, stateKey: String, roomId: String, session: SavedSession) async throws {
        // a bridge's state key holds a slash, which the path must carry encoded.
        let key = stateKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let url = URL(string: session.homeserverUrl)!.appendingPathComponent("_matrix/client/v3/rooms")
            .appendingPathComponent(roomId).appendingPathComponent("state").appendingPathComponent(type)
        var put = URLRequest(url: URL(string: url.absoluteString + "/" + key)!)
        put.httpMethod = "PUT"
        put.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        put.setValue("application/json", forHTTPHeaderField: "Content-Type")
        put.httpBody = try JSONSerialization.data(withJSONObject: content)
        let (body, response) = try await URLSession.shared.data(for: put)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, String(decoding: body, as: UTF8.self))
    }

    /// A new device of a test user, signed out at the test's end (TestDevices.swift).
    private func signIn(_ homeserver: String, _ user: String, _ password: String) async throws -> MatrixAccount {
        try await testAccount(homeserver, user, password)
    }
}
