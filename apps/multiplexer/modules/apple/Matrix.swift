import Foundation

/// Answers app.ts's asks with MatrixCore (the core-*.swift files beside this one).
/// The session is in the Keychain; the account's store is a folder in the app's data.
final class Matrix: ExactModule {
    // the agent's data is a fresh scratch tree, so it keeps its session apart from the app's.
    private lazy var keychain = SessionKeychain(service: "com.ramimaalouf.multiplexer.session" + (context.agent ? ".agent" : ""))
    /// A session the server must still forget. Until it does, its device stays on the account.
    private lazy var pending = SessionKeychain(service: keychain.service, slot: "sign-out")
    private var signingOutPending = false
    private var stores: URL { context.data.appendingPathComponent("matrix", isDirectory: true) }
    /// The signed-in account, made once and shared by every ask; nil when signed out or not restored yet.
    private var account: Task<MatrixAccount, Error>?
    /// Topics that changed and app.ts has not heard of yet: a burst of changes becomes one ask.
    private var changedTopics: Set<String> = []
    /// Downloaded pictures, as `app:/cache/matrix-media/<name>` in the view.
    private var media: URL { context.cache.appendingPathComponent("matrix-media", isDirectory: true) }
    /// Thumbnails on their way, and ones that failed (not tried again until the next launch).
    private var downloading: Set<String> = [], failedDownloads: Set<String> = []

    override func call(_ request: [String: Any]) throws -> [String: Any] {
        switch request["op"] as? String {
        case "session":
            defer { signOutPending() }
            return ["userId": try stored()?.session.userId ?? ""]
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
                    let started = Date(), account = try await signedIn(), rooms = try await account.rooms()
                    print("matrix: rooms answered \(rooms.count) chats in \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                    reply.send(["rooms": rooms.map { room in
                        ["id": room.id, "name": room.name, "isDirect": room.isDirect, "lastMessage": room.lastMessage,
                         "lastSender": room.lastSenderName, "lastIsOwn": room.lastIsOwn, "lastTime": Double(room.lastTimestamp),
                         "avatar": cached(room.avatarName, then: .rooms) {
                             _ = try await account.avatarFile(roomId: room.id, directory: self.media) }]
                    }])
                case "messages":
                    let roomId = request["roomId"] as? String ?? "", account = try await signedIn()
                    let messages = try await account.messages(roomId: roomId, limit: request["limit"] as? Int ?? 20)
                    let atStart = try await account.isAtStart(roomId: roomId)
                    reply.send(["atStart": atStart, "messages": messages.map {
                        ["id": $0.id, "sender": $0.sender, "senderName": $0.senderName, "body": $0.body,
                         "time": Double($0.timestamp), "isOwn": $0.isOwn, "state": $0.sendState.rawValue,
                         "waitingForKey": $0.waitingForKey,
                         "isImage": $0.image != nil, "image": thumbnail(account, roomId: roomId, message: $0),
                         "imageWidth": $0.image?.width ?? 0, "imageHeight": $0.image?.height ?? 0]
                    }])
                case "older":
                    let roomId = request["roomId"] as? String ?? ""
                    try await signedIn().loadOlder(roomId: roomId)
                    // older messages the timeline already held bring no change of their own.
                    changed(.room(roomId))
                    reply.send(["ok": true])
                case "photo":
                    let file = try await signedIn().imageFile(roomId: request["roomId"] as? String ?? "",
                                                              messageId: request["messageId"] as? String ?? "", full: true, directory: media)
                    reply.send(["path": "app:/cache/matrix-media/\(file.lastPathComponent)"])
                case "send":
                    // the message shows in the chat at once; its state says how the sending goes.
                    try await signedIn().send(roomId: request["roomId"] as? String ?? "", text: request["text"] as? String ?? "")
                    reply.send(["ok": true])
                case "discard":
                    try await signedIn().discard(roomId: request["roomId"] as? String ?? "", messageId: request["messageId"] as? String ?? "")
                    reply.send(["ok": true])
                case "retry":
                    try await signedIn().retry(roomId: request["roomId"] as? String ?? "", messageId: request["messageId"] as? String ?? "")
                    reply.send(["ok": true])
                case "signOut":
                    try await signOut()
                    reply.send(["ok": true])
                default:
                    reply.fail("matrix answers signIn, rooms, messages, older, photo, send, retry, discard and signOut")
                }
            } catch {
                reply.fail(String(describing: error))
            }
        }
    }

    /// The Keychain's session if its store is still there. A reinstall keeps the Keychain
    /// but not the store, and a session without its store has lost its encryption keys:
    /// it waits to be signed out on the server, and the app opens signed out.
    private func stored() throws -> StoredSession? {
        guard let stored = try keychain.read() else { return nil }
        if FileManager.default.fileExists(atPath: stores.appendingPathComponent(stored.store).path) { return stored }
        try pending.write(stored)
        try keychain.delete()
        return nil
    }

    /// Signs the pending session out on the server in the background. If the server cannot
    /// be reached, the session stays pending for the next launch.
    private func signOutPending() {
        guard !signingOutPending, let stale = try? pending.read() else { return }
        signingOutPending = true
        let scratch = context.temporary.appendingPathComponent("matrix-sign-out-\(UUID().uuidString)", isDirectory: true)
        Task { @MainActor in
            if await MatrixAccount.signOutOnServer(stale.session, scratchDirectory: scratch) {
                try? pending.delete()
                print("matrix: signed out a session whose store was gone")
            }
            signingOutPending = false
        }
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
            tellChanges(signedIn)
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
            let restored = try await restoring.value
            tellChanges(restored)
            return restored
        } catch {
            account = nil
            throw error
        }
    }

    /// A photo message's thumbnail as an `app:/` path once it is here (see `cached`).
    @MainActor private func thumbnail(_ account: MatrixAccount, roomId: String, message: Message) -> String {
        cached(message.image?.thumbnailName ?? "", then: .room(roomId)) {
            _ = try await account.imageFile(roomId: roomId, messageId: message.id, full: false, directory: self.media)
        }
    }

    /// A downloaded picture's `app:/` path once its file is here. Until then "": `fetch`
    /// starts (once), and when it ends app.ts is told `change`, so it asks again.
    @MainActor private func cached(_ name: String, then change: MatrixChange, fetch: @escaping () async throws -> Void) -> String {
        guard !name.isEmpty else { return "" }
        if FileManager.default.fileExists(atPath: media.appendingPathComponent(name).path) { return "app:/cache/matrix-media/\(name)" }
        guard !failedDownloads.contains(name), downloading.insert(name).inserted else { return "" }
        Task { @MainActor in
            do {
                try await fetch()
                changed(change)
            } catch {
                failedDownloads.insert(name)
            }
            downloading.remove(name)
        }
        return ""
    }

    /// Passes the account's changes to app.ts, as the topics its sources watch:
    /// `rooms`, and `thread:<room id>` for an open chat.
    private func tellChanges(_ account: MatrixAccount) {
        account.onChange { [weak self] change in
            DispatchQueue.main.async { self?.changed(change) }
        }
    }

    private func changed(_ change: MatrixChange) {
        if changedTopics.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                let topics = changedTopics
                changedTopics = []
                topics.forEach(context.changed)
            }
        }
        switch change {
        case .rooms: changedTopics.insert("rooms")
        case .room(let roomId): changedTopics.insert("thread:\(roomId)")
        }
    }

    /// Asks the server to forget this device, then forgets the session here. If the server
    /// could not be reached, the session waits to be signed out there later.
    @MainActor private func signOut() async throws {
        let stored = try keychain.read()
        var forgotten = false
        if let signedIn = try? await signedIn() { forgotten = (try? await signedIn.signOut()) != nil }
        account = nil
        if !forgotten, let stored { try pending.write(stored) }
        try keychain.delete()
        try? FileManager.default.removeItem(at: stores)
        try? FileManager.default.removeItem(at: media)
        if !forgotten { signOutPending() }
    }
}
let exactModule: ExactModule.Type = Matrix.self
