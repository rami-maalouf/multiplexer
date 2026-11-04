import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The account data only this account sees (its own names, archive and delete marks, reminders,
/// merged chats, frequent emojis, bookmarks) is one global event of each type, which a change writes whole. A
/// device just signed in has none of them in its store until some seconds after its first sync
/// (seen 2026-11-03), so a change made then would start from nothing and replace what the other
/// devices saved. A change starts from the server's event while the store has none.
extension MatrixAccount {
    /// The content a change of `type` starts from: the store's, else the server's. A failed server
    /// read throws, so no change starts from content this device does not know.
    func accountDataForChange(_ type: String) async throws -> String? {
        if let stored = try? await client.accountData(eventType: type) { return stored }
        let session = try savedSession()
        return try await serverAccountData.content(type) { try await accountDataOnServer(type, session: session) }
    }
}

/// The server's events read while the store had none, each kept a short while: a burst of changes
/// reads the server once.
final class ServerAccountData: @unchecked Sendable {
    /// After this, the server is asked again (another device may have changed the event).
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var fetched: [String: (content: String?, at: Date)] = [:]

    func content(_ type: String, fetch: () async throws -> String?) async throws -> String? {
        if let known = lock.withLock({ fetched[type] }), Date().timeIntervalSince(known.at) < Self.patience { return known.content }
        let content = try await fetch()
        lock.withLock { fetched[type] = (content, Date()) }
        return content
    }
}

/// A global account data event's content on the server (`GET /user/{userId}/account_data/{type}`),
/// as JSON; nil when the account has none.
func accountDataOnServer(_ type: String, session: SavedSession) async throws -> String? {
    guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
    let url = base.appendingPathComponent("_matrix/client/v3/user").appendingPathComponent(session.userId)
        .appendingPathComponent("account_data").appendingPathComponent(type)
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    switch (response as? HTTPURLResponse)?.statusCode {
    case 200: return String(decoding: data, as: UTF8.self)
    case 404: return nil
    default: throw URLError(.badServerResponse)
    }
}
