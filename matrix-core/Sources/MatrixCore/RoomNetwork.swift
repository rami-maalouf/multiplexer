import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The chat networks a bridge can bring a room from, by the word in its users' ids. The sdk
/// does not sync a bridge's own state (`m.bridge`), so a room's network comes from those users
/// (`matrix-core/NOTES.md`, "A chat's network").
enum RoomNetwork {
    /// A room no bridge serves.
    static let matrix = "matrix"

    /// Each network, and the words its bridges name their users with: the bot (`whatsappbot`)
    /// and its ghosts (`whatsapp_<id>`). Messenger's older bridge said "facebook".
    private static let words: [(network: String, words: [String])] = [
        ("whatsapp", ["whatsapp"]), ("instagram", ["instagram"]), ("messenger", ["messenger", "facebook"]),
        ("telegram", ["telegram"]), ("signal", ["signal"]), ("discord", ["discord"]), ("linkedin", ["linkedin"]),
    ]

    /// Every network, in the filter sheet's order: Matrix first, as Beeper lists its own
    /// network first, then the bridged ones.
    static var all: [String] { [matrix] + words.map(\.network) }

    /// A room's network, from the bridge bot it names as a service member (a mautrix bridge
    /// puts `io.element.functional_members` in each room it makes), else from its heroes: a
    /// ghost or a bot of a bridge on this account's own server. `matrix` when none is a bridge's.
    static func of(serviceMembers: [String], heroes: [String], ownUserId: String) -> String {
        let ownServer = server(ownUserId)
        let candidates = serviceMembers + heroes.filter { !ownServer.isEmpty && server($0) == ownServer }
        for userId in candidates {
            if let network = network(ofBridgeUser: userId) { return network }
        }
        return matrix
    }

    static func of(_ info: RoomInfo, ownUserId: String) -> String {
        of(serviceMembers: info.serviceMembers, heroes: info.heroes.map(\.userId), ownUserId: ownUserId)
    }

    /// The network of a bridge's bot (`@whatsappbot:server`) or ghost (`@whatsapp_123:server`).
    static func network(ofBridgeUser userId: String) -> String? {
        let local = userId.dropFirst().prefix { $0 != ":" }.lowercased()
        return words.first { $0.words.contains { local == "\($0)bot" || local.hasPrefix("\($0)_") } }?.network
    }

    private static func server(_ userId: String) -> String {
        userId.firstIndex(of: ":").map { String(userId[userId.index(after: $0)...]) } ?? ""
    }
}
