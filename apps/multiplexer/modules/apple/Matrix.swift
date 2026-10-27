import Foundation

/// Answers app.ts's asks with MatrixCore (the core-*.swift files beside this one).
/// The session is in the Keychain; the account's store is a folder in the app's data.
final class Matrix: ExactModule {
    // the agent's data is a fresh scratch tree, so it keeps its session apart from the app's.
    private lazy var keychain = SessionKeychain(service: "com.ramimaalouf.multiplexer.session" + (context.agent ? ".agent" : ""))
    private var stores: URL { context.data.appendingPathComponent("matrix", isDirectory: true) }
    /// The signed-in account, made once and shared by every ask; nil when signed out or not restored yet.
    private var account: Task<MatrixAccount, Error>?

    override func call(_ request: [String: Any]) throws -> [String: Any] {
        switch request["op"] as? String {
        case "session": return ["userId": try stored()?.session.userId ?? ""]
        default: throw ExactNativeRefusal("matrix answers session")
        }
    }

    override func later(_ request: [String: Any], reply: ExactReply) {
        Task { @MainActor in
            do {
                switch request["op"] as? String {
                case "signIn":
                    reply.send(await signIn(server: request["server"] as? String ?? "", user: request["user"] as? String ?? "",
                                            password: request["password"] as? String ?? ""))
                case "rooms":
                    reply.send(["rooms": try await signedIn().rooms().map { ["id": $0.id, "name": $0.name] }])
                case "signOut":
                    try await signOut()
                    reply.send(["ok": true])
                default:
                    reply.fail("matrix answers signIn, rooms and signOut")
                }
            } catch {
                reply.fail(String(describing: error))
            }
        }
    }

    /// The Keychain's session if its store is still there. A reinstall keeps the Keychain
    /// but not the store, and a session without its store has lost its encryption keys.
    private func stored() throws -> StoredSession? {
        guard let stored = try keychain.read() else { return nil }
        if FileManager.default.fileExists(atPath: stores.appendingPathComponent(stored.store).path) { return stored }
        try keychain.delete()
        return nil
    }

    /// A refusal is a reply: `problem` names it for app.ts, which says it to the person.
    @MainActor private func signIn(server: String, user: String, password: String) async -> [String: Any] {
        account = nil
        try? FileManager.default.removeItem(at: stores)
        let store = UUID().uuidString
        do {
            let signedIn = try await MatrixAccount.signIn(homeserver: server, user: user, password: password,
                                                          deviceName: context.agent ? "Multiplexer test" : "Multiplexer",
                                                          storeDirectory: stores.appendingPathComponent(store))
            do {
                try keychain.write(StoredSession(session: try signedIn.savedSession(), store: store))
            } catch {
                // a session this device cannot keep must not stay on the server.
                try? await signedIn.signOut()
                throw error
            }
            account = Task { signedIn }
            return ["ok": true, "problem": "", "detail": ""]
        } catch {
            try? FileManager.default.removeItem(at: stores)
            let problem: String
            switch error as? SignInError {
            case .wrongPassword?: problem = "wrong-password"
            case .serverNotFound?: problem = "server-not-found"
            case .serverNotSupported?: problem = "server-not-supported"
            case .rateLimited?: problem = "rate-limited"
            case .other?, nil: problem = "other"
            }
            return ["ok": false, "problem": problem, "detail": String(describing: error)]
        }
    }

    @MainActor private func signedIn() async throws -> MatrixAccount {
        if let account { return try await account.value }
        guard let stored = try stored() else { throw ExactNativeRefusal("signed out") }
        let restoring = Task { try await MatrixAccount.restore(stored.session, storeDirectory: stores.appendingPathComponent(stored.store)) }
        account = restoring
        do {
            return try await restoring.value
        } catch {
            account = nil
            throw error
        }
    }

    /// Asks the server to forget this device, then forgets the session here even if the server could not be reached.
    @MainActor private func signOut() async throws {
        if let signedIn = try? await signedIn() { try? await signedIn.signOut() }
        account = nil
        try keychain.delete()
        try? FileManager.default.removeItem(at: stores)
    }
}
let exactModule: ExactModule.Type = Matrix.self
